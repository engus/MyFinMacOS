# Active/Archived Accounts Blocks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On the "Счета" page, show active accounts and archived accounts as two explicitly separated blocks instead of one intermixed list.

**Architecture:** Replace `AccountsListView`'s single flat `List(displayedAccounts, id: \.id)` with a `List` containing an "Активные счета" `Section` (always, when non-empty) and an "Архивные счета" `Section` (only when the "Показать архивные" toggle is on and there's at least one archived account). Remove `AccountRowView`'s per-row active/archived status text, since the section it now sits in already conveys that.

**Tech Stack:** Swift 5.9, SwiftUI, XCTest, Swift Package Manager (no Xcode project).

**Spec:** `docs/superpowers/specs/2026-09-04-myfin-active-archived-accounts-blocks-design.md`

## Global Constraints

- **No git** in this project (neither `MyFinLocal/` nor `MyFinLocal/MyFin/` is a git repository) — never run `git` commands; every "Commit" step below is skipped, left in the template only where the plan format requires it.
- **Swift toolchain is available and verified working in this environment** — run every `swift build` / `swift test` step yourself, directly via Bash, from `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin`. Only the manual look-at-the-running-app step (explicitly marked "Hand to human partner") needs the human.
- The "Показать архивные" toggle's own behavior is unchanged — off shows only active accounts, on shows both blocks. This plan only changes how accounts are grouped once visible, per the spec's "Out of scope" section.
- No new tests for `AccountsListView`/`AccountRowView` — consistent with this codebase's existing convention of zero View-level XCTest coverage. Verified by `swift build` + `swift test` + a manual look at the running app.

## File Structure

- Modify: `Sources/MyFin/Localization.swift` — 2 new `L10nKey` cases + ru/en entries (Task 1).
- Modify: `Tests/MyFinTests/LocalizationTests.swift` — value assertions for the 2 new keys (Task 1).
- Modify: `Sources/MyFin/Views/AccountsListView.swift` — sectioned list + remove per-row status text (Task 2).

---

### Task 1: Localization — 2 new keys

**Files:**
- Modify: `Sources/MyFin/Localization.swift`
- Test: `Tests/MyFinTests/LocalizationTests.swift`

**Interfaces:**
- Produces (for Task 2): `L10nKey` cases `.activeAccountsSectionTitle`, `.archivedAccountsSectionTitle`.

- [x] **Step 1: Write the failing tests**

Add to `Tests/MyFinTests/LocalizationTests.swift`, inside `LocalizationTests`:

```swift
    func test_activeAccountsSectionTitle_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.activeAccountsSectionTitle], "Активные счета")
    }

    func test_archivedAccountsSectionTitle_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.archivedAccountsSectionTitle], "Архивные счета")
    }
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter MyFinTests.LocalizationTests`
Expected: build failure — the 2 new `L10nKey` cases referenced by these tests don't exist yet.

- [x] **Step 3: Add the new keys**

In `Sources/MyFin/Localization.swift`, add to the `L10nKey` enum (anywhere in the case list, e.g. right after `.institutionArchivedConflictMessage`):

```swift
    case activeAccountsSectionTitle
    case archivedAccountsSectionTitle
```

Add to the `ru` dictionary (anywhere, e.g. right after `.institutionArchivedConflictMessage: "..."`,):

```swift
        .activeAccountsSectionTitle: "Активные счета",
        .archivedAccountsSectionTitle: "Архивные счета",
```

Add to the `en` dictionary (same position, mirroring the `ru` block above):

```swift
        .activeAccountsSectionTitle: "Active accounts",
        .archivedAccountsSectionTitle: "Archived accounts",
```

- [x] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter MyFinTests.LocalizationTests`
Expected: all `LocalizationTests` pass, including the 2 new ones.

- [x] **Step 5: Run the full test suite**

Run: `swift test`
Expected: all 107 previously-passing tests still pass, plus the 2 new ones (109 total).

- [x] **Step 6: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 2: Sectioned list + remove redundant per-row status

**Files:**
- Modify: `Sources/MyFin/Views/AccountsListView.swift`

**Interfaces:**
- Consumes: `L10nKey.activeAccountsSectionTitle` / `.archivedAccountsSectionTitle` (Task 1); existing `AccountsListModel.accounts: [Account]` / `.activeAccounts: [Account]`; existing `Account` (`Identifiable` via `id: String`, has `archived: Bool`).
- Produces: none — this is the final task in this plan.

- [x] **Step 1: Replace the flat list with sectioned blocks**

In `Sources/MyFin/Views/AccountsListView.swift`, change:

```swift
            if displayedAccounts.isEmpty {
                Text(preferences.string(.noAccountsYet)).foregroundStyle(.secondary)
                Spacer()
            } else {
                List(displayedAccounts, id: \.id) { account in
                    AccountRowView(
                        account: account,
                        institutionOrCountryLabel: institutionOrCountryLabel(for: account),
                        onEdit: { editingAccount = account },
                        onToggleArchive: { toggleArchive(account) }
                    )
                }
            }
