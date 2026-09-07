import Foundation

enum FlowKind: String, CaseIterable, Codable { case income, expense }
enum FlowSource: String, Codable { case ordinary, recurring, reconciliation, opening, adjustment, transfer, assetPurchase }
enum RepeatUnit: String, CaseIterable, Codable { case week, month, quarter, year, days }

struct FlowCategory: Identifiable, Codable {
    let id: String
    let kind: FlowKind
    let name: String
    let englishName: String
    func title(_ language: AppLanguage) -> String { language == .ru ? name : englishName }
}

struct FXSnapshot: Codable, Equatable {
    let from: Currency
    let to: Currency
    let rate: Decimal
    let date: String
    let source: String
    var stale: Bool = false
}

struct FlowOperation: Identifiable, Codable {
    var id = UUID().uuidString
    let accountID: String
    let kind: FlowKind
    let categoryID: String
    let amount: Decimal
    let currency: Currency
    let accountAmount: Decimal
    let accountCurrency: Currency
    let date: String
    var note: String
    var source: FlowSource = .ordinary
    var templateID: String? = nil
    var occurrence: String? = nil
    var reversalOf: String? = nil
    var replacementOf: String? = nil
    var fx: [FXSnapshot] = []
    var gap = false
    var expected = false
    var createdAt = ISO8601DateFormatter().string(from: Date())
}

struct FlowDraft {
    var accountID: String
    var kind: FlowKind = .expense
    var categoryID = "other-expense"
    var amount: Decimal
    var currency: Currency
    var date: String
    var note = ""
    var source: FlowSource = .ordinary
}

struct RecurringFlow: Identifiable, Codable {
    var id = UUID().uuidString
    var accountID: String
    var kind: FlowKind
    var categoryID: String
    var amount: Decimal
    var currency: Currency
    var note: String
    var start: String
    var end: String? = nil
    var unit: RepeatUnit
    var interval: Int = 1
    var timezone: String
    var active = true

    // Always anchor to the original day; Jan 31 -> Feb 28 -> Mar 31.
    func dates(through endDate: String) throws -> [String] {
        guard interval > 0, interval <= 366, let zone = TimeZone(identifier: timezone) else { throw FlowError.invalidSchedule }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        guard let anchor = FlowDate.parse(start, timezone: zone) else { throw FlowError.invalidDate }
        var result: [String] = []
        for index in 0..<100_000 {
            let component: Calendar.Component = unit == .days || unit == .week ? .day : .month
            let multiplier = unit == .week ? 7 : unit == .quarter ? 3 : unit == .year ? 12 : 1
            guard let date = calendar.date(byAdding: component, value: index * interval * multiplier, to: anchor) else { break }
            let key = FlowDate.key(date, timezone: zone)
            if key > endDate || (end != nil && key > end!) { return result }
            result.append(key)
        }
        throw FlowError.invalidSchedule
    }
}

struct FlowTotals {
    var income: Decimal = 0
    var expense: Decimal = 0
    var expectedIncome: Decimal = 0
    var expectedExpense: Decimal = 0
    var missingFX = 0
    var staleFX = 0
    var net: Decimal { income - expense }
    var projectedNet: Decimal { net + expectedIncome - expectedExpense }
    var savingsRate: Decimal? { income > 0 && missingFX == 0 ? net / income : nil }
}

struct Reconciliation: Identifiable, Codable {
    var id = UUID().uuidString
    let accountID: String
    let month: String
    let reported: Decimal
    let currency: Currency
    let operationID: String?
    let previousID: String?
    let gap: Bool
    let createdAt: String
}

enum FlowError: LocalizedError {
    case invalidAmount, invalidDate, invalidSchedule, accountUnavailable, categoryMismatch
    case missingFX, alreadyReversed, immutable, futurePosting, invalidMonth, corruptData
    var errorDescription: String? {
        switch self {
        case .invalidAmount: return "Некорректная сумма: больше нуля, до 8 знаков после запятой, максимум 9 млрд. / Invalid amount."
        case .invalidDate: return "Некорректная дата / Invalid date."
        case .invalidSchedule: return "Некорректное расписание / Invalid recurring schedule."
        case .accountUnavailable: return "Счёт недоступен для этой операции / Account unavailable."
        case .categoryMismatch: return "Категория не соответствует типу операции / Category mismatch."
        case .missingFX: return "Нет курса на дату операции. Добавьте курс в Cashflow → FX. / Missing dated FX quote."
        case .alreadyReversed: return "Операция уже сторнирована / Operation already reversed."
        case .immutable: return "Используйте сторно для исправления проведённой операции / Use a reversal."
        case .futurePosting: return "Будущие операции создаются через расписание / Use a recurring template for future dates."
        case .invalidMonth: return "Для сверки выберите завершённый месяц / Select a completed month."
        case .corruptData: return "Не удалось прочитать журнал / Invalid ledger data."
        }
    }
}

enum FlowDate {
    static func formatter(_ timezone: TimeZone) -> DateFormatter {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = timezone; f.dateFormat = "yyyy-MM-dd"; f.isLenient = false
        return f
    }
    static func key(_ date: Date, timezone: TimeZone = .current) -> String { formatter(timezone).string(from: date) }
    static func parse(_ key: String, timezone: TimeZone = .current) -> Date? {
        guard key.count == 10, let date = formatter(timezone).date(from: key), self.key(date, timezone: timezone) == key else { return nil }
        return date
    }
    static func month(_ date: Date, timezone: TimeZone = .current) -> String { String(key(date, timezone: timezone).prefix(7)) }
    static func end(_ month: String) throws -> String {
        let zone = TimeZone(secondsFromGMT: 0)!
        guard month.count == 7, let start = parse(month + "-01", timezone: zone) else { throw FlowError.invalidMonth }
        var c = Calendar(identifier: .gregorian); c.timeZone = zone
        let next = c.date(byAdding: .month, value: 1, to: start)!
        return key(c.date(byAdding: .day, value: -1, to: next)!, timezone: zone)
    }
    static func url(month: String) -> URL { URL(string: "myfin://cashflow?month=\(month)")! }
    static func month(from url: URL) -> String? {
        guard url.scheme == "myfin", url.host == "cashflow",
              let key = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "month" })?.value,
              (try? end(key)) != nil else { return nil }
        return key
    }
}

enum FlowMoney {
    static let scale: Decimal = 100_000_000
    static func units(_ amount: Decimal) throws -> Int64 {
        guard !amount.isNaN, abs(amount) <= 9_000_000_000, AccountService.decimalPlaces(of: amount) <= 8 else { throw FlowError.invalidAmount }
        return NSDecimalNumber(decimal: amount * scale).int64Value
    }
    static func rounded(_ amount: Decimal) -> Decimal {
        var source = amount; var result = Decimal(); NSDecimalRound(&result, &source, 8, .plain); return result
    }
}
