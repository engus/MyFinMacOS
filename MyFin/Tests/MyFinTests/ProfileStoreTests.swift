import XCTest
@testable import MyFin

final class ProfileStoreTests: XCTestCase {
    var tempDirectory: URL!
    var store: ProfileStore!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyFinTests-\(UUID().uuidString)", isDirectory: true)
        store = ProfileStore(baseDirectory: tempDirectory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func test_listProfiles_onEmptyDirectory_returnsEmptyArray() throws {
        XCTAssertEqual(try store.listProfiles(), [])
    }

    func test_createProfileDirectory_createsFolderAndMetadataFile() throws {
        let profile = try store.createProfileDirectory(displayName: "Женя")
        let dir = store.profileDirectory(for: profile.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("profile.json").path))
        XCTAssertEqual(profile.displayName, "Женя")
    }

    func test_listProfiles_afterCreate_returnsCreatedProfile() throws {
        let created = try store.createProfileDirectory(displayName: "Женя")
        XCTAssertEqual(try store.listProfiles(), [created])
    }

    func test_deleteProfile_removesFolder() throws {
        let profile = try store.createProfileDirectory(displayName: "Женя")
        try store.deleteProfile(id: profile.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.profileDirectory(for: profile.id).path))
    }

    func test_deleteProfile_whenMissing_throwsProfileNotFound() {
        XCTAssertThrowsError(try store.deleteProfile(id: UUID())) { error in
            XCTAssertEqual(error as? ProfileStoreError, .profileNotFound)
        }
    }

    func test_createProfileDirectory_usesDefaultIconAndColor() throws {
        let profile = try store.createProfileDirectory(displayName: "Женя")
        XCTAssertEqual(profile.iconName, Profile.defaultIconName)
        XCTAssertEqual(profile.iconColor, Profile.defaultIconColor)
    }

    func test_updateProfile_overwritesDisplayNameIconAndColor() throws {
        let created = try store.createProfileDirectory(displayName: "Женя")
        var updated = created
        updated.displayName = "Евгений"
        updated.iconName = "star.circle.fill"
        updated.iconColor = "purple"

        try store.updateProfile(updated)

        XCTAssertEqual(try store.listProfiles(), [updated])
    }

    func test_listProfiles_decodesLegacyProfileMissingIconFields() throws {
        let profile = try store.createProfileDirectory(displayName: "Женя")
        let legacyJSON = """
        {"id":"\(profile.id.uuidString)","displayName":"Женя","createdAt":\(profile.createdAt.timeIntervalSince1970)}
        """
        let metadataURL = store.profileDirectory(for: profile.id).appendingPathComponent("profile.json")
        try legacyJSON.write(to: metadataURL, atomically: true, encoding: .utf8)

        let profiles = try store.listProfiles()
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles[0].iconName, Profile.defaultIconName)
        XCTAssertEqual(profiles[0].iconColor, Profile.defaultIconColor)
    }

    func test_profile_decodedWithoutOnboardingKey_defaultsToTrue() throws {
        let json = """
        {"id":"\(UUID().uuidString)","displayName":"Legacy","createdAt":0,"iconName":"person.crop.circle.fill","iconColor":"blue"}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let profile = try decoder.decode(Profile.self, from: json)
        XCTAssertTrue(profile.hasCompletedOnboarding)
    }

    func test_newlyConstructedProfile_defaultsOnboardingToFalse() {
        let profile = Profile(id: UUID(), displayName: "New", createdAt: Date())
        XCTAssertFalse(profile.hasCompletedOnboarding)
    }
}
