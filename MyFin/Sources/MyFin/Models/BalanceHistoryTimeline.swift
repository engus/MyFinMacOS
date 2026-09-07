import Foundation

struct BalanceHistoryTimeline {
    struct Row: Identifiable {
        let entry: BalanceHistoryEntry
        let delta: Decimal?
        let percentage: Decimal?
        let comparisonCurrency: Currency?
        let isInitial: Bool
        var id: String { entry.id }
    }

    let rows: [Row]

    init(entriesOldestFirst entries: [BalanceHistoryEntry]) {
        rows = entries.indices.reversed().map { index in
            let entry = entries[index]
            guard index > 0 else { return Row(entry: entry, delta: nil, percentage: nil, comparisonCurrency: nil, isInitial: true) }
            let previousCurrency = entries[index - 1].currency
            if let currency = entry.currency, let previousCurrency, currency != previousCurrency {
                return Row(entry: entry, delta: nil, percentage: nil, comparisonCurrency: nil, isInitial: false)
            }
            let previous = entries[index - 1].balance
            let delta = entry.balance - previous
            return Row(entry: entry, delta: delta, percentage: previous == 0 ? nil : delta / previous * 100,
                       comparisonCurrency: entry.currency == previousCurrency ? entry.currency : nil, isInitial: false)
        }
    }
}
