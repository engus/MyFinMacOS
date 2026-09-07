import Foundation

enum CashflowSchema {
    static func install(_ db: DatabaseConnection) throws {
        let statements = [
            "CREATE TABLE IF NOT EXISTS flow_categories (id TEXT PRIMARY KEY, kind TEXT NOT NULL, payload TEXT NOT NULL);",
            "CREATE TABLE IF NOT EXISTS ledger_accounts (id TEXT PRIMARY KEY, account_id TEXT REFERENCES accounts(id), category_id TEXT REFERENCES flow_categories(id));",
            """
            CREATE TABLE IF NOT EXISTS flow_operations (
                id TEXT PRIMARY KEY, account_id TEXT NOT NULL REFERENCES accounts(id), date TEXT NOT NULL,
                payload TEXT NOT NULL, reversal_of TEXT UNIQUE REFERENCES flow_operations(id),
                template_id TEXT, occurrence TEXT, UNIQUE(template_id, occurrence)
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS ledger_entries (
                id TEXT PRIMARY KEY, operation_id TEXT NOT NULL REFERENCES flow_operations(id),
                ledger_account_id TEXT NOT NULL REFERENCES ledger_accounts(id), currency TEXT NOT NULL,
                units INTEGER NOT NULL CHECK(typeof(units) = 'integer' AND abs(units) <= 900000000000000000)
            );
            """,
            "CREATE INDEX IF NOT EXISTS ledger_by_account ON ledger_entries(ledger_account_id, operation_id);",
            "CREATE TABLE IF NOT EXISTS ledger_seals (operation_id TEXT PRIMARY KEY REFERENCES flow_operations(id));",
            """
            CREATE TRIGGER IF NOT EXISTS balanced_before_seal BEFORE INSERT ON ledger_seals BEGIN
                SELECT CASE WHEN (SELECT COUNT(*) FROM ledger_entries WHERE operation_id = NEW.operation_id) < 2
                    THEN RAISE(ABORT, 'at least two entries required') END;
                SELECT CASE WHEN EXISTS (SELECT currency FROM ledger_entries WHERE operation_id = NEW.operation_id
                    GROUP BY currency HAVING SUM(units) != 0) THEN RAISE(ABORT, 'unbalanced transaction') END;
            END;
            """,
            """
            CREATE TRIGGER IF NOT EXISTS immutable_entries_insert BEFORE INSERT ON ledger_entries
            WHEN EXISTS (SELECT 1 FROM ledger_seals WHERE operation_id = NEW.operation_id)
            BEGIN SELECT RAISE(ABORT, 'posted entries are immutable'); END;
            """,
            "CREATE TABLE IF NOT EXISTS flow_templates (id TEXT PRIMARY KEY, payload TEXT NOT NULL);",
            "CREATE TABLE IF NOT EXISTS flow_reconciliations (id TEXT PRIMARY KEY, account_id TEXT NOT NULL REFERENCES accounts(id), month TEXT NOT NULL, payload TEXT NOT NULL);",
            "CREATE TABLE IF NOT EXISTS flow_fx (from_currency TEXT NOT NULL, to_currency TEXT NOT NULL, date TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(from_currency, to_currency, date));"
            ,"CREATE TABLE IF NOT EXISTS flow_valuations (operation_id TEXT NOT NULL REFERENCES flow_operations(id), currency TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(operation_id, currency));"
        ]
        for sql in statements { try db.execute(sql) }
        for table in ["flow_operations", "ledger_entries", "ledger_seals", "flow_reconciliations", "flow_valuations"] {
            for action in ["UPDATE", "DELETE"] {
                try db.execute("CREATE TRIGGER IF NOT EXISTS immutable_\(table)_\(action) BEFORE \(action) ON \(table) BEGIN SELECT RAISE(ABORT, 'financial records are immutable'); END;")
            }
        }
        try seedCategories(db)
        for id in ["equity", "fx"] { try db.execute("INSERT OR IGNORE INTO ledger_accounts VALUES (?, NULL, NULL);", params: [.text(id)]) }
        // Import the last known legacy balance as equity, never as Cashflow income.
        for row in try db.query("SELECT * FROM accounts;") {
            guard let account = AccountService.rowToAccount(row) else { throw FlowError.corruptData }
            let existing = try db.query("SELECT id FROM ledger_accounts WHERE account_id = ?;", params: [.text(account.id)])
            if existing.isEmpty {
                let last = try db.query("SELECT recorded_at FROM balance_history WHERE account_id = ? ORDER BY recorded_at DESC, rowid DESC LIMIT 1;", params: [.text(account.id)]).first?.string("recorded_at")
                let baselineDate = last.flatMap { ISO8601DateFormatter().date(from: $0) } ?? account.balanceDate
                try CashflowService(db: db).opening(accountID: account.id, amount: account.openingBalance,
                    currency: account.currency, date: FlowDate.key(baselineDate))
            }
        }
    }

