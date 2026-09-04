# Account row subtitle: country, currency, type near the bank name

## Context

`AccountsListView.swift`'s private `AccountRowView` currently shows, per row: name + a caption line under it (`institutionOrCountryLabel(for:)` — the institution name for a normal bank/card account, or the country as a fallback for cash accounts / an unresolved institution), then separately, right-aligned far from the name: `Text(account.type.displayName)` and `Text(account.currency.rawValue)`, then the balance, then Edit/Archive-Restore buttons.

## Goal

Move country, currency, and type into the caption line under the account name, alongside the bank name, and show the country there always (not only as a cash/fallback case). Remove the two separate right-aligned type/currency columns.

## Design

Replace `institutionOrCountryLabel(for:)` in `AccountsListView` with `accountSubtitle(for:) -> String`, building a single string from up to 4 parts joined by `" · "`:

1. Institution name — included only for a non-`.cash` account whose `institutionId` resolves to a row in `institutions` (the existing SQL lookup, unchanged). Omitted for cash accounts or an unresolved institution.
2. Country — always `"\(account.country.flag) \(account.country.displayName)"`, every account, every type.
3. Currency — `account.currency.rawValue`.
4. Type — `account.type.displayName`.

Examples:
- Bank account, institution resolved: `"Halyk Bank · 🇰🇿 Kazakhstan · USD · Дебетовая карта"`.
- Cash account: `"🇰🇿 Kazakhstan · KZT · Наличные"` (no institution part).

In `AccountRowView`, remove `Text(account.type.displayName)` and `Text(account.currency.rawValue)` (now redundant with the subtitle). The row becomes: name+subtitle `VStack` on the left, `Spacer()`, balance, Edit button, Archive/Restore button — the same structure as today minus those two `Text`s.

## Testing

No new tests — `AccountsListView`/`AccountRowView` have none today, consistent with this codebase's zero View-level XCTest coverage. Verified by `swift build` + `swift test` (regression safety) + a manual look at the running app.

## Out of scope

- No change to how the institution name is looked up (same SQL query, same non-throwing fallback behavior).
- No change to the sidebar's account rows or the "Банки" tab — this is scoped to `AccountsListView`'s rows only.
- No change to sort order, archiving, or any other row behavior.
