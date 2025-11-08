import Foundation

/// Centralized statistics formatting utilities
/// Eliminates ~80 lines of duplicated min/max/average code
enum StatsFormatters {

    // MARK: - Generic Statistics

    /// Calculate and format minimum value
    static func formatMin<T>(
        _ data: [T],
        valueKeyPath: KeyPath<T, Double>,
        unit: String,
        decimalPlaces: Int = 1,
        emptyPlaceholder: String = "--"
    ) -> String {
        guard !data.isEmpty else { return emptyPlaceholder }

        let values = data.map { $0[keyPath: valueKeyPath] }
        guard let min = values.min() else { return emptyPlaceholder }

        return String(format: "%.\(decimalPlaces)f \(unit)", min)
    }

    /// Calculate and format maximum value
    static func formatMax<T>(
        _ data: [T],
        valueKeyPath: KeyPath<T, Double>,
        unit: String,
        decimalPlaces: Int = 1,
        emptyPlaceholder: String = "--"
    ) -> String {
        guard !data.isEmpty else { return emptyPlaceholder }

        let values = data.map { $0[keyPath: valueKeyPath] }
        guard let max = values.max() else { return emptyPlaceholder }

        return String(format: "%.\(decimalPlaces)f \(unit)", max)
    }

    /// Calculate and format average value
    static func formatAverage<T>(
        _ data: [T],
        valueKeyPath: KeyPath<T, Double>,
        unit: String,
        decimalPlaces: Int = 1,
        emptyPlaceholder: String = "--"
    ) -> String {
        guard !data.isEmpty else { return emptyPlaceholder }

        let values = data.map { $0[keyPath: valueKeyPath] }
        let sum = values.reduce(0, +)
        let average = sum / Double(values.count)

        return String(format: "%.\(decimalPlaces)f \(unit)", average)
    }

    /// Calculate and format range (min - max)
    static func formatRange<T>(
        _ data: [T],
        valueKeyPath: KeyPath<T, Double>,
        unit: String,
        decimalPlaces: Int = 1,
        emptyPlaceholder: String = "--"
    ) -> String {
        guard !data.isEmpty else { return emptyPlaceholder }

        let values = data.map { $0[keyPath: valueKeyPath] }
        guard let min = values.min(), let max = values.max() else {
            return emptyPlaceholder
        }

        let range = max - min
        return String(format: "%.\(decimalPlaces)f \(unit)", range)
    }

    // MARK: - Chart Domain Calculation

    /// Calculate Y-domain for charts with padding
    static func calculateYDomain<T>(
        for data: [T],
        valueKeyPath: KeyPath<T, Double>,
        paddingPercent: Double = 0.1,
        minPadding: Double = 1.0,
        allowNegative: Bool = true
    ) -> ClosedRange<Double> {
        guard !data.isEmpty else {
            return 0...100 // Default range
        }

        let values = data.map { $0[keyPath: valueKeyPath] }
        guard let minValue = values.min(), let maxValue = values.max() else {
            return 0...100
        }

        let range = maxValue - minValue
        let padding = Swift.max(range * paddingPercent, minPadding)

        let lowerBound: Double
        if allowNegative {
            lowerBound = minValue - padding
        } else {
            lowerBound = Swift.max(0, minValue - padding)
        }

        let upperBound = maxValue + padding

        return lowerBound...upperBound
    }

    // MARK: - Specialized Formatters

    /// Format percentage
    static func formatPercentage(_ value: Double, decimalPlaces: Int = 1) -> String {
        String(format: "%.\(decimalPlaces)f%%", value)
    }

    /// Format change with +/- sign
    static func formatChange(_ value: Double, unit: String = "", decimalPlaces: Int = 1) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.\(decimalPlaces)f", value)) \(unit)".trimmingCharacters(in: .whitespaces)
    }

    /// Format duration in seconds to human readable
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }

    // MARK: - Value Extraction

    /// Get raw statistics values
    static func getStats<T>(
        _ data: [T],
        valueKeyPath: KeyPath<T, Double>
    ) -> (min: Double, max: Double, average: Double, range: Double)? {
        guard !data.isEmpty else { return nil }

        let values = data.map { $0[keyPath: valueKeyPath] }
        guard let min = values.min(), let max = values.max() else {
            return nil
        }

        let sum = values.reduce(0, +)
        let average = sum / Double(values.count)
        let range = max - min

        return (min: min, max: max, average: average, range: range)
    }
}
