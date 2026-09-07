import XCTest
@testable import MyFin

final class BalanceHistoryTimelineTests: XCTestCase {
    private func entry(_ id: String, _ balance: Decimal) -> BalanceHistoryEntry {
        BalanceHistoryEntry(id: id, balance: balance, recordedAt: Date(timeIntervalSince1970: 100), currency: .kzt)
    }

    func test_reversesHistoryAndComparesEachBalanceWithItsPredecessor() {
        let rows = BalanceHistoryTimeline(entriesOldestFirst: [
            entry("initial", 1000), entry("gain", 10000), entry("loss", 1000), entry("latest", 100000)
        ]).rows
        XCTAssertEqual(rows.map(\.id), ["latest", "loss", "gain", "initial"])
        XCTAssertEqual(rows.map(\.delta), [99000, -9000, 9000, nil])
        XCTAssertEqual(rows.map(\.percentage), [9900, -90, 900, nil])
        XCTAssertEqual(rows.first?.comparisonCurrency, .kzt)
    }

    func test_zeroPreviousBalanceHasAnAbsoluteChangeButNoPercentage() {
        let rows = BalanceHistoryTimeline(entriesOldestFirst: [entry("zero", 0), entry("gain", 50)]).rows
        XCTAssertEqual(rows.first?.delta, 50)
        XCTAssertNil(rows.first?.percentage)
    }

    func test_initialAndEmptyHistoriesDoNotInventChanges() {
        XCTAssertTrue(BalanceHistoryTimeline(entriesOldestFirst: []).rows.isEmpty)
        let row = BalanceHistoryTimeline(entriesOldestFirst: [entry("initial", 10)]).rows.first
        XCTAssertNil(row?.delta)
        XCTAssertNil(row?.percentage)
        let unchanged = BalanceHistoryTimeline(entriesOldestFirst: [entry("a", 10), entry("b", 10)]).rows.first
        XCTAssertEqual(unchanged?.delta, 0)
        XCTAssertEqual(unchanged?.percentage, 0)
    }
    func test_currencyChangesDoNotProduceMisleadingDeltas() {
        let usd = BalanceHistoryEntry(id: "usd", balance: 100, recordedAt: .distantPast, currency: .usd)
        let kzt = BalanceHistoryEntry(id: "kzt", balance: 46050, recordedAt: .distantPast, currency: .kzt)
        for entries in [[usd, kzt], [kzt, usd]] {
            let row = BalanceHistoryTimeline(entriesOldestFirst: entries).rows.first
            XCTAssertNil(row?.delta)
            XCTAssertNil(row?.percentage)
            XCTAssertEqual(row?.isInitial, false)
        }
    }

    func test_legacyHistoryShowsRawChangesIncludingFirstCurrencySnapshot() {
        let balances: [Decimal] = [1000, 10000, 1000, 10000, 100000, 100000]
        let entries = balances.enumerated().map { index, balance in
            BalanceHistoryEntry(id: "entry-\(index)", balance: balance, recordedAt: .distantPast,
                                currency: index == 5 ? .kzt : nil)
        }
        let rows = BalanceHistoryTimeline(entriesOldestFirst: entries).rows
        XCTAssertEqual(rows.map(\.delta), [0, 90000, 9000, -9000, 9000, nil])
        XCTAssertEqual(rows.map(\.percentage), [0, 900, 900, -90, 900, nil])
        XCTAssertTrue(rows.allSatisfy { $0.comparisonCurrency == nil })
    }

}
