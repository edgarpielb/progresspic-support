import SwiftUI
import Foundation

/// Centralized X-axis generation and formatting for measurement and body composition charts
/// Eliminates ~300 lines of duplicated code across MeasurementDetailView and BodyCompositionDetailView
enum ChartXAxisHelpers {

    /// Generate all X-axis date points for a given time range
    static func getAllXAxisDates(
        for timeRange: TimeRange,
        filteredData: [any Dated],
        calendar: Calendar = .current
    ) -> [Date] {
        guard !filteredData.isEmpty else { return [] }

        let dates = filteredData.map { $0.date }
        guard let minDate = dates.min(), let maxDate = dates.max() else { return [] }

        var axisDates: [Date] = []

        switch timeRange {
        case .week:
            // Show 7 days
            for i in 0..<7 {
                if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                    axisDates.append(calendar.startOfDay(for: date))
                }
            }
            axisDates.reverse()

        case .month:
            // Show ~30 days, every 5 days
            for i in stride(from: 0, to: 31, by: 5) {
                if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                    axisDates.append(calendar.startOfDay(for: date))
                }
            }
            axisDates.reverse()

        case .sixMonths:
            // Show ~180 days, bi-weekly
            for i in stride(from: 0, to: 181, by: 14) {
                if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                    axisDates.append(calendar.startOfDay(for: date))
                }
            }
            axisDates.reverse()

        case .year:
            // Show 12 months
            for i in 0..<12 {
                if let date = calendar.date(byAdding: .month, value: -i, to: Date()) {
                    axisDates.append(calendar.startOfDay(for: date))
                }
            }
            axisDates.reverse()

        case .all:
            // Distribute dates across the full range
            let totalDays = calendar.dateComponents([.day], from: minDate, to: maxDate).day ?? 0
            let step = max(1, totalDays / 10) // Show ~10 points

            for i in stride(from: 0, to: totalDays + 1, by: step) {
                if let date = calendar.date(byAdding: .day, value: i, to: minDate) {
                    axisDates.append(calendar.startOfDay(for: date))
                }
            }
        }

        return axisDates
    }

    /// Get formatted X-axis values as strings
    static func getXAxisValues(
        for timeRange: TimeRange,
        filteredData: [any Dated],
        calendar: Calendar = .current
    ) -> [String] {
        let dates = getAllXAxisDates(for: timeRange, filteredData: filteredData, calendar: calendar)
        return dates.map { formatXAxisLabel($0, timeRange: timeRange) }
    }

    /// Format a date for X-axis label based on time range
    static func formatXAxisLabel(_ date: Date, timeRange: TimeRange) -> String {
        let formatter = DateFormatter()

        switch timeRange {
        case .week:
            formatter.dateFormat = "E" // Mon, Tue, Wed...
            return formatter.string(from: date)

        case .month:
            formatter.dateFormat = "d MMM" // 1 Jan, 15 Feb...
            return formatter.string(from: date)

        case .sixMonths, .year:
            formatter.dateFormat = "MMM" // Jan, Feb, Mar...
            return formatter.string(from: date)

        case .all:
            // Use month/year for very long ranges
            formatter.dateFormat = "MMM yy" // Jan 23, Feb 23...
            return formatter.string(from: date)
        }
    }
}

/// Protocol for any type that has a date property
/// Used to make ChartXAxisHelpers generic
protocol Dated {
    var date: Date { get }
}

// Extend your existing models to conform
extension MeasurementEntry: Dated {}
extension HealthDataPoint: Dated {}
