# Sidebar accounts list, relabeling, and settings relocation

## Context

The MyFin sidebar (`MainShellView`) currently lists five flat items: Дашборд, Аккаунты, Cashflow, Активы, Настройки. Two Russian labels don't fit the app's terminology, the sidebar gives no at-a-glance view of account balances, and the Settings entry takes a full-weight slot at the top of the list instead of reading as "you, the current profile."

## Goals

1. Rename two Russian sidebar labels.
2. Show active accounts (name + balance) directly under "Счета" in the sidebar, collapsible.
3. Move Settings to the bottom of the sidebar, presented as the profile's icon + display name instead of the word "Настройки".

Only the Russian localization changes; English strings are untouched.

## 1. Localization

In `Sources/MyFin/Localization.swift`, `ru` dictionary only:

| Key | Old | New |
|---|---|---|
| `.sidebarAccounts` | "Аккаунты" | "Счета" |
| `.sidebarCashflow` | "Cashflow" | "Доходы и расходы" |
| `.cashflowPlaceholder` | "Cashflow — здесь скоро появится содержимое" | "Доходы и расходы — здесь скоро появится содержимое" |

`en` dictionary is unchanged. `LocalizationTests` (`test_ru_and_en_haveTheSameKeyCount`, `test_everyKey_hasNonEmptyRussianAndEnglishTranslation`) continue to pass since no keys are added or removed.

## 2. Shared accounts state

**Problem:** `AccountsListView` currently owns its account list in a private `@State` array, loaded via its own `AccountService` computed property, refreshed only in response to its own UI actions (create/edit/archive sheets). The sidebar needs the same underlying data (active accounts + balances) and must reflect changes made on the Accounts page immediately — a second, independent load in the sidebar would drift out of sync until the user happened to revisit it.

**Design:** Introduce `AccountsListModel`, a `@MainActor` `ObservableObject` in `Sources/MyFin/Services/AccountsListModel.swift`:

```swift
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

- `MainShellView` owns it: `@StateObject private var accountsModel: AccountsListModel`, initialized in `init(session:)` as `_accountsModel = StateObject(wrappedValue: AccountsListModel(session: session))`.
- Passed down to `AccountsListView(session:model:)`, which is changed to take `@ObservedObject var model: AccountsListModel` instead of building its own `accounts` state/service. Its `showArchived` toggle stays local UI state; the displayed list becomes `model.showArchived ? model.accounts : model.activeAccounts` computed inline in the view (no change to `AccountsListModel` needed for this — `showArchived` remains a plain `@State` in `AccountsListView` as it is today, only the underlying data source changes).
- Create/edit sheet dismissal and the archive/restore buttons call `model.reload()` / `model.archive(_:)` / `model.restore(_:)` instead of the view's own private methods.
- The sidebar (in `MainShellView`) reads `accountsModel.activeAccounts` directly for its account rows.
- `accountsModel.reload()` is called once in `MainShellView.onAppear`.

This keeps `AccountService` itself unchanged — only the state-holding layer moves up one level to `MainShellView` so both consumers share it.

## 3. Sidebar layout

`MainShellView`'s sidebar content changes from a flat `List(selection:)` over all five `SidebarItem` cases to:

```
List(selection: $selection) {
    Text(dashboard label).tag(.dashboard)

    DisclosureGroup(isExpanded: $isAccountsExpanded) {
        ForEach(accountsModel.activeAccounts) { account in
            HStack {
                Text(account.name)
                Spacer()
                Text("\(account.openingBalance) \(account.currency.rawValue)")
            }
            .contentShape(Rectangle())
            .onTapGesture { selection = .accounts }
        }
    } label: {
        Text(accounts label).tag(.accounts)
    }

    Text(cashflow label).tag(.cashflow)
    Text(assets label).tag(.assets)
}
.listStyle(.sidebar)
```

followed immediately below the `List` (both inside the `NavigationSplitView`'s sidebar column, replacing the bare `List` that's there today) by:

```
Divider()

Button {
    selection = .settings
} label: {
    HStack {
        Image(systemName: profile.iconName)
            .foregroundStyle(ProfileIconPalette.color(named: profile.iconColor))
        Text(profile.displayName)
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
```

using `session.unlockedProfile` for `profile` (falling back to `Profile.defaultIconName` / `Profile.defaultIconColor` and empty name if somehow nil, matching the existing `session.unlockedProfile?.displayName ?? "MyFin"` fallback style already used for the nav title).

- `SidebarItem.settings` remains a valid enum case (the `detail:` switch in `MainShellView` is unchanged — `.settings` still resolves to `SettingsView`), it's just no longer iterated in the top `List`'s `ForEach`.
- The account balance row uses `account.openingBalance` in the account's own currency — the same value `AccountsListView` already displays; there is no separate ledger/transaction system yet, so this is the account's current balance.
- Tapping an account row sets `selection = .accounts`, identical to tapping the "Счета" label itself (no per-account detail view exists).
- The `DisclosureGroup` is backed by `@State private var isAccountsExpanded = true` in `MainShellView`, so it starts expanded and the user can collapse/expand it by clicking the disclosure arrow, but that state is not persisted across launches (no stored expand/collapse state) — YAGNI, matches how nothing else in the sidebar persists UI state today.

## Testing

- `LocalizationTests` already assert Russian/English key parity and non-empty translations — no changes needed, they'll pass against the new strings automatically.
- Add a test for `AccountsListModel` (new `Tests/MyFinTests/AccountsListModelTests.swift`) covering: `reload()` populates `accounts` from the service, `activeAccounts` excludes archived accounts, `archive(_:)`/`restore(_:)` mutate and reload.
- No new tests are planned for the sidebar's SwiftUI layout itself (view-tree assertions aren't the pattern used elsewhere in this codebase — `MainShellView`, `DashboardView`, etc. have no view tests today); manual verification via `swift build` + running the app.

## Out of scope

- No per-account detail page.
- No persistence of sidebar expand/collapse state.
- No changes to English localization.
- No changes to how balances are computed/converted (still raw `openingBalance` in the account's own currency, same as the Accounts page).
