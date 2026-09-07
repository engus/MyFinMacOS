import Foundation

struct Account: Identifiable, Equatable {
    let id: String
    var name: String
    var country: Country
    var type: AccountType
    var currency: Currency
    var openingBalance: Decimal
    var balanceDate: Date
    var institutionId: String?
    var archived: Bool
    let createdAt: Date
    var updatedAt: Date
    var appearance = AccountAppearance()
}

enum AccountError: Error, Equatable {
    case institutionRequired
    case negativeBalance
    case tooManyDecimalDigits
    case institutionError(InstitutionError)
    case notFound
    case invalidCustomBankName
    case currencyHasPostings
}

struct BalanceHistoryEntry: Identifiable, Equatable {
    let id: String
    let balance: Decimal
    let recordedAt: Date
    let currency: Currency?

    init(id: String, balance: Decimal, recordedAt: Date, currency: Currency? = nil) {
        self.id = id
        self.balance = balance
        self.recordedAt = recordedAt
        self.currency = currency
    }
}
