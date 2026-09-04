import SwiftUI

enum AppTheme: String, CaseIterable, Codable {
    case system, light, dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AppLanguage: String, CaseIterable, Codable {
    case ru, en
}

@MainActor
final class AppPreferences: ObservableObject {
    @Published var theme: AppTheme {
        didSet { persist() }
    }
    @Published var language: AppLanguage {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private static let themeKey = "appTheme"
    private static let languageKey = "appLanguage"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.theme = AppTheme(rawValue: defaults.string(forKey: Self.themeKey) ?? "") ?? .system
        self.language = AppLanguage(rawValue: defaults.string(forKey: Self.languageKey) ?? "") ?? .ru
    }

    private func persist() {
        defaults.set(theme.rawValue, forKey: Self.themeKey)
        defaults.set(language.rawValue, forKey: Self.languageKey)
    }

    func string(_ key: L10nKey) -> String {
        Localization.string(key, language: language)
    }
}
