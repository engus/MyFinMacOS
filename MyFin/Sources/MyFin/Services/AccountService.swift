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
        country: Country,
        type: AccountType,
        institutionSelection: InstitutionSelection,
        currency: Currency,
        openingBalance: Decimal,
        name: String,
        balanceDate: Date?
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
            try connection.withTransaction {
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
                try connection.execute(
                    "INSERT INTO balance_history (id, account_id, balance, recorded_at) VALUES (?, ?, ?, ?);",
                    params: [.text(UUID().uuidString), .text(id), .text(Self.decimalString(openingBalance)), .text(nowString)]
                )
            }
        } catch {
            return .failure(.notFound)
        }

        return .success(Account(
            id: id, name: finalName, country: country, type: type, currency: currency,
            openingBalance: openingBalance, balanceDate: resolvedDate, institutionId: institutionId,
            archived: false, createdAt: now(), updatedAt: now()
        ))
    }

    static func decimalString(_ value: Decimal) -> String {
        var value = value
        var result = Decimal()
        NSDecimalRound(&result, &value, 8, .plain)
        return "\(result)"
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
        _ = try? connection.execute(
            "UPDATE accounts SET name = ?, country = ?, type = ?, currency = ?, institution_id = ?, opening_balance = ?, updated_at = ? WHERE id = ?;",
            params: [
                .text(name), .text(country.rawValue), .text(type.rawValue), .text(currency.rawValue),
                institutionId.map(SQLValue.text) ?? .null, .text(Self.decimalString(openingBalance)), .text(nowString), .text(id)
            ]
        )
        if openingBalance != existingAccount.openingBalance {
            try? connection.execute(
                "INSERT INTO balance_history (id, account_id, balance, recorded_at) VALUES (?, ?, ?, ?);",
                params: [.text(UUID().uuidString), .text(id), .text(Self.decimalString(openingBalance)), .text(nowString)]
            )
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
        return rows.compactMap(Self.rowToAccount)
    }

    func balanceHistory(accountId: String) -> [BalanceHistoryEntry] {
        let rows = (try? connection.query(
            "SELECT * FROM balance_history WHERE account_id = ? ORDER BY recorded_at ASC;",
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
        return BalanceHistoryEntry(id: id, balance: balance, recordedAt: recordedAt)
    }

    private func fetchAccount(id: String) -> Account? {
        guard let rows = try? connection.query("SELECT * FROM accounts WHERE id = ?;", params: [.text(id)]),
              let row = rows.first else { return nil }
        return Self.rowToAccount(row)
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
