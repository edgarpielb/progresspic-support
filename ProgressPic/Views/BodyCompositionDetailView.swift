import SwiftUI
import Charts
import HealthKit

struct BodyCompositionDetailView: View {
    let metricType: BodyMetricType
    @ObservedObject var healthKit: HealthKitService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTimeRange: TimeRange = .year
    @State private var historicalData: [HealthDataPoint] = []
    @State private var isLoading = false
    @State private var userProfile = UserProfile.load()
    @State private var showAddDataSheet = false
    @State private var pointToDelete: HealthDataPoint?
    @State private var showDeleteConfirmation = false
    
    private var aggregatedData: [HealthDataPoint] {
        guard !historicalData.isEmpty else { return [] }
        
        switch selectedTimeRange {
        case .week:
            // Normalize to start of each day
            return aggregateByDay(historicalData)
        case .month:
            // Aggregate by week
            return aggregateByWeek(historicalData)
        case .sixMonths:
            // Aggregate by month
            return aggregateByMonth(historicalData)
        case .year:
            // Aggregate by month
            return aggregateByMonth(historicalData)
        case .all:
            // Aggregate by quarter
            return aggregateByQuarter(historicalData)
        }
    }
    
    var body: some View {
        ZStack {
            Color(red: 30/255, green: 32/255, blue: 35/255).ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Text(metricType.title)
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Color.clear
                            .frame(width: 30)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Time Range Selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(TimeRange.allCases) { range in
                                Button(action: {
                                    selectedTimeRange = range
                                    Task {
                                        await fetchData()
                                    }
                                }) {
                                    Text(range.rawValue)
                                        .font(.subheadline)
                                        .foregroundColor(selectedTimeRange == range ? .white : .white.opacity(0.6))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(selectedTimeRange == range ? Color.white.opacity(0.2) : Color.white.opacity(0.06))
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Stats Summary
                    if !historicalData.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(metricType.icon)
                                    .font(.caption)
                                Text(metricType.title.uppercased())
                                    .font(.caption)
                                    .foregroundStyle(.pink)
                            }
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(formatRange())
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            Text("Range • \(formatDateRange())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            // Min/Max stats
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Lowest")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(formatMinValue())
                                        .font(.callout.bold())
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Average")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(formatAverageValue())
                                        .font(.callout.bold())
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Highest")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(formatMaxValue())
                                        .font(.callout.bold())
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Chart
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 250)
                            .padding()
                    } else if historicalData.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.line.downtrend.xyaxis")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.3))
                            Text("No data for this period")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                        .padding()
                    } else {
                        Chart {
                            ForEach(Array(aggregatedData.enumerated()), id: \.offset) { index, point in
                                LineMark(
                                    x: .value("Date", formatXAxisLabel(point.date)),
                                    y: .value("Value", point.value)
                                )
                                .foregroundStyle(.pink)
                                .interpolationMethod(.catmullRom)
                                
                                PointMark(
                                    x: .value("Date", formatXAxisLabel(point.date)),
                                    y: .value("Value", point.value)
                                )
                                .foregroundStyle(.pink)
                                .symbolSize(30)
                            }
                        }
                        .chartYScale(domain: calculateYDomain())
                        .chartXScale(domain: .automatic(includesZero: false))
                        .chartXAxis {
                            AxisMarks { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                    .foregroundStyle(.white.opacity(0.1))
                                AxisValueLabel(centered: true)
                                    .foregroundStyle(.secondary)
                                    .font(.caption2)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .trailing) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                    .foregroundStyle(.white.opacity(0.1))
                                AxisValueLabel {
                                    if let doubleValue = value.as(Double.self) {
                                        Text(formatYAxisValue(doubleValue))
                                            .foregroundStyle(.secondary)
                                            .font(.caption2)
                                    }
                                }
                            }
                        }
                        .frame(height: 250)
                        .padding()
                        .padding(.trailing, 8)
                        .glassCard()
                        .padding(.horizontal)
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text(metricType.title)
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        
                        Text(metricType.description)
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    }
                    .padding()
                    .glassCard()
                    .padding(.horizontal)
                    
