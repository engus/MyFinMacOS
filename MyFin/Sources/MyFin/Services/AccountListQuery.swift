import Foundation

enum AccountListSort: CaseIterable {
    case name, balanceDescending, balanceAscending
}

struct AccountListSection: Identifiable {
    let id: String
    let label: String
    let accounts: [Account]
    let total: Decimal
}

/// The account table applies all filters before grouping and computing subtotals.
struct AccountListQuery {
    var archived = false
    var type: AccountType?
    var search = ""
    var sort: AccountListSort = .balanceDescending

    func matching(_ accounts: [Account], institutionNames: [String: String], baseCurrency: Currency) -> [Account] {
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return accounts.filter { account in
            guard account.archived == archived, type == nil || account.type == type else { return false }
            let searchable = [account.name, institutionNames[account.institutionId ?? ""] ?? "",
                              account.country.rawValue, account.country.displayName, account.currency.rawValue,
                              account.type.displayName, Localization.string(account.type.labelKey, language: .ru)]
            return needle.isEmpty || searchable.contains { $0.localizedStandardContains(needle) }
        }.sorted { lhs, rhs in
            if sort != .name {
                let left = Self.convertedBalance(lhs, to: baseCurrency)
                let right = Self.convertedBalance(rhs, to: baseCurrency)
                if left != right { return sort == .balanceDescending ? left > right : left < right }
            }
            let comparison = lhs.name.localizedStandardCompare(rhs.name)
            return comparison == .orderedSame ? lhs.id < rhs.id : comparison == .orderedAscending
        }
    }

    func sections(_ accounts: [Account], institutionNames: [String: String], grouping: SidebarGroupingMode,
                  baseCurrency: Currency, language: AppLanguage = .en) -> [AccountListSection] {
        let visible = matching(accounts, institutionNames: institutionNames, baseCurrency: baseCurrency)
        let groups = Dictionary(grouping: visible) { account -> String in
            switch grouping {
            case .country: return account.country.rawValue
            case .currency: return account.currency.rawValue
            case .type: return account.type.rawValue
            case .institution: return account.type == .cash ? "__cash__" : (account.institutionId ?? "__cash__")
            }
        }
        return groups.map { key, values in
            let label: String
            switch grouping {
            case .country, .currency: label = key
            case .type: label = AccountType(rawValue: key).map { Localization.string($0.labelKey, language: language) } ?? key
            case .institution: label = key == "__cash__" ? Localization.string(.cashFieldLabel, language: language) : (institutionNames[key] ?? key)
            }
            return AccountListSection(id: key, label: label, accounts: values, total: Self.total(values, in: baseCurrency))
        }.sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    static func convertedBalance(_ account: Account, to currency: Currency) -> Decimal {
        account.openingBalance * HardcodedExchangeRateProvider().rate(from: account.currency, to: currency)
    }

    static func total(_ accounts: [Account], in currency: Currency) -> Decimal {
        var sum = accounts.reduce(Decimal(0)) { $0 + convertedBalance($1, to: currency) }
        var rounded = Decimal()
        NSDecimalRound(&rounded, &sum, 8, .plain)
        return rounded
    }
}

extension AccountType {
    var labelKey: L10nKey {
        switch self {
        case .cash: return .cashFieldLabel
        case .debitCard: return .debitCardType
        case .deposit: return .depositType
        case .bankAccount: return .bankAccountType
        }
    }

    var symbolName: String {
        switch self {
        case .cash: return "banknote"
        case .debitCard: return "creditcard"
        case .deposit: return "lock.shield"
        case .bankAccount: return "building.columns"
        }
    }
}

extension SidebarGroupingMode {
    var labelKey: L10nKey {
        switch self {
        case .country: return .groupByCountryLabel
        case .currency: return .groupByCurrencyLabel
        case .type: return .groupByTypeLabel
        case .institution: return .groupByInstitutionLabel
        }
    }
}
