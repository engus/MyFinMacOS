# MyFin Accounts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give MyFin its first real domain feature — Accounts (debit cards, deposits, bank accounts, cash) — backed by a migrated per-profile SQLite schema, with full SwiftUI screens, a Dashboard total, a base-currency setting, and a one-time Onboarding placeholder.

**Architecture:** Add a small raw-SQL helper layer + migration runner to the existing `DatabaseConnection` (no ORM, matches project style). Layer `InstitutionService` → `AccountService` → `DashboardService` on top, each operating on one profile's already-open `DatabaseConnection`. Wire new `AppSession` state (`.onboarding` screen, `hasCompletedOnboarding`) and new SwiftUI screens (`AccountsListView`, `AccountFormView`, `BankPickerView`, `OnboardingView`) on top of the existing sidebar/navigation shell.

**Tech Stack:** Swift 5.9, SwiftUI, SQLCipher.swift (raw C API via `sqlite3_*`), XCTest. No Xcode project — Swift Package Manager only, built/run/tested exclusively by the human partner in their own Terminal.

**Spec:** `docs/superpowers/specs/2026-09-01-myfin-accounts-design.md`

## Global Constraints

- **No git** — this project does not use git. Never run `git` commands; skip every "Commit" step below (left in the task template only where the plan format requires it, immediately followed by a note to skip it).
- **No macOS Swift toolchain available to whoever executes this plan in an automated/agentic way.** Every step that runs `swift build` / `swift test` / `swift run` must be handed to the human partner as an exact command, with expected output, and the executor must wait for pasted-back results before proceeding. Do not attempt to run these yourself.
- File edits happen against `$HOME/mnt/MyFinLocal/MyFin/...`, which is `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin/...` on the real machine.
- Money is `Decimal` in Swift, `TEXT` decimal strings in SQLite — **never** `REAL`/`Double`/`Float` for any monetary value, at any layer.
- Currencies are hardcoded to `USD` and `KZT` only. Exchange rate is hardcoded: `1 USD = 460.5 KZT`.
- Base currency is a per-profile *display-only* setting (stored in `profile_settings`, key `baseCurrency`) — it never changes how an account's own currency/balance is stored.
- `hasFinancialHistory` type/currency locking is explicitly OUT of scope for this iteration — `type` and `currency` stay freely editable on `updateAccount`.
- System institutions (`source = 'system'`) can never be renamed, archived, or otherwise mutated — every mutating `InstitutionService` call on one must fail with `.systemInstitutionIsReadOnly`.
- `.otherBank` is a pure UI/logic sentinel — it is never written to the `institutions` table.
- Deployment target rises from macOS 13 to macOS 14 (`.onKeyPress` requires it) — Task 1, first.
- Tests follow the project's existing style: temp-directory-backed `ProfileStore`/`DatabaseConnection`, XCTest, no mocking framework/library (hand-written fakes/protocols only, matching the existing `BiometricAuthenticating`/`DeviceAuthenticator` pattern).

---

## ⚠️ Blocking gap: system institution catalog data

Task 5 below (seeding the system institution catalog) needs the **full, verbatim list of institutions for all 4 countries (KZ, AE, RU, US)** from the original product prompt. Only a partial KZ list survived this session's context compaction:

```
kz.halyk-bank — Halyk Bank; aliases: Halyk, Народный банк
kz.kaspi-bank — Kaspi Bank; aliases: Kaspi, Kaspi.kz
kz.bank-centercredit — Bank CenterCredit; aliases: BCC, ЦентрКредит
kz.fortebank — ForteBank; aliases: Forte
kz.freedom-bank-kazakhstan — Freedom Bank Kazakhstan; aliases: Freedom, Фридом
kz.eurasian-bank — Eurasian Bank; aliases: Евразийский банк
kz.otbasy-bank — Otbasy Bank; aliases: Отбасы, ЖССБ
kz.alatau-city-bank — Alatau City Bank; aliases: Alatau, Jusan, Жусан
kz.bereke-bank — Bereke Bank; aliases: Bereke, Береке
kz.home-credit-bank-kazakhstan — Home Credit Bank ... (rest of this entry, the remaining KZ entries, and all of AE/RU/US are not recoverable from this session)
```

Per the spec's own instruction ("do not abbreviate or invent placeholder entries") and the plan-writing rule against placeholders, this task is written below with the schema/wiring complete but the actual catalog array left for the human partner to paste in from the original prompt (or wherever it was originally drafted) before Task 5 is executed. Everything else in this plan (Tasks 1-4, 6-17) is fully specified and can be executed independently of this gap.

---

### Task 1: Raise deployment target to macOS 14

**Files:**
- Modify: `Package.swift`

**Interfaces:** None — this task only changes the platform floor.

- [ ] **Step 1: Change the platform entry**

In `Package.swift`, change:
```swift
platforms: [
    .macOS(.v13)
],
```
to:
```swift
platforms: [
    .macOS(.v14)
],
```

- [ ] **Step 2: Verify the build still passes**

Hand to human partner. Run: `swift build`
Expected: Build succeeds with no errors (this is a pure floor change; nothing in the existing codebase uses anything removed between 13 and 14).

- [ ] **Step 3: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 2: SQL primitives on `DatabaseConnection`

**Files:**
- Modify: `Sources/MyFin/Services/DatabaseService.swift`
- Test: `Tests/MyFinTests/DatabaseServiceTests.swift`

**Interfaces:**
- Consumes: existing `DatabaseConnection.open(at:password:) throws -> DatabaseConnection`, existing private `handle: OpaquePointer?` (same file, so new methods can touch it directly).
- Produces (for all later tasks):
  - `enum SQLValue: Equatable { case text(String); case int(Int64); case null }`
  - `DatabaseConnection.execute(_ sql: String, params: [SQLValue] = []) throws`
  - `DatabaseConnection.query(_ sql: String, params: [SQLValue] = []) throws -> [[String: SQLValue]]`
  - `DatabaseConnection.withTransaction<T>(_ body: () throws -> T) throws -> T`
  - `DatabaseConnection.userVersion: Int32 { get throws }`
  - `DatabaseConnection.setUserVersion(_ version: Int32) throws`

- [ ] **Step 1: Write the failing tests**

Add to `Tests/MyFinTests/DatabaseServiceTests.swift`:

```swift
func test_executeAndQuery_roundTripsTextAndIntValues() throws {
    let connection = try makeConnection() // existing test helper that opens a temp DB
    try connection.execute("CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT, n INTEGER);")
    try connection.execute("INSERT INTO t (id, name, n) VALUES (?, ?, ?);", params: [.int(1), .text("hello"), .int(42)])
    let rows = try connection.query("SELECT id, name, n FROM t WHERE id = ?;", params: [.int(1)])
    XCTAssertEqual(rows.count, 1)
    XCTAssertEqual(rows[0]["name"], .text("hello"))
    XCTAssertEqual(rows[0]["n"], .int(42))
}

func test_userVersion_defaultsToZeroAndCanBeSet() throws {
    let connection = try makeConnection()
    let initial = try connection.userVersion
    XCTAssertEqual(initial, 0)
    try connection.setUserVersion(3)
    XCTAssertEqual(try connection.userVersion, 3)
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
```

If `makeConnection()` does not already exist as a shared test helper in this file, add it using the same temp-directory pattern as the existing tests in this file (open a `DatabaseConnection` at a temp file URL with a throwaway password).

- [ ] **Step 2: Run tests to verify they fail**

Hand to human partner. Run: `swift test --filter DatabaseServiceTests`
Expected: FAIL — `execute`/`query`/`withTransaction`/`userVersion`/`setUserVersion` not defined on `DatabaseConnection`.

- [ ] **Step 3: Implement the SQL primitives**

Add to `Sources/MyFin/Services/DatabaseService.swift` (same file, so these can see the existing `private var handle: OpaquePointer?`):

```swift
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
            try? execute("ROLLBACK;")
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
```

Note: `handle` is `private` inside the `DatabaseConnection` class declared earlier in this same file — Swift allows same-file extensions to see `private` members of a type declared in that file, so no access-level change is needed.

- [ ] **Step 4: Run tests to verify they pass**

Hand to human partner. Run: `swift test --filter DatabaseServiceTests`
Expected: PASS (all `DatabaseServiceTests`, including the 3 new ones).

- [ ] **Step 5: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 3: Migration runner + migrations 1 & 2 (schema only, no seed data)

**Files:**
- Modify: `Sources/MyFin/Services/DatabaseService.swift`
- Test: `Tests/MyFinTests/DatabaseServiceTests.swift`

