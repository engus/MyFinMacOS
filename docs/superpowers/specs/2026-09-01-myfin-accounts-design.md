# MyFin — Accounts Business Logic & UI Design

## Purpose

The first real domain feature in MyFin: an "Accounts" section where the user tracks money they currently own — debit cards, deposits, bank accounts, and cash. This is the first feature to give the per-profile encrypted SQLite database actual application data (until now it held nothing but a placeholder `_myfin_meta` table). It also introduces a small Dashboard total and a one-time Onboarding placeholder.

This spec is adapted from a pre-existing product prompt written before MyFin's actual architecture (Swift/SwiftUI, SPM, one SQLCipher-encrypted database per local profile, no server, no shared storage) existed. Deviations from that original prompt are called out explicitly below wherever they occur, with the reasoning.

## Scope

In scope:
- Migration system for per-profile SQLite databases.
- System institution catalog (unchanged list, see the original prompt) seeded into each profile's database.
- Custom (user-created) institutions: create, rename, archive/restore, country change (only while unused), dedup-on-create.
- Accounts: create, edit, archive/restore, list (with Show Archived).
- Bank picker: searchable, keyboard-navigable, "Other bank" flow into custom institution creation.
- A minimal transactions ledger, used only to record each account's opening balance (if positive).
- A per-profile base currency setting (Settings screen) and a Dashboard total across all active accounts, converted to that base currency via a hardcoded exchange rate.
- A one-time Onboarding placeholder screen shown after profile creation (and on next login, if not yet dismissed).
- Full SwiftUI screens for all of the above (this is not a logic-only pass — the user explicitly asked for the real UI, not just business logic).
- Raising the package's minimum macOS deployment target from 13 to 14, to use `.onKeyPress` for the bank picker's keyboard navigation.

Out of scope (unchanged from the original prompt):
- Credit cards, loans, mortgages, overdrafts, negative balances, Open Banking, automatic bank sync, statement import.
- Editing or archiving system institutions.

Deviations from the original prompt (confirmed with the user during brainstorming):
- **Currency list.** The original prompt required a `currency` field but never listed which currencies are supported. For this iteration, the currency list is hardcoded to `USD` and `KZT` only. A real currency/exchange-rate lookup is future work.
- **`hasFinancialHistory` lock.** The original prompt required blocking `type`/`currency` edits once an account has financial history. Dropped from this iteration's scope entirely — `type` and `currency` remain freely editable. Can be revisited later.
- **Onboarding.** The original prompt's acceptance criteria required "identical form behavior in Accounts and Onboarding." MyFin has no Onboarding flow at all yet. This iteration adds only a placeholder Onboarding screen (a text label reading "Онбординг" and an "OK" button that dismisses it) shown once per profile; it does not contain the account-creation form. The identical-form requirement is dropped until a real Onboarding flow is designed.
- **`owner_user_id` on institutions.** Dropped. The original prompt modeled institutions as belonging to a "user" in a shared, multi-tenant database. MyFin has one encrypted SQLite database per local profile; a custom institution living inside that database has an implicit, singular owner (the profile itself), so a separate owner column would be redundant.
- **`inUse` on institutions.** Dropped as a stored column. Computed on demand via `COUNT(*) FROM accounts WHERE institution_id = ?` instead of a maintained boolean, to avoid a class of sync bugs between the flag and the real data.
- **System catalog storage.** The user asked for the bank/institution lists to move into the database (rather than living only as in-app static data, e.g. how `ProfileIconPalette` works today) without changing their content. The Swift source remains the master/source-of-truth listing (unchanged from the original prompt), but a database migration seeds it into each profile's `institutions` table on first run, so from the app's runtime perspective it is genuinely a database-backed catalog, joinable with custom institutions in the same table.
- **Deployment target.** Raised from macOS 13 to macOS 14 in `Package.swift`, to use `.onKeyPress` for the bank picker instead of a manual `NSEvent` monitor. This is a personal, local-only app running on the user's own current Mac (macOS versions are now year-numbered, e.g. "26"; the deployment target is only a floor, not a reflection of what's installed), so this has no practical downside.
- **Dashboard total + base currency (added, not in the original prompt).** The user asked, mid-brainstorm, for a total-across-accounts figure on the Dashboard, converted to a per-profile "base currency" (a display-only setting in Settings — it never affects how accounts are stored), using a hardcoded exchange rate for now (`1 USD = 460.5 KZT`). A small `ExchangeRateProviding` seam is introduced so the hardcoded rate can be swapped for a real source later without touching call sites.

