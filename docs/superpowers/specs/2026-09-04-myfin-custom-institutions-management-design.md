# Custom institutions management (Settings → Банки tab)

## Context

MyFin already distinguishes system institutions (`source = 'system'`, read-only, seeded from the built-in catalog) from custom institutions (`source = 'custom'`, created ad hoc by a user picking "Other bank" while creating/editing an account, via `InstitutionService.resolveOrCreateCustomInstitution`). Once created, a custom institution has no visible home anywhere in the app — the user can only encounter it again by re-opening the bank picker for the same country. `InstitutionService` already has full rename/archive/restore/change-country support for custom institutions (`renameCustomInstitution`, `archiveCustomInstitution`, `restoreCustomInstitution`, `changeCustomInstitutionCountry`); none of it is reachable from any screen today.

## Goal

Give the user a place — a new tab in Settings — to see every custom institution they've created (across all countries), and to add, rename, change the country of, archive, and restore them.

There is no hard delete anywhere else in this app (accounts included) — only archive/restore. "Delete" in this feature means archive, for the same reason.

## 1. Service layer — one new read method

Add to `InstitutionService` (`Sources/MyFin/Services/InstitutionService.swift`):

```swift
func listCustomInstitutions(includeArchived: Bool) -> [Institution] {
    let sql = includeArchived
        ? "SELECT * FROM institutions WHERE source = 'custom' ORDER BY country ASC, name ASC;"
        : "SELECT * FROM institutions WHERE source = 'custom' AND archived = 0 ORDER BY country ASC, name ASC;"
    let rows = (try? connection.query(sql)) ?? []
    return rows.compactMap(Self.rowToInstitution)
}
```

This mirrors `AccountService.listAccounts(includeArchived:)`'s existing shape exactly. Every other operation this feature needs (`renameCustomInstitution`, `archiveCustomInstitution`, `restoreCustomInstitution`, `changeCustomInstitutionCountry`, `resolveOrCreateCustomInstitution`) already exists, unchanged.

## 2. Settings gains real tabs

`SettingsView` (`Sources/MyFin/Views/SettingsView.swift`) gets a segmented control at the top, replacing its single always-shown `Form`:

```swift
enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case institutions
    var id: String { rawValue }
}
```

- `.general` renders the exact `Form` that exists today (Профиль, Смена пароля, Оформление и язык, Базовая валюта, Выйти, Удалить профиль) — completely unchanged, just now inside one branch of a `switch selectedTab`.
- `.institutions` renders the new `CustomInstitutionsView(session: session)`.

`@State private var selectedTab: SettingsTab = .general` — not persisted; Settings always opens on "Общее".

## 3. New tab: `CustomInstitutionsView` (list) + `CustomInstitutionFormView` (add/edit)

New file `Sources/MyFin/Views/CustomInstitutionsView.swift`, containing both views (small enough to share a file, same pattern as `AccountsListView.swift` housing its private `AccountRowView`).

