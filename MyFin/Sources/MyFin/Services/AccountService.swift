import Foundation

final class AccountService {
    private let connection: DatabaseConnection
    private let institutionService: InstitutionService
    private let now: () -> Date

    init(connection: DatabaseConnection, institutionService: InstitutionService, now: @escaping () -> Date = Date.init) {
        self.connection = connection
        self.institutionService = institutionService
        self.now = now
    }

    func createAccount(
        country: Country, type: AccountType, institutionSelection: InstitutionSelection,
        currency: Currency, openingBalance: Decimal, name: String, balanceDate: Date?,
        appearance: AccountAppearance = AccountAppearance()
    ) -> Result<Account, AccountError> {
        do {
            return .success(try connection.withTransaction {
                try createAccountInTransaction(country: country, type: type, institutionSelection: institutionSelection,
                    currency: currency, openingBalance: openingBalance, name: name,
                    balanceDate: balanceDate, appearance: appearance).get()
            })
        } catch let error as AccountError { return .failure(error) }
        catch { return .failure(.notFound) }
    }

    private func createAccountInTransaction(
        country: Country,
        type: AccountType,
        institutionSelection: InstitutionSelection,
        currency: Currency,
        openingBalance: Decimal,
        name: String,
        balanceDate: Date?,
        appearance: AccountAppearance = AccountAppearance()
    ) -> Result<Account, AccountError> {
        guard openingBalance >= 0 else { return .failure(.negativeBalance) }
        guard Self.decimalPlaces(of: openingBalance) <= 8 else { return .failure(.tooManyDecimalDigits) }

        var institutionId: String?
        var institutionDisplayName = ""

        if type == .cash {
            institutionId = nil
        } else {
            switch institutionSelection {
            case .none:
                return .failure(.institutionRequired)
            case .existing(let id):
                institutionId = id
                let row = (try? connection.query("SELECT * FROM institutions WHERE id = ?;", params: [.text(id)]))?.first
                institutionDisplayName = row.flatMap(InstitutionService.rowToInstitution)?.name ?? ""
            case .newCustom(let customName):
                switch institutionService.resolveOrCreateCustomInstitution(name: customName, country: country) {
                case .failure(let error): return .failure(.institutionError(error))
                case .success(let institution):
                    institutionId = institution.id
                    institutionDisplayName = institution.name
                }
            }
        }

        let resolvedDate = balanceDate ?? now()
        let id = UUID().uuidString
        let nowString = ISO8601DateFormatter().string(from: now())
        let dateFormatter = ISO8601DateFormatter()
        let balanceDateString = dateFormatter.string(from: resolvedDate)

        let finalName: String
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            finalName = name
        } else if type == .cash {
            finalName = "Cash · \(country.displayName)"
        } else {
            finalName = "\(institutionDisplayName) · \(type.displayName)"
        }

        do {
            do {
                try connection.execute(
                    """
                    INSERT INTO accounts (id, name, country, type, currency, opening_balance, balance_date, institution_id, archived, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?);
                    """,
                    params: [
                        .text(id), .text(finalName), .text(country.rawValue), .text(type.rawValue), .text(currency.rawValue),
                        .text(Self.decimalString(openingBalance)), .text(balanceDateString),
                        institutionId.map(SQLValue.text) ?? .null, .text(nowString), .text(nowString)
                    ]
                )
                if openingBalance > 0 {
                    try connection.execute(
                        "INSERT INTO transactions (id, account_id, amount, date, kind, created_at) VALUES (?, ?, ?, ?, 'opening_balance', ?);",
                        params: [.text(UUID().uuidString), .text(id), .text(Self.decimalString(openingBalance)), .text(balanceDateString), .text(nowString)]
                    )
                }
                try insertAppearance(appearance.sanitized(for: type), accountId: id)
                try CashflowService(db: connection, now: now).opening(accountID: id, amount: openingBalance,
                    currency: currency, date: FlowDate.key(resolvedDate))
                try connection.execute(
                    "INSERT INTO balance_history (id, account_id, balance, recorded_at, currency) VALUES (?, ?, ?, ?, ?);",
                    params: [.text(UUID().uuidString), .text(id), .text(Self.decimalString(openingBalance)), .text(nowString), .text(currency.rawValue)]
                )
            }
        } catch {
            return .failure(.notFound)
        }