                    // Healthy Range Comparison
                    if let gender = userProfile.gender,
                       let latestValue = historicalData.last?.value {
                        let comparison = HealthyRangeComparison(
                            metricType: metricType,
                            userValue: latestValue,
                            userGender: gender,
                            userHeight: userProfile.heightCm,
                            userAge: userProfile.age
                        )
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "heart.text.square")
                                    .foregroundColor(.pink)
                                Text("Healthy Range")
                                    .font(.title3.bold())
                                    .foregroundColor(.white)
                            }
                            
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(comparison.comparisonColor)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(comparison.comparisonText)
                                        .font(.callout)
                                        .foregroundColor(.white)
                                    
                                    let range = comparison.healthyRange
                                    Text("\(comparison.rangeLabel): \(formatComparisonRange(range))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()
                        .padding(.horizontal)
                    }
                    
                    // All Recorded Data
                    VStack(alignment: .leading, spacing: 12) {
                        Text("All Recorded Data")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        if !historicalData.isEmpty {
                            List {
                                // Use explicit IDs for better performance
                                ForEach(Array(historicalData.reversed().enumerated()), id: \.element.id) { index, point in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(formatFullDate(point.date))
                                                .font(.callout)
                                                .foregroundColor(.white)
                                            Text("Apple Health")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(formatValue(point.value))
                                            .font(.callout.bold())
                                            .foregroundColor(.white)
                                    }
                                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                                    .listRowBackground(Color.white.opacity(0.05))
                                    .listRowSeparator(.visible, edges: .all)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            pointToDelete = point
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .tint(.red)
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .scrollDisabled(true)
                            .frame(height: CGFloat(historicalData.count * 60))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .glassCard()
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.top)
            }
            
            // Add Data Button (floating at bottom right)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showAddDataSheet = true
                    }) {
                        Text("Add Data")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.pink)
                            .cornerRadius(24)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await fetchData()
        }
        .sheet(isPresented: $showAddDataSheet) {
            AddHealthDataSheet(metricType: metricType, healthKit: healthKit) {
                Task {
                    await fetchData()
                }
            }
        }
        .alert("Delete Data", isPresented: $showDeleteConfirmation, presenting: pointToDelete) { point in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    let success = await healthKit.deleteHealthData(identifier: metricType.identifier, date: point.date)
                    if success {
                        await fetchData()
                    }
                }
            }
        } message: { point in
            Text("Are you sure you want to delete this data from \(formatFullDate(point.date))? This will remove it from Apple Health.")
        }
    }
    
    private func fetchData() async {
        isLoading = true
        historicalData = await healthKit.fetchHistoricalData(for: metricType.identifier, timeRange: selectedTimeRange)
        isLoading = false
    }
    
    private func formatRange() -> String {
        guard !historicalData.isEmpty else { return "--" }
        let first = historicalData.first?.value ?? 0
        let last = historicalData.last?.value ?? 0
        
        switch metricType {
        case .bodyFat:
            return String(format: "%.1f-%.1f %%", first, last)
        case .bmi:
            return String(format: "%.1f-%.1f", first, last)
        case .leanMass, .weight:
            return String(format: "%.1f-%.1f kg", first, last)
        }
    }
    
    private func formatMinValue() -> String {
        guard !historicalData.isEmpty else { return "--" }
        let values = historicalData.map { $0.value }
        let min = values.min() ?? 0
        
        switch metricType {
        case .bodyFat:
            return String(format: "%.1f %%", min)
        case .bmi:
            return String(format: "%.1f", min)
        case .leanMass, .weight:
            return String(format: "%.1f kg", min)
        }
    }
    
    private func formatMaxValue() -> String {
        guard !historicalData.isEmpty else { return "--" }
        let values = historicalData.map { $0.value }
        let max = values.max() ?? 0
        
        switch metricType {
        case .bodyFat:
            return String(format: "%.1f %%", max)
        case .bmi:
            return String(format: "%.1f", max)
        case .leanMass, .weight:
            return String(format: "%.1f kg", max)
        }
    }
    
    private func formatAverageValue() -> String {
        guard !historicalData.isEmpty else { return "--" }
        let values = historicalData.map { $0.value }
        let average = values.reduce(0, +) / Double(values.count)
        
        switch metricType {
        case .bodyFat:
            return String(format: "%.1f %%", average)
        case .bmi:
            return String(format: "%.1f", average)
        case .leanMass, .weight:
            return String(format: "%.1f kg", average)
        }
    }
    
    private func calculateYDomain() -> ClosedRange<Double> {
        guard !historicalData.isEmpty else { return 0...100 }
        
        let values = historicalData.map { $0.value }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 100
        
        // Add some padding (10% on each side)
        let range = maxValue - minValue
        let padding = Swift.max(range * 0.1, 1.0) // At least 1 unit of padding
        
        let lowerBound = Swift.max(0, minValue - padding)
        let upperBound = maxValue + padding
        
        return lowerBound...upperBound
    }
    
    private func formatValue(_ value: Double) -> String {
        switch metricType {
        case .bodyFat:
            return String(format: "%.1f %%", value)
        case .bmi:
            return String(format: "%.1f BMI", value)
        case .leanMass, .weight:
            return String(format: "%.1f kg", value)
        }
    }
    
    private func formatYAxisValue(_ value: Double) -> String {
        switch metricType {
        case .bodyFat:
            return String(format: "%.0f%%", value)
        case .bmi:
            return String(format: "%.0f", value)
        case .leanMass, .weight:
            return String(format: "%.0f", value)
        }
    }
    
    private func formatDateRange() -> String {
        guard let first = historicalData.first?.date,
              let last = historicalData.last?.date else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        
        return "\(formatter.string(from: first))-\(formatter.string(from: last))"
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
    
    private func formatComparisonRange(_ range: ClosedRange<Double>) -> String {
        switch metricType {
        case .bodyFat:
            return String(format: "%.1f%% - %.1f%%", range.lowerBound, range.upperBound)
        case .bmi:
            return String(format: "%.1f - %.1f", range.lowerBound, range.upperBound)
        case .leanMass, .weight:
            return String(format: "%.1f kg - %.1f kg", range.lowerBound, range.upperBound)
        }
    }
    
    private func getXAxisValues() -> [Date] {
        // Use the actual data point dates for perfect alignment
        return aggregatedData.map { $0.date }
    }
    
    private func formatXAxisLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        switch selectedTimeRange {
        case .week:
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
            
        case .month:
            // Show date ranges in 7-day spans (e.g., "8-14", "15-21")
            let startDay = calendar.component(.day, from: date)
            if let endDate = calendar.date(byAdding: .day, value: 6, to: date) {
                let endDay = calendar.component(.day, from: endDate)
                return "\(startDay)-\(endDay)"
            }
            return "\(startDay)"
            
        case .sixMonths:
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
            
        case .year:
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
            
        case .all:
            // Show quarters (Q1, Q2, Q3, Q4)
            let month = calendar.component(.month, from: date)
            let quarter = (month - 1) / 3 + 1
            let year = calendar.component(.year, from: date)
            return "Q\(quarter) '\(String(year).suffix(2))"
        }
    }
    
    private func aggregateByDay(_ data: [HealthDataPoint]) -> [HealthDataPoint] {
        guard !data.isEmpty else { return [] }
        
        let calendar = Calendar.current
        var dailyData: [Date: [Double]] = [:]
        // Pre-allocate capacity for better performance
        dailyData.reserveCapacity(min(data.count, 7))
        
        // Collect data points by day
        for point in data {
            let dayStart = calendar.startOfDay(for: point.date)
            if dailyData[dayStart] == nil {
                dailyData[dayStart] = []
            }
            dailyData[dayStart]?.append(point.value)
        }
        
        // Get the most recent date and find the week it belongs to
        guard let mostRecentDate = data.map({ $0.date }).max() else {
            return []
        }
        
        // Find Monday of the week containing the most recent date
        var weekStart = calendar.startOfDay(for: mostRecentDate)
        let weekday = calendar.component(.weekday, from: weekStart)
        
        // Adjust to Monday (weekday 2 in Gregorian calendar, 1 = Sunday)
        let daysToSubtract = weekday == 1 ? 6 : weekday - 2
        weekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: weekStart) ?? weekStart
        
        // Generate all 7 days (Mon-Sun)
        var results: [HealthDataPoint] = []
        var currentDate = weekStart
        
        for _ in 0..<7 {
            if let values = dailyData[currentDate] {
                let average = values.reduce(0, +) / Double(values.count)
                results.append(HealthDataPoint(date: currentDate, value: average))
            } else {
                // Add interpolated point to maintain chart structure
                if let lastValue = results.last?.value {
                    results.append(HealthDataPoint(date: currentDate, value: lastValue))
                }
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return results
    }
    
    private func aggregateByWeek(_ data: [HealthDataPoint]) -> [HealthDataPoint] {
        guard !data.isEmpty else { return [] }
        
        let calendar = Calendar.current
        var weeklyData: [Date: [Double]] = [:]
        
        // Collect data points by week
        for point in data {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: point.date)?.start ?? point.date
            if weeklyData[weekStart] == nil {
                weeklyData[weekStart] = []
            }
            weeklyData[weekStart]?.append(point.value)
        }
        
        // Get the first and last dates
        guard let firstDate = data.map({ $0.date }).min(),
              let lastDate = data.map({ $0.date }).max() else {
            return []
        }
        
        let startWeek = calendar.dateInterval(of: .weekOfYear, for: firstDate)?.start ?? firstDate
        let endWeek = calendar.dateInterval(of: .weekOfYear, for: lastDate)?.start ?? lastDate
        
        // Generate all weeks in range
        var results: [HealthDataPoint] = []
        var currentDate = startWeek
        
        while currentDate <= endWeek {
            if let values = weeklyData[currentDate] {
                let average = values.reduce(0, +) / Double(values.count)
                results.append(HealthDataPoint(date: currentDate, value: average))
            }
            // Don't add interpolated points - only plot actual data
            currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
        }
        
        return results
    }
    
    private func aggregateByMonth(_ data: [HealthDataPoint]) -> [HealthDataPoint] {
        guard !data.isEmpty else { return [] }
        
        let calendar = Calendar.current
        var monthlyData: [Date: [Double]] = [:]
        
        // Collect data points by month
        for point in data {
            let monthStart = calendar.dateInterval(of: .month, for: point.date)?.start ?? point.date
            if monthlyData[monthStart] == nil {
                monthlyData[monthStart] = []
            }
            monthlyData[monthStart]?.append(point.value)
        }
        
        // Get the most recent date and calculate 12 months back
        guard let mostRecentDate = data.map({ $0.date }).max() else {
            return []
        }
        
        let endMonth = calendar.dateInterval(of: .month, for: mostRecentDate)?.start ?? mostRecentDate
        // Go back 11 months (12 months total including current)
        let startMonth = calendar.date(byAdding: .month, value: -11, to: endMonth) ?? endMonth
        
        // Generate only the most recent 12 months
        var results: [HealthDataPoint] = []
        var currentDate = startMonth
        
        while currentDate <= endMonth {
            if let values = monthlyData[currentDate] {
                let average = values.reduce(0, +) / Double(values.count)
                results.append(HealthDataPoint(date: currentDate, value: average))
            }
            // Don't add interpolated points - only plot actual data
            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
        }
        
        return results
    }
    
    private func aggregateByQuarter(_ data: [HealthDataPoint]) -> [HealthDataPoint] {
        guard !data.isEmpty else { return [] }
        
        let calendar = Calendar.current
        var quarterlyData: [Date: [Double]] = [:]
        
        // Collect data points by quarter
        for point in data {
            let components = calendar.dateComponents([.year, .month], from: point.date)
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
                quarterlyData[quarterStart]?.append(point.value)
            }
        }
        
        // Get the first and last dates
        guard let firstDate = data.map({ $0.date }).min(),
              let lastDate = data.map({ $0.date }).max() else {
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
        var results: [HealthDataPoint] = []
        var currentDate = startQuarter
        
        while currentDate <= endQuarter {
            if let values = quarterlyData[currentDate] {
                let average = values.reduce(0, +) / Double(values.count)
                results.append(HealthDataPoint(date: currentDate, value: average))
            }
            // Don't add interpolated points - only plot actual data
            currentDate = calendar.date(byAdding: .month, value: 3, to: currentDate) ?? currentDate
        }
        
        return results
    }
}

