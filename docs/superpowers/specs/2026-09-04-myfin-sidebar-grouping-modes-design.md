# Sidebar grouping modes

## Context

The sidebar's "Счета" list currently groups active accounts by institution only, via `AccountsListModel.groupedByInstitution(baseCurrency:)` (added earlier this session). The user wants to choose between grouping by bank (existing), currency, country, or account type.

## Goal

Add three new grouping dimensions — currency, country, account type — selectable in Settings, persisted per profile (like `baseCurrency`/`numberFormatPreferences`, both already live on `AppSession`).

## 1. `SidebarGroupingMode` + generalized grouping in `AccountsListModel`

New enum in `Sources/MyFin/Services/AccountsListModel.swift` (same file `AccountGroup` already lives in):

```swift
enum SidebarGroupingMode: String, CaseIterable, Equatable {
    case institution
    case currency
    case country
    case type
}
```

`AccountGroup` gains one field:

```swift
struct AccountGroup: Identifiable, Equatable {
    let id: String
    let label: String
    let total: Decimal
    let displayCurrency: Currency
}
```

- For `.institution`-mode groups (existing `groupedByInstitution`, unchanged otherwise): `displayCurrency` is always the passed-in `baseCurrency` — same as today.
- For `.country`/`.type`-mode groups: also always `baseCurrency` (accounts within one country or one type can be in different currencies, so a converted sum is the only sum that makes sense, exactly like institution-mode).
- For `.currency`-mode groups: `displayCurrency` is the group's *own* currency — every account in a currency-group already shares that currency by construction, so the sum needs no conversion at all, and showing it in `baseCurrency` would be actively wrong (per the user: no conversion for this mode).

Three new methods, each mirroring `groupedByInstitution`'s existing shape (accumulate per key while iterating `activeAccounts`, round the final sums to 8 places via `NSDecimalRound(..., 8, .plain)`, same as `DashboardService.totalBalance`):

- `groupedByCurrency() -> [AccountGroup]` — key/label = `account.currency.rawValue`; sums each account's `openingBalance` directly, **no `HardcodedExchangeRateProvider` call at all**; `displayCurrency` = that group's own `Currency`.
- `groupedByCountry(baseCurrency: Currency) -> [AccountGroup]` — key = `account.country.rawValue`, label = `"\(country.flag) \(country.displayName)"`; converts each account via `HardcodedExchangeRateProvider`, same as `groupedByInstitution`; `displayCurrency` = `baseCurrency`.
- `groupedByType(baseCurrency: Currency) -> [AccountGroup]` — key = `account.type.rawValue`, label = `account.type.displayName` (English-only today, same as every other existing use of `AccountType.displayName` in this codebase — not a regression introduced here); converts via `HardcodedExchangeRateProvider`; `displayCurrency` = `baseCurrency`. All 4 real `AccountType` cases are used as-is (no coarser "Cash/Bank/Cards" bucketing) — confirmed with the user.

One dispatcher, the only entry point `MainShellView` calls:

```swift
func grouped(by mode: SidebarGroupingMode, baseCurrency: Currency) -> [AccountGroup] {
    switch mode {
    case .institution: return groupedByInstitution(baseCurrency: baseCurrency)
    case .currency: return groupedByCurrency()
    case .country: return groupedByCountry(baseCurrency: baseCurrency)
    case .type: return groupedByType(baseCurrency: baseCurrency)
    }
}
```

## 2. Persistence — `AppSession.sidebarGroupingMode`

Live, like `baseCurrency`/`numberFormatPreferences`:

```swift
@Published private(set) var sidebarGroupingMode: SidebarGroupingMode = .institution
```

Loaded at the same two points those two already are (`createProfile`/`logIn`), read directly from `profile_settings` (key `"sidebarGroupingMode"`, value = the mode's raw string) — **no new service class**: unlike `numberFormatPreferences` (4 related fields, worth its own `NumberFormatPreferencesService`), this is a single string value with no other logic attached, so `AppSession` reads/writes it inline with the same `connection.query`/`.execute(...ON CONFLICT...)` idiom `DashboardService.baseCurrency()`/`.setBaseCurrency()` already use — adding a whole service class for one key would be unwarranted ceremony.

New method:

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

## 3. Settings UI

New `Section` in `SettingsView`'s `.general` tab (placed with the other display-preference sections, alongside "Формат чисел"): one segmented `Picker` with 4 options — Банк / Валюта / Страна / Тип — bound to a local `@State` loaded from `session.sidebarGroupingMode` in the existing `.onAppear`, `.onChange` calling `session.updateSidebarGroupingMode(...)`. Same wiring shape already used for `numberFormatPreferences` in that file.

## 4. Sidebar wiring

In `MainShellView`, the `DisclosureGroup`'s `ForEach` switches from `accountsModel.groupedByInstitution(baseCurrency: session.baseCurrency)` to `accountsModel.grouped(by: session.sidebarGroupingMode, baseCurrency: session.baseCurrency)`.

- **Icon:** shown only when `session.sidebarGroupingMode == .institution` — the existing bank-icon/cash-icon logic (`SystemInstitutionCatalog`/`AccountsListModel.cashIconName`) is wrapped in that check. No icons for currency/country/type groups (not requested; avoids inventing icon choices for dimensions that were never asked to have one).
- **Label:** unchanged ternary (`group.id == AccountsListModel.cashGroupID ? ... : group.label`) — safe to leave as-is for every mode, since `cashGroupID` (`"__cash__"`) can never collide with a real currency code, country code, or `AccountType` raw value produced by the 3 new grouping methods.
- **Amount:** changes from the hardcoded `session.baseCurrency.rawValue` to `group.displayCurrency.rawValue`, so a currency-mode group shows its own currency code instead of always the base one.
- Tapping a row still just sets `selection = .accounts` in every mode — no drill-down, unchanged from the existing institution-mode behavior.

## Testing

- New `AccountsListModelTests` cases for `groupedByCurrency()`, `groupedByCountry(baseCurrency:)`, `groupedByType(baseCurrency:)`, and `grouped(by:baseCurrency:)`'s dispatch — mirroring the existing `groupedByInstitution` test style (sum-within-group, separate-different-groups, currency-conversion-matches-known-rate where applicable, archived-exclusion).
- New `AppSessionTests` case for `updateSidebarGroupingMode`, mirroring the existing `updateBaseCurrency`/`updateNumberFormatPreferences` tests (persists + publishes immediately, survives logout/login).
- No tests for `SettingsView`/`MainShellView` themselves — consistent with this codebase's zero View-level XCTest coverage. Verified by `swift build` + `swift test` + a manual look at the running app.

## Out of scope

- No per-group icons for currency/country/type modes.
- No drill-down from a sidebar group into its specific accounts, in any mode.
- The grouping-mode picker lives in Settings only, not as a control directly in the sidebar.