        return .success(Account(
            id: id, name: finalName, country: country, type: type, currency: currency,
            openingBalance: openingBalance, balanceDate: resolvedDate, institutionId: institutionId,
            archived: false, createdAt: now(), updatedAt: now(), appearance: appearance.sanitized(for: type)
        ))
    }

    static func decimalString(_ value: Decimal) -> String {
        var value = value
        var result = Decimal()
        NSDecimalRound(&result, &value, 8, .plain)
        return "\(result)"
    }

    private func insertAppearance(_ value: AccountAppearance, accountId: String) throws {
        func text(_ value: String?) -> SQLValue { value.map(SQLValue.text) ?? .null }
        let tags = String(data: try JSONEncoder().encode(value.tags), encoding: .utf8) ?? "[]"
        try connection.execute("""
            INSERT INTO account_appearances
            (account_id, theme_preset, accent_tint, badge_icon, tags_json, payment_network)
            VALUES (?, ?, ?, ?, ?, ?);
            """, params: [.text(accountId), .text(value.themePreset.rawValue), .text(value.accentTint.rawValue),
                .text(value.badgeIcon.rawValue), .text(tags), text(value.paymentNetwork?.rawValue)])
    }

    private func fetchAppearance(accountId: String) -> AccountAppearance {
        guard let row = (try? connection.query("SELECT * FROM account_appearances WHERE account_id = ?;", params: [.text(accountId)]))?.first else { return AccountAppearance() }
        func text(_ key: String) -> String? { if case .text(let value)? = row[key] { return value }; return nil }
        var value = AccountAppearance()
        value.themePreset = text("theme_preset").flatMap(AccountThemePreset.init(rawValue:)) ?? .obsidianMatte
        value.accentTint = text("accent_tint").flatMap(AccountAccentTint.init(rawValue:)) ?? .blue
        value.badgeIcon = text("badge_icon").flatMap(AccountBadgeIcon.init(rawValue:)) ?? .card
        value.tags = text("tags_json").flatMap { $0.data(using: .utf8) }.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
        value.paymentNetwork = text("payment_network").map { PaymentNetwork(rawValue: $0) ?? .mastercard }
        return value
    }

    static func decimalPlaces(of value: Decimal) -> Int {
        max(0, -value.exponent)
    }
}

extension AccountService {
    func updateAccount(
        id: String, name: String, country: Country, type: AccountType, currency: Currency,
        institutionSelection: InstitutionSelection, openingBalance: Decimal
    ) -> Result<Account, AccountError> {
        guard let existingAccount = fetchAccount(id: id) else { return .failure(.notFound) }
        guard openingBalance >= 0 else { return .failure(.negativeBalance) }
        guard Self.decimalPlaces(of: openingBalance) <= 8 else { return .failure(.tooManyDecimalDigits) }

        if currency != existingAccount.currency {
            let ledger = CashflowService(db: connection, now: now)
            do {
                let linked = try connection.query("SELECT DISTINCT operation_id FROM ledger_entries WHERE ledger_account_id = ?;", params: [.text("account:" + id)]).compactMap { $0.string("operation_id") }
                if try ledger.operations().contains(where: { linked.contains($0.id) && $0.source != .opening }) ||
                    ledger.templates().contains(where: { $0.accountID == id }) ||
                    ledger.reconciliations().contains(where: { $0.accountID == id }) { return .failure(.currencyHasPostings) }
            } catch { return .failure(.notFound) }
        }

        var institutionId: String?
        if type != .cash {
            switch institutionSelection {
            case .none:
                return .failure(.institutionRequired)
            case .existing(let existingId):
                institutionId = existingId
            case .newCustom(let customName):
                switch institutionService.resolveOrCreateCustomInstitution(name: customName, country: country) {
                case .failure(let error): return .failure(.institutionError(error))
                case .success(let institution): institutionId = institution.id
                }
            }
        }

        let nowString = ISO8601DateFormatter().string(from: now())
        do {
            try connection.withTransaction {
                try connection.execute(
                    "UPDATE accounts SET name = ?, country = ?, type = ?, currency = ?, institution_id = ?, updated_at = ? WHERE id = ?;",
                    params: [
                        .text(name), .text(country.rawValue), .text(type.rawValue), .text(currency.rawValue),
                        institutionId.map(SQLValue.text) ?? .null, .text(nowString), .text(id)
                    ]
                )
                let ledger = CashflowService(db: connection, now: now)
                if currency != existingAccount.currency {
                    // Preserve both currency histories with explicit equity postings.
                    try ledger.opening(accountID: id, amount: -existingAccount.openingBalance, currency: existingAccount.currency, date: ledger.today)
                    try ledger.opening(accountID: id, amount: openingBalance, currency: currency, date: ledger.today)
                    try connection.execute(
                        "INSERT INTO balance_history (id, account_id, balance, recorded_at, currency) VALUES (?, ?, ?, ?, ?);",
                        params: [.text(UUID().uuidString), .text(id), .text(Self.decimalString(openingBalance)), .text(nowString), .text(currency.rawValue)]
                    )
                } else if openingBalance != existingAccount.openingBalance {
                    try ledger.adjustBalance(accountID: id, currency: currency, target: openingBalance)
                }
            }
        } catch {
            return .failure(.notFound)
        }
        guard let updated = fetchAccount(id: id) else { return .failure(.notFound) }
        return .success(updated)
    }

