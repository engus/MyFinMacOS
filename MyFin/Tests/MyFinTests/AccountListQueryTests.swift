import XCTest
@testable import MyFin

final class AccountListQueryTests: XCTestCase {
    private func account(_ id: String, name: String = "Savings", country: Country = .kz,
                         type: AccountType = .cash, currency: Currency = .usd,
                         balance: Decimal = 100, institution: String? = nil,
                         archived: Bool = false) -> Account {
        Account(id: id, name: name, country: country, type: type, currency: currency,
                openingBalance: balance, balanceDate: .distantPast, institutionId: institution,
                archived: archived, createdAt: .distantPast, updatedAt: .distantPast)
    }

    func test_searchCombinesStatusTypeAndInstitutionName() {
        let accounts = [
            account("match", type: .deposit, institution: "bank"),
            account("archived", type: .deposit, institution: "bank", archived: true),
            account("cash", name: "Halyk Cash"),
            account("other", type: .deposit, institution: "other")
        ]
        var query = AccountListQuery()
        query.type = .deposit
        query.search = "  HALYK  "
        XCTAssertEqual(query.matching(accounts, institutionNames: ["bank": "Halyk Bank"], baseCurrency: .usd).map(\.id), ["match"])
        query.archived = true
        XCTAssertEqual(query.matching(accounts, institutionNames: ["bank": "Halyk Bank"], baseCurrency: .usd).map(\.id), ["archived"])
    }

    func test_balanceSortComparesConvertedValuesAndCanReverse() {
        let accounts = [account("ten-usd", balance: 10), account("one-usd", currency: .kzt, balance: 460)]
        var query = AccountListQuery()
        XCTAssertEqual(query.matching(accounts, institutionNames: [:], baseCurrency: .usd).map(\.id), ["ten-usd", "one-usd"])
        query.sort = .balanceAscending
        XCTAssertEqual(query.matching(accounts, institutionNames: [:], baseCurrency: .usd).map(\.id), ["one-usd", "ten-usd"])
    }

    func test_sectionsUseOnlyVisibleAccountsAndConvertSubtotals() {
        let accounts = [
            account("usd", balance: 1), account("kzt", currency: .kzt, balance: 460),
            account("us", country: .us, balance: 3), account("hidden", balance: 900, archived: true)
        ]
        let sections = AccountListQuery().sections(accounts, institutionNames: [:], grouping: .country, baseCurrency: .usd)
        XCTAssertEqual(sections.map(\.id), ["KZ", "US"])
        XCTAssertEqual(sections.map(\.total), [2, 3])
        XCTAssertEqual(sections.map { $0.accounts.count }, [2, 1])
    }

    func test_searchMatchesLocalizedTypeAndCurrencyAndName() {
        let accounts = [account("cash", name: "Наличные дома"), account("deposit", type: .deposit, currency: .kzt)]
        var query = AccountListQuery()
        for (search, expected) in [("дома", "cash"), ("KZT", "deposit"), ("депозит", "deposit")] {
            query.search = search
            XCTAssertEqual(query.matching(accounts, institutionNames: [:], baseCurrency: .usd).map(\.id), [expected])
        }
        query.search = "nothing matches"
        XCTAssertTrue(query.sections(accounts, institutionNames: [:], grouping: .country, baseCurrency: .usd).isEmpty)
    }
}
