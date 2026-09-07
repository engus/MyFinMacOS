import Foundation

extension CashflowService {
    // Explicit opt-in dev fixture. Uses separate named accounts and no invented market FX quotes.
    func addDemoData() throws {
        guard try db.query("SELECT value FROM profile_settings WHERE key = 'cashflowDemo';").isEmpty else { return }
        let accountService = AccountService(connection: db, institutionService: InstitutionService(connection: db), now: now)
        let month = String(today.prefix(7))
        let openingDate = FlowDate.parse(month + "-01", timezone: timezone)!
        func getAccount(_ name: String, type: AccountType) throws -> Account {
            if let existing = accounts().first(where: { $0.name == name }) { return existing }
            return try accountService.createAccount(country: .kz, type: type,
                institutionSelection: type == .cash ? .none : .existing(id: "kz.kaspi-bank"), currency: .usd,
                openingBalance: 1000, name: name, balanceDate: openingDate).get()
        }
        let card = try getAccount("Demo · Card", type: .debitCard)
        let bank = try getAccount("Demo · Bank", type: .bankAccount)
        let cash = try getAccount("Demo · Cash", type: .cash)
        let samples: [(Account, FlowKind, String, Decimal, String)] = [
            (bank, .income, "salary", 4200, "Demo · Salary"),
            (card, .expense, "utilities", 120, "Demo · Utilities"),
            (card, .expense, "groceries", 85, "Demo · Groceries"),
            (cash, .expense, "transport", 15, "Demo · Transport"),
            (card, .expense, "travel", 300, "Demo · Travel")
        ]
        for (account, kind, category, amount, note) in samples {
            if try operations().contains(where: { $0.note == note }) { continue }
            _ = try post(FlowDraft(accountID: account.id, kind: kind, categoryID: category, amount: amount,
                currency: .usd, date: month + "-01", note: note))
        }
        for template in [
            RecurringFlow(id: "demo-rent", accountID: bank.id, kind: .income, categoryID: "rent", amount: 800,
                currency: .usd, note: "Demo · Rent", start: month + "-10", unit: .month, timezone: timezone.identifier),
            RecurringFlow(id: "demo-subscription", accountID: card.id, kind: .expense, categoryID: "subscriptions", amount: 25,
                currency: .usd, note: "Demo · Subscription", start: month + "-20", unit: .month, timezone: timezone.identifier)
        ] { try saveTemplate(template) }
        _ = try materializeDue()
        try db.execute("INSERT INTO profile_settings VALUES ('cashflowDemo', 'true');")
    }
}
