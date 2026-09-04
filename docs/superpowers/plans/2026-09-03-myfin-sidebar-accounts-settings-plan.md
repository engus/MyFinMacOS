# MyFin Sidebar Accounts & Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename two Russian sidebar labels, show active accounts (name + balance) directly under "Счета" in the sidebar as a collapsible list, and move Settings to the bottom of the sidebar as the profile's icon + display name instead of the word "Настройки".

**Architecture:** Introduce one new `ObservableObject`, `AccountsListModel`, owned by `MainShellView` and shared with `AccountsListView` (replacing `AccountsListView`'s private local account state) so the sidebar and the Accounts page always show the same data. Restructure `MainShellView`'s sidebar `List` from a flat `ForEach` over all five `SidebarItem` cases into: Dashboard row, a `DisclosureGroup` for Accounts (with per-account rows underneath), Cashflow row, Assets row — with Settings pulled out of the list entirely and rendered as a pinned bottom row.

**Tech Stack:** Swift 5.9, SwiftUI, SQLCipher.swift, XCTest, Swift Package Manager (no Xcode project).

**Spec:** `docs/superpowers/specs/2026-09-03-myfin-sidebar-accounts-settings-design.md`

## Global Constraints

- **No git** in this project (neither `MyFinLocal/` nor `MyFinLocal/MyFin/` is a git repository) — never run `git` commands; every "Commit" step below is skipped, left in the template only where the plan format requires it.
- **Swift toolchain is available and verified working in this environment** — `swift build` and `swift test` were both run directly via Bash immediately before this plan was written (clean build, 91/91 tests passing). Run every `swift build` / `swift test` step yourself, directly, from the `MyFin/` package directory (`/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin`) — do not hand these off to the human partner. Only hand off the manual in-app UI walkthrough steps (explicitly marked "Hand to human partner" below), since driving the running macOS GUI app is not something you can do yourself.
- Only **Russian** localized strings change. English strings in `Localization.swift` are untouched.
- The account balance shown anywhere in this feature is `account.openingBalance` in the account's own currency — there is no transaction ledger/running balance yet, so this is the same value `AccountsListView` already displays. No currency conversion.
- No per-account detail page exists or is created by this plan — tapping an account row in the sidebar navigates to the existing "Счета" (Accounts) page, exactly like tapping "Счета" itself.
- The sidebar's accounts `DisclosureGroup` starts expanded (`true`) and its expand/collapse state is plain `@State`, not persisted across app launches.
- `SidebarItem.settings` remains a valid enum case and the existing `detail:` `switch selection` in `MainShellView` keeps its `.settings` branch unchanged — only the sidebar's top-level `List` stops iterating it.

## File Structure

- Modify: `Sources/MyFin/Localization.swift` — three Russian string values change (Task 1).
- Modify: `Tests/MyFinTests/LocalizationTests.swift` — add value assertions for the three changed strings (Task 1).
- Create: `Sources/MyFin/Services/AccountsListModel.swift` — shared `ObservableObject` wrapping `AccountService` for one profile's account list (Task 2).
- Create: `Tests/MyFinTests/AccountsListModelTests.swift` — unit tests for `AccountsListModel` (Task 2).
- Modify: `Sources/MyFin/Views/AccountsListView.swift` — drop private account state, consume `AccountsListModel` instead (Task 3).
- Modify: `Sources/MyFin/Views/MainShellView.swift` — own `AccountsListModel`, wire it into `AccountsListView` (Task 3); add the accounts `DisclosureGroup` to the sidebar (Task 4); pull Settings out into a pinned bottom row (Task 5).

---

### Task 1: Rename Russian sidebar labels

**Files:**
- Modify: `Sources/MyFin/Localization.swift`
- Test: `Tests/MyFinTests/LocalizationTests.swift`

**Interfaces:** None — pure string content change, no new keys, no signature changes.

- [x] **Step 1: Write the failing tests**

Add to `Tests/MyFinTests/LocalizationTests.swift`, inside `LocalizationTests`:

```swift
func test_sidebarAccounts_ru_isSchyota() {
    XCTAssertEqual(Localization.ru[.sidebarAccounts], "Счета")
}

func test_sidebarCashflow_ru_isDohodyIRashody() {
    XCTAssertEqual(Localization.ru[.sidebarCashflow], "Доходы и расходы")
}

func test_cashflowPlaceholder_ru_matchesNewCashflowLabel() {
    XCTAssertEqual(Localization.ru[.cashflowPlaceholder], "Доходы и расходы — здесь скоро появится содержимое")
}
```

- [x] **Step 2: Run the tests to verify they fail**

Run (from `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin`): `swift test --filter MyFinTests.LocalizationTests`
Expected: 3 new failures — `sidebarAccounts` is still `"Аккаунты"`, `sidebarCashflow` is still `"Cashflow"`, `cashflowPlaceholder` still starts with `"Cashflow —"`. The two pre-existing `LocalizationTests` still pass.

- [x] **Step 3: Update the Russian strings**

In `Sources/MyFin/Localization.swift`, in the `ru` dictionary, change:

```swift
        .sidebarAccounts: "Аккаунты",
```
to:
```swift
        .sidebarAccounts: "Счета",
```

change:
```swift
        .sidebarCashflow: "Cashflow",
```
to:
```swift
        .sidebarCashflow: "Доходы и расходы",
```

and change:
```swift
        .cashflowPlaceholder: "Cashflow — здесь скоро появится содержимое",
```
to:
```swift
        .cashflowPlaceholder: "Доходы и расходы — здесь скоро появится содержимое",
```

Leave every entry in the `en` dictionary exactly as it is.

- [x] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter MyFinTests.LocalizationTests`
Expected: all 5 `LocalizationTests` tests pass.

- [x] **Step 5: Run the full test suite**

Run: `swift test`
Expected: all 91 previously-passing tests still pass, plus the 3 new ones (94 total). Nothing else references the literal strings `"Аккаунты"` or `"Cashflow"`, so no other test should be affected.

- [x] **Step 6: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 2: `AccountsListModel` — shared account list state

**Files:**
- Create: `Sources/MyFin/Services/AccountsListModel.swift`
- Test: `Tests/MyFinTests/AccountsListModelTests.swift`

**Interfaces:**
- Consumes: existing `AppSession` (`session.connection: DatabaseConnection?`), existing `AccountService(connection:institutionService:)`, `AccountService.listAccounts(includeArchived:) -> [Account]`, `AccountService.archiveAccount(id:) -> Result<Account, AccountError>`, `AccountService.restoreAccount(id:) -> Result<Account, AccountError>`, existing `InstitutionService(connection:)`, existing `Account` (has `id: String`, `archived: Bool`).
- Produces (for Task 3 and later):
  - `@MainActor final class AccountsListModel: ObservableObject`
  - `init(session: AppSession)`
  - `@Published private(set) var accounts: [Account]` — **all** accounts (archived and active), loaded via `includeArchived: true`.
  - `var activeAccounts: [Account]` — `accounts` filtered to `!archived`.
  - `func reload()`
  - `func archive(_ account: Account)`
  - `func restore(_ account: Account)`

- [x] **Step 1: Write the failing tests**

Create `Tests/MyFinTests/AccountsListModelTests.swift`:

```swift
import XCTest
@testable import MyFin

private struct StubAuthenticator: BiometricAuthenticating {
    let result: Bool
    func authenticate(reason: String) async -> Bool { result }
}

@MainActor
final class AccountsListModelTests: XCTestCase {
    var tempDirectory: URL!
    var session: AppSession!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyFinAccountsListModelTests-\(UUID().uuidString)", isDirectory: true)
        let store = ProfileStore(baseDirectory: tempDirectory)
        let keychain = KeychainService(service: "com.myfin.local.tests.accountslistmodel")
        session = AppSession(profileStore: store, keychain: keychain, authenticator: StubAuthenticator(result: true))
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    @discardableResult
    private func createAccount(named name: String) -> Account {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        let result = accounts.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .usd, openingBalance: 100, name: name, balanceDate: nil
        )
        guard case .success(let account) = result else { fatalError("expected success creating test account") }
        return account
    }

    func test_reload_populatesAccountsFromService() {
        let model = AccountsListModel(session: session)
        createAccount(named: "Cash A")

        model.reload()

        XCTAssertEqual(model.accounts.map(\.name), ["Cash A"])
    }

    func test_activeAccounts_excludesArchivedAccounts() {
        let model = AccountsListModel(session: session)
        let toArchive = createAccount(named: "Cash A")
        createAccount(named: "Cash B")
        model.reload()

        model.archive(toArchive)

        XCTAssertEqual(model.accounts.count, 2, "archive() should reload, keeping both accounts in the full list")
        XCTAssertEqual(model.activeAccounts.map(\.name), ["Cash B"])
    }

    func test_restore_movesAccountBackIntoActiveAccounts() {
        let model = AccountsListModel(session: session)
        let account = createAccount(named: "Cash A")
        model.archive(account)

        model.restore(account)

        XCTAssertEqual(model.activeAccounts.map(\.name), ["Cash A"])
    }
}
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter MyFinTests.AccountsListModelTests`
Expected: build failure — `AccountsListModel` does not exist yet.

- [x] **Step 3: Create `AccountsListModel`**

Create `Sources/MyFin/Services/AccountsListModel.swift`:

```swift
import Foundation

