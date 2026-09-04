# Account Row Subtitle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On the "Счета" page, show each account's bank name, country, currency, and type together in the caption line under its name, and drop the separate right-aligned type/currency columns.

**Architecture:** Rename `AccountsListView`'s `institutionOrCountryLabel(for:)` to `accountSubtitle(for:)`, extend it to join up to 4 parts (institution, country, currency, type) with `" · "`, rename `AccountRowView`'s corresponding property/argument from `institutionOrCountryLabel` to `subtitle`, and delete the two now-redundant `Text` lines from its body.

**Tech Stack:** Swift 5.9, SwiftUI, Swift Package Manager (no Xcode project).

**Spec:** `docs/superpowers/specs/2026-09-04-myfin-account-row-subtitle-design.md`

## Global Constraints

- **No git** in this project (neither `MyFinLocal/` nor `MyFinLocal/MyFin/` is a git repository) — never run `git` commands; the "Commit" step below is skipped, left in the template only where the plan format requires it.
- **Swift toolchain is available and verified working in this environment** — run every `swift build` / `swift test` step yourself, directly via Bash, from `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin`. Only the manual look-at-the-running-app step (explicitly marked "Hand to human partner") needs the human.
- Country is shown on **every** row now, not only for cash accounts / an unresolved institution — this is a real behavior addition for the normal-bank-account case, not just a rename.
- No new tests — `AccountsListView`/`AccountRowView` have none today, consistent with this codebase's existing convention of zero View-level XCTest coverage. Verified by `swift build` + `swift test` + a manual look at the running app.

## File Structure

- Modify: `Sources/MyFin/Views/AccountsListView.swift` — rename/extend the subtitle-building function, rename the `AccountRowView` property, remove the two redundant `Text` lines (Task 1).

---

### Task 1: Rename and extend the subtitle, trim the row

**Files:**
- Modify: `Sources/MyFin/Views/AccountsListView.swift`

**Interfaces:**
- Consumes: existing `Account` (`name`, `country: Country` with `.flag`/`.displayName`, `currency: Currency` with `.rawValue`, `type: AccountType` with `.displayName`, `institutionId: String?`, `type != .cash` check), existing `session.connection` SQL lookup pattern, existing `NumberDisplayFormatter.format(_:preferences:)`.
- Produces: none — this is the only task in this plan.

- [x] **Step 1: Rename and extend the subtitle-building function**

In `Sources/MyFin/Views/AccountsListView.swift`, change:

```swift
    private func institutionOrCountryLabel(for account: Account) -> String {
        guard account.type != .cash, let institutionId = account.institutionId, let connection = session.connection else {
            return "\(account.country.flag) \(account.country.displayName)"
        }
        let rows = (try? connection.query("SELECT name FROM institutions WHERE id = ?;", params: [.text(institutionId)])) ?? []
        if case let .text(name)? = rows.first?["name"] {
            return name
        }
        return "\(account.country.flag) \(account.country.displayName)"
    }
```

to:

```swift
    private func accountSubtitle(for account: Account) -> String {
        var parts: [String] = []
        if let institutionName = institutionName(for: account) {
            parts.append(institutionName)
        }
        parts.append("\(account.country.flag) \(account.country.displayName)")
        parts.append(account.currency.rawValue)
        parts.append(account.type.displayName)
        return parts.joined(separator: " · ")
    }

    private func institutionName(for account: Account) -> String? {
        guard account.type != .cash, let institutionId = account.institutionId, let connection = session.connection else {
            return nil
        }
        let rows = (try? connection.query("SELECT name FROM institutions WHERE id = ?;", params: [.text(institutionId)])) ?? []
        if case let .text(name)? = rows.first?["name"] {
            return name
        }
        return nil
    }
```

- [x] **Step 2: Update both `AccountRowView` construction call sites**

In `Sources/MyFin/Views/AccountsListView.swift`, inside the active-accounts `Section`, change:

