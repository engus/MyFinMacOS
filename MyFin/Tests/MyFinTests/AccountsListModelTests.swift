import XCTest
@testable import MyFin

private struct StubAuthenticator: BiometricAuthenticating {
    let result: Bool
    func authenticate(reason: String) async -> Bool { result }
}

@MainActor
final class AccountsListModelTests: XCTestCase {
    var tempDirectory: URL!
    var session: AppSession!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyFinAccountsListModelTests-\(UUID().uuidString)", isDirectory: true)
        let store = ProfileStore(baseDirectory: tempDirectory)
        let keychain = KeychainService(service: "com.myfin.local.tests.accountslistmodel")
        session = AppSession(profileStore: store, keychain: keychain, authenticator: StubAuthenticator(result: true))
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    @discardableResult
    private func createAccount(named name: String) -> Account {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        let result = accounts.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .usd, openingBalance: 100, name: name, balanceDate: nil
        )
        guard case .success(let account) = result else { fatalError("expected success creating test account") }
        return account
    }

    func test_reload_populatesAccountsFromService() {
        let model = AccountsListModel(session: session)
        createAccount(named: "Cash A")

        model.reload()

        XCTAssertEqual(model.accounts.map(\.name), ["Cash A"])
    }

    func test_activeAccounts_excludesArchivedAccounts() {
        let model = AccountsListModel(session: session)
        let toArchive = createAccount(named: "Cash A")
        createAccount(named: "Cash B")
        model.reload()

        model.archive(toArchive)

        XCTAssertEqual(model.accounts.count, 2, "archive() should reload, keeping both accounts in the full list")
        XCTAssertEqual(model.activeAccounts.map(\.name), ["Cash B"])
    }

    func test_restore_movesAccountBackIntoActiveAccounts() {
        let model = AccountsListModel(session: session)
        let account = createAccount(named: "Cash A")
        model.archive(account)

        model.restore(account)

        XCTAssertEqual(model.activeAccounts.map(\.name), ["Cash A"])
    }

    func test_groupedByInstitution_sumsAccountsAtSameInstitution() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        _ = accounts.createAccount(country: .kz, type: .bankAccount, institutionSelection: .existing(id: "kz.halyk-bank"), currency: .usd, openingBalance: 100, name: "A", balanceDate: nil)
        _ = accounts.createAccount(country: .kz, type: .bankAccount, institutionSelection: .existing(id: "kz.halyk-bank"), currency: .usd, openingBalance: 50, name: "B", balanceDate: nil)

        let model = AccountsListModel(session: session)
        model.reload()

        let groups = model.groupedByInstitution(baseCurrency: .usd)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.id, "kz.halyk-bank")
        XCTAssertEqual(groups.first?.label, "Halyk Bank")
        XCTAssertEqual(groups.first?.total, 150)
    }

    func test_groupedByInstitution_separatesDifferentInstitutions() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        _ = accounts.createAccount(country: .kz, type: .bankAccount, institutionSelection: .existing(id: "kz.halyk-bank"), currency: .usd, openingBalance: 100, name: "A", balanceDate: nil)
        _ = accounts.createAccount(country: .kz, type: .bankAccount, institutionSelection: .existing(id: "kz.kaspi-bank"), currency: .usd, openingBalance: 50, name: "B", balanceDate: nil)

        let model = AccountsListModel(session: session)
        model.reload()

        let groups = model.groupedByInstitution(baseCurrency: .usd)

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(Set(groups.map(\.id)), ["kz.halyk-bank", "kz.kaspi-bank"])
    }

    func test_groupedByInstitution_cashAccountsFormSeparateGroup() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 100, name: "Cash", balanceDate: nil)
        _ = accounts.createAccount(country: .kz, type: .bankAccount, institutionSelection: .existing(id: "kz.halyk-bank"), currency: .usd, openingBalance: 50, name: "Bank", balanceDate: nil)

        let model = AccountsListModel(session: session)
        model.reload()

        let groups = model.groupedByInstitution(baseCurrency: .usd)

        XCTAssertEqual(groups.count, 2)
        XCTAssertTrue(groups.contains { $0.id == AccountsListModel.cashGroupID && $0.total == 100 })
        XCTAssertTrue(groups.contains { $0.id == "kz.halyk-bank" && $0.total == 50 })
    }

    func test_groupedByInstitution_convertsToBaseCurrency() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        _ = accounts.createAccount(country: .kz, type: .bankAccount, institutionSelection: .existing(id: "kz.halyk-bank"), currency: .kzt, openingBalance: Decimal(string: "460.5")!, name: "A", balanceDate: nil)

        let model = AccountsListModel(session: session)
        model.reload()

        let groups = model.groupedByInstitution(baseCurrency: .usd)

        XCTAssertEqual(groups.first?.total, 1)
    }

    func test_groupedByInstitution_excludesArchivedAccounts() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        guard case .success(let account) = accounts.createAccount(country: .kz, type: .bankAccount, institutionSelection: .existing(id: "kz.halyk-bank"), currency: .usd, openingBalance: 100, name: "A", balanceDate: nil) else {
            return XCTFail("expected success")
        }

        let model = AccountsListModel(session: session)
        model.reload()
        model.archive(account)

        let groups = model.groupedByInstitution(baseCurrency: .usd)

        XCTAssertTrue(groups.isEmpty)
    }

    func test_groupedByCurrency_sumsAccountsInSameCurrencyWithoutConversion() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 100, name: "A", balanceDate: nil)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 50, name: "B", balanceDate: nil)

        let model = AccountsListModel(session: session)
        model.reload()

        let groups = model.groupedByCurrency()

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.id, "USD")
        XCTAssertEqual(groups.first?.total, 150)
        XCTAssertEqual(groups.first?.displayCurrency, .usd)
    }

    func test_groupedByCurrency_separatesDifferentCurrencies() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 100, name: "A", balanceDate: nil)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .kzt, openingBalance: 200, name: "B", balanceDate: nil)

        let model = AccountsListModel(session: session)
        model.reload()

        let groups = model.groupedByCurrency()

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(Set(groups.map(\.id)), ["USD", "KZT"])
        XCTAssertTrue(groups.contains { $0.id == "KZT" && $0.total == 200 && $0.displayCurrency == .kzt })
    }

    func test_groupedByCountry_sumsAndConvertsToBaseCurrency() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 1, name: "A", balanceDate: nil)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .kzt, openingBalance: Decimal(string: "460.5")!, name: "B", balanceDate: nil)

        let model = AccountsListModel(session: session)
        model.reload()

        let groups = model.groupedByCountry(baseCurrency: .usd)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.id, "KZ")
        XCTAssertEqual(groups.first?.label, "🇰🇿 Kazakhstan")
        XCTAssertEqual(groups.first?.total, 2)
        XCTAssertEqual(groups.first?.displayCurrency, .usd)
    }

    func test_groupedByCountry_separatesDifferentCountries() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 100, name: "A", balanceDate: nil)
        _ = accounts.createAccount(country: .ae, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 50, name: "B", balanceDate: nil)

        let model = AccountsListModel(session: session)
        model.reload()

        let groups = model.groupedByCountry(baseCurrency: .usd)

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(Set(groups.map(\.id)), ["KZ", "AE"])
    }

    func test_groupedByType_sumsAndSeparatesDifferentTypes() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 100, name: "A", balanceDate: nil)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 50, name: "B", balanceDate: nil)
        _ = accounts.createAccount(country: .kz, type: .bankAccount, institutionSelection: .existing(id: "kz.halyk-bank"), currency: .usd, openingBalance: 200, name: "C", balanceDate: nil)

        let model = AccountsListModel(session: session)
        model.reload()

        let groups = model.groupedByType(baseCurrency: .usd)

        XCTAssertEqual(groups.count, 2)
        XCTAssertTrue(groups.contains { $0.id == "cash" && $0.label == "Cash" && $0.total == 150 })
        XCTAssertTrue(groups.contains { $0.id == "bank_account" && $0.label == "Bank account" && $0.total == 200 })
    }

    func test_groupedByType_convertsToBaseCurrency() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        _ = accounts.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .kzt, openingBalance: Decimal(string: "460.5")!, name: "A", balanceDate: nil)

        let model = AccountsListModel(session: session)
        model.reload()

        let groups = model.groupedByType(baseCurrency: .usd)

        XCTAssertEqual(groups.first?.total, 1)
        XCTAssertEqual(groups.first?.displayCurrency, .usd)
    }

    func test_grouped_dispatchesToTheCorrectMethodPerMode() {
        let institutions = InstitutionService(connection: session.connection!)
        let accounts = AccountService(connection: session.connection!, institutionService: institutions)
        _ = accounts.createAccount(country: .kz, type: .bankAccount, institutionSelection: .existing(id: "kz.halyk-bank"), currency: .usd, openingBalance: 100, name: "A", balanceDate: nil)

        let model = AccountsListModel(session: session)
        model.reload()

        XCTAssertEqual(model.grouped(by: .institution, baseCurrency: .usd), model.groupedByInstitution(baseCurrency: .usd))
        XCTAssertEqual(model.grouped(by: .currency, baseCurrency: .usd), model.groupedByCurrency())
        XCTAssertEqual(model.grouped(by: .country, baseCurrency: .usd), model.groupedByCountry(baseCurrency: .usd))
        XCTAssertEqual(model.grouped(by: .type, baseCurrency: .usd), model.groupedByType(baseCurrency: .usd))
    }
}
