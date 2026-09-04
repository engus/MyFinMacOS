# Number Format Preferences Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user choose, per profile, how numbers display everywhere MyFin shows one today (decimal separator, max decimal places, full/compact large-number notation, hide/show trailing zeroes) without changing any stored or calculated `Decimal` value.

**Architecture:** A pure `NumberDisplayFormatter.format(_:preferences:)` function does all the string formatting. A `NumberFormatPreferences` struct holds the 4 choices; `NumberFormatPreferencesService` persists it per-profile in the existing `profile_settings` table (same pattern `DashboardService.baseCurrency()` already uses). `AppSession` holds a live `@Published numberFormatPreferences`, loaded at login/profile-creation and updated by a new `updateNumberFormatPreferences(_:)` method, so every view already observing `session` (Dashboard, Accounts list, the always-mounted sidebar) re-renders immediately when it changes. The 3 places MyFin currently displays a number call the formatter; a new Settings section lets the user change the 4 preferences.

**Tech Stack:** Swift 5.9, SwiftUI, SQLCipher.swift, XCTest, Swift Package Manager (no Xcode project).

**Spec:** `docs/superpowers/specs/2026-09-04-myfin-number-format-preferences-design.md`

## Global Constraints

- **No git** in this project (neither `MyFinLocal/` nor `MyFinLocal/MyFin/` is a git repository) — never run `git` commands; every "Commit" step below is skipped, left in the template only where the plan format requires it.
- **Swift toolchain is available and verified working in this environment** — run every `swift build` / `swift test` step yourself, directly via Bash, from `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin`. Only the final manual look-at-the-running-app step (explicitly marked "Hand to human partner") needs the human.
- **Compact-notation thresholds are confirmed as `≥ 1_000` → K, `≥ 1_000_000` → M, `≥ 1_000_000_000` → B, uniformly** — `1500` under compact notation is `"1,5K"`. This overrides two of the three worked examples in the original (web-app) product brief, which the user explicitly confirmed superseded (see spec's Section 4 note).
- **All arithmetic stays in `Decimal`, never `Double`/`Float`** — matches this codebase's existing money-handling rule (`AccountService`/`DashboardService` never use `REAL` for a monetary value either).
- **Money is per-profile** — this feature's 4 settings are stored in each profile's own encrypted SQLite database (`profile_settings` table), not in `UserDefaults` (unlike `AppPreferences`'s theme/language, which are machine-wide) — confirmed with the user.
- Only Russian and English localized strings are added; no existing key's value changes.
- No automated tests for `SettingsView`/`DashboardView`/`AccountsListView`/`MainShellView` themselves — consistent with this codebase's existing convention of zero View-level XCTest coverage. Verified by `swift build` + `swift test` + a manual look at the running app.

## File Structure

- Create: `Sources/MyFin/Models/NumberFormatPreferences.swift` — the 4-field struct (Task 1).
- Create: `Sources/MyFin/Services/NumberFormatPreferencesService.swift` — per-profile persistence (Task 1).
- Test: `Tests/MyFinTests/NumberFormatPreferencesServiceTests.swift` (Task 1).
- Create: `Sources/MyFin/Services/NumberDisplayFormatter.swift` — pure formatting logic (Task 2).
- Test: `Tests/MyFinTests/NumberDisplayFormatterTests.swift` (Task 2).
- Modify: `Sources/MyFin/AppSession.swift` — `numberFormatPreferences` published property + `updateNumberFormatPreferences(_:)` (Task 3).
- Modify: `Tests/MyFinTests/AppSessionTests.swift` (Task 3).
- Modify: `Sources/MyFin/Views/DashboardView.swift`, `Sources/MyFin/Views/AccountsListView.swift`, `Sources/MyFin/Views/MainShellView.swift` — wire the formatter into the 3 real display sites (Task 4).
- Modify: `Sources/MyFin/Localization.swift` — 9 new `L10nKey` cases + ru/en entries (Task 5).
- Modify: `Tests/MyFinTests/LocalizationTests.swift` (Task 5).
- Modify: `Sources/MyFin/Views/SettingsView.swift` — new "Формат чисел" section (Task 6).

---

### Task 1: `NumberFormatPreferences` model + `NumberFormatPreferencesService`

**Files:**
- Create: `Sources/MyFin/Models/NumberFormatPreferences.swift`
- Create: `Sources/MyFin/Services/NumberFormatPreferencesService.swift`
- Test: `Tests/MyFinTests/NumberFormatPreferencesServiceTests.swift`

**Interfaces:**
- Consumes: existing `DatabaseConnection(query:params:)` / `.execute(_:params:)` / `.withTransaction(_:)`, existing `profile_settings` table (already used by `DashboardService.baseCurrency()`/`.setBaseCurrency(_:)`).
- Produces (for every later task):
  - `struct NumberFormatPreferences: Equatable { var useCommaDecimalSeparator: Bool = false; var maxDecimalPlaces: Int = 2; var useCompactNotation: Bool = false; var hideTrailingZeroes: Bool = true }`
  - `final class NumberFormatPreferencesService { init(connection: DatabaseConnection); func load() -> NumberFormatPreferences; func save(_ preferences: NumberFormatPreferences) throws }`

- [x] **Step 1: Write the failing tests**

Create `Tests/MyFinTests/NumberFormatPreferencesServiceTests.swift`:

```swift
import XCTest
@testable import MyFin

final class NumberFormatPreferencesServiceTests: XCTestCase {
    private func makeService() throws -> NumberFormatPreferencesService {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        let connection = try DatabaseConnection.open(at: url, password: "pw")
        return NumberFormatPreferencesService(connection: connection)
    }

    func test_load_onFreshConnection_returnsDefaults() throws {
        let service = try makeService()
        XCTAssertEqual(service.load(), NumberFormatPreferences())
    }

    func test_save_thenLoad_roundTripsAllFields() throws {
        let service = try makeService()
        let preferences = NumberFormatPreferences(
            useCommaDecimalSeparator: true,
            maxDecimalPlaces: 0,
            useCompactNotation: true,
            hideTrailingZeroes: false
        )
        try service.save(preferences)
        XCTAssertEqual(service.load(), preferences)
    }

    func test_save_thenLoad_roundTripsOnePlaceVariant() throws {
        let service = try makeService()
        let preferences = NumberFormatPreferences(
            useCommaDecimalSeparator: false,
            maxDecimalPlaces: 1,
            useCompactNotation: false,
            hideTrailingZeroes: true
        )
        try service.save(preferences)
        XCTAssertEqual(service.load(), preferences)
    }
}
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter MyFinTests.NumberFormatPreferencesServiceTests`
Expected: build failure — neither `NumberFormatPreferences` nor `NumberFormatPreferencesService` exist yet.

- [x] **Step 3: Create the model**

Create `Sources/MyFin/Models/NumberFormatPreferences.swift`:

```swift
import Foundation

struct NumberFormatPreferences: Equatable {
    var useCommaDecimalSeparator: Bool = false
    var maxDecimalPlaces: Int = 2
    var useCompactNotation: Bool = false
    var hideTrailingZeroes: Bool = true
}
```

- [x] **Step 4: Create the service**

Create `Sources/MyFin/Services/NumberFormatPreferencesService.swift`:

```swift
import Foundation

final class NumberFormatPreferencesService {
    private let connection: DatabaseConnection

    private static let decimalSeparatorKey = "numberFormatDecimalSeparator"
    private static let maxDecimalPlacesKey = "numberFormatMaxDecimalPlaces"
    private static let notationKey = "numberFormatNotation"
    private static let hideTrailingZeroesKey = "numberFormatHideTrailingZeroes"

    init(connection: DatabaseConnection) {
        self.connection = connection
    }

    func load() -> NumberFormatPreferences {
        let rows = (try? connection.query(
            "SELECT key, value FROM profile_settings WHERE key IN (?, ?, ?, ?);",
            params: [
                .text(Self.decimalSeparatorKey), .text(Self.maxDecimalPlacesKey),
                .text(Self.notationKey), .text(Self.hideTrailingZeroesKey)
            ]
        )) ?? []

        var values: [String: String] = [:]
        for row in rows {
            if case let .text(key)? = row["key"], case let .text(value)? = row["value"] {
                values[key] = value
            }
        }

        var preferences = NumberFormatPreferences()
        if let raw = values[Self.decimalSeparatorKey] {
            preferences.useCommaDecimalSeparator = (raw == "comma")
        }
        if let raw = values[Self.maxDecimalPlacesKey], let places = Int(raw), (0...2).contains(places) {
            preferences.maxDecimalPlaces = places
        }
        if let raw = values[Self.notationKey] {
            preferences.useCompactNotation = (raw == "compact")
        }
        if let raw = values[Self.hideTrailingZeroesKey] {
            preferences.hideTrailingZeroes = (raw == "true")
        }
        return preferences
    }

    func save(_ preferences: NumberFormatPreferences) throws {
        try connection.withTransaction {
            try connection.execute(
                "INSERT INTO profile_settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
                params: [.text(Self.decimalSeparatorKey), .text(preferences.useCommaDecimalSeparator ? "comma" : "period")]
            )
            try connection.execute(
                "INSERT INTO profile_settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
                params: [.text(Self.maxDecimalPlacesKey), .text(String(preferences.maxDecimalPlaces))]
            )
            try connection.execute(
                "INSERT INTO profile_settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
                params: [.text(Self.notationKey), .text(preferences.useCompactNotation ? "compact" : "full")]
            )
            try connection.execute(
                "INSERT INTO profile_settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
                params: [.text(Self.hideTrailingZeroesKey), .text(preferences.hideTrailingZeroes ? "true" : "false")]
            )
        }
    }
}
```

- [x] **Step 5: Run the tests to verify they pass**

Run: `swift test --filter MyFinTests.NumberFormatPreferencesServiceTests`
Expected: all 3 new tests pass.

- [x] **Step 6: Run the full test suite**

Run: `swift test`
Expected: all 109 previously-passing tests still pass, plus the 3 new ones (112 total).

- [x] **Step 7: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 2: `NumberDisplayFormatter`

**Files:**
- Create: `Sources/MyFin/Services/NumberDisplayFormatter.swift`
- Test: `Tests/MyFinTests/NumberDisplayFormatterTests.swift`

**Interfaces:**
- Consumes: `NumberFormatPreferences` (Task 1).
- Produces (for Task 4): `NumberDisplayFormatter.format(_ value: Decimal, preferences: NumberFormatPreferences) -> String`.

- [x] **Step 1: Write the failing tests**

Create `Tests/MyFinTests/NumberDisplayFormatterTests.swift`:

```swift
import XCTest
@testable import MyFin

final class NumberDisplayFormatterTests: XCTestCase {
    func test_wholeNumber_periodSeparator_hidesTrailingZeroes() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: false, maxDecimalPlaces: 2, useCompactNotation: false, hideTrailingZeroes: true)
        XCTAssertEqual(NumberDisplayFormatter.format(1500, preferences: preferences), "1 500")
    }

    func test_wholeNumber_showsTrailingZeroesWhenNotHidden() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: false, maxDecimalPlaces: 2, useCompactNotation: false, hideTrailingZeroes: false)
        XCTAssertEqual(NumberDisplayFormatter.format(1500, preferences: preferences), "1 500.00")
    }

    func test_nonZeroFractional_periodSeparator_isKept() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: false, maxDecimalPlaces: 2, useCompactNotation: false, hideTrailingZeroes: true)
        XCTAssertEqual(NumberDisplayFormatter.format(Decimal(string: "1500.25")!, preferences: preferences), "1 500.25")
    }

    func test_commaSeparator_groupingStaysSpace() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: true, maxDecimalPlaces: 2, useCompactNotation: false, hideTrailingZeroes: true)
        XCTAssertEqual(NumberDisplayFormatter.format(Decimal(string: "1500.25")!, preferences: preferences), "1 500,25")
    }

    func test_compactNotation_thousandThreshold_matchesConfirmedResolution() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: true, maxDecimalPlaces: 2, useCompactNotation: true, hideTrailingZeroes: true)
        XCTAssertEqual(NumberDisplayFormatter.format(1500, preferences: preferences), "1,5K")
    }

    func test_compactNotation_millionThreshold() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: true, maxDecimalPlaces: 2, useCompactNotation: true, hideTrailingZeroes: true)
        XCTAssertEqual(NumberDisplayFormatter.format(1_500_000, preferences: preferences), "1,5M")
    }

    func test_compactNotation_billionThreshold() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: false, maxDecimalPlaces: 2, useCompactNotation: true, hideTrailingZeroes: true)
        XCTAssertEqual(NumberDisplayFormatter.format(2_500_000_000, preferences: preferences), "2.5B")
    }

    func test_compactNotation_belowThousand_noSuffixApplied() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: false, maxDecimalPlaces: 0, useCompactNotation: true, hideTrailingZeroes: true)
        XCTAssertEqual(NumberDisplayFormatter.format(999, preferences: preferences), "999")
    }

    func test_maxDecimalPlacesZero_neverShowsFraction_andRoundsUp() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: false, maxDecimalPlaces: 0, useCompactNotation: false, hideTrailingZeroes: false)
        XCTAssertEqual(NumberDisplayFormatter.format(Decimal(string: "1500.99")!, preferences: preferences), "1 501")
    }

    func test_maxDecimalPlacesOne_roundsAndKeepsNonZeroDigit() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: false, maxDecimalPlaces: 1, useCompactNotation: false, hideTrailingZeroes: true)
        XCTAssertEqual(NumberDisplayFormatter.format(Decimal(string: "1500.26")!, preferences: preferences), "1 500.3")
    }

    func test_zero() {
        let preferences = NumberFormatPreferences()
        XCTAssertEqual(NumberDisplayFormatter.format(0, preferences: preferences), "0")
    }

    func test_negativeValue_keepsSign() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: false, maxDecimalPlaces: 2, useCompactNotation: false, hideTrailingZeroes: true)
        XCTAssertEqual(NumberDisplayFormatter.format(-1500, preferences: preferences), "-1 500")
    }

    func test_smallFractionalOnly_keepsLeadingZeroInteger() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: false, maxDecimalPlaces: 2, useCompactNotation: false, hideTrailingZeroes: true)
        XCTAssertEqual(NumberDisplayFormatter.format(Decimal(string: "0.05")!, preferences: preferences), "0.05")
    }
}
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter MyFinTests.NumberDisplayFormatterTests`
Expected: build failure — `NumberDisplayFormatter` does not exist yet.

- [x] **Step 3: Create the formatter**

Create `Sources/MyFin/Services/NumberDisplayFormatter.swift`:

```swift
import Foundation

enum NumberDisplayFormatter {
    static func format(_ value: Decimal, preferences: NumberFormatPreferences) -> String {
        let isNegative = value < 0
        var magnitude = isNegative ? -value : value

        var suffix = ""
        if preferences.useCompactNotation {
            let billion = Decimal(1_000_000_000)
            let million = Decimal(1_000_000)
            let thousand = Decimal(1_000)
            if magnitude >= billion {
                magnitude /= billion
                suffix = "B"
            } else if magnitude >= million {
                magnitude /= million
                suffix = "M"
            } else if magnitude >= thousand {
                magnitude /= thousand
                suffix = "K"
            }
        }

        let (integerPart, fractionalPart) = splitDigits(magnitude, places: preferences.maxDecimalPlaces)

        var fractional = fractionalPart
        if preferences.hideTrailingZeroes {
            while fractional.hasSuffix("0") {
                fractional.removeLast()
            }
        }

        let separator = preferences.useCommaDecimalSeparator ? "," : "."
        var result = groupThousands(integerPart)
        if !fractional.isEmpty {
            result += separator + fractional
        }
        result += suffix
        if isNegative {
            result = "-" + result
        }
        return result
    }

    private static func splitDigits(_ magnitude: Decimal, places: Int) -> (integer: String, fractional: String) {
        var scale = Decimal(1)
        for _ in 0..<places { scale *= 10 }

        var scaled = magnitude * scale
        var scaledRounded = Decimal()
        NSDecimalRound(&scaledRounded, &scaled, 0, .plain)

        var digits = "\(scaledRounded)"
        while digits.count < places + 1 {
            digits = "0" + digits
        }

        guard places > 0 else { return (digits, "") }

        let splitIndex = digits.index(digits.endIndex, offsetBy: -places)
        return (String(digits[digits.startIndex..<splitIndex]), String(digits[splitIndex...]))
    }

    private static func groupThousands(_ digits: String) -> String {
        var result = ""
        for (index, character) in digits.reversed().enumerated() {
            if index > 0 && index.isMultiple(of: 3) {
                result = " " + result
            }
            result = String(character) + result
        }
        return result
    }
}
```

- [x] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter MyFinTests.NumberDisplayFormatterTests`
Expected: all 13 new tests pass.

- [x] **Step 5: Run the full test suite**

Run: `swift test`
Expected: 112 + 13 = 125 tests pass, 0 failures.

- [x] **Step 6: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 3: `AppSession` wiring

**Files:**
- Modify: `Sources/MyFin/AppSession.swift`
- Test: `Tests/MyFinTests/AppSessionTests.swift`

**Interfaces:**
- Consumes: `NumberFormatPreferencesService` (Task 1), `NumberFormatPreferences` (Task 1).
- Produces (for Tasks 4 and 6): `AppSession.numberFormatPreferences: NumberFormatPreferences` (published, read-only from outside), `AppSession.updateNumberFormatPreferences(_ preferences: NumberFormatPreferences)`.

- [x] **Step 1: Write the failing test**

Add to `Tests/MyFinTests/AppSessionTests.swift`, inside `AppSessionTests`:

```swift
    func test_updateNumberFormatPreferences_publishesImmediatelyAndPersists() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)
        let updated = NumberFormatPreferences(
            useCommaDecimalSeparator: true, maxDecimalPlaces: 0, useCompactNotation: true, hideTrailingZeroes: false
        )

        session.updateNumberFormatPreferences(updated)
        XCTAssertEqual(session.numberFormatPreferences, updated)

        let profile = session.profiles[0]
        session.logOut()
        session.logIn(profile: profile, password: "pw1")
        XCTAssertEqual(session.numberFormatPreferences, updated)
    }
