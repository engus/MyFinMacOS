import Foundation

@MainActor
final class AppSession: ObservableObject {
    enum Screen: Equatable {
        case profilePicker
        case mainShell
        case onboarding
    }

    @Published var screen: Screen = .profilePicker
    @Published var profiles: [Profile] = []
    @Published var errorMessage: String?
    @Published private(set) var numberFormatPreferences = NumberFormatPreferences()
    @Published private(set) var baseCurrency: Currency = .usd
    @Published private(set) var sidebarGroupingMode: SidebarGroupingMode = .institution
    @Published private(set) var showOriginalCurrencies: Bool = false

    private(set) var unlockedProfile: Profile?
    private(set) var connection: DatabaseConnection?

    let profileStore: ProfileStore
    let keychain: KeychainService
    let authenticator: BiometricAuthenticating

    init(
        profileStore: ProfileStore = ProfileStore(),
        keychain: KeychainService = KeychainService(service: "com.myfin.local"),
        authenticator: BiometricAuthenticating = DeviceAuthenticator()
    ) {
        self.profileStore = profileStore
        self.keychain = keychain
        self.authenticator = authenticator
        refreshProfiles()
    }

    func refreshProfiles() {
        profiles = (try? profileStore.listProfiles()) ?? []
    }

    func createProfile(displayName: String, password: String, remember: Bool) {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let isDuplicate = profiles.contains {
            $0.displayName.caseInsensitiveCompare(trimmedName) == .orderedSame
        }
        guard !isDuplicate else {
            errorMessage = "Профиль с таким именем уже существует"
            return
        }

        do {
            let profile = try profileStore.createProfileDirectory(displayName: trimmedName)
            let connection = try DatabaseConnection.open(at: profileStore.databaseURL(for: profile.id), password: password)
            if remember {
                try? keychain.savePassword(password, for: profile.id)
            }
            self.connection = connection
            self.unlockedProfile = profile
            self.numberFormatPreferences = NumberFormatPreferencesService(connection: connection).load()
            let institutions = InstitutionService(connection: connection)
            let accountService = AccountService(connection: connection, institutionService: institutions)
            self.baseCurrency = DashboardService(connection: connection, accountService: accountService, exchangeRateProvider: HardcodedExchangeRateProvider()).baseCurrency()
            let groupingRows = (try? connection.query("SELECT value FROM profile_settings WHERE key = 'sidebarGroupingMode';")) ?? []
            if case let .text(raw)? = groupingRows.first?["value"], let mode = SidebarGroupingMode(rawValue: raw) {
                self.sidebarGroupingMode = mode
            } else {
                self.sidebarGroupingMode = .institution
            }
            let originalCurrenciesRows = (try? connection.query("SELECT value FROM profile_settings WHERE key = 'showOriginalCurrencies';")) ?? []
            self.showOriginalCurrencies = (originalCurrenciesRows.first?["value"] == .text("true"))
            self.errorMessage = nil
            self.screen = profile.hasCompletedOnboarding ? .mainShell : .onboarding
            refreshProfiles()
        } catch {
            errorMessage = "Не удалось создать профиль: \(error.localizedDescription)"
        }
    }

