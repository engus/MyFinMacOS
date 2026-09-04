# Sidebar Bank Grouping Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In the sidebar's "Счета" list, show one row per bank (accounts at the same institution summed together, converted to the profile's base currency) instead of one row per account, with cash accounts collapsed into a single "Наличные" row.

**Architecture:** Make `AppSession.baseCurrency` live-published, exactly like `numberFormatPreferences` already is, so the always-mounted sidebar never shows a stale currency. Add `AccountsListModel.groupedByInstitution(baseCurrency:)`, returning `[AccountGroup]` (id/label/total), reusing the exact rounding and exchange-rate logic `DashboardService.totalBalance` already uses. Migrate `DashboardView`/`SettingsView` off their own ad-hoc `baseCurrency` loads onto `session.baseCurrency`, then wire the sidebar's `DisclosureGroup` onto the new grouping method.

**Tech Stack:** Swift 5.9, SwiftUI, SQLCipher.swift, XCTest, Swift Package Manager (no Xcode project).

**Spec:** `docs/superpowers/specs/2026-09-04-myfin-sidebar-bank-grouping-design.md`

## Global Constraints

- **No git** in this project (neither `MyFinLocal/` nor `MyFinLocal/MyFin/` is a git repository) — never run `git` commands; every "Commit" step below is skipped, left in the template only where the plan format requires it.
- **Swift toolchain is available and verified working in this environment** — run every `swift build` / `swift test` step yourself, directly via Bash, from `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin`. Only the final manual look-at-the-running-app step (explicitly marked "Hand to human partner") needs the human.
- **Services never localize** — `AccountsListModel.groupedByInstitution` returns `label: ""` for the cash group (keyed by the public `AccountsListModel.cashGroupID` constant); only `MainShellView` (a view, which already holds `@EnvironmentObject var preferences: AppPreferences`) turns that into visible text, via the existing `.cashFieldLabel` key — no new localization key.
- All exchange-rate/summation arithmetic stays in `Decimal`, rounded to 8 places via `NSDecimalRound(..., 8, .plain)` — identical precision handling to `DashboardService.totalBalance`, never `Double`/`Float`.
- No new tests for `MainShellView`/`DashboardView`/`SettingsView` themselves — consistent with this codebase's existing convention of zero View-level XCTest coverage. Verified by `swift build` + `swift test` + a manual look at the running app.

## File Structure

- Modify: `Sources/MyFin/AppSession.swift` — `baseCurrency` published property + `updateBaseCurrency(_:)` (Task 1).
- Modify: `Tests/MyFinTests/AppSessionTests.swift` (Task 1).
- Modify: `Sources/MyFin/Services/AccountsListModel.swift` — `AccountGroup`, `cashGroupID`, `groupedByInstitution(baseCurrency:)` (Task 2).
- Modify: `Tests/MyFinTests/AccountsListModelTests.swift` (Task 2).
- Modify: `Sources/MyFin/Views/DashboardView.swift`, `Sources/MyFin/Views/SettingsView.swift` — read/write `session.baseCurrency` instead of an ad-hoc local load (Task 3).
- Modify: `Sources/MyFin/Views/MainShellView.swift` — sidebar wired onto `groupedByInstitution` (Task 4).

---

### Task 1: `AppSession.baseCurrency` — live, like `numberFormatPreferences`

**Files:**
- Modify: `Sources/MyFin/AppSession.swift`
- Test: `Tests/MyFinTests/AppSessionTests.swift`

**Interfaces:**
- Consumes: existing `DashboardService(connection:accountService:exchangeRateProvider:)`, `.baseCurrency()`, `.setBaseCurrency(_:) throws`, existing `InstitutionService(connection:)`, `AccountService(connection:institutionService:)`, `HardcodedExchangeRateProvider()`.
- Produces (for Tasks 3–4): `AppSession.baseCurrency: Currency` (published, read-only from outside), `AppSession.updateBaseCurrency(_ currency: Currency)`.

- [x] **Step 1: Write the failing test**

Add to `Tests/MyFinTests/AppSessionTests.swift`, inside `AppSessionTests`, right before the class's closing `}`:

```swift
    func test_updateBaseCurrency_publishesImmediatelyAndPersists() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)

        session.updateBaseCurrency(.kzt)
        XCTAssertEqual(session.baseCurrency, .kzt)

        let profile = session.profiles[0]
        session.logOut()
        session.logIn(profile: profile, password: "pw1")
        XCTAssertEqual(session.baseCurrency, .kzt)
    }
```

- [x] **Step 2: Run the test to verify it fails**

