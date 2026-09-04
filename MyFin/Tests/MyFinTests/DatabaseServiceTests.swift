import XCTest
@testable import MyFin

final class DatabaseServiceTests: XCTestCase {
    var tempDirectory: URL!
    var dbURL: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyFinDBTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        dbURL = tempDirectory.appendingPathComponent("db.sqlite")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func test_open_createsDatabaseFile() throws {
        let connection = try DatabaseConnection.open(at: dbURL, password: "correct-horse")
        connection.close()
        XCTAssertTrue(FileManager.default.fileExists(atPath: dbURL.path))
    }

    func test_open_withCorrectPassword_reopensSuccessfully() throws {
        try DatabaseConnection.open(at: dbURL, password: "correct-horse").close()
        try DatabaseConnection.open(at: dbURL, password: "correct-horse").close()
    }

    func test_open_withWrongPassword_throwsWrongPassword() throws {
        try DatabaseConnection.open(at: dbURL, password: "correct-horse").close()

        XCTAssertThrowsError(try DatabaseConnection.open(at: dbURL, password: "wrong-password")) { error in
            XCTAssertEqual(error as? DatabaseError, .wrongPassword)
        }
    }

    func test_rekey_allowsReopeningWithNewPasswordOnly() throws {
        let connection = try DatabaseConnection.open(at: dbURL, password: "old-password")
        try connection.rekey(newPassword: "new-password")
        connection.close()

        try DatabaseConnection.open(at: dbURL, password: "new-password").close()

        XCTAssertThrowsError(try DatabaseConnection.open(at: dbURL, password: "old-password"))
    }

    private func makeConnection() throws -> DatabaseConnection {
        try DatabaseConnection.open(at: dbURL, password: "correct-horse")
    }

    private func tempDatabaseURL() -> URL {
        tempDirectory.appendingPathComponent("db2-\(UUID().uuidString).sqlite")
    }

    func test_executeAndQuery_roundTripsTextAndIntValues() throws {
        let connection = try makeConnection()
        try connection.execute("CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT, n INTEGER);")
        try connection.execute("INSERT INTO t (id, name, n) VALUES (?, ?, ?);", params: [.int(1), .text("hello"), .int(42)])
        let rows = try connection.query("SELECT id, name, n FROM t WHERE id = ?;", params: [.int(1)])
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0]["name"], .text("hello"))
        XCTAssertEqual(rows[0]["n"], .int(42))
    }

    func test_userVersion_canBeReadAndSet() throws {
        // A freshly opened connection is already auto-migrated to the latest
        // schema version (see migration tests below) -- this test only
        // verifies get/set plumbing, not a specific starting value.
        let connection = try makeConnection()
        try connection.setUserVersion(99)
        XCTAssertEqual(try connection.userVersion, 99)
    }

    func test_withTransaction_rollsBackOnThrow() throws {
        let connection = try makeConnection()
        try connection.execute("CREATE TABLE t (id INTEGER PRIMARY KEY);")
        struct Boom: Error {}
        XCTAssertThrowsError(try connection.withTransaction {
            try connection.execute("INSERT INTO t (id) VALUES (1);")
            throw Boom()
        })
        let rows = try connection.query("SELECT * FROM t;")
        XCTAssertEqual(rows.count, 0)
    }

    func test_open_freshDatabase_endsUpAtLatestUserVersion() throws {
        let connection = try makeConnection()
        XCTAssertEqual(try connection.userVersion, 4)
    }

    func test_open_freshDatabase_createsExpectedTables() throws {
        let connection = try makeConnection()
        let tables = try connection.query("SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name;")
            .compactMap { row -> String? in
                guard case let .text(name) = row["name"] else { return nil }
                return name
            }
        XCTAssertTrue(tables.contains("institutions"))
        XCTAssertTrue(tables.contains("accounts"))
        XCTAssertTrue(tables.contains("transactions"))
        XCTAssertTrue(tables.contains("profile_settings"))
        XCTAssertTrue(tables.contains("balance_history"))
        XCTAssertTrue(tables.contains("_myfin_meta"))
    }

    func test_reopeningAlreadyMigratedDatabase_isANoOp() throws {
        let url = tempDatabaseURL()
        let first = try DatabaseConnection.open(at: url, password: "pw")
        XCTAssertEqual(try first.userVersion, 4)
        first.close()

        let second = try DatabaseConnection.open(at: url, password: "pw")
        XCTAssertEqual(try second.userVersion, 4)
    }

    func test_open_freshDatabase_seedsSystemInstitutionCatalog() throws {
        let connection = try makeConnection()
        let rows = try connection.query("SELECT COUNT(*) AS c FROM institutions WHERE source = 'system';")
        guard case let .int(count) = rows[0]["c"] else { return XCTFail("expected int") }
        XCTAssertEqual(Int(count), SystemInstitutionCatalog.all.count)
    }

    func test_open_freshDatabase_seedsKnownEntryWithAliases() throws {
        let connection = try makeConnection()
        let rows = try connection.query("SELECT name, aliases, archived FROM institutions WHERE id = ?;", params: [.text("kz.halyk-bank")])
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0]["name"], .text("Halyk Bank"))
        XCTAssertEqual(rows[0]["archived"], .int(0))
    }

    func test_reopeningAlreadySeededDatabase_doesNotDuplicateRows() throws {
        let url = tempDatabaseURL()
        let first = try DatabaseConnection.open(at: url, password: "pw")
        first.close()
        let second = try DatabaseConnection.open(at: url, password: "pw")
        let rows = try second.query("SELECT COUNT(*) AS c FROM institutions WHERE source = 'system';")
        guard case let .int(count) = rows[0]["c"] else { return XCTFail("expected int") }
        XCTAssertEqual(Int(count), SystemInstitutionCatalog.all.count)
    }
}