```

- [x] **Step 2: Run the test to verify it fails**

Run: `swift test --filter MyFinTests.AppSessionTests`
Expected: build failure — `AppSession` has no member `numberFormatPreferences`/`updateNumberFormatPreferences`.

- [x] **Step 3: Add the property and loading points**

In `Sources/MyFin/AppSession.swift`, add the published property next to the existing ones:

```swift
    @Published var screen: Screen = .profilePicker
    @Published var profiles: [Profile] = []
    @Published var errorMessage: String?
    @Published private(set) var numberFormatPreferences = NumberFormatPreferences()
```

In `createProfile(...)`, change:

```swift
            self.connection = connection
            self.unlockedProfile = profile
            self.errorMessage = nil
            self.screen = profile.hasCompletedOnboarding ? .mainShell : .onboarding
            refreshProfiles()
```

to:

```swift
            self.connection = connection
            self.unlockedProfile = profile
            self.numberFormatPreferences = NumberFormatPreferencesService(connection: connection).load()
            self.errorMessage = nil
            self.screen = profile.hasCompletedOnboarding ? .mainShell : .onboarding
            refreshProfiles()
```

In `logIn(...)`, change:

```swift
            let connection = try DatabaseConnection.open(at: profileStore.databaseURL(for: profile.id), password: password)
            self.connection = connection
            self.unlockedProfile = profile
            self.errorMessage = nil
            self.screen = profile.hasCompletedOnboarding ? .mainShell : .onboarding