```swift
                                AccountRowView(
                                    account: account,
                                    institutionOrCountryLabel: institutionOrCountryLabel(for: account),
                                    numberFormatPreferences: session.numberFormatPreferences,
                                    onEdit: { editingAccount = account },
                                    onToggleArchive: { toggleArchive(account) }
                                )
```

to:

```swift
                                AccountRowView(
                                    account: account,
                                    subtitle: accountSubtitle(for: account),
                                    numberFormatPreferences: session.numberFormatPreferences,
                                    onEdit: { editingAccount = account },
                                    onToggleArchive: { toggleArchive(account) }
                                )
```

and, separately, inside the archived-accounts `Section` (note its deeper indentation — this is a distinct block of text in the file, not the same one matched twice), change:

```swift
                                    AccountRowView(
                                        account: account,
                                        institutionOrCountryLabel: institutionOrCountryLabel(for: account),
                                        numberFormatPreferences: session.numberFormatPreferences,
                                        onEdit: { editingAccount = account },
                                        onToggleArchive: { toggleArchive(account) }
                                    )
```

to:

```swift
                                    AccountRowView(
                                        account: account,
                                        subtitle: accountSubtitle(for: account),
                                        numberFormatPreferences: session.numberFormatPreferences,
                                        onEdit: { editingAccount = account },
                                        onToggleArchive: { toggleArchive(account) }
                                    )
```

- [x] **Step 3: Update `AccountRowView` itself**

In the same file, change:

```swift
private struct AccountRowView: View {
    let account: Account
    let institutionOrCountryLabel: String
    let numberFormatPreferences: NumberFormatPreferences
    let onEdit: () -> Void
    let onToggleArchive: () -> Void

    @EnvironmentObject var preferences: AppPreferences

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(account.name).font(.headline)
                Text(institutionOrCountryLabel).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(account.type.displayName)
            Text(account.currency.rawValue)
            Text(NumberDisplayFormatter.format(account.openingBalance, preferences: numberFormatPreferences))
            Button(preferences.string(.editButton), action: onEdit)
            Button(account.archived ? preferences.string(.restoreButton) : preferences.string(.archiveButton), action: onToggleArchive)
        }
    }
}
```

to:

```swift
private struct AccountRowView: View {
    let account: Account
    let subtitle: String
    let numberFormatPreferences: NumberFormatPreferences
    let onEdit: () -> Void
    let onToggleArchive: () -> Void

    @EnvironmentObject var preferences: AppPreferences

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(account.name).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(NumberDisplayFormatter.format(account.openingBalance, preferences: numberFormatPreferences))
            Button(preferences.string(.editButton), action: onEdit)
            Button(account.archived ? preferences.string(.restoreButton) : preferences.string(.archiveButton), action: onToggleArchive)
        }
    }
}
```

- [x] **Step 4: Build**

Run: `swift build`
Expected: build succeeds with no errors.

- [x] **Step 5: Run the full test suite**

Run: `swift test`
Expected: all 135 tests still pass (this task adds none of its own).

- [ ] **Step 6: Manual look at the running app**

Hand to human partner. Run: `swift run` from `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin`
Ask them to open "Счета" and confirm: each row's caption line under the account name now reads bank name (if any) · country flag+name · currency · type, all together; a cash account's caption shows country · currency · type with no bank name; the type/currency no longer appear as separate columns on the right; the balance and Edit/Archive-Restore buttons still work as before.
Expected: everything above behaves as described.

- [x] **Step 7: Commit**

Skipped — this project does not use git (see Global Constraints).

---

## Self-Review Notes

- **Spec coverage:** the spec's one design section maps entirely to this single task — subtitle-building logic (Step 1), both call sites (Step 2), and the trimmed row (Step 3).
- **No placeholders:** every step has complete, exact before/after code, including both call sites individually (not "update both similarly").
- **Type/name consistency checked:** `accountSubtitle(for:)` → `String` (Step 1) is called identically at both sites in Step 2; `AccountRowView`'s `subtitle` property (Step 3) matches the `subtitle:` argument label used in Step 2.
