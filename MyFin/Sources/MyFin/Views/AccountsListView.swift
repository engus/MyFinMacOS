import SwiftUI

struct AccountsListView: View {
    @ObservedObject var session: AppSession
    @ObservedObject var model: AccountsListModel
    @EnvironmentObject var preferences: AppPreferences

    @State private var showArchived = false
    @State private var showingCreate = false
    @State private var editingAccount: Account?
    @State private var selectedAccount: Account?

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
                List {
                    if !model.activeAccounts.isEmpty {
                        Section(preferences.string(.activeAccountsSectionTitle)) {
                            ForEach(model.activeAccounts) { account in
                                AccountRowView(
                                    account: account,
                                    subtitle: accountSubtitle(for: account),
                                    numberFormatPreferences: session.numberFormatPreferences,
                                    onSelect: { selectedAccount = account },
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
                                        subtitle: accountSubtitle(for: account),
                                        numberFormatPreferences: session.numberFormatPreferences,
                                        onSelect: { selectedAccount = account },
                                        onEdit: { editingAccount = account },
                                        onToggleArchive: { toggleArchive(account) }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { model.reload() }
        .sheet(isPresented: $showingCreate, onDismiss: { model.reload() }) {
            AccountFormView(session: session, existingAccount: nil)
        }
        .sheet(item: $editingAccount, onDismiss: {
            model.reload()
            if let id = selectedAccount?.id {
                selectedAccount = model.accounts.first { $0.id == id }
            }
        }) { account in
            AccountFormView(session: session, existingAccount: account)
        }
        .inspector(isPresented: Binding(
            get: { selectedAccount != nil },
            set: { if !$0 { selectedAccount = nil } }
        )) {
            if let account = selectedAccount {
                BalanceHistoryPanelView(session: session, account: account, onClose: { selectedAccount = nil })
                    .id("\(account.id)-\(account.updatedAt.timeIntervalSince1970)")
            }
        }
    }

    private func toggleArchive(_ account: Account) {
        account.archived ? model.restore(account) : model.archive(account)
    }

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
}

private struct AccountRowView: View {
    let account: Account
    let subtitle: String
    let numberFormatPreferences: NumberFormatPreferences
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onToggleArchive: () -> Void

    @EnvironmentObject var preferences: AppPreferences

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(account.name).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }
            Spacer()
            Text(NumberDisplayFormatter.format(account.openingBalance, preferences: numberFormatPreferences))
            Button(preferences.string(.editButton), action: onEdit)
            Button(account.archived ? preferences.string(.restoreButton) : preferences.string(.archiveButton), action: onToggleArchive)
        }
    }
}
