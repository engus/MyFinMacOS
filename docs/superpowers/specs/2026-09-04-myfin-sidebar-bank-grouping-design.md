# Sidebar: group accounts by bank, converted to base currency

## Context

The sidebar's "Счета" `DisclosureGroup` (`Sources/MyFin/Views/MainShellView.swift`) currently lists every active account individually — name + its own raw balance in its own currency (`ForEach(accountsModel.activeAccounts)`). The user wants this replaced with one row per bank, summing that bank's accounts and converting the sum to the profile's base currency.

`AppSession` does not currently hold `baseCurrency` live — `DashboardView` and `SettingsView` each load their own copy in `.onAppear` via `DashboardService.baseCurrency()`. That's fine today because neither view stays mounted continuously. The sidebar does (same reason `numberFormatPreferences` was made live on `AppSession` earlier this session) — if it read a locally-loaded `baseCurrency` snapshot, changing the base currency in Settings while the sidebar is already showing would leave its grouped totals silently wrong until some unrelated reload happened to fire. This spec makes `baseCurrency` live on `AppSession` too, the same way, and migrates `DashboardView`/`SettingsView` onto it so there's one source of truth instead of two independently-stale copies.

## 1. `AppSession.baseCurrency` — live, like `numberFormatPreferences`

Add to `AppSession`:

```swift
@Published private(set) var baseCurrency: Currency = .usd
```

Loaded at the same two points `numberFormatPreferences` already is — inside `createProfile(...)` and `logIn(...)`, right next to that line — using the exact same construction `DashboardView`/`SettingsView` already use to read it today:

```swift
let institutions = InstitutionService(connection: connection)
let accounts = AccountService(connection: connection, institutionService: institutions)
self.baseCurrency = DashboardService(connection: connection, accountService: accounts, exchangeRateProvider: HardcodedExchangeRateProvider()).baseCurrency()
```

New method, mirroring `updateNumberFormatPreferences(_:)`:

```swift
func updateBaseCurrency(_ currency: Currency) {
    guard let connection else { return }
    let institutions = InstitutionService(connection: connection)
    let accounts = AccountService(connection: connection, institutionService: institutions)
    let dashboard = DashboardService(connection: connection, accountService: accounts, exchangeRateProvider: HardcodedExchangeRateProvider())
    try? dashboard.setBaseCurrency(currency)
    baseCurrency = currency
}
```

`SettingsView`'s base-currency `Picker`'s `.onChange` calls `session.updateBaseCurrency(newValue)` instead of constructing its own `DashboardService` inline; its local `@State private var baseCurrency` is still loaded from `session.baseCurrency` in `.onAppear` (same pattern already used for `numberFormatPreferences` there). `DashboardView` drops its own `dashboardService.baseCurrency()` call and reads `session.baseCurrency` directly wherever it needs the currency to display/convert into — its `reload()` still calls `service.totalBalance(displayCurrency:)`, just passing `session.baseCurrency` instead of a locally-loaded copy.

## 2. Grouping logic — `AccountsListModel.groupedByInstitution(baseCurrency:)`

New method + a small result type in `Sources/MyFin/Services/AccountsListModel.swift`:

```swift
struct AccountGroup: Identifiable, Equatable {
    let id: String
    let label: String
    let total: Decimal
}
```

```swift
func groupedByInstitution(baseCurrency: Currency) -> [AccountGroup] {
    ...
}
```

- Operates on `activeAccounts` only (already-excluded-archived, existing computed property — unchanged).
- Every `.cash` account (or any account with no `institutionId`) goes into one bucket, keyed by a public `AccountsListModel.cashGroupID` constant (`"__cash__"`), with `label: ""` — **not** localized here. This codebase's services never localize (only views call `preferences.string(...)`; `AccountsListModel` has no access to `AppPreferences`/current language at all), so `MainShellView` is what turns this into visible text: it checks `group.id == AccountsListModel.cashGroupID` and substitutes `preferences.string(.cashFieldLabel)` (the same key `AccountFormView` already uses for "Наличные"/"Cash" — no new localization key needed) in place of the empty `label`.
- Every other account is keyed by its `institutionId`; the label is that institution's name, resolved via the same raw SQL lookup pattern already used in `AccountsListView.institutionName(for:)` (`SELECT name FROM institutions WHERE id = ?`) — a small private helper on `AccountsListModel` duplicates that one-line query rather than sharing code across the two files, since both are already-tiny, independent, single-purpose lookups (matches this codebase's existing style — `AccountsListView` and `MainShellView` already each format their own balance strings rather than sharing a helper). Institution names are literal database text, not translated, so resolving them inside the model (which already has `connection`) is consistent with how `AccountsListView` does it today.
- Each account's contribution to its group's `total` is `account.openingBalance * HardcodedExchangeRateProvider().rate(from: account.currency, to: baseCurrency)`, summed per group, then rounded to 8 decimal places via `NSDecimalRound(..., 8, .plain)` — identical precision handling to `DashboardService.totalBalance`.
- Groups are returned in the order their key was first encountered while iterating `activeAccounts` (stable, no re-sorting) — matches how the existing per-account sidebar list has no explicit sort today either.

## 3. Sidebar wiring

In `MainShellView.swift`, change the `DisclosureGroup`'s content from `ForEach(accountsModel.activeAccounts)` (per-account rows) to `ForEach(accountsModel.groupedByInstitution(baseCurrency: session.baseCurrency))` (per-group rows): `Text(group.id == AccountsListModel.cashGroupID ? preferences.string(.cashFieldLabel) : group.label)` + `Text(NumberDisplayFormatter.format(group.total, preferences: session.numberFormatPreferences)) \(session.baseCurrency.rawValue)`. Tapping a row still sets `selection = .accounts` (opens "Счета") — there is no per-group or per-account drill-down; the "Счета" page itself already lists every individual account.

## Testing

- New `AccountsListModelTests` cases for `groupedByInstitution(baseCurrency:)`: two accounts at the same institution sum into one group; a cash account and a bank account produce two separate groups; currency conversion matches `HardcodedExchangeRateProvider`'s known rate (mirrors `DashboardServiceTests`' existing `test_totalBalance_convertsMixedCurrencies`); archived accounts are excluded.
- New `AppSessionTests` case for `updateBaseCurrency(_:)`, mirroring the existing `updateNumberFormatPreferences` test (persists + publishes immediately, survives logout/login).
- No tests for `MainShellView`/`DashboardView`/`SettingsView` themselves — consistent with this codebase's zero View-level XCTest coverage. Verified by `swift build` + `swift test` + a manual look at the running app.

## Out of scope

- No drill-down from a sidebar group into that bank's specific accounts — clicking still just opens "Счета" as a whole.
- No change to the "Счета" page's own per-account list, or the "Банки" tab.
- No change to how exchange rates themselves are sourced (`HardcodedExchangeRateProvider`, unchanged).
