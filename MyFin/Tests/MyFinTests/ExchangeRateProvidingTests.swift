import XCTest
@testable import MyFin

final class ExchangeRateProvidingTests: XCTestCase {
    func test_sameCurrency_rateIsOne() {
        let provider = HardcodedExchangeRateProvider()
        XCTAssertEqual(provider.rate(from: .usd, to: .usd), 1)
        XCTAssertEqual(provider.rate(from: .kzt, to: .kzt), 1)
    }

    func test_usdToKzt_isFixedRate() {
        let provider = HardcodedExchangeRateProvider()
        XCTAssertEqual(provider.rate(from: .usd, to: .kzt), Decimal(string: "460.5"))
    }

    func test_kztToUsd_isReciprocal() {
        let provider = HardcodedExchangeRateProvider()
        let rate = provider.rate(from: .kzt, to: .usd)
        let roundTrip = rate * (Decimal(string: "460.5")!)
        XCTAssertEqual((roundTrip as NSDecimalNumber).doubleValue, 1.0, accuracy: 0.0001)
    }
}