struct HealthyRangeComparison {
    let metricType: BodyMetricType
    let userValue: Double
    let userGender: UserProfile.Gender
    let userHeight: Double? // in cm
    let userAge: Int?
    
    var healthyRange: ClosedRange<Double> {
        switch metricType {
        case .bodyFat:
            return healthyBodyFat(gender: userGender)
        case .bmi:
            return healthyBMI()
        case .leanMass:
            return averageLeanMass(gender: userGender, height: userHeight, age: userAge)
        case .weight:
            return healthyWeight(gender: userGender, height: userHeight)
        }
    }
    
    var rangeLabel: String {
        return metricType == .leanMass ? "Average range" : "Healthy range"
    }
    
    var comparisonText: String {
        let range = healthyRange
        
        // For lean mass, show comparison to average
        if metricType == .leanMass {
            if userValue < range.lowerBound {
                return "Below average for your demographics"
            } else if userValue > range.upperBound {
                return "Above average for your demographics"
            } else {
                return "Within average range"
            }
        }
        
        // For other metrics, use standard comparison
        if userValue < range.lowerBound {
            return "Below healthy range"
        } else if userValue > range.upperBound {
            return "Above healthy range"
        } else {
            return "Within healthy range"
        }
    }
    
    var comparisonColor: Color {
        let range = healthyRange
        
        // For lean mass, any value is "okay" - it's just informational
        if metricType == .leanMass {
            // Show blue for informational (not a health judgment)
            return .blue
        }
        
        // For other metrics, must be within range
        if userValue >= range.lowerBound && userValue <= range.upperBound {
            return .green
        } else {
            return .orange
        }
    }
    
