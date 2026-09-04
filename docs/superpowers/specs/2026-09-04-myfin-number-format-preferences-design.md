# Number format preferences

## Context

The original product brief for this feature was written for a web app with a PostgreSQL-backed API — it does not describe MyFin's real architecture (Swift/SwiftUI, one SQLCipher-encrypted SQLite database per local profile, no server, no API). This spec adapts the underlying idea (four user-chosen display preferences for how numbers look) to that architecture; every mention of "API"/"PostgreSQL"/"devices" in the original brief is replaced below with MyFin's actual persistence and sync story.

**Scope reality check:** the original brief lists money, balances, cashflow figures, asset values, FX values, percentages, chart labels/tooltips, summary counts, and previews as needing this formatting. MyFin today only actually displays numbers in 3 places — the Dashboard total, the balance in each row of the "Счета" page, and the balance in each row of the sidebar's account list (added earlier this session). Cashflow and Assets are still placeholder pages with no numbers; there are no charts, percentages, or FX-rate displays anywhere yet. This spec wires the formatter into those 3 real call sites; when Cashflow/Assets grow real numeric displays later, they should reuse the same formatter rather than reinvent one.

## Goal

Let the user choose, per profile: decimal separator (`.` or `,`), maximum decimal places (`0`, `1`, or `2`), large-number notation (full or compact with K/M/B), and whether insignificant trailing zeroes are shown or hidden — without changing the underlying `Decimal` values used for storage or calculation anywhere.

## 1. Data model

`Sources/MyFin/Models/NumberFormatPreferences.swift` (new file):

```swift
struct NumberFormatPreferences: Equatable {
    var useCommaDecimalSeparator: Bool = false
    var maxDecimalPlaces: Int = 2
    var useCompactNotation: Bool = false
    var hideTrailingZeroes: Bool = true
}
```

Plain `Bool`/`Int` rather than dedicated enums — each field is a closed 2-or-3-way choice with no behavior of its own beyond picking a branch in the formatter (Section 3), so a dedicated type would add ceremony without adding safety (the Settings UI, Section 4, only ever offers the valid choices). Defaults match the brief's stated defaults (`.`, `2`, full, hide).

## 2. Persistence — `NumberFormatPreferencesService`

New file `Sources/MyFin/Services/NumberFormatPreferencesService.swift`, mirroring `DashboardService.baseCurrency()`/`.setBaseCurrency()`'s existing use of the per-profile `profile_settings` key-value table:

```swift
final class NumberFormatPreferencesService {
    private let connection: DatabaseConnection
    init(connection: DatabaseConnection) { self.connection = connection }

    func load() -> NumberFormatPreferences { ... }
    func save(_ preferences: NumberFormatPreferences) { ... }
}
```

Four rows in `profile_settings`, one per field, written/read with the same `INSERT ... ON CONFLICT(key) DO UPDATE SET value = excluded.value;` idiom `DashboardService.setBaseCurrency` already uses:

| Key | Stored value |
|---|---|
| `numberFormatDecimalSeparator` | `"comma"` or `"period"` |
| `numberFormatMaxDecimalPlaces` | `"0"`, `"1"`, or `"2"` |
| `numberFormatNotation` | `"compact"` or `"full"` |
| `numberFormatHideTrailingZeroes` | `"true"` or `"false"` |

`load()` returns the struct's defaults for any key that's missing or unparseable (a brand-new profile, or one created before this feature existed) — same "tolerate missing/legacy data" spirit as `Profile`'s own `hasOnboarding` decode fallback.

## 3. Live sync — `AppSession.numberFormatPreferences`

Rather than each consuming view loading its own copy on `.onAppear` (how `baseCurrency` works today, which is fine there because Dashboard/Settings are only ever seen one at a time), this preference is read by the sidebar in `MainShellView`, which — per this session's earlier `AccountsListModel` fix — stays mounted continuously for the whole profile session and would otherwise go stale the moment Settings changes it while the sidebar is already showing.

So `AppSession` (`Sources/MyFin/AppSession.swift`) gets:

```swift
@Published private(set) var numberFormatPreferences: NumberFormatPreferences = NumberFormatPreferences()
```

