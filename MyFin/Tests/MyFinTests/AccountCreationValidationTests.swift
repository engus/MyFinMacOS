import XCTest
@testable import MyFin

final class AccountCreationValidationTests: XCTestCase {
    func test_balanceRejectsJunkAndAcceptsDecimalComma() {
        XCTAssertNil(AccountCreationValidation.balance("12abc"))
        XCTAssertNil(AccountCreationValidation.balance("NaN"))
        XCTAssertEqual(AccountCreationValidation.balance("142500,25"), Decimal(string: "142500.25"))
        XCTAssertEqual(AccountCreationValidation.balance(" 0 "), 0)
    }
}