```

to:

```swift
            if displayedAccounts.isEmpty {
                Text(preferences.string(.noAccountsYet)).foregroundStyle(.secondary)
                Spacer()
            } else {
                List {
                    if !model.activeAccounts.isEmpty {
                        Section(preferences.string(.activeAccountsSectionTitle)) {
                            ForEach(model.activeAccounts) { account in
                                AccountRowView(
                                    account: account,
                                    institutionOrCountryLabel: institutionOrCountryLabel(for: account),
                                    onEdit: { editingAccount = account },
                                    onToggleArchive: { toggleArchive(account) }
                                )
                            }
                        }
                    }
                    if showArchived {
                        let archivedAccounts = model.accounts.filter(\.archived)
                        if !archivedAccounts.isEmpty {
                            Section(preferences.string(.archivedAccountsSectionTitle)) {
                                ForEach(archivedAccounts) { account in
                                    AccountRowView(
                                        account: account,
                                        institutionOrCountryLabel: institutionOrCountryLabel(for: account),
                                        onEdit: { editingAccount = account },
                                        onToggleArchive: { toggleArchive(account) }
                                    )
                                }
                            }
                        }
                    }
                }
            }
```

(`displayedAccounts` itself — the computed property already used by the `if displayedAccounts.isEmpty` check above — is unchanged; it still correctly gates the single overall empty-state message, since it's empty exactly when both `model.activeAccounts` and, if `showArchived` is on, the archived set are empty.)

- [x] **Step 2: Remove the redundant per-row status text**

In the same file, in `AccountRowView`'s `body`, change:

```swift
            Text(account.type.displayName)
            Text(account.currency.rawValue)
            Text("\(account.openingBalance)")
            Text(account.archived ? preferences.string(.archivedStatusLabel) : preferences.string(.activeStatusLabel))
                .foregroundStyle(account.archived ? Color.secondary : Color.green)
            Button(preferences.string(.editButton), action: onEdit)
```

to:

```swift
            Text(account.type.displayName)
            Text(account.currency.rawValue)
            Text("\(account.openingBalance)")
            Button(preferences.string(.editButton), action: onEdit)
```

- [x] **Step 3: Build**

Run: `swift build`
Expected: build succeeds with no errors.

- [x] **Step 4: Run the full test suite**

Run: `swift test`
Expected: all 109 tests still pass.

- [ ] **Step 5: Manual look at the running app**

Hand to human partner. Run: `swift run` from `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin`
Ask them to confirm on the "Счета" page: with "Показать архивные" off, only active accounts show, under an "Активные счета" header; turn it on with at least one archived account present — an "Архивные счета" block appears below the active one; turn it on with zero archived accounts — no archived block appears at all; confirm no row shows the old green/gray "Активен"/"Архивирован" text anymore; confirm Edit and Archive/Restore buttons still work on rows in both sections.
Expected: everything above behaves as described.

- [x] **Step 6: Commit**

Skipped — this project does not use git (see Global Constraints).

---

## Self-Review Notes

- **Spec coverage:** the spec's single design section (sectioned list, per-row status removal, 2 new keys, toggle behavior unchanged) maps to Task 1 (keys) and Task 2 (view changes). The spec's "Out of scope" items (toggle behavior, sort order, other account lists) are respected — nothing in either task touches `AccountsListModel`, `AccountService`, the sidebar, or `CustomInstitutionsView`.
- **No placeholders:** every step has complete, exact before/after code.
- **Type/name consistency checked:** `.activeAccountsSectionTitle` / `.archivedAccountsSectionTitle` (Task 1) are referenced with those exact names in Task 2; `model.activeAccounts` / `model.accounts` match `AccountsListModel`'s existing property names unchanged from prior work this session.
