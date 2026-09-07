import Foundation

final class CashflowService {
    let db: DatabaseConnection
    let now: () -> Date
    init(db: DatabaseConnection, now: @escaping () -> Date = Date.init) { self.db = db; self.now = now }

    var timezone: TimeZone {
        let raw = (try? db.query("SELECT value FROM profile_settings WHERE key = 'cashflowTimezone';"))?.first?.string("value")
        return raw.flatMap(TimeZone.init(identifier:)) ?? .current
    }
    var today: String { FlowDate.key(now(), timezone: timezone) }
    func setTimezone(_ id: String) throws {
        guard TimeZone(identifier: id) != nil else { throw FlowError.invalidSchedule }
        try db.execute("INSERT INTO profile_settings VALUES ('cashflowTimezone', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;", params: [.text(id)])
    }
    func accounts(includeArchived: Bool = false) -> [Account] {
        AccountService(connection: db, institutionService: InstitutionService(connection: db), now: now)
            .listAccounts(includeArchived: includeArchived)
    }
    func operationalAccounts() -> [Account] { accounts().filter { $0.type != .deposit } }
    func categories() throws -> [FlowCategory] { try db.query("SELECT payload FROM flow_categories ORDER BY rowid;").map { try $0.decode(FlowCategory.self) } }
    func addCategory(name: String, kind: FlowKind) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw FlowError.categoryMismatch }
        let category = FlowCategory(id: UUID().uuidString, kind: kind, name: name, englishName: name)
        try db.withTransaction {
            try db.execute("INSERT INTO flow_categories VALUES (?, ?, ?);", params: [.text(category.id), .text(kind.rawValue), .text(try CashflowSchema.json(category))])
            try db.execute("INSERT INTO ledger_accounts VALUES (?, NULL, ?);", params: [.text("category:" + category.id), .text(category.id)])
        }
    }
    func operations() throws -> [FlowOperation] {
        try db.query("SELECT o.payload FROM flow_operations o JOIN ledger_seals s ON s.operation_id = o.id ORDER BY o.date, o.rowid;").map { try $0.decode(FlowOperation.self) }
    }
    func balance(accountID: String, currency: Currency, through date: String = "9999-12-31") throws -> Decimal {
        let rows = try db.query("""
            SELECT e.units FROM ledger_entries e JOIN ledger_seals s ON s.operation_id = e.operation_id
            JOIN flow_operations o ON o.id = e.operation_id
            WHERE e.ledger_account_id = ? AND e.currency = ? AND o.date <= ?;
            """, params: [.text("account:" + accountID), .text(currency.rawValue), .text(date)])
        return try rows.reduce(Decimal.zero) { sum, row in
            guard case .int(let units)? = row["units"] else { throw FlowError.corruptData }
            return sum + Decimal(units) / FlowMoney.scale
        }
    }

    // Called inside the account service/migration transaction.
    func opening(accountID: String, amount: Decimal, currency: Currency, date: String) throws {
        try db.execute("INSERT OR IGNORE INTO ledger_accounts VALUES (?, ?, NULL);", params: [.text("account:" + accountID), .text(accountID)])
        let operation = FlowOperation(accountID: accountID, kind: .income, categoryID: "", amount: abs(amount), currency: currency,
            accountAmount: abs(amount), accountCurrency: currency, date: date, note: "Opening balance", source: .opening)
        try persist(operation, entries: [("account:" + accountID, currency, amount), ("equity", currency, -amount)])
    }

    func quote(from: Currency, to: Currency, date: String) throws -> FXSnapshot? {
        FXSnapshot(from: from, to: to, rate: HardcodedExchangeRateProvider().rate(from: from, to: to),
            date: date, source: from == to ? "identity" : "Fixed: 1 USD = 460 KZT")
    }

    @discardableResult func post(_ draft: FlowDraft) throws -> FlowOperation {
        guard draft.source == .ordinary || (draft.source == .assetPurchase && draft.kind == .expense) else { throw FlowError.immutable }
        return try db.withTransaction { try postInside(draft) }
    }
    private func makeOperation(_ draft: FlowDraft, allowDeposit: Bool = false, requireFX: Bool = true) throws -> FlowOperation {
        guard draft.amount > 0 else { throw FlowError.invalidAmount }
        _ = try FlowMoney.units(draft.amount)
        guard FlowDate.parse(draft.date) != nil else { throw FlowError.invalidDate }
        guard let account = accounts().first(where: { $0.id == draft.accountID }), allowDeposit || account.type != .deposit else { throw FlowError.accountUnavailable }
        guard try categories().contains(where: { $0.id == draft.categoryID && $0.kind == draft.kind }) else { throw FlowError.categoryMismatch }
        var snapshots: [FXSnapshot] = []
        for target in Currency.allCases where target != draft.currency {
            if let q = try quote(from: draft.currency, to: target, date: draft.date) { snapshots.append(q) }
        }
        let conversion = try quote(from: draft.currency, to: account.currency, date: draft.date)
        if conversion == nil && requireFX { throw FlowError.missingFX }
        let accountAmount = FlowMoney.rounded(draft.amount * (conversion?.rate ?? 0))
        if conversion != nil && accountAmount <= 0 { throw FlowError.invalidAmount }
        _ = try FlowMoney.units(accountAmount)
        return FlowOperation(accountID: account.id, kind: draft.kind, categoryID: draft.categoryID, amount: draft.amount,
            currency: draft.currency, accountAmount: accountAmount, accountCurrency: account.currency,
            date: draft.date, note: draft.note, source: draft.source, fx: snapshots)
    }
    @discardableResult private func postInside(_ draft: FlowDraft, templateID: String? = nil, occurrence: String? = nil,
        replacementOf: String? = nil, gap: Bool = false, allowDeposit: Bool = false, dueThrough: String? = nil) throws -> FlowOperation {
        guard draft.date <= (dueThrough ?? today) else { throw FlowError.futurePosting }
        var op = try makeOperation(draft, allowDeposit: allowDeposit)
        op.templateID = templateID; op.occurrence = occurrence; op.replacementOf = replacementOf; op.gap = gap
        let sign: Decimal = op.kind == .income ? 1 : -1
        var entries = [("account:" + op.accountID, op.accountCurrency, sign * op.accountAmount),
                       ("category:" + op.categoryID, op.currency, -sign * op.amount)]
        if op.currency != op.accountCurrency {
            entries += [("fx", op.accountCurrency, -sign * op.accountAmount), ("fx", op.currency, sign * op.amount)]
        }
        try persist(op, entries: entries)
        try snapshot(op)
        return op
    }
    private func persist(_ operation: FlowOperation, entries: [(String, Currency, Decimal)]) throws {
        var operation = operation
        operation.createdAt = ISO8601DateFormatter().string(from: now())
        guard entries.count >= 2 else { throw FlowError.corruptData }
        for currency in Currency.allCases {
            guard entries.filter({ $0.1 == currency }).reduce(Decimal.zero, { $0 + $1.2 }) == 0 else { throw FlowError.corruptData }
        }
        try db.execute("INSERT INTO flow_operations VALUES (?, ?, ?, ?, ?, ?, ?);", params: [
            .text(operation.id), .text(operation.accountID), .text(operation.date), .text(try CashflowSchema.json(operation)),
            operation.reversalOf.map(SQLValue.text) ?? .null, operation.templateID.map(SQLValue.text) ?? .null, operation.occurrence.map(SQLValue.text) ?? .null])
        for (account, currency, amount) in entries {
            try db.execute("INSERT INTO ledger_entries VALUES (?, ?, ?, ?, ?);", params: [.text(UUID().uuidString), .text(operation.id), .text(account), .text(currency.rawValue), .int(try FlowMoney.units(amount))])
        }
        try db.execute("INSERT INTO ledger_seals VALUES (?);", params: [.text(operation.id)])
    }
    private func snapshot(_ operation: FlowOperation) throws {
        let affected = try db.query("SELECT DISTINCT a.account_id, e.currency FROM ledger_entries e JOIN ledger_accounts a ON a.id = e.ledger_account_id WHERE e.operation_id = ? AND a.account_id IS NOT NULL;", params: [.text(operation.id)])
        for row in affected {
            guard let id = row.string("account_id"), let currency = row.string("currency").flatMap(Currency.init(rawValue:)) else { throw FlowError.corruptData }
            let amount = try balance(accountID: id, currency: currency)
            try db.execute("INSERT INTO balance_history VALUES (?, ?, ?, ?, ?);", params: [.text(UUID().uuidString), .text(id),
                .text(AccountService.decimalString(amount)), .text(ISO8601DateFormatter().string(from: now())), .text(currency.rawValue)])
        }
    }

    @discardableResult func transfer(from sourceID: String, to destinationID: String, amount: Decimal, date: String) throws -> FlowOperation {
        guard sourceID != destinationID, amount > 0 else { throw FlowError.invalidAmount }
        _ = try FlowMoney.units(amount)
        guard FlowDate.parse(date) != nil, date <= today else { throw FlowError.futurePosting }
        let available = accounts()
        guard let source = available.first(where: { $0.id == sourceID }), let destination = available.first(where: { $0.id == destinationID }) else { throw FlowError.accountUnavailable }
        guard let q = try quote(from: source.currency, to: destination.currency, date: date) else { throw FlowError.missingFX }
        let converted = FlowMoney.rounded(amount * q.rate)
        guard converted > 0 else { throw FlowError.invalidAmount }
        return try db.withTransaction {
            let op = FlowOperation(accountID: sourceID, kind: .expense, categoryID: "", amount: amount, currency: source.currency,
                accountAmount: amount, accountCurrency: source.currency, date: date, note: "Transfer → " + destination.name, source: .transfer, fx: [q])
            var entries = [("account:" + sourceID, source.currency, -amount), ("account:" + destinationID, destination.currency, converted)]
            if source.currency != destination.currency { entries += [("fx", source.currency, amount), ("fx", destination.currency, -converted)] }
            try persist(op, entries: entries); try snapshot(op); return op
        }
    }

    @discardableResult func reverse(_ id: String, note: String = "Reversal") throws -> FlowOperation {
        try db.withTransaction { try reverseInside(id, note: note) }
    }
    private func reverseInside(_ id: String, note: String) throws -> FlowOperation {
        let all = try operations()
        guard var original = all.first(where: { $0.id == id }), original.reversalOf == nil,
              original.source != .opening else { throw FlowError.immutable }
        guard !all.contains(where: { $0.reversalOf == id }) else { throw FlowError.alreadyReversed }
        original.id = UUID().uuidString; original.reversalOf = id; original.replacementOf = nil
        original.templateID = nil; original.occurrence = nil; original.note = note
        let entries = try db.query("SELECT * FROM ledger_entries WHERE operation_id = ?;", params: [.text(id)]).map { row -> (String, Currency, Decimal) in
            guard let account = row.string("ledger_account_id"), let currency = row.string("currency").flatMap(Currency.init(rawValue:)),
                  case .int(let units)? = row["units"] else { throw FlowError.corruptData }
            return (account, currency, -Decimal(units) / FlowMoney.scale)
        }
        try persist(original, entries: entries)
        try snapshot(original)
        return original
    }
    @discardableResult func correct(_ id: String, with draft: FlowDraft) throws -> FlowOperation {
        try db.withTransaction {
            guard let original = try operations().first(where: { $0.id == id }), original.source != .reconciliation,
                  original.source != .transfer, draft.source == .ordinary || draft.source == .assetPurchase else { throw FlowError.immutable }
            _ = try reverseInside(id, note: "Correction")
            return try postInside(draft, replacementOf: id)
        }
    }

    // Existing account editor: an adjustment is an ordinary balanced Other Income/Expense posting.
    func adjustBalance(accountID: String, currency: Currency, target: Decimal) throws {
        let difference = target - (try balance(accountID: accountID, currency: currency))
        if difference == 0 { return }
        let kind: FlowKind = difference > 0 ? .income : .expense
        _ = try postInside(FlowDraft(accountID: accountID, kind: kind, categoryID: kind == .income ? "other-income" : "other-expense",
            amount: abs(difference), currency: currency, date: today, note: "Balance adjustment", source: .adjustment), allowDeposit: true)
    }

    func templates() throws -> [RecurringFlow] { try db.query("SELECT payload FROM flow_templates ORDER BY rowid;").map { try $0.decode(RecurringFlow.self) } }
    func saveTemplate(_ template: RecurringFlow) throws {
        guard template.end == nil || (FlowDate.parse(template.end!) != nil && template.end! >= template.start) else { throw FlowError.invalidSchedule }
        _ = try template.dates(through: template.start)
        _ = try makeOperation(FlowDraft(accountID: template.accountID, kind: template.kind, categoryID: template.categoryID,
            amount: template.amount, currency: template.currency, date: template.start, note: template.note), requireFX: false)
        let isEditing = try templates().contains(where: { $0.id == template.id })
        // Due postings each own their transaction, just as on the periodic app refresh.
        if isEditing { _ = try materializeDue() }
        try db.withTransaction {
            var value = template
            if isEditing {
                let zone = TimeZone(identifier: template.timezone)!
                var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone
                value.effectiveFrom = FlowDate.key(calendar.date(byAdding: .day, value: 1, to: now())!, timezone: zone)
            }
            try db.execute("INSERT INTO flow_templates VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET payload = excluded.payload;", params: [.text(value.id), .text(try CashflowSchema.json(value))])
        }
    }
    func setTemplateActive(_ id: String, active: Bool) throws {
        guard var template = try templates().first(where: { $0.id == id }) else { throw FlowError.corruptData }
        template.active = active
        try db.execute("UPDATE flow_templates SET payload = ? WHERE id = ?;", params: [.text(try CashflowSchema.json(template)), .text(id)])
    }
    // Idempotent across launches. Each occurrence and its entries commit atomically.
    @discardableResult func materializeDue() throws -> Int {
        var count = 0
        var failure: Error?
        for template in try templates() where template.active {
            guard operationalAccounts().contains(where: { $0.id == template.accountID }) else { continue }
            let zone = TimeZone(identifier: template.timezone) ?? timezone
            for date in try template.dates(through: FlowDate.key(now(), timezone: zone)) {
                do { try db.withTransaction {
                    let existing = try db.query("SELECT id FROM flow_operations WHERE template_id = ? AND occurrence = ?;", params: [.text(template.id), .text(date)])
                    guard existing.isEmpty else { return }
                    _ = try postInside(FlowDraft(accountID: template.accountID, kind: template.kind, categoryID: template.categoryID,
                        amount: template.amount, currency: template.currency, date: date, note: template.note, source: .recurring),
                        templateID: template.id, occurrence: date, dueThrough: FlowDate.key(now(), timezone: zone))
                    count += 1
                } } catch { failure = error; break }
            }
        }
        if let failure { throw failure }
        return count
    }
    func monthly(_ month: String) throws -> [FlowOperation] {
        let last = try FlowDate.end(month)
        let current = String(today.prefix(7))
        let posted = try operations()
        var result = month <= current ? posted.filter { $0.date.hasPrefix(month) && $0.source != .opening && $0.source != .transfer } : []
        if month >= current {
            for template in try templates() where template.active {
                guard operationalAccounts().contains(where: { $0.id == template.accountID }) else { continue }
                let templateToday = FlowDate.key(now(), timezone: TimeZone(identifier: template.timezone) ?? timezone)
                for date in try template.dates(through: last) where date.hasPrefix(month) && date > templateToday {
                    guard !posted.contains(where: { $0.templateID == template.id && $0.occurrence == date }) else { continue }
                    // Projections may have no cross-currency quote; no posting occurs here.
                    let account = operationalAccounts().first(where: { $0.id == template.accountID })!
                    var op = FlowOperation(id: template.id + ":" + date, accountID: template.accountID, kind: template.kind,
                        categoryID: template.categoryID, amount: template.amount, currency: template.currency,
                        accountAmount: template.amount, accountCurrency: account.currency, date: date, note: template.note,
                        source: .recurring, templateID: template.id, occurrence: date, expected: true)
                    if let q = try quote(from: template.currency, to: account.currency, date: date) { op = FlowOperation(id: op.id,
                        accountID: op.accountID, kind: op.kind, categoryID: op.categoryID, amount: op.amount, currency: op.currency,
                        accountAmount: FlowMoney.rounded(op.amount * q.rate), accountCurrency: account.currency, date: date,
                        note: op.note, source: .recurring, templateID: template.id, occurrence: date, expected: true) }
                    result.append(op)
                }
            }
        }
        return result.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
    }
    func totals(_ rows: [FlowOperation], base: Currency) throws -> FlowTotals {
        var totals = FlowTotals()
        for row in rows where row.source != .opening && row.source != .transfer {
            let q = try valuation(row, base: base)
            guard let q else { totals.missingFX += 1; continue }
            if q.stale { totals.staleFX += 1 }
            let value = FlowMoney.rounded(row.amount * q.rate) * (row.reversalOf == nil ? Decimal(1) : Decimal(-1))
            if row.expected {
                if row.kind == .income { totals.expectedIncome += value } else { totals.expectedExpense += value }
            } else {
                if row.kind == .income { totals.income += value } else { totals.expense += value }
            }
        }
        return totals
    }

    func valuation(_ row: FlowOperation, base: Currency) throws -> FXSnapshot? {
        // Reporting uses the same temporary fixed rate as accounts and the dashboard.
        // Historical posting snapshots remain available in the audit payload.
        try quote(from: row.currency, to: base, date: row.date)
    }

    func reconciliations() throws -> [Reconciliation] { try db.query("SELECT payload FROM flow_reconciliations ORDER BY rowid;").map { try $0.decode(Reconciliation.self) } }
    @discardableResult func reconcile(accountID: String, month: String, reported: Decimal) throws -> Reconciliation {
        let date = try FlowDate.end(month)
        guard date < today else { throw FlowError.invalidMonth }
        _ = try FlowMoney.units(reported)
        guard let account = accounts().first(where: { $0.id == accountID }), FlowDate.key(account.balanceDate, timezone: timezone) <= date else { throw FlowError.accountUnavailable }
        return try db.withTransaction {
            let records = try reconciliations().filter { $0.accountID == accountID }
            let previous = records.last { $0.month == month }
            if let id = previous?.operationID, !(try operations().contains { $0.reversalOf == id }) { _ = try reverseInside(id, note: "Repeated reconciliation") }
            let difference = reported - (try balance(accountID: accountID, currency: account.currency, through: date))
            let earlierMonth = records.filter { $0.month < month }.map(\.month).max()
            let startMonth = earlierMonth ?? FlowDate.month(account.balanceDate, timezone: timezone)
            let gap = (try FlowDate.end(startMonth)) < (try FlowDate.end(previousMonth(month)))
            var op: FlowOperation?
            if difference != 0 {
                let kind: FlowKind = difference > 0 ? .income : .expense
                op = try postInside(FlowDraft(accountID: accountID, kind: kind, categoryID: kind == .income ? "other-income" : "other-expense",
                    amount: abs(difference), currency: account.currency, date: date, note: "Reconciliation " + month, source: .reconciliation),
                    replacementOf: previous?.operationID, gap: gap, allowDeposit: true)
            }
            let record = Reconciliation(accountID: accountID, month: month, reported: reported, currency: account.currency,
                operationID: op?.id, previousID: previous?.id, gap: gap, createdAt: ISO8601DateFormatter().string(from: now()))
            try db.execute("INSERT INTO flow_reconciliations VALUES (?, ?, ?, ?);", params: [.text(record.id), .text(accountID), .text(month), .text(try CashflowSchema.json(record))])
            return record
        }
    }
    func isReconciled(account: Account, month: String) throws -> Bool {
        guard let record = try reconciliations().last(where: { $0.accountID == account.id && $0.month == month }), record.currency == account.currency else { return false }
        return try balance(accountID: account.id, currency: account.currency, through: FlowDate.end(month)) == record.reported
    }
    private func previousMonth(_ month: String) throws -> String {
        let zone = TimeZone(secondsFromGMT: 0)!
        guard let date = FlowDate.parse(month + "-01", timezone: zone) else { throw FlowError.invalidMonth }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone
        return FlowDate.month(calendar.date(byAdding: .month, value: -1, to: date)!, timezone: zone)
    }
}
