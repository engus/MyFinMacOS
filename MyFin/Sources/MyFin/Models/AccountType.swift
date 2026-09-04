import Foundation

enum AccountType: String, Codable, CaseIterable, Equatable {
    case debitCard = "debit_card"
    case deposit = "deposit"
    case bankAccount = "bank_account"
    case cash = "cash"

    var displayName: String {
        switch self {
        case .debitCard: return "Debit card"
        case .deposit: return "Deposit"
        case .bankAccount: return "Bank account"
        case .cash: return "Cash"
        }
    }
}
