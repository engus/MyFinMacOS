import Foundation

struct NumberFormatPreferences: Equatable {
    var useCommaDecimalSeparator: Bool = false
    var maxDecimalPlaces: Int = 2
    var useCompactNotation: Bool = false
    var hideTrailingZeroes: Bool = true
}