```

to:

```swift
            let connection = try DatabaseConnection.open(at: profileStore.databaseURL(for: profile.id), password: password)
            self.connection = connection
            self.unlockedProfile = profile
            self.numberFormatPreferences = NumberFormatPreferencesService(connection: connection).load()
            self.errorMessage = nil
            self.screen = profile.hasCompletedOnboarding ? .mainShell : .onboarding
```

- [x] **Step 4: Add `updateNumberFormatPreferences(_:)`**

In `Sources/MyFin/AppSession.swift`, add this method right after `updateProfile(...)`:

```swift
    func updateNumberFormatPreferences(_ preferences: NumberFormatPreferences) {
        guard let connection else { return }
        try? NumberFormatPreferencesService(connection: connection).save(preferences)
        numberFormatPreferences = preferences
    }
```

- [x] **Step 5: Run the test to verify it passes**

Run: `swift test --filter MyFinTests.AppSessionTests`
Expected: all `AppSessionTests` pass, including the new one.

- [x] **Step 6: Run the full test suite**

Run: `swift test`
Expected: 125 + 1 = 126 tests pass.

- [x] **Step 7: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 4: Wire the formatter into the 3 real display sites

**Files:**
- Modify: `Sources/MyFin/Views/DashboardView.swift`
- Modify: `Sources/MyFin/Views/AccountsListView.swift`
- Modify: `Sources/MyFin/Views/MainShellView.swift`

**Interfaces:**
- Consumes: `NumberDisplayFormatter.format(_:preferences:)` (Task 2), `session.numberFormatPreferences` (Task 3).
- Produces: `AccountRowView` (private struct in `AccountsListView.swift`) gains a new required `let numberFormatPreferences: NumberFormatPreferences` stored property — both of its construction call sites must be updated in this same task or the build breaks.

- [x] **Step 1: Dashboard total**

In `Sources/MyFin/Views/DashboardView.swift`, change:

```swift
            Text("\(total) \(displayCurrency.rawValue)").font(.system(size: 40, weight: .bold))
