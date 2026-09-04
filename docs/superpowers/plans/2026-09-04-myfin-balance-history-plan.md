# Balance History for Accounts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Record a `balance_history` entry every time an account's balance actually changes (including its very first balance at creation), and show that history in a right-side inspector panel when an account row is clicked on the "Счета" (Accounts) page.

**Architecture:** A new `balance_history` SQL table (migration version 4) holds one row per recorded balance. `AccountService` writes to it inline (mirroring how it already writes to `transactions` inline) — unconditionally at account creation, conditionally at update (only when the balance actually changed) — and exposes a new read method. `AccountsListView` gains tap-to-select on each row and a native `.inspector` panel; a new `BalanceHistoryPanelView` renders the selected account's history newest-first with computed deltas.

**Tech Stack:** Swift 5.9, SwiftUI (macOS 14+ `.inspector` modifier), SQLCipher.swift, XCTest. Swift Package Manager project (no Xcode project file).

## Global Constraints

- This project (`/Users/yevgeniygolota/Documents/Projects/MyFinLocal` and its `MyFin/` subdirectory) is NOT a git repository — skip every "Commit" step in this plan entirely.
- Swift package root is `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin`; all file paths below are relative to that directory.
- `swift build` and `swift test` run directly via Bash in this session.
- No retention cap on `balance_history` rows — keep everything.
- No note/reason field on history entries — balance, date, and delta only.
- No change to `AccountFormView` — the history write is a side effect inside `AccountService`, invisible to the form.
- No change to the existing `transactions` table or its `opening_balance`-kind row — `balance_history` is a separate, independent table.
- Money handling: always `Decimal`, never `Double`/`Float`; balances stored as text via `AccountService.decimalString(_:)`, same as `accounts.opening_balance`.

---

### Task 1: `balance_history` schema migration + `BalanceHistoryEntry` model

**Files:**
- Modify: `Sources/MyFin/Services/DatabaseService.swift`
- Modify: `Sources/MyFin/Models/Account.swift`
- Modify: `Tests/MyFinTests/DatabaseServiceTests.swift`

**Interfaces:**
- Consumes: nothing new from other tasks.
- Produces: the `balance_history` table (columns `id TEXT PRIMARY KEY`, `account_id TEXT NOT NULL REFERENCES accounts(id)`, `balance TEXT NOT NULL`, `recorded_at TEXT NOT NULL`), and `struct BalanceHistoryEntry: Identifiable, Equatable { let id: String; let balance: Decimal; let recordedAt: Date }`. Task 2's `AccountService` inserts into this table and returns `[BalanceHistoryEntry]` from it.

- [ ] **Step 1: Write the failing tests**

Open `Tests/MyFinTests/DatabaseServiceTests.swift` and find these three existing tests:

```swift
    func test_open_freshDatabase_endsUpAtLatestUserVersion() throws {
        let connection = try makeConnection()
        XCTAssertEqual(try connection.userVersion, 3)
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
        let url = tempDatabaseURL()
        let first = try DatabaseConnection.open(at: url, password: "pw")
        XCTAssertEqual(try first.userVersion, 3)
        first.close()

        let second = try DatabaseConnection.open(at: url, password: "pw")
        XCTAssertEqual(try second.userVersion, 3)
    }
```

Replace with (bumping the expected version to 4, and asserting the new table exists):

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter DatabaseServiceTests`
Expected: FAIL — `test_open_freshDatabase_endsUpAtLatestUserVersion` and `test_reopeningAlreadyMigratedDatabase_isANoOp` fail because `userVersion` is still `3`; `test_open_freshDatabase_createsExpectedTables` fails because `balance_history` isn't in the table list yet.

- [ ] **Step 3: Add the migration step**

In `Sources/MyFin/Services/DatabaseService.swift`, find:

```swift
        MigrationStep(version: 3, statements: [])
    ]