**Interfaces:**
- Consumes: `SQLValue`, `execute`, `query`, `withTransaction`, `userVersion`, `setUserVersion` from Task 2.
- Produces: `DatabaseConnection.open(at:password:)` now leaves every profile database at `user_version == 2` with tables `_myfin_meta`, `institutions`, `accounts`, `transactions`, `profile_settings` created. No rows are seeded yet (that's Task 5).

- [ ] **Step 1: Write the failing tests**

Add to `Tests/MyFinTests/DatabaseServiceTests.swift`:

```swift
func test_open_freshDatabase_endsUpAtLatestUserVersion() throws {
    let connection = try makeConnection()
    XCTAssertEqual(try connection.userVersion, 2)
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
    XCTAssertTrue(tables.contains("_myfin_meta"))
}

func test_reopeningAlreadyMigratedDatabase_isANoOp() throws {
    let url = tempDatabaseURL() // existing/new helper returning a fresh temp file URL
    let first = try DatabaseConnection.open(at: url, password: "pw")
    XCTAssertEqual(try first.userVersion, 2)
    first.close()

    let second = try DatabaseConnection.open(at: url, password: "pw")
    XCTAssertEqual(try second.userVersion, 2)
    // No error means idempotent re-migration; a naive re-run of "CREATE TABLE"
    // without "IF NOT EXISTS" would throw here instead.
}
```

If `tempDatabaseURL()` doesn't already exist, add it: return a `URL` under a fresh `FileManager.default.temporaryDirectory` subpath, matching how existing tests in this file obtain their temp DB paths.

- [ ] **Step 2: Run tests to verify they fail**

Hand to human partner. Run: `swift test --filter DatabaseServiceTests`
Expected: FAIL — `userVersion` stays at whatever the old hardcoded `_myfin_meta` creation left it (0), and `institutions`/`accounts`/`transactions`/`profile_settings` don't exist.

- [ ] **Step 3: Implement the migration runner**

In `Sources/MyFin/Services/DatabaseService.swift`, replace the old hardcoded materialize block inside `open(at:password:)`:

```swift
// A brand-new SQLite file has no pages until the first write, so an
// empty database never actually materializes its encrypted header --
// a wrong password would trivially "succeed" against it. Force one
// write now so every profile's database is non-empty on disk from
// the moment it's created, making the header check above meaningful
// on every subsequent open.
let materializeResult = sqlite3_exec(handle, "CREATE TABLE IF NOT EXISTS _myfin_meta (id INTEGER PRIMARY KEY);", nil, nil, nil)
guard materializeResult == SQLITE_OK else {
    let message = String(cString: sqlite3_errmsg(handle))
    sqlite3_close_v2(handle)
    throw DatabaseError.openFailed(message)
}

return DatabaseConnection(handle: handle)
```

with:

```swift
let connection = DatabaseConnection(handle: handle)
do {
    try connection.runMigrations()
} catch {
    connection.close()
    throw error
}
return connection
```

Add the migration table and runner (same file, e.g. right after the `DatabaseConnection` class, or as an extension near the SQL primitives from Task 2):

```swift
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
        ])
    ]

    func runMigrations() throws {
        let current = try userVersion
        for step in DatabaseConnection.migrations where step.version > current {
            try withTransaction {
                for statement in step.statements {
                    try execute(statement)
                }
                try setUserVersion(step.version)
            }
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Hand to human partner. Run: `swift test --filter DatabaseServiceTests`
Expected: PASS (all `DatabaseServiceTests`).

- [ ] **Step 5: Run the full suite to check nothing else broke**

Hand to human partner. Run: `swift test`
Expected: PASS (all existing tests — this change alters `DatabaseConnection.open`'s internals but not its public error behavior).

- [ ] **Step 6: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 4: Domain models

**Files:**
- Create: `Sources/MyFin/Models/Country.swift`
- Create: `Sources/MyFin/Models/Currency.swift`
- Create: `Sources/MyFin/Models/AccountType.swift`
- Create: `Sources/MyFin/Models/Institution.swift`
- Create: `Sources/MyFin/Models/Account.swift`
- Test: `Tests/MyFinTests/InstitutionModelTests.swift`
- Test: `Tests/MyFinTests/AccountModelTests.swift`

**Interfaces:**
- Produces (for all Institutions/Accounts tasks below):
  - `enum Country: String, Codable, CaseIterable, Equatable { case kz = "KZ", ae = "AE", ru = "RU", us = "US" }`, with `var displayName: String`.
  - `enum Currency: String, Codable, CaseIterable, Equatable { case usd = "USD", kzt = "KZT" }`.
  - `enum AccountType: String, Codable, CaseIterable, Equatable { case debitCard = "debit_card", deposit, bankAccount = "bank_account", cash }`, with `var displayName: String`.
  - `enum InstitutionSource: String, Codable, Equatable { case system, custom }`.
  - `struct Institution: Identifiable, Equatable { let id: String; let source: InstitutionSource; var country: Country; var name: String; let aliases: [String]; var archived: Bool; let createdAt: Date; var updatedAt: Date }`.
  - `enum InstitutionPickerItem: Identifiable, Equatable { case institution(Institution); case otherBank }` with `var id: String`.
  - `enum InstitutionError: Error, Equatable { case systemInstitutionIsReadOnly; case inUse; case conflictWithArchived(Institution); case notFound; case invalidName }`.
  - `enum InstitutionSelection: Equatable { case existing(id: String); case none; case newCustom(name: String) }`.
  - `struct Account: Identifiable, Equatable { let id: String; var name: String; var country: Country; var type: AccountType; var currency: Currency; var openingBalance: Decimal; var balanceDate: Date; var institutionId: String?; var archived: Bool; let createdAt: Date; var updatedAt: Date }`.
  - `enum AccountError: Error, Equatable { case institutionRequired; case negativeBalance; case tooManyDecimalDigits; case institutionError(InstitutionError); case notFound; case invalidCustomBankName }`.

- [ ] **Step 1: Write the failing tests**

Create `Tests/MyFinTests/InstitutionModelTests.swift`:

```swift
import XCTest
@testable import MyFin

final class InstitutionModelTests: XCTestCase {
    func test_institutionPickerItem_otherBank_hasStableId() {
        XCTAssertEqual(InstitutionPickerItem.otherBank.id, "__other_bank__")
    }

    func test_institutionPickerItem_institution_idMatchesInstitutionId() {
        let institution = Institution(
            id: "kz.halyk-bank", source: .system, country: .kz, name: "Halyk Bank",
            aliases: ["Halyk"], archived: false, createdAt: Date(), updatedAt: Date()
        )
        XCTAssertEqual(InstitutionPickerItem.institution(institution).id, "kz.halyk-bank")
    }

    func test_country_allCasesCoverExpectedFour() {
        XCTAssertEqual(Set(Country.allCases), [.kz, .ae, .ru, .us])
    }
}
```

Create `Tests/MyFinTests/AccountModelTests.swift`:

```swift
import XCTest
@testable import MyFin

final class AccountModelTests: XCTestCase {
    func test_accountType_allCasesCoverExpectedFour() {
        XCTAssertEqual(Set(AccountType.allCases), [.debitCard, .deposit, .bankAccount, .cash])
    }

    func test_currency_allCasesCoverExpectedTwo() {
        XCTAssertEqual(Set(Currency.allCases), [.usd, .kzt])
    }

    func test_accountType_rawValues_matchDatabaseConvention() {
        XCTAssertEqual(AccountType.debitCard.rawValue, "debit_card")
        XCTAssertEqual(AccountType.bankAccount.rawValue, "bank_account")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Hand to human partner. Run: `swift test --filter InstitutionModelTests`
Then: `swift test --filter AccountModelTests`
Expected: FAIL to compile — none of these types exist yet.

- [ ] **Step 3: Implement the models**

Create `Sources/MyFin/Models/Country.swift`:

```swift
import Foundation

enum Country: String, Codable, CaseIterable, Equatable {
    case kz = "KZ"
    case ae = "AE"
    case ru = "RU"
    case us = "US"

    var displayName: String {
        switch self {
        case .kz: return "Kazakhstan"
        case .ae: return "United Arab Emirates"
        case .ru: return "Russia"
        case .us: return "United States"
        }
    }
}
```

Create `Sources/MyFin/Models/Currency.swift`:

```swift
import Foundation

enum Currency: String, Codable, CaseIterable, Equatable {
    case usd = "USD"
    case kzt = "KZT"
}
```

Create `Sources/MyFin/Models/AccountType.swift`:

```swift
import Foundation

enum AccountType: String, Codable, CaseIterable, Equatable {
    case debitCard = "debit_card"
    case deposit = "deposit"
    case bankAccount = "bank_account"
    case cash = "cash"

    var displayName: String {
        switch self {
        case .debitCard: return "Debit card"
        case .deposit: return "Deposit"
        case .bankAccount: return "Bank account"
        case .cash: return "Cash"
        }
    }
}
```

Create `Sources/MyFin/Models/Institution.swift`:

```swift
import Foundation

enum InstitutionSource: String, Codable, Equatable {
    case system
    case custom
}

struct Institution: Identifiable, Equatable {
    let id: String
    let source: InstitutionSource
    var country: Country
    var name: String
    let aliases: [String]
    var archived: Bool
    let createdAt: Date
    var updatedAt: Date
}

enum InstitutionPickerItem: Identifiable, Equatable {
    case institution(Institution)
    case otherBank

    var id: String {
        switch self {
        case .institution(let institution): return institution.id
        case .otherBank: return "__other_bank__"
        }
    }
}

enum InstitutionError: Error, Equatable {
    case systemInstitutionIsReadOnly
    case inUse
    case conflictWithArchived(Institution)
    case notFound
    case invalidName
}

enum InstitutionSelection: Equatable {
    case existing(id: String)
    case none
    case newCustom(name: String)
}
```

Create `Sources/MyFin/Models/Account.swift`:

```swift
import Foundation

struct Account: Identifiable, Equatable {
    let id: String
    var name: String
    var country: Country
    var type: AccountType
    var currency: Currency
    var openingBalance: Decimal
    var balanceDate: Date
    var institutionId: String?
    var archived: Bool
    let createdAt: Date
    var updatedAt: Date
}

enum AccountError: Error, Equatable {
    case institutionRequired
    case negativeBalance
    case tooManyDecimalDigits
    case institutionError(InstitutionError)
    case notFound
    case invalidCustomBankName
}
```

- [ ] **Step 4: Run tests to verify they pass**

Hand to human partner. Run: `swift test --filter InstitutionModelTests`
Then: `swift test --filter AccountModelTests`
Expected: PASS.

- [ ] **Step 5: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 5: Seed system institution catalog (⚠️ blocked — needs full catalog data, see banner above)

**Files:**
- Create: `Sources/MyFin/Models/SystemInstitutionCatalog.swift`
- Modify: `Sources/MyFin/Services/DatabaseService.swift` (add migration 3)
- Test: `Tests/MyFinTests/DatabaseServiceTests.swift`

**Interfaces:**
- Consumes: `Institution`, `InstitutionSource`, `Country` (Task 4); `execute`/`withTransaction` (Task 2); migration runner (Task 3).
- Produces: `SystemInstitutionCatalog.all: [(id: String, country: Country, name: String, aliases: [String])]`; every profile database seeded with one `institutions` row per catalog entry (`source = 'system'`, `archived = 0`).

**Before starting this task:** get the full, verbatim original institution list (all 4 countries — KZ, AE, RU, US — stable IDs, display names, and aliases) from the human partner. Do not invent, guess, or abbreviate any entry.

- [ ] **Step 1: Fill in the catalog**

Create `Sources/MyFin/Models/SystemInstitutionCatalog.swift`:

```swift
import Foundation

enum SystemInstitutionCatalog {
    struct Entry {
        let id: String
        let country: Country
        let name: String
        let aliases: [String]
    }

    // PASTE THE FULL ORIGINAL LIST HERE, ONE Entry PER INSTITUTION, GROUPED BY COUNTRY.
    // Example row shape (from the surviving partial KZ list):
    // Entry(id: "kz.halyk-bank", country: .kz, name: "Halyk Bank", aliases: ["Halyk", "Народный банк"]),
    static let all: [Entry] = [
        // KZ — Kazakhstan
        Entry(id: "kz.halyk-bank", country: .kz, name: "Halyk Bank", aliases: ["Halyk", "Народный банк"]),
        Entry(id: "kz.kaspi-bank", country: .kz, name: "Kaspi Bank", aliases: ["Kaspi", "Kaspi.kz"]),
        Entry(id: "kz.bank-centercredit", country: .kz, name: "Bank CenterCredit", aliases: ["BCC", "ЦентрКредит"]),
        Entry(id: "kz.fortebank", country: .kz, name: "ForteBank", aliases: ["Forte"]),
        Entry(id: "kz.freedom-bank-kazakhstan", country: .kz, name: "Freedom Bank Kazakhstan", aliases: ["Freedom", "Фридом"]),
        Entry(id: "kz.eurasian-bank", country: .kz, name: "Eurasian Bank", aliases: ["Евразийский банк"]),
        Entry(id: "kz.otbasy-bank", country: .kz, name: "Otbasy Bank", aliases: ["Отбасы", "ЖССБ"]),
        Entry(id: "kz.alatau-city-bank", country: .kz, name: "Alatau City Bank", aliases: ["Alatau", "Jusan", "Жусан"]),
        Entry(id: "kz.bereke-bank", country: .kz, name: "Bereke Bank", aliases: ["Bereke", "Береке"]),
        Entry(id: "kz.home-credit-bank-kazakhstan", country: .kz, name: "Home Credit Bank", aliases: []),
        // ... remaining KZ entries go here ...

        // AE — United Arab Emirates
        // ... entries go here ...

        // RU — Russia
        // ... entries go here ...

        // US — United States
        // ... entries go here ...
    ]
}
```

Fill in every `// ...` section with the real entries before continuing to Step 2. Do not proceed with a partial list — every institution row this migration inserts is permanent seed data in every profile database created from this point on.

- [ ] **Step 2: Write the failing tests**

Add to `Tests/MyFinTests/DatabaseServiceTests.swift`:

```swift
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
```

- [ ] **Step 3: Run tests to verify they fail**

Hand to human partner. Run: `swift test --filter DatabaseServiceTests`
Expected: FAIL — `institutions` table is empty (no migration 3 seeding yet).

- [ ] **Step 4: Implement migration 3 (seed insert)**

In `Sources/MyFin/Services/DatabaseService.swift`, add a third entry to the `migrations` array from Task 3:

```swift
MigrationStep(version: 3, statements: []) // placeholder — seeding needs per-row params, see below
```

Seeding needs bound parameters per row (aliases is a JSON array encoded as text), which the current `MigrationStep(statements: [String])` shape can't express. Change `runMigrations()` to special-case version 3 with a dedicated method instead of raw SQL strings:

```swift
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
```

And make sure migration 3's `statements` array is simply empty (all its work happens in `seedSystemInstitutions()`):

```swift
MigrationStep(version: 3, statements: [])
```

- [ ] **Step 5: Run tests to verify they pass**

Hand to human partner. Run: `swift test --filter DatabaseServiceTests`
Expected: PASS.

- [ ] **Step 6: Run the full suite**

Hand to human partner. Run: `swift test`
Expected: PASS.

- [ ] **Step 7: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 6: `InstitutionService` — listing and search

**Files:**
- Create: `Sources/MyFin/Services/InstitutionService.swift`
- Test: `Tests/MyFinTests/InstitutionServiceTests.swift`

**Interfaces:**
- Consumes: `DatabaseConnection` (`query`/`execute`), `Institution`, `InstitutionSource`, `InstitutionPickerItem`, `Country` (Task 4), seeded catalog (Task 5).
- Produces:
  - `final class InstitutionService { init(connection: DatabaseConnection) }`
  - `func listInstitutions(country: Country) throws -> [InstitutionPickerItem]`
  - `func search(query: String, in country: Country) throws -> [InstitutionPickerItem]`
  - `private func rowToInstitution(_ row: [String: SQLValue]) -> Institution?` (internal helper reused by later steps)

- [ ] **Step 1: Write the failing tests**

Create `Tests/MyFinTests/InstitutionServiceTests.swift`:

```swift
import XCTest
@testable import MyFin

final class InstitutionServiceTests: XCTestCase {
    private func makeService() throws -> (InstitutionService, DatabaseConnection) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        let connection = try DatabaseConnection.open(at: url, password: "pw")
        return (InstitutionService(connection: connection), connection)
    }

    func test_listInstitutions_kz_includesSystemBanksAndEndsWithOtherBank() throws {
        let (service, _) = try makeService()
        let items = try service.listInstitutions(country: .kz)
        XCTAssertEqual(items.last, .otherBank)
        XCTAssertTrue(items.contains { if case .institution(let i) = $0 { return i.id == "kz.halyk-bank" }; return false })
    }

    func test_listInstitutions_us_doesNotIncludeKazakhstaniBanks() throws {
        let (service, _) = try makeService()
        let items = try service.listInstitutions(country: .us)
        XCTAssertFalse(items.contains { if case .institution(let i) = $0 { return i.id == "kz.halyk-bank" }; return false })
    }

    func test_search_matchesByNameCaseInsensitive() throws {
        let (service, _) = try makeService()
        let items = try service.search(query: "kaspi", in: .kz)
        XCTAssertTrue(items.contains { if case .institution(let i) = $0 { return i.id == "kz.kaspi-bank" }; return false })
    }

    func test_search_matchesByAliasCaseInsensitive() throws {
        let (service, _) = try makeService()
        let items = try service.search(query: "KASPI.KZ", in: .kz)
        XCTAssertTrue(items.contains { if case .institution(let i) = $0 { return i.id == "kz.kaspi-bank" }; return false })
    }

    func test_search_alwaysIncludesOtherBankRegardlessOfQuery() throws {
        let (service, _) = try makeService()
        let items = try service.search(query: "zzz-no-such-bank-zzz", in: .kz)
        XCTAssertEqual(items.last, .otherBank)
    }

    func test_listInstitutions_excludesArchivedCustomInstitutions() throws {
        let (service, connection) = try makeService()
        try connection.execute(
            "INSERT INTO institutions (id, source, country, name, aliases, archived, created_at, updated_at) VALUES (?, 'custom', 'KZ', 'My Bank', '[]', 1, '2026-01-01', '2026-01-01');",
            params: [.text("custom-1")]
        )
        let items = try service.listInstitutions(country: .kz)
        XCTAssertFalse(items.contains { if case .institution(let i) = $0 { return i.id == "custom-1" }; return false })
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Hand to human partner. Run: `swift test --filter InstitutionServiceTests`
Expected: FAIL to compile — `InstitutionService` doesn't exist yet.

- [ ] **Step 3: Implement `InstitutionService` listing and search**

Create `Sources/MyFin/Services/InstitutionService.swift`:

```swift
import Foundation

final class InstitutionService {
    private let connection: DatabaseConnection

    init(connection: DatabaseConnection) {
        self.connection = connection
    }

    func listInstitutions(country: Country) throws -> [InstitutionPickerItem] {
        let rows = try connection.query(
            "SELECT * FROM institutions WHERE country = ? AND archived = 0 ORDER BY source DESC, name ASC;",
            params: [.text(country.rawValue)]
        )
        let institutions = rows.compactMap(Self.rowToInstitution)
        return institutions.map(InstitutionPickerItem.institution) + [.otherBank]
    }

    func search(query: String, in country: Country) throws -> [InstitutionPickerItem] {
        let all = try listInstitutions(country: country)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        let lowered = trimmed.lowercased()
        return all.filter { item in
            switch item {
            case .otherBank:
                return true
            case .institution(let institution):
                if institution.name.lowercased().contains(lowered) { return true }
                return institution.aliases.contains { $0.lowercased().contains(lowered) }
            }
        }
    }

    static func rowToInstitution(_ row: [String: SQLValue]) -> Institution? {
        guard case let .text(id)? = row["id"],
              case let .text(sourceRaw)? = row["source"],
              let source = InstitutionSource(rawValue: sourceRaw),
              case let .text(countryRaw)? = row["country"],
              let country = Country(rawValue: countryRaw),
              case let .text(name)? = row["name"],
              case let .text(aliasesJSON)? = row["aliases"],
              case let .int(archivedInt)? = row["archived"],
              case let .text(createdAtRaw)? = row["created_at"],
              case let .text(updatedAtRaw)? = row["updated_at"]
        else { return nil }

        let aliases = (try? JSONDecoder().decode([String].self, from: Data(aliasesJSON.utf8))) ?? []
        let formatter = ISO8601DateFormatter()
        let createdAt = formatter.date(from: createdAtRaw) ?? Date()
        let updatedAt = formatter.date(from: updatedAtRaw) ?? Date()

        return Institution(
            id: id, source: source, country: country, name: name, aliases: aliases,
            archived: archivedInt != 0, createdAt: createdAt, updatedAt: updatedAt
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Hand to human partner. Run: `swift test --filter InstitutionServiceTests`
Expected: PASS.

- [ ] **Step 5: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 7: `InstitutionService` — custom institution create/rename/archive/restore/change-country

**Files:**
- Modify: `Sources/MyFin/Services/InstitutionService.swift`
- Test: `Tests/MyFinTests/InstitutionServiceTests.swift`

**Interfaces:**
- Consumes: `InstitutionService` (Task 6), `InstitutionError` (Task 4).
- Produces:
  - `func resolveOrCreateCustomInstitution(name: String, country: Country) -> Result<Institution, InstitutionError>`
  - `func renameCustomInstitution(id: String, name: String) -> Result<Institution, InstitutionError>`
  - `func archiveCustomInstitution(id: String) -> Result<Institution, InstitutionError>`
  - `func restoreCustomInstitution(id: String) -> Result<Institution, InstitutionError>`
  - `func changeCustomInstitutionCountry(id: String, country: Country) -> Result<Institution, InstitutionError>`

- [ ] **Step 1: Write the failing tests**

Add to `Tests/MyFinTests/InstitutionServiceTests.swift`:

```swift
func test_resolveOrCreateCustomInstitution_createsNewOnFirstCall() throws {
    let (service, _) = try makeService()
    let result = service.resolveOrCreateCustomInstitution(name: "My Local Bank", country: .kz)
    guard case .success(let institution) = result else { return XCTFail("expected success") }
    XCTAssertEqual(institution.name, "My Local Bank")
    XCTAssertEqual(institution.source, .custom)
    XCTAssertFalse(institution.archived)
}

func test_resolveOrCreateCustomInstitution_reusesExistingActiveMatch_caseAndWhitespaceInsensitive() throws {
    let (service, _) = try makeService()
    let first = service.resolveOrCreateCustomInstitution(name: "My Local Bank", country: .kz)
    guard case .success(let firstInstitution) = first else { return XCTFail("expected success") }
    let second = service.resolveOrCreateCustomInstitution(name: "  my local bank  ", country: .kz)
    guard case .success(let secondInstitution) = second else { return XCTFail("expected success") }
    XCTAssertEqual(firstInstitution.id, secondInstitution.id)
}

func test_resolveOrCreateCustomInstitution_archivedMatch_returnsConflict() throws {
    let (service, _) = try makeService()
    guard case .success(let institution) = service.resolveOrCreateCustomInstitution(name: "Old Bank", country: .kz) else {
        return XCTFail("expected success")
    }
    guard case .success = service.archiveCustomInstitution(id: institution.id) else {
        return XCTFail("expected archive to succeed")
    }
    let result = service.resolveOrCreateCustomInstitution(name: "Old Bank", country: .kz)
    guard case .failure(.conflictWithArchived(let conflicting)) = result else {
        return XCTFail("expected conflictWithArchived, got \(result)")
    }
    XCTAssertEqual(conflicting.id, institution.id)
}

func test_renameCustomInstitution_updatesName() throws {
    let (service, _) = try makeService()
    guard case .success(let institution) = service.resolveOrCreateCustomInstitution(name: "Old Name", country: .kz) else {
        return XCTFail("expected success")
    }
    let result = service.renameCustomInstitution(id: institution.id, name: "New Name")
    guard case .success(let renamed) = result else { return XCTFail("expected success") }
    XCTAssertEqual(renamed.name, "New Name")
}

func test_changeCustomInstitutionCountry_failsWhenInUse() throws {
    let (service, connection) = try makeService()
    guard case .success(let institution) = service.resolveOrCreateCustomInstitution(name: "Used Bank", country: .kz) else {
        return XCTFail("expected success")
    }
    try connection.execute(
        "INSERT INTO accounts (id, name, country, type, currency, opening_balance, balance_date, institution_id, archived, created_at, updated_at) VALUES ('acc-1', 'Acc', 'KZ', 'bank_account', 'USD', '0', '2026-01-01', ?, 0, '2026-01-01', '2026-01-01');",
        params: [.text(institution.id)]
    )
    let result = service.changeCustomInstitutionCountry(id: institution.id, country: .ae)
    XCTAssertEqual(result, .failure(.inUse))
}

func test_archiveCustomInstitution_doesNotBreakAccountsReferencingIt() throws {
    let (service, connection) = try makeService()
    guard case .success(let institution) = service.resolveOrCreateCustomInstitution(name: "Ref Bank", country: .kz) else {
        return XCTFail("expected success")
    }
    try connection.execute(
        "INSERT INTO accounts (id, name, country, type, currency, opening_balance, balance_date, institution_id, archived, created_at, updated_at) VALUES ('acc-2', 'Acc', 'KZ', 'bank_account', 'USD', '0', '2026-01-01', ?, 0, '2026-01-01', '2026-01-01');",
        params: [.text(institution.id)]
    )
    XCTAssertEqual(service.archiveCustomInstitution(id: institution.id).isSuccess, true)
    let rows = try connection.query("SELECT institution_id FROM accounts WHERE id = 'acc-2';")
    XCTAssertEqual(rows[0]["institution_id"], .text(institution.id))
}

func test_everyMutation_onSystemInstitution_failsWithReadOnly() throws {
    let (service, _) = try makeService()
    XCTAssertEqual(service.renameCustomInstitution(id: "kz.halyk-bank", name: "X"), .failure(.systemInstitutionIsReadOnly))
    XCTAssertEqual(service.archiveCustomInstitution(id: "kz.halyk-bank"), .failure(.systemInstitutionIsReadOnly))
    XCTAssertEqual(service.restoreCustomInstitution(id: "kz.halyk-bank"), .failure(.systemInstitutionIsReadOnly))
    XCTAssertEqual(service.changeCustomInstitutionCountry(id: "kz.halyk-bank", country: .ae), .failure(.systemInstitutionIsReadOnly))
}
```

Add a small `Result` convenience used above, in the same test file:

```swift
private extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Hand to human partner. Run: `swift test --filter InstitutionServiceTests`
Expected: FAIL to compile — the new methods don't exist yet.

- [ ] **Step 3: Implement the mutation methods**

Add to `Sources/MyFin/Services/InstitutionService.swift`, inside the `InstitutionService` class:

```swift
func resolveOrCreateCustomInstitution(name: String, country: Country) -> Result<Institution, InstitutionError> {
    let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else { return .failure(.invalidName) }

    let existingRows = (try? connection.query(
        "SELECT * FROM institutions WHERE source = 'custom' AND country = ? AND lower(trim(name)) = lower(trim(?));",
        params: [.text(country.rawValue), .text(normalized)]
    )) ?? []

    if let row = existingRows.first, let existing = Self.rowToInstitution(row) {
        if existing.archived {
            return .failure(.conflictWithArchived(existing))
        }
        return .success(existing)
    }

    let now = ISO8601DateFormatter().string(from: Date())
    let id = UUID().uuidString
    do {
        try connection.execute(
            "INSERT INTO institutions (id, source, country, name, aliases, archived, created_at, updated_at) VALUES (?, 'custom', ?, ?, '[]', 0, ?, ?);",
            params: [.text(id), .text(country.rawValue), .text(normalized), .text(now), .text(now)]
        )
    } catch {
        return .failure(.notFound)
    }
    return .success(Institution(id: id, source: .custom, country: country, name: normalized, aliases: [], archived: false, createdAt: Date(), updatedAt: Date()))
}

private func fetchInstitution(id: String) -> Institution? {
    guard let rows = try? connection.query("SELECT * FROM institutions WHERE id = ?;", params: [.text(id)]),
          let row = rows.first else { return nil }
    return Self.rowToInstitution(row)
}

private func requireCustom(id: String) -> Result<Institution, InstitutionError> {
    guard let institution = fetchInstitution(id: id) else { return .failure(.notFound) }
    guard institution.source == .custom else { return .failure(.systemInstitutionIsReadOnly) }
    return .success(institution)
}

func renameCustomInstitution(id: String, name: String) -> Result<Institution, InstitutionError> {
    switch requireCustom(id: id) {
    case .failure(let error): return .failure(error)
    case .success:
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.invalidName) }
        let now = ISO8601DateFormatter().string(from: Date())
        try? connection.execute("UPDATE institutions SET name = ?, updated_at = ? WHERE id = ?;", params: [.text(trimmed), .text(now), .text(id)])
        guard let updated = fetchInstitution(id: id) else { return .failure(.notFound) }
        return .success(updated)
    }
}

func archiveCustomInstitution(id: String) -> Result<Institution, InstitutionError> {
    switch requireCustom(id: id) {
    case .failure(let error): return .failure(error)
    case .success:
        let now = ISO8601DateFormatter().string(from: Date())
        try? connection.execute("UPDATE institutions SET archived = 1, updated_at = ? WHERE id = ?;", params: [.text(now), .text(id)])
        guard let updated = fetchInstitution(id: id) else { return .failure(.notFound) }
        return .success(updated)
    }
}

func restoreCustomInstitution(id: String) -> Result<Institution, InstitutionError> {
    switch requireCustom(id: id) {
    case .failure(let error): return .failure(error)
    case .success:
        let now = ISO8601DateFormatter().string(from: Date())
        try? connection.execute("UPDATE institutions SET archived = 0, updated_at = ? WHERE id = ?;", params: [.text(now), .text(id)])
        guard let updated = fetchInstitution(id: id) else { return .failure(.notFound) }
        return .success(updated)
    }
}

func changeCustomInstitutionCountry(id: String, country: Country) -> Result<Institution, InstitutionError> {
    switch requireCustom(id: id) {
    case .failure(let error): return .failure(error)
    case .success:
        let inUseRows = (try? connection.query("SELECT COUNT(*) AS c FROM accounts WHERE institution_id = ?;", params: [.text(id)])) ?? []
        if case let .int(count)? = inUseRows.first?["c"], count > 0 {
            return .failure(.inUse)
        }
        let now = ISO8601DateFormatter().string(from: Date())
        try? connection.execute("UPDATE institutions SET country = ?, updated_at = ? WHERE id = ?;", params: [.text(country.rawValue), .text(now), .text(id)])
        guard let updated = fetchInstitution(id: id) else { return .failure(.notFound) }
        return .success(updated)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Hand to human partner. Run: `swift test --filter InstitutionServiceTests`
Expected: PASS.

- [ ] **Step 5: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 8: `AccountService` — `createAccount`

**Files:**
- Create: `Sources/MyFin/Services/AccountService.swift`
- Test: `Tests/MyFinTests/AccountServiceTests.swift`

**Interfaces:**
- Consumes: `DatabaseConnection`, `InstitutionService` (Tasks 6-7), `Account`, `AccountError`, `AccountType`, `Currency`, `Country`, `InstitutionSelection` (Task 4).
- Produces:
  - `final class AccountService { init(connection: DatabaseConnection, institutionService: InstitutionService, now: @escaping () -> Date = Date.init) }`
  - `func createAccount(country: Country, type: AccountType, institutionSelection: InstitutionSelection, currency: Currency, openingBalance: Decimal, name: String, balanceDate: Date?) -> Result<Account, AccountError>`

- [ ] **Step 1: Write the failing tests**

Create `Tests/MyFinTests/AccountServiceTests.swift`:

```swift
import XCTest
@testable import MyFin

final class AccountServiceTests: XCTestCase {
    private func makeServices() throws -> (AccountService, InstitutionService, DatabaseConnection) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        let connection = try DatabaseConnection.open(at: url, password: "pw")
        let institutions = InstitutionService(connection: connection)
        let accounts = AccountService(connection: connection, institutionService: institutions)
        return (accounts, institutions, connection)
    }

    func test_createAccount_debitCard_withExistingInstitution_succeeds() throws {
        let (service, _, _) = try makeServices()
        let result = service.createAccount(
            country: .kz, type: .debitCard, institutionSelection: .existing(id: "kz.halyk-bank"),
            currency: .usd, openingBalance: 100, name: "", balanceDate: nil
        )
        guard case .success(let account) = result else { return XCTFail("expected success") }
        XCTAssertEqual(account.institutionId, "kz.halyk-bank")
        XCTAssertEqual(account.name, "Halyk Bank · Debit card")
    }

    func test_createAccount_cash_storesNoInstitutionAndAutoGeneratesName() throws {
        let (service, _, _) = try makeServices()
        let result = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .kzt, openingBalance: 0, name: "", balanceDate: nil
        )
        guard case .success(let account) = result else { return XCTFail("expected success") }
        XCTAssertNil(account.institutionId)
        XCTAssertEqual(account.name, "Cash · Kazakhstan")
    }

    func test_createAccount_nonCashType_withoutInstitution_fails() throws {
        let (service, _, _) = try makeServices()
        let result = service.createAccount(
            country: .kz, type: .bankAccount, institutionSelection: .none,
            currency: .usd, openingBalance: 0, name: "", balanceDate: nil
        )
        XCTAssertEqual(result, .failure(.institutionRequired))
    }

    func test_createAccount_negativeBalance_fails() throws {
        let (service, _, _) = try makeServices()
        let result = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .usd, openingBalance: -1, name: "", balanceDate: nil
        )
        XCTAssertEqual(result, .failure(.negativeBalance))
    }

    func test_createAccount_tooManyDecimalDigits_fails() throws {
        let (service, _, _) = try makeServices()
        let overPrecise = Decimal(string: "1.123456789")! // 9 digits after the point
        let result = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .usd, openingBalance: overPrecise, name: "", balanceDate: nil
        )
        XCTAssertEqual(result, .failure(.tooManyDecimalDigits))
    }

    func test_createAccount_positiveBalance_createsOneOpeningBalanceTransaction() throws {
        let (service, _, connection) = try makeServices()
        guard case .success(let account) = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .usd, openingBalance: 50, name: "", balanceDate: nil
        ) else { return XCTFail("expected success") }
        let rows = try connection.query("SELECT * FROM transactions WHERE account_id = ?;", params: [.text(account.id)])
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0]["kind"], .text("opening_balance"))
    }

    func test_createAccount_zeroBalance_createsNoTransaction() throws {
        let (service, _, connection) = try makeServices()
        guard case .success(let account) = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .usd, openingBalance: 0, name: "", balanceDate: nil
        ) else { return XCTFail("expected success") }
        let rows = try connection.query("SELECT * FROM transactions WHERE account_id = ?;", params: [.text(account.id)])
        XCTAssertEqual(rows.count, 0)
    }

    func test_createAccount_withOtherBank_resolvesOrCreatesCustomInstitutionAtomically() throws {
        let (service, institutions, _) = try makeServices()
        let result = service.createAccount(
            country: .kz, type: .bankAccount, institutionSelection: .newCustom(name: "My New Bank"),
            currency: .usd, openingBalance: 0, name: "", balanceDate: nil
        )
        guard case .success(let account) = result else { return XCTFail("expected success") }
        XCTAssertNotNil(account.institutionId)
        let list = try institutions.listInstitutions(country: .kz)
        XCTAssertTrue(list.contains { if case .institution(let i) = $0 { return i.id == account.institutionId }; return false })
    }

    func test_createAccount_explicitName_isNotOverwritten() throws {
        let (service, _, _) = try makeServices()
        let result = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .usd, openingBalance: 0, name: "My Wallet", balanceDate: nil
        )
        guard case .success(let account) = result else { return XCTFail("expected success") }
        XCTAssertEqual(account.name, "My Wallet")
    }

    func test_createAccount_omittedBalanceDate_defaultsToToday() throws {
        let (service, _, _) = try makeServices()
        let result = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .usd, openingBalance: 0, name: "", balanceDate: nil
        )
        guard case .success(let account) = result else { return XCTFail("expected success") }
        XCTAssertTrue(Calendar.current.isDateInToday(account.balanceDate))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Hand to human partner. Run: `swift test --filter AccountServiceTests`
Expected: FAIL to compile — `AccountService` doesn't exist yet.

- [ ] **Step 3: Implement `AccountService.createAccount`**

Create `Sources/MyFin/Services/AccountService.swift`:

```swift
import Foundation

final class AccountService {
    private let connection: DatabaseConnection
    private let institutionService: InstitutionService
    private let now: () -> Date

    init(connection: DatabaseConnection, institutionService: InstitutionService, now: @escaping () -> Date = Date.init) {
        self.connection = connection
        self.institutionService = institutionService
        self.now = now
    }

    func createAccount(
        country: Country,
        type: AccountType,
        institutionSelection: InstitutionSelection,
        currency: Currency,
        openingBalance: Decimal,
        name: String,
        balanceDate: Date?
    ) -> Result<Account, AccountError> {
        guard openingBalance >= 0 else { return .failure(.negativeBalance) }
        guard Self.decimalPlaces(of: openingBalance) <= 8 else { return .failure(.tooManyDecimalDigits) }

        var institutionId: String?
        var institutionDisplayName = ""

        if type == .cash {
            institutionId = nil
        } else {
            switch institutionSelection {
            case .none:
                return .failure(.institutionRequired)
            case .existing(let id):
                institutionId = id
                institutionDisplayName = InstitutionService.rowToInstitution(
                    (try? connection.query("SELECT * FROM institutions WHERE id = ?;", params: [.text(id)]))?.first ?? [:]
                )?.name ?? ""
            case .newCustom(let customName):
                switch institutionService.resolveOrCreateCustomInstitution(name: customName, country: country) {
                case .failure(let error): return .failure(.institutionError(error))
                case .success(let institution):
                    institutionId = institution.id
                    institutionDisplayName = institution.name
                }
            }
        }

        let resolvedDate = balanceDate ?? now()
        let id = UUID().uuidString
        let nowString = ISO8601DateFormatter().string(from: now())
        let dateFormatter = ISO8601DateFormatter()
        let balanceDateString = dateFormatter.string(from: resolvedDate)

        let finalName: String
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            finalName = name
        } else if type == .cash {
            finalName = "Cash · \(country.displayName)"
        } else {
            finalName = "\(institutionDisplayName) · \(type.displayName)"
        }

        do {
            try connection.withTransaction {
                try connection.execute(
                    """
                    INSERT INTO accounts (id, name, country, type, currency, opening_balance, balance_date, institution_id, archived, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?);
                    """,
                    params: [
                        .text(id), .text(finalName), .text(country.rawValue), .text(type.rawValue), .text(currency.rawValue),
                        .text(Self.decimalString(openingBalance)), .text(balanceDateString),
                        institutionId.map(SQLValue.text) ?? .null, .text(nowString), .text(nowString)
                    ]
                )
                if openingBalance > 0 {
                    try connection.execute(
                        "INSERT INTO transactions (id, account_id, amount, date, kind, created_at) VALUES (?, ?, ?, ?, 'opening_balance', ?);",
                        params: [.text(UUID().uuidString), .text(id), .text(Self.decimalString(openingBalance)), .text(balanceDateString), .text(nowString)]
                    )
                }
            }
        } catch {
            return .failure(.notFound)
        }

        return .success(Account(
            id: id, name: finalName, country: country, type: type, currency: currency,
            openingBalance: openingBalance, balanceDate: resolvedDate, institutionId: institutionId,
            archived: false, createdAt: now(), updatedAt: now()
        ))
    }

    static func decimalString(_ value: Decimal) -> String {
        var value = value
        var handler = NSDecimalNumberHandler(roundingMode: .plain, scale: 8, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
        var result = Decimal()
        NSDecimalRound(&result, &value, 8, .plain)
        return "\(result)"
    }

    static func decimalPlaces(of value: Decimal) -> Int {
        max(0, -value.exponent)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Hand to human partner. Run: `swift test --filter AccountServiceTests`
Expected: PASS.

- [ ] **Step 5: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 9: `AccountService` — `updateAccount`, `archiveAccount`/`restoreAccount`, `listAccounts`

**Files:**
- Modify: `Sources/MyFin/Services/AccountService.swift`
- Test: `Tests/MyFinTests/AccountServiceTests.swift`

**Interfaces:**
- Consumes: `AccountService` (Task 8).
- Produces:
  - `func updateAccount(id: String, name: String, country: Country, type: AccountType, currency: Currency, institutionSelection: InstitutionSelection) -> Result<Account, AccountError>`
  - `func archiveAccount(id: String) -> Result<Account, AccountError>`
  - `func restoreAccount(id: String) -> Result<Account, AccountError>`
  - `func listAccounts(includeArchived: Bool) -> [Account]`
  - `static func rowToAccount(_ row: [String: SQLValue]) -> Account?` (internal helper)

- [ ] **Step 1: Write the failing tests**

Add to `Tests/MyFinTests/AccountServiceTests.swift`:

```swift
func test_listAccounts_excludesArchivedByDefault() throws {
    let (service, _, _) = try makeServices()
    guard case .success(let account) = service.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 0, name: "A", balanceDate: nil) else {
        return XCTFail("expected success")
    }
    _ = service.archiveAccount(id: account.id)
    XCTAssertEqual(service.listAccounts(includeArchived: false).count, 0)
    XCTAssertEqual(service.listAccounts(includeArchived: true).count, 1)
}

func test_archiveThenRestore_roundTrips() throws {
    let (service, _, _) = try makeServices()
    guard case .success(let account) = service.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 0, name: "A", balanceDate: nil) else {
        return XCTFail("expected success")
    }
    guard case .success(let archived) = service.archiveAccount(id: account.id) else { return XCTFail("expected success") }
    XCTAssertTrue(archived.archived)
    guard case .success(let restored) = service.restoreAccount(id: account.id) else { return XCTFail("expected success") }
    XCTAssertFalse(restored.archived)
}

func test_updateAccount_changesNameCountryAndInstitution() throws {
    let (service, _, _) = try makeServices()
    guard case .success(let account) = service.createAccount(
        country: .kz, type: .bankAccount, institutionSelection: .existing(id: "kz.halyk-bank"),
        currency: .usd, openingBalance: 0, name: "A", balanceDate: nil
    ) else { return XCTFail("expected success") }

    let result = service.updateAccount(
        id: account.id, name: "B", country: .ae, type: .bankAccount, currency: .usd,
        institutionSelection: .existing(id: "kz.kaspi-bank")
    )
    guard case .success(let updated) = result else { return XCTFail("expected success") }
    XCTAssertEqual(updated.name, "B")
    XCTAssertEqual(updated.country, .ae)
    XCTAssertEqual(updated.institutionId, "kz.kaspi-bank")
}

func test_updateAccount_cashCountryChange_isJustAFieldUpdate() throws {
    let (service, _, _) = try makeServices()
    guard case .success(let account) = service.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 0, name: "A", balanceDate: nil) else {
        return XCTFail("expected success")
    }
    let result = service.updateAccount(id: account.id, name: "A", country: .ae, type: .cash, currency: .usd, institutionSelection: .none)
    guard case .success(let updated) = result else { return XCTFail("expected success") }
    XCTAssertEqual(updated.country, .ae)
    XCTAssertNil(updated.institutionId)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Hand to human partner. Run: `swift test --filter AccountServiceTests`
Expected: FAIL to compile — the new methods don't exist yet.

- [ ] **Step 3: Implement the remaining methods**

Add to `Sources/MyFin/Services/AccountService.swift`, inside the `AccountService` class:

```swift
func updateAccount(
    id: String, name: String, country: Country, type: AccountType, currency: Currency,
    institutionSelection: InstitutionSelection
) -> Result<Account, AccountError> {
    guard fetchAccount(id: id) != nil else { return .failure(.notFound) }

    var institutionId: String?
    if type != .cash {
        switch institutionSelection {
        case .none:
            return .failure(.institutionRequired)
        case .existing(let existingId):
            institutionId = existingId
        case .newCustom(let customName):
            switch institutionService.resolveOrCreateCustomInstitution(name: customName, country: country) {
            case .failure(let error): return .failure(.institutionError(error))
            case .success(let institution): institutionId = institution.id
            }
        }
    }

    let nowString = ISO8601DateFormatter().string(from: now())
    try? connection.execute(
        "UPDATE accounts SET name = ?, country = ?, type = ?, currency = ?, institution_id = ?, updated_at = ? WHERE id = ?;",
        params: [
            .text(name), .text(country.rawValue), .text(type.rawValue), .text(currency.rawValue),
            institutionId.map(SQLValue.text) ?? .null, .text(nowString), .text(id)
        ]
    )
    guard let updated = fetchAccount(id: id) else { return .failure(.notFound) }
    return .success(updated)
}

func archiveAccount(id: String) -> Result<Account, AccountError> {
    setArchived(true, id: id)
}

func restoreAccount(id: String) -> Result<Account, AccountError> {
    setArchived(false, id: id)
}

private func setArchived(_ archived: Bool, id: String) -> Result<Account, AccountError> {
    guard fetchAccount(id: id) != nil else { return .failure(.notFound) }
    let nowString = ISO8601DateFormatter().string(from: now())
    try? connection.execute(
        "UPDATE accounts SET archived = ?, updated_at = ? WHERE id = ?;",
        params: [.int(archived ? 1 : 0), .text(nowString), .text(id)]
    )
    guard let updated = fetchAccount(id: id) else { return .failure(.notFound) }
    return .success(updated)
}

func listAccounts(includeArchived: Bool) -> [Account] {
    let sql = includeArchived
        ? "SELECT * FROM accounts ORDER BY created_at ASC;"
        : "SELECT * FROM accounts WHERE archived = 0 ORDER BY created_at ASC;"
    let rows = (try? connection.query(sql)) ?? []
    return rows.compactMap(Self.rowToAccount)
}

private func fetchAccount(id: String) -> Account? {
    guard let rows = try? connection.query("SELECT * FROM accounts WHERE id = ?;", params: [.text(id)]),
          let row = rows.first else { return nil }
    return Self.rowToAccount(row)
}

static func rowToAccount(_ row: [String: SQLValue]) -> Account? {
    guard case let .text(id)? = row["id"],
          case let .text(name)? = row["name"],
          case let .text(countryRaw)? = row["country"], let country = Country(rawValue: countryRaw),
          case let .text(typeRaw)? = row["type"], let type = AccountType(rawValue: typeRaw),
          case let .text(currencyRaw)? = row["currency"], let currency = Currency(rawValue: currencyRaw),
          case let .text(openingBalanceRaw)? = row["opening_balance"], let openingBalance = Decimal(string: openingBalanceRaw),
          case let .text(balanceDateRaw)? = row["balance_date"],
          case let .int(archivedInt)? = row["archived"],
          case let .text(createdAtRaw)? = row["created_at"],
          case let .text(updatedAtRaw)? = row["updated_at"]
    else { return nil }

    let formatter = ISO8601DateFormatter()
    let balanceDate = formatter.date(from: balanceDateRaw) ?? Date()
    let createdAt = formatter.date(from: createdAtRaw) ?? Date()
    let updatedAt = formatter.date(from: updatedAtRaw) ?? Date()

    var institutionId: String?
    if case let .text(value)? = row["institution_id"] {
        institutionId = value
    }

    return Account(
        id: id, name: name, country: country, type: type, currency: currency,
        openingBalance: openingBalance, balanceDate: balanceDate, institutionId: institutionId,
        archived: archivedInt != 0, createdAt: createdAt, updatedAt: updatedAt
    )
}
```

- [ ] **Step 4: Run tests to verify they pass**

Hand to human partner. Run: `swift test --filter AccountServiceTests`
Expected: PASS.

- [ ] **Step 5: Run the full suite**

Hand to human partner. Run: `swift test`
Expected: PASS.

- [ ] **Step 6: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 10: `ExchangeRateProviding` + `HardcodedExchangeRateProvider`

**Files:**
- Create: `Sources/MyFin/Services/ExchangeRateProviding.swift`
- Test: `Tests/MyFinTests/ExchangeRateProvidingTests.swift`

**Interfaces:**
- Consumes: `Currency` (Task 4).
- Produces:
  - `protocol ExchangeRateProviding { func rate(from: Currency, to: Currency) -> Decimal }`
  - `struct HardcodedExchangeRateProvider: ExchangeRateProviding { static let usdToKzt: Decimal }`

- [ ] **Step 1: Write the failing tests**

Create `Tests/MyFinTests/ExchangeRateProvidingTests.swift`:

```swift
import XCTest
@testable import MyFin

final class ExchangeRateProvidingTests: XCTestCase {
    func test_sameCurrency_rateIsOne() {
        let provider = HardcodedExchangeRateProvider()
        XCTAssertEqual(provider.rate(from: .usd, to: .usd), 1)
        XCTAssertEqual(provider.rate(from: .kzt, to: .kzt), 1)
    }

    func test_usdToKzt_isFixedRate() {
        let provider = HardcodedExchangeRateProvider()
        XCTAssertEqual(provider.rate(from: .usd, to: .kzt), Decimal(string: "460.5"))
    }

    func test_kztToUsd_isReciprocal() {
        let provider = HardcodedExchangeRateProvider()
        let rate = provider.rate(from: .kzt, to: .usd)
        let roundTrip = rate * (Decimal(string: "460.5")!)
        XCTAssertEqual((roundTrip as NSDecimalNumber).doubleValue, 1.0, accuracy: 0.0001)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Hand to human partner. Run: `swift test --filter ExchangeRateProvidingTests`
Expected: FAIL to compile — neither type exists yet.

- [ ] **Step 3: Implement**

Create `Sources/MyFin/Services/ExchangeRateProviding.swift`:

```swift
import Foundation

protocol ExchangeRateProviding {
    func rate(from: Currency, to: Currency) -> Decimal
}

struct HardcodedExchangeRateProvider: ExchangeRateProviding {
    static let usdToKzt: Decimal = Decimal(string: "460.5")!

    func rate(from: Currency, to: Currency) -> Decimal {
        if from == to { return 1 }
        if from == .usd && to == .kzt { return Self.usdToKzt }
        if from == .kzt && to == .usd { return 1 / Self.usdToKzt }
        return 1
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Hand to human partner. Run: `swift test --filter ExchangeRateProvidingTests`
Expected: PASS.

- [ ] **Step 5: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 11: `DashboardService` — total balance & base currency setting

**Files:**
- Create: `Sources/MyFin/Services/DashboardService.swift`
- Test: `Tests/MyFinTests/DashboardServiceTests.swift`

**Interfaces:**
- Consumes: `AccountService` (Task 9), `ExchangeRateProviding` (Task 10), `DatabaseConnection` (Task 2).
- Produces:
  - `final class DashboardService { init(connection: DatabaseConnection, accountService: AccountService, exchangeRateProvider: ExchangeRateProviding) }`
  - `func totalBalance(displayCurrency: Currency) -> Decimal`
  - `func baseCurrency() -> Currency` (defaults to `.usd` if unset)
  - `func setBaseCurrency(_ currency: Currency) throws`

- [ ] **Step 1: Write the failing tests**

Create `Tests/MyFinTests/DashboardServiceTests.swift`:

```swift
import XCTest
@testable import MyFin

final class DashboardServiceTests: XCTestCase {
    private func makeServices() throws -> (DashboardService, AccountService, DatabaseConnection) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        let connection = try DatabaseConnection.open(at: url, password: "pw")
        let institutions = InstitutionService(connection: connection)
        let accounts = AccountService(connection: connection, institutionService: institutions)
        let dashboard = DashboardService(connection: connection, accountService: accounts, exchangeRateProvider: HardcodedExchangeRateProvider())
        return (dashboard, accounts, connection)
    }

    func test_totalBalance_sumsSingleCurrencyAccounts() throws {
        let (dashboard, accounts, _) = try makeServices()
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 100, name: "A", balanceDate: nil)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 50, name: "B", balanceDate: nil)
        XCTAssertEqual(dashboard.totalBalance(displayCurrency: .usd), 150)
    }

    func test_totalBalance_convertsMixedCurrencies() throws {
        let (dashboard, accounts, _) = try makeServices()
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 1, name: "A", balanceDate: nil)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .kzt, openingBalance: Decimal(string: "460.5")!, name: "B", balanceDate: nil)
        XCTAssertEqual(dashboard.totalBalance(displayCurrency: .usd), 2)
    }

    func test_totalBalance_excludesArchivedAccounts() throws {
        let (dashboard, accounts, _) = try makeServices()
        guard case .success(let account) = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 100, name: "A", balanceDate: nil) else {
            return XCTFail("expected success")
        }
        _ = accounts.archiveAccount(id: account.id)
        XCTAssertEqual(dashboard.totalBalance(displayCurrency: .usd), 0)
    }

    func test_baseCurrency_defaultsToUSD() throws {
        let (dashboard, _, _) = try makeServices()
        XCTAssertEqual(dashboard.baseCurrency(), .usd)
    }

    func test_setBaseCurrency_persistsAndIsReadableAfter() throws {
        let (dashboard, _, _) = try makeServices()
        try dashboard.setBaseCurrency(.kzt)
        XCTAssertEqual(dashboard.baseCurrency(), .kzt)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Hand to human partner. Run: `swift test --filter DashboardServiceTests`
Expected: FAIL to compile — `DashboardService` doesn't exist yet.

- [ ] **Step 3: Implement**

Create `Sources/MyFin/Services/DashboardService.swift`:

```swift
import Foundation

final class DashboardService {
    private let connection: DatabaseConnection
    private let accountService: AccountService
    private let exchangeRateProvider: ExchangeRateProviding

    init(connection: DatabaseConnection, accountService: AccountService, exchangeRateProvider: ExchangeRateProviding) {
        self.connection = connection
        self.accountService = accountService
        self.exchangeRateProvider = exchangeRateProvider
    }

    func totalBalance(displayCurrency: Currency) -> Decimal {
        accountService.listAccounts(includeArchived: false).reduce(Decimal(0)) { total, account in
            total + account.openingBalance * exchangeRateProvider.rate(from: account.currency, to: displayCurrency)
        }
    }

    func baseCurrency() -> Currency {
        let rows = (try? connection.query("SELECT value FROM profile_settings WHERE key = 'baseCurrency';")) ?? []
        guard case let .text(raw)? = rows.first?["value"], let currency = Currency(rawValue: raw) else {
            return .usd
        }
        return currency
    }

    func setBaseCurrency(_ currency: Currency) throws {
        try connection.execute(
            "INSERT INTO profile_settings (key, value) VALUES ('baseCurrency', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
            params: [.text(currency.rawValue)]
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Hand to human partner. Run: `swift test --filter DashboardServiceTests`
Expected: PASS.

- [ ] **Step 5: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 12: Onboarding session logic — `Profile.hasCompletedOnboarding`, `AppSession.Screen.onboarding`, routing

**Files:**
- Modify: `Sources/MyFin/Models/Profile.swift`
- Modify: `Sources/MyFin/AppSession.swift`
- Test: `Tests/MyFinTests/ProfileStoreTests.swift`
- Test: `Tests/MyFinTests/AppSessionTests.swift`

**Interfaces:**
- Consumes: existing `Profile`, `AppSession` (see current state in plan header/spec).
- Produces:
  - `Profile.hasCompletedOnboarding: Bool` (memberwise-init default `false`; decode-from-missing-key default `true`).
  - `AppSession.Screen.onboarding` case.
  - `AppSession.completeOnboarding()`.
  - `AppSession.connection` becomes readable (`private(set)`) so later UI tasks can build services from it.

- [ ] **Step 1: Write the failing tests**

Add to `Tests/MyFinTests/ProfileStoreTests.swift`:

```swift
func test_profile_decodedWithoutOnboardingKey_defaultsToTrue() throws {
    let json = """
    {"id":"\\(UUID().uuidString)","displayName":"Legacy","createdAt":0,"iconName":"person.crop.circle.fill","iconColor":"blue"}
    """.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let profile = try decoder.decode(Profile.self, from: json)
    XCTAssertTrue(profile.hasCompletedOnboarding)
}

func test_newlyConstructedProfile_defaultsOnboardingToFalse() {
    let profile = Profile(id: UUID(), displayName: "New", createdAt: Date())
    XCTAssertFalse(profile.hasCompletedOnboarding)
}
```

Add to `Tests/MyFinTests/AppSessionTests.swift`:

```swift
func test_createProfile_firstScreenIsOnboarding() {
    let session = makeSession() // existing test helper building a temp-backed AppSession
    session.createProfile(displayName: "Alice", password: "pw123456", remember: false)
    XCTAssertEqual(session.screen, .onboarding)
}

func test_completeOnboarding_persistsFlagAndTransitionsToMainShell() {
    let session = makeSession()
    session.createProfile(displayName: "Bob", password: "pw123456", remember: false)
    session.completeOnboarding()
    XCTAssertEqual(session.screen, .mainShell)
    XCTAssertTrue(session.unlockedProfile?.hasCompletedOnboarding ?? false)
}

func test_login_profileThatAlreadyCompletedOnboarding_goesStraightToMainShell() {
    let session = makeSession()
    session.createProfile(displayName: "Carol", password: "pw123456", remember: false)
    session.completeOnboarding()
    let profile = session.unlockedProfile!
    session.logOut()
    session.logIn(profile: profile, password: "pw123456")
    XCTAssertEqual(session.screen, .mainShell)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Hand to human partner. Run: `swift test --filter ProfileStoreTests`
Then: `swift test --filter AppSessionTests`
Expected: FAIL — `hasCompletedOnboarding`, `.onboarding`, `completeOnboarding()` don't exist yet.

- [ ] **Step 3: Implement**

In `Sources/MyFin/Models/Profile.swift`, add the field, update the memberwise initializer, and update decoding:

```swift
struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    var displayName: String
    let createdAt: Date
    var iconName: String
    var iconColor: String
    var hasCompletedOnboarding: Bool

    static let defaultIconName = "person.crop.circle.fill"
    static let defaultIconColor = "blue"

    init(
        id: UUID, displayName: String, createdAt: Date,
        iconName: String = Profile.defaultIconName,
        iconColor: String = Profile.defaultIconColor,
        hasCompletedOnboarding: Bool = false
    ) {
        self.id = id; self.displayName = displayName; self.createdAt = createdAt
        self.iconName = iconName; self.iconColor = iconColor
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    enum CodingKeys: String, CodingKey { case id, displayName, createdAt, iconName, iconColor, hasCompletedOnboarding }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? Profile.defaultIconName
        iconColor = try container.decodeIfPresent(String.self, forKey: .iconColor) ?? Profile.defaultIconColor
        // A profile.json written before this feature existed has no key here at
        // all -- that must decode to `true` (never show onboarding retroactively
        // to an existing profile). A newly-constructed Profile uses the
        // memberwise initializer above, whose default is `false`, not this path.
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? true
    }
}
```

In `Sources/MyFin/AppSession.swift`:

1. Add the new screen case:
```swift
enum Screen: Equatable {
    case profilePicker
    case mainShell
    case onboarding
}
```

2. Change `private var connection` to `private(set) var connection: DatabaseConnection?` so later UI tasks can read it.

3. In `createProfile`, replace `self.screen = .mainShell` with:
```swift
self.screen = profile.hasCompletedOnboarding ? .mainShell : .onboarding
```

4. In `logIn`, replace `self.screen = .mainShell` with the same line (using the local `profile` parameter, whose freshest on-disk value doesn't matter here since `hasCompletedOnboarding` is only ever flipped by `completeOnboarding()` below, which always updates both disk and `unlockedProfile` together).

5. In `logInWithRememberedPassword`, no change needed — it delegates to `logIn`, which now handles routing.

6. Add the new method:
```swift
func completeOnboarding() {
    guard var profile = unlockedProfile else { return }
    profile.hasCompletedOnboarding = true
    do {
        try profileStore.updateProfile(profile)
        unlockedProfile = profile
        screen = .mainShell
        refreshProfiles()
    } catch {
        errorMessage = "Не удалось обновить профиль: \(error.localizedDescription)"
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Hand to human partner. Run: `swift test --filter ProfileStoreTests`
Then: `swift test --filter AppSessionTests`
Expected: PASS.

- [ ] **Step 5: Run the full suite**

Hand to human partner. Run: `swift test`
Expected: PASS.

- [ ] **Step 6: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 13: `OnboardingView` + wiring into `MyFinApp`

**Files:**
- Create: `Sources/MyFin/Views/OnboardingView.swift`
- Modify: `Sources/MyFin/MyFinApp.swift`

**Interfaces:**
- Consumes: `AppSession.Screen.onboarding`, `AppSession.completeOnboarding()` (Task 12).
- Produces: `struct OnboardingView: View { let session: AppSession }`, routed into the app's top-level `Group`.

No unit tests for this task (SwiftUI views in this project are verified manually, matching the existing `ProfilePickerView`/`SettingsView` pattern — there is no UI test target). Verification is a manual run-through, Step 3 below.

- [ ] **Step 1: Create `OnboardingView`**

Create `Sources/MyFin/Views/OnboardingView.swift`:

```swift
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var session: AppSession

    var body: some View {
        VStack(spacing: 16) {
            Text("Онбординг")
                .font(.largeTitle.bold())
            Button("OK") {
                session.completeOnboarding()
            }
            .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 420, minHeight: 320)
    }
}
```

This is intentionally a placeholder (per spec: no account-creation form yet) — do not add anything beyond the label and button.

- [ ] **Step 2: Wire it into `MyFinApp`**

In `Sources/MyFin/MyFinApp.swift`, change the top-level `Group`:

```swift
Group {
    if session.screen == .profilePicker {
        ProfilePickerView(session: session)
    } else {
        MainShellView(session: session)
    }
}
```

to:

```swift
Group {
    switch session.screen {
    case .profilePicker:
        ProfilePickerView(session: session)
    case .onboarding:
        OnboardingView(session: session)
    case .mainShell:
        MainShellView(session: session)
    }
}
```

- [ ] **Step 3: Manual verification**

Hand to human partner. Run: `swift build && swift run`
Expected checklist:
1. Create a brand-new profile → immediately after creation, the Onboarding screen appears ("Онбординг" + "OK" button), not the main shell.
2. Click "OK" → the main shell (sidebar + Dashboard) appears.
3. Quit and relaunch, log back into that same profile → main shell appears directly (onboarding is not shown again).
4. Log into a profile created before this feature existed (if one is available) → main shell appears directly, never onboarding.

- [ ] **Step 4: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 14: `AccountsListView` — replaces the Accounts placeholder

**Files:**
- Create: `Sources/MyFin/Views/AccountsListView.swift`
- Modify: `Sources/MyFin/Views/MainShellView.swift`
- Modify: `Sources/MyFin/Localization.swift`

**Interfaces:**
- Consumes: `AccountService`, `InstitutionService`, `Account` (Tasks 6-9), `AppSession.connection` (Task 12).
- Produces: `struct AccountsListView: View { let session: AppSession }`, routed in place of `PlaceholderPageView` for `.accounts`. `AccountFormView` (Task 16) is presented from here as a sheet — this task only needs to reference it by name; Task 16 supplies its actual implementation, but AccountsListView should be written now assuming the signature `AccountFormView(session: session, existingAccount: Account?)` so Task 16 doesn't need to touch this file again.

No unit tests for this task (see Task 13's note on SwiftUI views in this project). Verification is manual, Step 4 below.

- [ ] **Step 1: Add localization keys**

In `Sources/MyFin/Localization.swift`, add to the `L10nKey` enum:
```swift
case showArchivedToggle
case createAccountButton
case editButton
case archiveButton
case restoreButton
case activeStatusLabel
case archivedStatusLabel
case noAccountsYet
```

Add the Russian and English entries to the `ru`/`en` dictionaries, following the file's existing pattern, e.g.:
```swift
.showArchivedToggle: "Показать архивные",
.createAccountButton: "Создать счёт",
.editButton: "Изменить",
.archiveButton: "Архивировать",
.restoreButton: "Восстановить",
.activeStatusLabel: "Активен",
.archivedStatusLabel: "Архивирован",
.noAccountsYet: "Пока нет счетов",
```
(and the English equivalents in the `en` dictionary: "Show archived", "Create account", "Edit", "Archive", "Restore", "Active", "Archived", "No accounts yet").

- [ ] **Step 2: Create `AccountsListView`**

Create `Sources/MyFin/Views/AccountsListView.swift`:

```swift
import SwiftUI

struct AccountsListView: View {
    @ObservedObject var session: AppSession
    @EnvironmentObject var preferences: AppPreferences

    @State private var showArchived = false
    @State private var accounts: [Account] = []
    @State private var showingCreate = false
    @State private var editingAccount: Account?

    private var accountService: AccountService? {
        guard let connection = session.connection else { return nil }
        return AccountService(connection: connection, institutionService: InstitutionService(connection: connection))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(preferences.string(.sidebarAccounts)).font(.largeTitle.bold())
                Spacer()
                Toggle(preferences.string(.showArchivedToggle), isOn: $showArchived)
                    .toggleStyle(.switch)
                    .onChange(of: showArchived) { _ in reload() }
                Button(preferences.string(.createAccountButton)) { showingCreate = true }
            }
            if accounts.isEmpty {
                Text(preferences.string(.noAccountsYet)).foregroundStyle(.secondary)
                Spacer()
            } else {
                List(accounts) { account in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(account.name).font(.headline)
                            Text(institutionOrCountryLabel(for: account)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(account.type.displayName)
                        Text(account.currency.rawValue)
                        Text("\(account.openingBalance)")
                        Text(account.archived ? preferences.string(.archivedStatusLabel) : preferences.string(.activeStatusLabel))
                            .foregroundStyle(account.archived ? .secondary : .green)
                        Button(preferences.string(.editButton)) { editingAccount = account }
                        Button(account.archived ? preferences.string(.restoreButton) : preferences.string(.archiveButton)) {
                            toggleArchive(account)
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { reload() }
        .sheet(isPresented: $showingCreate, onDismiss: reload) {
            AccountFormView(session: session, existingAccount: nil)
        }
        .sheet(item: $editingAccount, onDismiss: reload) { account in
            AccountFormView(session: session, existingAccount: account)
        }
    }

    private func reload() {
        accounts = accountService?.listAccounts(includeArchived: showArchived) ?? []
    }

    private func toggleArchive(_ account: Account) {
        guard let service = accountService else { return }
        if account.archived {
            _ = service.archiveAccount(id: account.id) // no-op guard, real call below
        }
        _ = account.archived ? service.restoreAccount(id: account.id) : service.archiveAccount(id: account.id)
        reload()
    }

    private func institutionOrCountryLabel(for account: Account) -> String {
        guard account.type != .cash, let institutionId = account.institutionId, let connection = session.connection else {
            return account.country.displayName
        }
        let rows = (try? connection.query("SELECT name FROM institutions WHERE id = ?;", params: [.text(institutionId)])) ?? []
        if case let .text(name)? = rows.first?["name"] {
            return name
        }
        return account.country.displayName
    }
}
```

Fix the accidental double-call in `toggleArchive` before moving on — it should be exactly one call:

```swift
private func toggleArchive(_ account: Account) {
    guard let service = accountService else { return }
    _ = account.archived ? service.restoreAccount(id: account.id) : service.archiveAccount(id: account.id)
    reload()
}
```

- [ ] **Step 3: Route it in `MainShellView`**

In `Sources/MyFin/Views/MainShellView.swift`, replace:
```swift
case .accounts:
    PlaceholderPageView(title: preferences.string(.sidebarAccounts), message: preferences.string(.accountsPlaceholder))
```
with:
```swift
case .accounts:
    AccountsListView(session: session)
```

- [ ] **Step 4: Manual verification**

Hand to human partner. Run: `swift build && swift run`
Expected checklist:
1. Open the "Аккаунты" sidebar item → an empty list with "Пока нет счетов" and a "Создать счёт" button appears (no crash).
2. Toggle "Показать архивные" on and off with no accounts yet → no crash, list stays empty.
3. (After Task 16 lands `AccountFormView`) creating, editing, archiving, and restoring an account all update this list correctly, and the archived toggle correctly includes/excludes archived rows.

- [ ] **Step 5: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 15: `BankPickerView` — searchable, keyboard-navigable institution combobox

**Files:**
- Create: `Sources/MyFin/Views/BankPickerView.swift`
- Modify: `Sources/MyFin/Localization.swift`

**Interfaces:**
- Consumes: `InstitutionService.search(query:in:)` (Task 6), `InstitutionPickerItem`, `InstitutionSelection` (Task 4). Requires macOS 14 (`.onKeyPress`, from Task 1).
- Produces:
  ```swift
  struct BankPickerView: View {
      let country: Country
      let institutionService: InstitutionService
      @Binding var selection: InstitutionSelection
  }
  ```
  Later consumed directly by `AccountFormView` (Task 16).

No unit tests for this task (see Task 13's note on SwiftUI views in this project). Verification is manual, Step 3 below.

- [ ] **Step 1: Add localization keys**

In `Sources/MyFin/Localization.swift`, add to `L10nKey`:
```swift
case otherBankLabel
case customBankNameField
case backToListButton
case bankFieldLabel
case cashFieldLabel
```
And to `ru`/`en`:
```swift
.otherBankLabel: "Другой банк",
.customBankNameField: "Название банка",
.backToListButton: "Назад к списку",
.bankFieldLabel: "Банк",
.cashFieldLabel: "Наличные",
```
(English: "Other bank", "Bank name", "Back to list", "Bank", "Cash").

- [ ] **Step 2: Create `BankPickerView`**

Create `Sources/MyFin/Views/BankPickerView.swift`:

```swift
import SwiftUI

struct BankPickerView: View {
    let country: Country
    let institutionService: InstitutionService
    @Binding var selection: InstitutionSelection
    @EnvironmentObject var preferences: AppPreferences

    @State private var searchText = ""
    @State private var items: [InstitutionPickerItem] = []
    @State private var highlightedIndex = 0
    @State private var isEnteringCustomName = false
    @State private var customName = ""
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isEnteringCustomName {
                TextField(preferences.string(.customBankNameField), text: $customName)
                    .onChange(of: customName) { newValue in
                        let trimmed = String(newValue.prefix(100))
                        customName = trimmed
                        selection = .newCustom(name: trimmed)
                    }
                Button(preferences.string(.backToListButton)) {
                    isEnteringCustomName = false
                    customName = ""
                    reload()
                }
            } else {
                TextField(preferences.string(.bankFieldLabel), text: $searchText)
                    .onChange(of: searchText) { _ in reload(); isExpanded = true }
                    .onTapGesture { isExpanded = true }
                    .onKeyPress(.downArrow) {
                        highlightedIndex = min(highlightedIndex + 1, max(items.count - 1, 0))
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        highlightedIndex = max(highlightedIndex - 1, 0)
                        return .handled
                    }
                    .onKeyPress(.return) {
                        selectHighlighted()
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        isExpanded = false
                        return .handled
                    }
                if isExpanded {
                    List(Array(items.enumerated()), id: \.element.id) { index, item in
                        Text(label(for: item))
                            .background(index == highlightedIndex ? Color.accentColor.opacity(0.2) : Color.clear)
                            .onTapGesture {
                                highlightedIndex = index
                                selectHighlighted()
                            }
                    }
                    .frame(maxHeight: 180)
                }
            }
        }
        .onAppear { reload() }
        .onChange(of: country) { _ in reload() }
    }

    private func reload() {
        items = (try? institutionService.search(query: searchText, in: country)) ?? []
        highlightedIndex = 0
    }

    private func selectHighlighted() {
        guard items.indices.contains(highlightedIndex) else { return }
        switch items[highlightedIndex] {
        case .otherBank:
            isEnteringCustomName = true
            isExpanded = false
        case .institution(let institution):
            selection = .existing(id: institution.id)
            searchText = institution.name
            isExpanded = false
        }
    }

    private func label(for item: InstitutionPickerItem) -> String {
        switch item {
        case .otherBank: return preferences.string(.otherBankLabel)
        case .institution(let institution): return institution.name
        }
    }
}
```

- [ ] **Step 3: Manual verification**

Hand to human partner. Run: `swift build && swift run`
(This view has no host screen yet — it will be exercised through `AccountFormView` in Task 16. For this task, confirm only that the project builds with the new file added — `swift build` succeeding is sufficient here. Full interactive verification (typing to filter, arrow keys, Enter, Escape, "Other bank" flow, empty custom name rejection) happens as part of Task 16's manual verification, once the picker is actually on screen.)
Expected: `swift build` succeeds with no errors or warnings about `BankPickerView`.

- [ ] **Step 4: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 16: `AccountFormView` — shared create/edit form

**Files:**
- Create: `Sources/MyFin/Views/AccountFormView.swift`
- Modify: `Sources/MyFin/Localization.swift`

**Interfaces:**
- Consumes: `AccountService`, `InstitutionService` (Tasks 6-9), `BankPickerView` (Task 15), `AppSession.connection` (Task 12).
- Produces: `struct AccountFormView: View { let session: AppSession; let existingAccount: Account? }` — already referenced by `AccountsListView` (Task 14).

No unit tests for this task (see Task 13's note on SwiftUI views in this project). Verification is manual, Step 3 below — this is also where Task 14 and Task 15's deferred manual checks get exercised end-to-end.

- [ ] **Step 1: Add localization keys**

In `Sources/MyFin/Localization.swift`, add to `L10nKey`:
```swift
case countryFieldLabel
case typeFieldLabel
case currencyFieldLabel
case balanceTodayFieldLabel
case accountNameFieldLabel
case specifyBalanceDateToggle
case balanceDateFieldLabel
case saveAccountButton
case invalidCustomBankNameMessage
case negativeBalanceMessage
case tooManyDecimalDigitsMessage
case institutionRequiredMessage
```
And to `ru`/`en`, e.g.:
```swift
.countryFieldLabel: "Страна",
.typeFieldLabel: "Тип",
.currencyFieldLabel: "Валюта",
.balanceTodayFieldLabel: "Баланс сегодня",
.accountNameFieldLabel: "Название счёта",
.specifyBalanceDateToggle: "Указать дату баланса",
.balanceDateFieldLabel: "Дата баланса",
.saveAccountButton: "Сохранить",
.invalidCustomBankNameMessage: "Введите название банка",
.negativeBalanceMessage: "Баланс не может быть отрицательным",
.tooManyDecimalDigitsMessage: "Слишком много знаков после запятой",
.institutionRequiredMessage: "Выберите банк",
```
(English equivalents: "Country", "Type", "Currency", "Balance today", "Account name", "Specify a balance date", "Balance date", "Save", "Enter a bank name", "Balance cannot be negative", "Too many decimal digits", "Select a bank".)

- [ ] **Step 2: Create `AccountFormView`**

Create `Sources/MyFin/Views/AccountFormView.swift`:

```swift
import SwiftUI

struct AccountFormView: View {
    let session: AppSession
    let existingAccount: Account?

    @EnvironmentObject var preferences: AppPreferences
    @Environment(\.dismiss) private var dismiss

    @State private var country: Country = .kz
    @State private var type: AccountType = .bankAccount
    @State private var institutionSelection: InstitutionSelection = .none
    @State private var currency: Currency = .usd
    @State private var balanceText: String = "0"
    @State private var name: String = ""
    @State private var specifyDate = false
    @State private var balanceDate = Date()
    @State private var errorMessage: String?

    private var institutionService: InstitutionService? {
        session.connection.map { InstitutionService(connection: $0) }
    }

    private var accountService: AccountService? {
        guard let connection = session.connection, let institutionService else { return nil }
        return AccountService(connection: connection, institutionService: institutionService)
    }

    var body: some View {
        Form {
            Picker(preferences.string(.countryFieldLabel), selection: $country) {
                ForEach(Country.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .onChange(of: country) { _ in institutionSelection = .none }

            Picker(preferences.string(.typeFieldLabel), selection: $type) {
                ForEach(AccountType.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }

            if type == .cash {
                Text(preferences.string(.cashFieldLabel)).foregroundStyle(.secondary)
            } else if let institutionService {
                BankPickerView(country: country, institutionService: institutionService, selection: $institutionSelection)
            }

            Picker(preferences.string(.currencyFieldLabel), selection: $currency) {
                ForEach(Currency.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }

            TextField(preferences.string(.balanceTodayFieldLabel), text: $balanceText)

            TextField(preferences.string(.accountNameFieldLabel), text: $name)

            Toggle(preferences.string(.specifyBalanceDateToggle), isOn: $specifyDate)
            if specifyDate {
                DatePicker(preferences.string(.balanceDateFieldLabel), selection: $balanceDate, displayedComponents: .date)
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }

            HStack {
                Button(preferences.string(.cancelButton)) { dismiss() }
                Button(preferences.string(.saveAccountButton)) { save() }
            }
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 420)
        .onAppear(perform: loadExistingAccount)
    }

    private func loadExistingAccount() {
        guard let account = existingAccount else { return }
        country = account.country
        type = account.type
        currency = account.currency
        balanceText = "\(account.openingBalance)"
        name = account.name
        if let institutionId = account.institutionId {
            institutionSelection = .existing(id: institutionId)
        }
        specifyDate = true
        balanceDate = account.balanceDate
    }

    private func save() {
        guard let accountService else { return }
        guard let balance = Decimal(string: balanceText) else {
            errorMessage = preferences.string(.negativeBalanceMessage)
            return
        }

        if case .newCustom(let customName) = institutionSelection, customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = preferences.string(.invalidCustomBankNameMessage)
            return
        }

        let result: Result<Account, AccountError>
        if let existingAccount {
            result = accountService.updateAccount(
                id: existingAccount.id, name: name, country: country, type: type, currency: currency,
                institutionSelection: type == .cash ? .none : institutionSelection
            )
        } else {
            result = accountService.createAccount(
                country: country, type: type,
                institutionSelection: type == .cash ? .none : institutionSelection,
                currency: currency, openingBalance: balance, name: name,
                balanceDate: specifyDate ? balanceDate : nil
            )
        }

        switch result {
        case .success:
            errorMessage = nil
            dismiss()
        case .failure(.negativeBalance):
            errorMessage = preferences.string(.negativeBalanceMessage)
        case .failure(.tooManyDecimalDigits):
            errorMessage = preferences.string(.tooManyDecimalDigitsMessage)
        case .failure(.institutionRequired):
            errorMessage = preferences.string(.institutionRequiredMessage)
        case .failure:
            errorMessage = preferences.string(.invalidCustomBankNameMessage)
        }
    }
}
```

- [ ] **Step 3: Manual verification**

Hand to human partner. Run: `swift build && swift run`
Expected checklist (exercises Tasks 14, 15, and 16 together):
1. From "Аккаунты", click "Создать счёт" → the form appears with fields in order Country → Type → Bank → Currency → Balance today → Account name → date toggle.
2. Pick Country = Kazakhstan, Type = Bank account → the Bank field shows a searchable list including Halyk Bank, Kaspi Bank, etc., ending with "Другой банк".
3. Type "kaspi" into the Bank field → the list filters live to Kaspi Bank.
4. Use ArrowDown/ArrowUp to move the highlight, Enter to select, Escape to close the dropdown — all work.
5. Select "Другой банк" → a required text field appears; leaving it empty and saving shows "Введите название банка"; typing a name and saving creates the account with a new custom institution.
6. Change Type to Cash → the Bank field becomes a disabled "Наличные" label; Country changes update the auto-generated name preview logic (auto-name applies once saved with an empty Account name field).
7. Enter a negative balance → save is rejected with "Баланс не может быть отрицательным".
8. Save a valid new account → it appears in the Accounts list with correct institution/country, type, currency, balance, and "Активен" status.
9. Click "Изменить" on that account, change its name, save → the list reflects the new name.
10. Click "Архивировать", then toggle "Показать архивные" → the archived account appears with "Архивирован" status; "Восстановить" flips it back.

- [ ] **Step 4: Run the full automated suite one more time**

Hand to human partner. Run: `swift test`
Expected: PASS (this task adds no new automated tests, but confirms nothing in Views broke compilation of the test target).

- [ ] **Step 5: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 17: Dashboard total balance + base-currency picker in Settings

**Files:**
- Modify: `Sources/MyFin/Views/MainShellView.swift`
- Create: `Sources/MyFin/Views/DashboardView.swift`
- Modify: `Sources/MyFin/Views/SettingsView.swift`
- Modify: `Sources/MyFin/Localization.swift`

**Interfaces:**
- Consumes: `DashboardService` (Task 11), `AppSession.connection` (Task 12).
- Produces: `struct DashboardView: View { let session: AppSession }`, routed in place of `PlaceholderPageView` for `.dashboard`; a new "Base currency" section in `SettingsView`.

No unit tests for this task (see Task 13's note on SwiftUI views in this project). Verification is manual, Step 4 below.

- [ ] **Step 1: Add localization keys**

In `Sources/MyFin/Localization.swift`, add to `L10nKey`:
```swift
case totalBalanceLabel
case baseCurrencySectionTitle
case baseCurrencyPickerLabel
```
And to `ru`/`en`:
```swift
.totalBalanceLabel: "Общий баланс",
.baseCurrencySectionTitle: "Базовая валюта",
.baseCurrencyPickerLabel: "Валюта отображения",
```
(English: "Total balance", "Base currency", "Display currency".)

- [ ] **Step 2: Create `DashboardView`**

Create `Sources/MyFin/Views/DashboardView.swift`:

```swift
import SwiftUI

struct DashboardView: View {
    @ObservedObject var session: AppSession
    @EnvironmentObject var preferences: AppPreferences

    @State private var total: Decimal = 0
    @State private var displayCurrency: Currency = .usd

    private var dashboardService: DashboardService? {
        guard let connection = session.connection else { return nil }
        let institutions = InstitutionService(connection: connection)
        let accounts = AccountService(connection: connection, institutionService: institutions)
        return DashboardService(connection: connection, accountService: accounts, exchangeRateProvider: HardcodedExchangeRateProvider())
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(preferences.string(.sidebarDashboard)).font(.largeTitle.bold())
            Text(preferences.string(.totalBalanceLabel)).foregroundStyle(.secondary)
            Text("\(total) \(displayCurrency.rawValue)").font(.system(size: 40, weight: .bold))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: reload)
    }

    private func reload() {
        guard let service = dashboardService else { return }
        displayCurrency = service.baseCurrency()
        total = service.totalBalance(displayCurrency: displayCurrency)
    }
}
```

- [ ] **Step 3: Route it and add the Settings picker**

In `Sources/MyFin/Views/MainShellView.swift`, replace:
```swift
case .dashboard:
    PlaceholderPageView(title: preferences.string(.sidebarDashboard), message: preferences.string(.dashboardPlaceholder))
```
with:
```swift
case .dashboard:
    DashboardView(session: session)
```

In `Sources/MyFin/Views/SettingsView.swift`, add a new section (placement: after the Appearance section is a reasonable spot, matching the file's existing section ordering) —

```swift
Section(preferences.string(.baseCurrencySectionTitle)) {
    Picker(preferences.string(.baseCurrencyPickerLabel), selection: $baseCurrency) {
        ForEach(Currency.allCases, id: \.self) { Text($0.rawValue).tag($0) }
    }
    .onChange(of: baseCurrency) { newValue in
        guard let connection = session.connection else { return }
        let institutions = InstitutionService(connection: connection)
        let accounts = AccountService(connection: connection, institutionService: institutions)
        let dashboard = DashboardService(connection: connection, accountService: accounts, exchangeRateProvider: HardcodedExchangeRateProvider())
        try? dashboard.setBaseCurrency(newValue)
    }
}
```

Add the backing state near `SettingsView`'s other `@State` properties:
```swift
@State private var baseCurrency: Currency = .usd
```

And initialize it wherever the view already loads existing state on appear (add to the existing `.onAppear` block, or add one if none exists that runs on first load):
```swift
if let connection = session.connection {
    let institutions = InstitutionService(connection: connection)
    let accounts = AccountService(connection: connection, institutionService: institutions)
    baseCurrency = DashboardService(connection: connection, accountService: accounts, exchangeRateProvider: HardcodedExchangeRateProvider()).baseCurrency()
}
```

- [ ] **Step 4: Manual verification**

Hand to human partner. Run: `swift build && swift run`
Expected checklist:
1. Open Dashboard with no accounts → shows "0 USD" (or whatever the current base currency is) without crashing.
2. Create a USD cash account with balance 100 and a KZT cash account with balance 460.5 → Dashboard total (base currency USD) shows "2" combined, matching the hardcoded 460.5 KZT = 1 USD rate.
3. In Settings, switch base currency to KZT → Dashboard total re-displays converted to KZT the next time Dashboard is opened.
4. Archive one of the two accounts → Dashboard total drops by that account's contribution.

- [ ] **Step 5: Run the full suite one final time**

Hand to human partner. Run: `swift test`
Expected: PASS — every test added across Tasks 1-17.

- [ ] **Step 6: Commit**

Skipped — this project does not use git (see Global Constraints).

---

## Plan self-review notes

- **Spec coverage:** every section of `2026-09-01-myfin-accounts-design.md` maps to at least one task — Data model & migrations → Tasks 2-3; System catalog → Task 5; Institutions → Tasks 6-7; Accounts → Tasks 8-9; Dashboard/base currency → Tasks 10-11, 17; Onboarding → Tasks 12-13; UI screens → Tasks 14-17. The two explicitly dropped acceptance criteria (`hasFinancialHistory` lock, identical Accounts/Onboarding form) have no task, matching the spec's Deviations section.
- **Placeholder scan:** the only intentional placeholder is Task 5's catalog data gap, called out explicitly at the top of this document and again at the start of Task 5, with instructions not to proceed without the real data — this is a data dependency being surfaced honestly, not a vague instruction.
- **Type consistency:** `InstitutionSelection`, `InstitutionPickerItem`, `Account`, `AccountError`, `InstitutionError`, `Country`, `AccountType`, `Currency` are all defined once in Task 4 and reused with identical names/cases through every later task; `AccountService.createAccount`/`updateAccount` signatures match what `AccountFormView` (Task 16) calls; `DashboardService`'s constructor signature matches every call site in Tasks 14, 16 (indirectly via `AccountsListView`'s pattern), and 17.
