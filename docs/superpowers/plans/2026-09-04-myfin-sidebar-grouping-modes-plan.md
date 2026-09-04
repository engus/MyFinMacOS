# Sidebar Grouping Modes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user choose how the sidebar's "Счета" list groups accounts — bank (existing), currency, country, or account type — persisted per profile.

**Architecture:** Add a `SidebarGroupingMode` enum and 3 new grouping methods to `AccountsListModel`, behind one dispatcher `grouped(by:baseCurrency:)`. `AccountGroup` gains a `displayCurrency` field so a currency-mode group can show its own currency instead of always the base one. `AppSession.sidebarGroupingMode` goes live (published, persisted), mirroring `baseCurrency`/`numberFormatPreferences` exactly. A new Settings section lets the user pick the mode; the sidebar switches from calling `groupedByInstitution` directly to the dispatcher.

**Tech Stack:** Swift 5.9, SwiftUI, SQLCipher.swift, XCTest, Swift Package Manager (no Xcode project).

**Spec:** `docs/superpowers/specs/2026-09-04-myfin-sidebar-grouping-modes-design.md`

## Global Constraints

- **No git** in this project (neither `MyFinLocal/` nor `MyFinLocal/MyFin/` is a git repository) — never run `git` commands; every "Commit" step below is skipped, left in the template only where the plan format requires it.
- **Swift toolchain is available and verified working in this environment** — run every `swift build` / `swift test` step yourself, directly via Bash, from `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin`. Only the final manual look-at-the-running-app step (explicitly marked "Hand to human partner") needs the human.
- **Currency-mode groups are never converted** — `groupedByCurrency()` sums each account's `openingBalance` directly, with no `HardcodedExchangeRateProvider` call, and its groups' `displayCurrency` is that group's own currency. Every other mode (institution, country, type) converts via `HardcodedExchangeRateProvider` to the passed-in `baseCurrency`, and its groups' `displayCurrency` is always that `baseCurrency` — confirmed with the user.
- **Type-mode uses the 4 real `AccountType` cases as-is** (`debitCard`/`deposit`/`bankAccount`/`cash`) — no coarser "Cash/Bank/Cards" bucketing — confirmed with the user.
- **No new persistence service class** for `sidebarGroupingMode` — a single string value, read/written inline in `AppSession` against `profile_settings`, the same idiom `DashboardService.baseCurrency()`/`.setBaseCurrency()` already uses (unlike `numberFormatPreferences`'s 4 related fields, which warranted their own `NumberFormatPreferencesService`).
- **Icons only for institution mode** — the sidebar's existing bank/cash icon logic is gated on `session.sidebarGroupingMode == .institution`; no icons are added for currency/country/type groups.
- No new tests for `SettingsView`/`MainShellView` themselves — consistent with this codebase's existing convention of zero View-level XCTest coverage. Verified by `swift build` + `swift test` + a manual look at the running app.

## File Structure

- Modify: `Sources/MyFin/Services/AccountsListModel.swift` — `SidebarGroupingMode`, `AccountGroup.displayCurrency`, 3 new grouping methods, dispatcher (Task 1).
- Modify: `Tests/MyFinTests/AccountsListModelTests.swift` (Task 1).
- Modify: `Sources/MyFin/AppSession.swift` — `sidebarGroupingMode` published property + `updateSidebarGroupingMode(_:)` (Task 2).
- Modify: `Tests/MyFinTests/AppSessionTests.swift` (Task 2).
- Modify: `Sources/MyFin/Localization.swift` — 6 new `L10nKey` cases + ru/en entries (Task 3).
- Modify: `Sources/MyFin/Views/SettingsView.swift` — new "Группировка сайдбара" section (Task 3).
- Modify: `Sources/MyFin/Views/MainShellView.swift` — sidebar wired onto the dispatcher, icon gated on mode, currency suffix from `group.displayCurrency` (Task 4).

---

### Task 1: `SidebarGroupingMode` + 3 new grouping methods + dispatcher

**Files:**
- Modify: `Sources/MyFin/Services/AccountsListModel.swift`
- Test: `Tests/MyFinTests/AccountsListModelTests.swift`

**Interfaces:**
- Consumes: existing `activeAccounts: [Account]`, existing `HardcodedExchangeRateProvider`, existing `Account` (`country: Country`, `currency: Currency`, `type: AccountType`, `openingBalance: Decimal`), existing `AccountsListModel.groupedByInstitution(baseCurrency:)` (unchanged in behavior, only its `AccountGroup` construction gains the new field).
- Produces (for Task 4): `enum SidebarGroupingMode: String, CaseIterable, Equatable { case institution, currency, country, type }`; `AccountGroup.displayCurrency: Currency` (new field); `AccountsListModel.groupedByCurrency() -> [AccountGroup]`; `.groupedByCountry(baseCurrency: Currency) -> [AccountGroup]`; `.groupedByType(baseCurrency: Currency) -> [AccountGroup]`; `.grouped(by: SidebarGroupingMode, baseCurrency: Currency) -> [AccountGroup]`.

- [x] **Step 1: Write the failing tests**

Add to `Tests/MyFinTests/AccountsListModelTests.swift`, inside `AccountsListModelTests` (after the existing `groupedByInstitution` tests, before the class's closing `}`):

```swift
    func test_groupedByCurrency_sumsAccountsInSameCurrencyWithoutConversion() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 100, name: "A", balanceDate: nil)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 50, name: "B", balanceDate: nil)

        let model = AccountsListModel(session: session)
        model.reload()

        let groups = model.groupedByCurrency()

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.id, "USD")
        XCTAssertEqual(groups.first?.total, 150)
        XCTAssertEqual(groups.first?.displayCurrency, .usd)
    }

    func test_groupedByCurrency_separatesDifferentCurrencies() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 100, name: "A", balanceDate: nil)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .kzt, openingBalance: 200, name: "B", balanceDate: nil)

        let model = AccountsListModel(session: session)
        model.reload()

        let groups = model.groupedByCurrency()

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(Set(groups.map(\.id)), ["USD", "KZT"])
        XCTAssertTrue(groups.contains { $0.id == "KZT" && $0.total == 200 && $0.displayCurrency == .kzt })
    }

    func test_groupedByCountry_sumsAndConvertsToBaseCurrency() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 1, name: "A", balanceDate: nil)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .kzt, openingBalance: Decimal(string: "460.5")!, name: "B", balanceDate: nil)

        let model = AccountsListModel(session: session)
        model.reload()

        let groups = model.groupedByCountry(baseCurrency: .usd)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.id, "KZ")
        XCTAssertEqual(groups.first?.label, "🇰🇿 Kazakhstan")
        XCTAssertEqual(groups.first?.total, 2)
        XCTAssertEqual(groups.first?.displayCurrency, .usd)
    }

    func test_groupedByCountry_separatesDifferentCountries() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 100, name: "A", balanceDate: nil)
        _ = accounts.createAccount(country: .ae, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 50, name: "B", balanceDate: nil)

        let model = AccountsListModel(session: session)
        model.reload()

        let groups = model.groupedByCountry(baseCurrency: .usd)

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(Set(groups.map(\.id)), ["KZ", "AE"])
    }

    func test_groupedByType_sumsAndSeparatesDifferentTypes() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 100, name: "A", balanceDate: nil)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 50, name: "B", balanceDate: nil)
        _ = accounts.createAccount(country: .kz, type: .bankAccount, institutionSelection: .existing(id: "kz.halyk-bank"), currency: .usd, openingBalance: 200, name: "C", balanceDate: nil)

        let model = AccountsListModel(session: session)
        model.reload()

        let groups = model.groupedByType(baseCurrency: .usd)

        XCTAssertEqual(groups.count, 2)
        XCTAssertTrue(groups.contains { $0.id == "cash" && $0.label == "Cash" && $0.total == 150 })
        XCTAssertTrue(groups.contains { $0.id == "bank_account" && $0.label == "Bank account" && $0.total == 200 })
    }

    func test_groupedByType_convertsToBaseCurrency() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .kzt, openingBalance: Decimal(string: "460.5")!, name: "A", balanceDate: nil)

        let model = AccountsListModel(session: session)
        model.reload()

        let groups = model.groupedByType(baseCurrency: .usd)

        XCTAssertEqual(groups.first?.total, 1)
        XCTAssertEqual(groups.first?.displayCurrency, .usd)
    }

    func test_grouped_dispatchesToTheCorrectMethodPerMode() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        _ = accounts.createAccount(country: .kz, type: .bankAccount, institutionSelection: .existing(id: "kz.halyk-bank"), currency: .usd, openingBalance: 100, name: "A", balanceDate: nil)

        let model = AccountsListModel(session: session)
        model.reload()

        XCTAssertEqual(model.grouped(by: .institution, baseCurrency: .usd), model.groupedByInstitution(baseCurrency: .usd))
        XCTAssertEqual(model.grouped(by: .currency, baseCurrency: .usd), model.groupedByCurrency())
        XCTAssertEqual(model.grouped(by: .country, baseCurrency: .usd), model.groupedByCountry(baseCurrency: .usd))
        XCTAssertEqual(model.grouped(by: .type, baseCurrency: .usd), model.groupedByType(baseCurrency: .usd))
    }
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter MyFinTests.AccountsListModelTests`
Expected: build failure — `SidebarGroupingMode`, `groupedByCurrency`, `groupedByCountry`, `groupedByType`, `grouped(by:baseCurrency:)`, and `AccountGroup.displayCurrency` don't exist yet.

- [x] **Step 3: Add the enum, the field, the 3 methods, and the dispatcher**

In `Sources/MyFin/Services/AccountsListModel.swift`, change:

```swift
struct AccountGroup: Identifiable, Equatable {
    let id: String
    let label: String
    let total: Decimal
}
```

to:

```swift
enum SidebarGroupingMode: String, CaseIterable, Equatable {
    case institution
    case currency
    case country
    case type
}

struct AccountGroup: Identifiable, Equatable {
    let id: String
    let label: String
    let total: Decimal
    let displayCurrency: Currency
}
```

Change the one existing `AccountGroup(...)` construction site, inside `groupedByInstitution(baseCurrency:)`:

```swift
        return order.map { key in
            var rounded = Decimal()
            var value = totalsByKey[key] ?? 0
            NSDecimalRound(&rounded, &value, 8, .plain)
            return AccountGroup(id: key, label: labelsByKey[key] ?? "", total: rounded)
        }
```

to:

```swift
        return order.map { key in
            var rounded = Decimal()
            var value = totalsByKey[key] ?? 0
            NSDecimalRound(&rounded, &value, 8, .plain)
            return AccountGroup(id: key, label: labelsByKey[key] ?? "", total: rounded, displayCurrency: baseCurrency)
        }
```

Then add the 3 new methods and the dispatcher right after `groupedByInstitution(baseCurrency:)`'s closing brace (still before the private `institutionName(id:)` helper):

```swift
    func groupedByCurrency() -> [AccountGroup] {
        var totalsByKey: [String: Decimal] = [:]
        var order: [String] = []

        for account in activeAccounts {
            let key = account.currency.rawValue
            totalsByKey[key, default: 0] += account.openingBalance
            if !order.contains(key) {
                order.append(key)
            }
        }

        return order.map { key in
            var rounded = Decimal()
            var value = totalsByKey[key] ?? 0
            NSDecimalRound(&rounded, &value, 8, .plain)
            return AccountGroup(id: key, label: key, total: rounded, displayCurrency: Currency(rawValue: key) ?? .usd)
        }
    }

    func groupedByCountry(baseCurrency: Currency) -> [AccountGroup] {
        let exchangeRateProvider = HardcodedExchangeRateProvider()
        var totalsByKey: [String: Decimal] = [:]
        var labelsByKey: [String: String] = [:]
        var order: [String] = []

        for account in activeAccounts {
            let key = account.country.rawValue
            let converted = account.openingBalance * exchangeRateProvider.rate(from: account.currency, to: baseCurrency)
            totalsByKey[key, default: 0] += converted
            if labelsByKey[key] == nil {
                labelsByKey[key] = "\(account.country.flag) \(account.country.displayName)"
                order.append(key)
            }
        }

        return order.map { key in
            var rounded = Decimal()
            var value = totalsByKey[key] ?? 0
            NSDecimalRound(&rounded, &value, 8, .plain)
            return AccountGroup(id: key, label: labelsByKey[key] ?? key, total: rounded, displayCurrency: baseCurrency)
        }
    }

    func groupedByType(baseCurrency: Currency) -> [AccountGroup] {
        let exchangeRateProvider = HardcodedExchangeRateProvider()
        var totalsByKey: [String: Decimal] = [:]
        var labelsByKey: [String: String] = [:]
        var order: [String] = []

        for account in activeAccounts {
            let key = account.type.rawValue
            let converted = account.openingBalance * exchangeRateProvider.rate(from: account.currency, to: baseCurrency)
            totalsByKey[key, default: 0] += converted
            if labelsByKey[key] == nil {
                labelsByKey[key] = account.type.displayName
                order.append(key)
            }
        }

        return order.map { key in
            var rounded = Decimal()
            var value = totalsByKey[key] ?? 0
            NSDecimalRound(&rounded, &value, 8, .plain)
            return AccountGroup(id: key, label: labelsByKey[key] ?? key, total: rounded, displayCurrency: baseCurrency)
        }
    }

    func grouped(by mode: SidebarGroupingMode, baseCurrency: Currency) -> [AccountGroup] {
        switch mode {
        case .institution: return groupedByInstitution(baseCurrency: baseCurrency)
        case .currency: return groupedByCurrency()
        case .country: return groupedByCountry(baseCurrency: baseCurrency)
        case .type: return groupedByType(baseCurrency: baseCurrency)
        }
    }
```

- [x] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter MyFinTests.AccountsListModelTests`
Expected: all `AccountsListModelTests` pass, including the 7 new ones.

- [x] **Step 5: Run the full test suite**

Run: `swift test`
Expected: all 147 previously-passing tests still pass, plus the 7 new ones (154 total).

- [x] **Step 6: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 2: `AppSession.sidebarGroupingMode` — live, persisted inline

**Files:**
- Modify: `Sources/MyFin/AppSession.swift`
- Test: `Tests/MyFinTests/AppSessionTests.swift`

**Interfaces:**
- Consumes: `SidebarGroupingMode` (Task 1), existing `connection.query(_:params:)` / `.execute(_:params:)`.
- Produces (for Tasks 3–4): `AppSession.sidebarGroupingMode: SidebarGroupingMode` (published, read-only from outside), `AppSession.updateSidebarGroupingMode(_ mode: SidebarGroupingMode)`.

- [x] **Step 1: Write the failing test**

Add to `Tests/MyFinTests/AppSessionTests.swift`, inside `AppSessionTests`, right before the class's closing `}`:

```swift
    func test_updateSidebarGroupingMode_publishesImmediatelyAndPersists() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)

        session.updateSidebarGroupingMode(.currency)
        XCTAssertEqual(session.sidebarGroupingMode, .currency)

        let profile = session.profiles[0]
        session.logOut()
        session.logIn(profile: profile, password: "pw1")
        XCTAssertEqual(session.sidebarGroupingMode, .currency)
    }
