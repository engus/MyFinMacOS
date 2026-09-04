import SwiftUI

struct BalanceHistoryPanelView: View {
    @ObservedObject var session: AppSession
    let account: Account
    let onClose: () -> Void
    @EnvironmentObject var preferences: AppPreferences

    @State private var entries: [BalanceHistoryEntry] = []

    private var accountService: AccountService? {
        guard let connection = session.connection else { return nil }
        let institutions = InstitutionService(connection: connection)
        return AccountService(connection: connection, institutionService: institutions)
    }

    private var newestFirstEntries: [BalanceHistoryEntry] {
        entries.reversed()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(account.name).font(.headline)
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding([.horizontal, .top], 12)

            List {
                ForEach(Array(newestFirstEntries.enumerated()), id: \.element.id) { index, entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NumberDisplayFormatter.format(entry.balance, preferences: session.numberFormatPreferences))
                            .font(.headline)
                        HStack {
                            Text(entry.recordedAt, style: .date)
                            if let delta = delta(at: index) {
                                Text(deltaText(delta))
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear(perform: reload)
    }

    private func delta(at index: Int) -> Decimal? {
        guard index + 1 < newestFirstEntries.count else { return nil }
        return newestFirstEntries[index].balance - newestFirstEntries[index + 1].balance
    }

    private func deltaText(_ delta: Decimal) -> String {
        let formatted = NumberDisplayFormatter.format(delta, preferences: session.numberFormatPreferences)
        return delta >= 0 ? "+\(formatted)" : formatted
    }

    private func reload() {
        guard let service = accountService else { return }
        entries = service.balanceHistory(accountId: account.id)
    }
}
