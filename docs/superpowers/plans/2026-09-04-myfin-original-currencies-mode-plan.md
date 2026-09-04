# "Оригинальные валюты" Base-Currency Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a third base-currency option, "Оригинальные валюты" ("Original currencies"), that shows the Dashboard as a per-currency breakdown with no conversion, while leaving `baseCurrency` and every other consumer of it completely untouched.

**Architecture:** A new, fully independent `AppSession.showOriginalCurrencies: Bool` field, live-published and persisted in `profile_settings` exactly like the existing `sidebarGroupingMode` field. `SettingsView` gets a View-only `BaseCurrencySelection` wrapper enum that turns the existing currency-only `Picker` into a 3-way segmented control. `DashboardView` gains an `AccountsListModel` dependency and branches its body on the new flag between the existing single converted total and `model.groupedByCurrency()`.

**Tech Stack:** Swift 5.9, SwiftUI, SQLCipher.swift, XCTest. Swift Package Manager project (no Xcode project file).

## Global Constraints

- This project (`/Users/yevgeniygolota/Documents/Projects/MyFinLocal` and its `MyFin/` subdirectory) is NOT a git repository — skip every "Commit" step in this plan entirely.
- Swift package root is `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin`; all file paths below are relative to that directory.
- `swift build` and `swift test` run directly via Bash in this session.
- No change to `baseCurrency`'s type, storage, or its 3 existing sidebar-grouping consumers (`groupedByInstitution`/`groupedByCountry`/`groupedByType`).
- No per-currency breakdown anywhere except the Dashboard.
- No new fallback-currency setting for the 3 grouping modes.
- Persist `showOriginalCurrencies` using the same inline `connection.execute(...ON CONFLICT...)` idiom already used for `sidebarGroupingMode` — no new service class.
- Money handling: always `Decimal`, never `Double`/`Float` (unaffected by this feature, noted for consistency — no new money math is introduced here; `groupedByCurrency()` already exists and is reused as-is).

---

### Task 1: `AppSession.showOriginalCurrencies` live wiring + test

**Files:**
- Modify: `Sources/MyFin/AppSession.swift`
- Test: `Tests/MyFinTests/AppSessionTests.swift`

**Interfaces:**
- Consumes: nothing new from other tasks.
- Produces: `AppSession.showOriginalCurrencies: Bool` (published, `private(set)`), `AppSession.updateShowOriginalCurrencies(_ show: Bool)`. Task 2 and Task 3 both read `session.showOriginalCurrencies` and Task 2 calls `session.updateShowOriginalCurrencies(_:)`.

- [ ] **Step 1: Write the failing test**

Open `Tests/MyFinTests/AppSessionTests.swift` and find the last test in the file:

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
}
```

Add a new test immediately after it, before the closing `}` of the test class:

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

    func test_updateShowOriginalCurrencies_publishesImmediatelyAndPersists() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)

        XCTAssertFalse(session.showOriginalCurrencies)

        session.updateShowOriginalCurrencies(true)
        XCTAssertTrue(session.showOriginalCurrencies)

        let profile = session.profiles[0]
        session.logOut()
        session.logIn(profile: profile, password: "pw1")
        XCTAssertTrue(session.showOriginalCurrencies)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AppSessionTests/test_updateShowOriginalCurrencies_publishesImmediatelyAndPersists`
Expected: FAIL to compile — `value of type 'AppSession' has no member 'showOriginalCurrencies'` (and no member `updateShowOriginalCurrencies`).

- [ ] **Step 3: Add the published property**

In `Sources/MyFin/AppSession.swift`, find:

```swift
    @Published private(set) var baseCurrency: Currency = .usd
    @Published private(set) var sidebarGroupingMode: SidebarGroupingMode = .institution
```

Replace with:

```swift
    @Published private(set) var baseCurrency: Currency = .usd
    @Published private(set) var sidebarGroupingMode: SidebarGroupingMode = .institution
    @Published private(set) var showOriginalCurrencies: Bool = false
```

- [ ] **Step 4: Load the value at profile creation and login**

This exact block appears twice in `Sources/MyFin/AppSession.swift` — once inside `createProfile(displayName:password:remember:)` (immediately followed by `refreshProfiles()`), once inside `logIn(profile:password:)` (immediately followed by `} catch DatabaseError.wrongPassword {`):

```swift
            self.baseCurrency = DashboardService(connection: connection, accountService: accountService, exchangeRateProvider: HardcodedExchangeRateProvider()).baseCurrency()
            let groupingRows = (try? connection.query("SELECT value FROM profile_settings WHERE key = 'sidebarGroupingMode';")) ?? []
            if case let .text(raw)? = groupingRows.first?["value"], let mode = SidebarGroupingMode(rawValue: raw) {
                self.sidebarGroupingMode = mode
            } else {
                self.sidebarGroupingMode = .institution
            }
            self.errorMessage = nil
```