```

Replace with:

```swift
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
```

`runMigrations()`'s `if step.version == 3 { try seedSystemInstitutions() }` branch needs no change — it only fires for version 3, and version 4 has no seed step.

- [ ] **Step 4: Add the `BalanceHistoryEntry` model**

In `Sources/MyFin/Models/Account.swift`, find:

```swift
enum AccountError: Error, Equatable {
    case institutionRequired
    case negativeBalance
    case tooManyDecimalDigits
    case institutionError(InstitutionError)
    case notFound
    case invalidCustomBankName
}
```

Replace with:

```swift
enum AccountError: Error, Equatable {
    case institutionRequired
    case negativeBalance
    case tooManyDecimalDigits
    case institutionError(InstitutionError)
    case notFound
    case invalidCustomBankName
}

struct BalanceHistoryEntry: Identifiable, Equatable {
    let id: String
    let balance: Decimal
    let recordedAt: Date
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter DatabaseServiceTests`
Expected: PASS

- [ ] **Step 6: Run full test suite to confirm no regression**

Run: `swift test`
Expected: all tests pass (156 total from before this feature — no new tests added yet in this task beyond the 3 modified ones, so still 156/156).

---

### Task 2: `AccountService` balance-history writes and read method

**Files:**
- Modify: `Sources/MyFin/Services/AccountService.swift`
- Test: `Tests/MyFinTests/AccountServiceTests.swift`

**Interfaces:**
- Consumes: the `balance_history` table and `BalanceHistoryEntry` model (from Task 1).
- Produces: `AccountService.balanceHistory(accountId: String) -> [BalanceHistoryEntry]`, ordered oldest → newest. `createAccount(...)` and `updateAccount(...)` keep their existing signatures unchanged — the history writes are internal side effects. Task 3's `BalanceHistoryPanelView` calls `balanceHistory(accountId:)`.

- [ ] **Step 1: Write the failing tests**

Open `Tests/MyFinTests/AccountServiceTests.swift` and add these test cases as new `func test_...` methods in the `AccountServiceTests` class (following the file's existing `makeServices()` pattern — place them after the existing tests, before the closing `}` of the class):

```swift
    func test_createAccount_withPositiveOpeningBalance_writesInitialBalanceHistoryEntry() throws {
        let (service, _, _) = try makeServices()
        let result = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .kzt, openingBalance: 500, name: "", balanceDate: nil
        )
        guard case .success(let account) = result else { return XCTFail("expected success") }

        let history = service.balanceHistory(accountId: account.id)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].balance, 500)
    }

    func test_createAccount_withZeroOpeningBalance_stillWritesInitialBalanceHistoryEntry() throws {
        let (service, _, _) = try makeServices()
        let result = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .kzt, openingBalance: 0, name: "", balanceDate: nil
        )
        guard case .success(let account) = result else { return XCTFail("expected success") }

        let history = service.balanceHistory(accountId: account.id)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].balance, 0)
    }

    func test_updateAccount_withChangedOpeningBalance_appendsBalanceHistoryEntry() throws {
        let (service, _, _) = try makeServices()
        let created = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .kzt, openingBalance: 100, name: "My Cash", balanceDate: nil
        )
        guard case .success(let account) = created else { return XCTFail("expected success") }

        let updated = service.updateAccount(
            id: account.id, name: account.name, country: account.country, type: account.type,
            currency: account.currency, institutionSelection: .none, openingBalance: 300
        )
        guard case .success = updated else { return XCTFail("expected success") }

        let history = service.balanceHistory(accountId: account.id)
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].balance, 100)
        XCTAssertEqual(history[1].balance, 300)
    }

    func test_updateAccount_withUnchangedOpeningBalance_writesNoNewBalanceHistoryEntry() throws {
        let (service, _, _) = try makeServices()
        let created = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .kzt, openingBalance: 100, name: "My Cash", balanceDate: nil
        )
        guard case .success(let account) = created else { return XCTFail("expected success") }

        let updated = service.updateAccount(
            id: account.id, name: "Renamed Cash", country: account.country, type: account.type,
            currency: account.currency, institutionSelection: .none, openingBalance: 100
        )
        guard case .success = updated else { return XCTFail("expected success") }

        let history = service.balanceHistory(accountId: account.id)
        XCTAssertEqual(history.count, 1)
    }

    func test_balanceHistory_returnsEntriesOldestToNewest() throws {
        let (service, _, _) = try makeServices()
        let created = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .kzt, openingBalance: 100, name: "My Cash", balanceDate: nil
        )
        guard case .success(let account) = created else { return XCTFail("expected success") }

        _ = service.updateAccount(
            id: account.id, name: account.name, country: account.country, type: account.type,
            currency: account.currency, institutionSelection: .none, openingBalance: 200
        )
        _ = service.updateAccount(
            id: account.id, name: account.name, country: account.country, type: account.type,
            currency: account.currency, institutionSelection: .none, openingBalance: 50
        )

        let history = service.balanceHistory(accountId: account.id)
        XCTAssertEqual(history.map(\.balance), [100, 200, 50])
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter AccountServiceTests`
Expected: FAIL to compile — `value of type 'AccountService' has no member 'balanceHistory'`.

- [ ] **Step 3: Add the initial balance-history write to `createAccount`**

In `Sources/MyFin/Services/AccountService.swift`, find:

```swift
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
```

Replace with:

```swift
                if openingBalance > 0 {
                    try connection.execute(
                        "INSERT INTO transactions (id, account_id, amount, date, kind, created_at) VALUES (?, ?, ?, ?, 'opening_balance', ?);",
                        params: [.text(UUID().uuidString), .text(id), .text(Self.decimalString(openingBalance)), .text(balanceDateString), .text(nowString)]
                    )
                }
                try connection.execute(
                    "INSERT INTO balance_history (id, account_id, balance, recorded_at) VALUES (?, ?, ?, ?);",
                    params: [.text(UUID().uuidString), .text(id), .text(Self.decimalString(openingBalance)), .text(nowString)]
                )
            }
        } catch {
            return .failure(.notFound)
        }