```

- [x] **Step 2: Run the test to verify it fails**

Run: `swift test --filter MyFinTests.AppSessionTests`
Expected: build failure — `AppSession` has no member `sidebarGroupingMode`/`updateSidebarGroupingMode`.

- [x] **Step 3: Add the property and loading points**

In `Sources/MyFin/AppSession.swift`, add the published property next to `baseCurrency`:

```swift
    @Published private(set) var numberFormatPreferences = NumberFormatPreferences()
    @Published private(set) var baseCurrency: Currency = .usd
    @Published private(set) var sidebarGroupingMode: SidebarGroupingMode = .institution
```

In `createProfile(...)`, change:

```swift
            self.baseCurrency = DashboardService(connection: connection, accountService: accountService, exchangeRateProvider: HardcodedExchangeRateProvider()).baseCurrency()
            self.errorMessage = nil
            self.screen = profile.hasCompletedOnboarding ? .mainShell : .onboarding
            refreshProfiles()
```

to:

```swift
            self.baseCurrency = DashboardService(connection: connection, accountService: accountService, exchangeRateProvider: HardcodedExchangeRateProvider()).baseCurrency()
            let groupingRows = (try? connection.query("SELECT value FROM profile_settings WHERE key = 'sidebarGroupingMode';")) ?? []
            if case let .text(raw)? = groupingRows.first?["value"], let mode = SidebarGroupingMode(rawValue: raw) {
                self.sidebarGroupingMode = mode
            } else {
                self.sidebarGroupingMode = .institution
            }
            self.errorMessage = nil
            self.screen = profile.hasCompletedOnboarding ? .mainShell : .onboarding
            refreshProfiles()
