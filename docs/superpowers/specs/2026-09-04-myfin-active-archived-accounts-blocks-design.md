# Active/archived accounts as separate blocks

## Context

`AccountsListView` (`Sources/MyFin/Views/AccountsListView.swift`) currently renders all matched accounts in one flat `List(displayedAccounts, id: \.id)`, where `displayedAccounts` is `model.activeAccounts` with the "Показать архивные" toggle off, or `model.accounts` (active and archived mixed together, ordered by `created_at`) with it on. Each row (`AccountRowView`) already shows a per-row status label — "Активен" (green) or "Архивирован" (secondary gray) — via the existing `.activeStatusLabel`/`.archivedStatusLabel` L10n keys.

## Goal

When both active and archived accounts are visible (toggle on), show them as two explicitly separated blocks — active accounts on top, archived accounts below — instead of one intermixed list.

## Design

Replace the flat `List` with a sectioned one:

```swift
if displayedAccounts.isEmpty {
    Text(preferences.string(.noAccountsYet)).foregroundStyle(.secondary)
    Spacer()
} else {
    List {
        if !model.activeAccounts.isEmpty {
            Section(preferences.string(.activeAccountsSectionTitle)) {
                ForEach(model.activeAccounts) { account in
                    AccountRowView(account: account, institutionOrCountryLabel: institutionOrCountryLabel(for: account), onEdit: { editingAccount = account }, onToggleArchive: { toggleArchive(account) })
                }
            }
        }
        if showArchived {
            let archivedAccounts = model.accounts.filter(\.archived)
            if !archivedAccounts.isEmpty {
                Section(preferences.string(.archivedAccountsSectionTitle)) {
                    ForEach(archivedAccounts) { account in
                        AccountRowView(account: account, institutionOrCountryLabel: institutionOrCountryLabel(for: account), onEdit: { editingAccount = account }, onToggleArchive: { toggleArchive(account) })
                    }
                }
            }
        }
    }
}
```

- With the toggle **off**: only the active section renders (no archived section, and — since there's only one group — a section header showing above it is harmless but present; this is an acceptable, minor cosmetic change from today's headerless list, not worth special-casing away).
- With the toggle **on**: active section on top, archived section below, each hidden individually if empty (e.g. toggle on with zero archived accounts shows only the active section, matching intuition — nothing calls out an empty "Архивные счета" block for no reason).
- `displayedAccounts.isEmpty` (existing computed property, unchanged) still gates the single overall empty-state message — it's already `showArchived ? model.accounts : model.activeAccounts`, so it's empty exactly when there is nothing to show in either section.

**Per-row status text removed:** `AccountRowView`'s `Text(account.archived ? ... : ...)` status label/color line is deleted — the section it now sits in already conveys active/archived, so the per-row badge duplicates that. Every other part of the row (name, institution/country label, type, currency, balance, Edit/Archive-Restore buttons) is unchanged.

## New localization keys (2)

| Key | ru | en |
|---|---|---|
| `.activeAccountsSectionTitle` | Активные счета | Active accounts |
| `.archivedAccountsSectionTitle` | Архивные счета | Archived accounts |

`.activeStatusLabel`/`.archivedStatusLabel` remain defined (still used elsewhere, e.g. `CustomInstitutionsView`'s row) — only `AccountRowView`'s usage of them is removed.

## Testing

No new tests — `AccountsListView`/`AccountRowView` have none today (consistent with this codebase's zero View-level XCTest coverage). Verified by `swift build` + `swift test` (regression safety) plus a manual look at the running app.

## Out of scope

- The "Показать архивные" toggle's own behavior is unchanged — it still controls whether archived accounts appear at all; this feature only changes how they're grouped once visible.
- No change to sort order within each section (still `created_at ASC`, via `AccountsListModel`/`AccountService.listAccounts`, unchanged).
- No change to `CustomInstitutionsView`'s or the sidebar's account lists — this is scoped to the "Счета" page only.
