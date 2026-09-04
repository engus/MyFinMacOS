import XCTest
@testable import MyFin

final class DashboardServiceTests: XCTestCase {
    private func makeServices() throws -> (DashboardService, AccountService, DatabaseConnection) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        let connection = try DatabaseConnection.open(at: url, password: "pw")
        let institutions = InstitutionService(connection: connection)
        let accounts = AccountService(connection: connection, institutionService: institutions)
        let dashboard = DashboardService(connection: connection, accountService: accounts, exchangeRateProvider: HardcodedExchangeRateProvider())
        return (dashboard, accounts, connection)
    }

    func test_totalBalance_sumsSingleCurrencyAccounts() throws {
        let (dashboard, accounts, _) = try makeServices()
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 100, name: "A", balanceDate: nil)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 50, name: "B", balanceDate: nil)
        XCTAssertEqual(dashboard.totalBalance(displayCurrency: .usd), 150)
    }

    func test_totalBalance_convertsMixedCurrencies() throws {
        let (dashboard, accounts, _) = try makeServices()
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 1, name: "A", balanceDate: nil)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .kzt, openingBalance: Decimal(string: "460.5")!, name: "B", balanceDate: nil)
        XCTAssertEqual(dashboard.totalBalance(displayCurrency: .usd), 2)
    }

    func test_totalBalance_excludesArchivedAccounts() throws {
        let (dashboard, accounts, _) = try makeServices()
        guard case .success(let account) = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 100, name: "A", balanceDate: nil) else {
            return XCTFail("expected success")
        }
        _ = accounts.archiveAccount(id: account.id)
        XCTAssertEqual(dashboard.totalBalance(displayCurrency: .usd), 0)
    }

    func test_baseCurrency_defaultsToUSD() throws {
        let (dashboard, _, _) = try makeServices()
        XCTAssertEqual(dashboard.baseCurrency(), .usd)
    }

    func test_setBaseCurrency_persistsAndIsReadableAfter() throws {
        let (dashboard, _, _) = try makeServices()
        try dashboard.setBaseCurrency(.kzt)
        XCTAssertEqual(dashboard.baseCurrency(), .kzt)
    }
}
