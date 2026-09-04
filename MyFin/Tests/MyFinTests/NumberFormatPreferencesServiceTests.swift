import XCTest
@testable import MyFin

final class NumberFormatPreferencesServiceTests: XCTestCase {
    private func makeService() throws -> NumberFormatPreferencesService {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        let connection = try DatabaseConnection.open(at: url, password: "pw")
        return NumberFormatPreferencesService(connection: connection)
    }

    func test_load_onFreshConnection_returnsDefaults() throws {
        let service = try makeService()
        XCTAssertEqual(service.load(), NumberFormatPreferences())
    }

    func test_save_thenLoad_roundTripsAllFields() throws {
        let service = try makeService()
        let preferences = NumberFormatPreferences(
            useCommaDecimalSeparator: true,
            maxDecimalPlaces: 0,
            useCompactNotation: true,
            hideTrailingZeroes: false
        )
        try service.save(preferences)
        XCTAssertEqual(service.load(), preferences)
    }

    func test_save_thenLoad_roundTripsOnePlaceVariant() throws {
        let service = try makeService()
        let preferences = NumberFormatPreferences(
            useCommaDecimalSeparator: false,
            maxDecimalPlaces: 1,
            useCompactNotation: false,
            hideTrailingZeroes: true
        )
        try service.save(preferences)
        XCTAssertEqual(service.load(), preferences)
    }
}
