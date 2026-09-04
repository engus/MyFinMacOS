import XCTest
@testable import MyFin

final class KeychainServiceTests: XCTestCase {
    let service = "com.myfin.local.tests"
    var profileId: UUID!
    var keychain: KeychainService!

    override func setUpWithError() throws {
        profileId = UUID()
        keychain = KeychainService(service: service)
    }

    override func tearDownWithError() throws {
        keychain.deletePassword(for: profileId)
    }

    func test_savePassword_thenReadPassword_roundTrips() throws {
        try keychain.savePassword("s3cret", for: profileId)
        XCTAssertEqual(keychain.readPassword(for: profileId), "s3cret")
    }

    func test_readPassword_whenNotSaved_returnsNil() {
        XCTAssertNil(keychain.readPassword(for: profileId))
    }

    func test_savePassword_overwritesExistingValue() throws {
        try keychain.savePassword("first", for: profileId)
        try keychain.savePassword("second", for: profileId)
        XCTAssertEqual(keychain.readPassword(for: profileId), "second")
    }

    func test_deletePassword_removesEntry() throws {
        try keychain.savePassword("s3cret", for: profileId)
        keychain.deletePassword(for: profileId)
        XCTAssertNil(keychain.readPassword(for: profileId))
    }
}