    private func healthyBodyFat(gender: UserProfile.Gender) -> ClosedRange<Double> {
        // General healthy ranges based on fitness standards
        switch gender {
        case .male:
            return 10...20 // Athletic to fitness range
        case .female:
            return 18...28 // Athletic to fitness range
        }
    }
    
    private func healthyBMI() -> ClosedRange<Double> {
        return 18.5...24.9 // WHO healthy BMI range
    }
    
    private func averageLeanMass(gender: UserProfile.Gender, height: Double?, age: Int?) -> ClosedRange<Double> {
        guard let heightCm = height else {
            // Fallback to general averages
            switch gender {
            case .male: return 55...75
            case .female: return 40...60
            }
        }
        
        let heightM = heightCm / 100.0
        let heightSquared = heightM * heightM
        
        // Base lean mass index (LMI) ranges by gender
        // These are average population ranges, not "healthy" thresholds
        var baseLMI: (lower: Double, upper: Double)
        
        switch gender {
        case .male:
            baseLMI = (16.5, 20.5) // Average male range
        case .female:
            baseLMI = (13.5, 17.5) // Average female range
        }
        
        // Adjust for age - lean mass typically decreases with age
        if let userAge = age {
            let ageAdjustment: Double
            switch userAge {
            case 18...29:
                ageAdjustment = 0.5  // Young adults have more muscle
            case 30...39:
                ageAdjustment = 0.0  // Prime adult years
            case 40...49:
                ageAdjustment = -0.5 // Slight decline
            case 50...59:
                ageAdjustment = -1.0 // More decline
            case 60...69:
                ageAdjustment = -1.5 // Significant decline
            case 70...:
                ageAdjustment = -2.0 // Natural age-related loss
            default:
                ageAdjustment = 0.5  // Under 18, still developing
            }
            
            baseLMI.lower = Swift.max(10.0, baseLMI.lower + ageAdjustment)
            baseLMI.upper = Swift.max(baseLMI.lower + 2.0, baseLMI.upper + ageAdjustment)
        }
        
        // Calculate actual lean mass range based on height
        let minLean = heightSquared * baseLMI.lower
        let maxLean = heightSquared * baseLMI.upper
        
        return minLean...maxLean
    }
    
