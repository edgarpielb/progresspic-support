import Foundation

/// Centralized date formatting utilities
/// Uses cached DateFormatter instances to avoid expensive recreation
/// Eliminates ~50 lines of duplicated code across views
enum DateFormatters {

    // MARK: - Cached Formatters

    /// Full date format: "1 Jan 2024"
    static let fullDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    /// Short date format: "Jan 1"
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    /// Month and year: "Jan 2024"
    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    /// Month only: "January"
    static let monthOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f
    }()

    /// Day and month: "1 Jan"
    static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    /// ISO date for parsing: "yyyy-MM-dd"
    static let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Time only: "3:45 PM"
    static let timeOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    // MARK: - Formatting Methods

    /// Format a full date: "1 Jan 2024"
    static func formatFullDate(_ date: Date) -> String {
        fullDate.string(from: date)
    }

    /// Format a short date: "Jan 1"
    static func formatShortDate(_ date: Date) -> String {
        shortDate.string(from: date)
    }

    /// Format month and year: "Jan 2024"
    static func formatMonthYear(_ date: Date) -> String {
        monthYear.string(from: date)
    }

    /// Format a date range: "1 Jan - 31 Jan 2024"
    static func formatDateRange(from startDate: Date, to endDate: Date) -> String {
        let calendar = Calendar.current

        // If same day
        if calendar.isDate(startDate, inSameDayAs: endDate) {
            return formatFullDate(startDate)
        }

        // If same year
        if calendar.component(.year, from: startDate) == calendar.component(.year, from: endDate) {
            // If same month
            if calendar.component(.month, from: startDate) == calendar.component(.month, from: endDate) {
                let startDay = calendar.component(.day, from: startDate)
                return "\(startDay) - \(formatFullDate(endDate))"
            } else {
                return "\(formatShortDate(startDate)) - \(formatFullDate(endDate))"
            }
        } else {
            return "\(formatFullDate(startDate)) - \(formatFullDate(endDate))"
        }
    }

    /// Format relative to now: "Today", "Yesterday", or full date
    static func formatRelative(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            return formatFullDate(date)
        }
    }

    // MARK: - EXIF Date Parsing

    /// Parse EXIF date string: "2024:01:15 14:30:00"
    static func parseEXIFDateString(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: dateString)
    }

    /// Parse GPS date/time from EXIF
    static func parseGPSDateTime(dateStamp: String, timeStamp: String) -> Date? {
        let combined = "\(dateStamp) \(timeStamp)"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: combined)
    }
}
