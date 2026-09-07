import XCTest
@testable import MyFin

final class AccountCreationDraftTests: XCTestCase {
    func test_newDraftStartsOnTypeWithAccountSelected() {
        let draft = AccountCreationDraft()
        XCTAssertEqual(draft.step, .type)
        XCTAssertEqual(draft.entity, .account)
    }

    func test_accountAndCashflowCanContinueWhileAssetsRemainUnavailable() {
        XCTAssertTrue(CreationEntity.account.isAvailable)
        XCTAssertTrue(CreationEntity.incomeExpense.isAvailable)
        XCTAssertFalse(CreationEntity.asset.isAvailable)
    }

    func test_accountFlowAdvancesThroughThreeSteps() {
        XCTAssertEqual(CreationStep.type.next(for: .account), .details)
        XCTAssertEqual(CreationStep.details.next(for: .account), .appearance)
        XCTAssertNil(CreationStep.appearance.next(for: .account))
    }
}
