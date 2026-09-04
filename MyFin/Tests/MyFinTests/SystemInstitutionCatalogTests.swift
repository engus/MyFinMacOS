import XCTest
@testable import MyFin

final class SystemInstitutionCatalogTests: XCTestCase {
    func test_everyEntry_hasAColorFromTheProfilePalette() {
        for entry in SystemInstitutionCatalog.all {
            XCTAssertTrue(
                ProfileIconPalette.colorNames.contains(entry.color),
                "\(entry.id) has color \(entry.color), not in ProfileIconPalette.colorNames"
            )
        }
    }

    func test_color_forKnownID_returnsThatEntrysColor() {
        XCTAssertEqual(SystemInstitutionCatalog.color(forID: "kz.halyk-bank"), "blue")
        XCTAssertEqual(SystemInstitutionCatalog.color(forID: "kz.kaspi-bank"), "green")
    }

    func test_color_forUnknownID_returnsNil() {
        XCTAssertNil(SystemInstitutionCatalog.color(forID: "not-a-real-institution-id"))
    }

    func test_institutionIconName_isBuildingColumns() {
        XCTAssertEqual(SystemInstitutionCatalog.institutionIconName, "building.columns.fill")
    }
}