## Data model & migrations

`DatabaseService.swift` currently opens a SQLCipher connection and forces one write (`_myfin_meta`) purely to materialize the encrypted header — it defines no application schema. This spec introduces a small migration system: on open, read the current `PRAGMA user_version`, and apply any missing migration steps in order (plain SQL via the existing raw C API — no ORM, consistent with the rest of the project). The existing `_myfin_meta` table becomes migration 1; the tables below become migration 2, which also seeds the system institution catalog.

New tables, all inside each profile's own encrypted database (there is no shared/global database in this app):

- **`institutions`**: `id TEXT PRIMARY KEY`, `source TEXT` (`'system'` or `'custom'`), `country TEXT`, `name TEXT`, `aliases TEXT` (JSON array of strings; only meaningful for `source = 'system'` — custom institutions have no aliases), `archived INTEGER` (0/1; always 0 for system rows, which can never be archived), `created_at TEXT`, `updated_at TEXT`. System rows use the stable IDs from the original prompt (e.g. `kz.halyk-bank`) as their primary key; custom rows get a generated UUID.
- **`accounts`**: `id TEXT PRIMARY KEY`, `name TEXT`, `country TEXT`, `type TEXT` (`debit_card`/`deposit`/`bank_account`/`cash`), `currency TEXT` (`USD`/`KZT`), `opening_balance TEXT` (a canonical decimal string, e.g. `"1234.56780000"` — never a numeric SQLite column, to avoid float round-tripping), `balance_date TEXT`, `institution_id TEXT NULL` (NULL only for `cash`; foreign key to `institutions.id` otherwise), `archived INTEGER`, `created_at TEXT`, `updated_at TEXT`.
- **`transactions`**: `id TEXT PRIMARY KEY`, `account_id TEXT`, `amount TEXT` (same decimal-string convention), `date TEXT`, `kind TEXT` (only `'opening_balance'` exists today), `created_at TEXT`. This is intentionally minimal — just enough to record one opening-balance entry per account with a positive starting balance. It is expected to become the real ledger once a Cashflow feature exists; for now an account's current balance is simply its `opening_balance` (there is nothing else to sum yet).
- **`profile_settings`**: `key TEXT PRIMARY KEY`, `value TEXT` — a generic key-value store for profile-scoped settings. First user: `baseCurrency`.

Money is represented as Swift's `Decimal` type everywhere in code, and as a `TEXT` decimal string in the database — never `REAL`/float, at any layer. `Decimal` (base-10, exact) avoids the precision loss inherent to binary floating point (e.g. `0.1 + 0.2 != 0.3` in `Double`), which matters for financial data; `REAL` in SQLite is the same binary-float representation under the hood, so storing amounts as text sidesteps the same problem at the persistence layer too.

## Institutions

`InstitutionService`, operating on one profile's `ProfileDatabase` (a small wrapper introduced around the raw `DatabaseConnection` for running the SQL this feature needs — see Testing section for how this stays testable without a real encrypted file where possible):

- `listInstitutions(country:) -> [InstitutionPickerItem]` — all system institutions plus non-archived custom institutions for that country, always ending with a synthetic `.otherBank` case. `.otherBank` is a pure UI/logic sentinel meaning "create a new custom institution" — it is never written to the `institutions` table.
- `search(query:, in:) -> [InstitutionPickerItem]` — case-insensitive substring match against `name` and (for system rows) each alias; `.otherBank` is always retained in results regardless of query, matching the original prompt.
- `resolveOrCreateCustomInstitution(name:, country:) -> Result<Institution, InstitutionError>` — trims and case-folds `name`, looks for an existing custom institution with the same normalized name in the same country:
  - an active match is reused (no duplicate created);
  - an archived match returns `.conflictWithArchived(existing)`, which the UI surfaces as "a bank with this name already exists, archived — restore it in Settings";
  - no match creates a new custom institution row. This call always runs inside the same SQLite transaction as the account creation that triggered it (see Accounts), so the institution and the account are created atomically or not at all.