```

In `logIn(...)`, change:

```swift
            self.baseCurrency = DashboardService(connection: connection, accountService: accountService, exchangeRateProvider: HardcodedExchangeRateProvider()).baseCurrency()
            self.errorMessage = nil
            self.screen = profile.hasCompletedOnboarding ? .mainShell : .onboarding
        } catch DatabaseError.wrongPassword {
```

to:

```swift
            self.baseCurrency = DashboardService(connection: connection, accountService: accountService, exchangeRateProvider: HardcodedExchangeRateProvider()).baseCurrency()
            let groupingRows = (try? connection.query("SELECT value FROM profile_settings WHERE key = 'sidebarGroupingMode';")) ?? []
            if case let .text(raw)? = groupingRows.first?["value"], let mode = SidebarGroupingMode(rawValue: raw) {
                self.sidebarGroupingMode = mode
            } else {
                self.sidebarGroupingMode = .institution
            }
            self.errorMessage = nil
            self.screen = profile.hasCompletedOnboarding ? .mainShell : .onboarding
        } catch DatabaseError.wrongPassword {
```

- [x] **Step 4: Add `updateSidebarGroupingMode(_:)`**

In `Sources/MyFin/AppSession.swift`, add this method right after `updateBaseCurrency(_:)`:

```swift
    func updateSidebarGroupingMode(_ mode: SidebarGroupingMode) {
        guard let connection else { return }
        try? connection.execute(
            "INSERT INTO profile_settings (key, value) VALUES ('sidebarGroupingMode', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
            params: [.text(mode.rawValue)]
        )
        sidebarGroupingMode = mode
    }
```

- [x] **Step 5: Run the test to verify it passes**

Run: `swift test --filter MyFinTests.AppSessionTests`
Expected: all `AppSessionTests` pass, including the new one.

- [x] **Step 6: Run the full test suite**

Run: `swift test`
Expected: 154 + 1 = 155 tests pass.

- [x] **Step 7: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 3: Localization + Settings UI section

**Files:**
- Modify: `Sources/MyFin/Localization.swift`
- Modify: `Sources/MyFin/Views/SettingsView.swift`

**Interfaces:**
- Consumes: `SidebarGroupingMode` (Task 1), `session.sidebarGroupingMode` / `session.updateSidebarGroupingMode(_:)` (Task 2).
- Produces (for Task 4): none directly — Task 4 doesn't depend on this task, but both must land for the feature to be user-facing-complete.

- [x] **Step 1: Add the 6 new `L10nKey` cases**

In `Sources/MyFin/Localization.swift`, change:

```swift
    case trailingZeroesShowLabel
    case trailingZeroesHideLabel
}
```

to:

```swift
    case trailingZeroesShowLabel
    case trailingZeroesHideLabel
    case sidebarGroupingSectionTitle
    case sidebarGroupingModeFieldLabel
    case groupByInstitutionLabel
    case groupByCurrencyLabel
    case groupByCountryLabel
    case groupByTypeLabel
}
```

- [x] **Step 2: Add the `ru` entries**

Change:

```swift
        .trailingZeroesShowLabel: "Показывать",
        .trailingZeroesHideLabel: "Скрывать",
    ]
