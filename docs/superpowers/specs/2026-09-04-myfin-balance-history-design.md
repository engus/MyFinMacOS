# Balance History for Accounts

## Context

MyFin's `AccountService` currently persists only the account's current `openingBalance` — editing an account's balance overwrites the stored value with no trace of what it used to be (`AccountService.updateAccount(...)` does a plain `UPDATE accounts SET ... opening_balance = ? ... WHERE id = ?`). Separately, a `transactions` table already exists and records a single `opening_balance`-kind row at account creation (only when the opening balance is > 0), but nothing is written to it on edits. The user wants to see, per account, how its balance changed over time, surfaced as a right-side panel on the "Счета" (Accounts) page when clicking an account.

This is the third and final feature in a queue of three requested together this session; the first two ("Sidebar Grouping Modes" and "Оригинальные валюты" base-currency mode) are already implemented and verified.

## Goal

Every time an account's balance actually changes — including the very first balance at account creation — record a `balance_history` entry. Clicking an account row on the Accounts page opens a right-side inspector panel showing that account's balance history: balance, date, and the delta versus the previous entry.

## Design

**Schema.** A new table, added as migration version 4 (this project's existing `MigrationStep` array in `DatabaseConnection`'s migrations goes up to version 3 today):

```sql
CREATE TABLE IF NOT EXISTS balance_history (
    id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL REFERENCES accounts(id),
    balance TEXT NOT NULL,
    recorded_at TEXT NOT NULL
);
```

`balance` is stored as text (same convention as `accounts.opening_balance`, via `AccountService.decimalString(_:)`); `recorded_at` is an ISO8601 string (same convention as every other timestamp column in this schema).

**Model.** A new `BalanceHistoryEntry: Identifiable, Equatable` struct, added to `Sources/MyFin/Models/Account.swift` alongside `Account`:

```swift
struct BalanceHistoryEntry: Identifiable, Equatable {
    let id: String
    let balance: Decimal
    let recordedAt: Date
}
```

**`AccountService` changes.** No new service class — `balance_history` inserts happen directly via `connection.execute(...)`, the same way `transactions` inserts already happen inline inside `createAccount`.

- `createAccount(...)`: inside the existing `connection.withTransaction { ... }` block, after inserting the `accounts` row, always insert one `balance_history` row (`balance = openingBalance`, `recorded_at = nowString`) — unconditionally, even when `openingBalance == 0`. (This differs from the existing `transactions` opening-balance insert, which is skipped when the balance is 0 — the two are independent and this one always fires, since the user confirmed the very first balance should always be the first history entry.)
- `updateAccount(...)`: it already calls `fetchAccount(id:)` once at the top for the not-found check — that fetched `Account.openingBalance` becomes the "old" value to compare against the incoming `openingBalance` parameter. If they differ, insert a new `balance_history` row (`balance = openingBalance` (new value), `recorded_at = nowString`) right after the `UPDATE accounts` statement. If they're equal (a save where the balance field didn't change), no history row is written.
- New read method: `balanceHistory(accountId: String) -> [BalanceHistoryEntry]`, querying `SELECT * FROM balance_history WHERE account_id = ? ORDER BY recorded_at ASC;` and mapping rows the same way `rowToAccount` does today. No cap on rows returned — retention is unbounded per the user's choice.

**Panel UI.** `AccountsListView` gains `@State private var selectedAccount: Account?`. The private `AccountRowView` gets a new `onSelect: () -> Void` closure, wired to a `.contentShape(Rectangle()).onTapGesture { onSelect() }` on the row's leading `VStack` (name + subtitle) only — the trailing balance text and the existing Edit/Archive `Button`s are untouched, so tapping them keeps their current behavior instead of also opening the panel.

`AccountsListView`'s body gains:

```swift
.inspector(isPresented: Binding(
    get: { selectedAccount != nil },
    set: { if !$0 { selectedAccount = nil } }
)) {
    if let account = selectedAccount {
        BalanceHistoryPanelView(session: session, account: account)
    }
}
```

A new file, `Sources/MyFin/Views/BalanceHistoryPanelView.swift`, defines `BalanceHistoryPanelView(session: AppSession, account: Account)`. It loads `balanceHistory(accountId: account.id)` via `AccountService` (constructed the same way `AccountsListView`/`DashboardView` already construct it from `session.connection`), reverses it to newest-first for display, and renders a `List` of rows: formatted balance (via `NumberDisplayFormatter`, using `session.numberFormatPreferences` and `account.currency`), formatted date, and the delta versus the chronologically previous (older) entry — computed as `entries[i].balance - entries[i + 1].balance` in the newest-first array (the oldest/last entry has no delta, since nothing precedes it). Delta is shown as a signed number (e.g. `+500`, `-200`).

## Testing

- New `AccountServiceTests` cases:
  - `createAccount` with a positive opening balance writes one `balance_history` entry matching it.
  - `createAccount` with a **zero** opening balance still writes one `balance_history` entry (unlike the existing `transactions` opening-balance row, which is skipped at zero).
  - `updateAccount` with a changed `openingBalance` appends a new `balance_history` entry.
  - `updateAccount` with an unchanged `openingBalance` (e.g. only the name changed) writes no new `balance_history` entry — history stays at its prior count.
  - `balanceHistory(accountId:)` returns entries ordered oldest → newest.
- No new tests for `AccountsListView`/`BalanceHistoryPanelView` — consistent with this codebase's zero View-level XCTest coverage. Verified by `swift build` + `swift test` + a manual walkthrough of the running app.

## Out of scope

- No retention cap or pruning of old `balance_history` rows.
- No note/reason field on history entries — balance, date, and delta only.
- No editing or deleting individual history entries from the UI.
- No change to `AccountFormView` itself — it keeps saving exactly as today; the history write is a side effect entirely inside `AccountService`, invisible to the form.
- No change to the existing `transactions` table or its `opening_balance`-kind row — `balance_history` is a separate, independent table.