```

Note this new insert is unconditional (unlike the `transactions` insert right above it, which is skipped when `openingBalance == 0`) — the first `balance_history` entry must exist even for a $0 opening balance.

- [ ] **Step 4: Capture the pre-update balance in `updateAccount`**

In `Sources/MyFin/Services/AccountService.swift`, find:

```swift
    func updateAccount(
        id: String, name: String, country: Country, type: AccountType, currency: Currency,
        institutionSelection: InstitutionSelection, openingBalance: Decimal
    ) -> Result<Account, AccountError> {
        guard fetchAccount(id: id) != nil else { return .failure(.notFound) }
        guard openingBalance >= 0 else { return .failure(.negativeBalance) }
```

Replace with:

```swift
    func updateAccount(
        id: String, name: String, country: Country, type: AccountType, currency: Currency,
        institutionSelection: InstitutionSelection, openingBalance: Decimal
    ) -> Result<Account, AccountError> {
        guard let existingAccount = fetchAccount(id: id) else { return .failure(.notFound) }
        guard openingBalance >= 0 else { return .failure(.negativeBalance) }
```

- [ ] **Step 5: Write the conditional balance-history insert in `updateAccount`**

In `Sources/MyFin/Services/AccountService.swift`, find:

```swift
        let nowString = ISO8601DateFormatter().string(from: now())
        _ = try? connection.execute(
            "UPDATE accounts SET name = ?, country = ?, type = ?, currency = ?, institution_id = ?, opening_balance = ?, updated_at = ? WHERE id = ?;",
            params: [
                .text(name), .text(country.rawValue), .text(type.rawValue), .text(currency.rawValue),
                institutionId.map(SQLValue.text) ?? .null, .text(Self.decimalString(openingBalance)), .text(nowString), .text(id)
            ]
        )
        guard let updated = fetchAccount(id: id) else { return .failure(.notFound) }
        return .success(updated)
    }

    func archiveAccount(id: String) -> Result<Account, AccountError> {
```

Replace with:

```swift
        let nowString = ISO8601DateFormatter().string(from: now())
        _ = try? connection.execute(
            "UPDATE accounts SET name = ?, country = ?, type = ?, currency = ?, institution_id = ?, opening_balance = ?, updated_at = ? WHERE id = ?;",
            params: [
                .text(name), .text(country.rawValue), .text(type.rawValue), .text(currency.rawValue),
                institutionId.map(SQLValue.text) ?? .null, .text(Self.decimalString(openingBalance)), .text(nowString), .text(id)
            ]
        )
        if openingBalance != existingAccount.openingBalance {
            try? connection.execute(
                "INSERT INTO balance_history (id, account_id, balance, recorded_at) VALUES (?, ?, ?, ?);",
                params: [.text(UUID().uuidString), .text(id), .text(Self.decimalString(openingBalance)), .text(nowString)]
            )
        }
        guard let updated = fetchAccount(id: id) else { return .failure(.notFound) }
        return .success(updated)
    }

    func archiveAccount(id: String) -> Result<Account, AccountError> {
```

- [ ] **Step 6: Add the `balanceHistory(accountId:)` read method**

In `Sources/MyFin/Services/AccountService.swift`, find:

```swift
    func listAccounts(includeArchived: Bool) -> [Account] {
        let sql = includeArchived
            ? "SELECT * FROM accounts ORDER BY created_at ASC;"
            : "SELECT * FROM accounts WHERE archived = 0 ORDER BY created_at ASC;"
        let rows = (try? connection.query(sql)) ?? []
        return rows.compactMap(Self.rowToAccount)
    }
```

Replace with:

```swift
    func listAccounts(includeArchived: Bool) -> [Account] {
        let sql = includeArchived
            ? "SELECT * FROM accounts ORDER BY created_at ASC;"
            : "SELECT * FROM accounts WHERE archived = 0 ORDER BY created_at ASC;"
        let rows = (try? connection.query(sql)) ?? []
        return rows.compactMap(Self.rowToAccount)
    }

    func balanceHistory(accountId: String) -> [BalanceHistoryEntry] {
        let rows = (try? connection.query(
            "SELECT * FROM balance_history WHERE account_id = ? ORDER BY recorded_at ASC;",
            params: [.text(accountId)]
        )) ?? []
        return rows.compactMap(Self.rowToBalanceHistoryEntry)
    }

    static func rowToBalanceHistoryEntry(_ row: [String: SQLValue]) -> BalanceHistoryEntry? {
        guard case let .text(id)? = row["id"],
              case let .text(balanceRaw)? = row["balance"], let balance = Decimal(string: balanceRaw),
              case let .text(recordedAtRaw)? = row["recorded_at"]
        else { return nil }

        let recordedAt = ISO8601DateFormatter().date(from: recordedAtRaw) ?? Date()
        return BalanceHistoryEntry(id: id, balance: balance, recordedAt: recordedAt)
    }
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `swift test --filter AccountServiceTests`
Expected: PASS (all existing `AccountServiceTests` cases plus the 5 new ones).

- [ ] **Step 8: Run full test suite to confirm no regression**

Run: `swift test`
Expected: all tests pass (156 + 5 new = 161/161).

---

### Task 3: `AccountsListView` inspector panel + `BalanceHistoryPanelView`

**Files:**
- Modify: `Sources/MyFin/Views/AccountsListView.swift`
- Create: `Sources/MyFin/Views/BalanceHistoryPanelView.swift`

**Interfaces:**
- Consumes: `AccountService.balanceHistory(accountId:) -> [BalanceHistoryEntry]` and `BalanceHistoryEntry.balance: Decimal` / `.recordedAt: Date` (from Task 2), `NumberDisplayFormatter.format(_:preferences:)` (pre-existing, unchanged), `session.connection: DatabaseConnection?` (pre-existing).
- Produces: `BalanceHistoryPanelView.init(session: AppSession, account: Account)` — consumed only by `AccountsListView` in this same task.

- [ ] **Step 1: Add `onSelect` to `AccountRowView` and wire the row tap**

In `Sources/MyFin/Views/AccountsListView.swift`, find:

```swift
private struct AccountRowView: View {
    let account: Account
    let subtitle: String
    let numberFormatPreferences: NumberFormatPreferences
    let onEdit: () -> Void
    let onToggleArchive: () -> Void

    @EnvironmentObject var preferences: AppPreferences

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(account.name).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(NumberDisplayFormatter.format(account.openingBalance, preferences: numberFormatPreferences))
            Button(preferences.string(.editButton), action: onEdit)
            Button(account.archived ? preferences.string(.restoreButton) : preferences.string(.archiveButton), action: onToggleArchive)
        }
    }
}
```

Replace with:

```swift
private struct AccountRowView: View {
    let account: Account
    let subtitle: String
    let numberFormatPreferences: NumberFormatPreferences
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onToggleArchive: () -> Void

    @EnvironmentObject var preferences: AppPreferences

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(account.name).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }
            Spacer()
            Text(NumberDisplayFormatter.format(account.openingBalance, preferences: numberFormatPreferences))
            Button(preferences.string(.editButton), action: onEdit)
            Button(account.archived ? preferences.string(.restoreButton) : preferences.string(.archiveButton), action: onToggleArchive)
        }
    }
}
```

- [ ] **Step 2: Add `selectedAccount` state**

In `Sources/MyFin/Views/AccountsListView.swift`, find:

```swift
    @State private var showArchived = false
    @State private var showingCreate = false
    @State private var editingAccount: Account?
```

Replace with:

```swift
    @State private var showArchived = false
    @State private var showingCreate = false
    @State private var editingAccount: Account?
    @State private var selectedAccount: Account?
```

- [ ] **Step 3: Pass `onSelect` at the active-accounts section's `AccountRowView` call site**

In `Sources/MyFin/Views/AccountsListView.swift`, find (this is the active-accounts section, inside `Section(preferences.string(.activeAccountsSectionTitle))`):

```swift
                            ForEach(model.activeAccounts) { account in
                                AccountRowView(
                                    account: account,
                                    subtitle: accountSubtitle(for: account),
                                    numberFormatPreferences: session.numberFormatPreferences,
                                    onEdit: { editingAccount = account },
                                    onToggleArchive: { toggleArchive(account) }
                                )
                            }
```

Replace with:

```swift
                            ForEach(model.activeAccounts) { account in
                                AccountRowView(
                                    account: account,
                                    subtitle: accountSubtitle(for: account),
                                    numberFormatPreferences: session.numberFormatPreferences,
                                    onSelect: { selectedAccount = account },
                                    onEdit: { editingAccount = account },
                                    onToggleArchive: { toggleArchive(account) }
                                )
                            }
```

- [ ] **Step 4: Pass `onSelect` at the archived-accounts section's `AccountRowView` call site**

This second call site has different indentation (4 extra spaces) than the one in Step 3 — a separate edit is required. In `Sources/MyFin/Views/AccountsListView.swift`, find (this is the archived-accounts section, inside `Section(preferences.string(.archivedAccountsSectionTitle))`):

```swift
                                ForEach(archivedAccounts) { account in
                                    AccountRowView(
                                        account: account,
                                        subtitle: accountSubtitle(for: account),
                                        numberFormatPreferences: session.numberFormatPreferences,
                                        onEdit: { editingAccount = account },
                                        onToggleArchive: { toggleArchive(account) }
                                    )
                                }
```

Replace with:

```swift
                                ForEach(archivedAccounts) { account in
                                    AccountRowView(
                                        account: account,
                                        subtitle: accountSubtitle(for: account),
                                        numberFormatPreferences: session.numberFormatPreferences,
                                        onSelect: { selectedAccount = account },
                                        onEdit: { editingAccount = account },
                                        onToggleArchive: { toggleArchive(account) }
                                    )
                                }
```

- [ ] **Step 5: Add the `.inspector` modifier**

In `Sources/MyFin/Views/AccountsListView.swift`, find:

```swift
        .sheet(item: $editingAccount, onDismiss: { model.reload() }) { account in
            AccountFormView(session: session, existingAccount: account)
        }
    }

    private func toggleArchive(_ account: Account) {
```

Replace with:

```swift
        .sheet(item: $editingAccount, onDismiss: { model.reload() }) { account in
            AccountFormView(session: session, existingAccount: account)
        }
        .inspector(isPresented: Binding(
            get: { selectedAccount != nil },
            set: { if !$0 { selectedAccount = nil } }
        )) {
            if let account = selectedAccount {
                BalanceHistoryPanelView(session: session, account: account)
            }
        }
    }

    private func toggleArchive(_ account: Account) {
```

- [ ] **Step 6: Build to confirm `AccountsListView` compiles**

Run: `swift build`
Expected: FAILS with `cannot find 'BalanceHistoryPanelView' in scope` — this is expected until Step 7.

- [ ] **Step 7: Create `BalanceHistoryPanelView`**

Create `Sources/MyFin/Views/BalanceHistoryPanelView.swift`:

```swift
import SwiftUI

struct BalanceHistoryPanelView: View {
    @ObservedObject var session: AppSession
    let account: Account
    @EnvironmentObject var preferences: AppPreferences

    @State private var entries: [BalanceHistoryEntry] = []

    private var accountService: AccountService? {
        guard let connection = session.connection else { return nil }
        let institutions = InstitutionService(connection: connection)
        return AccountService(connection: connection, institutionService: institutions)
    }

    private var newestFirstEntries: [BalanceHistoryEntry] {
        entries.reversed()
    }

    var body: some View {
        List {
            ForEach(Array(newestFirstEntries.enumerated()), id: \.element.id) { index, entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(NumberDisplayFormatter.format(entry.balance, preferences: session.numberFormatPreferences))
                        .font(.headline)
                    HStack {
                        Text(entry.recordedAt, style: .date)
                        if let delta = delta(at: index) {
                            Text(deltaText(delta))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(account.name)
        .onAppear(perform: reload)
    }

    private func delta(at index: Int) -> Decimal? {
        guard index + 1 < newestFirstEntries.count else { return nil }
        return newestFirstEntries[index].balance - newestFirstEntries[index + 1].balance
    }

    private func deltaText(_ delta: Decimal) -> String {
        let formatted = NumberDisplayFormatter.format(delta, preferences: session.numberFormatPreferences)
        return delta >= 0 ? "+\(formatted)" : formatted
    }

    private func reload() {
        guard let service = accountService else { return }
        entries = service.balanceHistory(accountId: account.id)
    }
}
```

- [ ] **Step 8: Build to confirm both files compile**

Run: `swift build`
Expected: builds cleanly.

- [ ] **Step 9: Run full test suite to confirm no regression**

Run: `swift test`
Expected: 161/161 passing (no new tests in this task — consistent with this codebase's zero View-level XCTest coverage; `AccountService.balanceHistory(accountId:)` itself already has coverage from Task 2).

- [ ] **Step 10: Manual verification in the running app**

Run: `swift run` (this step needs the human).

Walk through:
1. Go to "Счета". Click on an account's name/subtitle area (not the Edit/Archive buttons) — confirm a right-side inspector panel opens showing that account's balance history.
2. Confirm the first entry (oldest, at the bottom of the newest-first list) shows the account's original balance with no delta.
3. Edit the account and change its balance. Confirm a new entry appears at the top of the panel with a delta showing the change (e.g. `+500` or `-200`).
4. Edit the account again but change only the name (not the balance). Confirm no new history entry was added.
5. Click a different account row — confirm the panel updates to show that account's own history.
6. Click the Edit or Archive/Restore buttons on a row — confirm they still work as before and do not also open the panel.

---

## Self-Review Notes

- **Spec coverage:** `balance_history` table + migration version 4 (Task 1) ✓; `BalanceHistoryEntry` model (Task 1) ✓; `createAccount` always writes an initial entry, even at $0 (Task 2) ✓; `updateAccount` writes only on an actual balance change (Task 2) ✓; `balanceHistory(accountId:)` read method, oldest → newest (Task 2) ✓; row-tap → `.inspector` panel, newest-first with delta (Task 3) ✓; `AccountServiceTests` coverage for all of the above (Task 2) ✓; no View-level tests (matches spec) ✓; existing `DatabaseServiceTests` updated for the version bump so they don't regress (Task 1) ✓.
- **Placeholder scan:** none found — every step has literal before/after code.
- **Type consistency:** `BalanceHistoryEntry(id: String, balance: Decimal, recordedAt: Date)` (Task 1) matches every later reference — `rowToBalanceHistoryEntry` (Task 2) constructs it with those exact labels, `balanceHistory(accountId:) -> [BalanceHistoryEntry]` (Task 2) matches its two consumers (`AccountServiceTests` in Task 2, `BalanceHistoryPanelView.reload()` in Task 3); `AccountRowView`'s new `onSelect: () -> Void` (Task 3, Step 1) matches both of its call sites (Task 3, Steps 3 and 4); `BalanceHistoryPanelView.init(session:account:)` (Task 3, Step 7) matches its one call site (Task 3, Step 5).
