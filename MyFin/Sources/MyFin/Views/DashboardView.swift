import SwiftUI

struct DashboardView: View {
    @ObservedObject var session: AppSession
    @ObservedObject var model: AccountsListModel
    @EnvironmentObject var preferences: AppPreferences

    @State private var total: Decimal = 0

    private var dashboardService: DashboardService? {
        guard let connection = session.connection else { return nil }
        let institutions = InstitutionService(connection: connection)
        let accounts = AccountService(connection: connection, institutionService: institutions)
        return DashboardService(connection: connection, accountService: accounts, exchangeRateProvider: HardcodedExchangeRateProvider())
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(preferences.string(.sidebarDashboard)).font(.largeTitle.bold())
            Text(preferences.string(.totalBalanceLabel)).foregroundStyle(.secondary)
            if session.showOriginalCurrencies {
                VStack(spacing: 6) {
                    ForEach(model.groupedByCurrency()) { group in
                        Text("\(NumberDisplayFormatter.format(group.total, preferences: session.numberFormatPreferences)) \(group.displayCurrency.rawValue)")
                            .font(.system(size: 28, weight: .bold))
                    }
                }
            } else {
                Text("\(NumberDisplayFormatter.format(total, preferences: session.numberFormatPreferences)) \(session.baseCurrency.rawValue)").font(.system(size: 40, weight: .bold))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: reload)
    }

    private func reload() {
        guard let service = dashboardService else { return }
        total = service.totalBalance(displayCurrency: session.baseCurrency)
    }
}