Replace **both occurrences** with:

```swift
            self.baseCurrency = DashboardService(connection: connection, accountService: accountService, exchangeRateProvider: HardcodedExchangeRateProvider()).baseCurrency()
            let groupingRows = (try? connection.query("SELECT value FROM profile_settings WHERE key = 'sidebarGroupingMode';")) ?? []
            if case let .text(raw)? = groupingRows.first?["value"], let mode = SidebarGroupingMode(rawValue: raw) {
                self.sidebarGroupingMode = mode
            } else {
                self.sidebarGroupingMode = .institution
            }
            let originalCurrenciesRows = (try? connection.query("SELECT value FROM profile_settings WHERE key = 'showOriginalCurrencies';")) ?? []
            self.showOriginalCurrencies = (originalCurrenciesRows.first?["value"] == .text("true"))
            self.errorMessage = nil
```

Since `SQLValue` is `Equatable` with cases `.text(String)`, `.int(Int64)`, `.null`, comparing `originalCurrenciesRows.first?["value"]` (an `Optional<SQLValue>`) against `.text("true")` (auto-wrapped to `Optional<SQLValue>.some(.text("true"))`) is valid and correctly defaults to `false` when no row exists yet (comparing `nil == .text("true")` is `false`).

- [ ] **Step 5: Add the update method**

In `Sources/MyFin/AppSession.swift`, find:

```swift
    func updateSidebarGroupingMode(_ mode: SidebarGroupingMode) {
        guard let connection else { return }
        try? connection.execute(
            "INSERT INTO profile_settings (key, value) VALUES ('sidebarGroupingMode', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
            params: [.text(mode.rawValue)]
        )
        sidebarGroupingMode = mode
    }

    func changePassword(currentPassword: String, newPassword: String) {
```

Replace with:

```swift
    func updateSidebarGroupingMode(_ mode: SidebarGroupingMode) {
        guard let connection else { return }
        try? connection.execute(
            "INSERT INTO profile_settings (key, value) VALUES ('sidebarGroupingMode', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
            params: [.text(mode.rawValue)]
        )
        sidebarGroupingMode = mode
    }

    func updateShowOriginalCurrencies(_ show: Bool) {
        guard let connection else { return }
        try? connection.execute(
            "INSERT INTO profile_settings (key, value) VALUES ('showOriginalCurrencies', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
            params: [.text(show ? "true" : "false")]
        )
        showOriginalCurrencies = show
    }

    func changePassword(currentPassword: String, newPassword: String) {
```

- [ ] **Step 6: Run test to verify it passes**

Run: `swift test --filter AppSessionTests/test_updateShowOriginalCurrencies_publishesImmediatelyAndPersists`
Expected: PASS

- [ ] **Step 7: Run full test suite to confirm no regression**

Run: `swift test`
Expected: all tests pass (155 + 1 new = 156/156).

---

### Task 2: Settings UI — `BaseCurrencySelection` wrapper + 3-way segmented control

**Files:**
- Modify: `Sources/MyFin/Localization.swift`
- Modify: `Sources/MyFin/Views/SettingsView.swift`

**Interfaces:**
- Consumes: `session.baseCurrency: Currency`, `session.showOriginalCurrencies: Bool`, `session.updateBaseCurrency(_ currency: Currency)` (all pre-existing), `session.updateShowOriginalCurrencies(_ show: Bool)` (from Task 1).
- Produces: `enum BaseCurrencySelection: Hashable { case currency(Currency); case original }` (View-only, lives in `SettingsView.swift`, not consumed by any other task).

- [ ] **Step 1: Add the new localization key**

In `Sources/MyFin/Localization.swift`, find the tail of the `L10nKey` enum:

```swift
    case sidebarGroupingSectionTitle
    case sidebarGroupingModeFieldLabel
    case groupByInstitutionLabel
    case groupByCurrencyLabel
    case groupByCountryLabel
    case groupByTypeLabel
}
```

Replace with:

```swift
    case sidebarGroupingSectionTitle
    case sidebarGroupingModeFieldLabel
    case groupByInstitutionLabel
    case groupByCurrencyLabel
    case groupByCountryLabel
    case groupByTypeLabel
    case originalCurrenciesLabel
}
```

Find the tail of the `ru` dictionary:

```swift
        .groupByInstitutionLabel: "Банк",
        .groupByCurrencyLabel: "Валюта",
        .groupByCountryLabel: "Страна",
        .groupByTypeLabel: "Тип",
    ]

    static let en: [L10nKey: String] = [
```

