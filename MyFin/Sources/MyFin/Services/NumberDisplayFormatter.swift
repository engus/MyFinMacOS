import Foundation

enum NumberDisplayFormatter {
    static func format(_ value: Decimal, preferences: NumberFormatPreferences) -> String {
        let isNegative = value < 0
        var magnitude = isNegative ? -value : value

        var suffix = ""
        if preferences.useCompactNotation {
            let billion = Decimal(1_000_000_000)
            let million = Decimal(1_000_000)
            let thousand = Decimal(1_000)
            if magnitude >= billion {
                magnitude /= billion
                suffix = "B"
            } else if magnitude >= million {
                magnitude /= million
                suffix = "M"
            } else if magnitude >= thousand {
                magnitude /= thousand
                suffix = "K"
            }
        }

        let (integerPart, fractionalPart) = splitDigits(magnitude, places: preferences.maxDecimalPlaces)

        var fractional = fractionalPart
        if preferences.hideTrailingZeroes {
            while fractional.hasSuffix("0") {
                fractional.removeLast()
            }
        }

        let separator = preferences.useCommaDecimalSeparator ? "," : "."
        var result = groupThousands(integerPart)
        if !fractional.isEmpty {
            result += separator + fractional
        }
        result += suffix
        if isNegative {
            result = "-" + result
        }
        return result
    }

    private static func splitDigits(_ magnitude: Decimal, places: Int) -> (integer: String, fractional: String) {
        var scale = Decimal(1)
        for _ in 0..<places { scale *= 10 }

        var scaled = magnitude * scale
        var scaledRounded = Decimal()
        NSDecimalRound(&scaledRounded, &scaled, 0, .plain)

        var digits = "\(scaledRounded)"
        while digits.count < places + 1 {
            digits = "0" + digits
        }

        guard places > 0 else { return (digits, "") }

        let splitIndex = digits.index(digits.endIndex, offsetBy: -places)
        return (String(digits[digits.startIndex..<splitIndex]), String(digits[splitIndex...]))
    }

    private static func groupThousands(_ digits: String) -> String {
        var result = ""
        for (index, character) in digits.reversed().enumerated() {
            if index > 0 && index.isMultiple(of: 3) {
                result = " " + result
            }
            result = String(character) + result
        }
        return result
    }
}