```

to:

```swift
            Text("\(NumberDisplayFormatter.format(total, preferences: session.numberFormatPreferences)) \(displayCurrency.rawValue)").font(.system(size: 40, weight: .bold))
```

- [x] **Step 2: Accounts page row**

In `Sources/MyFin/Views/AccountsListView.swift`, add the new property to `AccountRowView`:

```swift
private struct AccountRowView: View {
    let account: Account
    let institutionOrCountryLabel: String
    let numberFormatPreferences: NumberFormatPreferences
    let onEdit: () -> Void
    let onToggleArchive: () -> Void
```

Change its body's balance line:

```swift
            Text("\(account.openingBalance)")
```

to:

```swift
            Text(NumberDisplayFormatter.format(account.openingBalance, preferences: numberFormatPreferences))
```

Update **both** construction call sites inside `AccountsListView.body` (the active-accounts `Section` and the archived-accounts `Section`) — each currently reads:

```swift
                                AccountRowView(
                                    account: account,
                                    institutionOrCountryLabel: institutionOrCountryLabel(for: account),
                                    onEdit: { editingAccount = account },
                                    onToggleArchive: { toggleArchive(account) }
                                )
```

change **both** occurrences to:

```swift
                                AccountRowView(
                                    account: account,
                                    institutionOrCountryLabel: institutionOrCountryLabel(for: account),
                                    numberFormatPreferences: session.numberFormatPreferences,
                                    onEdit: { editingAccount = account },
                                    onToggleArchive: { toggleArchive(account) }
                                )
```

- [x] **Step 3: Sidebar row**

In `Sources/MyFin/Views/MainShellView.swift`, change:

```swift
                                        Text("\(account.openingBalance) \(account.currency.rawValue)")
                                            .foregroundStyle(.secondary)
```

to:

```swift
                                        Text("\(NumberDisplayFormatter.format(account.openingBalance, preferences: session.numberFormatPreferences)) \(account.currency.rawValue)")
                                            .foregroundStyle(.secondary)
```

- [x] **Step 4: Build**

Run: `swift build`
Expected: build succeeds with no errors.

- [x] **Step 5: Run the full test suite**

Run: `swift test`
Expected: all 126 tests still pass.

- [x] **Step 6: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 5: Localization — 9 new keys

**Files:**
- Modify: `Sources/MyFin/Localization.swift`
- Test: `Tests/MyFinTests/LocalizationTests.swift`

**Interfaces:**
- Produces (for Task 6): `L10nKey` cases `.numberFormatSectionTitle`, `.decimalSeparatorFieldLabel`, `.maxDecimalPlacesFieldLabel`, `.largeNumberNotationFieldLabel`, `.trailingZeroesFieldLabel`, `.notationFullLabel`, `.notationCompactLabel`, `.trailingZeroesShowLabel`, `.trailingZeroesHideLabel`.

- [x] **Step 1: Write the failing tests**

Add to `Tests/MyFinTests/LocalizationTests.swift`, inside `LocalizationTests`:

```swift
    func test_numberFormatSectionTitle_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.numberFormatSectionTitle], "Формат чисел")
    }

    func test_decimalSeparatorFieldLabel_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.decimalSeparatorFieldLabel], "Разделитель дробной части")
    }

    func test_maxDecimalPlacesFieldLabel_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.maxDecimalPlacesFieldLabel], "Знаков после запятой")
    }

    func test_largeNumberNotationFieldLabel_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.largeNumberNotationFieldLabel], "Крупные числа")
    }

    func test_trailingZeroesFieldLabel_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.trailingZeroesFieldLabel], "Незначащие нули")
    }

    func test_notationFullLabel_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.notationFullLabel], "Полностью")
    }

    func test_notationCompactLabel_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.notationCompactLabel], "Сокращённо")
    }

    func test_trailingZeroesShowLabel_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.trailingZeroesShowLabel], "Показывать")
    }

    func test_trailingZeroesHideLabel_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.trailingZeroesHideLabel], "Скрывать")
    }
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter MyFinTests.LocalizationTests`
Expected: build failure — the 9 new `L10nKey` cases don't exist yet.

- [x] **Step 3: Add the new keys**

In `Sources/MyFin/Localization.swift`, add to the `L10nKey` enum (anywhere in the case list, e.g. right after `.archivedAccountsSectionTitle`):

```swift
    case numberFormatSectionTitle
    case decimalSeparatorFieldLabel
    case maxDecimalPlacesFieldLabel
    case largeNumberNotationFieldLabel
    case trailingZeroesFieldLabel
    case notationFullLabel
    case notationCompactLabel
    case trailingZeroesShowLabel
    case trailingZeroesHideLabel