@MainActor
final class AccountsListModel: ObservableObject {
    @Published private(set) var accounts: [Account] = []

    private weak var session: AppSession?

    init(session: AppSession) {
        self.session = session
    }

    var activeAccounts: [Account] {
        accounts.filter { !$0.archived }
    }

    private var accountService: AccountService? {
        guard let connection = session?.connection else { return nil }
        return AccountService(connection: connection, institutionService: InstitutionService(connection: connection))
    }

    func reload() {
        accounts = accountService?.listAccounts(includeArchived: true) ?? []
    }

    func archive(_ account: Account) {
        _ = accountService?.archiveAccount(id: account.id)
        reload()
    }

    func restore(_ account: Account) {
        _ = accountService?.restoreAccount(id: account.id)
        reload()
    }
}
```

- [x] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter MyFinTests.AccountsListModelTests`
Expected: all 3 new tests pass.

- [x] **Step 5: Run the full test suite**

Run: `swift test`
Expected: 94 + 3 = 97 tests pass, 0 failures.

- [x] **Step 6: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 3: Wire `AccountsListModel` into `AccountsListView` and `MainShellView`

Pure state-lifting — no visible UI change yet. After this task, `AccountsListView` no longer owns its own account state or its own `AccountService`; both it and (starting in Task 4) the sidebar read from the same `AccountsListModel` owned by `MainShellView`.

