import XCTest
@testable import ProgressPic

/// Test suite for DateFormatters utility
/// Validates date formatting and parsing for consistent UI display
final class DateFormattersTests: XCTestCase {

    // MARK: - Test Data

    var testDate: Date!
    var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar.current

        // Create a known test date: January 15, 2024, 14:30:00
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 15
        components.hour = 14
        components.minute = 30
        components.second = 0
        testDate = calendar.date(from: components)!
    }

    // MARK: - Cached Formatter Tests

    func testFullDateFormatter_CachedInstance() {
        // Verify formatter is cached (same instance)
        let formatter1 = DateFormatters.fullDate
        let formatter2 = DateFormatters.fullDate
        XCTAssertTrue(formatter1 === formatter2, "Should return cached formatter instance")
    }

    // MARK: - formatFullDate Tests

    func testFormatFullDate_StandardDate_FormatsCorrectly() {
        let result = DateFormatters.formatFullDate(testDate)
        XCTAssertEqual(result, "15 Jan 2024", "Should format as '15 Jan 2024'")
    }

    func testFormatFullDate_FirstDayOfMonth_FormatsCorrectly() {
        var components = DateComponents()
        components.year = 2024
        components.month = 3
        components.day = 1
        let date = calendar.date(from: components)!

        let result = DateFormatters.formatFullDate(date)
        XCTAssertEqual(result, "1 Mar 2024", "Should format first day correctly")
    }

    func testFormatFullDate_LastDayOfYear_FormatsCorrectly() {
        var components = DateComponents()
        components.year = 2024
        components.month = 12
        components.day = 31
        let date = calendar.date(from: components)!

        let result = DateFormatters.formatFullDate(date)
        XCTAssertEqual(result, "31 Dec 2024", "Should format last day of year")
    }

    // MARK: - formatShortDate Tests

    func testFormatShortDate_StandardDate_FormatsCorrectly() {
        let result = DateFormatters.formatShortDate(testDate)
        XCTAssertEqual(result, "Jan 15", "Should format as 'Jan 15'")
    }

    // MARK: - formatMonthYear Tests

    func testFormatMonthYear_StandardDate_FormatsCorrectly() {
        let result = DateFormatters.formatMonthYear(testDate)
        XCTAssertEqual(result, "Jan 2024", "Should format as 'Jan 2024'")
    }

    func testFormatMonthYear_DecemberDate_FormatsCorrectly() {
        var components = DateComponents()
        components.year = 2024
        components.month = 12
        components.day = 25
        let date = calendar.date(from: components)!

        let result = DateFormatters.formatMonthYear(date)
        XCTAssertEqual(result, "Dec 2024", "Should format as 'Dec 2024'")
    }

    // MARK: - formatDateRange Tests

    func testFormatDateRange_SameDay_ReturnsSingleDate() {
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 15
        components.hour = 10
        let startDate = calendar.date(from: components)!

        components.hour = 18
        let endDate = calendar.date(from: components)!

        let result = DateFormatters.formatDateRange(from: startDate, to: endDate)
        XCTAssertEqual(result, "15 Jan 2024", "Same day should return single date")
    }

    func testFormatDateRange_SameMonthDifferentDays_FormatsCorrectly() {
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 15
        let startDate = calendar.date(from: components)!

        components.day = 20
        let endDate = calendar.date(from: components)!

        let result = DateFormatters.formatDateRange(from: startDate, to: endDate)
        XCTAssertEqual(result, "15 - 20 Jan 2024", "Same month should show day range")
    }

    func testFormatDateRange_SameYearDifferentMonths_FormatsCorrectly() {
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 15
        let startDate = calendar.date(from: components)!

        components.month = 3
        components.day = 20
        let endDate = calendar.date(from: components)!

        let result = DateFormatters.formatDateRange(from: startDate, to: endDate)
        XCTAssertEqual(result, "Jan 15 - 20 Mar 2024", "Same year different months should show month abbreviations")
    }

    func testFormatDateRange_DifferentYears_FormatsWithFullDates() {
        var components = DateComponents()
        components.year = 2023
        components.month = 12
        components.day = 25
        let startDate = calendar.date(from: components)!

        components.year = 2024
        components.month = 1
        components.day = 5
        let endDate = calendar.date(from: components)!

        let result = DateFormatters.formatDateRange(from: startDate, to: endDate)
        XCTAssertEqual(result, "25 Dec 2023 - 5 Jan 2024", "Different years should show full dates")
    }

    // MARK: - formatRelative Tests

    func testFormatRelative_Today_ReturnsToday() {
        let now = Date()
        let result = DateFormatters.formatRelative(now)
        XCTAssertEqual(result, "Today", "Current date should return 'Today'")
    }

    func testFormatRelative_Yesterday_ReturnsYesterday() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let result = DateFormatters.formatRelative(yesterday)
        XCTAssertEqual(result, "Yesterday", "Yesterday should return 'Yesterday'")
    }

    func testFormatRelative_Tomorrow_ReturnsTomorrow() {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let result = DateFormatters.formatRelative(tomorrow)
        XCTAssertEqual(result, "Tomorrow", "Tomorrow should return 'Tomorrow'")
    }

    func testFormatRelative_OlderDate_ReturnsFormattedDate() {
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 1
        let oldDate = calendar.date(from: components)!

        let result = DateFormatters.formatRelative(oldDate)
        XCTAssertEqual(result, "1 Jan 2024", "Older date should return formatted date")
    }

    func testFormatRelative_FutureDate_ReturnsFormattedDate() {
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 31
        let futureDate = calendar.date(from: components)!

        let result = DateFormatters.formatRelative(futureDate)
        XCTAssertEqual(result, "31 Dec 2025", "Future date (not tomorrow) should return formatted date")
    }

    // MARK: - parseEXIFDateString Tests

    func testParseEXIFDateString_ValidFormat_ParsesCorrectly() {
        let exifString = "2024:01:15 14:30:00"
        let result = DateFormatters.parseEXIFDateString(exifString)

        XCTAssertNotNil(result, "Should parse valid EXIF string")

        if let parsedDate = result {
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: parsedDate)
            XCTAssertEqual(components.year, 2024)
            XCTAssertEqual(components.month, 1)
            XCTAssertEqual(components.day, 15)
            XCTAssertEqual(components.hour, 14)
            XCTAssertEqual(components.minute, 30)
            XCTAssertEqual(components.second, 0)
        }
    }

    func testParseEXIFDateString_InvalidFormat_ReturnsNil() {
        let invalidString = "2024-01-15 14:30:00"
        let result = DateFormatters.parseEXIFDateString(invalidString)
        XCTAssertNil(result, "Invalid EXIF format should return nil")
    }

    func testParseEXIFDateString_MidnightTime_ParsesCorrectly() {
        let exifString = "2024:01:15 00:00:00"
        let result = DateFormatters.parseEXIFDateString(exifString)

        XCTAssertNotNil(result, "Should parse midnight time")
        if let parsedDate = result {
            let components = calendar.dateComponents([.hour, .minute, .second], from: parsedDate)
            XCTAssertEqual(components.hour, 0)
            XCTAssertEqual(components.minute, 0)
            XCTAssertEqual(components.second, 0)
        }
    }

    func testParseEXIFDateString_EndOfDay_ParsesCorrectly() {
        let exifString = "2024:01:15 23:59:59"
        let result = DateFormatters.parseEXIFDateString(exifString)

        XCTAssertNotNil(result, "Should parse end of day time")
        if let parsedDate = result {
            let components = calendar.dateComponents([.hour, .minute, .second], from: parsedDate)
            XCTAssertEqual(components.hour, 23)
            XCTAssertEqual(components.minute, 59)
            XCTAssertEqual(components.second, 59)
        }
    }

    func testParseEXIFDateString_EmptyString_ReturnsNil() {
        let result = DateFormatters.parseEXIFDateString("")
        XCTAssertNil(result, "Empty string should return nil")
    }

    func testParseEXIFDateString_PartialDate_ReturnsNil() {
        let result = DateFormatters.parseEXIFDateString("2024:01:15")
        XCTAssertNil(result, "Partial date without time should return nil")
    }

    // MARK: - parseGPSDateTime Tests

    func testParseGPSDateTime_ValidFormat_ParsesCorrectly() {
        let dateStamp = "2024:01:15"
        let timeStamp = "14:30:00"
        let result = DateFormatters.parseGPSDateTime(dateStamp: dateStamp, timeStamp: timeStamp)

        XCTAssertNotNil(result, "Should parse valid GPS date/time")

        if let parsedDate = result {
            // GPS time is in UTC (GMT+0)
            var utcCalendar = Calendar.current
            utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

            let components = utcCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: parsedDate)
            XCTAssertEqual(components.year, 2024)
            XCTAssertEqual(components.month, 1)
            XCTAssertEqual(components.day, 15)
            XCTAssertEqual(components.hour, 14)
            XCTAssertEqual(components.minute, 30)
            XCTAssertEqual(components.second, 0)
        }
    }

    func testParseGPSDateTime_Midnight_ParsesCorrectly() {
        let dateStamp = "2024:01:15"
        let timeStamp = "00:00:00"
        let result = DateFormatters.parseGPSDateTime(dateStamp: dateStamp, timeStamp: timeStamp)

        XCTAssertNotNil(result, "Should parse midnight GPS time")

        if let parsedDate = result {
            var utcCalendar = Calendar.current
            utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

            let components = utcCalendar.dateComponents([.hour, .minute, .second], from: parsedDate)
            XCTAssertEqual(components.hour, 0)
            XCTAssertEqual(components.minute, 0)
            XCTAssertEqual(components.second, 0)
        }
    }

    func testParseGPSDateTime_InvalidDateStamp_ReturnsNil() {
        let result = DateFormatters.parseGPSDateTime(dateStamp: "2024-01-15", timeStamp: "14:30:00")
        XCTAssertNil(result, "Invalid date stamp format should return nil")
    }

    func testParseGPSDateTime_InvalidTimeStamp_ReturnsNil() {
        let result = DateFormatters.parseGPSDateTime(dateStamp: "2024:01:15", timeStamp: "14-30-00")
        XCTAssertNil(result, "Invalid time stamp format should return nil")
    }

    func testParseGPSDateTime_EmptyStrings_ReturnsNil() {
        let result = DateFormatters.parseGPSDateTime(dateStamp: "", timeStamp: "")
        XCTAssertNil(result, "Empty strings should return nil")
    }

    // MARK: - ISO Date Formatter Tests

    func testISODateFormatter_UsesPOSIXLocale() {
        XCTAssertEqual(
            DateFormatters.isoDate.locale?.identifier,
            "en_US_POSIX",
            "ISO date formatter should use POSIX locale for consistency"
        )
    }

    func testISODateFormatter_FormatsCorrectly() {
        let result = DateFormatters.isoDate.string(from: testDate)
        XCTAssertEqual(result, "2024-01-15", "Should format as ISO date")
    }

    func testISODateFormatter_ParsesCorrectly() {
        let dateString = "2024-01-15"
        let result = DateFormatters.isoDate.date(from: dateString)

        XCTAssertNotNil(result, "Should parse ISO date string")
        if let parsedDate = result {
            let components = calendar.dateComponents([.year, .month, .day], from: parsedDate)
            XCTAssertEqual(components.year, 2024)
            XCTAssertEqual(components.month, 1)
            XCTAssertEqual(components.day, 15)
        }
    }

    // MARK: - Time Formatter Tests

    func testTimeOnlyFormatter_FormatsCorrectly() {
        let result = DateFormatters.timeOnly.string(from: testDate)
        XCTAssertEqual(result, "2:30 PM", "Should format time as '2:30 PM'")
    }

    func testTimeOnlyFormatter_Midnight_FormatsCorrectly() {
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 15
        components.hour = 0
        components.minute = 0
        let midnight = calendar.date(from: components)!

        let result = DateFormatters.timeOnly.string(from: midnight)
        XCTAssertEqual(result, "12:00 AM", "Midnight should format as '12:00 AM'")
    }

    func testTimeOnlyFormatter_Noon_FormatsCorrectly() {
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 15
        components.hour = 12
        components.minute = 0
        let noon = calendar.date(from: components)!

        let result = DateFormatters.timeOnly.string(from: noon)
        XCTAssertEqual(result, "12:00 PM", "Noon should format as '12:00 PM'")
    }

    // MARK: - Month Formatters Tests

    func testMonthOnlyFormatter_FormatsCorrectly() {
        let result = DateFormatters.monthOnly.string(from: testDate)
        XCTAssertEqual(result, "January", "Should format full month name")
    }

    func testDayMonthFormatter_FormatsCorrectly() {
        let result = DateFormatters.dayMonth.string(from: testDate)
        XCTAssertEqual(result, "15 Jan", "Should format as '15 Jan'")
    }

    // MARK: - Edge Case Tests

    func testFormatters_LeapYearDate_HandlesCorrectly() {
        var components = DateComponents()
        components.year = 2024  // Leap year
        components.month = 2
        components.day = 29
        let leapDate = calendar.date(from: components)!

        let result = DateFormatters.formatFullDate(leapDate)
        XCTAssertEqual(result, "29 Feb 2024", "Should handle leap year date")
    }

    func testFormatters_YearBoundary_HandlesCorrectly() {
        var components = DateComponents()
        components.year = 2023
        components.month = 12
        components.day = 31
        let endOfYear = calendar.date(from: components)!

        let result = DateFormatters.formatFullDate(endOfYear)
        XCTAssertEqual(result, "31 Dec 2023", "Should handle year boundary")
    }
}
