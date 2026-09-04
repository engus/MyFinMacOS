import XCTest
@testable import MyFin

@MainActor
final class AppPreferencesTests: XCTestCase {
    var suiteName: String!
    var defaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "com.myfin.local.tests.preferences.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func test_defaultsToSystemThemeAndRussian_whenNothingStored() {
        let preferences = AppPreferences(defaults: defaults)
        XCTAssertEqual(preferences.theme, .system)
        XCTAssertEqual(preferences.language, .ru)
    }

    func test_settingTheme_persistsAcrossReinit() {
        let first = AppPreferences(defaults: defaults)
        first.theme = .dark

        let second = AppPreferences(defaults: defaults)
        XCTAssertEqual(second.theme, .dark)
    }

    func test_settingLanguage_persistsAcrossReinit() {
        let first = AppPreferences(defaults: defaults)
        first.language = .en

        let second = AppPreferences(defaults: defaults)
        XCTAssertEqual(second.language, .en)
    }

    func test_string_returnsValueForCurrentLanguage() {
        let preferences = AppPreferences(defaults: defaults)
        preferences.language = .en
        XCTAssertEqual(preferences.string(.loginButton), "Log In")
        preferences.language = .ru
        XCTAssertEqual(preferences.string(.loginButton), "Войти")
    }
}
