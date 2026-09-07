import Foundation

enum AccountCreationValidation {
    static func balance(_ raw: String) -> Decimal? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard text.range(of: "^-?[0-9]+(?:\\.[0-9]+)?$", options: .regularExpression) != nil else { return nil }
        return Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
    }
}