    static func json<T: Encodable>(_ value: T) throws -> String { String(decoding: try JSONEncoder().encode(value), as: UTF8.self) }

    static func seedCategories(_ db: DatabaseConnection) throws {
        for category in categories {
            try db.execute("INSERT OR IGNORE INTO flow_categories VALUES (?, ?, ?);", params: [.text(category.id), .text(category.kind.rawValue), .text(try json(category))])
            try db.execute("INSERT OR IGNORE INTO ledger_accounts VALUES (?, NULL, ?);", params: [.text("category:" + category.id), .text(category.id)])
        }
    }

    static let categories = [
        FlowCategory(id: "other-income", kind: .income, name: "Прочие доходы", englishName: "Other Income"),
        FlowCategory(id: "salary", kind: .income, name: "Зарплата", englishName: "Salary"),
        FlowCategory(id: "rent", kind: .income, name: "Аренда", englishName: "Rent"),
        FlowCategory(id: "freelance", kind: .income, name: "Фриланс", englishName: "Freelance"),
        FlowCategory(id: "business", kind: .income, name: "Бизнес", englishName: "Business"),
        FlowCategory(id: "bonuses", kind: .income, name: "Премии", englishName: "Bonuses"),
        FlowCategory(id: "dividends", kind: .income, name: "Дивиденды", englishName: "Dividends"),
        FlowCategory(id: "interest", kind: .income, name: "Проценты по вкладам", englishName: "Interest"),
        FlowCategory(id: "gifts", kind: .income, name: "Подарки", englishName: "Gifts"),
        FlowCategory(id: "refunds", kind: .income, name: "Возвраты и кешбэк", englishName: "Refunds & Cashback"),
        FlowCategory(id: "other-expense", kind: .expense, name: "Прочие расходы", englishName: "Other Expense"),
        FlowCategory(id: "utilities", kind: .expense, name: "Коммунальные услуги", englishName: "Utilities"),
        FlowCategory(id: "groceries", kind: .expense, name: "Продукты", englishName: "Groceries"),
        FlowCategory(id: "transport", kind: .expense, name: "Транспорт", englishName: "Transport"),
        FlowCategory(id: "subscriptions", kind: .expense, name: "Подписки", englishName: "Subscriptions"),
        FlowCategory(id: "travel", kind: .expense, name: "Путешествия", englishName: "Travel"),
        FlowCategory(id: "housing", kind: .expense, name: "Жильё и аренда", englishName: "Housing & Rent"),
        FlowCategory(id: "dining", kind: .expense, name: "Кафе и рестораны", englishName: "Dining"),
        FlowCategory(id: "health", kind: .expense, name: "Здоровье", englishName: "Health"),
        FlowCategory(id: "shopping", kind: .expense, name: "Покупки", englishName: "Shopping")
    ]
}

extension Dictionary where Key == String, Value == SQLValue {
    func string(_ key: String) -> String? { if case .text(let value)? = self[key] { return value }; return nil }
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        guard let payload = string("payload") else { throw FlowError.corruptData }
        return try JSONDecoder().decode(type, from: Data(payload.utf8))
    }
}