```

Add to the `ru` dictionary (anywhere, e.g. right after `.archivedAccountsSectionTitle: "Архивные счета",`):

```swift
        .numberFormatSectionTitle: "Формат чисел",
        .decimalSeparatorFieldLabel: "Разделитель дробной части",
        .maxDecimalPlacesFieldLabel: "Знаков после запятой",
        .largeNumberNotationFieldLabel: "Крупные числа",
        .trailingZeroesFieldLabel: "Незначащие нули",
        .notationFullLabel: "Полностью",
        .notationCompactLabel: "Сокращённо",
        .trailingZeroesShowLabel: "Показывать",
        .trailingZeroesHideLabel: "Скрывать",
```

Add to the `en` dictionary (same position, mirroring the `ru` block above):

```swift
        .numberFormatSectionTitle: "Number format",
        .decimalSeparatorFieldLabel: "Decimal separator",
        .maxDecimalPlacesFieldLabel: "Decimal places",
        .largeNumberNotationFieldLabel: "Large numbers",
        .trailingZeroesFieldLabel: "Trailing zeroes",
        .notationFullLabel: "Full",
        .notationCompactLabel: "Compact",
        .trailingZeroesShowLabel: "Show",
        .trailingZeroesHideLabel: "Hide",
```

- [x] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter MyFinTests.LocalizationTests`
Expected: all `LocalizationTests` pass, including the 9 new ones.