    func logIn(profile: Profile, password: String) {
        do {
            let connection = try DatabaseConnection.open(at: profileStore.databaseURL(for: profile.id), password: password)
            self.connection = connection
            self.unlockedProfile = profile
            self.numberFormatPreferences = NumberFormatPreferencesService(connection: connection).load()
            let institutions = InstitutionService(connection: connection)
            let accountService = AccountService(connection: connection, institutionService: institutions)
            self.baseCurrency = DashboardService(connection: connection, accountService: accountService, exchangeRateProvider: HardcodedExchangeRateProvider()).baseCurrency()
            let groupingRows = (try? connection.query("SELECT value FROM profile_settings WHERE key = 'sidebarGroupingMode';")) ?? []
            if case let .text(raw)? = groupingRows.first?["value"], let mode = SidebarGroupingMode(rawValue: raw) {
                self.sidebarGroupingMode = mode
            } else {
                self.sidebarGroupingMode = .institution
            }
            let originalCurrenciesRows = (try? connection.query("SELECT value FROM profile_settings WHERE key = 'showOriginalCurrencies';")) ?? []
            self.showOriginalCurrencies = (originalCurrenciesRows.first?["value"] == .text("true"))
            self.errorMessage = nil
            self.screen = profile.hasCompletedOnboarding ? .mainShell : .onboarding
        } catch DatabaseError.wrongPassword {
            errorMessage = "Неверный пароль"
        } catch {
            errorMessage = "Не удалось открыть профиль: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func logInWithRememberedPassword(profile: Profile) async -> Bool {
        guard keychain.hasSavedPassword(for: profile.id) else { return false }

        let authorized = await authenticator.authenticate(
            reason: "Войти в профиль «\(profile.displayName)»"
        )
        guard authorized else { return false }

        guard let password = keychain.readPassword(for: profile.id) else { return false }
        logIn(profile: profile, password: password)
        return unlockedProfile?.id == profile.id
    }

    /// Deletes the currently unlocked profile, but only after re-verifying its
    /// password: attempts to open a throwaway connection to its encrypted
    /// database with the given password (reusing SQLCipher's own wrong-password
    /// detection), and only proceeds with deletion if that succeeds. This is
    /// intentionally scoped to `unlockedProfile` only — there is no way to
    /// delete a profile you are not currently logged into, since that would
    /// let anyone at the picker screen delete someone else's profile without
    /// ever knowing its password.
    func deleteCurrentProfile(confirmingWithPassword password: String) {
        guard let profile = unlockedProfile else { return }

        do {
            let verification = try DatabaseConnection.open(at: profileStore.databaseURL(for: profile.id), password: password)
            verification.close()
        } catch DatabaseError.wrongPassword {
            errorMessage = "Неверный пароль"
            return
        } catch {
            errorMessage = "Не удалось проверить пароль: \(error.localizedDescription)"
            return
        }

        connection?.close()
        connection = nil
        keychain.deletePassword(for: profile.id)
        try? profileStore.deleteProfile(id: profile.id)
        unlockedProfile = nil
        errorMessage = nil
        screen = .profilePicker
        refreshProfiles()
    }

    func completeOnboarding() {
        guard var profile = unlockedProfile else { return }
        profile.hasCompletedOnboarding = true
        do {
            try profileStore.updateProfile(profile)
            unlockedProfile = profile
            screen = .mainShell
            refreshProfiles()
        } catch {
            errorMessage = "Не удалось обновить профиль: \(error.localizedDescription)"
        }
    }

    func logOut() {
        connection?.close()
        connection = nil
        unlockedProfile = nil
        errorMessage = nil
        screen = .profilePicker
        refreshProfiles()
    }

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

    func updateNumberFormatPreferences(_ preferences: NumberFormatPreferences) {
        guard let connection else { return }
        try? NumberFormatPreferencesService(connection: connection).save(preferences)
        numberFormatPreferences = preferences
    }

    func updateBaseCurrency(_ currency: Currency) {
        guard let connection else { return }
        let institutions = InstitutionService(connection: connection)
        let accountService = AccountService(connection: connection, institutionService: institutions)
        let dashboard = DashboardService(connection: connection, accountService: accountService, exchangeRateProvider: HardcodedExchangeRateProvider())
        try? dashboard.setBaseCurrency(currency)
        baseCurrency = currency
    }

    func updateSidebarGroupingMode(_ mode: SidebarGroupingMode) {
        guard let connection else { return }
        try? connection.execute(
            "INSERT INTO profile_settings (key, value) VALUES ('sidebarGroupingMode', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
            params: [.text(mode.rawValue)]
        )
        sidebarGroupingMode = mode
    }

    func updateShowOriginalCurrencies(_ show: Bool) {
        guard let connection else { return }
        try? connection.execute(
            "INSERT INTO profile_settings (key, value) VALUES ('showOriginalCurrencies', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
            params: [.text(show ? "true" : "false")]
        )
        showOriginalCurrencies = show
    }

    func changePassword(currentPassword: String, newPassword: String) {
        guard let connection, let profile = unlockedProfile else { return }

        do {
            let verification = try DatabaseConnection.open(at: profileStore.databaseURL(for: profile.id), password: currentPassword)
            verification.close()
        } catch DatabaseError.wrongPassword {
            errorMessage = "Неверный пароль"
            return
        } catch {
            errorMessage = "Не удалось проверить пароль: \(error.localizedDescription)"
            return
        }

        do {
            try connection.rekey(newPassword: newPassword)
            if keychain.readPassword(for: profile.id) != nil {
                try? keychain.savePassword(newPassword, for: profile.id)
            }
            errorMessage = nil
        } catch {
            errorMessage = "Не удалось сменить пароль: \(error.localizedDescription)"
        }
    }
}