Run: `swift test --filter MyFinTests.AppSessionTests`
Expected: build failure — `AppSession` has no member `baseCurrency`/`updateBaseCurrency`.

- [x] **Step 3: Add the property and loading points**

In `Sources/MyFin/AppSession.swift`, add the published property next to `numberFormatPreferences`:

```swift
    @Published var screen: Screen = .profilePicker
    @Published var profiles: [Profile] = []
    @Published var errorMessage: String?
    @Published private(set) var numberFormatPreferences = NumberFormatPreferences()
    @Published private(set) var baseCurrency: Currency = .usd
```

In `createProfile(...)`, change:

```swift
            self.connection = connection
            self.unlockedProfile = profile
            self.numberFormatPreferences = NumberFormatPreferencesService(connection: connection).load()
            self.errorMessage = nil
            self.screen = profile.hasCompletedOnboarding ? .mainShell : .onboarding
            refreshProfiles()
```

to:

```swift
            self.connection = connection
            self.unlockedProfile = profile
            self.numberFormatPreferences = NumberFormatPreferencesService(connection: connection).load()
            let institutions = InstitutionService(connection: connection)
            let accountService = AccountService(connection: connection, institutionService: institutions)
            self.baseCurrency = DashboardService(connection: connection, accountService: accountService, exchangeRateProvider: HardcodedExchangeRateProvider()).baseCurrency()
            self.errorMessage = nil
            self.screen = profile.hasCompletedOnboarding ? .mainShell : .onboarding
            refreshProfiles()
```

In `logIn(...)`, change:

```swift
            let connection = try DatabaseConnection.open(at: profileStore.databaseURL(for: profile.id), password: password)
            self.connection = connection
            self.unlockedProfile = profile
            self.numberFormatPreferences = NumberFormatPreferencesService(connection: connection).load()
            self.errorMessage = nil
            self.screen = profile.hasCompletedOnboarding ? .mainShell : .onboarding
        } catch DatabaseError.wrongPassword {
```

to:

```swift
            let connection = try DatabaseConnection.open(at: profileStore.databaseURL(for: profile.id), password: password)
            self.connection = connection
            self.unlockedProfile = profile
            self.numberFormatPreferences = NumberFormatPreferencesService(connection: connection).load()
            let institutions = InstitutionService(connection: connection)
            let accountService = AccountService(connection: connection, institutionService: institutions)
            self.baseCurrency = DashboardService(connection: connection, accountService: accountService, exchangeRateProvider: HardcodedExchangeRateProvider()).baseCurrency()
            self.errorMessage = nil
            self.screen = profile.hasCompletedOnboarding ? .mainShell : .onboarding
        } catch DatabaseError.wrongPassword {
```

(Local variable named `accountService`, not `accounts`, to avoid shadowing the unrelated `@Published var profiles: [Profile]`-adjacent naming used elsewhere in this file — this file has no existing `accounts` local, so either name would compile, but `accountService` is clearer here.)

- [x] **Step 4: Add `updateBaseCurrency(_:)`**

In `Sources/MyFin/AppSession.swift`, add this method right after `updateNumberFormatPreferences(_:)`:

```swift
    func updateBaseCurrency(_ currency: Currency) {
        guard let connection else { return }
        let institutions = InstitutionService(connection: connection)
        let accountService = AccountService(connection: connection, institutionService: institutions)
        let dashboard = DashboardService(connection: connection, accountService: accountService, exchangeRateProvider: HardcodedExchangeRateProvider())
        try? dashboard.setBaseCurrency(currency)
        baseCurrency = currency
    }
```

- [x] **Step 5: Run the test to verify it passes**

Run: `swift test --filter MyFinTests.AppSessionTests`
Expected: all `AppSessionTests` pass, including the new one.

- [x] **Step 6: Run the full test suite**

Run: `swift test`
Expected: all 135 previously-passing tests still pass, plus the 1 new one (136 total).

- [x] **Step 7: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 2: `AccountsListModel.groupedByInstitution(baseCurrency:)`

**Files:**
- Modify: `Sources/MyFin/Services/AccountsListModel.swift`
- Test: `Tests/MyFinTests/AccountsListModelTests.swift`

**Interfaces:**
- Consumes: existing `activeAccounts: [Account]`, existing `session?.connection`, existing `HardcodedExchangeRateProvider()` / `ExchangeRateProviding.rate(from:to:)`, existing `Account` (`institutionId: String?`, `type: AccountType`, `openingBalance: Decimal`, `currency: Currency`).
- Produces (for Task 4): `struct AccountGroup: Identifiable, Equatable { let id: String; let label: String; let total: Decimal }`, `AccountsListModel.cashGroupID: String` (static), `AccountsListModel.groupedByInstitution(baseCurrency: Currency) -> [AccountGroup]`.

