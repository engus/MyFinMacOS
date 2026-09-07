import Foundation

enum L10nKey: String, CaseIterable {
    case addNewTitle
    case addNewSubtitle
    case creationTypeStep
    case newButtonLabel
    case accountEntityTitle
    case accountEntityKicker
    case accountEntityDescription
    case accountEntityExamples
    case incomeExpenseEntityTitle
    case incomeExpenseEntityKicker
    case incomeExpenseEntityDescription
    case incomeExpenseEntityExamples
    case assetEntityTitle
    case assetEntityKicker
    case assetEntityDescription
    case assetEntityExamples
    case comingSoon
    case continueAccountDetails
    case creationTypeTip
    case tintBlue
    case tintGreen
    case tintOrange
    case tintPurple
    case tintPink
    case tintGray
    case badgeBank
    case badgeCard
    case badgeWallet
    case badgeLock
    case badgeChart
    case newAccountTitle
    case accountDetailsStep
    case accountAppearanceStep
    case nextAppearanceButton
    case wizardBack
    case addAccountButton
    case livePreview
    case cardTheme
    case cardNetwork
    case accountTags
    case addTag
    case invalidBalanceMessage
    case accountSaveFailed
    case accentTint
    case accountSpecifications
    case investUnavailable
    case cryptoUnavailable
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
    case portionOfTotalLabel
    case netCashflowLabel
    case recentMovementsLabel
    case capitalDistributionLabel
    case noMovementsTrackedMessage
    case cashflowComingSoonMessage
    case addEntryButton
    case legacyHistoryCurrencyNote
    case historyComparisonUnavailable
    case accountDetailsTitle
    case currentBalanceLabel
    case initialBalanceLabel
    case reconcileBalanceButton
    case updatedAtLabel
    case closeDetailsButton
    case emptyBalanceHistory
    case sidebarAnalytics
    case analyticsPlaceholder
    case accountsDescription
    case activeTab
    case archivedTab
    case allTypes
    case filterAccounts
    case noMatchingAccounts
    case clearFilters
    case accountInstitutionColumn
    case balanceColumn
    case actionsColumn
    case subtotalLabel
    case totalValueLabel
    case expandAccounts
    case collapseAccounts
    case localProfile
    case manageAccounts
    case distributionDescription
    case recordedBalances
    case balanceHistoryButton
    case debitCardType
    case depositType
    case bankAccountType
    case cashAndBank
    case depositsLabel
    case accountCountLabel
    case sortByName
    case sortBalanceDescending
    case sortBalanceAscending
    case sortLabel
    case groupByLabel
    case noArchivedAccounts
}

enum Localization {
    static func string(_ key: L10nKey, language: AppLanguage) -> String {
        switch language {
        case .ru: return ru[key] ?? key.rawValue
        case .en: return en[key] ?? key.rawValue
        }
    }