```

to:

```swift
        .trailingZeroesShowLabel: "Показывать",
        .trailingZeroesHideLabel: "Скрывать",
        .sidebarGroupingSectionTitle: "Группировка сайдбара",
        .sidebarGroupingModeFieldLabel: "Режим группировки",
        .groupByInstitutionLabel: "Банк",
        .groupByCurrencyLabel: "Валюта",
        .groupByCountryLabel: "Страна",
        .groupByTypeLabel: "Тип",
    ]
```

- [x] **Step 3: Add the `en` entries**

Change:

```swift
        .trailingZeroesShowLabel: "Show",
        .trailingZeroesHideLabel: "Hide",
    ]
```

to:

```swift
        .trailingZeroesShowLabel: "Show",
        .trailingZeroesHideLabel: "Hide",
        .sidebarGroupingSectionTitle: "Sidebar grouping",
        .sidebarGroupingModeFieldLabel: "Group by",
        .groupByInstitutionLabel: "Bank",
        .groupByCurrencyLabel: "Currency",
        .groupByCountryLabel: "Country",
        .groupByTypeLabel: "Type",
    ]
```

- [x] **Step 4: Add the new state property to `SettingsView`**

In `Sources/MyFin/Views/SettingsView.swift`, change:

```swift
    @State private var baseCurrency: Currency = .usd
    @State private var numberFormatPreferences = NumberFormatPreferences()