**Files:**
- Modify: `Sources/MyFin/Views/AccountsListView.swift`
- Modify: `Sources/MyFin/Views/MainShellView.swift`

**Interfaces:**
- Consumes: `AccountsListModel` (Task 2) — `init(session:)`, `accounts`, `activeAccounts`, `reload()`, `archive(_:)`, `restore(_:)`.
- Produces (for Task 4 and Task 5): `MainShellView` has a `@StateObject private var accountsModel: AccountsListModel` property and an explicit `init(session: AppSession)`; `AccountsListView` takes `model: AccountsListModel` as a second required argument.

- [x] **Step 1: Rewrite `AccountsListView` to consume the shared model**

Replace the full contents of `Sources/MyFin/Views/AccountsListView.swift`:

```swift
import SwiftUI

struct AccountsListView: View {
    @ObservedObject var session: AppSession
    @ObservedObject var model: AccountsListModel
    @EnvironmentObject var preferences: AppPreferences

    @State private var showArchived = false
    @State private var showingCreate = false
    @State private var editingAccount: Account?

    private var displayedAccounts: [Account] {
        showArchived ? model.accounts : model.activeAccounts
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(preferences.string(.sidebarAccounts)).font(.largeTitle.bold())
                Spacer()
                Toggle(preferences.string(.showArchivedToggle), isOn: $showArchived)
                    .toggleStyle(.switch)
                Button(preferences.string(.createAccountButton)) { showingCreate = true }
            }
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
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { model.reload() }
        .sheet(isPresented: $showingCreate, onDismiss: { model.reload() }) {
            AccountFormView(session: session, existingAccount: nil)
        }
        .sheet(item: $editingAccount, onDismiss: { model.reload() }) { account in
            AccountFormView(session: session, existingAccount: account)
        }
    }

    private func toggleArchive(_ account: Account) {
        account.archived ? model.restore(account) : model.archive(account)
    }

    private func institutionOrCountryLabel(for account: Account) -> String {
        guard account.type != .cash, let institutionId = account.institutionId, let connection = session.connection else {
            return account.country.displayName
        }
        let rows = (try? connection.query("SELECT name FROM institutions WHERE id = ?;", params: [.text(institutionId)])) ?? []
        if case let .text(name)? = rows.first?["name"] {
            return name
        }
        return account.country.displayName
    }
}

private struct AccountRowView: View {
    let account: Account
    let institutionOrCountryLabel: String
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
            Text("\(account.openingBalance)")
            Text(account.archived ? preferences.string(.archivedStatusLabel) : preferences.string(.activeStatusLabel))
                .foregroundStyle(account.archived ? Color.secondary : Color.green)
            Button(preferences.string(.editButton), action: onEdit)
            Button(account.archived ? preferences.string(.restoreButton) : preferences.string(.archiveButton), action: onToggleArchive)
        }
    }
}
```