    static let ru: [L10nKey: String] = [
        .addNewTitle: "Добавить…",
        .addNewSubtitle: "Выберите, что добавить в ваш финансовый учёт",
        .creationTypeStep: "Тип",
        .newButtonLabel: "Новое",
        .accountEntityTitle: "Счёт",
        .accountEntityKicker: "БАНК, КАРТА ИЛИ НАЛИЧНЫЕ",
        .accountEntityDescription: "Учитывайте банковские счета, дебетовые карты, вклады и наличные.",
        .accountEntityExamples: "Например: Kaspi Bank, IBKR, наличные",
        .incomeExpenseEntityTitle: "Доход / Расход",
        .incomeExpenseEntityKicker: "ОПЕРАЦИЯ ИЛИ РЕГУЛЯРНЫЙ ПЛАТЁЖ",
        .incomeExpenseEntityDescription: "Добавляйте доходы, расходы и регулярные платежи.",
        .incomeExpenseEntityExamples: "Например: зарплата, дивиденды, аренда",
        .assetEntityTitle: "Актив",
        .assetEntityKicker: "КАПИТАЛ, ИМУЩЕСТВО И ИНВЕСТИЦИИ",
        .assetEntityDescription: "Учитывайте недвижимость, транспорт, металлы и другие активы.",
        .assetEntityExamples: "Например: квартира, автомобиль, золото",
        .comingSoon: "Скоро",
        .continueAccountDetails: "Продолжить: данные счёта",
        .creationTypeTip: "Добавляйте счета, доходы и расходы. Активы появятся позже.",
        .tintBlue: "Синий",
        .tintGreen: "Зелёный",
        .tintOrange: "Оранжевый",
        .tintPurple: "Фиолетовый",
        .tintPink: "Розовый",
        .tintGray: "Серый",
        .badgeBank: "Банк",
        .badgeCard: "Карта",
        .badgeWallet: "Кошелёк",
        .badgeLock: "Замок",
        .badgeChart: "График",
        .newAccountTitle: "Новый счёт",
        .accountDetailsStep: "Данные счёта",
        .accountAppearanceStep: "Оформление",
        .nextAppearanceButton: "Далее: оформление",
        .wizardBack: "Назад",
        .addAccountButton: "Добавить счёт",
        .livePreview: "Предпросмотр",
        .cardTheme: "Тема и материал карты",
        .cardNetwork: "Платёжная система",
        .accountTags: "Теги счёта",
        .addTag: "Добавить тег",
        .invalidBalanceMessage: "Введите корректную сумму баланса",
        .accountSaveFailed: "Не удалось сохранить счёт. Повторите попытку.",
        .accentTint: "Оттенок рамки",
        .accountSpecifications: "Параметры счёта",
        .investUnavailable: "Инвестиции · скоро",
        .cryptoUnavailable: "Крипто · скоро",
        .legacyHistoryCurrencyNote: "Валюта старых записей не сохранена. Изменения для них — разница записанных сумм без пересчёта валют.",
        .historyComparisonUnavailable: "Нет данных для сравнения в одной валюте",
        .accountDetailsTitle: "Детали счёта",
        .currentBalanceLabel: "Текущий баланс",
        .initialBalanceLabel: "Начальный",
        .reconcileBalanceButton: "Сверить баланс",
        .updatedAtLabel: "Изменён",
        .closeDetailsButton: "Закрыть детали",
        .emptyBalanceHistory: "История баланса пока пуста",

        .sidebarAnalytics: "Аналитика",
        .analyticsPlaceholder: "Аналитика появится после добавления учёта операций",
        .accountsDescription: "Управляйте банковскими счетами, вкладами и наличными",
        .activeTab: "Активные",
        .archivedTab: "Архивные",
        .allTypes: "Все типы",
        .filterAccounts: "Найти счёт…",
        .noMatchingAccounts: "Счета не найдены",
        .clearFilters: "Сбросить фильтры",
        .accountInstitutionColumn: "Счёт / Банк",
        .balanceColumn: "Баланс",
        .actionsColumn: "Действия",
        .subtotalLabel: "Подытог",
        .totalValueLabel: "Общая сумма",
        .expandAccounts: "Раскрыть активные счета",
        .collapseAccounts: "Свернуть активные счета",
        .localProfile: "Локальный профиль",
        .manageAccounts: "Управлять счетами",
        .distributionDescription: "Распределение средств по счетам и валютам",
        .recordedBalances: "Сохранённые остатки",
        .balanceHistoryButton: "История баланса",
        .debitCardType: "Дебетовая карта",
        .depositType: "Депозит",
        .bankAccountType: "Банковский счёт",
        .cashAndBank: "Наличные и счета",
        .depositsLabel: "Вклады",
        .accountCountLabel: "Счетов",
        .sortByName: "По названию",
        .sortBalanceDescending: "Баланс: по убыванию",
        .sortBalanceAscending: "Баланс: по возрастанию",
        .sortLabel: "Сортировка",
        .groupByLabel: "Группировать",
        .noArchivedAccounts: "Нет архивных счетов",

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
        .portionOfTotalLabel: "Доля от общего",
        .netCashflowLabel: "Чистый денежный поток",
        .recentMovementsLabel: "Последние операции",
        .capitalDistributionLabel: "Распределение капитала",
        .noMovementsTrackedMessage: "Движения пока не отслеживаются",
        .cashflowComingSoonMessage: "Учёт доходов и расходов скоро появится",
        .addEntryButton: "+ Добавить",
    ]