```

to:

```swift
    @State private var baseCurrency: Currency = .usd
    @State private var numberFormatPreferences = NumberFormatPreferences()
    @State private var sidebarGroupingMode: SidebarGroupingMode = .institution
```

- [x] **Step 5: Add the new Section**

Change:

```swift
                    Section {
                        Button(preferences.string(.logOutButton), role: .destructive) {
                            session.logOut()
                        }
                    }
```

to:

```swift
                    Section(preferences.string(.sidebarGroupingSectionTitle)) {
                        Picker(preferences.string(.sidebarGroupingModeFieldLabel), selection: $sidebarGroupingMode) {
                            Text(preferences.string(.groupByInstitutionLabel)).tag(SidebarGroupingMode.institution)
                            Text(preferences.string(.groupByCurrencyLabel)).tag(SidebarGroupingMode.currency)
                            Text(preferences.string(.groupByCountryLabel)).tag(SidebarGroupingMode.country)
                            Text(preferences.string(.groupByTypeLabel)).tag(SidebarGroupingMode.type)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: sidebarGroupingMode) { newValue in
                            session.updateSidebarGroupingMode(newValue)
                        }
                    }

                    Section {
                        Button(preferences.string(.logOutButton), role: .destructive) {
                            session.logOut()
                        }
                    }
