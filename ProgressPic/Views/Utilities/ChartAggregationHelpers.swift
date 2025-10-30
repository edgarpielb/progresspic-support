import Foundation

// MARK: - Chart Data Aggregation Helpers
// Shared utilities for aggregating time-series data in charts
// Used by MeasurementDetailView and BodyCompositionDetailView to reduce code duplication

enum ChartAggregationHelpers {
    
    /// Aggregate data points by day (for week view)
    static func aggregateByDay<T>(_ data: [T], dateKeyPath: KeyPath<T, Date>, valueKeyPath: KeyPath<T, Double>, createPoint: (Date, Double) -> T) -> [T] {
        guard !data.isEmpty else { return [] }
        
        let calendar = Calendar.current
        var dailyData: [Date: [Double]] = [:]
        dailyData.reserveCapacity(min(data.count, 7))
        
        // Collect data points by day
        for point in data {
            let dayStart = calendar.startOfDay(for: point[keyPath: dateKeyPath])
            if dailyData[dayStart] == nil {
                dailyData[dayStart] = []
            }
            dailyData[dayStart]?.append(point[keyPath: valueKeyPath])
        }
        
        // Get the most recent date and find the week it belongs to
        guard let mostRecentDate = data.map({ $0[keyPath: dateKeyPath] }).max() else {
            return []
        }
        
        // Find Monday of the week containing the most recent date
        var weekStart = calendar.startOfDay(for: mostRecentDate)
        let weekday = calendar.component(.weekday, from: weekStart)
        
        // Adjust to Monday (weekday 2 in Gregorian calendar, 1 = Sunday)
        let daysToSubtract = weekday == 1 ? 6 : weekday - 2
        weekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: weekStart) ?? weekStart
        
        // Generate results only for days that have data
        var results: [T] = []
        var currentDate = weekStart
        
        for _ in 0..<7 {
            if let values = dailyData[currentDate] {
                let average = values.reduce(0, +) / Double(values.count)
                results.append(createPoint(currentDate, average))
            }
            // Don't add interpolated points - only plot actual data
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return results
    }
    
    /// Aggregate data points by week (for month view)
    static func aggregateByWeek<T>(_ data: [T], dateKeyPath: KeyPath<T, Date>, valueKeyPath: KeyPath<T, Double>, createPoint: (Date, Double) -> T) -> [T] {
        guard !data.isEmpty else { return [] }
        
        let calendar = Calendar.current
        var weeklyData: [Date: [Double]] = [:]
        
        // Collect data points by week
        for point in data {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: point[keyPath: dateKeyPath])?.start ?? point[keyPath: dateKeyPath]
            if weeklyData[weekStart] == nil {
                weeklyData[weekStart] = []
            }
            weeklyData[weekStart]?.append(point[keyPath: valueKeyPath])
        }
        
        // Get the first and last dates
        guard let firstDate = data.map({ $0[keyPath: dateKeyPath] }).min(),
              let lastDate = data.map({ $0[keyPath: dateKeyPath] }).max() else {
            return []
        }
        
        let startWeek = calendar.dateInterval(of: .weekOfYear, for: firstDate)?.start ?? firstDate
        let endWeek = calendar.dateInterval(of: .weekOfYear, for: lastDate)?.start ?? lastDate
        
        // Generate all weeks in range
        var results: [T] = []
        var currentDate = startWeek
        
        while currentDate <= endWeek {
            if let values = weeklyData[currentDate] {
                let average = values.reduce(0, +) / Double(values.count)
                results.append(createPoint(currentDate, average))
            }
            currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
        }
        
