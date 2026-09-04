import XCTest
@testable import MyFin

final class AccountModelTests: XCTestCase {
    func test_accountType_allCasesCoverExpectedFour() {
        XCTAssertEqual(Set(AccountType.allCases), [.debitCard, .deposit, .bankAccount, .cash])
    }

    func test_currency_allCasesCoverExpectedTwo() {
        XCTAssertEqual(Set(Currency.allCases), [.usd, .kzt])
    }

    func test_accountType_rawValues_matchDatabaseConvention() {
        XCTAssertEqual(AccountType.debitCard.rawValue, "debit_card")
        XCTAssertEqual(AccountType.bankAccount.rawValue, "bank_account")
    }
}
