import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard
    case accounts
    case cashflow
    case assets
    case settings

    var id: String { rawValue }

    var labelKey: L10nKey {
        switch self {
        case .dashboard: return .sidebarDashboard
        case .accounts: return .sidebarAccounts
        case .cashflow: return .sidebarCashflow
        case .assets: return .sidebarAssets
        case .settings: return .sidebarSettings
        }
    }
}

struct MainShellView: View {
    @ObservedObject var session: AppSession
    @EnvironmentObject var preferences: AppPreferences
    @StateObject private var accountsModel: AccountsListModel
    @State private var selection: SidebarItem? = .dashboard
    @State private var isAccountsExpanded = true

    init(session: AppSession) {
        self.session = session
        _accountsModel = StateObject(wrappedValue: AccountsListModel(session: session))
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(SidebarItem.allCases.filter { $0 != .settings }) { item in
                        if item == .accounts {
                            DisclosureGroup(isExpanded: $isAccountsExpanded) {
                                ForEach(accountsModel.grouped(by: session.sidebarGroupingMode, baseCurrency: session.baseCurrency)) { group in
                                    HStack {
                                        if session.sidebarGroupingMode == .institution {
                                            if group.id == AccountsListModel.cashGroupID {
                                                Image(systemName: AccountsListModel.cashIconName)
                                                    .foregroundStyle(ProfileIconPalette.color(named: AccountsListModel.cashIconColor))
                                            } else {
                                                Image(systemName: SystemInstitutionCatalog.institutionIconName)
                                                    .foregroundStyle(ProfileIconPalette.color(named: SystemInstitutionCatalog.color(forID: group.id) ?? "blue"))
                                            }
                                        }
                                        Text(group.id == AccountsListModel.cashGroupID ? preferences.string(.cashFieldLabel) : group.label)
                                        Spacer()
                                        Text("\(NumberDisplayFormatter.format(group.total, preferences: session.numberFormatPreferences)) \(group.displayCurrency.rawValue)")
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
            switch selection {
            case .dashboard:
                DashboardView(session: session, model: accountsModel)
            case .accounts:
                AccountsListView(session: session, model: accountsModel)
            case .cashflow:
                PlaceholderPageView(title: preferences.string(.sidebarCashflow), message: preferences.string(.cashflowPlaceholder))
            case .assets:
                PlaceholderPageView(title: preferences.string(.sidebarAssets), message: preferences.string(.assetsPlaceholder))
            case .settings:
                SettingsView(session: session)
            case .none:
                PlaceholderPageView(title: "MyFin", message: preferences.string(.selectSectionMessage))
            }
        }
        .onAppear { accountsModel.reload() }
    }
}