        return results
    }
    
    /// Aggregate data points by month (for 6-month and year views)
    static func aggregateByMonth<T>(_ data: [T], dateKeyPath: KeyPath<T, Date>, valueKeyPath: KeyPath<T, Double>, createPoint: (Date, Double) -> T) -> [T] {
        guard !data.isEmpty else { return [] }
        
        let calendar = Calendar.current
        var monthlyData: [Date: [Double]] = [:]
        
        // Collect data points by month
        for point in data {
            let monthStart = calendar.dateInterval(of: .month, for: point[keyPath: dateKeyPath])?.start ?? point[keyPath: dateKeyPath]
            if monthlyData[monthStart] == nil {
                monthlyData[monthStart] = []
            }
            monthlyData[monthStart]?.append(point[keyPath: valueKeyPath])
        }
        
        // Get the most recent date and calculate 12 months back
        guard let mostRecentDate = data.map({ $0[keyPath: dateKeyPath] }).max() else {
            return []
        }
        
        let endMonth = calendar.dateInterval(of: .month, for: mostRecentDate)?.start ?? mostRecentDate
        let startMonth = calendar.date(byAdding: .month, value: -11, to: endMonth) ?? endMonth
        
        // Generate only the most recent 12 months
        var results: [T] = []
        var currentDate = startMonth
        
        while currentDate <= endMonth {
            if let values = monthlyData[currentDate] {
                let average = values.reduce(0, +) / Double(values.count)
                results.append(createPoint(currentDate, average))
            }
            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
        }
        
        return results
    }
    
    /// Aggregate data points by quarter (for all-time view)
    static func aggregateByQuarter<T>(_ data: [T], dateKeyPath: KeyPath<T, Date>, valueKeyPath: KeyPath<T, Double>, createPoint: (Date, Double) -> T) -> [T] {
        guard !data.isEmpty else { return [] }
        
        let calendar = Calendar.current
        var quarterlyData: [Date: [Double]] = [:]
        
        // Collect data points by quarter
        for point in data {
            let components = calendar.dateComponents([.year, .month], from: point[keyPath: dateKeyPath])
            let month = components.month ?? 1
            let year = components.year ?? 2024
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            
            var quarterComponents = DateComponents()
            quarterComponents.year = year
            quarterComponents.month = quarterStartMonth
            quarterComponents.day = 1
            
            if let quarterStart = calendar.date(from: quarterComponents) {
                if quarterlyData[quarterStart] == nil {
                    quarterlyData[quarterStart] = []
                }
                quarterlyData[quarterStart]?.append(point[keyPath: valueKeyPath])
            }
        }
        
        // Get the first and last dates
        guard let firstDate = data.map({ $0[keyPath: dateKeyPath] }).min(),
              let lastDate = data.map({ $0[keyPath: dateKeyPath] }).max() else {
            return []
        }
        
        // Get quarter starts
        let firstComponents = calendar.dateComponents([.year, .month], from: firstDate)
        let firstMonth = firstComponents.month ?? 1
        let firstYear = firstComponents.year ?? 2024
        let firstQuarterMonth = ((firstMonth - 1) / 3) * 3 + 1
        
        var startComponents = DateComponents()
        startComponents.year = firstYear
        startComponents.month = firstQuarterMonth
        startComponents.day = 1
        
        let lastComponents = calendar.dateComponents([.year, .month], from: lastDate)
        let lastMonth = lastComponents.month ?? 1
        let lastYear = lastComponents.year ?? 2024
        let lastQuarterMonth = ((lastMonth - 1) / 3) * 3 + 1
        
        var endComponents = DateComponents()
        endComponents.year = lastYear
        endComponents.month = lastQuarterMonth
        endComponents.day = 1
        
        guard let startQuarter = calendar.date(from: startComponents),
              let endQuarter = calendar.date(from: endComponents) else {
            return []
        }
        
        // Generate all quarters in range
        var results: [T] = []
        var currentDate = startQuarter
        
        while currentDate <= endQuarter {
            if let values = quarterlyData[currentDate] {
                let average = values.reduce(0, +) / Double(values.count)
                results.append(createPoint(currentDate, average))
            }
            currentDate = calendar.date(byAdding: .month, value: 3, to: currentDate) ?? currentDate
        }
        
        return results
    }
}

