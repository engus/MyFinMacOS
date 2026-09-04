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
    case currentPasswordField
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
    case showArchivedToggle
    case createAccountButton
    case editButton
    case archiveButton
    case restoreButton
    case activeStatusLabel
    case archivedStatusLabel
    case noAccountsYet
    case otherBankLabel
    case customBankNameField
    case backToListButton
    case bankFieldLabel
    case cashFieldLabel
    case countryFieldLabel
    case typeFieldLabel
    case currencyFieldLabel
    case balanceTodayFieldLabel
    case accountNameFieldLabel
    case specifyBalanceDateToggle
    case balanceDateFieldLabel
    case saveAccountButton
    case invalidCustomBankNameMessage
    case negativeBalanceMessage
    case tooManyDecimalDigitsMessage
    case institutionRequiredMessage
    case totalBalanceLabel
    case baseCurrencySectionTitle
    case baseCurrencyPickerLabel
    case settingsTabGeneral
    case settingsTabInstitutions
    case addCustomInstitutionButton
    case noCustomInstitutionsYet
    case institutionInUseMessage
    case institutionArchivedConflictMessage
    case activeAccountsSectionTitle
    case archivedAccountsSectionTitle
    case numberFormatSectionTitle
    case decimalSeparatorFieldLabel
    case maxDecimalPlacesFieldLabel
    case largeNumberNotationFieldLabel
    case trailingZeroesFieldLabel
    case notationFullLabel
    case notationCompactLabel
    case trailingZeroesShowLabel
    case trailingZeroesHideLabel
    case sidebarGroupingSectionTitle
    case sidebarGroupingModeFieldLabel
    case groupByInstitutionLabel
    case groupByCurrencyLabel
    case groupByCountryLabel
    case groupByTypeLabel
    case originalCurrenciesLabel
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
        .currentPasswordField: "Текущий пароль",
        .newPasswordField: "Новый пароль",
        .confirmNewPasswordField: "Повторите новый пароль",
        .passwordChangedMessage: "Пароль изменён",
        .changePasswordButton: "Сменить пароль",
        .logOutButton: "Выйти из профиля",
        .sidebarDashboard: "Дашборд",
        .sidebarAccounts: "Счета",
        .sidebarCashflow: "Доходы и расходы",
        .sidebarAssets: "Активы",
        .sidebarSettings: "Настройки",
        .dashboardPlaceholder: "Дашборд — здесь скоро появится содержимое",
        .accountsPlaceholder: "Аккаунты — здесь скоро появится содержимое",
        .cashflowPlaceholder: "Доходы и расходы — здесь скоро появится содержимое",
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
        .showArchivedToggle: "Показать архивные",
        .createAccountButton: "Создать счёт",
        .editButton: "Изменить",
        .archiveButton: "Архивировать",
        .restoreButton: "Восстановить",
        .activeStatusLabel: "Активен",
        .archivedStatusLabel: "Архивирован",
        .noAccountsYet: "Пока нет счетов",
        .otherBankLabel: "Другой банк",
        .customBankNameField: "Название банка",
        .backToListButton: "Назад к списку",
        .bankFieldLabel: "Банк",
        .cashFieldLabel: "Наличные",
        .countryFieldLabel: "Страна",
        .typeFieldLabel: "Тип",
        .currencyFieldLabel: "Валюта",
        .balanceTodayFieldLabel: "Баланс сегодня",
        .accountNameFieldLabel: "Название счёта",
        .specifyBalanceDateToggle: "Указать дату баланса",
        .balanceDateFieldLabel: "Дата баланса",
        .saveAccountButton: "Сохранить",
        .invalidCustomBankNameMessage: "Введите название банка",
        .negativeBalanceMessage: "Баланс не может быть отрицательным",
        .tooManyDecimalDigitsMessage: "Слишком много знаков после запятой",
        .institutionRequiredMessage: "Выберите банк",
        .totalBalanceLabel: "Общий баланс",
        .baseCurrencySectionTitle: "Базовая валюта",
        .baseCurrencyPickerLabel: "Валюта отображения",
        .settingsTabGeneral: "Общее",
        .settingsTabInstitutions: "Банки",
        .addCustomInstitutionButton: "Добавить банк",
        .noCustomInstitutionsYet: "Пока нет добавленных банков",
        .institutionInUseMessage: "Нельзя сменить страну — банк уже используется в счетах",
        .institutionArchivedConflictMessage: "Банк с таким названием уже существует в архиве — восстановите его из списка",
        .activeAccountsSectionTitle: "Активные счета",
        .archivedAccountsSectionTitle: "Архивные счета",
        .numberFormatSectionTitle: "Формат чисел",
        .decimalSeparatorFieldLabel: "Разделитель дробной части",
        .maxDecimalPlacesFieldLabel: "Знаков после запятой",
        .largeNumberNotationFieldLabel: "Крупные числа",
        .trailingZeroesFieldLabel: "Незначащие нули",
        .notationFullLabel: "Полностью",
        .notationCompactLabel: "Сокращённо",
        .trailingZeroesShowLabel: "Показывать",
        .trailingZeroesHideLabel: "Скрывать",
        .sidebarGroupingSectionTitle: "Группировка сайдбара",
        .sidebarGroupingModeFieldLabel: "Режим группировки",
        .groupByInstitutionLabel: "Банк",
        .groupByCurrencyLabel: "Валюта",
        .groupByCountryLabel: "Страна",
        .groupByTypeLabel: "Тип",
        .originalCurrenciesLabel: "Оригинальные валюты",
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
        .currentPasswordField: "Current Password",
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
        .showArchivedToggle: "Show archived",
        .createAccountButton: "Create account",
        .editButton: "Edit",
        .archiveButton: "Archive",
        .restoreButton: "Restore",
        .activeStatusLabel: "Active",
        .archivedStatusLabel: "Archived",
        .noAccountsYet: "No accounts yet",
        .otherBankLabel: "Other bank",
        .customBankNameField: "Bank name",
        .backToListButton: "Back to list",
        .bankFieldLabel: "Bank",
        .cashFieldLabel: "Cash",
        .countryFieldLabel: "Country",
        .typeFieldLabel: "Type",
        .currencyFieldLabel: "Currency",
        .balanceTodayFieldLabel: "Balance today",
        .accountNameFieldLabel: "Account name",
        .specifyBalanceDateToggle: "Specify a balance date",
        .balanceDateFieldLabel: "Balance date",
        .saveAccountButton: "Save",
        .invalidCustomBankNameMessage: "Enter a bank name",
        .negativeBalanceMessage: "Balance cannot be negative",
        .tooManyDecimalDigitsMessage: "Too many decimal digits",
        .institutionRequiredMessage: "Select a bank",
        .totalBalanceLabel: "Total balance",
        .baseCurrencySectionTitle: "Base currency",
        .baseCurrencyPickerLabel: "Display currency",
        .settingsTabGeneral: "General",
        .settingsTabInstitutions: "Banks",
        .addCustomInstitutionButton: "Add bank",
        .noCustomInstitutionsYet: "No custom banks yet",
        .institutionInUseMessage: "Can't change country — this bank is already used by an account",
        .institutionArchivedConflictMessage: "A bank with this name already exists, archived — restore it from the list instead",
        .activeAccountsSectionTitle: "Active accounts",
        .archivedAccountsSectionTitle: "Archived accounts",
        .numberFormatSectionTitle: "Number format",
        .decimalSeparatorFieldLabel: "Decimal separator",
        .maxDecimalPlacesFieldLabel: "Decimal places",
        .largeNumberNotationFieldLabel: "Large numbers",
        .trailingZeroesFieldLabel: "Trailing zeroes",
        .notationFullLabel: "Full",
        .notationCompactLabel: "Compact",
        .trailingZeroesShowLabel: "Show",
        .trailingZeroesHideLabel: "Hide",
        .sidebarGroupingSectionTitle: "Sidebar grouping",
        .sidebarGroupingModeFieldLabel: "Group by",
        .groupByInstitutionLabel: "Bank",
        .groupByCurrencyLabel: "Currency",
        .groupByCountryLabel: "Country",
        .groupByTypeLabel: "Type",
        .originalCurrenciesLabel: "Original currencies",
    ]
}