**`CustomInstitutionsView`** — list, styled like `AccountsListView`:
- Toolbar row: "Показать архивные" toggle (reuses `.showArchivedToggle`), "Добавить банк" button (new `.addCustomInstitutionButton`).
- Empty state: new `.noCustomInstitutionsYet`.
- Otherwise a `List` of rows: name, country (`institution.country.displayName`), status (reuses `.activeStatusLabel`/`.archivedStatusLabel`), an "Изменить" button (reuses `.editButton`, opens the form sheet) and an "Архивировать"/"Восстановить" button (reuses `.archiveButton`/`.restoreButton`, calls `archiveCustomInstitution`/`restoreCustomInstitution` directly, then reloads).
- Data source: `institutionService.listCustomInstitutions(includeArchived: showArchived)`, reloaded `onAppear`, on the archived-toggle change, and on sheet dismiss — same reload-on-every-mutation pattern `AccountsListView` used before its Task-3 refactor (no shared observable model here; this list has no sibling consumer the way accounts now has the sidebar, so the extra machinery isn't warranted — YAGNI).

**`CustomInstitutionFormView`** — one sheet for both add and edit, mirroring `AccountFormView`'s `existingAccount: Account?` pattern:

```swift
struct CustomInstitutionFormView: View {
    let session: AppSession
    let existingInstitution: Institution?

    @State private var country: Country
    @State private var name: String
    @State private var errorMessage: String?

    init(session: AppSession, existingInstitution: Institution?) {
        self.session = session
        self.existingInstitution = existingInstitution
        _country = State(initialValue: existingInstitution?.country ?? .kz)
        _name = State(initialValue: existingInstitution?.name ?? "")
    }
    ...
}
```

(Initial `@State` is set via `init`, not `.onAppear`, for the same reason as the account-editing bugfix earlier this session: assigning `@State` in `.onAppear` creates a spurious first "change" that any `.onChange` on that property would react to. This form has no such `.onChange`, but starting `@State` correctly from `init` is now the established, safer pattern in this codebase for any form that edits an optional existing model.)

Fields: a `Picker` over `Country.allCases` (reuses `.countryFieldLabel`) and a `TextField` (reuses `.customBankNameField`). Save/Cancel buttons reuse `.saveButton`/`.cancelButton`.

`save()`:
- No existing institution → `institutionService.resolveOrCreateCustomInstitution(name:country:)`.
- Existing institution, name changed → `renameCustomInstitution(id:name:)`.
- Existing institution, country changed → `changeCustomInstitutionCountry(id:country:)` (only called if the rename step, when attempted, succeeded or wasn't needed).
- Any `InstitutionError` failure maps to an inline `errorMessage`:
  - `.invalidName` → reuses `.invalidCustomBankNameMessage`.
  - `.inUse` → new `.institutionInUseMessage` ("Нельзя сменить страну — банк уже используется в счетах").
  - `.conflictWithArchived` → new `.institutionArchivedConflictMessage` ("Банк с таким названием уже существует в архиве — восстановите его из списка").
  - `.systemInstitutionIsReadOnly` / `.notFound` → reuses `.invalidCustomBankNameMessage` as a generic fallback (can't practically occur here, since this form only ever operates on institutions already fetched from `listCustomInstitutions`, which excludes system institutions by construction — same "fallback for an unreachable case" shortcut `AccountFormView.save()` already uses today).
- On success, `dismiss()`.

## New localization keys (6)

| Key | ru | en |
|---|---|---|
| `.settingsTabGeneral` | Общее | General |
| `.settingsTabInstitutions` | Банки | Banks |
| `.addCustomInstitutionButton` | Добавить банк | Add bank |
| `.noCustomInstitutionsYet` | Пока нет добавленных банков | No custom banks yet |
| `.institutionInUseMessage` | Нельзя сменить страну — банк уже используется в счетах | Can't change country — this bank is already used by an account |
| `.institutionArchivedConflictMessage` | Банк с таким названием уже существует в архиве — восстановите его из списка | A bank with this name already exists, archived — restore it from the list instead |

Every other label reuses an existing `L10nKey` (see section 3).

## Testing

- New `InstitutionServiceTests` cases for `listCustomInstitutions(includeArchived:)`: returns only `source = 'custom'` rows (a seeded system institution like `kz.halyk-bank` must never appear), excludes archived by default, includes archived when asked, spans multiple countries in one call.
- No new tests for `CustomInstitutionsView`/`CustomInstitutionFormView`/the `SettingsView` tab switch — consistent with this codebase's existing convention of zero View-level XCTest coverage anywhere (verified: no test file touches any SwiftUI `View` type in this project). Verification is `swift build` + `swift test` (regression safety) plus a manual walkthrough.

## Out of scope

- No hard delete — archive/restore only, matching every other entity in this app.
- No bulk actions (multi-select archive, etc.).
- No change to how the account-creation "Other bank" flow works — it still calls `resolveOrCreateCustomInstitution` exactly as it does today; this feature only adds a second place to see/manage the institutions that flow already creates.
- Tab selection is not persisted across Settings re-opens.