- `renameCustomInstitution(id:, name:)`, `archiveCustomInstitution(id:)`, `restoreCustomInstitution(id:)`, `changeCustomInstitutionCountry(id:, country:)` — the last one fails with `.inUse` if `COUNT(*) FROM accounts WHERE institution_id = ?` is greater than zero.
- Every mutating call on a `source = 'system'` row fails with `.systemInstitutionIsReadOnly` — enforced in the service, not left to callers to check first.

## Accounts

`AccountService`:

- `createAccount(country:, type:, institutionSelection:, currency:, openingBalance:, name:, balanceDate:) -> Result<Account, AccountError>`. Validation, matching the original prompt exactly:
  - `country` and `type` are required.
  - An institution is required for every type except `cash` (for `cash`, any passed institution selection is ignored — the account is created with `institution_id = NULL`).
  - `currency` must be `USD` or `KZT`.
  - `openingBalance` must be a non-negative `Decimal` with at most 8 digits after the decimal point; negative and over-precision values are distinct error cases so the UI can show a specific message for each.
  - `balanceDate`, if omitted, defaults to the current calendar date in the device's time zone (`Calendar.current`/`TimeZone.current` — no custom timezone handling needed).
  - If `name` is empty, it is generated and persisted as `"<Bank> · Debit card"` / `"<Bank> · Deposit"` / `"<Bank> · Bank account"` / `"Cash · <Country>"`. This is a one-time snapshot: renaming a bank later does not retroactively rename accounts.
  - `institutionSelection` being "Other bank + typed name" first resolves/creates the custom institution (see Institutions), then creates the account — same transaction.
  - If `openingBalance > 0`, one row is written to `transactions` (`kind = 'opening_balance'`) in the same transaction as the account; if `0`, no transaction row is written.
- `updateAccount(id:, name:, country:, institutionSelection:) -> Result<Account, AccountError>` — `name`, `country`, and `institution` are editable. `type` and `currency` are also left freely editable in this iteration (the `hasFinancialHistory` lock is out of scope, per Deviations above). Changing `country` on a `cash` account is just a field update — there is no transfer/movement transaction, matching the original prompt.
- `archiveAccount(id:)` / `restoreAccount(id:)` — flips `archived`; never deletes data.
- `listAccounts(includeArchived:) -> [Account]`.
- An account's current balance is its `opening_balance` — there is no other transaction kind yet to sum against it.

## Dashboard total & base currency

- `ExchangeRateProviding` — a one-method protocol: `rate(from: Currency, to: Currency) -> Decimal`. `HardcodedExchangeRateProvider` is the only implementation for now, knowing only `USD ⇄ KZT` (`1 USD = 460.5 KZT`, and its reciprocal for the other direction). This mirrors the existing `BiometricAuthenticating`/`DeviceAuthenticator` seam already in the codebase — swapping in a real rate source later means adding a new conforming type and changing one injection point, not touching `DashboardService` or its tests.
- Base currency is a per-profile setting, stored in `profile_settings` (key `baseCurrency`), defaulting to `USD`, editable from Settings. It is purely a display preference — it never changes how an account's own currency or balance is stored.
- `DashboardService.totalBalance(displayCurrency:) -> Decimal` sums every non-archived account's balance, each converted to `displayCurrency` via `ExchangeRateProviding`.
- The Dashboard screen (currently a bare placeholder) shows this total next to the display currency. Nothing else is added to the Dashboard in this iteration — no charts, no per-account breakdown there — to avoid scope creep beyond what was asked.

## Onboarding placeholder

