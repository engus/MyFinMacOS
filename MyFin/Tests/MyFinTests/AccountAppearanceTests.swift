import XCTest
@testable import MyFin

final class AccountAppearanceTests: XCTestCase {
    func test_failedAppearanceInsertRollsBackAllAccountRows() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let db = try DatabaseConnection.open(at: url, password: "test")
        try db.execute("CREATE TRIGGER reject_appearance BEFORE INSERT ON account_appearances BEGIN SELECT RAISE(ABORT, 'reject'); END;")
        let service = AccountService(connection: db, institutionService: InstitutionService(connection: db))
        XCTAssertThrowsError(try service.createAccount(country: .kz, type: .cash, institutionSelection: .none,
            currency: .usd, openingBalance: 100, name: "Rollback", balanceDate: nil).get())
        for table in ["accounts", "transactions", "balance_history", "account_appearances"] {
            XCTAssertTrue(try db.query("SELECT * FROM \(table);").isEmpty)
        }
        XCTAssertThrowsError(try service.createAccount(country: .kz, type: .bankAccount,
            institutionSelection: .newCustom(name: "Must roll back"), currency: .usd,
            openingBalance: 100, name: "Rollback bank", balanceDate: nil).get())
        XCTAssertTrue(try db.query("SELECT * FROM institutions WHERE name = 'Must roll back';").isEmpty)
    }

    func test_legacyMigrationAndCorruptAppearanceKeepAccountReadable() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let db = try DatabaseConnection.open(at: url, password: "test")
        let service = AccountService(connection: db, institutionService: InstitutionService(connection: db))
        _ = try service.createAccount(country: .kz, type: .cash, institutionSelection: .none,
            currency: .usd, openingBalance: 0, name: "Legacy", balanceDate: nil).get()
        try db.execute("DROP TABLE account_appearances;")
        try db.setUserVersion(5)
        db.close()
        let migrated = try DatabaseConnection.open(at: url, password: "test")
        let migratedService = AccountService(connection: migrated, institutionService: InstitutionService(connection: migrated))
        XCTAssertEqual(try migrated.userVersion, 9)
        XCTAssertEqual(migratedService.listAccounts(includeArchived: true).first?.appearance.themePreset, .obsidianMatte)
        XCTAssertNil(migratedService.listAccounts(includeArchived: true).first?.appearance.paymentNetwork)
        let new = try migratedService.createAccount(country: .kz, type: .cash, institutionSelection: .none,
            currency: .usd, openingBalance: 0, name: "Corrupt", balanceDate: nil).get()
        try migrated.execute("UPDATE account_appearances SET theme_preset = 'future', tags_json = 'broken' WHERE account_id = ?;", params: [.text(new.id)])
        let loaded = try XCTUnwrap(migratedService.listAccounts(includeArchived: true).first { $0.id == new.id })
        XCTAssertEqual(loaded.appearance.themePreset, .obsidianMatte)
        XCTAssertEqual(loaded.appearance.tags, [])
    }

    func test_tagsAndNonCardFieldsAreNormalized() {
        var value = AccountAppearance()
        value.tags = [" #Salary ", "salary", "", "##Travel"]
        let cash = value.sanitized(for: .cash)
        XCTAssertEqual(cash.tags, ["Salary", "Travel"])
        XCTAssertNil(cash.paymentNetwork)
    }

    func test_persistenceSurvivesReopenAndOrdinaryEdit() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let db = try DatabaseConnection.open(at: url, password: "test")
        let service = AccountService(connection: db, institutionService: InstitutionService(connection: db))
        var appearance = AccountAppearance()
        appearance.themePreset = .emeraldGlass
        appearance.tags = ["Salary"]
        appearance.paymentNetwork = .visa
        let created = try service.createAccount(country: .kz, type: .debitCard,
            institutionSelection: .existing(id: "kz.kaspi-bank"), currency: .kzt,
            openingBalance: 123, name: "Card", balanceDate: nil, appearance: appearance).get()
        _ = try service.updateAccount(id: created.id, name: "Renamed", country: .kz,
            type: .debitCard, currency: .kzt, institutionSelection: .existing(id: "kz.kaspi-bank"), openingBalance: 456).get()
        db.close()
        let reopened = try DatabaseConnection.open(at: url, password: "test")
        let loaded = AccountService(connection: reopened, institutionService: InstitutionService(connection: reopened)).listAccounts(includeArchived: true)
        XCTAssertEqual(loaded.first?.appearance, appearance)
    }
}
