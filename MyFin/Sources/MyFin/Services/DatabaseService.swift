import Foundation
import SQLCipher

enum DatabaseError: Error, Equatable {
    case openFailed(String)
    case keyingFailed(String)
    case wrongPassword
    case rekeyFailed(String)
}

final class DatabaseConnection {
    private var handle: OpaquePointer?

    private init(handle: OpaquePointer) {
        self.handle = handle
    }

    static func open(at url: URL, password: String) throws -> DatabaseConnection {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        let openResult = sqlite3_open_v2(url.path, &db, flags, nil)
        guard openResult == SQLITE_OK, let handle = db else {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            sqlite3_close_v2(db)
            throw DatabaseError.openFailed(message)
        }

        let keyResult = password.withCString { cPassword in
            sqlite3_key(handle, cPassword, Int32(strlen(cPassword)))
        }
        guard keyResult == SQLITE_OK else {
            sqlite3_close_v2(handle)
            throw DatabaseError.keyingFailed("sqlite3_key failed with code \(keyResult)")
        }

        // sqlite3_key() only derives a key; it never touches the file. A wrong
        // password is only revealed once we actually try to read the header.
        let checkResult = sqlite3_exec(handle, "SELECT count(*) FROM sqlite_master;", nil, nil, nil)
        guard checkResult == SQLITE_OK else {
            sqlite3_close_v2(handle)
            throw DatabaseError.wrongPassword
        }

        let connection = DatabaseConnection(handle: handle)
        do {
            try connection.runMigrations()
        } catch {
            connection.close()
            throw error
        }
        return connection
    }

    func rekey(newPassword: String) throws {
        guard let handle else { return }
        let result = newPassword.withCString { cPassword in
            sqlite3_rekey(handle, cPassword, Int32(strlen(cPassword)))
        }
        guard result == SQLITE_OK else {
            throw DatabaseError.rekeyFailed("sqlite3_rekey failed with code \(result)")
        }
    }

    func close() {
        guard let handle else { return }
        sqlite3_close_v2(handle)
        self.handle = nil
    }

    deinit {
        close()
    }
}

enum SQLValue: Equatable {
    case text(String)
    case int(Int64)
    case null
}

extension DatabaseConnection {
    var userVersion: Int32 {
        get throws {
            let rows = try query("PRAGMA user_version;")
            guard let value = rows.first?["user_version"], case let .int(v) = value else {
                return 0
            }
            return Int32(v)
        }
    }

    func setUserVersion(_ version: Int32) throws {
        try execute("PRAGMA user_version = \(version);")
    }

    @discardableResult
    func execute(_ sql: String, params: [SQLValue] = []) throws -> Int32 {
        guard let handle else { throw DatabaseError.openFailed("connection closed") }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(handle))
            sqlite3_finalize(statement)
            throw DatabaseError.openFailed(message)
        }
        defer { sqlite3_finalize(statement) }
        bind(params, to: statement)
        let stepResult = sqlite3_step(statement)
        guard stepResult == SQLITE_DONE || stepResult == SQLITE_ROW else {
            throw DatabaseError.openFailed(String(cString: sqlite3_errmsg(handle)))
        }
        return sqlite3_changes(handle)
    }

    func query(_ sql: String, params: [SQLValue] = []) throws -> [[String: SQLValue]] {
        guard let handle else { throw DatabaseError.openFailed("connection closed") }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(handle))
            sqlite3_finalize(statement)
            throw DatabaseError.openFailed(message)
        }
        defer { sqlite3_finalize(statement) }
        bind(params, to: statement)

        var rows: [[String: SQLValue]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: SQLValue] = [:]
            let columnCount = sqlite3_column_count(statement)
            for i in 0..<columnCount {
                let columnName = String(cString: sqlite3_column_name(statement, i))
                switch sqlite3_column_type(statement, i) {
                case SQLITE_INTEGER:
                    row[columnName] = .int(sqlite3_column_int64(statement, i))
                case SQLITE_NULL:
                    row[columnName] = .null
                default:
                    if let cString = sqlite3_column_text(statement, i) {
                        row[columnName] = .text(String(cString: cString))
                    } else {
                        row[columnName] = .null
                    }
                }
            }
            rows.append(row)
        }
        return rows
    }

    func withTransaction<T>(_ body: () throws -> T) throws -> T {
        try execute("BEGIN;")
        do {
            let result = try body()
            try execute("COMMIT;")
            return result
        } catch {
            _ = try? execute("ROLLBACK;")
            throw error
        }
    }

    private func bind(_ params: [SQLValue], to statement: OpaquePointer?) {
        for (index, param) in params.enumerated() {
            let position = Int32(index + 1)
            switch param {
            case .text(let value):
                sqlite3_bind_text(statement, position, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case .int(let value):
                sqlite3_bind_int64(statement, position, value)
            case .null:
                sqlite3_bind_null(statement, position)
            }
        }
    }
}


private struct MigrationStep {
    let version: Int32
    let statements: [String]
}

extension DatabaseConnection {
    private static let migrations: [MigrationStep] = [
        MigrationStep(version: 1, statements: [
            "CREATE TABLE IF NOT EXISTS _myfin_meta (id INTEGER PRIMARY KEY);"
        ]),
        MigrationStep(version: 2, statements: [
            """
            CREATE TABLE IF NOT EXISTS institutions (
                id TEXT PRIMARY KEY,
                source TEXT NOT NULL,
                country TEXT NOT NULL,
                name TEXT NOT NULL,
                aliases TEXT NOT NULL DEFAULT '[]',
                archived INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS accounts (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                country TEXT NOT NULL,
                type TEXT NOT NULL,
                currency TEXT NOT NULL,
                opening_balance TEXT NOT NULL,
                balance_date TEXT NOT NULL,
                institution_id TEXT NULL REFERENCES institutions(id),
                archived INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS transactions (
                id TEXT PRIMARY KEY,
                account_id TEXT NOT NULL REFERENCES accounts(id),
                amount TEXT NOT NULL,
                date TEXT NOT NULL,
                kind TEXT NOT NULL,
                created_at TEXT NOT NULL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS profile_settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            """
        ]),
        MigrationStep(version: 3, statements: []),
        MigrationStep(version: 4, statements: [
            """
            CREATE TABLE IF NOT EXISTS balance_history (
                id TEXT PRIMARY KEY,
                account_id TEXT NOT NULL REFERENCES accounts(id),
                balance TEXT NOT NULL,
                recorded_at TEXT NOT NULL
            );
            """
        ])
    ]

    func runMigrations() throws {
        let current = try userVersion
        for step in DatabaseConnection.migrations where step.version > current {
            try withTransaction {
                for statement in step.statements {
                    try execute(statement)
                }
                if step.version == 3 {
                    try seedSystemInstitutions()
                }
                try setUserVersion(step.version)
            }
        }
    }

    private func seedSystemInstitutions() throws {
        let now = ISO8601DateFormatter().string(from: Date())
        for entry in SystemInstitutionCatalog.all {
            let aliasesJSON = (try? JSONEncoder().encode(entry.aliases)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            try execute(
                """
                INSERT INTO institutions (id, source, country, name, aliases, archived, created_at, updated_at)
                VALUES (?, 'system', ?, ?, ?, 0, ?, ?);
                """,
                params: [.text(entry.id), .text(entry.country.rawValue), .text(entry.name), .text(aliasesJSON), .text(now), .text(now)]
            )
        }
    }
}