    private func healthyWeight(gender: UserProfile.Gender, height: Double?) -> ClosedRange<Double> {
        guard let heightCm = height else {
            // Fallback to average height estimates
            switch gender {
            case .male: return 60...80
            case .female: return 50...70
            }
        }
        
        let heightM = heightCm / 100.0
        let heightSquared = heightM * heightM
        
        // Use healthy BMI range (18.5-24.9) with user's actual height
        // Weight = BMI × Height²
        let minWeight = 18.5 * heightSquared
        let maxWeight = 24.9 * heightSquared
        
        return minWeight...maxWeight
    }
}

enum BodyMetricType {
    case bodyFat
    case bmi
    case leanMass
    case weight
    
    var title: String {
        switch self {
        case .bodyFat: return "Body Fat Percentage"
        case .bmi: return "Body Mass Index"
        case .leanMass: return "Lean Mass"
        case .weight: return "Weight"
        }
    }
    
    var icon: String {
        switch self {
        case .bodyFat: return "🔥"
        case .bmi: return "📊"
        case .leanMass: return "💪"
        case .weight: return "⚖️"
        }
    }
    
    var identifier: HKQuantityTypeIdentifier {
        switch self {
        case .bodyFat: return .bodyFatPercentage
        case .bmi: return .bodyMassIndex
        case .leanMass: return .leanBodyMass
        case .weight: return .bodyMass
        }
    }
    
