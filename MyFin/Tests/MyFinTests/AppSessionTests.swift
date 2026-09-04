import XCTest
@testable import MyFin

private struct StubAuthenticator: BiometricAuthenticating {
    let result: Bool
    func authenticate(reason: String) async -> Bool { result }
}

@MainActor
final class AppSessionTests: XCTestCase {
    var tempDirectory: URL!
    var session: AppSession!

    private func makeSession(authenticatorResult: Bool = true) -> AppSession {
        let store = ProfileStore(baseDirectory: tempDirectory)
        let keychain = KeychainService(service: "com.myfin.local.tests.session")
        return AppSession(profileStore: store, keychain: keychain, authenticator: StubAuthenticator(result: authenticatorResult))
    }

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyFinSessionTests-\(UUID().uuidString)", isDirectory: true)
        session = makeSession()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func test_createProfile_switchesToOnboardingAndUnlocksProfile() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)
        XCTAssertEqual(session.screen, .onboarding)
        XCTAssertEqual(session.unlockedProfile?.displayName, "Женя")
        XCTAssertNil(session.errorMessage)
    }

    func test_logOut_returnsToProfilePickerAndKeepsProfileListed() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)
        session.logOut()
        XCTAssertEqual(session.screen, .profilePicker)
        XCTAssertNil(session.unlockedProfile)
        XCTAssertEqual(session.profiles.count, 1)
    }

    func test_logIn_withWrongPassword_setsErrorMessageAndStaysOnPicker() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)
        let profile = session.profiles[0]
        session.logOut()

        session.logIn(profile: profile, password: "wrong")
        XCTAssertEqual(session.screen, .profilePicker)
        XCTAssertEqual(session.errorMessage, "Неверный пароль")
    }

    func test_logIn_withCorrectPassword_unlocksProfile() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)
        session.completeOnboarding()
        let profile = session.profiles[0]
        session.logOut()

        session.logIn(profile: profile, password: "pw1")
        XCTAssertEqual(session.screen, .mainShell)
        XCTAssertEqual(session.unlockedProfile?.id, profile.id)
    }

    func test_logInWithRememberedPassword_whenRemembered_unlocksAfterBiometricSuccess() async {
        session.createProfile(displayName: "Женя", password: "pw1", remember: true)
        session.completeOnboarding()
        let profile = session.profiles[0]
        session.logOut()

        let unlocked = await session.logInWithRememberedPassword(profile: profile)
        XCTAssertTrue(unlocked)
        XCTAssertEqual(session.screen, .mainShell)
    }

    func test_logInWithRememberedPassword_whenBiometricFails_staysOnPicker() async {
        session.createProfile(displayName: "Женя", password: "pw1", remember: true)
        let profile = session.profiles[0]
        session.logOut()
        session = makeSession(authenticatorResult: false)

        let unlocked = await session.logInWithRememberedPassword(profile: profile)
        XCTAssertFalse(unlocked)
        XCTAssertEqual(session.screen, .profilePicker)
    }

    func test_logInWithRememberedPassword_whenNothingRemembered_returnsFalseWithoutPrompting() async {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)
        let profile = session.profiles[0]
        session.logOut()

        let unlocked = await session.logInWithRememberedPassword(profile: profile)
        XCTAssertFalse(unlocked)
        XCTAssertEqual(session.screen, .profilePicker)
    }

    func test_deleteCurrentProfile_withCorrectPassword_deletesLogsOutAndClearsList() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)

        session.deleteCurrentProfile(confirmingWithPassword: "pw1")

        XCTAssertEqual(session.screen, .profilePicker)
        XCTAssertNil(session.unlockedProfile)
        XCTAssertTrue(session.profiles.isEmpty)
        XCTAssertNil(session.errorMessage)
    }

    func test_deleteCurrentProfile_withWrongPassword_setsErrorAndKeepsProfile() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)

        session.deleteCurrentProfile(confirmingWithPassword: "wrong")

        XCTAssertEqual(session.screen, .onboarding)
        XCTAssertNotNil(session.unlockedProfile)
        XCTAssertEqual(session.profiles.count, 1)
        XCTAssertEqual(session.errorMessage, "Неверный пароль")
    }

    func test_createProfile_withDuplicateName_setsErrorAndDoesNotCreateSecondProfile() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)
        session.logOut()

        session.createProfile(displayName: "Женя", password: "pw2", remember: false)

        XCTAssertEqual(session.screen, .profilePicker)
        XCTAssertEqual(session.profiles.count, 1)
        XCTAssertNotNil(session.errorMessage)
    }

    func test_createProfile_withDuplicateNameDifferentCaseAndWhitespace_setsError() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)
        session.logOut()

        session.createProfile(displayName: "  женя  ", password: "pw2", remember: false)

        XCTAssertEqual(session.profiles.count, 1)
        XCTAssertNotNil(session.errorMessage)
    }

    func test_changePassword_withCorrectCurrentPassword_succeedsAndAllowsLoginWithNewPassword() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)
        session.completeOnboarding()

        session.changePassword(currentPassword: "pw1", newPassword: "pw2")

        XCTAssertNil(session.errorMessage)

        let profile = session.profiles[0]
        session.logOut()
        session.logIn(profile: profile, password: "pw2")
        XCTAssertEqual(session.screen, .mainShell)
    }

    func test_changePassword_withWrongCurrentPassword_setsErrorAndKeepsOldPassword() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)
        session.completeOnboarding()

        session.changePassword(currentPassword: "wrong", newPassword: "pw2")

        XCTAssertEqual(session.errorMessage, "Неверный пароль")

        let profile = session.profiles[0]
        session.logOut()
        session.logIn(profile: profile, password: "pw1")
        XCTAssertEqual(session.screen, .mainShell)
    }

    func test_updateProfile_updatesUnlockedProfileAndProfilesList() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)

        session.updateProfile(displayName: "Евгений", iconName: "star.circle.fill", iconColor: "purple")

        XCTAssertEqual(session.unlockedProfile?.displayName, "Евгений")
        XCTAssertEqual(session.unlockedProfile?.iconName, "star.circle.fill")
        XCTAssertEqual(session.unlockedProfile?.iconColor, "purple")
        XCTAssertEqual(session.profiles.first?.displayName, "Евгений")
        XCTAssertNil(session.errorMessage)
    }

    func test_createProfile_firstScreenIsOnboarding() {
        let session = makeSession()
        session.createProfile(displayName: "Alice", password: "pw123456", remember: false)
        XCTAssertEqual(session.screen, .onboarding)
    }

    func test_completeOnboarding_persistsFlagAndTransitionsToMainShell() {
        let session = makeSession()
        session.createProfile(displayName: "Bob", password: "pw123456", remember: false)
        session.completeOnboarding()
        XCTAssertEqual(session.screen, .mainShell)
        XCTAssertTrue(session.unlockedProfile?.hasCompletedOnboarding ?? false)
    }

    func test_login_profileThatAlreadyCompletedOnboarding_goesStraightToMainShell() {
        let session = makeSession()
        session.createProfile(displayName: "Carol", password: "pw123456", remember: false)
        session.completeOnboarding()
        let profile = session.unlockedProfile!
        session.logOut()
        session.logIn(profile: profile, password: "pw123456")
        XCTAssertEqual(session.screen, .mainShell)
    }

    func test_updateNumberFormatPreferences_publishesImmediatelyAndPersists() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)
        let updated = NumberFormatPreferences(
            useCommaDecimalSeparator: true, maxDecimalPlaces: 0, useCompactNotation: true, hideTrailingZeroes: false
        )

        session.updateNumberFormatPreferences(updated)
        XCTAssertEqual(session.numberFormatPreferences, updated)

        let profile = session.profiles[0]
        session.logOut()
        session.logIn(profile: profile, password: "pw1")
        XCTAssertEqual(session.numberFormatPreferences, updated)
    }

    func test_updateBaseCurrency_publishesImmediatelyAndPersists() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)

        session.updateBaseCurrency(.kzt)
        XCTAssertEqual(session.baseCurrency, .kzt)

        let profile = session.profiles[0]
        session.logOut()
        session.logIn(profile: profile, password: "pw1")
        XCTAssertEqual(session.baseCurrency, .kzt)
    }

    func test_updateSidebarGroupingMode_publishesImmediatelyAndPersists() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)

        session.updateSidebarGroupingMode(.currency)
        XCTAssertEqual(session.sidebarGroupingMode, .currency)

        let profile = session.profiles[0]
        session.logOut()
        session.logIn(profile: profile, password: "pw1")
        XCTAssertEqual(session.sidebarGroupingMode, .currency)
    }

    func test_updateShowOriginalCurrencies_publishesImmediatelyAndPersists() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)

        XCTAssertFalse(session.showOriginalCurrencies)

        session.updateShowOriginalCurrencies(true)
        XCTAssertTrue(session.showOriginalCurrencies)

        let profile = session.profiles[0]
        session.logOut()
        session.logIn(profile: profile, password: "pw1")
        XCTAssertTrue(session.showOriginalCurrencies)
    }
}
