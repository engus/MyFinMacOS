import Foundation

enum CreationEntity: String, CaseIterable, Equatable {
    case account
    case incomeExpense
    case asset

    var isAvailable: Bool { self != .asset }
}

enum CreationStep: Int, CaseIterable, Equatable {
    case type
    case details
    case appearance

    func next(for entity: CreationEntity) -> CreationStep? {
        guard entity == .account else { return nil }
        switch self {
        case .type: return .details
        case .details: return .appearance
        case .appearance: return nil
        }
    }
}

struct AccountCreationDraft {
    var step = CreationStep.type
    var entity = CreationEntity.account
    var country = Country.kz
    var type = AccountType.debitCard
    var currency = Currency.kzt
    var institutionSelection = InstitutionSelection.none
    var name = ""
    var balance = "0"
    var appearance = AccountAppearance()
}