    var description: String {
        switch self {
        case .bodyFat:
            return "Body fat percentage indicates the proportion of fat in your body composition. It's an important health metric that affects both athletic performance and long-term wellness. A balanced body fat percentage supports hormonal function, energy levels, and physical performance."
        case .bmi:
            return "Body Mass Index (BMI) is a measure of body fat based on height and weight. It's commonly used as a general indicator of whether a person has a healthy body weight. However, BMI doesn't directly measure body fat and may not be accurate for athletes or people with high muscle mass."
        case .leanMass:
            return "Lean Body Mass represents the weight of everything in your body except fat, including muscles, bones, organs, and water. Maintaining or increasing lean mass is important for metabolic health, physical strength, and overall fitness. Regular exercise, especially resistance training, can help preserve and build lean mass."
        case .weight:
            return "Body weight is the total mass of your body, including bones, muscles, fat, organs, and water. Monitoring your weight over time can help track changes in your overall health and fitness. However, weight alone doesn't tell the whole story—body composition metrics like body fat percentage and lean mass provide more insight."
        }
    }
}

struct AddHealthDataSheet: View {
    let metricType: BodyMetricType
    @ObservedObject var healthKit: HealthKitService
    var onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var value: String = ""
    @State private var selectedDate = Date()
    @State private var isSaving = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    
                    HStack {
                        Text(metricType.title)
                        Spacer()
                        TextField("Value", text: $value)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text(unit)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Add \(metricType.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveData()
                        }
                    }
                    .disabled(value.isEmpty || isSaving)
                }
            }
        }
    }
    
    private var unit: String {
        switch metricType {
        case .bodyFat: return "%"
        case .bmi: return ""
        case .leanMass, .weight: return "kg"
        }
    }
    
    private func saveData() async {
        guard let doubleValue = Double(value) else { return }
        isSaving = true
        
        let success = await healthKit.saveHealthData(
            type: metricType.identifier,
            value: doubleValue,
            date: selectedDate
        )
        
        isSaving = false
        
        if success {
            onSave()
            dismiss()
        }
    }
}

