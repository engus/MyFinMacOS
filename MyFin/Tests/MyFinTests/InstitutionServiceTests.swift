import XCTest
@testable import MyFin

final class InstitutionServiceTests: XCTestCase {
    private func makeService() throws -> (InstitutionService, DatabaseConnection) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        let connection = try DatabaseConnection.open(at: url, password: "pw")
        return (InstitutionService(connection: connection), connection)
    }

    func test_listInstitutions_kz_includesSystemBanksAndEndsWithOtherBank() throws {
        let (service, _) = try makeService()
        let items = try service.listInstitutions(country: .kz)
        XCTAssertEqual(items.last, .otherBank)
        XCTAssertTrue(items.contains { if case .institution(let i) = $0 { return i.id == "kz.halyk-bank" }; return false })
    }

    func test_listInstitutions_us_doesNotIncludeKazakhstaniBanks() throws {
        let (service, _) = try makeService()
        let items = try service.listInstitutions(country: .us)
        XCTAssertFalse(items.contains { if case .institution(let i) = $0 { return i.id == "kz.halyk-bank" }; return false })
    }

    func test_search_matchesByNameCaseInsensitive() throws {
        let (service, _) = try makeService()
        let items = try service.search(query: "kaspi", in: .kz)
        XCTAssertTrue(items.contains { if case .institution(let i) = $0 { return i.id == "kz.kaspi-bank" }; return false })
    }

    func test_search_matchesByAliasCaseInsensitive() throws {
        let (service, _) = try makeService()
        let items = try service.search(query: "KASPI.KZ", in: .kz)
        XCTAssertTrue(items.contains { if case .institution(let i) = $0 { return i.id == "kz.kaspi-bank" }; return false })
    }

    func test_search_alwaysIncludesOtherBankRegardlessOfQuery() throws {
        let (service, _) = try makeService()
        let items = try service.search(query: "zzz-no-such-bank-zzz", in: .kz)
        XCTAssertEqual(items.last, .otherBank)
    }

    func test_listInstitutions_excludesArchivedCustomInstitutions() throws {
        let (service, connection) = try makeService()
        try connection.execute(
            "INSERT INTO institutions (id, source, country, name, aliases, archived, created_at, updated_at) VALUES (?, 'custom', 'KZ', 'My Bank', '[]', 1, '2026-01-01', '2026-01-01');",
            params: [.text("custom-1")]
        )
        let items = try service.listInstitutions(country: .kz)
        XCTAssertFalse(items.contains { if case .institution(let i) = $0 { return i.id == "custom-1" }; return false })
    }

    func test_resolveOrCreateCustomInstitution_createsNewOnFirstCall() throws {
        let (service, _) = try makeService()
        let result = service.resolveOrCreateCustomInstitution(name: "My Local Bank", country: .kz)
        guard case .success(let institution) = result else { return XCTFail("expected success") }
        XCTAssertEqual(institution.name, "My Local Bank")
        XCTAssertEqual(institution.source, .custom)
        XCTAssertFalse(institution.archived)
    }

    func test_resolveOrCreateCustomInstitution_reusesExistingActiveMatch_caseAndWhitespaceInsensitive() throws {
        let (service, _) = try makeService()
        let first = service.resolveOrCreateCustomInstitution(name: "My Local Bank", country: .kz)
        guard case .success(let firstInstitution) = first else { return XCTFail("expected success") }
        let second = service.resolveOrCreateCustomInstitution(name: "  my local bank  ", country: .kz)
        guard case .success(let secondInstitution) = second else { return XCTFail("expected success") }
        XCTAssertEqual(firstInstitution.id, secondInstitution.id)
    }

    func test_resolveOrCreateCustomInstitution_archivedMatch_returnsConflict() throws {
        let (service, _) = try makeService()
        guard case .success(let institution) = service.resolveOrCreateCustomInstitution(name: "Old Bank", country: .kz) else {
            return XCTFail("expected success")
        }
        guard case .success = service.archiveCustomInstitution(id: institution.id) else {
            return XCTFail("expected archive to succeed")
        }
        let result = service.resolveOrCreateCustomInstitution(name: "Old Bank", country: .kz)
        guard case .failure(.conflictWithArchived(let conflicting)) = result else {
            return XCTFail("expected conflictWithArchived, got \(result)")
        }
        XCTAssertEqual(conflicting.id, institution.id)
    }

    func test_renameCustomInstitution_updatesName() throws {
        let (service, _) = try makeService()
        guard case .success(let institution) = service.resolveOrCreateCustomInstitution(name: "Old Name", country: .kz) else {
            return XCTFail("expected success")
        }
        let result = service.renameCustomInstitution(id: institution.id, name: "New Name")
        guard case .success(let renamed) = result else { return XCTFail("expected success") }
        XCTAssertEqual(renamed.name, "New Name")
    }

    func test_changeCustomInstitutionCountry_failsWhenInUse() throws {
        let (service, connection) = try makeService()
        guard case .success(let institution) = service.resolveOrCreateCustomInstitution(name: "Used Bank", country: .kz) else {
            return XCTFail("expected success")
        }
        try connection.execute(
            "INSERT INTO accounts (id, name, country, type, currency, opening_balance, balance_date, institution_id, archived, created_at, updated_at) VALUES ('acc-1', 'Acc', 'KZ', 'bank_account', 'USD', '0', '2026-01-01', ?, 0, '2026-01-01', '2026-01-01');",
            params: [.text(institution.id)]
        )
        let result = service.changeCustomInstitutionCountry(id: institution.id, country: .ae)
        XCTAssertEqual(result, .failure(.inUse))
    }

    func test_archiveCustomInstitution_doesNotBreakAccountsReferencingIt() throws {
        let (service, connection) = try makeService()
        guard case .success(let institution) = service.resolveOrCreateCustomInstitution(name: "Ref Bank", country: .kz) else {
            return XCTFail("expected success")
        }
        try connection.execute(
            "INSERT INTO accounts (id, name, country, type, currency, opening_balance, balance_date, institution_id, archived, created_at, updated_at) VALUES ('acc-2', 'Acc', 'KZ', 'bank_account', 'USD', '0', '2026-01-01', ?, 0, '2026-01-01', '2026-01-01');",
            params: [.text(institution.id)]
        )
        XCTAssertEqual(service.archiveCustomInstitution(id: institution.id).isSuccess, true)
        let rows = try connection.query("SELECT institution_id FROM accounts WHERE id = 'acc-2';")
        XCTAssertEqual(rows[0]["institution_id"], .text(institution.id))
    }

    func test_everyMutation_onSystemInstitution_failsWithReadOnly() throws {
        let (service, _) = try makeService()
        XCTAssertEqual(service.renameCustomInstitution(id: "kz.halyk-bank", name: "X"), .failure(.systemInstitutionIsReadOnly))
        XCTAssertEqual(service.archiveCustomInstitution(id: "kz.halyk-bank"), .failure(.systemInstitutionIsReadOnly))
        XCTAssertEqual(service.restoreCustomInstitution(id: "kz.halyk-bank"), .failure(.systemInstitutionIsReadOnly))
        XCTAssertEqual(service.changeCustomInstitutionCountry(id: "kz.halyk-bank", country: .ae), .failure(.systemInstitutionIsReadOnly))
    }

    func test_listCustomInstitutions_excludesSystemInstitutions() throws {
        let (service, _) = try makeService()
        _ = service.resolveOrCreateCustomInstitution(name: "My Custom Bank", country: .kz)

        let customOnly = service.listCustomInstitutions(includeArchived: true)

        XCTAssertFalse(customOnly.contains { $0.id == "kz.halyk-bank" })
        XCTAssertTrue(customOnly.contains { $0.name == "My Custom Bank" })
    }

    func test_listCustomInstitutions_excludesArchivedByDefault() throws {
        let (service, _) = try makeService()
        guard case .success(let institution) = service.resolveOrCreateCustomInstitution(name: "Archived Bank", country: .kz) else {
            return XCTFail("expected success")
        }
        _ = service.archiveCustomInstitution(id: institution.id)

        XCTAssertFalse(service.listCustomInstitutions(includeArchived: false).contains { $0.id == institution.id })
        XCTAssertTrue(service.listCustomInstitutions(includeArchived: true).contains { $0.id == institution.id })
    }

    func test_listCustomInstitutions_spansMultipleCountries() throws {
        let (service, _) = try makeService()
        _ = service.resolveOrCreateCustomInstitution(name: "KZ Custom Bank", country: .kz)
        _ = service.resolveOrCreateCustomInstitution(name: "US Custom Bank", country: .us)

        let names = Set(service.listCustomInstitutions(includeArchived: true).map(\.name))

        XCTAssertTrue(names.isSuperset(of: ["KZ Custom Bank", "US Custom Bank"]))
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
