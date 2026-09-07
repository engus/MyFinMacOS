# Cashflow implementation

Scope: functional native macOS Cashflow, backed by existing Accounts and an immutable double-entry ledger. Decimal amounts; no independent Cashflow balance.

1. Add ledger, categories, dated FX quotes/snapshots, recurring templates, reconciliation records. Import legacy balances as opening equity postings.
2. Route account opening and balance changes through postings. Derive displayed account balances from ledger entries.
3. Implement posting, reversal/replacement, date-based recurrence with deduplication, expected rows, monthly metrics and reconciliation with audit links.
4. Add native functional forms, monthly filters, audit rows, recurring management, reconciliation and dated FX entry. Enable Income / Expense in Add New.
5. Verify accounting invariants, migration, recurrence/timezone/month end, FX completeness and correction/reconciliation; build and render the UI.

Native adaptation: store month in scene state and accept/copy `myfin://cashflow?month=YYYY-MM`. Operational groups use existing card/cash/bank accounts; deposit and unimplemented debt/asset models are not invented. Historical FX quotes are entered explicitly and stored with date/source; cached older quotes are identified. Missing conversions remain incomplete. Demo data is opt-in.

## Implemented behavior

- Existing account balances are derived from sealed ledger entries. Legacy `opening_balance` remains migration metadata; legacy `transactions` is not a Cashflow balance source.
- Schema v8 imports each legacy account's last known balance once as opening equity, using its latest balance-history timestamp. It does not invent historical income or expenses.
- Signed integer units at 8 decimal places enforce database-level balance checks, while application accounting uses Decimal. Posted operations, entries, seals, reconciliation records and late FX valuations reject UPDATE/DELETE. Posting and corrections are transactional.
- Changing an account's balance through its existing editor produces Other Income/Expense postings. Changing currency after Cashflow activity, recurring templates or reconciliation is rejected to preserve currency provenance.
- Recurrence supports weekly, monthly, quarterly, yearly and custom day intervals, optional end dates, and pause/resume. Calendar dates anchor to the original day (Jan 31 -> Feb 28 -> Mar 31). Resume catches up unposted due dates, including dates while paused.
- Due occurrences materialize when the main app opens, becomes active and every minute while open. Missing FX is reported; other templates still run. A unique template/date key prevents duplicate postings, including after reversal/correction.
- Expected operations are generated without ledger writes. Past/current/future month rules, filters, posted and projected metrics, missing/stale FX indicators are implemented.
- Reconciliation accepts completed months. Repeating it reverses the previous adjustment and links the new record. A later backdated operation invalidates completion when the ledger no longer matches the report.
- Audit detail exposes original/reversal/replacement IDs, timestamps, currency snapshots and exact entries. Late FX additions use separate immutable valuation records shared with reversals.
- Transfer postings affect both accounts and are excluded from Cashflow totals. Asset-purchase expense source is supported by the service for later Assets integration; this change does not create an Assets or Debt subsystem.

## Manual use

Open Income & Expenses. Add an operation through `+ Operation` or `+ New -> Income / Expense`. Use the recurring toggle for projections. Use `FX` to enter a dated USD/KZT quote and source; no external market-data connection or fabricated historical quote is used.

Select a completed month for reconciliation. Use a posted row's menu to inspect entries, reverse or correct it. Reconciliation adjustments are corrected via the reconciliation form. In debug builds, `Add demo data` creates three clearly named demo accounts plus example operations and templates, once per profile.

The month is persisted per window. The link button copies a native month URL; it can be pasted into the month field. An `onOpenURL` handler also accepts the URL when delivered by a packaged app; Launch Services registration for a distributed app bundle is outside this Swift-package-only project.

Verification: accounting integration tests cover immutable balanced postings, rollback, corrections, reversals, account integration, FX provenance/completeness, recurring month ends/timezones/deduplication, independent and repeated reconciliation, transfer exclusion, asset expense inclusion, demo idempotence and legacy migration. Native rendering fixtures cover Cashflow in light/dark mode and the entry form.