```

- [x] **Step 6: Load it in `.onAppear`**

Change:

```swift
            baseCurrency = session.baseCurrency
            numberFormatPreferences = session.numberFormatPreferences
        }
```

to:

```swift
            baseCurrency = session.baseCurrency
            numberFormatPreferences = session.numberFormatPreferences
            sidebarGroupingMode = session.sidebarGroupingMode
        }
```

- [x] **Step 7: Build**

Run: `swift build`
Expected: build succeeds with no errors.

- [x] **Step 8: Run the full test suite**

Run: `swift test`
Expected: all 155 tests still pass.

- [x] **Step 9: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 4: Wire the sidebar onto `grouped(by:baseCurrency:)`

**Files:**
- Modify: `Sources/MyFin/Views/MainShellView.swift`

**Interfaces:**
- Consumes: `AccountsListModel.grouped(by:baseCurrency:)` (Task 1), `session.sidebarGroupingMode` (Task 2).
- Produces: none — this is the final task in this plan.

- [x] **Step 1: Replace the sidebar's grouping call, gate the icon, fix the currency suffix**

In `Sources/MyFin/Views/MainShellView.swift`, change:

```swift
                            DisclosureGroup(isExpanded: $isAccountsExpanded) {
                                ForEach(accountsModel.groupedByInstitution(baseCurrency: session.baseCurrency)) { group in
                                    HStack {
                                        if group.id == AccountsListModel.cashGroupID {
                                            Image(systemName: AccountsListModel.cashIconName)
                                                .foregroundStyle(ProfileIconPalette.color(named: AccountsListModel.cashIconColor))
                                        } else {
                                            Image(systemName: SystemInstitutionCatalog.institutionIconName)
                                                .foregroundStyle(ProfileIconPalette.color(named: SystemInstitutionCatalog.color(forID: group.id) ?? "blue"))
                                        }
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

to:

```swift
                            DisclosureGroup(isExpanded: $isAccountsExpanded) {
                                ForEach(accountsModel.grouped(by: session.sidebarGroupingMode, baseCurrency: session.baseCurrency)) { group in
                                    HStack {
                                        if session.sidebarGroupingMode == .institution {
                                            if group.id == AccountsListModel.cashGroupID {
                                                Image(systemName: AccountsListModel.cashIconName)
                                                    .foregroundStyle(ProfileIconPalette.color(named: AccountsListModel.cashIconColor))
                                            } else {
                                                Image(systemName: SystemInstitutionCatalog.institutionIconName)
                                                    .foregroundStyle(ProfileIconPalette.color(named: SystemInstitutionCatalog.color(forID: group.id) ?? "blue"))
                                            }
                                        }
                                        Text(group.id == AccountsListModel.cashGroupID ? preferences.string(.cashFieldLabel) : group.label)
                                        Spacer()
                                        Text("\(NumberDisplayFormatter.format(group.total, preferences: session.numberFormatPreferences)) \(group.displayCurrency.rawValue)")
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
Expected: all 155 tests still pass.

- [ ] **Step 4: Manual look at the running app**

Hand to human partner. Run: `swift run` from `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin`
Ask them to: open Settings → Общее, confirm a new "Группировка сайдбара" section with a 4-option segmented control (Банк/Валюта/Страна/Тип) appears; switch to "Банк" and confirm the sidebar looks exactly as before (bank icons, "Наличные" row); switch to "Валюта" and confirm the sidebar now shows one row per currency actually in use, each amount shown in *that* currency (not converted), with no icon; switch to "Страна" and confirm one row per country, each amount converted to the base currency, no icon; switch to "Тип" and confirm one row per account type (e.g. "Cash", "Bank account"), converted to base currency, no icon; quit and relaunch, log back into the same profile, and confirm the chosen mode was remembered.
Expected: everything above behaves as described.

- [x] **Step 5: Commit**

Skipped — this project does not use git (see Global Constraints).

---

## Self-Review Notes

- **Spec coverage:** Section 1 (enum + methods + dispatcher) → Task 1. Section 2 (persistence) → Task 2. Section 3 (Settings UI) → Task 3. Section 4 (sidebar wiring) → Task 4. The spec's "Out of scope" items (no per-group icons for the 3 new modes, no drill-down, mode picker only in Settings) are respected — Task 4's icon block is gated on `.institution` mode exactly, and no new navigation is added anywhere.
- **No placeholders:** every step has complete, exact code, including all 7 of Task 1's hand-traceable test cases (currency sums with no conversion, country/type sums with the known 1 USD = 460.5 KZT rate, and the dispatcher cross-checked against each underlying method).
- **Type/name consistency checked:** `SidebarGroupingMode`'s 4 cases and `AccountGroup.displayCurrency` (Task 1) are used identically in Task 2 (`SidebarGroupingMode(rawValue:)`), Task 3 (the Picker's 4 tags), and Task 4 (`session.sidebarGroupingMode == .institution`, `group.displayCurrency.rawValue`); `session.sidebarGroupingMode` / `session.updateSidebarGroupingMode(_:)` (Task 2) match exactly what Tasks 3–4 call.
