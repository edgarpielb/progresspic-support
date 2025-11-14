import XCTest
@testable import ProgressPic

/// Test suite for StatsFormatters utility
/// Validates statistical calculations and formatting for data visualization
final class StatsFormattersTests: XCTestCase {

    // MARK: - Test Data

    struct TestDataPoint {
        let value: Double
    }

    // MARK: - formatMin Tests

    func testFormatMin_EmptyArray_ReturnsPlaceholder() {
        let data: [TestDataPoint] = []
        let result = StatsFormatters.formatMin(data, valueKeyPath: \.value, unit: "kg")
        XCTAssertEqual(result, "--", "Empty array should return placeholder")
    }

    func testFormatMin_SingleValue_ReturnsThatValue() {
        let data = [TestDataPoint(value: 75.5)]
        let result = StatsFormatters.formatMin(data, valueKeyPath: \.value, unit: "kg", decimalPlaces: 1)
        XCTAssertEqual(result, "75.5 kg", "Single value should be returned as minimum")
    }

    func testFormatMin_MultipleValues_ReturnsMinimum() {
        let data = [
            TestDataPoint(value: 80.0),
            TestDataPoint(value: 75.5),
            TestDataPoint(value: 82.3)
        ]
        let result = StatsFormatters.formatMin(data, valueKeyPath: \.value, unit: "kg", decimalPlaces: 1)
        XCTAssertEqual(result, "75.5 kg", "Should return the minimum value")
    }

    func testFormatMin_CustomDecimalPlaces_FormatsCorrectly() {
        let data = [TestDataPoint(value: 75.567)]
        let result = StatsFormatters.formatMin(data, valueKeyPath: \.value, unit: "kg", decimalPlaces: 2)
        XCTAssertEqual(result, "75.57 kg", "Should format with 2 decimal places")
    }

    func testFormatMin_CustomPlaceholder_ReturnsCustomPlaceholder() {
        let data: [TestDataPoint] = []
        let result = StatsFormatters.formatMin(data, valueKeyPath: \.value, unit: "kg", emptyPlaceholder: "N/A")
        XCTAssertEqual(result, "N/A", "Should use custom placeholder")
    }

    // MARK: - formatMax Tests

    func testFormatMax_EmptyArray_ReturnsPlaceholder() {
        let data: [TestDataPoint] = []
        let result = StatsFormatters.formatMax(data, valueKeyPath: \.value, unit: "kg")
        XCTAssertEqual(result, "--", "Empty array should return placeholder")
    }

    func testFormatMax_SingleValue_ReturnsThatValue() {
        let data = [TestDataPoint(value: 75.5)]
        let result = StatsFormatters.formatMax(data, valueKeyPath: \.value, unit: "kg", decimalPlaces: 1)
        XCTAssertEqual(result, "75.5 kg", "Single value should be returned as maximum")
    }

    func testFormatMax_MultipleValues_ReturnsMaximum() {
        let data = [
            TestDataPoint(value: 80.0),
            TestDataPoint(value: 75.5),
            TestDataPoint(value: 82.3)
        ]
        let result = StatsFormatters.formatMax(data, valueKeyPath: \.value, unit: "kg", decimalPlaces: 1)
        XCTAssertEqual(result, "82.3 kg", "Should return the maximum value")
    }

    // MARK: - formatAverage Tests

    func testFormatAverage_EmptyArray_ReturnsPlaceholder() {
        let data: [TestDataPoint] = []
        let result = StatsFormatters.formatAverage(data, valueKeyPath: \.value, unit: "kg")
        XCTAssertEqual(result, "--", "Empty array should return placeholder")
    }

    func testFormatAverage_SingleValue_ReturnsThatValue() {
        let data = [TestDataPoint(value: 75.5)]
        let result = StatsFormatters.formatAverage(data, valueKeyPath: \.value, unit: "kg", decimalPlaces: 1)
        XCTAssertEqual(result, "75.5 kg", "Average of single value should be that value")
    }

    func testFormatAverage_MultipleValues_ReturnsCorrectAverage() {
        let data = [
            TestDataPoint(value: 70.0),
            TestDataPoint(value: 80.0),
            TestDataPoint(value: 90.0)
        ]
        let result = StatsFormatters.formatAverage(data, valueKeyPath: \.value, unit: "kg", decimalPlaces: 1)
        XCTAssertEqual(result, "80.0 kg", "Should calculate correct average: (70+80+90)/3 = 80")
    }

    func testFormatAverage_TwoValues_ReturnsCorrectAverage() {
        let data = [
            TestDataPoint(value: 75.0),
            TestDataPoint(value: 85.0)
        ]
        let result = StatsFormatters.formatAverage(data, valueKeyPath: \.value, unit: "kg", decimalPlaces: 1)
        XCTAssertEqual(result, "80.0 kg", "Should calculate average: (75+85)/2 = 80")
    }

    // MARK: - formatRange Tests