Replace with:

```swift
        .groupByInstitutionLabel: "Банк",
        .groupByCurrencyLabel: "Валюта",
        .groupByCountryLabel: "Страна",
        .groupByTypeLabel: "Тип",
        .originalCurrenciesLabel: "Оригинальные валюты",
    ]

    static let en: [L10nKey: String] = [
```

Find the tail of the `en` dictionary:

```swift
        .groupByInstitutionLabel: "Bank",
        .groupByCurrencyLabel: "Currency",
        .groupByCountryLabel: "Country",
        .groupByTypeLabel: "Type",
    ]
}
```

Replace with:

```swift
        .groupByInstitutionLabel: "Bank",
        .groupByCurrencyLabel: "Currency",
        .groupByCountryLabel: "Country",
        .groupByTypeLabel: "Type",
        .originalCurrenciesLabel: "Original currencies",
    ]
}
```

- [ ] **Step 2: Build to confirm the localization change compiles**

Run: `swift build`
Expected: builds cleanly (no test yet — this is plain data, matching this codebase's existing convention of zero test coverage for localization string tables).

- [ ] **Step 3: Add the `BaseCurrencySelection` wrapper enum**

In `Sources/MyFin/Views/SettingsView.swift`, find:

```swift
enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case institutions

    var id: String { rawValue }
}
```

Replace with:

```swift
enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case institutions

    var id: String { rawValue }
}

enum BaseCurrencySelection: Hashable {
    case currency(Currency)
    case original
}
```

- [ ] **Step 4: Replace the `@State baseCurrency` with `@State baseCurrencySelection`**

In `Sources/MyFin/Views/SettingsView.swift`, find:

```swift
    @State private var baseCurrency: Currency = .usd
    @State private var numberFormatPreferences = NumberFormatPreferences()
    @State private var sidebarGroupingMode: SidebarGroupingMode = .institution
```

Replace with:

```swift
    @State private var baseCurrencySelection: BaseCurrencySelection = .currency(.usd)
    @State private var numberFormatPreferences = NumberFormatPreferences()
    @State private var sidebarGroupingMode: SidebarGroupingMode = .institution
```

- [ ] **Step 5: Replace the base-currency `Picker` with the 3-way segmented control**

In `Sources/MyFin/Views/SettingsView.swift`, find:

```swift
                    Section(preferences.string(.baseCurrencySectionTitle)) {
                        Picker(preferences.string(.baseCurrencyPickerLabel), selection: $baseCurrency) {
                            ForEach(Currency.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .onChange(of: baseCurrency) { newValue in
                            session.updateBaseCurrency(newValue)
                        }
                    }
```

Replace with:

```swift
                    Section(preferences.string(.baseCurrencySectionTitle)) {
                        Picker(preferences.string(.baseCurrencyPickerLabel), selection: $baseCurrencySelection) {
                            ForEach(Currency.allCases, id: \.self) { currency in
                                Text(currency.rawValue).tag(BaseCurrencySelection.currency(currency))
                            }
                            Text(preferences.string(.originalCurrenciesLabel)).tag(BaseCurrencySelection.original)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: baseCurrencySelection) { newValue in
                            switch newValue {
                            case .currency(let currency):
                                session.updateBaseCurrency(currency)
                                session.updateShowOriginalCurrencies(false)
                            case .original:
                                session.updateShowOriginalCurrencies(true)
                            }
                        }
                    }
```

- [ ] **Step 6: Update the `.onAppear` load block**

In `Sources/MyFin/Views/SettingsView.swift`, find:

```swift
        .onAppear {
            editedName = session.unlockedProfile?.displayName ?? ""
            editedIconName = session.unlockedProfile?.iconName ?? Profile.defaultIconName
            editedIconColor = session.unlockedProfile?.iconColor ?? Profile.defaultIconColor
            baseCurrency = session.baseCurrency
            numberFormatPreferences = session.numberFormatPreferences
            sidebarGroupingMode = session.sidebarGroupingMode
        }
```

Replace with:

```swift
        .onAppear {
            editedName = session.unlockedProfile?.displayName ?? ""
            editedIconName = session.unlockedProfile?.iconName ?? Profile.defaultIconName
            editedIconColor = session.unlockedProfile?.iconColor ?? Profile.defaultIconColor
            baseCurrencySelection = session.showOriginalCurrencies ? .original : .currency(session.baseCurrency)
            numberFormatPreferences = session.numberFormatPreferences
            sidebarGroupingMode = session.sidebarGroupingMode
        }
```

- [ ] **Step 7: Build to confirm SettingsView compiles**

Run: `swift build`
Expected: builds cleanly — no remaining references to the removed `baseCurrency` `@State` property anywhere in `SettingsView.swift` (the file has no other use of that name; `session.baseCurrency` on `AppSession` itself is untouched and still valid).

- [ ] **Step 8: Run full test suite to confirm no regression**

Run: `swift test`
Expected: 156/156 passing (no new tests in this task — consistent with this codebase's zero View-level XCTest coverage, per the approved spec's Testing section).

---

### Task 3: `DashboardView` original-currencies breakdown

**Files:**
- Modify: `Sources/MyFin/Views/DashboardView.swift`
- Modify: `Sources/MyFin/Views/MainShellView.swift`

**Interfaces:**
- Consumes: `session.showOriginalCurrencies: Bool` (from Task 1), `AccountsListModel.groupedByCurrency() -> [AccountGroup]` (pre-existing, unchanged), `AccountGroup.total: Decimal` and `AccountGroup.displayCurrency: Currency` (pre-existing, unchanged), `MainShellView`'s existing `@StateObject private var accountsModel: AccountsListModel`.
- Produces: `DashboardView.init(session: AppSession, model: AccountsListModel)` — no other task depends on this.

- [ ] **Step 1: Add the `model` dependency and the original-currencies branch to `DashboardView`**

Replace the full current content of `Sources/MyFin/Views/DashboardView.swift`:

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

with:

```swift
import SwiftUI

struct DashboardView: View {
    @ObservedObject var session: AppSession
    @ObservedObject var model: AccountsListModel
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
            if session.showOriginalCurrencies {
                VStack(spacing: 6) {
                    ForEach(model.groupedByCurrency()) { group in
                        Text("\(NumberDisplayFormatter.format(group.total, preferences: session.numberFormatPreferences)) \(group.displayCurrency.rawValue)")
                            .font(.system(size: 28, weight: .bold))
                    }
                }
            } else {
                Text("\(NumberDisplayFormatter.format(total, preferences: session.numberFormatPreferences)) \(session.baseCurrency.rawValue)").font(.system(size: 40, weight: .bold))
            }
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

`reload()` intentionally stays unconditional: it costs nothing extra to keep `total` fresh even while the original-currencies branch is showing, and it means switching back to a fixed currency shows an up-to-date number immediately without needing a new code path.

- [ ] **Step 2: Update the call site in `MainShellView`**

In `Sources/MyFin/Views/MainShellView.swift`, find:

```swift
            case .dashboard:
                DashboardView(session: session)
```

Replace with:

```swift
            case .dashboard:
                DashboardView(session: session, model: accountsModel)
```

- [ ] **Step 3: Build to confirm both files compile**

Run: `swift build`
Expected: builds cleanly.

- [ ] **Step 4: Run full test suite to confirm no regression**

Run: `swift test`
Expected: 156/156 passing (no new tests in this task — consistent with this codebase's zero View-level XCTest coverage; `AccountsListModel.groupedByCurrency()` itself already has coverage from the sidebar-grouping-modes feature).

- [ ] **Step 5: Manual verification in the running app**

Run: `swift run` (this step needs the human).

Walk through:
1. Open Settings → General. Confirm the base-currency control now shows three segments: USD, KZT, "Оригинальные валюты".
2. Select "Оригинальные валюты". Go to Dashboard — confirm it now shows a per-currency breakdown (one line per currency in use across active accounts) instead of one converted number.
3. Confirm the sidebar's Институт/Страна/Тип grouping modes still show one converted sum each, unaffected by the toggle.
4. Switch back to USD or KZT in Settings — confirm the Dashboard reverts to the single converted total, and that number is correct.
5. Log out and log back into the same profile with "Оригинальные валюты" selected — confirm the setting persisted (Settings still shows it selected, Dashboard still shows the breakdown).

---

## Self-Review Notes

- **Spec coverage:** `showOriginalCurrencies` field + persistence (Task 1) ✓; Settings 3-way control with `BaseCurrencySelection` (Task 2) ✓; Dashboard breakdown via `model.groupedByCurrency()`, other consumers of `baseCurrency` untouched (Task 3) ✓; new `AppSessionTests` case (Task 1) ✓; no new View-level tests (matches spec) ✓.
- **Placeholder scan:** none found — every step has literal before/after code.
- **Type consistency:** `showOriginalCurrencies: Bool` (Task 1) matches every later reference (`session.showOriginalCurrencies` in Tasks 2 and 3); `updateShowOriginalCurrencies(_ show: Bool)` (Task 1) matches its two call sites in Task 2; `BaseCurrencySelection` (Task 2) is consumed only within Task 2, no cross-task signature drift; `DashboardView.init(session:model:)` (Task 3) matches its one call site update in the same task.
