import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard, accounts, cashflow, assets, analytics, settings

    var id: String { rawValue }

    var labelKey: L10nKey {
        switch self {
        case .dashboard: return .sidebarDashboard
        case .accounts: return .sidebarAccounts
        case .cashflow: return .sidebarCashflow
        case .assets: return .sidebarAssets
        case .analytics: return .sidebarAnalytics
        case .settings: return .sidebarSettings
        }
    }

    var symbolName: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .accounts: return "creditcard"
        case .cashflow: return "arrow.up.arrow.down"
        case .assets: return "chart.pie"
        case .analytics: return "chart.bar.xaxis"
        case .settings: return "gearshape"
        }
    }
}

struct MainShellView: View {
    @ObservedObject var session: AppSession
    @EnvironmentObject var preferences: AppPreferences
    @StateObject private var accountsModel: AccountsListModel
    @State private var selection: SidebarItem = .dashboard
    @SceneStorage("sidebar.accountsExpanded") private var isAccountsExpanded = true
    @State private var showingCreateAccount = false
    @State private var selectedAccount: Account?
    @State private var editingAccount: Account?
    @State private var focusBalanceOnEdit = false
    @SceneStorage("cashflow.month") private var cashflowMonth = FlowDate.month(Date())
    @Environment(\.scenePhase) private var scenePhase
    private let cashflowTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    init(session: AppSession) {
        self.session = session
        _accountsModel = StateObject(wrappedValue: AccountsListModel(session: session))
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 3) {
                        navigationButton(.dashboard)
                            .keyboardShortcut("1", modifiers: .command)
                        accountsNavigation
                            .padding(.top, 14)
                            .padding(.bottom, 12)
                        navigationButton(.cashflow)
                            .keyboardShortcut("3", modifiers: .command)
                        navigationButton(.assets)
                            .keyboardShortcut("4", modifiers: .command)
                        navigationButton(.analytics)
                            .keyboardShortcut("5", modifiers: .command)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                }
                profileFooter
            }
            .background(.regularMaterial)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignTokens.Colors.canvas)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        HStack(spacing: 10) {
                            Text("MyFin").font(.system(size: 14, weight: .semibold))
                            Text("/").foregroundStyle(.tertiary)
                            Text(preferences.string(selection.labelKey))
                                .font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                    }
                    .flatToolbarBackground()
                    if #available(macOS 26.0, *) {
                        ToolbarSpacer(.flexible, placement: .primaryAction)
                    } else {
                        ToolbarItem(placement: .automatic) { Spacer() }
                    }
                    if selection != .settings {
                        if selection == .dashboard {
                            ToolbarItem(placement: .primaryAction) { monthPickerPlaceholder }
                        }
                        ToolbarItem(placement: .primaryAction) { currencyPicker }
                        ToolbarItem(placement: .primaryAction) {
                            Button { showingCreateAccount = true } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                    Text(preferences.string(.newButtonLabel))
                                }
                                .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(DesignTokens.Colors.accent)
                            .keyboardShortcut("n", modifiers: .command)
                        }
                    }
                }
        }
        .inspector(isPresented: Binding(
            get: { selection == .accounts && selectedAccount != nil },
            set: { if !$0 { selectedAccount = nil } }
        )) {
            if let account = selectedAccount {
                BalanceHistoryPanelView(
                    session: session, account: account,
                    institution: accountsModel.institutionNames[account.institutionId ?? ""],
                    onClose: { selectedAccount = nil },
                    onEdit: { edit(account, focusBalance: false) },
                    onReconcile: { edit(account, focusBalance: true) }
                )
                .inspectorColumnWidth(min: 330, ideal: 350, max: 440)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbarBackground(.visible, for: .windowToolbar)
        .tint(DesignTokens.Colors.accent)
        .onAppear { session.materializeCashflow(); accountsModel.reload() }
        .onReceive(cashflowTimer) { _ in session.materializeCashflow() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { session.materializeCashflow() } }
        .onChange(of: session.ledgerRevision) { _, _ in accountsModel.reload() }
        .onChange(of: session.cashflowFocus) { _, focus in
            if let focus { cashflowMonth = focus.month; selection = .cashflow }
        }
        .onOpenURL { url in
            if let month = FlowDate.month(from: url) { cashflowMonth = month; selection = .cashflow }
        }
        .onChange(of: selection) { _, _ in selectedAccount = nil }
        .sheet(item: $editingAccount, onDismiss: {
            accountsModel.reload()
            if let id = selectedAccount?.id {
                selectedAccount = accountsModel.accounts.first { $0.id == id }
            }
        }) { account in
            AccountFormView(session: session, existingAccount: account, focusBalance: focusBalanceOnEdit)
        }
        .sheet(isPresented: $showingCreateAccount, onDismiss: { accountsModel.reload() }) {
            NewAccountWizardView(session: session)
        }
    }

    @ViewBuilder private var detail: some View {
        switch selection {
        case .dashboard:
            DashboardView(session: session, model: accountsModel, onManageAccounts: { selection = .accounts })
        case .accounts:
            AccountsListView(session: session, model: accountsModel, selectedAccount: $selectedAccount,
                             onEdit: { edit($0, focusBalance: $1) })
        case .cashflow:
            CashflowView(session: session, month: $cashflowMonth)
        case .assets:
            PlaceholderPageView(title: preferences.string(.sidebarAssets), message: preferences.string(.assetsPlaceholder))
        case .analytics:
            PlaceholderPageView(title: preferences.string(.sidebarAnalytics), message: preferences.string(.analyticsPlaceholder))
        case .settings:
            SettingsView(session: session)
        }
    }

    private func edit(_ account: Account, focusBalance: Bool) {
        focusBalanceOnEdit = focusBalance
        editingAccount = account
    }

    private func navigationButton(_ item: SidebarItem) -> some View {
        Button { selection = item } label: {
            HStack(spacing: 10) {
                Image(systemName: item.symbolName)
                    .font(.system(size: 15, weight: .regular))
                    .frame(width: 18)
                    .foregroundStyle(selection == item ? Color.white : Color.secondary)
                Text(preferences.string(item.labelKey)).font(.system(size: 13, weight: .medium))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(SidebarButtonStyle(selected: selection == item))
        .accessibilityAddTraits(selection == item ? .isSelected : [])
    }

    private var accountsNavigation: some View {
        VStack(spacing: 4) {
            // Separate controls: selecting Accounts never changes the disclosure state.
            HStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { isAccountsExpanded.toggle() }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(isAccountsExpanded ? 90 : 0))
                        .frame(width: 30, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(preferences.string(isAccountsExpanded ? .collapseAccounts : .expandAccounts))
                .help(preferences.string(isAccountsExpanded ? .collapseAccounts : .expandAccounts))

                Button { selection = .accounts } label: {
                    HStack {
                        Text(preferences.string(.sidebarAccounts).uppercased())
                            .font(.system(size: 11, weight: .semibold)).tracking(0.6)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut("2", modifiers: .command)
                .accessibilityAddTraits(selection == .accounts ? .isSelected : [])

                Button { showingCreateAccount = true } label: {
                    Image(systemName: "plus").font(.system(size: 11, weight: .medium))
                        .frame(width: 26, height: 32).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(preferences.string(.createAccountButton))
                .accessibilityLabel(preferences.string(.createAccountButton))
            }
            .foregroundStyle(selection == .accounts ? Color.white : Color.secondary)
            .background(selection == .accounts ? DesignTokens.Colors.accent : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6))

            if isAccountsExpanded {
                VStack(spacing: 2) {
                    ForEach(accountsModel.grouped(by: session.sidebarGroupingMode, baseCurrency: session.baseCurrency)) { group in
                        Button { selection = .accounts } label: {
                            HStack(spacing: 8) {
                                Circle().fill(DesignTokens.color(for: group.id)).frame(width: 8, height: 8)
                                Text(groupLabel(group)).font(.system(size: 12.5, weight: .medium))
                                    .lineLimit(1).help(groupLabel(group))
                                Spacer(minLength: 4)
                                HStack(alignment: .firstTextBaseline, spacing: 3) {
                                    Text(NumberDisplayFormatter.format(group.total, preferences: session.numberFormatPreferences))
                                        .font(.system(size: 12, weight: .medium)).monospacedDigit()
                                    Text(group.displayCurrency.rawValue).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                                }
                                .fixedSize()
                            }
                            .padding(.horizontal, 10).frame(height: 30)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(SidebarButtonStyle(selected: false))
                    }
                }
                .padding(.leading, 16)
                .overlay(alignment: .leading) {
                    Rectangle().fill(DesignTokens.Colors.cardBorder).frame(width: 1).padding(.leading, 15)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func groupLabel(_ group: AccountGroup) -> String {
        if group.id == AccountsListModel.cashGroupID { return preferences.string(.cashFieldLabel) }
        if session.sidebarGroupingMode == .type, let type = AccountType(rawValue: group.id) {
            return preferences.string(type.labelKey)
        }
        return group.label
    }

    private var profileFooter: some View {
        VStack(spacing: 0) {
            Divider()
            Button { selection = .settings } label: {
                HStack(spacing: 10) {
                    Image(systemName: session.unlockedProfile?.iconName ?? Profile.defaultIconName)
                        .font(.system(size: 13)).foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(ProfileIconPalette.color(named: session.unlockedProfile?.iconColor ?? Profile.defaultIconColor), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.unlockedProfile?.displayName ?? "").font(.system(size: 13, weight: .medium))
                        Text(preferences.string(.localProfile)).font(.system(size: 10.5))
                            .foregroundStyle(selection == .settings ? Color.white.opacity(0.8) : Color.secondary)
                    }
                    Spacer()
                    Image(systemName: "slider.horizontal.3").foregroundStyle(selection == .settings ? Color.white : Color.secondary)
                }
                .padding(8).contentShape(Rectangle())
            }
            .buttonStyle(SidebarButtonStyle(selected: selection == .settings))
            .padding(10)
        }
    }

    private var monthPickerPlaceholder: some View {
        Button {} label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                Text(Date().formatted(.dateTime.month(.abbreviated).year().locale(Locale(identifier: preferences.language == .ru ? "ru_RU" : "en_US"))))
            }
            .font(.system(size: 12))
        }
        .disabled(true)
        .help(preferences.string(.cashflowComingSoonMessage))
    }

    private var currencyPicker: some View {
        Menu {
            ForEach(Currency.allCases, id: \.self) { currency in
                Button {
                    session.updateBaseCurrency(currency)
                    session.updateShowOriginalCurrencies(false)
                } label: {
                    if currency == session.baseCurrency && !session.showOriginalCurrencies {
                        Label(currency.rawValue, systemImage: "checkmark")
                    } else { Text(currency.rawValue) }
                }
            }
            Divider()
            Button { session.updateShowOriginalCurrencies(true) } label: {
                if session.showOriginalCurrencies {
                    Label(preferences.string(.originalCurrenciesLabel), systemImage: "checkmark")
                } else { Text(preferences.string(.originalCurrenciesLabel)) }
            }
        } label: {
            Text(session.showOriginalCurrencies ? preferences.string(.originalCurrenciesLabel) : session.baseCurrency.rawValue)
                .font(.system(size: 12, weight: .medium))
        }
    }
}

private struct SidebarButtonStyle: ButtonStyle {
    let selected: Bool
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background(selected ? DesignTokens.Colors.accent : Color.primary.opacity(hovering || configuration.isPressed ? 0.05 : 0),
                        in: RoundedRectangle(cornerRadius: 6))
            .onHover { hovering = $0 }
    }
}
