import Foundation

protocol ExchangeRateProviding {
    func rate(from: Currency, to: Currency) -> Decimal
}

struct HardcodedExchangeRateProvider: ExchangeRateProviding {
    static let usdToKzt: Decimal = 460

    func rate(from: Currency, to: Currency) -> Decimal {
        if from == to { return 1 }
        if from == .usd && to == .kzt { return Self.usdToKzt }
        if from == .kzt && to == .usd { return 1 / Self.usdToKzt }
        return 1
    }
}
