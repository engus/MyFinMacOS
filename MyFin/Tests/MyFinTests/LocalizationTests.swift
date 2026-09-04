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

    func test_sidebarAccounts_ru_isSchyota() {
        XCTAssertEqual(Localization.ru[.sidebarAccounts], "Счета")
    }

    func test_sidebarCashflow_ru_isDohodyIRashody() {
        XCTAssertEqual(Localization.ru[.sidebarCashflow], "Доходы и расходы")
    }

    func test_cashflowPlaceholder_ru_matchesNewCashflowLabel() {
        XCTAssertEqual(Localization.ru[.cashflowPlaceholder], "Доходы и расходы — здесь скоро появится содержимое")
    }

    func test_settingsTabGeneral_ru_isObshee() {
        XCTAssertEqual(Localization.ru[.settingsTabGeneral], "Общее")
    }

    func test_settingsTabInstitutions_ru_isBanki() {
        XCTAssertEqual(Localization.ru[.settingsTabInstitutions], "Банки")
    }

    func test_addCustomInstitutionButton_ru_isDobavitBank() {
        XCTAssertEqual(Localization.ru[.addCustomInstitutionButton], "Добавить банк")
    }

    func test_noCustomInstitutionsYet_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.noCustomInstitutionsYet], "Пока нет добавленных банков")
    }

    func test_institutionInUseMessage_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.institutionInUseMessage], "Нельзя сменить страну — банк уже используется в счетах")
    }

    func test_institutionArchivedConflictMessage_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.institutionArchivedConflictMessage], "Банк с таким названием уже существует в архиве — восстановите его из списка")
    }

    func test_activeAccountsSectionTitle_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.activeAccountsSectionTitle], "Активные счета")
    }

    func test_archivedAccountsSectionTitle_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.archivedAccountsSectionTitle], "Архивные счета")
    }

    func test_numberFormatSectionTitle_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.numberFormatSectionTitle], "Формат чисел")
    }

    func test_decimalSeparatorFieldLabel_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.decimalSeparatorFieldLabel], "Разделитель дробной части")
    }

    func test_maxDecimalPlacesFieldLabel_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.maxDecimalPlacesFieldLabel], "Знаков после запятой")
    }

    func test_largeNumberNotationFieldLabel_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.largeNumberNotationFieldLabel], "Крупные числа")
    }

    func test_trailingZeroesFieldLabel_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.trailingZeroesFieldLabel], "Незначащие нули")
    }

    func test_notationFullLabel_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.notationFullLabel], "Полностью")
    }

    func test_notationCompactLabel_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.notationCompactLabel], "Сокращённо")
    }

    func test_trailingZeroesShowLabel_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.trailingZeroesShowLabel], "Показывать")
    }

    func test_trailingZeroesHideLabel_ru_matchesExpectedCopy() {
        XCTAssertEqual(Localization.ru[.trailingZeroesHideLabel], "Скрывать")
    }
}
