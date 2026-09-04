import Foundation

enum SidebarGroupingMode: String, CaseIterable, Equatable {
    case institution
    case currency
    case country
    case type
}

struct AccountGroup: Identifiable, Equatable {
    let id: String
    let label: String
    let total: Decimal
    let displayCurrency: Currency
}

@MainActor
final class AccountsListModel: ObservableObject {
    @Published private(set) var accounts: [Account] = []

    private weak var session: AppSession?

    init(session: AppSession) {
        self.session = session
    }

    var activeAccounts: [Account] {
        accounts.filter { !$0.archived }
    }

    private var accountService: AccountService? {
        guard let connection = session?.connection else { return nil }
        return AccountService(connection: connection, institutionService: InstitutionService(connection: connection))
    }

    func reload() {
        accounts = accountService?.listAccounts(includeArchived: true) ?? []
    }

    func archive(_ account: Account) {
        _ = accountService?.archiveAccount(id: account.id)
        reload()
    }

    func restore(_ account: Account) {
        _ = accountService?.restoreAccount(id: account.id)
        reload()
    }

    static let cashGroupID = "__cash__"
    static let cashIconName = "banknote.fill"
    static let cashIconColor = "green"

    func groupedByInstitution(baseCurrency: Currency) -> [AccountGroup] {
        let exchangeRateProvider = HardcodedExchangeRateProvider()
        var totalsByKey: [String: Decimal] = [:]
        var labelsByKey: [String: String] = [:]
        var order: [String] = []

        for account in activeAccounts {
            let key: String
            let label: String
            if account.type == .cash || account.institutionId == nil {
                key = Self.cashGroupID
                label = ""
            } else {
                key = account.institutionId!
                label = institutionName(id: key) ?? key
            }

            let converted = account.openingBalance * exchangeRateProvider.rate(from: account.currency, to: baseCurrency)
            totalsByKey[key, default: 0] += converted
            if labelsByKey[key] == nil {
                labelsByKey[key] = label
                order.append(key)
            }
        }

        return order.map { key in
            var rounded = Decimal()
            var value = totalsByKey[key] ?? 0
            NSDecimalRound(&rounded, &value, 8, .plain)
            return AccountGroup(id: key, label: labelsByKey[key] ?? "", total: rounded, displayCurrency: baseCurrency)
        }
    }

    func groupedByCurrency() -> [AccountGroup] {
        var totalsByKey: [String: Decimal] = [:]
        var order: [String] = []

        for account in activeAccounts {
            let key = account.currency.rawValue
            totalsByKey[key, default: 0] += account.openingBalance
            if !order.contains(key) {
                order.append(key)
            }
        }

        return order.map { key in
            var rounded = Decimal()
            var value = totalsByKey[key] ?? 0
            NSDecimalRound(&rounded, &value, 8, .plain)
            return AccountGroup(id: key, label: key, total: rounded, displayCurrency: Currency(rawValue: key) ?? .usd)
        }
    }

    func groupedByCountry(baseCurrency: Currency) -> [AccountGroup] {
        let exchangeRateProvider = HardcodedExchangeRateProvider()
        var totalsByKey: [String: Decimal] = [:]
        var labelsByKey: [String: String] = [:]
        var order: [String] = []

        for account in activeAccounts {
            let key = account.country.rawValue
            let converted = account.openingBalance * exchangeRateProvider.rate(from: account.currency, to: baseCurrency)
            totalsByKey[key, default: 0] += converted
            if labelsByKey[key] == nil {
                labelsByKey[key] = "\(account.country.flag) \(account.country.displayName)"
                order.append(key)
            }
        }

        return order.map { key in
            var rounded = Decimal()
            var value = totalsByKey[key] ?? 0
            NSDecimalRound(&rounded, &value, 8, .plain)
            return AccountGroup(id: key, label: labelsByKey[key] ?? key, total: rounded, displayCurrency: baseCurrency)
        }
    }

    func groupedByType(baseCurrency: Currency) -> [AccountGroup] {
        let exchangeRateProvider = HardcodedExchangeRateProvider()
        var totalsByKey: [String: Decimal] = [:]
        var labelsByKey: [String: String] = [:]
        var order: [String] = []

        for account in activeAccounts {
            let key = account.type.rawValue
            let converted = account.openingBalance * exchangeRateProvider.rate(from: account.currency, to: baseCurrency)
            totalsByKey[key, default: 0] += converted
            if labelsByKey[key] == nil {
                labelsByKey[key] = account.type.displayName
                order.append(key)
            }
        }

        return order.map { key in
            var rounded = Decimal()
            var value = totalsByKey[key] ?? 0
            NSDecimalRound(&rounded, &value, 8, .plain)
            return AccountGroup(id: key, label: labelsByKey[key] ?? key, total: rounded, displayCurrency: baseCurrency)
        }
    }

    func grouped(by mode: SidebarGroupingMode, baseCurrency: Currency) -> [AccountGroup] {
        switch mode {
        case .institution: return groupedByInstitution(baseCurrency: baseCurrency)
        case .currency: return groupedByCurrency()
        case .country: return groupedByCountry(baseCurrency: baseCurrency)
        case .type: return groupedByType(baseCurrency: baseCurrency)
        }
    }

    private func institutionName(id: String) -> String? {
        guard let connection = session?.connection else { return nil }
        let rows = (try? connection.query("SELECT name FROM institutions WHERE id = ?;", params: [.text(id)])) ?? []
        if case let .text(name)? = rows.first?["name"] {
            return name
        }
        return nil
    }
}
