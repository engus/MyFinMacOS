import SwiftUI

struct BalanceHistoryPanelView: View {
    @ObservedObject var session: AppSession
    let account: Account
    let institution: String?
    let onClose: () -> Void
    let onEdit: () -> Void
    let onReconcile: () -> Void
    @EnvironmentObject var preferences: AppPreferences

    @State private var entries: [BalanceHistoryEntry] = []

    private var timeline: [BalanceHistoryTimeline.Row] {
        BalanceHistoryTimeline(entriesOldestFirst: entries).rows
    }

    private var convertedCurrency: Currency {
        session.baseCurrency
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    AccountVirtualCardView(accountName: account.name, institutionName: institution,
                        type: account.type, currency: account.currency,
                        balance: NumberDisplayFormatter.format(account.openingBalance, preferences: session.numberFormatPreferences),
                        appearance: account.appearance, country: account.country,
                        baseCurrencyEquivalent: account.currency == session.baseCurrency ? nil : "≈ \(NumberDisplayFormatter.format(AccountListQuery.convertedBalance(account, to: convertedCurrency), preferences: session.numberFormatPreferences)) \(convertedCurrency.rawValue)")
                    if !account.appearance.tags.isEmpty {
                        Text(account.appearance.tags.map { "#" + $0 }.joined(separator: "  ")).font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(alignment: .top) {
                        latestChange
                        Spacer(minLength: 4)
                        updatedTimestamp
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text(preferences.string(.balanceHistoryButton))
                            .font(.system(size: 13, weight: .semibold))
                        historyCard
                        if entries.contains(where: { $0.currency == nil }) {
                            Text(preferences.string(.legacyHistoryCurrencyNote))
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            footer
        }
        .background(DesignTokens.Colors.canvas)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(preferences.string(.accountDetailsTitle)).font(.system(size: 13, weight: .semibold))
            }
            .flatToolbarBackground()
            ToolbarItem(placement: .primaryAction) { closeButton }
        }
        .onAppear(perform: reload)
        .onChange(of: account) { _, _ in reload() }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
        }
        .buttonStyle(QuietButtonStyle())
        .help(preferences.string(.closeDetailsButton))
        .accessibilityLabel(preferences.string(.closeDetailsButton))
    }


    @ViewBuilder private var latestChange: some View {
        if let latest = timeline.first, latest.comparisonCurrency == account.currency, let delta = latest.delta {
            let tint: Color = delta > 0 ? .green : (delta < 0 ? .red : .secondary)
            HStack(spacing: 4) {
                Image(systemName: delta > 0 ? "arrow.up" : (delta < 0 ? "arrow.down" : "minus"))
                Text(changeText(delta, percentage: latest.percentage))
            }
            .font(.system(size: 10, weight: .semibold)).monospacedDigit()
            .foregroundStyle(tint)
            .padding(.horizontal, 7).padding(.vertical, 5)
            .background(tint.opacity(0.13), in: Capsule())
            .overlay { Capsule().strokeBorder(tint.opacity(0.25)) }
            .fixedSize()
        }
    }

    private var updatedTimestamp: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(preferences.string(.updatedAtLabel))
            Text(timestamp(account.updatedAt)).fontWeight(.medium)
        }
        .font(.system(size: 9)).foregroundStyle(.secondary)
        .fixedSize()
    }

    private var historyCard: some View {
        let rows = timeline
        return Group {
            if rows.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 24)).foregroundStyle(.tertiary)
                    Text(preferences.string(.emptyBalanceHistory)).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 28)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        historyRow(row, first: index == 0, last: index == rows.count - 1)
                    }
                }
                .padding(14)
            }
        }
        .cardSurface()
    }

    private func historyRow(_ row: BalanceHistoryTimeline.Row, first: Bool, last: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            TimelineRail(first: first, last: last)
                .frame(width: 14, height: 56)
            VStack(alignment: .leading, spacing: 5) {
                Text(historyAmount(row.entry)).font(.system(size: 13, weight: .semibold)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(timestamp(row.entry.recordedAt)).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .padding(.top, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            historyBadge(row).padding(.top, 8)
        }
        .frame(minHeight: 56, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func historyBadge(_ row: BalanceHistoryTimeline.Row) -> some View {
        let delta = row.delta
        let color: Color = delta.map { $0 > 0 ? .green : ($0 < 0 ? .red : .secondary) } ?? .secondary
        return Text(delta.map { signedAmount($0, compact: true, currency: row.comparisonCurrency) } ?? (row.isInitial ? preferences.string(.initialBalanceLabel) : "—"))
            .font(.system(size: 10, weight: .semibold)).monospacedDigit()
            .foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 4))
            .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(color.opacity(0.18)) }
            .fixedSize()
            .help(delta == nil && !row.isInitial ? preferences.string(.historyComparisonUnavailable) : "")
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button(action: onEdit) { Label(preferences.string(.editButton), systemImage: "pencil").frame(maxWidth: .infinity) }
                .buttonStyle(InspectorActionStyle(primary: false))
            Button(action: onReconcile) { Label(preferences.string(.reconcileBalanceButton), systemImage: "arrow.triangle.2.circlepath").frame(maxWidth: .infinity) }
                .buttonStyle(InspectorActionStyle(primary: true))
        }
        .padding(12)
        .background(DesignTokens.Colors.subtleBackground)
    }

    private func symbol(_ currency: Currency) -> String { currency == .kzt ? "₸" : "$" }

    private func amount(_ value: Decimal) -> String {
        "\(NumberDisplayFormatter.format(value, preferences: session.numberFormatPreferences)) \(symbol(account.currency))"
    }

    private func historyAmount(_ entry: BalanceHistoryEntry) -> String {
        let formatted = NumberDisplayFormatter.format(entry.balance, preferences: session.numberFormatPreferences)
        return entry.currency.map { formatted + " " + symbol($0) } ?? formatted
    }

    private func signedAmount(_ value: Decimal, compact: Bool = false, currency: Currency? = nil) -> String {
        var format = session.numberFormatPreferences
        if compact { format.useCompactNotation = true }
        return (value > 0 ? "+" : "") + NumberDisplayFormatter.format(value, preferences: format) + (currency.map { " " + symbol($0) } ?? "")
    }

    private func changeText(_ delta: Decimal, percentage: Decimal?) -> String {
        guard let percentage else { return signedAmount(delta, currency: account.currency) }
        var format = session.numberFormatPreferences
        format.maxDecimalPlaces = 1
        format.useCompactNotation = false
        let percent = (percentage > 0 ? "+" : "") + NumberDisplayFormatter.format(percentage, preferences: format) + "%"
        return "\(signedAmount(delta, currency: account.currency)) (\(percent))"
    }

    private func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: preferences.language == .ru ? "ru_RU" : "en_US")
        formatter.dateFormat = "d MMM yyyy · HH:mm"
        return formatter.string(from: date)
    }

    private func reload() {
        guard let connection = session.connection else { entries = []; return }
        let service = AccountService(connection: connection, institutionService: InstitutionService(connection: connection))
        entries = service.balanceHistory(accountId: account.id)
    }
}

private struct TimelineRail: View {
    let first: Bool
    let last: Bool

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: 7, y: first ? 17 : 0))
                path.addLine(to: CGPoint(x: 7, y: last ? 17 : geometry.size.height))
            }
            .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            Circle().fill(DesignTokens.Colors.cardBackground).frame(width: 14, height: 14).position(x: 7, y: 17)
            if first {
                Circle().fill(Color.green.opacity(0.2)).frame(width: 14, height: 14).position(x: 7, y: 17)
            }
            Circle().fill(first ? Color.green : Color.secondary.opacity(last ? 0.35 : 0.65))
                .frame(width: 8, height: 8).position(x: 7, y: 17)
        }
        .accessibilityHidden(true)
    }
}

private struct InspectorActionStyle: ButtonStyle {
    let primary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(primary ? Color.white : Color.primary)
            .padding(.horizontal, 10).frame(height: 32)
            .background(primary ? DesignTokens.Colors.accent : DesignTokens.Colors.cardBackground,
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(primary ? Color.clear : DesignTokens.Colors.cardBorder) }
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
