import Foundation

final class DashboardService {
    private let connection: DatabaseConnection
    private let accountService: AccountService
    private let exchangeRateProvider: ExchangeRateProviding

    init(connection: DatabaseConnection, accountService: AccountService, exchangeRateProvider: ExchangeRateProviding) {
        self.connection = connection
        self.accountService = accountService
        self.exchangeRateProvider = exchangeRateProvider
    }

    func totalBalance(displayCurrency: Currency) -> Decimal {
        let total = accountService.listAccounts(includeArchived: false).reduce(Decimal(0)) { total, account in
            total + account.openingBalance * exchangeRateProvider.rate(from: account.currency, to: displayCurrency)
        }
        // Division-based rates (e.g. converting KZT -> USD via 1/460.5) don't
        // terminate exactly in base-10, so the raw sum can differ from the
        // "obvious" answer by a residue far past the 8th decimal place --
        // rounding here matches the 8-decimal-place precision already used
        // for stored money amounts everywhere else in this app.
        var rounded = Decimal()
        var value = total
        NSDecimalRound(&rounded, &value, 8, .plain)
        return rounded
    }

    func baseCurrency() -> Currency {
        let rows = (try? connection.query("SELECT value FROM profile_settings WHERE key = 'baseCurrency';")) ?? []
        guard case let .text(raw)? = rows.first?["value"], let currency = Currency(rawValue: raw) else {
            return .usd
        }
        return currency
    }

    func setBaseCurrency(_ currency: Currency) throws {
        try connection.execute(
            "INSERT INTO profile_settings (key, value) VALUES ('baseCurrency', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
            params: [.text(currency.rawValue)]
        )
    }
}
