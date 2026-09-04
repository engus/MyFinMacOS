import SwiftUI

/// Theme + language pickers, shared between the profile picker (pre-login)
/// and Settings (post-login) so both read/write the same `AppPreferences`.
struct PreferencesControls: View {
    @EnvironmentObject var preferences: AppPreferences

    var body: some View {
        HStack(spacing: 16) {
            Picker(preferences.string(.themePickerLabel), selection: $preferences.theme) {
                Text(preferences.string(.themeSystem)).tag(AppTheme.system)
                Text(preferences.string(.themeLight)).tag(AppTheme.light)
                Text(preferences.string(.themeDark)).tag(AppTheme.dark)
            }
            .frame(maxWidth: 220)

            Picker(preferences.string(.languagePickerLabel), selection: $preferences.language) {
                Text(preferences.string(.languageRussian)).tag(AppLanguage.ru)
                Text(preferences.string(.languageEnglish)).tag(AppLanguage.en)
            }
            .frame(maxWidth: 220)
        }
    }
}