    func testFormatRange_EmptyArray_ReturnsPlaceholder() {
        let data: [TestDataPoint] = []
        let result = StatsFormatters.formatRange(data, valueKeyPath: \.value, unit: "kg")
        XCTAssertEqual(result, "--", "Empty array should return placeholder")
    }

    func testFormatRange_SingleValue_ReturnsZero() {
        let data = [TestDataPoint(value: 75.5)]
        let result = StatsFormatters.formatRange(data, valueKeyPath: \.value, unit: "kg", decimalPlaces: 1)
        XCTAssertEqual(result, "0.0 kg", "Range of single value should be 0")
    }

    func testFormatRange_MultipleValues_ReturnsCorrectRange() {
        let data = [
            TestDataPoint(value: 70.0),
            TestDataPoint(value: 85.0),
            TestDataPoint(value: 75.0)
        ]
        let result = StatsFormatters.formatRange(data, valueKeyPath: \.value, unit: "kg", decimalPlaces: 1)
        XCTAssertEqual(result, "15.0 kg", "Should calculate range: 85 - 70 = 15")
    }

    // MARK: - calculateYDomain Tests

    func testCalculateYDomain_EmptyArray_ReturnsDefaultRange() {
        let data: [TestDataPoint] = []
        let domain = StatsFormatters.calculateYDomain(for: data, valueKeyPath: \.value)
        XCTAssertEqual(domain, 0...100, "Empty array should return default 0...100 range")
    }

    func testCalculateYDomain_SingleValue_AddsPadding() {
        let data = [TestDataPoint(value: 75.0)]
        let domain = StatsFormatters.calculateYDomain(
            for: data,
            valueKeyPath: \.value,
            paddingPercent: 0.1,
            minPadding: 1.0
        )

        // Range is 0, so padding should be minPadding = 1.0
        XCTAssertEqual(domain.lowerBound, 74.0, accuracy: 0.01, "Lower bound should be 75 - 1 = 74")
        XCTAssertEqual(domain.upperBound, 76.0, accuracy: 0.01, "Upper bound should be 75 + 1 = 76")
    }

    func testCalculateYDomain_MultipleValues_AddsPercentPadding() {
        let data = [
            TestDataPoint(value: 70.0),
            TestDataPoint(value: 80.0)
        ]
        let domain = StatsFormatters.calculateYDomain(
            for: data,
            valueKeyPath: \.value,
            paddingPercent: 0.1,
            minPadding: 0.0
        )

        // Range is 10, padding is 10 * 0.1 = 1.0
        XCTAssertEqual(domain.lowerBound, 69.0, accuracy: 0.01, "Lower bound should be 70 - 1 = 69")
        XCTAssertEqual(domain.upperBound, 81.0, accuracy: 0.01, "Upper bound should be 80 + 1 = 81")
    }

    func testCalculateYDomain_NegativeValuesDisallowed_ClampsToZero() {
        let data = [
            TestDataPoint(value: 5.0),
            TestDataPoint(value: 10.0)
        ]
        let domain = StatsFormatters.calculateYDomain(
            for: data,
            valueKeyPath: \.value,
            paddingPercent: 1.0,  // Large padding to force negative
            minPadding: 0.0,
            allowNegative: false
        )

        XCTAssertGreaterThanOrEqual(domain.lowerBound, 0.0, "Lower bound should not go below 0 when allowNegative is false")
    }

    func testCalculateYDomain_NegativeValuesAllowed_CanGoNegative() {
        let data = [
            TestDataPoint(value: 5.0),
            TestDataPoint(value: 10.0)
        ]
        let domain = StatsFormatters.calculateYDomain(
            for: data,
            valueKeyPath: \.value,
            paddingPercent: 1.0,  // Large padding to force negative
            minPadding: 0.0,
            allowNegative: true
        )

        // Range is 5, padding is 5 * 1.0 = 5.0
        XCTAssertEqual(domain.lowerBound, 0.0, accuracy: 0.01, "Lower bound should be 5 - 5 = 0")
    }

    func testCalculateYDomain_MinPaddingEnforced_UsesMinPaddingWhenLarger() {
        let data = [
            TestDataPoint(value: 75.0),
            TestDataPoint(value: 75.1)
        ]
        let domain = StatsFormatters.calculateYDomain(
            for: data,
            valueKeyPath: \.value,
            paddingPercent: 0.1,  // Would give 0.01 padding
            minPadding: 2.0       // Should use this instead
        )

        // Min padding should win
        XCTAssertEqual(domain.lowerBound, 73.0, accuracy: 0.01, "Should use minPadding")
        XCTAssertEqual(domain.upperBound, 77.1, accuracy: 0.01, "Should use minPadding")
    }

    // MARK: - formatPercentage Tests

    func testFormatPercentage_DefaultDecimalPlaces_FormatsCorrectly() {
        let result = StatsFormatters.formatPercentage(15.5)
        XCTAssertEqual(result, "15.5%", "Should format percentage with default 1 decimal place")
    }

