import XCTest
@testable import MyFin

final class AccountServiceTests: XCTestCase {
    private func makeServices() throws -> (AccountService, InstitutionService, DatabaseConnection) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        let connection = try DatabaseConnection.open(at: url, password: "pw")
        let institutions = InstitutionService(connection: connection)
        let accounts = AccountService(connection: connection, institutionService: institutions)
        return (accounts, institutions, connection)
    }

    func test_createAccount_debitCard_withExistingInstitution_succeeds() throws {
        let (service, _, _) = try makeServices()
        let result = service.createAccount(
            country: .kz, type: .debitCard, institutionSelection: .existing(id: "kz.halyk-bank"),
            currency: .usd, openingBalance: 100, name: "", balanceDate: nil
        )
        guard case .success(let account) = result else { return XCTFail("expected success") }
        XCTAssertEqual(account.institutionId, "kz.halyk-bank")
        XCTAssertEqual(account.name, "Halyk Bank · Debit card")
    }

    func test_createAccount_cash_storesNoInstitutionAndAutoGeneratesName() throws {
        let (service, _, _) = try makeServices()
        let result = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .kzt, openingBalance: 0, name: "", balanceDate: nil
        )
        guard case .success(let account) = result else { return XCTFail("expected success") }
        XCTAssertNil(account.institutionId)
        XCTAssertEqual(account.name, "Cash · Kazakhstan")
    }

    func test_createAccount_nonCashType_withoutInstitution_fails() throws {
        let (service, _, _) = try makeServices()
        let result = service.createAccount(
            country: .kz, type: .bankAccount, institutionSelection: .none,
            currency: .usd, openingBalance: 0, name: "", balanceDate: nil
        )
        XCTAssertEqual(result, .failure(.institutionRequired))
    }

    func test_createAccount_negativeBalance_fails() throws {
        let (service, _, _) = try makeServices()
        let result = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .usd, openingBalance: -1, name: "", balanceDate: nil
        )
        XCTAssertEqual(result, .failure(.negativeBalance))
    }

    func test_createAccount_tooManyDecimalDigits_fails() throws {
        let (service, _, _) = try makeServices()
        let overPrecise = Decimal(string: "1.123456789")!
        let result = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .usd, openingBalance: overPrecise, name: "", balanceDate: nil
        )
        XCTAssertEqual(result, .failure(.tooManyDecimalDigits))
    }

    func test_createAccount_positiveBalance_createsOneOpeningBalanceTransaction() throws {
        let (service, _, connection) = try makeServices()
        guard case .success(let account) = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .usd, openingBalance: 50, name: "", balanceDate: nil
        ) else { return XCTFail("expected success") }
        let rows = try connection.query("SELECT * FROM transactions WHERE account_id = ?;", params: [.text(account.id)])
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0]["kind"], .text("opening_balance"))
    }

    func test_createAccount_zeroBalance_createsNoTransaction() throws {
        let (service, _, connection) = try makeServices()
        guard case .success(let account) = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .usd, openingBalance: 0, name: "", balanceDate: nil
        ) else { return XCTFail("expected success") }
        let rows = try connection.query("SELECT * FROM transactions WHERE account_id = ?;", params: [.text(account.id)])
        XCTAssertEqual(rows.count, 0)
    }

    func test_createAccount_withOtherBank_resolvesOrCreatesCustomInstitutionAtomically() throws {
        let (service, institutions, _) = try makeServices()
        let result = service.createAccount(
            country: .kz, type: .bankAccount, institutionSelection: .newCustom(name: "My New Bank"),
            currency: .usd, openingBalance: 0, name: "", balanceDate: nil
        )
        guard case .success(let account) = result else { return XCTFail("expected success") }
        XCTAssertNotNil(account.institutionId)
        let list = try institutions.listInstitutions(country: .kz)
        XCTAssertTrue(list.contains { if case .institution(let i) = $0 { return i.id == account.institutionId }; return false })
    }

    func test_createAccount_explicitName_isNotOverwritten() throws {
        let (service, _, _) = try makeServices()
        let result = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .usd, openingBalance: 0, name: "My Wallet", balanceDate: nil
        )
        guard case .success(let account) = result else { return XCTFail("expected success") }
        XCTAssertEqual(account.name, "My Wallet")
    }

    func test_createAccount_omittedBalanceDate_defaultsToToday() throws {
        let (service, _, _) = try makeServices()
        let result = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .usd, openingBalance: 0, name: "", balanceDate: nil
        )
        guard case .success(let account) = result else { return XCTFail("expected success") }
        XCTAssertTrue(Calendar.current.isDateInToday(account.balanceDate))
    }

    func test_listAccounts_excludesArchivedByDefault() throws {
        let (service, _, _) = try makeServices()
        guard case .success(let account) = service.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 0, name: "A", balanceDate: nil) else {
            return XCTFail("expected success")
        }
        _ = service.archiveAccount(id: account.id)
        XCTAssertEqual(service.listAccounts(includeArchived: false).count, 0)
        XCTAssertEqual(service.listAccounts(includeArchived: true).count, 1)
    }

    func test_archiveThenRestore_roundTrips() throws {
        let (service, _, _) = try makeServices()
        guard case .success(let account) = service.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 0, name: "A", balanceDate: nil) else {
            return XCTFail("expected success")
        }
        guard case .success(let archived) = service.archiveAccount(id: account.id) else { return XCTFail("expected success") }
        XCTAssertTrue(archived.archived)
        guard case .success(let restored) = service.restoreAccount(id: account.id) else { return XCTFail("expected success") }
        XCTAssertFalse(restored.archived)
    }

    func test_updateAccount_changesNameCountryAndInstitution() throws {
        let (service, _, _) = try makeServices()
        guard case .success(let account) = service.createAccount(
            country: .kz, type: .bankAccount, institutionSelection: .existing(id: "kz.halyk-bank"),
            currency: .usd, openingBalance: 0, name: "A", balanceDate: nil
        ) else { return XCTFail("expected success") }

        let result = service.updateAccount(
            id: account.id, name: "B", country: .ae, type: .bankAccount, currency: .usd,
            institutionSelection: .existing(id: "kz.kaspi-bank"), openingBalance: 0
        )
        guard case .success(let updated) = result else { return XCTFail("expected success") }
        XCTAssertEqual(updated.name, "B")
        XCTAssertEqual(updated.country, .ae)
        XCTAssertEqual(updated.institutionId, "kz.kaspi-bank")
    }

    func test_updateAccount_cashCountryChange_isJustAFieldUpdate() throws {
        let (service, _, _) = try makeServices()
        guard case .success(let account) = service.createAccount(country: .kz, type: .cash, institutionSelection: .none, currency: .usd, openingBalance: 0, name: "A", balanceDate: nil) else {
            return XCTFail("expected success")
        }
        let result = service.updateAccount(id: account.id, name: "A", country: .ae, type: .cash, currency: .usd, institutionSelection: .none, openingBalance: 0)
        guard case .success(let updated) = result else { return XCTFail("expected success") }
        XCTAssertEqual(updated.country, .ae)
        XCTAssertNil(updated.institutionId)
    }

    func test_updateAccount_changesOpeningBalance() throws {
        let (service, _, _) = try makeServices()
        guard case .success(let account) = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .usd, openingBalance: 100, name: "A", balanceDate: nil
        ) else { return XCTFail("expected success") }

        let result = service.updateAccount(
            id: account.id, name: "A", country: .kz, type: .cash, currency: .usd,
            institutionSelection: .none, openingBalance: 250
        )
        guard case .success(let updated) = result else { return XCTFail("expected success") }
        XCTAssertEqual(updated.openingBalance, 250)
    }

    func test_updateAccount_negativeBalance_fails() throws {
        let (service, _, _) = try makeServices()
        guard case .success(let account) = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .usd, openingBalance: 100, name: "A", balanceDate: nil
        ) else { return XCTFail("expected success") }

        let result = service.updateAccount(
            id: account.id, name: "A", country: .kz, type: .cash, currency: .usd,
            institutionSelection: .none, openingBalance: -1
        )
        XCTAssertEqual(result, .failure(.negativeBalance))
    }

    func test_createAccount_withPositiveOpeningBalance_writesInitialBalanceHistoryEntry() throws {
        let (service, _, _) = try makeServices()
        let result = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .kzt, openingBalance: 500, name: "", balanceDate: nil
        )
        guard case .success(let account) = result else { return XCTFail("expected success") }

        let history = service.balanceHistory(accountId: account.id)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].balance, 500)
    }

    func test_createAccount_withZeroOpeningBalance_stillWritesInitialBalanceHistoryEntry() throws {
        let (service, _, _) = try makeServices()
        let result = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .kzt, openingBalance: 0, name: "", balanceDate: nil
        )
        guard case .success(let account) = result else { return XCTFail("expected success") }

        let history = service.balanceHistory(accountId: account.id)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].balance, 0)
    }

    func test_updateAccount_withChangedOpeningBalance_appendsBalanceHistoryEntry() throws {
        let (service, _, _) = try makeServices()
        let created = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .kzt, openingBalance: 100, name: "My Cash", balanceDate: nil
        )
        guard case .success(let account) = created else { return XCTFail("expected success") }

        let updated = service.updateAccount(
            id: account.id, name: account.name, country: account.country, type: account.type,
            currency: account.currency, institutionSelection: .none, openingBalance: 300
        )
        guard case .success = updated else { return XCTFail("expected success") }

        let history = service.balanceHistory(accountId: account.id)
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].balance, 100)
        XCTAssertEqual(history[1].balance, 300)
    }

    func test_updateAccount_withUnchangedOpeningBalance_writesNoNewBalanceHistoryEntry() throws {
        let (service, _, _) = try makeServices()
        let created = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .kzt, openingBalance: 100, name: "My Cash", balanceDate: nil
        )
        guard case .success(let account) = created else { return XCTFail("expected success") }

        let updated = service.updateAccount(
            id: account.id, name: "Renamed Cash", country: account.country, type: account.type,
            currency: account.currency, institutionSelection: .none, openingBalance: 100
        )
        guard case .success = updated else { return XCTFail("expected success") }

        let history = service.balanceHistory(accountId: account.id)
        XCTAssertEqual(history.count, 1)
    }

    func test_balanceHistory_returnsEntriesOldestToNewest() throws {
        let (service, _, _) = try makeServices()
        let created = service.createAccount(
            country: .kz, type: .cash, institutionSelection: .none,
            currency: .kzt, openingBalance: 100, name: "My Cash", balanceDate: nil
        )
        guard case .success(let account) = created else { return XCTFail("expected success") }

        _ = service.updateAccount(
            id: account.id, name: account.name, country: account.country, type: account.type,
            currency: account.currency, institutionSelection: .none, openingBalance: 200
        )
        _ = service.updateAccount(
            id: account.id, name: account.name, country: account.country, type: account.type,
            currency: account.currency, institutionSelection: .none, openingBalance: 50
        )

        let history = service.balanceHistory(accountId: account.id)
        XCTAssertEqual(history.map(\.balance), [100, 200, 50])
    }
}
