import XCTest
@testable import MyFin

final class InstitutionModelTests: XCTestCase {
    func test_institutionPickerItem_otherBank_hasStableId() {
        XCTAssertEqual(InstitutionPickerItem.otherBank.id, "__other_bank__")
    }

    func test_institutionPickerItem_institution_idMatchesInstitutionId() {
        let institution = Institution(
            id: "kz.halyk-bank", source: .system, country: .kz, name: "Halyk Bank",
            aliases: ["Halyk"], archived: false, createdAt: Date(), updatedAt: Date()
        )
        XCTAssertEqual(InstitutionPickerItem.institution(institution).id, "kz.halyk-bank")
    }

    func test_country_allCasesCoverExpectedFour() {
        XCTAssertEqual(Set(Country.allCases), [.kz, .ae, .ru, .us])
    }

    func test_country_flags_matchExpectedEmoji() {
        XCTAssertEqual(Country.kz.flag, "🇰🇿")
        XCTAssertEqual(Country.ae.flag, "🇦🇪")
        XCTAssertEqual(Country.ru.flag, "🇷🇺")
        XCTAssertEqual(Country.us.flag, "🇺🇸")
    }
}