- [x] **Step 1: Write the failing tests**

Add to `Tests/MyFinTests/AccountsListModelTests.swift`, inside `AccountsListModelTests` (after the existing `createAccount(named:)` helper and its tests, before the class's closing `}`):

```swift
    func test_groupedByInstitution_sumsAccountsAtSameInstitution() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        _ = accounts.createAccount(country: .kz, type: .bankAccount, institutionSelection: .existing(id: "kz.halyk-bank"), currency: .usd, openingBalance: 100, name: "A", balanceDate: nil)
        _ = accounts.createAccount(country: .kz, type: .bankAccount, institutionSelection: .existing(id: "kz.halyk-bank"), currency: .usd, openingBalance: 50, name: "B", balanceDate: nil)

        let model = AccountsListModel(session: session)
        model.reload()

        let groups = model.groupedByInstitution(baseCurrency: .usd)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.id, "kz.halyk-bank")
        XCTAssertEqual(groups.first?.label, "Halyk Bank")
        XCTAssertEqual(groups.first?.total, 150)
    }

    func test_groupedByInstitution_separatesDifferentInstitutions() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        _ = accounts.createAccount(country: .kz, type: .bankAccount, institutionSelection: .existing(id: "kz.halyk-bank"), currency: .usd, openingBalance: 100, name: "A", balanceDate: nil)
        _ = accounts.createAccount(country: .kz, type: .bankAccount, institutionSelection: .existing(id: "kz.kaspi-bank"), currency: .usd, openingBalance: 50, name: "B", balanceDate: nil)

        let model = AccountsListModel(session: session)
        model.reload()

        let groups = model.groupedByInstitution(baseCurrency: .usd)

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(Set(groups.map(\.id)), ["kz.halyk-bank", "kz.kaspi-bank"])
    }

    func test_groupedByInstitution_cashAccountsFormSeparateGroup() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 100, name: "Cash", balanceDate: nil)
        _ = accounts.createAccount(country: .kz, type: .bankAccount, institutionSelection: .existing(id: "kz.halyk-bank"), currency: .usd, openingBalance: 50, name: "Bank", balanceDate: nil)

        let model = AccountsListModel(session: session)
        model.reload()

        let groups = model.groupedByInstitution(baseCurrency: .usd)

        XCTAssertEqual(groups.count, 2)
        XCTAssertTrue(groups.contains { $0.id == AccountsListModel.cashGroupID && $0.total == 100 })
        XCTAssertTrue(groups.contains { $0.id == "kz.halyk-bank" && $0.total == 50 })
    }

    func test_groupedByInstitution_convertsToBaseCurrency() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        _ = accounts.createAccount(country: .kz, type: .bankAccount, institutionSelection: .existing(id: "kz.halyk-bank"), currency: .kzt, openingBalance: Decimal(string: "460.5")!, name: "A", balanceDate: nil)

        let model = AccountsListModel(session: session)
        model.reload()

        let groups = model.groupedByInstitution(baseCurrency: .usd)

        XCTAssertEqual(groups.first?.total, 1)
    }

    func test_groupedByInstitution_excludesArchivedAccounts() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        guard case .success(let account) = accounts.createAccount(country: .kz, type: .bankAccount, institutionSelection: .existing(id: "kz.halyk-bank"), currency: .usd, openingBalance: 100, name: "A", balanceDate: nil) else {
            return XCTFail("expected success")
        }

        let model = AccountsListModel(session: session)
        model.reload()
        model.archive(account)

        let groups = model.groupedByInstitution(baseCurrency: .usd)

        XCTAssertTrue(groups.isEmpty)
    }
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter MyFinTests.AccountsListModelTests`
Expected: build failure — `AccountGroup`, `AccountsListModel.cashGroupID`, and `groupedByInstitution(baseCurrency:)` don't exist yet.

- [x] **Step 3: Add `AccountGroup` and the grouping method**

In `Sources/MyFin/Services/AccountsListModel.swift`, add above the `AccountsListModel` class:

```swift
struct AccountGroup: Identifiable, Equatable {
    let id: String
    let label: String
    let total: Decimal
}
```

Inside the `AccountsListModel` class body, add (anywhere, e.g. right after `restore(_:)`):

```swift
    static let cashGroupID = "__cash__"

    func groupedByInstitution(baseCurrency: Currency) -> [AccountGroup] {
        let exchangeRateProvider = HardcodedExchangeRateProvider()
        var totalsByKey: [String: Decimal] = [:]
        var labelsByKey: [String: String] = [:]
        var order: [String] = []

        for account in activeAccounts {
            let key: String
            let label: String
            if account.type == .cash || account.institutionId == nil {
                key = Self.cashGroupID
                label = ""
            } else {
                key = account.institutionId!
                label = institutionName(id: key) ?? key
            }

            let converted = account.openingBalance * exchangeRateProvider.rate(from: account.currency, to: baseCurrency)
            totalsByKey[key, default: 0] += converted
            if labelsByKey[key] == nil {
                labelsByKey[key] = label
                order.append(key)
            }
        }

        return order.map { key in
            var rounded = Decimal()
            var value = totalsByKey[key] ?? 0
            NSDecimalRound(&rounded, &value, 8, .plain)
            return AccountGroup(id: key, label: labelsByKey[key] ?? "", total: rounded)
        }
    }

    private func institutionName(id: String) -> String? {
        guard let connection = session?.connection else { return nil }
        let rows = (try? connection.query("SELECT name FROM institutions WHERE id = ?;", params: [.text(id)])) ?? []
        if case let .text(name)? = rows.first?["name"] {
            return name
        }
        return nil
    }
```

- [x] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter MyFinTests.AccountsListModelTests`
Expected: all `AccountsListModelTests` pass, including the 5 new ones.

- [x] **Step 5: Run the full test suite**

Run: `swift test`
Expected: 136 + 5 = 141 tests pass, 0 failures.

- [x] **Step 6: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 3: Migrate `DashboardView`/`SettingsView` onto `session.baseCurrency`

**Files:**
- Modify: `Sources/MyFin/Views/DashboardView.swift`
- Modify: `Sources/MyFin/Views/SettingsView.swift`

**Interfaces:**
- Consumes: `session.baseCurrency` / `session.updateBaseCurrency(_:)` (Task 1).
- Produces: none.

- [x] **Step 1: `DashboardView`**

Replace the full contents of `Sources/MyFin/Views/DashboardView.swift`:

```swift
import SwiftUI

struct DashboardView: View {
    @ObservedObject var session: AppSession
    @EnvironmentObject var preferences: AppPreferences

    @State private var total: Decimal = 0

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
            Text("\(NumberDisplayFormatter.format(total, preferences: session.numberFormatPreferences)) \(session.baseCurrency.rawValue)").font(.system(size: 40, weight: .bold))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: reload)
    }

    private func reload() {
        guard let service = dashboardService else { return }
        total = service.totalBalance(displayCurrency: session.baseCurrency)
    }
}
```

(`@State private var displayCurrency` is gone — `session.baseCurrency` is now the single source of truth. `dashboardService` still exists and is still used, just only for `totalBalance(displayCurrency:)` now, not `.baseCurrency()`.)

- [x] **Step 2: `SettingsView` — the base-currency `Picker`'s `onChange`**

In `Sources/MyFin/Views/SettingsView.swift`, change:

```swift
                        .onChange(of: baseCurrency) { newValue in
                            guard let connection = session.connection else { return }
                            let institutions = InstitutionService(connection: connection)
                            let accounts = AccountService(connection: connection, institutionService: institutions)
                            let dashboard = DashboardService(connection: connection, accountService: accounts, exchangeRateProvider: HardcodedExchangeRateProvider())
                            try? dashboard.setBaseCurrency(newValue)
                        }