(This drops the private `accounts`/`accountService`/`reload()`/`toggleArchive()` that queried the database directly, and drops the `.onChange(of: showArchived)` handler — `displayedAccounts` now derives purely from `model`'s already-loaded data plus the local `showArchived` toggle, so no re-query is needed when the toggle flips. `AccountRowView` and `institutionOrCountryLabel(for:)` are unchanged.)

- [x] **Step 2: Update `MainShellView` to own the model and pass it down**

In `Sources/MyFin/Views/MainShellView.swift`, change:

```swift
struct MainShellView: View {
    @ObservedObject var session: AppSession
    @EnvironmentObject var preferences: AppPreferences
    @State private var selection: SidebarItem? = .dashboard

    var body: some View {
```

to:

```swift
struct MainShellView: View {
    @ObservedObject var session: AppSession
    @EnvironmentObject var preferences: AppPreferences
    @StateObject private var accountsModel: AccountsListModel
    @State private var selection: SidebarItem? = .dashboard

    init(session: AppSession) {
        self.session = session
        _accountsModel = StateObject(wrappedValue: AccountsListModel(session: session))
    }

    var body: some View {
```

Then change the `.accounts` branch of the `detail:` switch from:

```swift
            case .accounts:
                AccountsListView(session: session)
```

to:

```swift
            case .accounts:
                AccountsListView(session: session, model: accountsModel)
```

Finally, add a top-level `.onAppear` so the sidebar (wired up in Task 4) has data as soon as the shell appears, not only after the user first visits "Счета". Change the closing of the `NavigationSplitView`:

```swift
        }
    }
}
```

to:

```swift
        }
        .onAppear { accountsModel.reload() }
    }
}
```

- [x] **Step 3: Build**

Run: `swift build`
Expected: build succeeds with no errors. (`MainShellView(session: session)` at its one call site in `Sources/MyFin/MyFinApp.swift:38` still compiles unchanged, since the new `init(session:)` has the same external signature as the old implicit one.)

- [x] **Step 4: Run the full test suite**

Run: `swift test`
Expected: all 97 tests still pass — this task has no new unit tests of its own (no existing test file exercises `AccountsListView`/`MainShellView` directly; verification is the build plus the manual walkthrough below).

- [ ] **Step 5: Manual UI walkthrough**

Hand to human partner. Run: `swift run` from `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin`
Ask them to: log into (or create) a profile, open "Счета", create an account, confirm it appears in the list; archive it via the "Архивировать" button, confirm it disappears from the default (non-archived) view and reappears when "Показать архивные" is toggled on; restore it. Everything should behave exactly as before this task — this step only confirms the state-lifting refactor didn't change any visible behavior.
Expected: no behavior change from before this task. Confirm with the user before moving to Task 4.

- [x] **Step 6: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 4: Collapsible active-accounts list under "Счета" in the sidebar

**Files:**
- Modify: `Sources/MyFin/Views/MainShellView.swift`

**Interfaces:**
- Consumes: `accountsModel.activeAccounts: [Account]` (Task 2/3, already reloaded by the `.onAppear` added in Task 3); `Account.name: String`, `Account.openingBalance: Decimal`, `Account.currency: Currency` (existing, `Currency.rawValue: String`).
- Produces: `@State private var isAccountsExpanded = true` on `MainShellView`, used again in Task 5 only as-is (untouched).

- [x] **Step 1: Replace the flat sidebar `List` with one that expands "Счета" into a `DisclosureGroup`**

In `Sources/MyFin/Views/MainShellView.swift`, add a new state property next to `selection`:

```swift
    @State private var selection: SidebarItem? = .dashboard
    @State private var isAccountsExpanded = true
```

Then change the sidebar's `List`:

```swift
            List(selection: $selection) {
                ForEach(SidebarItem.allCases) { item in
                    Text(preferences.string(item.labelKey)).tag(item)
                }
            }
            .listStyle(.sidebar)
```

to:

```swift
            List(selection: $selection) {
                ForEach(SidebarItem.allCases) { item in
                    if item == .accounts {
                        DisclosureGroup(isExpanded: $isAccountsExpanded) {
                            ForEach(accountsModel.activeAccounts) { account in
                                HStack {
                                    Text(account.name)
                                    Spacer()
                                    Text("\(account.openingBalance) \(account.currency.rawValue)")
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { selection = .accounts }
                            }
                        } label: {
                            Text(preferences.string(item.labelKey)).tag(item)
                        }
                    } else {
                        Text(preferences.string(item.labelKey)).tag(item)
                    }
                }
            }
            .listStyle(.sidebar)
```

(`.settings` still comes through this `ForEach` unchanged for now — Task 5 removes it. `Account` is already `Identifiable` via its `id: String`, so `ForEach(accountsModel.activeAccounts)` needs no explicit `id:` parameter.)

- [x] **Step 2: Build**

Run: `swift build`
Expected: build succeeds with no errors.

- [x] **Step 3: Run the full test suite**

Run: `swift test`
Expected: all 97 tests still pass — no test in this codebase exercises `MainShellView`'s view tree (see Global Constraints/File Structure), so this is a build-only + manual check.

- [ ] **Step 4: Manual UI walkthrough**

Hand to human partner. Run: `swift run`
Ask them to: log into a profile with at least two active accounts (create them via "Счета" → "Создать счёт" if needed); confirm the sidebar shows "Счета" with a disclosure arrow, expanded by default, listing each active account's name and balance underneath; click the disclosure arrow to collapse and re-expand the list; click one of the account rows and confirm it opens the "Счета" detail page (same as clicking "Счета" itself); archive one of the accounts from the "Счета" page and confirm it disappears from the sidebar's list on next visit/refresh (it does not need to update live while the "Счета" page's own list is what's driving the archive — but since both share `accountsModel`, it should update immediately).
Expected: sidebar list matches the active accounts on the "Счета" page at all times. Confirm with the user before moving to Task 5.

- [x] **Step 5: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 5: Move Settings to the bottom of the sidebar as profile icon + name

**Files:**
- Modify: `Sources/MyFin/Views/MainShellView.swift`

**Interfaces:**
- Consumes: `session.unlockedProfile: Profile?` (existing), `Profile.iconName: String`, `Profile.iconColor: String`, `Profile.displayName: String`, `Profile.defaultIconName: String`, `Profile.defaultIconColor: String` (all existing), `ProfileIconPalette.color(named:) -> Color` (existing).
- Produces: none — this is the final task in this plan.

- [x] **Step 1: Exclude `.settings` from the top `List` and wrap the sidebar in a `VStack` with a pinned bottom row**

In `Sources/MyFin/Views/MainShellView.swift`, change the `ForEach` inside the `List` from:

```swift
                ForEach(SidebarItem.allCases) { item in
```

to:

```swift
                ForEach(SidebarItem.allCases.filter { $0 != .settings }) { item in
```

Then wrap the sidebar column's content in a `VStack` with a pinned bottom row. Change:

```swift
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SidebarItem.allCases.filter { $0 != .settings }) { item in
                    ...
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(session.unlockedProfile?.displayName ?? "MyFin")
        } detail: {
```

to:

```swift
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(SidebarItem.allCases.filter { $0 != .settings }) { item in
                        ...
                    }
                }
                .listStyle(.sidebar)

                Divider()

                Button {
                    selection = .settings
                } label: {
                    HStack {
                        Image(systemName: session.unlockedProfile?.iconName ?? Profile.defaultIconName)
                            .foregroundStyle(ProfileIconPalette.color(named: session.unlockedProfile?.iconColor ?? Profile.defaultIconColor))
                        Text(session.unlockedProfile?.displayName ?? "")
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(selection == .settings ? Color.accentColor.opacity(0.15) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .navigationTitle(session.unlockedProfile?.displayName ?? "MyFin")
        } detail: {
```

(Keep the `...` above as the exact `DisclosureGroup`/`else` body from Task 4 — only the surrounding structure changes here. The `detail:` switch below, including its unchanged `.settings: SettingsView(session: session)` branch, stays exactly as it already is.)

- [x] **Step 2: Build**

Run: `swift build`
Expected: build succeeds with no errors.

- [x] **Step 3: Run the full test suite**

Run: `swift test`
Expected: all 97 tests still pass.

- [ ] **Step 4: Manual UI walkthrough**

Hand to human partner. Run: `swift run`
Ask them to: confirm the word "Настройки" no longer appears as a row inside the scrollable sidebar list; confirm a row showing the profile's icon and name appears pinned below the list, separated by a divider; click it and confirm the Settings page opens (same page as before, just a different sidebar entry point); confirm the row is visually highlighted while Settings is open; change the profile's icon/color/name inside Settings, save, and confirm the bottom sidebar row updates to reflect the new icon/color/name.
Expected: Settings is reachable only from the bottom profile row now, and that row always reflects the current profile's icon and name. Confirm with the user.

- [x] **Step 5: Commit**

Skipped — this project does not use git (see Global Constraints).

---

## Self-Review Notes

- **Spec coverage:** Localization section → Task 1. "Shared accounts state" section → Tasks 2 (new `AccountsListModel` + tests) and 3 (wiring it into `AccountsListView`/`MainShellView`). "Sidebar layout" section → Task 4 (`DisclosureGroup` with per-account rows) and Task 5 (Settings moved to a pinned bottom row styled as profile icon + name). "Out of scope" items from the spec (no per-account detail page, no persisted expand/collapse state, no English changes, no balance conversion) are respected throughout and called out in Global Constraints.
- **No placeholders:** every step has complete code (no `TBD`/"add appropriate handling"/"similar to Task N" shortcuts); the one deliberate carry-over is Task 5 Step 1's `...` markers, which explicitly say to keep Task 4's already-fully-specified `DisclosureGroup`/`else` body unchanged — not a gap, a "don't touch this part again" pointer.
- **Type/name consistency checked:** `AccountsListModel.activeAccounts`/`reload()`/`archive(_:)`/`restore(_:)` (defined Task 2) are called with those exact names in Tasks 3–4; `AccountsListView`'s `model:` parameter (defined Task 3) matches the `AccountsListView(session: session, model: accountsModel)` call site added in the same task; `isAccountsExpanded` (defined Task 4) is not renamed in Task 5.
- **Corrected during writing:** the approved spec's Section 2 mentions `model.showArchived ? model.accounts : model.activeAccounts`, but per the same section's own text, `showArchived` is meant to stay a plain `@State` on `AccountsListView`, not a property of `AccountsListModel` (which has no such property, by design — it always loads everything and lets consumers filter). Task 3 above implements the correct form, `showArchived ? model.accounts : model.activeAccounts`, using the view's local `@State`.
