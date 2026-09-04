# MyFin Appearance, Language & Profile Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an app-wide Day/Night/System appearance setting, an app-wide EN/RU language switch with instant (no-restart) UI updates, and profile management (rename, SF-Symbol icon + color, delete confirmation) to the existing MyFin macOS app.

**Architecture:** A new `AppPreferences` `ObservableObject` (theme + language, `UserDefaults`-backed) and a hand-rolled `Localization` string table are injected app-wide via `.environmentObject`; every existing view is updated to read strings from it instead of hardcoded Russian, and to expose theme/language pickers. `Profile` gains `iconName`/`iconColor` fields with backward-compatible decoding, `ProfileStore`/`AppSession` gain an `updateProfile` path, and `SettingsView`/`ProfilePickerView` get the rename/icon UI and a delete-confirmation dialog.

**Tech Stack:** Swift 5.9+, SwiftUI, Foundation (`UserDefaults`), XCTest — no new external dependencies.

**Spec:** `docs/superpowers/specs/2026-09-01-myfin-preferences-and-profile-management-design.md`

## Global Constraints

- **No git.** Do not run any `git` command. Files are saved directly to disk.
- **No macOS build toolchain is available to the executing agent.** `device_bash` (used to edit files on the user's Mac) is a Linux VM with no `swift`/`xcodebuild`. **Every step that runs `swift build`, `swift test`, or `swift run` must be handed to the user**: give the exact command, ask them to run it in their own Terminal, and wait for their pasted output before continuing.
- **File edits happen via `device_bash`** against `$HOME/mnt/MyFinLocal/MyFin/...`, which is `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin/...` on the user's Mac.
- **Project root:** `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin` (existing SPM package — no `Package.swift` changes needed in this plan, no new dependencies).
- This plan **modifies existing files** built by the prior MVP shell plan. Each "Modify" step below gives the **full new file content** to write (not a diff) — the safest way to avoid divergence when a file is touched by more than one task in this plan.
- All new/changed user-facing strings go through `AppPreferences.string(_:)` / `Localization` — no new hardcoded Russian or English literal strings in views, except the literal app name `"MyFin"` (a proper noun, intentionally not localized) and `AppSession`'s existing internal error messages (`"Не удалось создать профиль: ..."` etc.), which stay hardcoded Russian — out of scope per the spec (it only requires translating the five *view* files, not the session/business-logic layer).
- Profile icon set: exactly the 12 SF Symbols and 8 color names given in Task 4 — don't invent others.

---

## File Structure

New files:
- `Sources/MyFin/Localization.swift` — `L10nKey`, `Localization.ru`/`.en`, `Localization.string(_:language:)`
- `Sources/MyFin/AppPreferences.swift` — `AppTheme`, `AppLanguage`, `AppPreferences`
- `Sources/MyFin/Views/PreferencesControls.swift` — shared theme/language picker row
- `Sources/MyFin/Models/ProfileIconPalette.swift` — the fixed icon/color vocabulary
- `Tests/MyFinTests/LocalizationTests.swift`
- `Tests/MyFinTests/AppPreferencesTests.swift`

Modified files (full replacement content given per task):
- `Sources/MyFin/Models/Profile.swift` — add `iconName`/`iconColor` with backward-compatible decoding
- `Sources/MyFin/Services/ProfileStore.swift` — add `updateProfile(_:)`
- `Sources/MyFin/AppSession.swift` — add `updateProfile(displayName:iconName:iconColor:)`
- `Sources/MyFin/MyFinApp.swift` — inject `AppPreferences`, apply `.preferredColorScheme`
- `Sources/MyFin/Views/ProfilePickerView.swift` — localized strings, theme/language row, profile icon, delete confirmation
- `Sources/MyFin/Views/CreateProfileView.swift` — localized strings
- `Sources/MyFin/Views/LoginView.swift` — localized strings
- `Sources/MyFin/Views/MainShellView.swift` — localized sidebar/placeholder strings
- `Sources/MyFin/Views/SettingsView.swift` — localized strings, appearance section, profile rename/icon section
- `Sources/MyFin/Views/RevealableSecureField.swift` — localized accessibility labels
- `Tests/MyFinTests/ProfileStoreTests.swift` — add `updateProfile`/legacy-decode tests
- `Tests/MyFinTests/AppSessionTests.swift` — add `updateProfile` test

---

### Task 1: Localization layer

**Files:**
- Create: `MyFin/Sources/MyFin/Localization.swift`
- Test: `MyFin/Tests/MyFinTests/LocalizationTests.swift`

**Interfaces:**
- Produces: `enum L10nKey: String, CaseIterable` (46 cases, listed below); `enum Localization { static let ru: [L10nKey: String]; static let en: [L10nKey: String]; static func string(_ key: L10nKey, language: AppLanguage) -> String }`. Note: `Localization.string` references `AppLanguage`, defined in Task 2 — write this file's `string(_:language:)` function now; it won't compile standalone until Task 2 adds `AppLanguage`, so Task 1's test step only exercises `Localization.ru`/`Localization.en` directly (no `AppLanguage` needed for that).

- [ ] **Step 1: Write the failing test**

`Tests/MyFinTests/LocalizationTests.swift`:
```swift
import XCTest
@testable import MyFin

final class LocalizationTests: XCTestCase {
    func test_everyKey_hasNonEmptyRussianAndEnglishTranslation() {
        for key in L10nKey.allCases {
            XCTAssertNotNil(Localization.ru[key], "Missing ru translation for \(key)")
            XCTAssertNotNil(Localization.en[key], "Missing en translation for \(key)")
            XCTAssertFalse((Localization.ru[key] ?? "").isEmpty, "Empty ru translation for \(key)")
            XCTAssertFalse((Localization.en[key] ?? "").isEmpty, "Empty en translation for \(key)")
        }
    }

    func test_ru_and_en_haveTheSameKeyCount() {
        XCTAssertEqual(Localization.ru.count, L10nKey.allCases.count)
        XCTAssertEqual(Localization.en.count, L10nKey.allCases.count)
    }
}
```

- [ ] **Step 2: Ask the user to run the test and confirm it fails**

```bash
swift test --filter LocalizationTests
```
Expected: compilation errors (`L10nKey`/`Localization` not found). Paste the output back.

- [ ] **Step 3: Write the implementation**

`Sources/MyFin/Localization.swift`:
```swift
import Foundation

enum L10nKey: String, CaseIterable {
    case noProfilesYet
    case loginButton
    case deleteButton
    case createProfileButton
    case createProfileTitle
    case profileNameField
    case passwordField
    case confirmPasswordField
    case rememberPasswordToggle
    case passwordRecoveryWarning
    case passwordsDoNotMatch
    case cancelButton
    case createButton
    case loginTitleFormat
    case changePasswordSectionTitle
    case newPasswordField
    case confirmNewPasswordField
    case passwordChangedMessage
    case changePasswordButton
    case logOutButton
    case sidebarDashboard
    case sidebarAccounts
    case sidebarCashflow
    case sidebarAssets
    case sidebarSettings
    case dashboardPlaceholder
    case accountsPlaceholder
    case cashflowPlaceholder
    case assetsPlaceholder
    case selectSectionMessage
    case themePickerLabel
    case themeSystem
    case themeLight
    case themeDark
    case languagePickerLabel
    case languageRussian
    case languageEnglish
    case appearanceSectionTitle
    case profileSectionTitle
    case iconLabel
    case colorLabel
    case saveButton
    case profileUpdatedMessage
    case deleteProfileConfirmTitleFormat
    case deleteProfileConfirmMessage
    case showPasswordLabel
    case hidePasswordLabel
}

enum Localization {
    static func string(_ key: L10nKey, language: AppLanguage) -> String {
        switch language {
        case .ru: return ru[key] ?? key.rawValue
        case .en: return en[key] ?? key.rawValue
        }
    }

    static let ru: [L10nKey: String] = [
        .noProfilesYet: "Профилей пока нет",
        .loginButton: "Войти",
        .deleteButton: "Удалить",
        .createProfileButton: "Создать профиль",
        .createProfileTitle: "Новый профиль",
        .profileNameField: "Имя профиля",
        .passwordField: "Пароль",
        .confirmPasswordField: "Повторите пароль",
        .rememberPasswordToggle: "Запомнить пароль в Keychain",
        .passwordRecoveryWarning: "Пароль нельзя восстановить: если вы его забудете, доступ к данным профиля будет утерян.",
        .passwordsDoNotMatch: "Пароли не совпадают",
        .cancelButton: "Отмена",
        .createButton: "Создать",
        .loginTitleFormat: "Вход: %@",
        .changePasswordSectionTitle: "Смена пароля",
        .newPasswordField: "Новый пароль",
        .confirmNewPasswordField: "Повторите новый пароль",
        .passwordChangedMessage: "Пароль изменён",
        .changePasswordButton: "Сменить пароль",
        .logOutButton: "Выйти из профиля",
        .sidebarDashboard: "Дашборд",
        .sidebarAccounts: "Аккаунты",
        .sidebarCashflow: "Cashflow",
        .sidebarAssets: "Активы",
        .sidebarSettings: "Настройки",
        .dashboardPlaceholder: "Дашборд — здесь скоро появится содержимое",
        .accountsPlaceholder: "Аккаунты — здесь скоро появится содержимое",
        .cashflowPlaceholder: "Cashflow — здесь скоро появится содержимое",
        .assetsPlaceholder: "Активы — здесь скоро появится содержимое",
        .selectSectionMessage: "Выберите раздел слева",
        .themePickerLabel: "Тема",
        .themeSystem: "Системная",
        .themeLight: "Светлая",
        .themeDark: "Тёмная",
        .languagePickerLabel: "Язык",
        .languageRussian: "Русский",
        .languageEnglish: "English",
        .appearanceSectionTitle: "Оформление и язык",
        .profileSectionTitle: "Профиль",
        .iconLabel: "Значок",
        .colorLabel: "Цвет",
        .saveButton: "Сохранить",
        .profileUpdatedMessage: "Профиль обновлён",
        .deleteProfileConfirmTitleFormat: "Удалить профиль «%@»?",
        .deleteProfileConfirmMessage: "Это действие необратимо.",
        .showPasswordLabel: "Показать пароль",
        .hidePasswordLabel: "Скрыть пароль",
    ]

    static let en: [L10nKey: String] = [
        .noProfilesYet: "No profiles yet",
        .loginButton: "Log In",
        .deleteButton: "Delete",
        .createProfileButton: "Create Profile",
        .createProfileTitle: "New Profile",
        .profileNameField: "Profile Name",
        .passwordField: "Password",
        .confirmPasswordField: "Confirm Password",
        .rememberPasswordToggle: "Remember password in Keychain",
        .passwordRecoveryWarning: "This password cannot be recovered: if you forget it, access to this profile's data will be lost.",
        .passwordsDoNotMatch: "Passwords don't match",
        .cancelButton: "Cancel",
        .createButton: "Create",
        .loginTitleFormat: "Log in: %@",
        .changePasswordSectionTitle: "Change Password",
        .newPasswordField: "New Password",
        .confirmNewPasswordField: "Confirm New Password",
        .passwordChangedMessage: "Password changed",
        .changePasswordButton: "Change Password",
        .logOutButton: "Log Out of Profile",
        .sidebarDashboard: "Dashboard",
        .sidebarAccounts: "Accounts",
        .sidebarCashflow: "Cashflow",
        .sidebarAssets: "Assets",
        .sidebarSettings: "Settings",
        .dashboardPlaceholder: "Dashboard — content coming soon",
        .accountsPlaceholder: "Accounts — content coming soon",
        .cashflowPlaceholder: "Cashflow — content coming soon",
        .assetsPlaceholder: "Assets — content coming soon",
        .selectSectionMessage: "Select a section on the left",
        .themePickerLabel: "Theme",
        .themeSystem: "System",
        .themeLight: "Light",
        .themeDark: "Dark",
        .languagePickerLabel: "Language",
        .languageRussian: "Russian",
        .languageEnglish: "English",
        .appearanceSectionTitle: "Appearance & Language",
        .profileSectionTitle: "Profile",
        .iconLabel: "Icon",
        .colorLabel: "Color",
        .saveButton: "Save",
        .profileUpdatedMessage: "Profile updated",
        .deleteProfileConfirmTitleFormat: "Delete profile \"%@\"?",
        .deleteProfileConfirmMessage: "This action cannot be undone.",
        .showPasswordLabel: "Show password",
        .hidePasswordLabel: "Hide password",
    ]
}
```

This won't compile yet — `Localization.string(_:language:)` references `AppLanguage`, which Task 2 defines. That's expected; the failure at this point should be about the missing `AppLanguage` type, not about `L10nKey`/`Localization.ru`/`.en`.

- [ ] **Step 4: Ask the user to confirm the expected (partial) compile error**

```bash
swift test --filter LocalizationTests
```
Expected: an error like `cannot find type 'AppLanguage' in scope` (pointing at `Localization.string`), **not** any error about `L10nKey`, `Localization.ru`, or `Localization.en` — those should now be recognized. Paste the output back so we can confirm it's only the expected `AppLanguage` gap. Task 2 resolves this.

---

### Task 2: AppPreferences

**Files:**
- Create: `MyFin/Sources/MyFin/AppPreferences.swift`
- Test: `MyFin/Tests/MyFinTests/AppPreferencesTests.swift`

**Interfaces:**
- Consumes: `L10nKey`, `Localization.string(_:language:)` (Task 1).
- Produces: `enum AppTheme: String, CaseIterable, Codable { case system, light, dark }` with `var colorScheme: ColorScheme?`; `enum AppLanguage: String, CaseIterable, Codable { case ru, en }`; `final class AppPreferences: ObservableObject` with `@Published var theme: AppTheme`, `@Published var language: AppLanguage`, `init(defaults: UserDefaults = .standard)`, `func string(_ key: L10nKey) -> String`. Every later task's views read `preferences.theme`, `preferences.language`, and `preferences.string(_:)`.

- [ ] **Step 1: Write the failing tests**

`Tests/MyFinTests/AppPreferencesTests.swift`:
```swift
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
```

- [ ] **Step 2: Ask the user to run the tests and confirm they fail**

```bash
swift test --filter AppPreferencesTests
```
Expected: compilation errors (`AppPreferences` not found). Paste the output back.

- [ ] **Step 3: Write the implementation**

`Sources/MyFin/AppPreferences.swift`:
```swift
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
```

- [ ] **Step 4: Ask the user to re-run both Task 1's and Task 2's tests and confirm they pass**

```bash
swift test --filter LocalizationTests
swift test --filter AppPreferencesTests
```
Expected: `LocalizationTests` now passes fully (the `AppLanguage` gap from Task 1 is resolved), and all 4 `AppPreferencesTests` pass. Paste the output back.

---

### Task 3: Wire theme & language into every existing view

**Files:**
- Create: `MyFin/Sources/MyFin/Views/PreferencesControls.swift`
- Modify: `MyFin/Sources/MyFin/MyFinApp.swift`
- Modify: `MyFin/Sources/MyFin/Views/RevealableSecureField.swift`
- Modify: `MyFin/Sources/MyFin/Views/ProfilePickerView.swift`
- Modify: `MyFin/Sources/MyFin/Views/CreateProfileView.swift`
- Modify: `MyFin/Sources/MyFin/Views/LoginView.swift`
- Modify: `MyFin/Sources/MyFin/Views/MainShellView.swift`
- Modify: `MyFin/Sources/MyFin/Views/SettingsView.swift`

**Interfaces:**
- Consumes: `AppPreferences`, `AppTheme`, `AppLanguage`, `L10nKey` (Tasks 1–2).
- Produces: `PreferencesControls` (a `View` reading `@EnvironmentObject var preferences: AppPreferences`, no parameters) — reused as-is in Task 5's `SettingsView` rewrite. `SidebarItem` changes its `rawValue`s to stable English identifiers (`"dashboard"`, `"accounts"`, `"cashflow"`, `"assets"`, `"settings"`) and gains `var labelKey: L10nKey` — Task 5/6 don't touch `SidebarItem` further.

This task has no new automated tests of its own (it's UI wiring over already-tested `AppPreferences`/`Localization`) — verified with the manual checklist in Step 9, consistent with how the original shell plan verified its UI tasks.

- [ ] **Step 1: Create the shared preferences control**

`Sources/MyFin/Views/PreferencesControls.swift`:
```swift
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
```

- [ ] **Step 2: Inject `AppPreferences` and apply the theme at the app root**

Replace the contents of `Sources/MyFin/MyFinApp.swift`:
```swift
import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct MyFinApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var session = AppSession()
    @StateObject private var preferences = AppPreferences()

    var body: some Scene {
        WindowGroup {
            Group {
                if session.screen == .profilePicker {
                    ProfilePickerView(session: session)
                } else {
                    MainShellView(session: session)
                }
            }
            .frame(minWidth: 700, minHeight: 480)
            .environmentObject(preferences)
            .preferredColorScheme(preferences.theme.colorScheme)
        }
    }
}
```

- [ ] **Step 3: Localize `RevealableSecureField`'s accessibility labels**

Replace the contents of `Sources/MyFin/Views/RevealableSecureField.swift`:
```swift
import SwiftUI

/// A password field with a toggle button to reveal/hide the plaintext value.
struct RevealableSecureField: View {
    let title: String
    @Binding var text: String
    @EnvironmentObject var preferences: AppPreferences
    @State private var isRevealed = false

    var body: some View {
        HStack {
            Group {
                if isRevealed {
                    TextField(title, text: $text)
                } else {
                    SecureField(title, text: $text)
                }
            }
            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? preferences.string(.hidePasswordLabel) : preferences.string(.showPasswordLabel))
        }
    }
}
```

- [ ] **Step 4: Localize `ProfilePickerView` and add the preferences row**

Replace the contents of `Sources/MyFin/Views/ProfilePickerView.swift`:
```swift
import SwiftUI

struct ProfilePickerView: View {
    @ObservedObject var session: AppSession
    @EnvironmentObject var preferences: AppPreferences
    @State private var showingCreateProfile = false
    @State private var loginTarget: Profile?

    var body: some View {
        VStack(spacing: 16) {
            Text("MyFin").font(.largeTitle.bold())
            PreferencesControls()

            if session.profiles.isEmpty {
                Text(preferences.string(.noProfilesYet))
                    .foregroundStyle(.secondary)
            } else {
                List(session.profiles) { profile in
                    HStack {
                        Text(profile.displayName)
                        Spacer()
                        Button(preferences.string(.loginButton)) { attemptLogin(profile) }
                        Button(role: .destructive) {
                            session.deleteProfile(profile)
                        } label: {
                            Text(preferences.string(.deleteButton))
                        }
                    }
                }
                .frame(minHeight: 120)
            }

            Button(preferences.string(.createProfileButton)) { showingCreateProfile = true }
        }
        .padding(32)
        .frame(minWidth: 420, minHeight: 320)
        .sheet(isPresented: $showingCreateProfile) {
            CreateProfileView(session: session)
        }
        .sheet(item: $loginTarget) { profile in
            LoginView(session: session, profile: profile)
        }
        .onAppear { session.refreshProfiles() }
    }

    private func attemptLogin(_ profile: Profile) {
        Task {
            if await session.logInWithRememberedPassword(profile: profile) {
                return
            }
            loginTarget = profile
        }
    }
}
```

(Task 5 adds the profile icon here, Task 6 adds the delete confirmation dialog — both further modify this same file.)

- [ ] **Step 5: Localize `CreateProfileView`**

Replace the contents of `Sources/MyFin/Views/CreateProfileView.swift`:
```swift
import SwiftUI

struct CreateProfileView: View {
    @ObservedObject var session: AppSession
    @EnvironmentObject var preferences: AppPreferences
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var rememberPassword = false
    @State private var localError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(preferences.string(.createProfileTitle)).font(.title2.bold())

            TextField(preferences.string(.profileNameField), text: $displayName)
            RevealableSecureField(title: preferences.string(.passwordField), text: $password)
            RevealableSecureField(title: preferences.string(.confirmPasswordField), text: $confirmPassword)
            Toggle(preferences.string(.rememberPasswordToggle), isOn: $rememberPassword)

            Text(preferences.string(.passwordRecoveryWarning))
                .font(.caption)
                .foregroundStyle(.secondary)

            if let localError {
                Text(localError).foregroundStyle(.red)
            }

            HStack {
                Button(preferences.string(.cancelButton)) { dismiss() }
                Spacer()
                Button(preferences.string(.createButton)) { submit() }
                    .disabled(displayName.isEmpty || password.isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 360)
    }

    private func submit() {
        guard password == confirmPassword else {
            localError = preferences.string(.passwordsDoNotMatch)
            return
        }
        session.createProfile(displayName: displayName, password: password, remember: rememberPassword)
        if session.errorMessage == nil {
            dismiss()
        }
    }
}
```

- [ ] **Step 6: Localize `LoginView`**

Replace the contents of `Sources/MyFin/Views/LoginView.swift`:
```swift
import SwiftUI

struct LoginView: View {
    @ObservedObject var session: AppSession
    @EnvironmentObject var preferences: AppPreferences
    let profile: Profile
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(format: preferences.string(.loginTitleFormat), profile.displayName)).font(.title2.bold())
            RevealableSecureField(title: preferences.string(.passwordField), text: $password)
                .onSubmit { submit() }

            if let message = session.errorMessage {
                Text(message).foregroundStyle(.red)
            }

            HStack {
                Button(preferences.string(.cancelButton)) { dismiss() }
                Spacer()
                Button(preferences.string(.loginButton)) { submit() }
                    .disabled(password.isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 320)
    }

    private func submit() {
        session.logIn(profile: profile, password: password)
        if session.unlockedProfile?.id == profile.id {
            dismiss()
        }
    }
}
```

- [ ] **Step 7: Localize `MainShellView` and its `SidebarItem`**

Replace the contents of `Sources/MyFin/Views/MainShellView.swift`:
```swift
import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard
    case accounts
    case cashflow
    case assets
    case settings

    var id: String { rawValue }

    var labelKey: L10nKey {
        switch self {
        case .dashboard: return .sidebarDashboard
        case .accounts: return .sidebarAccounts
        case .cashflow: return .sidebarCashflow
        case .assets: return .sidebarAssets
        case .settings: return .sidebarSettings
        }
    }
}

struct MainShellView: View {
    @ObservedObject var session: AppSession
    @EnvironmentObject var preferences: AppPreferences
    @State private var selection: SidebarItem? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SidebarItem.allCases) { item in
                    Text(preferences.string(item.labelKey)).tag(item)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(session.unlockedProfile?.displayName ?? "MyFin")
        } detail: {
            switch selection {
            case .dashboard:
                PlaceholderPageView(title: preferences.string(.sidebarDashboard), message: preferences.string(.dashboardPlaceholder))
            case .accounts:
                PlaceholderPageView(title: preferences.string(.sidebarAccounts), message: preferences.string(.accountsPlaceholder))
            case .cashflow:
                PlaceholderPageView(title: preferences.string(.sidebarCashflow), message: preferences.string(.cashflowPlaceholder))
            case .assets:
                PlaceholderPageView(title: preferences.string(.sidebarAssets), message: preferences.string(.assetsPlaceholder))
            case .settings:
                SettingsView(session: session)
            case .none:
                PlaceholderPageView(title: "MyFin", message: preferences.string(.selectSectionMessage))
            }
        }
    }
}
```

- [ ] **Step 8: Localize `SettingsView`'s existing sections and add the appearance section**

Replace the contents of `Sources/MyFin/Views/SettingsView.swift`:
```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var session: AppSession
    @EnvironmentObject var preferences: AppPreferences
    @State private var newPassword = ""
    @State private var confirmNewPassword = ""
    @State private var localError: String?
    @State private var didChangePassword = false

    var body: some View {
        Form {
            Section(preferences.string(.changePasswordSectionTitle)) {
                RevealableSecureField(title: preferences.string(.newPasswordField), text: $newPassword)
                RevealableSecureField(title: preferences.string(.confirmNewPasswordField), text: $confirmNewPassword)
                if let localError {
                    Text(localError).foregroundStyle(.red)
                }
                if didChangePassword {
                    Text(preferences.string(.passwordChangedMessage)).foregroundStyle(.green)
                }
                Button(preferences.string(.changePasswordButton)) { changePassword() }
                    .disabled(newPassword.isEmpty)
            }

            Section(preferences.string(.appearanceSectionTitle)) {
                PreferencesControls()
            }

            Section {
                Button(preferences.string(.logOutButton), role: .destructive) {
                    session.logOut()
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func changePassword() {
        guard newPassword == confirmNewPassword else {
            localError = preferences.string(.passwordsDoNotMatch)
            didChangePassword = false
            return
        }
        session.changePassword(newPassword: newPassword)
        localError = session.errorMessage
        didChangePassword = (session.errorMessage == nil)
        newPassword = ""
        confirmNewPassword = ""
    }
}
```

(Task 5 adds a "Профиль"/"Profile" section above this one, further modifying this same file.)

- [ ] **Step 9: Ask the user to build, run, and manually verify**

```bash
swift build
swift run
```

Manual checklist:
1. Profile picker shows a theme picker and a language picker under the "MyFin" title.
2. Switching the language picker to English instantly changes every visible label (picker screen, "Создать профиль"/"Create Profile" sheet, etc.) with no restart.
3. Switching it back to Russian instantly restores the Russian labels.
4. Switching the theme picker to Dark/Light instantly changes the window's appearance; System follows the Mac's current appearance.
5. Log into an existing profile → the sidebar labels and placeholder pages reflect the currently selected language; Settings has the same theme/language controls under "Оформление и язык"/"Appearance & Language", and changing them there updates the picker screen too (same shared state) — log out to confirm.

Have the user confirm all five points before moving to Task 4.

---

### Task 4: Profile icon/color fields and `updateProfile`

**Files:**
- Create: `MyFin/Sources/MyFin/Models/ProfileIconPalette.swift`
- Modify: `MyFin/Sources/MyFin/Models/Profile.swift`
- Modify: `MyFin/Sources/MyFin/Services/ProfileStore.swift`
- Modify: `MyFin/Sources/MyFin/AppSession.swift`
- Modify: `MyFin/Tests/MyFinTests/ProfileStoreTests.swift`
- Modify: `MyFin/Tests/MyFinTests/AppSessionTests.swift`

**Interfaces:**
- Produces:
  - `enum ProfileIconPalette { static let iconNames: [String] (12 SF Symbol names); static let colorNames: [String] (8 names); static func color(named: String) -> Color }` — used by Task 5's UI.
  - `Profile` gains `var iconName: String`, `var iconColor: String`, with `static let defaultIconName`/`defaultIconColor`, and decodes legacy JSON (missing these keys) using the defaults.
  - `ProfileStore.updateProfile(_ profile: Profile) throws` — overwrites that profile's `profile.json`.
  - `AppSession.updateProfile(displayName: String, iconName: String, iconColor: String)` — updates `unlockedProfile` and persists via `ProfileStore.updateProfile`, used by Task 5's `SettingsView`.

- [ ] **Step 1: Create the icon/color vocabulary**

`Sources/MyFin/Models/ProfileIconPalette.swift`:
```swift
import SwiftUI

enum ProfileIconPalette {
    static let iconNames = [
        "person.crop.circle.fill",
        "star.circle.fill",
        "heart.circle.fill",
        "leaf.circle.fill",
        "bolt.circle.fill",
        "moon.circle.fill",
        "sun.max.circle.fill",
        "pawprint.circle.fill",
        "gift.circle.fill",
        "car.circle.fill",
        "airplane.circle.fill",
        "graduationcap.circle.fill"
    ]

    static let colorNames = ["blue", "green", "orange", "pink", "purple", "red", "teal", "yellow"]

    static func color(named name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "purple": return .purple
        case "red": return .red
        case "teal": return .teal
        case "yellow": return .yellow
        default: return .blue
        }
    }
}
```

- [ ] **Step 2: Write the failing tests for `Profile` decoding and `ProfileStore.updateProfile`**

Add these test methods to `Tests/MyFinTests/ProfileStoreTests.swift` (add them inside the existing `ProfileStoreTests` class, after `test_deleteProfile_whenMissing_throwsProfileNotFound`):
```swift
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
        {"id":"\\(profile.id.uuidString)","displayName":"Женя","createdAt":\\(profile.createdAt.timeIntervalSince1970)}
        """
        let metadataURL = store.profileDirectory(for: profile.id).appendingPathComponent("profile.json")
        try legacyJSON.write(to: metadataURL, atomically: true, encoding: .utf8)

        let profiles = try store.listProfiles()
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles[0].iconName, Profile.defaultIconName)
        XCTAssertEqual(profiles[0].iconColor, Profile.defaultIconColor)
    }
```

- [ ] **Step 3: Ask the user to run the tests and confirm they fail**

```bash
swift test --filter ProfileStoreTests
```
Expected: compilation errors (`Profile` has no member `iconName`/`iconColor`/`defaultIconName`, `ProfileStore` has no member `updateProfile`). Paste the output back.

- [ ] **Step 4: Update `Profile` with backward-compatible icon/color fields**

Replace the contents of `Sources/MyFin/Models/Profile.swift`:
```swift
import Foundation

struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    var displayName: String
    let createdAt: Date
    var iconName: String
    var iconColor: String

    static let defaultIconName = "person.crop.circle.fill"
    static let defaultIconColor = "blue"

    init(
        id: UUID,
        displayName: String,
        createdAt: Date,
        iconName: String = Profile.defaultIconName,
        iconColor: String = Profile.defaultIconColor
    ) {
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
        self.iconName = iconName
        self.iconColor = iconColor
    }

    enum CodingKeys: String, CodingKey {
        case id, displayName, createdAt, iconName, iconColor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? Profile.defaultIconName
        iconColor = try container.decodeIfPresent(String.self, forKey: .iconColor) ?? Profile.defaultIconColor
    }
}
```

- [ ] **Step 5: Add `ProfileStore.updateProfile`**

In `Sources/MyFin/Services/ProfileStore.swift`, add this method inside the `ProfileStore` struct, directly after `createProfileDirectory`:
```swift
    func updateProfile(_ profile: Profile) throws {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            try encoder.encode(profile).write(to: metadataURL(for: profile.id))
        } catch {
            throw ProfileStoreError.ioFailure(error.localizedDescription)
        }
    }
```

- [ ] **Step 6: Ask the user to re-run the tests and confirm they pass**

```bash
swift test --filter ProfileStoreTests
```
Expected: all 8 tests in this file pass (5 original + 3 new). Paste the output back.

- [ ] **Step 7: Write the failing test for `AppSession.updateProfile`**

Add this test method to `Tests/MyFinTests/AppSessionTests.swift` (inside the existing `AppSessionTests` class, after `test_deleteProfile_removesItFromList`):
```swift
    func test_updateProfile_updatesUnlockedProfileAndProfilesList() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)

        session.updateProfile(displayName: "Евгений", iconName: "star.circle.fill", iconColor: "purple")

        XCTAssertEqual(session.unlockedProfile?.displayName, "Евгений")
        XCTAssertEqual(session.unlockedProfile?.iconName, "star.circle.fill")
        XCTAssertEqual(session.unlockedProfile?.iconColor, "purple")
        XCTAssertEqual(session.profiles.first?.displayName, "Евгений")
        XCTAssertNil(session.errorMessage)
    }
```

- [ ] **Step 8: Ask the user to run the test and confirm it fails**

```bash
swift test --filter AppSessionTests
```
Expected: compilation error (`AppSession` has no member `updateProfile`). Paste the output back.

- [ ] **Step 9: Add `AppSession.updateProfile`**

In `Sources/MyFin/AppSession.swift`, add this method inside the `AppSession` class, directly after `changePassword`:
```swift
    func updateProfile(displayName: String, iconName: String, iconColor: String) {
        guard var profile = unlockedProfile else { return }
        profile.displayName = displayName
        profile.iconName = iconName
        profile.iconColor = iconColor
        do {
            try profileStore.updateProfile(profile)
            unlockedProfile = profile
            errorMessage = nil
            refreshProfiles()
        } catch {
            errorMessage = "Не удалось обновить профиль: \(error.localizedDescription)"
        }
    }
```

- [ ] **Step 10: Ask the user to re-run the tests and confirm they pass**

```bash
swift test --filter AppSessionTests
```
Expected: all 9 tests in this file pass (8 original + 1 new). Paste the output back.

---

### Task 5: Rename & icon editing UI

**Files:**
- Modify: `MyFin/Sources/MyFin/Views/SettingsView.swift`
- Modify: `MyFin/Sources/MyFin/Views/ProfilePickerView.swift`

**Interfaces:**
- Consumes: `ProfileIconPalette`, `AppSession.updateProfile(displayName:iconName:iconColor:)`, `Profile.defaultIconName`/`.defaultIconColor` (Task 4); `PreferencesControls`, `L10nKey`/`preferences.string(_:)` (Tasks 1–3).

No new automated tests (pure UI over the already-tested `AppSession.updateProfile`) — verified with the manual checklist in Step 3.

- [ ] **Step 1: Add the "Профиль"/"Profile" section to `SettingsView`**

Replace the contents of `Sources/MyFin/Views/SettingsView.swift`:
```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var session: AppSession
    @EnvironmentObject var preferences: AppPreferences

    @State private var editedName: String = ""
    @State private var editedIconName: String = Profile.defaultIconName
    @State private var editedIconColor: String = Profile.defaultIconColor
    @State private var didUpdateProfile = false

    @State private var newPassword = ""
    @State private var confirmNewPassword = ""
    @State private var localError: String?
    @State private var didChangePassword = false

    private let iconColumns = [GridItem(.adaptive(minimum: 40))]

    var body: some View {
        Form {
            Section(preferences.string(.profileSectionTitle)) {
                TextField(preferences.string(.profileNameField), text: $editedName)

                Text(preferences.string(.iconLabel)).font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: iconColumns, spacing: 8) {
                    ForEach(ProfileIconPalette.iconNames, id: \.self) { icon in
                        Button {
                            editedIconName = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundStyle(ProfileIconPalette.color(named: editedIconColor))
                                .padding(6)
                                .background(
                                    Circle().stroke(icon == editedIconName ? ProfileIconPalette.color(named: editedIconColor) : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(preferences.string(.colorLabel)).font(.caption).foregroundStyle(.secondary)
                HStack {
                    ForEach(ProfileIconPalette.colorNames, id: \.self) { colorName in
                        Button {
                            editedIconColor = colorName
                        } label: {
                            Circle()
                                .fill(ProfileIconPalette.color(named: colorName))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle().stroke(Color.primary, lineWidth: colorName == editedIconColor ? 2 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if didUpdateProfile {
                    Text(preferences.string(.profileUpdatedMessage)).foregroundStyle(.green)
                }

                Button(preferences.string(.saveButton)) { saveProfile() }
                    .disabled(editedName.isEmpty)
            }

            Section(preferences.string(.changePasswordSectionTitle)) {
                RevealableSecureField(title: preferences.string(.newPasswordField), text: $newPassword)
                RevealableSecureField(title: preferences.string(.confirmNewPasswordField), text: $confirmNewPassword)
                if let localError {
                    Text(localError).foregroundStyle(.red)
                }
                if didChangePassword {
                    Text(preferences.string(.passwordChangedMessage)).foregroundStyle(.green)
                }
                Button(preferences.string(.changePasswordButton)) { changePassword() }
                    .disabled(newPassword.isEmpty)
            }

            Section(preferences.string(.appearanceSectionTitle)) {
                PreferencesControls()
            }

            Section {
                Button(preferences.string(.logOutButton), role: .destructive) {
                    session.logOut()
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            editedName = session.unlockedProfile?.displayName ?? ""
            editedIconName = session.unlockedProfile?.iconName ?? Profile.defaultIconName
            editedIconColor = session.unlockedProfile?.iconColor ?? Profile.defaultIconColor
        }
    }

    private func saveProfile() {
        session.updateProfile(displayName: editedName, iconName: editedIconName, iconColor: editedIconColor)
        didUpdateProfile = (session.errorMessage == nil)
    }

    private func changePassword() {
        guard newPassword == confirmNewPassword else {
            localError = preferences.string(.passwordsDoNotMatch)
            didChangePassword = false
            return
        }
        session.changePassword(newPassword: newPassword)
        localError = session.errorMessage
        didChangePassword = (session.errorMessage == nil)
        newPassword = ""
        confirmNewPassword = ""
    }
}
```

- [ ] **Step 2: Show each profile's icon in `ProfilePickerView`'s list**

Replace the contents of `Sources/MyFin/Views/ProfilePickerView.swift`:
```swift
import SwiftUI

struct ProfilePickerView: View {
    @ObservedObject var session: AppSession
    @EnvironmentObject var preferences: AppPreferences
    @State private var showingCreateProfile = false
    @State private var loginTarget: Profile?

    var body: some View {
        VStack(spacing: 16) {
            Text("MyFin").font(.largeTitle.bold())
            PreferencesControls()

            if session.profiles.isEmpty {
                Text(preferences.string(.noProfilesYet))
                    .foregroundStyle(.secondary)
            } else {
                List(session.profiles) { profile in
                    HStack {
                        Image(systemName: profile.iconName)
                            .foregroundStyle(ProfileIconPalette.color(named: profile.iconColor))
                        Text(profile.displayName)
                        Spacer()
                        Button(preferences.string(.loginButton)) { attemptLogin(profile) }
                        Button(role: .destructive) {
                            session.deleteProfile(profile)
                        } label: {
                            Text(preferences.string(.deleteButton))
                        }
                    }
                }
                .frame(minHeight: 120)
            }

            Button(preferences.string(.createProfileButton)) { showingCreateProfile = true }
        }
        .padding(32)
        .frame(minWidth: 420, minHeight: 320)
        .sheet(isPresented: $showingCreateProfile) {
            CreateProfileView(session: session)
        }
        .sheet(item: $loginTarget) { profile in
            LoginView(session: session, profile: profile)
        }
        .onAppear { session.refreshProfiles() }
    }

    private func attemptLogin(_ profile: Profile) {
        Task {
            if await session.logInWithRememberedPassword(profile: profile) {
                return
            }
            loginTarget = profile
        }
    }
}
```

(Task 6 adds the delete confirmation dialog, further modifying this same file.)

- [ ] **Step 3: Ask the user to build, run, and manually verify**

```bash
swift build
swift run
```

Manual checklist:
1. Log into a profile → open Настройки/Settings → see a "Профиль"/"Profile" section at the top with the current name pre-filled, a grid of 12 icons, and a row of 8 color swatches.
2. Pick a different icon and color, change the name, click "Сохранить"/"Save" → "Профиль обновлён"/"Profile updated" appears.
3. Log out → the profile picker's list now shows the new name and the chosen icon/color next to it.
4. Log back in → Settings shows the saved name/icon/color pre-filled (persisted correctly).

Have the user confirm all four points before moving to Task 6.

---

### Task 6: Delete confirmation dialog

**Files:**
- Modify: `MyFin/Sources/MyFin/Views/ProfilePickerView.swift`

**Interfaces:**
- Consumes: `AppSession.deleteProfile(_:)` (unchanged, existing), `L10nKey.deleteProfileConfirmTitleFormat`/`.deleteProfileConfirmMessage` (Task 1).

No new automated tests — `AppSession.deleteProfile` itself is unchanged and already covered by `test_deleteProfile_removesItFromList`; this task only adds a UI guard rail in front of the existing call. Verified with the manual checklist in Step 2.

- [ ] **Step 1: Add the confirmation dialog**

Replace the contents of `Sources/MyFin/Views/ProfilePickerView.swift`:
```swift
import SwiftUI

struct ProfilePickerView: View {
    @ObservedObject var session: AppSession
    @EnvironmentObject var preferences: AppPreferences
    @State private var showingCreateProfile = false
    @State private var loginTarget: Profile?
    @State private var profileToDelete: Profile?

    var body: some View {
        VStack(spacing: 16) {
            Text("MyFin").font(.largeTitle.bold())
            PreferencesControls()

            if session.profiles.isEmpty {
                Text(preferences.string(.noProfilesYet))
                    .foregroundStyle(.secondary)
            } else {
                List(session.profiles) { profile in
                    HStack {
                        Image(systemName: profile.iconName)
                            .foregroundStyle(ProfileIconPalette.color(named: profile.iconColor))
                        Text(profile.displayName)
                        Spacer()
                        Button(preferences.string(.loginButton)) { attemptLogin(profile) }
                        Button(role: .destructive) {
                            profileToDelete = profile
                        } label: {
                            Text(preferences.string(.deleteButton))
                        }
                    }
                }
                .frame(minHeight: 120)
            }

            Button(preferences.string(.createProfileButton)) { showingCreateProfile = true }
        }
        .padding(32)
        .frame(minWidth: 420, minHeight: 320)
        .sheet(isPresented: $showingCreateProfile) {
            CreateProfileView(session: session)
        }
        .sheet(item: $loginTarget) { profile in
            LoginView(session: session, profile: profile)
        }
        .confirmationDialog(
            deleteConfirmationTitle,
            isPresented: Binding(
                get: { profileToDelete != nil },
                set: { isPresented in if !isPresented { profileToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(preferences.string(.deleteButton), role: .destructive) {
                if let profile = profileToDelete {
                    session.deleteProfile(profile)
                }
                profileToDelete = nil
            }
            Button(preferences.string(.cancelButton), role: .cancel) {
                profileToDelete = nil
            }
        } message: {
            Text(preferences.string(.deleteProfileConfirmMessage))
        }
        .onAppear { session.refreshProfiles() }
    }

    private var deleteConfirmationTitle: String {
        String(format: preferences.string(.deleteProfileConfirmTitleFormat), profileToDelete?.displayName ?? "")
    }

    private func attemptLogin(_ profile: Profile) {
        Task {
            if await session.logInWithRememberedPassword(profile: profile) {
                return
            }
            loginTarget = profile
        }
    }
}
```

- [ ] **Step 2: Ask the user to build, run, and manually verify**

```bash
swift build
swift run
```

Manual checklist:
1. Click "Удалить"/"Delete" next to a profile → a confirmation dialog appears with the title "Удалить профиль «Имя»?"/"Delete profile \"Name\"?" and the message "Это действие необратимо."/"This action cannot be undone."
2. Clicking "Отмена"/"Cancel" dismisses the dialog and the profile is still listed.
3. Clicking "Удалить"/"Delete" in the dialog actually removes the profile from the list.
4. Switch the language picker and repeat step 1 to confirm the dialog's text is also localized.

- [ ] **Step 3: Ask the user to run the full test suite one final time**

```bash
swift test
```
Expected: all tests pass (21 from the original shell plan + 3 `LocalizationTests`-equivalent + 4 `AppPreferencesTests` + 3 new `ProfileStoreTests` + 1 new `AppSessionTests` = 32 total). Paste the output back — this closes out the plan.

---

## Self-Review Notes

- **Spec coverage:** theme (Task 3) ✓, language with instant switching via the custom `Localization`/`AppPreferences` layer (Tasks 1–3) ✓, rename (Task 5) ✓, icon+color (Tasks 4–5) ✓, legacy `profile.json` decoding (Task 4) ✓, delete confirmation (Task 6) ✓, shared picker on both the picker screen and Settings (Tasks 3, 5) ✓.
- **Type consistency checked:** `AppPreferences`, `AppTheme`, `AppLanguage`, `L10nKey`, `Localization`, `ProfileIconPalette`, `Profile.defaultIconName`/`.defaultIconColor`, `ProfileStore.updateProfile`, `AppSession.updateProfile(displayName:iconName:iconColor:)`, and `PreferencesControls` are named and typed identically everywhere they're used across tasks.
- **No placeholders:** every step contains complete, runnable code; every "Modify" step gives the full resulting file rather than a diff, so there's no ambiguity about the end state after a file is touched by multiple tasks (`ProfilePickerView` by Tasks 3/5/6, `SettingsView` by Tasks 3/5).