- `Profile` gains `var hasCompletedOnboarding: Bool`. Decoding is backward-compatible like `iconName`/`iconColor`, but with the opposite default: a `profile.json` written before this feature existed (i.e., missing this key) decodes to `hasCompletedOnboarding = true`, not `false` — so pre-existing profiles are never retroactively shown the onboarding screen. New profiles are always created with `hasCompletedOnboarding = false`.
- `AppSession.Screen` gains a `.onboarding` case.
- After both `createProfile` and any successful login path (`logIn`, `logInWithRememberedPassword`), the resulting screen is `.onboarding` if `!profile.hasCompletedOnboarding`, else `.mainShell`. Checking this on every login (not just at creation) means quitting the app before dismissing onboarding shows it again next time, rather than losing track of it.
- `AppSession.completeOnboarding()` sets `hasCompletedOnboarding = true` on the unlocked profile, persists it via `ProfileStore.updateProfile`, and transitions `screen` to `.mainShell`.
- `OnboardingView` is intentionally minimal: a text label ("Онбординг") and an "OK" button calling `completeOnboarding()`. It does not contain the account-creation form — that is deferred until a real Onboarding flow is designed (see Deviations).

## UI

- **`AccountsListView`** replaces the current `PlaceholderPageView` behind the "Аккаунты" sidebar item. Each row shows: account name, institution name (or country, for cash), type, currency, balance, and Active/Archived status. A "Show archived" toggle controls whether archived accounts are included. Row actions: Edit, Archive/Restore. A toolbar action: Create account.
- **`AccountFormView`**, shared by create and edit, renders fields in the exact order from the original prompt: Country → Type → Bank → Currency → Balance today → Account name (optional) → a toggle for "specify a balance date" → Balance date (only shown when that toggle is on). For `type = cash`, the Bank field stays in place, is labeled "Cash", and is disabled. Changing Country clears the selected bank and refreshes the institution list for the new country.
- **`BankPickerView`** — a new reusable searchable combobox: a text field with a dropdown list below it (system + custom institutions for the current country, "Other bank" always last), filtered live by the search text. Keyboard support (ArrowUp/ArrowDown/Enter/Escape) via `.onKeyPress` (macOS 14+). Selecting "Other bank" swaps the dropdown for a required text input (max 100 characters) with a "back to list" affordance; an empty custom name is invalid.
- **`OnboardingView`** — per the Onboarding section above.
- **Dashboard** — the total-balance figure from the Dashboard section above, replacing the current bare placeholder text. No further Dashboard content is added in this iteration.

## Testing

Unit tests (XCTest), following the project's existing style (temp-directory-backed `ProfileStore`/`DatabaseConnection`, no mocking framework):

- Migrations: a fresh database ends up with the expected `user_version` and seeded system institutions; re-opening an already-migrated database is a no-op (idempotent).
- `InstitutionService`: search matches by name and alias, case-insensitively, for the examples from the original prompt (Kaspi.kz, Jusan, Tinkoff/Тинькофф, Сбер, BofA); "Other bank" always appears; duplicate custom institution names are deduplicated; an archived-name conflict returns the specific conflict case; changing country on an in-use custom institution is rejected; archiving a custom institution does not break accounts that already reference it; system institutions reject every mutation.
- `AccountService`: creating each of the 4 account types; `cash` accounts store no institution; the other 3 types require one; changing country clears the previously selected bank in the form-level flow; opening balance of `0` creates no transaction row, a positive balance creates exactly one; negative balance is rejected; over-8-decimal-digit balance is rejected; name auto-generation for each type; archive/restore round-trips.
- `DashboardService`: total-balance conversion across `USD`/`KZT` accounts using the hardcoded rate, with archived accounts excluded.
- `AppSession`: a brand-new profile's first screen after creation is `.onboarding`; `completeOnboarding()` persists the flag and transitions to `.mainShell`; a profile that already completed onboarding goes straight to `.mainShell` after login; a profile decoded from a pre-existing (no-onboarding-field) `profile.json` never sees `.onboarding`.

Dropped from the original prompt's acceptance criteria (see Deviations): the `hasFinancialHistory` type/currency lock, and "identical form behavior in Accounts and Onboarding."
