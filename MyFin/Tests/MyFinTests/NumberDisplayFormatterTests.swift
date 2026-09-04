import XCTest
@testable import MyFin

final class NumberDisplayFormatterTests: XCTestCase {
    func test_wholeNumber_periodSeparator_hidesTrailingZeroes() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: false, maxDecimalPlaces: 2, useCompactNotation: false, hideTrailingZeroes: true)
        XCTAssertEqual(NumberDisplayFormatter.format(1500, preferences: preferences), "1 500")
    }

    func test_wholeNumber_showsTrailingZeroesWhenNotHidden() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: false, maxDecimalPlaces: 2, useCompactNotation: false, hideTrailingZeroes: false)
        XCTAssertEqual(NumberDisplayFormatter.format(1500, preferences: preferences), "1 500.00")
    }

    func test_nonZeroFractional_periodSeparator_isKept() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: false, maxDecimalPlaces: 2, useCompactNotation: false, hideTrailingZeroes: true)
        XCTAssertEqual(NumberDisplayFormatter.format(Decimal(string: "1500.25")!, preferences: preferences), "1 500.25")
    }

    func test_commaSeparator_groupingStaysSpace() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: true, maxDecimalPlaces: 2, useCompactNotation: false, hideTrailingZeroes: true)
        XCTAssertEqual(NumberDisplayFormatter.format(Decimal(string: "1500.25")!, preferences: preferences), "1 500,25")
    }

    func test_compactNotation_thousandThreshold_matchesConfirmedResolution() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: true, maxDecimalPlaces: 2, useCompactNotation: true, hideTrailingZeroes: true)
        XCTAssertEqual(NumberDisplayFormatter.format(1500, preferences: preferences), "1,5K")
    }

    func test_compactNotation_millionThreshold() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: true, maxDecimalPlaces: 2, useCompactNotation: true, hideTrailingZeroes: true)
        XCTAssertEqual(NumberDisplayFormatter.format(1_500_000, preferences: preferences), "1,5M")
    }

    func test_compactNotation_billionThreshold() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: false, maxDecimalPlaces: 2, useCompactNotation: true, hideTrailingZeroes: true)
        XCTAssertEqual(NumberDisplayFormatter.format(2_500_000_000, preferences: preferences), "2.5B")
    }

    func test_compactNotation_belowThousand_noSuffixApplied() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: false, maxDecimalPlaces: 0, useCompactNotation: true, hideTrailingZeroes: true)
        XCTAssertEqual(NumberDisplayFormatter.format(999, preferences: preferences), "999")
    }

    func test_maxDecimalPlacesZero_neverShowsFraction_andRoundsUp() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: false, maxDecimalPlaces: 0, useCompactNotation: false, hideTrailingZeroes: false)
        XCTAssertEqual(NumberDisplayFormatter.format(Decimal(string: "1500.99")!, preferences: preferences), "1 501")
    }

    func test_maxDecimalPlacesOne_roundsAndKeepsNonZeroDigit() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: false, maxDecimalPlaces: 1, useCompactNotation: false, hideTrailingZeroes: true)
        XCTAssertEqual(NumberDisplayFormatter.format(Decimal(string: "1500.26")!, preferences: preferences), "1 500.3")
    }

    func test_zero() {
        let preferences = NumberFormatPreferences()
        XCTAssertEqual(NumberDisplayFormatter.format(0, preferences: preferences), "0")
    }

    func test_negativeValue_keepsSign() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: false, maxDecimalPlaces: 2, useCompactNotation: false, hideTrailingZeroes: true)
        XCTAssertEqual(NumberDisplayFormatter.format(-1500, preferences: preferences), "-1 500")
    }

    func test_smallFractionalOnly_keepsLeadingZeroInteger() {
        let preferences = NumberFormatPreferences(useCommaDecimalSeparator: false, maxDecimalPlaces: 2, useCompactNotation: false, hideTrailingZeroes: true)
        XCTAssertEqual(NumberDisplayFormatter.format(Decimal(string: "0.05")!, preferences: preferences), "0.05")
    }
}