    func testFormatPercentage_CustomDecimalPlaces_FormatsCorrectly() {
        let result = StatsFormatters.formatPercentage(15.567, decimalPlaces: 2)
        XCTAssertEqual(result, "15.57%", "Should format percentage with 2 decimal places")
    }

    func testFormatPercentage_ZeroDecimalPlaces_FormatsAsInteger() {
        let result = StatsFormatters.formatPercentage(15.7, decimalPlaces: 0)
        XCTAssertEqual(result, "16%", "Should format percentage as integer")
    }

    // MARK: - formatChange Tests

    func testFormatChange_PositiveValue_IncludesPlusSign() {
        let result = StatsFormatters.formatChange(5.5, unit: "kg")
        XCTAssertEqual(result, "+5.5 kg", "Positive change should include + sign")
    }

    func testFormatChange_NegativeValue_IncludesMinusSign() {
        let result = StatsFormatters.formatChange(-3.2, unit: "kg")
        XCTAssertEqual(result, "-3.2 kg", "Negative change should include - sign")
    }

    func testFormatChange_ZeroValue_IncludesPlusSign() {
        let result = StatsFormatters.formatChange(0.0, unit: "kg")
        XCTAssertEqual(result, "+0.0 kg", "Zero should be treated as positive")
    }

    func testFormatChange_NoUnit_FormatsWithoutUnit() {
        let result = StatsFormatters.formatChange(5.5)
        XCTAssertEqual(result, "+5.5", "Should format without unit when not provided")
    }

    func testFormatChange_CustomDecimalPlaces_FormatsCorrectly() {
        let result = StatsFormatters.formatChange(5.567, unit: "kg", decimalPlaces: 2)
        XCTAssertEqual(result, "+5.57 kg", "Should format with 2 decimal places")
    }

    // MARK: - formatDuration Tests

    func testFormatDuration_OnlySeconds_FormatsCorrectly() {
        let result = StatsFormatters.formatDuration(45)
        XCTAssertEqual(result, "45s", "Should format seconds only")
    }

    func testFormatDuration_MinutesAndSeconds_FormatsCorrectly() {
        let result = StatsFormatters.formatDuration(125) // 2m 5s
        XCTAssertEqual(result, "2m 5s", "Should format minutes and seconds")
    }

    func testFormatDuration_HoursAndMinutes_FormatsCorrectly() {
        let result = StatsFormatters.formatDuration(3665) // 1h 1m 5s
        XCTAssertEqual(result, "1h 1m", "Should format hours and minutes (ignoring seconds)")
    }

    func testFormatDuration_ExactMinute_FormatsCorrectly() {
        let result = StatsFormatters.formatDuration(60)
        XCTAssertEqual(result, "1m 0s", "Should format exact minute")
    }

    func testFormatDuration_ExactHour_FormatsCorrectly() {
        let result = StatsFormatters.formatDuration(3600)
        XCTAssertEqual(result, "1h 0m", "Should format exact hour")
    }

    func testFormatDuration_Zero_FormatsAsZeroSeconds() {
        let result = StatsFormatters.formatDuration(0)
        XCTAssertEqual(result, "0s", "Should format zero as 0s")
    }

    // MARK: - getStats Tests

    func testGetStats_EmptyArray_ReturnsNil() {
        let data: [TestDataPoint] = []
        let stats = StatsFormatters.getStats(data, valueKeyPath: \.value)
        XCTAssertNil(stats, "Empty array should return nil")
    }

    func testGetStats_SingleValue_ReturnsCorrectStats() {
        let data = [TestDataPoint(value: 75.0)]
        let stats = StatsFormatters.getStats(data, valueKeyPath: \.value)

        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.min, 75.0)
        XCTAssertEqual(stats?.max, 75.0)
        XCTAssertEqual(stats?.average, 75.0)
        XCTAssertEqual(stats?.range, 0.0)
    }

    func testGetStats_MultipleValues_ReturnsCorrectStats() {
        let data = [
            TestDataPoint(value: 70.0),
            TestDataPoint(value: 80.0),
            TestDataPoint(value: 90.0)
        ]
        let stats = StatsFormatters.getStats(data, valueKeyPath: \.value)

        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.min, 70.0)
        XCTAssertEqual(stats?.max, 90.0)
        XCTAssertEqual(stats?.average, 80.0)
        XCTAssertEqual(stats?.range, 20.0)
    }

    func testGetStats_NegativeValues_HandlesCorrectly() {
        let data = [
            TestDataPoint(value: -10.0),
            TestDataPoint(value: 0.0),
            TestDataPoint(value: 10.0)
        ]
        let stats = StatsFormatters.getStats(data, valueKeyPath: \.value)

        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.min, -10.0)
        XCTAssertEqual(stats?.max, 10.0)
        XCTAssertEqual(stats?.average, 0.0)
        XCTAssertEqual(stats?.range, 20.0)
    }
}