```

to:

```swift
                        .onChange(of: baseCurrency) { newValue in
                            session.updateBaseCurrency(newValue)
                        }
```

(`@State private var baseCurrency: Currency = .usd` itself stays — it's still needed as the two-way binding target for the `Picker`, exactly like `numberFormatPreferences` already works in this same file. Only the `onChange` body changes.)

- [x] **Step 3: `SettingsView` — `.onAppear`**

In the same file, change:

```swift
        .onAppear {
            editedName = session.unlockedProfile?.displayName ?? ""
            editedIconName = session.unlockedProfile?.iconName ?? Profile.defaultIconName
            editedIconColor = session.unlockedProfile?.iconColor ?? Profile.defaultIconColor
            if let connection = session.connection {
                let institutions = InstitutionService(connection: connection)
                let accounts = AccountService(connection: connection, institutionService: institutions)
                baseCurrency = DashboardService(connection: connection, accountService: accounts, exchangeRateProvider: HardcodedExchangeRateProvider()).baseCurrency()
            }
            numberFormatPreferences = session.numberFormatPreferences
        }
```

to:

```swift
        .onAppear {
            editedName = session.unlockedProfile?.displayName ?? ""
            editedIconName = session.unlockedProfile?.iconName ?? Profile.defaultIconName
            editedIconColor = session.unlockedProfile?.iconColor ?? Profile.defaultIconColor
            baseCurrency = session.baseCurrency
            numberFormatPreferences = session.numberFormatPreferences
        }
