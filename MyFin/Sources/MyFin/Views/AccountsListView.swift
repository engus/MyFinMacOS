import SwiftUI

struct AccountsListView: View {
    @ObservedObject var session: AppSession
    @ObservedObject var model: AccountsListModel
    @EnvironmentObject var preferences: AppPreferences

    @State private var query = AccountListQuery()
    @State private var grouping: SidebarGroupingMode = .country
    @State private var collapsedGroups: Set<String> = []
    @Binding var selectedAccount: Account?
    let onEdit: (Account, Bool) -> Void

    private var visibleAccounts: [Account] {
        query.matching(model.accounts, institutionNames: model.institutionNames, baseCurrency: session.baseCurrency)
    }

    private var sections: [AccountListSection] {
        query.sections(model.accounts, institutionNames: model.institutionNames, grouping: grouping,
                       baseCurrency: session.baseCurrency, language: preferences.language)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(preferences.string(.sidebarAccounts))
                            .font(.system(size: 28, weight: .bold)).tracking(-0.6)
                        Text(preferences.string(.accountsDescription))
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 12)

                    ViewThatFits(in: .horizontal) {
                        HStack { statusTabs; Spacer(minLength: 16); totalValue }
                        VStack(alignment: .leading, spacing: 12) { statusTabs; totalValue }
                    }
                    Divider()
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) { filterMenus; Spacer(minLength: 12); searchField.frame(width: 240) }
                        VStack(alignment: .leading, spacing: 12) { filterMenus; searchField }
                    }
                    tableHeader(wide: geometry.size.width > 850)

                    if visibleAccounts.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 24) {
                            ForEach(sections) { section in
                                accountSection(section, wide: geometry.size.width > 850)
                            }
                        }
                    }
                }
                .padding(geometry.size.width > 650 ? 32 : 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear { model.reload() }
        .onChange(of: grouping) { _, _ in collapsedGroups.removeAll() }
        .onChange(of: query.archived) { _, _ in selectedAccount = nil }
    }

    private var statusTabs: some View {
        HStack(spacing: 2) {
            statusTab(archived: false, count: model.activeAccounts.count)
            statusTab(archived: true, count: model.accounts.filter(\.archived).count)
        }
        .padding(3)
        .background(DesignTokens.Colors.subtleBackground, in: RoundedRectangle(cornerRadius: 8))
        .fixedSize()
    }

    private func statusTab(archived: Bool, count: Int) -> some View {
        Button {
            query.archived = archived
            collapsedGroups.removeAll()
        } label: {
            HStack(spacing: 8) {
                Text(preferences.string(archived ? .archivedTab : .activeTab))
                Text("\(count)").font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.primary.opacity(0.045), in: Capsule())
            }
            .font(.system(size: 13, weight: query.archived == archived ? .semibold : .medium))
            .foregroundStyle(query.archived == archived ? Color.primary : Color.secondary)
            .padding(.horizontal, 12).frame(height: 28)
            .background(query.archived == archived ? DesignTokens.Colors.cardBackground : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(query.archived == archived ? .isSelected : [])
    }

    private var totalValue: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(preferences.string(.totalValueLabel) + ":").foregroundStyle(.secondary)
            Text(amount(AccountListQuery.total(visibleAccounts, in: session.baseCurrency), currency: session.baseCurrency))
                .fontWeight(.semibold).monospacedDigit()
        }
        .font(.system(size: 13))
        .fixedSize()
    }

    private var filterMenus: some View {
        HStack(spacing: 10) {
            Picker(preferences.string(.typeFieldLabel), selection: $query.type) {
                Text(preferences.string(.allTypes)).tag(nil as AccountType?)
                ForEach(AccountType.allCases, id: \.self) { type in
                    Text(preferences.string(type.labelKey)).tag(Optional(type))
                }
            }
            .labelsHidden().frame(width: 150)
            .accessibilityLabel(preferences.string(.typeFieldLabel))

            Picker(preferences.string(.groupByLabel), selection: $grouping) {
                ForEach(SidebarGroupingMode.allCases, id: \.self) { mode in
                    Text(preferences.string(mode.labelKey)).tag(mode)
                }
            }
            .frame(width: 200)
        }
        .controlSize(.large)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
            TextField(preferences.string(.filterAccounts), text: $query.search)
                .textFieldStyle(.plain)
                .accessibilityLabel(preferences.string(.filterAccounts))
            if !query.search.isEmpty {
                Button { query.search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain).accessibilityLabel(preferences.string(.clearFilters))
            }
        }
        .font(.system(size: 13)).padding(10)
        .background(DesignTokens.Colors.subtleBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(DesignTokens.Colors.cardBorder) }
    }

    private func tableHeader(wide: Bool) -> some View {
        HStack(spacing: 16) {
            Button { query.sort = .name } label: {
                HStack(spacing: 6) {
                    Text(preferences.string(.accountInstitutionColumn))
                    Image(systemName: query.sort == .name ? "chevron.up" : "chevron.up.chevron.down").font(.system(size: 9))
                }
            }
            .buttonStyle(.plain).frame(maxWidth: .infinity, alignment: .leading)
            if wide {
                Text(preferences.string(.typeFieldLabel)).frame(width: 120, alignment: .leading)
                Text(preferences.string(.countryFieldLabel) + " / " + preferences.string(.currencyFieldLabel))
                    .frame(width: 130, alignment: .leading)
            }
            Menu {
                Button(preferences.string(.sortByName)) { query.sort = .name }
                Button(preferences.string(.sortBalanceDescending)) { query.sort = .balanceDescending }
                Button(preferences.string(.sortBalanceAscending)) { query.sort = .balanceAscending }
            } label: {
                HStack(spacing: 6) {
                    Text(preferences.string(.balanceColumn))
                    Image(systemName: query.sort == .balanceAscending ? "chevron.up" : "chevron.down")
                        .foregroundStyle(DesignTokens.Colors.accent)
                }
            }
            .menuStyle(.borderlessButton).fixedSize()
            .frame(width: wide ? 160 : 125, alignment: .trailing)
            .accessibilityLabel(preferences.string(.sortLabel))
            Text(preferences.string(.actionsColumn)).frame(width: 84, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14).padding(.vertical, 15)
        .background(DesignTokens.Colors.subtleBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(DesignTokens.Colors.cardBorder) }
    }

    private func accountSection(_ section: AccountListSection, wide: Bool) -> some View {
        VStack(spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    if !collapsedGroups.insert(section.id).inserted { collapsedGroups.remove(section.id) }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(collapsedGroups.contains(section.id) ? 0 : 90)).foregroundStyle(.secondary)
                    Text(section.label).fontWeight(.semibold)
                    Text("\(section.accounts.count)")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Color.primary.opacity(0.05), in: Capsule())
                    Spacer(minLength: 8)
                    Text(preferences.string(.subtotalLabel) + ":").foregroundStyle(.secondary)
                    Text(amount(section.total, currency: session.baseCurrency)).fontWeight(.semibold).monospacedDigit()
                }
                .font(.system(size: 12)).padding(.horizontal, 12).padding(.vertical, 9)
                .background(DesignTokens.Colors.subtleBackground.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(collapsedGroups.contains(section.id) ? preferences.string(.expandAccounts) : preferences.string(.collapseAccounts))

            if !collapsedGroups.contains(section.id) {
                ForEach(section.accounts) { account in
                    AccountTableRow(account: account, institution: model.institutionNames[account.institutionId ?? ""],
                                    session: session, wide: wide, selected: selectedAccount?.id == account.id,
                                    onSelect: { selectedAccount = account },
                                    onEdit: { edit(account, focusBalance: false) },
                                    onToggleArchive: {
                                        account.archived ? model.restore(account) : model.archive(account)
                                        if selectedAccount?.id == account.id { selectedAccount = nil }
                                    })
                    if account.id != section.accounts.last?.id { Divider().padding(.leading, 12) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: query.archived ? "archivebox" : "creditcard").font(.system(size: 30)).foregroundStyle(.tertiary)
            Text(preferences.string(query.search.isEmpty && query.type == nil ? (query.archived ? .noArchivedAccounts : .noAccountsYet) : .noMatchingAccounts))
                .font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
            if !query.search.isEmpty || query.type != nil {
                Button(preferences.string(.clearFilters)) { query.search = ""; query.type = nil }
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }

    private func amount(_ value: Decimal, currency: Currency) -> String {
        "\(NumberDisplayFormatter.format(value, preferences: session.numberFormatPreferences)) \(currency.rawValue)"
    }

    private func edit(_ account: Account, focusBalance: Bool) {
        onEdit(account, focusBalance)
    }

}

private struct AccountTableRow: View {
    let account: Account
    let institution: String?
    @ObservedObject var session: AppSession
    let wide: Bool
    let selected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onToggleArchive: () -> Void
    @EnvironmentObject var preferences: AppPreferences
    @State private var hovering = false

    private var color: Color { DesignTokens.color(for: account) }

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onSelect) {
                HStack(spacing: 16) {
                    HStack(spacing: 12) {
                        AccountEmblem(account: account, institution: institution)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(account.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                            Text(subtitle).font(.system(size: 11.5)).foregroundStyle(.secondary).lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if wide {
                        Text(preferences.string(account.type.labelKey)).font(.system(size: 11, weight: .medium))
                            .foregroundStyle(color).padding(.horizontal, 6).padding(.vertical, 3)
                            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                            .frame(width: 120, alignment: .leading)
                        Text("\(account.country.flag) \(account.country.rawValue) · \(account.currency.rawValue)")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                            .frame(width: 130, alignment: .leading)
                    }
                    VStack(alignment: .trailing, spacing: 5) {
                        Text(amount(account.openingBalance, currency: account.currency))
                            .font(.system(size: 14, weight: .semibold))
                        if account.currency != session.baseCurrency {
                            Text("≈ " + amount(AccountListQuery.convertedBalance(account, to: session.baseCurrency), currency: session.baseCurrency))
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
                    .frame(width: wide ? 160 : 125, alignment: .trailing)
                }
                .frame(maxWidth: .infinity, minHeight: 58)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(preferences.string(.balanceHistoryButton))
            HStack(spacing: 0) {
                action("clock.arrow.circlepath", label: .balanceHistoryButton, action: onSelect)
                action("pencil", label: .editButton, action: onEdit)
                action(account.archived ? "arrow.uturn.backward" : "archivebox", label: account.archived ? .restoreButton : .archiveButton, action: onToggleArchive)
            }
            .frame(width: 84)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(selected ? DesignTokens.Colors.accent.opacity(0.07) : Color.primary.opacity(hovering ? 0.025 : 0),
                    in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(selected ? DesignTokens.Colors.accent.opacity(0.4) : Color.clear)
        }
        .onHover { hovering = $0 }
    }

    private var subtitle: String {
        var parts = [String]()
        if let institution, account.type != .cash { parts.append(institution) }
        parts += [account.country.rawValue, account.currency.rawValue, preferences.string(account.type.labelKey)]
        return parts.joined(separator: " · ")
    }

    private func amount(_ value: Decimal, currency: Currency) -> String {
        "\(NumberDisplayFormatter.format(value, preferences: session.numberFormatPreferences)) \(currency.rawValue)"
    }

    private func action(_ symbol: String, label: L10nKey, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 13)).foregroundStyle(.secondary) }
            .buttonStyle(QuietButtonStyle()).help(preferences.string(label)).accessibilityLabel(preferences.string(label))
    }
}

struct AccountEmblem: View {
    let account: Account
    let institution: String?

    var body: some View {
        let color = DesignTokens.color(for: account)
        Group {
            if account.type == .cash {
                Image(systemName: "banknote").font(.system(size: 17, weight: .medium))
            } else if let institution {
                Text(String(institution.prefix(4))).font(.system(size: 11, weight: .bold))
                    .lineLimit(1).minimumScaleFactor(0.7)
            } else {
                Image(systemName: account.type.symbolName).font(.system(size: 17))
            }
        }
        .foregroundStyle(color).frame(width: 36, height: 36)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(color.opacity(0.2)) }
        .accessibilityHidden(true)
    }
}
