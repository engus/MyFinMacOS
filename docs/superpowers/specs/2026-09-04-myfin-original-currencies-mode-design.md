# "Оригинальные валюты" base-currency mode

## Context

`AppSession.baseCurrency: Currency` (live-published, added earlier this session) is read by `DashboardView` (one converted total via `DashboardService.totalBalance(displayCurrency:)`), by three of `AccountsListModel`'s four sidebar grouping methods (`groupedByInstitution`/`groupedByCountry`/`groupedByType`, each converting every account in a group into one common-currency sum), and by `SettingsView`'s currency `Picker`. The user wants a way to see everything in each account's own currency, with no conversion — but confirmed the sidebar's bank/country/type grouping modes should keep summing in a fixed currency regardless (they already need one common currency to produce a group total; that requirement doesn't go away just because this new mode exists).

## Goal

Add "Оригинальные валюты" as a third option alongside the existing currency choices. When active, the Dashboard shows a per-currency breakdown instead of one converted number. Every other consumer of `baseCurrency` (the 3 sidebar grouping modes that need one) is completely unaffected — `baseCurrency` itself is never removed or replaced, so they keep working exactly as today.

## Design

**No change to `baseCurrency`'s type or any of its existing consumers.** Add one new, fully independent field instead:

```swift
@Published private(set) var showOriginalCurrencies: Bool = false
```

on `AppSession`, live and persisted exactly like `sidebarGroupingMode` — loaded at `createProfile`/`logIn` from a new `profile_settings` key (`"showOriginalCurrencies"`, value `"true"`/`"false"`), written via a new `updateShowOriginalCurrencies(_:)` method using the same inline `connection.execute(...ON CONFLICT...)` idiom (no new service class, matching the precedent already set for `sidebarGroupingMode`).

**Settings UI:** the existing base-currency `Picker` (currently just `Currency.allCases`) becomes a 3-way segmented control — USD / KZT / "Оригинальные валюты" — backed by a small View-only wrapper enum (never touches `AppSession`'s stored model, purely a UI convenience for one `Picker` binding):

```swift
enum BaseCurrencySelection: Hashable {
    case currency(Currency)
    case original
}
```

Selecting a concrete currency calls `session.updateBaseCurrency(_:)` (unchanged) and implicitly means "not original" (`showOriginalCurrencies` gets set to `false` via a new call); selecting "Оригинальные валюты" calls `session.updateShowOriginalCurrencies(true)` and does **not** touch the stored `baseCurrency` value at all — it stays whatever it was, ready to be used the moment the user switches back, and ready for the 3 sidebar modes that need it regardless of this toggle.

**Dashboard:** `DashboardView` gains an `AccountsListModel` dependency — `MainShellView` passes it the same `accountsModel` instance it already owns and already passes to `AccountsListView` (`DashboardView(session: session, model: accountsModel)`). When `session.showOriginalCurrencies` is `true`, the body renders `model.groupedByCurrency()` (the exact method the sidebar's "Валюта" grouping mode already uses — already unconverted by construction) as a short list, one line per currency in use, instead of the single converted `total`. When `false`, everything is exactly as it is today (unchanged `dashboardService.totalBalance(displayCurrency: session.baseCurrency)` path).

**Sidebar grouping (institution/country/type):** unchanged, per the user's explicit choice — they keep converting via `session.baseCurrency` regardless of `showOriginalCurrencies`. The sidebar's existing "Валюта" grouping mode is already unconverted and unaffected either way.

## Testing

- New `AppSessionTests` case for `updateShowOriginalCurrencies(_:)`, mirroring the existing `updateSidebarGroupingMode`/`updateBaseCurrency` tests (persists + publishes immediately, survives logout/login).
- No new tests for `DashboardView`/`SettingsView` — consistent with this codebase's zero View-level XCTest coverage; `AccountsListModel.groupedByCurrency()` itself already has tests from the sidebar-grouping-modes feature. Verified by `swift build` + `swift test` + a manual look at the running app.

## Out of scope

- No change to `baseCurrency`'s type, storage, or its 3 existing sidebar-grouping consumers.
- No per-currency breakdown anywhere except the Dashboard (the sidebar's "Валюта" mode already provides one, independent of this toggle).
- No new fallback-currency setting for the 3 grouping modes — they keep using `baseCurrency` exactly as before.
