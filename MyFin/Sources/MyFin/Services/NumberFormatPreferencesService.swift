import Foundation

final class NumberFormatPreferencesService {
    private let connection: DatabaseConnection

    private static let decimalSeparatorKey = "numberFormatDecimalSeparator"
    private static let maxDecimalPlacesKey = "numberFormatMaxDecimalPlaces"
    private static let notationKey = "numberFormatNotation"
    private static let hideTrailingZeroesKey = "numberFormatHideTrailingZeroes"

    init(connection: DatabaseConnection) {
        self.connection = connection
    }

    func load() -> NumberFormatPreferences {
        let rows = (try? connection.query(
            "SELECT key, value FROM profile_settings WHERE key IN (?, ?, ?, ?);",
            params: [
                .text(Self.decimalSeparatorKey), .text(Self.maxDecimalPlacesKey),
                .text(Self.notationKey), .text(Self.hideTrailingZeroesKey)
            ]
        )) ?? []

        var values: [String: String] = [:]
        for row in rows {
            if case let .text(key)? = row["key"], case let .text(value)? = row["value"] {
                values[key] = value
            }
        }

        var preferences = NumberFormatPreferences()
        if let raw = values[Self.decimalSeparatorKey] {
            preferences.useCommaDecimalSeparator = (raw == "comma")
        }
        if let raw = values[Self.maxDecimalPlacesKey], let places = Int(raw), (0...2).contains(places) {
            preferences.maxDecimalPlaces = places
        }
        if let raw = values[Self.notationKey] {
            preferences.useCompactNotation = (raw == "compact")
        }
        if let raw = values[Self.hideTrailingZeroesKey] {
            preferences.hideTrailingZeroes = (raw == "true")
        }
        return preferences
    }

    func save(_ preferences: NumberFormatPreferences) throws {
        try connection.withTransaction {
            try connection.execute(
                "INSERT INTO profile_settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
                params: [.text(Self.decimalSeparatorKey), .text(preferences.useCommaDecimalSeparator ? "comma" : "period")]
            )
            try connection.execute(
                "INSERT INTO profile_settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
                params: [.text(Self.maxDecimalPlacesKey), .text(String(preferences.maxDecimalPlaces))]
            )
            try connection.execute(
                "INSERT INTO profile_settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
                params: [.text(Self.notationKey), .text(preferences.useCompactNotation ? "compact" : "full")]
            )
            try connection.execute(
                "INSERT INTO profile_settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
                params: [.text(Self.hideTrailingZeroesKey), .text(preferences.hideTrailingZeroes ? "true" : "false")]
            )
        }
    }
}
