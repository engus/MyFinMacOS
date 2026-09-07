import XCTest
@testable import MyFin

final class CashflowTests: XCTestCase {
    var url: URL!
    var db: DatabaseConnection!
    var service: CashflowService!
    let now = ISO8601DateFormatter().date(from: "2026-09-15T12:00:00Z")!
    override func setUpWithError() throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        db = try DatabaseConnection.open(at: url, password: "test")
        service = CashflowService(db: db, now: { self.now })
        try service.setTimezone("Asia/Almaty")
    }
    override func tearDownWithError() throws { db.close(); try? FileManager.default.removeItem(at: url) }
    func account(_ currency: Currency = .usd, amount: Decimal = 100) throws -> Account {
        try AccountService(connection: db, institutionService: InstitutionService(connection: db), now: { self.now })
            .createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: currency,
                openingBalance: amount, name: "Wallet", balanceDate: FlowDate.parse("2026-01-01")).get()
    }
    func draft(_ account: Account, _ amount: Decimal = 10, date: String = "2026-09-10") -> FlowDraft {
        FlowDraft(accountID: account.id, amount: amount, currency: account.currency, date: date)
    }
    func test_postingUpdatesExistingAccountsUsingBalancedImmutableEntries() throws {
        let a = try account()
        let op = try service.post(draft(a))
        XCTAssertEqual(try service.balance(accountID: a.id, currency: .usd), 90)
        XCTAssertEqual(service.accounts().first?.openingBalance, 90)
        let rows = try db.query("SELECT units FROM ledger_entries WHERE operation_id = ?;", params: [.text(op.id)])
        XCTAssertEqual(rows.count, 2)
        XCTAssertThrowsError(try db.execute("DELETE FROM flow_operations WHERE id = ?;", params: [.text(op.id)]))
        XCTAssertThrowsError(try db.execute("UPDATE ledger_entries SET units = 0 WHERE operation_id = ?;", params: [.text(op.id)]))
        XCTAssertThrowsError(try db.execute("INSERT INTO ledger_entries VALUES ('bad', ?, ?, 'USD', 1);", params: [.text(op.id), .text("account:" + a.id)]))
        XCTAssertEqual(try service.totals(service.monthly("2026-09"), base: .usd).expense, 10)
    }
    func test_correctionAndReversalRetainAuditAndExactBalance() throws {
        let a = try account()
        let original = try service.post(draft(a))
        let replacement = try service.correct(original.id, with: draft(a, 25))
        XCTAssertEqual(replacement.replacementOf, original.id)
        XCTAssertEqual(try service.balance(accountID: a.id, currency: .usd), 75)
        XCTAssertEqual(try service.totals(service.monthly("2026-09"), base: .usd).expense, 25)
        XCTAssertThrowsError(try service.reverse(original.id))
        _ = try service.reverse(replacement.id)
        XCTAssertEqual(try service.balance(accountID: a.id, currency: .usd), 100)
    }
    func test_invalidReplacementRollsBackReversal() throws {
        let a = try account()
        let op = try service.post(draft(a))
        XCTAssertThrowsError(try service.correct(op.id, with: draft(a, -1)))
        XCTAssertFalse(try service.operations().contains { $0.reversalOf == op.id })
        XCTAssertEqual(try service.balance(accountID: a.id, currency: .usd), 90)
    }
    func test_crossCurrencyPostingsAndFXSnapshotSurviveQuoteChanges() throws {
        let a = try account(.kzt, amount: 10000)
        var d = draft(a); d.currency = .usd
        XCTAssertThrowsError(try service.post(d))
        try service.saveQuote(from: .usd, to: .kzt, rate: 500, date: d.date)
        let op = try service.post(d)
        XCTAssertEqual(op.accountAmount, 5000)
        XCTAssertEqual(try db.query("SELECT * FROM ledger_entries WHERE operation_id = ?;", params: [.text(op.id)]).count, 4)
        try service.saveQuote(from: .usd, to: .kzt, rate: 600, date: d.date)
        XCTAssertEqual(try service.totals(service.monthly("2026-09"), base: .kzt).expense, 5000)
        _ = try service.reverse(op.id)
        XCTAssertEqual(try service.balance(accountID: a.id, currency: .kzt), 10000)
    }
    func test_missingAndStaleFXAreReportedAndZeroIncomeHasNoSavingsRate() throws {
        let a = try account(.kzt)
        _ = try service.post(draft(a))
        let rows = try service.monthly("2026-09")
        XCTAssertEqual(try service.totals(rows, base: .usd).missingFX, 1)
        XCTAssertNil(try service.totals(rows, base: .kzt).savingsRate)
        try service.saveQuote(from: .usd, to: .kzt, rate: 500, date: "2026-09-01")
        XCTAssertEqual(try service.totals(rows, base: .usd).staleFX, 1)
    }
    func test_recurringMonthEndAndMaterializationAreIdempotent() throws {
        let a = try account(amount: 1000)
        let t = RecurringFlow(accountID: a.id, kind: .expense, categoryID: "subscriptions", amount: 10,
            currency: .usd, note: "Subscription", start: "2026-01-31", unit: .month, timezone: "Asia/Almaty")
        XCTAssertEqual(try t.dates(through: "2026-03-31"), ["2026-01-31", "2026-02-28", "2026-03-31"])
        try service.saveTemplate(t)
        XCTAssertEqual(try service.materializeDue(), 8)
        XCTAssertEqual(try service.materializeDue(), 0)
        XCTAssertEqual(try service.balance(accountID: a.id, currency: .usd), 920)
        let current = try service.monthly("2026-09")
        XCTAssertEqual(current.filter(\.expected).count, 1)
        XCTAssertEqual(try service.monthly("2026-08").filter(\.expected).count, 0)
        XCTAssertEqual(try service.monthly("2026-10").filter(\.expected).count, 1)
        XCTAssertEqual(try service.balance(accountID: a.id, currency: .usd), 920)
    }
    func test_reconciliationRepeatsWithReversalAndMarksGap() throws {
        let a = try account()
        let first = try service.reconcile(accountID: a.id, month: "2026-08", reported: 80)
        XCTAssertTrue(first.gap)
        XCTAssertEqual(try service.totals(service.monthly("2026-08"), base: .usd).expense, 20)
        let second = try service.reconcile(accountID: a.id, month: "2026-08", reported: 90)
        XCTAssertEqual(second.previousID, first.id)
        XCTAssertEqual(try service.balance(accountID: a.id, currency: .usd), 90)
        XCTAssertEqual(try service.totals(service.monthly("2026-08"), base: .usd).expense, 10)
        XCTAssertTrue(try service.isReconciled(account: a, month: "2026-08"))
        _ = try service.post(draft(a, 1, date: "2026-08-10"))
        XCTAssertFalse(try service.isReconciled(account: a, month: "2026-08"))
        XCTAssertThrowsError(try service.reconcile(accountID: a.id, month: "2026-09", reported: 0))
    }
    func test_accountsReconcileIndependentlyEvenWithZeroAdjustment() throws {
        let a = try account(); let b = try account()
        let record = try service.reconcile(accountID: a.id, month: "2026-08", reported: 100)
        XCTAssertNil(record.operationID)
        XCTAssertTrue(try service.isReconciled(account: a, month: "2026-08"))
        XCTAssertFalse(try service.isReconciled(account: b, month: "2026-08"))
    }
    func test_archiveAndInvalidCategoryPreventPosting() throws {
        let a = try account()
        var d = draft(a); d.categoryID = "salary"
        XCTAssertThrowsError(try service.post(d))
        _ = AccountService(connection: db, institutionService: InstitutionService(connection: db)).archiveAccount(id: a.id)
        XCTAssertThrowsError(try service.post(draft(a)))
    }
    func test_decimalArithmeticAndFutureDateValidation() throws {
        let a = try account(amount: 1)
        for _ in 0..<3 { _ = try service.post(draft(a, Decimal(string: "0.1")!)) }
        XCTAssertEqual(try service.balance(accountID: a.id, currency: .usd), Decimal(string: "0.7"))
        XCTAssertThrowsError(try service.post(draft(a, date: "2026-09-20")))
        XCTAssertThrowsError(try service.post(draft(a, Decimal(string: "0.000000001")!)))
    }
    func test_monthURLRoundTripAndInvalidDates() throws {
        XCTAssertEqual(FlowDate.month(from: FlowDate.url(month: "2026-09")), "2026-09")
        XCTAssertNil(FlowDate.month(from: URL(string: "myfin://cashflow?month=2026-99")!))
        XCTAssertNil(FlowDate.parse("2026-02-30"))
    }

    func test_lateFXSnapshotIsFrozenAndSharedWithReversal() throws {
        let a = try account(.kzt)
        let op = try service.post(draft(a))
        try service.saveQuote(from: .usd, to: .kzt, rate: 500, date: op.date)
        XCTAssertEqual(try service.totals([op], base: .usd).expense, Decimal(string: "0.02"))
        try service.saveQuote(from: .usd, to: .kzt, rate: 1000, date: op.date)
        XCTAssertEqual(try service.totals([op], base: .usd).expense, Decimal(string: "0.02"))
        _ = try service.reverse(op.id)
        XCTAssertEqual(try service.totals(service.monthly("2026-09"), base: .usd).expense, 0)
    }
    func test_internalTransferExcludedAndAssetPurchaseIncludedInExpenses() throws {
        let a = try account(); let b = try account()
        let op = try service.transfer(from: a.id, to: b.id, amount: 10, date: "2026-09-01")
        XCTAssertEqual(try service.balance(accountID: a.id, currency: .usd), 90)
        XCTAssertEqual(try service.balance(accountID: b.id, currency: .usd), 110)
        XCTAssertEqual(try service.totals(service.operations(), base: .usd).expense, 0)
        _ = try service.reverse(op.id)
        XCTAssertEqual(try service.balance(accountID: b.id, currency: .usd), 100)
        var d = draft(a); d.source = .assetPurchase
        _ = try service.post(d)
        XCTAssertEqual(try service.totals(service.monthly("2026-09"), base: .usd).expense, 10)
    }
    func test_postedActivityPreventsCurrencyRewrite() throws {
        let a = try account()
        _ = try service.post(draft(a))
        let result = AccountService(connection: db, institutionService: InstitutionService(connection: db)).updateAccount(
            id: a.id, name: a.name, country: a.country, type: a.type, currency: .kzt, institutionSelection: .none, openingBalance: 90)
        XCTAssertEqual(try? result.get(), nil)
        XCTAssertEqual(service.accounts().first?.currency, .usd)
    }
    func test_recurringTemplateUsesItsOwnTimezoneAtMidnight() throws {
        let a = try account()
        let engine = CashflowService(db: db, now: { ISO8601DateFormatter().date(from: "2026-09-15T23:30:00Z")! })
        try engine.setTimezone("America/Los_Angeles")
        let template = RecurringFlow(accountID: a.id, kind: .income, categoryID: "salary", amount: 10, currency: .usd,
            note: "Tokyo salary", start: "2026-09-16", unit: .month, timezone: "Asia/Tokyo")
        try engine.saveTemplate(template)
        XCTAssertEqual(try engine.materializeDue(), 1)
        XCTAssertEqual(try engine.materializeDue(), 0)
    }
    func test_missingRecurringFXDoesNotBlockOtherTemplates() throws {
        let a = try account(.kzt); let b = try account()
        try service.saveQuote(from: .usd, to: .kzt, rate: 500, date: "2026-09-01")
        try service.saveTemplate(RecurringFlow(accountID: a.id, kind: .income, categoryID: "salary", amount: 10,
            currency: .usd, note: "Missing FX", start: "2026-09-01", unit: .month, timezone: "Asia/Almaty"))
        try db.execute("DELETE FROM flow_fx;")
        try service.saveTemplate(RecurringFlow(accountID: b.id, kind: .income, categoryID: "salary", amount: 20,
            currency: .usd, note: "Available", start: "2026-09-01", unit: .month, timezone: "Asia/Almaty"))
        XCTAssertThrowsError(try service.materializeDue())
        XCTAssertEqual(try service.balance(accountID: b.id, currency: .usd), 120)
        XCTAssertEqual(try service.balance(accountID: a.id, currency: .kzt), 100)
    }
    func test_demoIsOptInAndDoesNotDuplicate() throws {
        XCTAssertTrue(service.accounts().isEmpty)
        try service.addDemoData()
        let count = try service.operations().count
        try service.addDemoData()
        XCTAssertEqual(service.accounts().count, 3)
        XCTAssertEqual(try service.operations().count, count)
        XCTAssertTrue(try service.monthly("2026-09").contains(where: \.expected))
    }
    func test_reopeningRetainsLedgerBalanceInsteadOfLegacyMutableValue() throws {
        let a = try account()
        _ = try service.post(draft(a))
        try db.execute("UPDATE accounts SET opening_balance = '99999' WHERE id = ?;", params: [.text(a.id)])
        db.close()
        db = try DatabaseConnection.open(at: url, password: "test")
        service = CashflowService(db: db, now: { self.now })
        XCTAssertEqual(service.accounts().first?.openingBalance, 90)
    }

    func test_unbalancedJournalCannotBeSealedOrAffectBalance() throws {
        let a = try account()
        XCTAssertThrowsError(try db.withTransaction {
            let op = FlowOperation(accountID: a.id, kind: .expense, categoryID: "other-expense", amount: 10,
                currency: .usd, accountAmount: 10, accountCurrency: .usd, date: "2026-09-01", note: "Invalid")
            try db.execute("INSERT INTO flow_operations VALUES (?, ?, ?, ?, NULL, NULL, NULL);",
                params: [.text(op.id), .text(a.id), .text(op.date), .text(try CashflowSchema.json(op))])
            for (ledger, units) in [("account:" + a.id, Int64(-100)), ("category:other-expense", Int64(90))] {
                try db.execute("INSERT INTO ledger_entries VALUES (?, ?, ?, 'USD', ?);", params: [.text(UUID().uuidString), .text(op.id), .text(ledger), .int(units)])
            }
            try db.execute("INSERT INTO ledger_seals VALUES (?);", params: [.text(op.id)])
        })
        XCTAssertEqual(try service.balance(accountID: a.id, currency: .usd), 100)
        XCTAssertEqual(try service.operations().count, 1)
    }
    func test_legacyBalanceMigratesToOpeningEquityExactlyOnce() throws {
        let a = try account(amount: 123)
        try db.execute("PRAGMA foreign_keys = OFF;")
        for table in ["flow_valuations", "ledger_seals", "ledger_entries", "flow_operations", "ledger_accounts"] {
            try db.execute("DROP TABLE \(table);")
        }
        try db.setUserVersion(7)
        db.close()
        db = try DatabaseConnection.open(at: url, password: "test")
        service = CashflowService(db: db, now: { self.now })
        XCTAssertEqual(try service.balance(accountID: a.id, currency: .usd), 123)
        XCTAssertEqual(try service.operations().count, 1)
        XCTAssertEqual(try service.operations().first?.source, .opening)
        XCTAssertEqual(try service.totals(service.operations(), base: .usd).income, 0)
        db.close()
        db = try DatabaseConnection.open(at: url, password: "test")
        service = CashflowService(db: db, now: { self.now })
        XCTAssertEqual(try service.operations().count, 1)
    }
}