```

- [x] **Step 4: Build**

Run: `swift build`
Expected: build succeeds with no errors.

- [x] **Step 5: Run the full test suite**

Run: `swift test`
Expected: all 141 tests still pass.

- [x] **Step 6: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 4: Wire the sidebar onto `groupedByInstitution`

**Files:**
- Modify: `Sources/MyFin/Views/MainShellView.swift`

**Interfaces:**
- Consumes: `AccountsListModel.groupedByInstitution(baseCurrency:)`, `AccountGroup`, `AccountsListModel.cashGroupID` (Task 2), `session.baseCurrency` (Task 1), existing `.cashFieldLabel` L10n key.
- Produces: none — this is the final task in this plan.

- [x] **Step 1: Replace the per-account rows with per-group rows**

In `Sources/MyFin/Views/MainShellView.swift`, change:

```swift
                            DisclosureGroup(isExpanded: $isAccountsExpanded) {
                                ForEach(accountsModel.activeAccounts) { account in
                                    HStack {
                                        Text(account.name)
                                        Spacer()
                                        Text("\(NumberDisplayFormatter.format(account.openingBalance, preferences: session.numberFormatPreferences)) \(account.currency.rawValue)")
                                            .foregroundStyle(.secondary)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture { selection = .accounts }
                                }
                            } label: {
```

to:

```swift
                            DisclosureGroup(isExpanded: $isAccountsExpanded) {
                                ForEach(accountsModel.groupedByInstitution(baseCurrency: session.baseCurrency)) { group in
                                    HStack {
                                        Text(group.id == AccountsListModel.cashGroupID ? preferences.string(.cashFieldLabel) : group.label)
                                        Spacer()
                                        Text("\(NumberDisplayFormatter.format(group.total, preferences: session.numberFormatPreferences)) \(session.baseCurrency.rawValue)")
                                            .foregroundStyle(.secondary)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture { selection = .accounts }
                                }
                            } label: {
```

- [x] **Step 2: Build**

Run: `swift build`
Expected: build succeeds with no errors.

- [x] **Step 3: Run the full test suite**

Run: `swift test`
Expected: all 141 tests still pass.

- [ ] **Step 4: Manual look at the running app**

Hand to human partner. Run: `swift run` from `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin`
Ask them to: confirm the sidebar's "Счета" list now shows one row per bank (not per account) with the summed balance in the base currency; create a second account at a bank that already has one, confirm the sidebar's row for that bank updates to the combined sum (not two rows); confirm cash accounts (if any) collapse into one "Наличные" row; open Settings and change the base currency while the sidebar is visible, confirm every sidebar row's amount updates immediately, in the new currency, without navigating away and back; confirm clicking a sidebar row still opens "Счета".
Expected: everything above behaves as described.

- [x] **Step 5: Commit**

Skipped — this project does not use git (see Global Constraints).

---

## Self-Review Notes

- **Spec coverage:** Section 1 (live `baseCurrency`) → Task 1. Section 2 (grouping logic) → Task 2. Section 3 (sidebar wiring) → Task 4, with Task 3 as the necessary bridge migrating the two other `baseCurrency` consumers so there's one source of truth before the sidebar starts depending on it. The spec's "Out of scope" items (no drill-down, no change to "Счета"/"Банки", no change to exchange-rate sourcing) are respected — nothing in any task adds navigation beyond `selection = .accounts` or touches `HardcodedExchangeRateProvider`'s own logic.
- **No placeholders:** every step has complete, exact before/after code, including all 5 of Task 2's hand-traceable test cases (sums, separates, cash bucket, currency conversion matching the known `DashboardServiceTests` 1 USD = 460.5 KZT rate, archived-exclusion).
- **Type/name consistency checked:** `AccountGroup`'s 3 fields and `AccountsListModel.cashGroupID` (Task 2) are used identically in Task 4's `MainShellView` changes; `session.baseCurrency` / `session.updateBaseCurrency(_:)` (Task 1) match exactly what Tasks 3–4 call; the localization-boundary rule from Global Constraints (cash label resolved in the view, not the model) is upheld in both Task 2 (`label = ""`) and Task 4 (`preferences.string(.cashFieldLabel)` substitution).
