import XCTest
import SwiftUI
import AppKit
@testable import MyFin

@MainActor
final class CashflowPresentationTests: XCTestCase {
    func test_savedOperationChangesVisibleMonthAndRepeatedSavesRefreshTheView() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = AppSession(profileStore: ProfileStore(baseDirectory: root))
        session.createProfile(displayName: "Presentation", password: "test", remember: false)
        let db = try XCTUnwrap(session.connection)
        let service = CashflowService(db: db)
        let account = try AccountService(connection: db, institutionService: InstitutionService(connection: db))
            .createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd,
                openingBalance: 100, name: "Wallet", balanceDate: nil).get()
        let preferences = AppPreferences(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        var visibleMonth = "2020-01"
        let view = CashflowView(session: session, month: Binding(get: { visibleMonth }, set: { visibleMonth = $0 }))
            .environmentObject(preferences)
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 1120, height: 800)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        defer { window.contentView = nil }
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        XCTAssertTrue(try service.monthly(visibleMonth).isEmpty)

        let operation = try service.post(FlowDraft(accountID: account.id, amount: 10, currency: .usd, date: service.today))
        session.ledgerChanged(focusingOn: operation.date)
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        XCTAssertEqual(visibleMonth, String(service.today.prefix(7)))
        XCTAssertEqual(try service.monthly(visibleMonth).map(\.id), [operation.id])

        let firstFocus = session.cashflowFocus
        session.ledgerChanged(focusingOn: operation.date)
        XCTAssertNotEqual(session.cashflowFocus, firstFocus)
        let secondFocus = session.cashflowFocus
        session.materializeCashflow()
        XCTAssertEqual(session.cashflowFocus, secondFocus, "Background refresh must not change the selected month")
    }
}
