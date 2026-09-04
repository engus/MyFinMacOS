import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case institutions

    var id: String { rawValue }
}

enum BaseCurrencySelection: Hashable {
    case currency(Currency)
    case original
}

struct SettingsView: View {
    @ObservedObject var session: AppSession
    @EnvironmentObject var preferences: AppPreferences
    @State private var selectedTab: SettingsTab = .general

    @State private var editedName: String = ""
    @State private var editedIconName: String = Profile.defaultIconName
    @State private var editedIconColor: String = Profile.defaultIconColor
    @State private var didUpdateProfile = false

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmNewPassword = ""
    @State private var localError: String?
    @State private var didChangePassword = false
    @State private var showingDeleteProfile = false
    @State private var baseCurrencySelection: BaseCurrencySelection = .currency(.usd)
    @State private var numberFormatPreferences = NumberFormatPreferences()
    @State private var sidebarGroupingMode: SidebarGroupingMode = .institution

    private let iconColumns = [GridItem(.adaptive(minimum: 40))]

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text(preferences.string(.settingsTabGeneral)).tag(SettingsTab.general)
                Text(preferences.string(.settingsTabInstitutions)).tag(SettingsTab.institutions)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding([.horizontal, .top], 24)

            switch selectedTab {
            case .general:
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
                        RevealableSecureField(title: preferences.string(.currentPasswordField), text: $currentPassword)
                        RevealableSecureField(title: preferences.string(.newPasswordField), text: $newPassword)
                        RevealableSecureField(title: preferences.string(.confirmNewPasswordField), text: $confirmNewPassword)
                        if let localError {
                            Text(localError).foregroundStyle(.red)
                        }
                        if didChangePassword {
                            Text(preferences.string(.passwordChangedMessage)).foregroundStyle(.green)
                        }
                        Button(preferences.string(.changePasswordButton)) { changePassword() }
                            .disabled(currentPassword.isEmpty || newPassword.isEmpty)
                    }

                    Section(preferences.string(.appearanceSectionTitle)) {
                        PreferencesControls()
                    }

                    Section(preferences.string(.baseCurrencySectionTitle)) {
                        Picker(preferences.string(.baseCurrencyPickerLabel), selection: $baseCurrencySelection) {
                            ForEach(Currency.allCases, id: \.self) { currency in
                                Text(currency.rawValue).tag(BaseCurrencySelection.currency(currency))
                            }
                            Text(preferences.string(.originalCurrenciesLabel)).tag(BaseCurrencySelection.original)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: baseCurrencySelection) { newValue in
                            switch newValue {
                            case .currency(let currency):
                                session.updateBaseCurrency(currency)
                                session.updateShowOriginalCurrencies(false)
                            case .original:
                                session.updateShowOriginalCurrencies(true)
                            }
                        }
                    }

                    Section(preferences.string(.numberFormatSectionTitle)) {
                        Picker(preferences.string(.decimalSeparatorFieldLabel), selection: $numberFormatPreferences.useCommaDecimalSeparator) {
                            Text(".").tag(false)
                            Text(",").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: numberFormatPreferences.useCommaDecimalSeparator) { _ in
                            session.updateNumberFormatPreferences(numberFormatPreferences)
                        }

                        Picker(preferences.string(.maxDecimalPlacesFieldLabel), selection: $numberFormatPreferences.maxDecimalPlaces) {
                            Text("0").tag(0)
                            Text("1").tag(1)
                            Text("2").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: numberFormatPreferences.maxDecimalPlaces) { _ in
                            session.updateNumberFormatPreferences(numberFormatPreferences)
                        }

                        Picker(preferences.string(.largeNumberNotationFieldLabel), selection: $numberFormatPreferences.useCompactNotation) {
                            Text(preferences.string(.notationFullLabel)).tag(false)
                            Text(preferences.string(.notationCompactLabel)).tag(true)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: numberFormatPreferences.useCompactNotation) { _ in
                            session.updateNumberFormatPreferences(numberFormatPreferences)
                        }

                        Picker(preferences.string(.trailingZeroesFieldLabel), selection: $numberFormatPreferences.hideTrailingZeroes) {
                            Text(preferences.string(.trailingZeroesShowLabel)).tag(false)
                            Text(preferences.string(.trailingZeroesHideLabel)).tag(true)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: numberFormatPreferences.hideTrailingZeroes) { _ in
                            session.updateNumberFormatPreferences(numberFormatPreferences)
                        }
                    }

                    Section(preferences.string(.sidebarGroupingSectionTitle)) {
                        Picker(preferences.string(.sidebarGroupingModeFieldLabel), selection: $sidebarGroupingMode) {
                            Text(preferences.string(.groupByInstitutionLabel)).tag(SidebarGroupingMode.institution)
                            Text(preferences.string(.groupByCurrencyLabel)).tag(SidebarGroupingMode.currency)
                            Text(preferences.string(.groupByCountryLabel)).tag(SidebarGroupingMode.country)
                            Text(preferences.string(.groupByTypeLabel)).tag(SidebarGroupingMode.type)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: sidebarGroupingMode) { newValue in
                            session.updateSidebarGroupingMode(newValue)
                        }
                    }

                    Section {
                        Button(preferences.string(.logOutButton), role: .destructive) {
                            session.logOut()
                        }
                    }

                    Section {
                        Button(preferences.string(.deleteButton), role: .destructive) {
                            showingDeleteProfile = true
                        }
                    }
                }
                .padding(24)
            case .institutions:
                CustomInstitutionsView(session: session)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            editedName = session.unlockedProfile?.displayName ?? ""
            editedIconName = session.unlockedProfile?.iconName ?? Profile.defaultIconName
            editedIconColor = session.unlockedProfile?.iconColor ?? Profile.defaultIconColor
            baseCurrencySelection = session.showOriginalCurrencies ? .original : .currency(session.baseCurrency)
            numberFormatPreferences = session.numberFormatPreferences
            sidebarGroupingMode = session.sidebarGroupingMode
        }
        .sheet(isPresented: $showingDeleteProfile) {
            DeleteProfileView(session: session)
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
        session.changePassword(currentPassword: currentPassword, newPassword: newPassword)
        localError = session.errorMessage
        didChangePassword = (session.errorMessage == nil)
        currentPassword = ""
        newPassword = ""
        confirmNewPassword = ""
    }
}