- Loaded via `NumberFormatPreferencesService(connection:).load()` at the same two points `unlockedProfile`/`connection` are already set: inside `createProfile(...)` and `logIn(...)`.
- A new method, mirroring `updateProfile(...)`'s shape:

```swift
func updateNumberFormatPreferences(_ preferences: NumberFormatPreferences) {
    guard let connection else { return }
    NumberFormatPreferencesService(connection: connection).save(preferences)
    numberFormatPreferences = preferences
}
```

`SettingsView` calls this whenever any of the 4 controls changes; every view holding `@ObservedObject var session: AppSession` (Dashboard, Accounts list, the sidebar) re-renders with the new value automatically.

## 4. Formatting logic — `NumberDisplayFormatter`

New file `Sources/MyFin/Services/NumberDisplayFormatter.swift`:

```swift
enum NumberDisplayFormatter {
    static func format(_ value: Decimal, preferences: NumberFormatPreferences) -> String { ... }
}
```

Algorithm:

1. **Sign:** record whether `value` is negative, work with its absolute value from here on, re-prepend `"−"` at the end if it was negative. (No current caller ever passes a negative value — account balances are validated non-negative, and the Dashboard total sums non-negative amounts — but a general-purpose formatter shouldn't silently mishandle one, since a future Cashflow feature will have them.)
2. **Compact notation** (only if `preferences.useCompactNotation`): pick the largest threshold the absolute value clears — `≥ 1_000_000_000` → divide by `1_000_000_000`, suffix `"B"`; else `≥ 1_000_000` → divide by `1_000_000`, suffix `"M"`; else `≥ 1_000` → divide by `1_000`, suffix `"K"`; else no division, no suffix. The threshold is a straight `≥ 1_000`, applied uniformly with no special-cased gap between the K and M thresholds. (The original brief's own worked examples conflict with this and with each other once worked through in full — `1 500 000 → "1,5M"` matches this rule, but `"1 500,00 becomes 1 500"` and `"1 500,25 remains 1 500,25"` both assume `1500` and `1500.25` *don't* get compacted to K, which only holds if K's threshold were higher than 1500. Confirmed with the user directly: `1500 → "1,5K"` under compact notation is correct, and both of those two examples from the original brief are superseded by this rule, not the other way around.)
3. **Round** the (possibly scaled) value to `preferences.maxDecimalPlaces` places via `NSDecimalRound(&rounded, &scaled, preferences.maxDecimalPlaces, .plain)` — same rounding mode already used by `AccountService.decimalString` and `DashboardService.totalBalance`.
4. **Split** into integer and fractional digit strings based on that rounding.
5. **Trailing zeroes:** if `preferences.hideTrailingZeroes`, strip trailing `"0"` characters from the fractional digits; if that empties the fractional part, drop it (and the separator) entirely — `1500.00` → `"1500"`, not `"1500."`. If `false`, the fractional part is always left padded to exactly `maxDecimalPlaces` digits (e.g. `"00"` for a whole number at 2 places). If `maxDecimalPlaces == 0`, there is never a fractional part regardless of this setting.
6. **Group** the integer digits with a space every 3 digits from the right (`"1500"` → `"1 500"`) — always a space, regardless of `useCommaDecimalSeparator`. (Confirmed by the brief's own worked example: with the decimal separator set to comma, the thousands grouping in the output is still a space, not a period — the two are independent.)
7. **Join:** `groupedInteger` + (if fractional part non-empty) `separator` + `fractionalDigits`, where `separator` is `","` if `useCommaDecimalSeparator` else `"."`. Append the K/M/B suffix directly with no space. Re-prepend the negative sign from step 1 if needed.

All arithmetic (scaling, rounding) stays in `Decimal` throughout — never converted to `Double`/`Float`, consistent with this codebase's existing money-handling rule (`AccountService`/`DashboardService` never use `REAL`/`Double` for a monetary value either). Only the final digit-splitting/grouping/string-assembly step touches `String`.

## 5. Wiring into the 3 existing display sites

- `Sources/MyFin/Views/DashboardView.swift`: `Text("\(total) \(displayCurrency.rawValue)")` → `Text("\(NumberDisplayFormatter.format(total, preferences: session.numberFormatPreferences)) \(displayCurrency.rawValue)")`.
- `Sources/MyFin/Views/AccountsListView.swift` (`AccountRowView`): `Text("\(account.openingBalance)")` → `Text(NumberDisplayFormatter.format(account.openingBalance, preferences: numberFormatPreferences))`. `AccountRowView` doesn't currently hold a `session` reference, only `@EnvironmentObject var preferences: AppPreferences` (language/theme) — it gains a new `let numberFormatPreferences: NumberFormatPreferences` stored property, passed in by its parent `AccountsListView` (which reads `session.numberFormatPreferences` and passes it at each of the two call sites that construct `AccountRowView`), not a second environment object — keeps `AccountRowView` a plain data-in view, matching its existing style.
- `Sources/MyFin/Views/MainShellView.swift` (sidebar account row): `Text("\(account.openingBalance) \(account.currency.rawValue)")` → `Text("\(NumberDisplayFormatter.format(account.openingBalance, preferences: session.numberFormatPreferences)) \(account.currency.rawValue)")`.

`DashboardView` and `MainShellView` both already hold `session` directly, so they read `session.numberFormatPreferences` with no new plumbing.

## 6. Settings UI

New `Section` in `SettingsView`'s `.general` tab (added after the existing "Базовая валюта" section, before "Выйти"), four segmented `Picker`s bound to a local `@State private var numberFormatPreferences: NumberFormatPreferences`, loaded from `session.numberFormatPreferences` in the existing `.onAppear`, each `.onChange` calling `session.updateNumberFormatPreferences(...)` with the updated struct:

- **Разделитель дробной части:** `.` / `,`
- **Знаков после запятой:** `0` / `1` / `2`
- **Крупные числа:** Полностью / Сокращённо
- **Незначащие нули:** Показывать / Скрывать

## New localization keys (9)

| Key | ru | en |
|---|---|---|
| `.numberFormatSectionTitle` | Формат чисел | Number format |
| `.decimalSeparatorFieldLabel` | Разделитель дробной части | Decimal separator |
| `.maxDecimalPlacesFieldLabel` | Знаков после запятой | Decimal places |
| `.largeNumberNotationFieldLabel` | Крупные числа | Large numbers |
| `.trailingZeroesFieldLabel` | Незначащие нули | Trailing zeroes |
| `.notationFullLabel` | Полностью | Full |
| `.notationCompactLabel` | Сокращённо | Compact |
| `.trailingZeroesShowLabel` | Показывать | Show |
| `.trailingZeroesHideLabel` | Скрывать | Hide |

The decimal-separator (`.`/`,`) and decimal-places (`0`/`1`/`2`) picker options are literal characters/digits, not localized strings.

## Testing

- `NumberDisplayFormatterTests` (new): full vs. compact notation at and just below each of the K/M/B thresholds; hide vs. show trailing zeroes (including the all-zero-fractional case dropping the separator entirely); 0/1/2 max decimal places; period vs. comma separator; zero; a negative value; a value needing the 3-decimal-place rounding down to 2.
- `NumberFormatPreferencesServiceTests` (new): `load()` returns struct defaults against a freshly-opened, never-written-to connection; `save()` followed by `load()` round-trips every field correctly.
- `AppSessionTests`: one new test that `updateNumberFormatPreferences` both persists (a fresh `AppSession`/`logIn` against the same profile reflects it) and updates the published property immediately.
- No tests for `SettingsView`/`DashboardView`/`AccountsListView`/`MainShellView` themselves — consistent with this codebase's zero View-level XCTest coverage. Verified by `swift build` + `swift test` + a manual look at the running app.

## Out of scope

- Cashflow/Assets pages — still placeholders, nothing to wire up yet.
- Charts, percentages, FX-rate displays, summary counts, "previews" — none exist in MyFin today.
- Form controls (the balance `TextField` in `AccountFormView`), export files, and stored/calculated `Decimal` values are untouched, per the original brief's own exclusions — this feature only changes what `Text(...)` renders.
- No new settings-sync-across-devices mechanism — "follows the user across sessions" is satisfied by per-profile SQLite storage (the profile's database already only exists on this machine; there is no multi-device sync anywhere in MyFin today).