    func archiveAccount(id: String) -> Result<Account, AccountError> {
        setArchived(true, id: id)
    }

    func restoreAccount(id: String) -> Result<Account, AccountError> {
        setArchived(false, id: id)
    }

    private func setArchived(_ archived: Bool, id: String) -> Result<Account, AccountError> {
        guard fetchAccount(id: id) != nil else { return .failure(.notFound) }
        let nowString = ISO8601DateFormatter().string(from: now())
        _ = try? connection.execute(
            "UPDATE accounts SET archived = ?, updated_at = ? WHERE id = ?;",
            params: [.int(archived ? 1 : 0), .text(nowString), .text(id)]
        )
        guard let updated = fetchAccount(id: id) else { return .failure(.notFound) }
        return .success(updated)
    }

    func listAccounts(includeArchived: Bool) -> [Account] {
        let sql = includeArchived
            ? "SELECT * FROM accounts ORDER BY created_at ASC;"
            : "SELECT * FROM accounts WHERE archived = 0 ORDER BY created_at ASC;"
        let rows = (try? connection.query(sql)) ?? []
        return rows.compactMap(Self.rowToAccount).compactMap { account in
            var account = account
            account.appearance = fetchAppearance(accountId: account.id).sanitized(for: account.type)
            guard let balance = try? CashflowService(db: connection, now: now).balance(accountID: account.id, currency: account.currency) else { return nil }
            account.openingBalance = balance
            return account
        }
    }

    func balanceHistory(accountId: String) -> [BalanceHistoryEntry] {
        let rows = (try? connection.query(
            "SELECT * FROM balance_history WHERE account_id = ? ORDER BY recorded_at ASC, rowid ASC;",
            params: [.text(accountId)]
        )) ?? []
        return rows.compactMap(Self.rowToBalanceHistoryEntry)
    }

    static func rowToBalanceHistoryEntry(_ row: [String: SQLValue]) -> BalanceHistoryEntry? {
        guard case let .text(id)? = row["id"],
              case let .text(balanceRaw)? = row["balance"], let balance = Decimal(string: balanceRaw),
              case let .text(recordedAtRaw)? = row["recorded_at"]
        else { return nil }

        let recordedAt = ISO8601DateFormatter().date(from: recordedAtRaw) ?? Date()
        let currency: Currency?
        if case let .text(raw)? = row["currency"] { currency = Currency(rawValue: raw) } else { currency = nil }
        return BalanceHistoryEntry(id: id, balance: balance, recordedAt: recordedAt, currency: currency)
    }

    private func fetchAccount(id: String) -> Account? {
        guard let rows = try? connection.query("SELECT * FROM accounts WHERE id = ?;", params: [.text(id)]),
              let row = rows.first else { return nil }
        guard var account = Self.rowToAccount(row) else { return nil }
        account.appearance = fetchAppearance(accountId: id).sanitized(for: account.type)
        guard let balance = try? CashflowService(db: connection, now: now).balance(accountID: id, currency: account.currency) else { return nil }
        account.openingBalance = balance
        return account
    }

    static func rowToAccount(_ row: [String: SQLValue]) -> Account? {
        guard case let .text(id)? = row["id"],
              case let .text(name)? = row["name"],
              case let .text(countryRaw)? = row["country"], let country = Country(rawValue: countryRaw),
              case let .text(typeRaw)? = row["type"], let type = AccountType(rawValue: typeRaw),
              case let .text(currencyRaw)? = row["currency"], let currency = Currency(rawValue: currencyRaw),
              case let .text(openingBalanceRaw)? = row["opening_balance"], let openingBalance = Decimal(string: openingBalanceRaw),
              case let .text(balanceDateRaw)? = row["balance_date"],
              case let .int(archivedInt)? = row["archived"],
              case let .text(createdAtRaw)? = row["created_at"],
              case let .text(updatedAtRaw)? = row["updated_at"]
        else { return nil }

        let formatter = ISO8601DateFormatter()
        let balanceDate = formatter.date(from: balanceDateRaw) ?? Date()
        let createdAt = formatter.date(from: createdAtRaw) ?? Date()
        let updatedAt = formatter.date(from: updatedAtRaw) ?? Date()

        var institutionId: String?
        if case let .text(value)? = row["institution_id"] {
            institutionId = value
        }

        return Account(
            id: id, name: name, country: country, type: type, currency: currency,
            openingBalance: openingBalance, balanceDate: balanceDate, institutionId: institutionId,
            archived: archivedInt != 0, createdAt: createdAt, updatedAt: updatedAt
        )
    }
}
