import SwiftUI

struct DashboardView: View {
    @ObservedObject var session: AppSession
    @ObservedObject var model: AccountsListModel
    @EnvironmentObject var preferences: AppPreferences
    var onManageAccounts: () -> Void = {}

    private var total: Decimal { AccountListQuery.total(model.activeAccounts, in: session.baseCurrency) }
    private var otherCurrency: Currency { session.baseCurrency == .usd ? .kzt : .usd }
    private var cashAndBank: [Account] { model.activeAccounts.filter { $0.type != .deposit } }
    private var deposits: [Account] { model.activeAccounts.filter { $0.type == .deposit } }
    private var distribution: [Account] {
        AccountListQuery().matching(model.accounts, institutionNames: model.institutionNames, baseCurrency: session.baseCurrency)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    heroBalanceCard
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16),
                                             count: geometry.size.width > 760 ? 3 : 1), spacing: 16) {
                        metricCard(title: .cashAndBank, accounts: cashAndBank, symbol: "creditcard", color: .orange)
                        metricCard(title: .depositsLabel, accounts: deposits, symbol: "chart.line.uptrend.xyaxis", color: .blue)
                        netCashflowCard
                    }
                    if geometry.size.width > 760 {
                        HStack(alignment: .top, spacing: 20) {
                            recentMovementsCard.frame(maxWidth: .infinity)
                            capitalDistributionCard.frame(width: (min(geometry.size.width, 1120) - 84) * 0.43)
                        }
                    } else {
                        recentMovementsCard
                        capitalDistributionCard
                    }
                }
                .padding(geometry.size.width > 650 ? 32 : 20)
                .frame(maxWidth: 1120)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { model.reload() }
    }

    private var heroBalanceCard: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 24) {
                heroBalance
                Spacer(minLength: 0)
                heroConversion
            }
            VStack(alignment: .leading, spacing: 18) {
                heroBalance
                heroConversion
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var heroBalance: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(preferences.string(.sidebarDashboard)).font(.system(size: 24, weight: .bold)).tracking(-0.5)
                    Text("·").foregroundStyle(.tertiary)
                    Text(preferences.string(.totalBalanceLabel)).font(.system(size: 13)).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(preferences.string(.sidebarDashboard)).font(.system(size: 24, weight: .bold))
                    Text(preferences.string(.totalBalanceLabel)).font(.system(size: 13)).foregroundStyle(.secondary)
                }
            }
            if session.showOriginalCurrencies {
                let groups = model.groupedByCurrency()
                if groups.isEmpty {
                    balanceLine(0, currency: session.baseCurrency)
                } else {
                    ForEach(groups) { group in balanceLine(group.total, currency: group.displayCurrency) }
                }
            } else {
                balanceLine(total, currency: session.baseCurrency)
            }
        }
    }

    private func balanceLine(_ value: Decimal, currency: Currency) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(NumberDisplayFormatter.format(value, preferences: session.numberFormatPreferences))
                .font(.system(size: 38, weight: .bold)).tracking(-1.2)
            Text(currency.rawValue).font(.system(size: 24, weight: .semibold)).foregroundStyle(.secondary)
        }
        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
    }

    private var heroConversion: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if !session.showOriginalCurrencies {
                Text("≈ " + amount(AccountListQuery.total(model.activeAccounts, in: otherCurrency), currency: otherCurrency))
                    .font(.system(size: 13)).foregroundStyle(.secondary).monospacedDigit()
            }
            HStack(spacing: 5) {
                Image(systemName: "externaldrive.badge.checkmark").font(.system(size: 11))
                Text(preferences.string(.recordedBalances)).font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(DesignTokens.Colors.subtleBackground, in: Capsule())
        }
        .fixedSize()
    }

    private func metricCard(title: L10nKey, accounts: [Account], symbol: String, color: Color) -> some View {
        let value = AccountListQuery.total(accounts, in: session.baseCurrency)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(preferences.string(title).uppercased())
                    .font(.system(size: 11, weight: .medium)).tracking(0.6).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                metricIcon(symbol, color: color)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(amount(value, currency: session.baseCurrency))
                    .font(.system(size: 20, weight: .bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
                Text("\(preferences.string(.accountCountLabel)): \(accounts.count)")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Divider()
            HStack {
                Text(preferences.string(.portionOfTotalLabel)).foregroundStyle(.secondary)
                Spacer()
                Text(percentage(value)).fontWeight(.semibold).monospacedDigit()
            }
            .font(.system(size: 11))
        }
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .dashboardCardStyle()
    }

    private func metricIcon(_ symbol: String, color: Color) -> some View {
        Image(systemName: symbol).font(.system(size: 14, weight: .medium))
            .foregroundStyle(color).frame(width: 28, height: 28)
            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
    }

    private var netCashflowCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(preferences.string(.netCashflowLabel).uppercased())
                    .font(.system(size: 11, weight: .medium)).tracking(0.6).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                metricIcon("arrow.up", color: .green)
            }
            Text("—").font(.system(size: 20, weight: .bold)).foregroundStyle(.secondary)
            Text(preferences.string(.cashflowComingSoonMessage))
                .font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Divider()
            Text(preferences.string(.noMovementsTrackedMessage)).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .dashboardCardStyle()
    }

    private var recentMovementsCard: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(preferences.string(.recentMovementsLabel)).font(.system(size: 13, weight: .semibold))
                    Text(preferences.string(.cashflowComingSoonMessage)).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
            .background(DesignTokens.Colors.subtleBackground.opacity(0.45))
            Divider()
            VStack(spacing: 10) {
                Image(systemName: "tray").font(.system(size: 26)).foregroundStyle(.tertiary)
                Text(preferences.string(.noMovementsTrackedMessage)).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity).frame(height: 180)
        }
        .cardSurface()
    }

    private var capitalDistributionCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(preferences.string(.capitalDistributionLabel)).font(.system(size: 14, weight: .semibold))
                Text(preferences.string(.distributionDescription))
                    .font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button(action: onManageAccounts) {
                    HStack(spacing: 4) { Text(preferences.string(.manageAccounts)); Image(systemName: "arrow.right") }
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(DesignTokens.Colors.accent)
                }
                .buttonStyle(.plain).padding(.top, 3)
            }
            if total > 0 {
                GeometryReader { proxy in
                    HStack(spacing: 0) {
                        ForEach(distribution) { account in
                            let balance = AccountListQuery.convertedBalance(account, to: session.baseCurrency)
                            distributionColor(for: account)
                                .frame(width: proxy.size.width * CGFloat(truncating: NSDecimalNumber(decimal: balance / total)))
                                .help("\(account.name): \(percentage(balance))")
                        }
                    }
                }
                .frame(height: 10).clipShape(Capsule())
            }
            if distribution.isEmpty {
                Text(preferences.string(.noAccountsYet)).font(.system(size: 12)).foregroundStyle(.secondary).padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(distribution) { account in
                        HStack(spacing: 9) {
                            Circle().fill(distributionColor(for: account)).frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(account.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                Text(amount(account.openingBalance, currency: account.currency))
                                    .font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
                            }
                            Spacer(minLength: 4)
                            Text(percentage(AccountListQuery.convertedBalance(account, to: session.baseCurrency)))
                                .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                        }
                        .padding(.vertical, 12)
                        if account.id != distribution.last?.id { Divider() }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCardStyle()
    }

    private func amount(_ value: Decimal, currency: Currency) -> String {
        "\(NumberDisplayFormatter.format(value, preferences: session.numberFormatPreferences)) \(currency.rawValue)"
    }

    private func distributionColor(for account: Account) -> Color {
        let palette: [Color] = [.blue, .green, .orange, .indigo, .teal, .pink]
        return palette[(distribution.firstIndex { $0.id == account.id } ?? 0) % palette.count]
    }

    private func percentage(_ value: Decimal) -> String {
        guard total > 0 else { return "0%" }
        let percent = value / total * 100
        if percent > 0 && percent < 0.1 { return session.numberFormatPreferences.useCommaDecimalSeparator ? "<0,1%" : "<0.1%" }
        var format = session.numberFormatPreferences
        format.maxDecimalPlaces = 1
        format.useCompactNotation = false
        return NumberDisplayFormatter.format(percent, preferences: format) + "%"
    }
}