- [x] **Step 5: Run the full test suite**

Run: `swift test`
Expected: all 126 previously-passing tests still pass, plus the 9 new ones (135 total).

- [x] **Step 6: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 6: Settings UI — "Формат чисел" section

**Files:**
- Modify: `Sources/MyFin/Views/SettingsView.swift`

**Interfaces:**
- Consumes: `NumberFormatPreferences` (Task 1), `session.numberFormatPreferences` / `session.updateNumberFormatPreferences(_:)` (Task 3), the 9 new `L10nKey` cases (Task 5).
- Produces: none — this is the final task in this plan.

- [x] **Step 1: Add the state property**

In `Sources/MyFin/Views/SettingsView.swift`, add next to `baseCurrency`:

```swift
    @State private var baseCurrency: Currency = .usd
    @State private var numberFormatPreferences = NumberFormatPreferences()
```

- [x] **Step 2: Add the new Section**

Change:

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

                    Section {
                        Button(preferences.string(.logOutButton), role: .destructive) {
                            session.logOut()
                        }
                    }
```

to:

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

                    Section(preferences.string(.numberFormatSectionTitle)) {
                        Picker(preferences.string(.decimalSeparatorFieldLabel), selection: $numberFormatPreferences.useCommaDecimalSeparator) {
                            Text(".").tag(false)
                            Text(",").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: numberFormatPreferences.useCommaDecimalSeparator) { _ in
                            session.updateNumberFormatPreferences(numberFormatPreferences)
                        }

                        Picker(preferences.string(.maxDecimalPlacesFieldLabel), selection: $numberFormatPreferences.maxDecimalPlaces) {
                            Text("0").tag(0)
                            Text("1").tag(1)
                            Text("2").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: numberFormatPreferences.maxDecimalPlaces) { _ in
                            session.updateNumberFormatPreferences(numberFormatPreferences)
                        }

                        Picker(preferences.string(.largeNumberNotationFieldLabel), selection: $numberFormatPreferences.useCompactNotation) {
                            Text(preferences.string(.notationFullLabel)).tag(false)
                            Text(preferences.string(.notationCompactLabel)).tag(true)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: numberFormatPreferences.useCompactNotation) { _ in
                            session.updateNumberFormatPreferences(numberFormatPreferences)
                        }

                        Picker(preferences.string(.trailingZeroesFieldLabel), selection: $numberFormatPreferences.hideTrailingZeroes) {
                            Text(preferences.string(.trailingZeroesShowLabel)).tag(false)
                            Text(preferences.string(.trailingZeroesHideLabel)).tag(true)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: numberFormatPreferences.hideTrailingZeroes) { _ in
                            session.updateNumberFormatPreferences(numberFormatPreferences)
                        }
                    }

                    Section {
                        Button(preferences.string(.logOutButton), role: .destructive) {
                            session.logOut()
                        }
                    }
```