    static let en: [L10nKey: String] = [
        .addNewTitle: "Add New…",
        .addNewSubtitle: "Choose what you want to add to your personal finance ledger",
        .creationTypeStep: "Type",
        .newButtonLabel: "New",
        .accountEntityTitle: "Account",
        .accountEntityKicker: "BANK, CARD OR CASH",
        .accountEntityDescription: "Track bank accounts, debit cards, deposits, and physical cash.",
        .accountEntityExamples: "e.g. Kaspi Bank, IBKR, Cash",
        .incomeExpenseEntityTitle: "Income / Expense",
        .incomeExpenseEntityKicker: "TRANSACTION OR RECURRING FLOW",
        .incomeExpenseEntityDescription: "Record income, expenses, and recurring payments.",
        .incomeExpenseEntityExamples: "e.g. Salary, Dividends, Rent",
        .assetEntityTitle: "Asset",
        .assetEntityKicker: "CAPITAL, PROPERTY & INVESTMENTS",
        .assetEntityDescription: "Track property, vehicles, metals, and other assets.",
        .assetEntityExamples: "e.g. Real Estate, Car, Gold",
        .comingSoon: "Coming soon",
        .continueAccountDetails: "Continue: Account Details",
        .creationTypeTip: "Add accounts, income and expenses. Assets are coming later.",
        .tintBlue: "Blue",
        .tintGreen: "Green",
        .tintOrange: "Orange",
        .tintPurple: "Purple",
        .tintPink: "Pink",
        .tintGray: "Gray",
        .badgeBank: "Bank",
        .badgeCard: "Card",
        .badgeWallet: "Wallet",
        .badgeLock: "Lock",
        .badgeChart: "Chart",
        .newAccountTitle: "Add New Account",
        .accountDetailsStep: "Account Details",
        .accountAppearanceStep: "Appearance",
        .nextAppearanceButton: "Next: Appearance",
        .wizardBack: "Back",
        .addAccountButton: "Add Account",
        .livePreview: "Live Preview",
        .cardTheme: "Card Theme & Material Finish",
        .cardNetwork: "Payment Network",
        .accountTags: "Account Tags",
        .addTag: "Add Tag",
        .invalidBalanceMessage: "Enter a valid balance",
        .accountSaveFailed: "Unable to save account. Please try again.",
        .accentTint: "Border Accent Tint",
        .accountSpecifications: "Account Specifications",
        .investUnavailable: "Invest · Soon",
        .cryptoUnavailable: "Crypto · Soon",
        .legacyHistoryCurrencyNote: "Older records have no saved currency. Their changes compare recorded amounts without currency conversion.",
        .historyComparisonUnavailable: "No comparable same-currency data",
        .accountDetailsTitle: "Account Details",
        .currentBalanceLabel: "Current Balance",
        .initialBalanceLabel: "Initial",
        .reconcileBalanceButton: "Reconcile",
        .updatedAtLabel: "Updated",
        .closeDetailsButton: "Close details",
        .emptyBalanceHistory: "No balance history yet",

        .sidebarAnalytics: "Analytics",
        .analyticsPlaceholder: "Analytics will be available with transaction tracking",
        .accountsDescription: "Manage and track your bank accounts, deposits, and cash",
        .activeTab: "Active",
        .archivedTab: "Archived",
        .allTypes: "All types",
        .filterAccounts: "Filter accounts…",
        .noMatchingAccounts: "No matching accounts",
        .clearFilters: "Clear filters",
        .accountInstitutionColumn: "Account / Institution",
        .balanceColumn: "Balance",
        .actionsColumn: "Actions",
        .subtotalLabel: "Subtotal",
        .totalValueLabel: "Total Value",
        .expandAccounts: "Expand active accounts",
        .collapseAccounts: "Collapse active accounts",
        .localProfile: "Local profile",
        .manageAccounts: "Manage Accounts",
        .distributionDescription: "Account exposure across currencies and institutions",
        .recordedBalances: "Recorded balances",
        .balanceHistoryButton: "Balance history",
        .debitCardType: "Debit card",
        .depositType: "Deposit",
        .bankAccountType: "Bank account",
        .cashAndBank: "Cash & Bank",
        .depositsLabel: "Deposits",
        .accountCountLabel: "Accounts",
        .sortByName: "By name",
        .sortBalanceDescending: "Balance: highest first",
        .sortBalanceAscending: "Balance: lowest first",
        .sortLabel: "Sort",
        .groupByLabel: "Group by",
        .noArchivedAccounts: "No archived accounts",

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
        .portionOfTotalLabel: "Portion of Total",
        .netCashflowLabel: "Net Cashflow",
        .recentMovementsLabel: "Recent Movements",
        .capitalDistributionLabel: "Capital Distribution",
        .noMovementsTrackedMessage: "No movements tracked yet",
        .cashflowComingSoonMessage: "Cashflow tracking is coming soon",
        .addEntryButton: "+ Add",
    ]
}