- [x] **Step 3: Load it in `.onAppear`**

Change:

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
        }
```

to:

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

- [x] **Step 4: Build**

Run: `swift build`
Expected: build succeeds with no errors.

- [x] **Step 5: Run the full test suite**

Run: `swift test`
Expected: all 135 tests still pass.

- [ ] **Step 6: Manual look at the running app**

Hand to human partner. Run: `swift run` from `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin`
Ask them to: open Settings → Общее, confirm a new "Формат чисел" section appears (after "Базовая валюта", before "Выйти") with 4 segmented controls; change the decimal separator to comma and confirm the Dashboard total, an account row on "Счета", and the sidebar's account row all immediately show the comma (no need to navigate away and back — the sidebar especially, since it stays mounted); switch large numbers to "Сокращённо" with an account balance ≥ 1000 and confirm it shows a `K`/`M`/`B` suffix; toggle "Незначащие нули" to "Показывать" and confirm a whole-number balance now shows trailing zeroes (e.g. "1 500,00"); change decimal places to 0 and confirm no decimal point shows anywhere; quit and relaunch the app, log back into the same profile, and confirm all 4 choices were remembered.
Expected: everything above behaves as described.

- [x] **Step 7: Commit**

Skipped — this project does not use git (see Global Constraints).

---

## Self-Review Notes

- **Spec coverage:** Section 1 (model) + Section 2 (persistence) → Task 1. Section 4 (formatter algorithm, including the confirmed K-from-1000 resolution) → Task 2. Section 3 (live sync via `AppSession`) → Task 3. Section 5 (the 3 real display sites) → Task 4. New localization keys → Task 5. Section 6 (Settings UI) → Task 6. The spec's "Out of scope" items (Cashflow/Assets, charts/percentages/FX/summary counts, form controls, export files, cross-device sync) are respected — nothing in any task touches `AccountFormView`'s balance `TextField`, and no chart/percentage code exists to touch.
- **No placeholders:** every step has complete, exact code — including the full `NumberDisplayFormatter` algorithm (no "add rounding logic here" gaps) and both `AccountRowView` call-site updates spelled out individually rather than "update both similarly."
- **Type/name consistency checked:** `NumberFormatPreferences`'s 4 field names (Task 1) are used identically in `NumberDisplayFormatter` (Task 2), `AppSession` (Task 3), all 3 view call sites (Task 4), and the Settings Pickers' bindings (Task 6) — no renaming drift anywhere. `NumberDisplayFormatter.format(_:preferences:)`'s signature (Task 2) matches every call site in Task 4 exactly. `session.numberFormatPreferences` / `session.updateNumberFormatPreferences(_:)` (Task 3) are the exact names used in Tasks 4 and 6.
- **Hand-verified formatter test expectations:** every expected string in Task 2's test file was traced through the algorithm by hand while writing this plan (e.g. `1500` at compact+comma+hide → divide by 1000 → `1.50` → round → strip trailing zero → `"1,5"` + `"K"` → `"1,5K"`; `1500.99` at 0 places → rounds to `1501`, not truncates to `1500`) rather than guessed.
