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

        let createPoint = { (date: Date, value: Double) -> HealthDataPoint in
            HealthDataPoint(date: date, value: value)
        }

        switch selectedTimeRange {
        case .week:
            return ChartAggregationHelpers.aggregateByDay(
                historicalData,
                dateKeyPath: \.date,
                valueKeyPath: \.value,
                createPoint: createPoint
            )
        case .month:
            return ChartAggregationHelpers.aggregateByWeek(
                historicalData,
                dateKeyPath: \.date,
                valueKeyPath: \.value,
                createPoint: createPoint
            )
        case .sixMonths, .year:
            return ChartAggregationHelpers.aggregateByMonth(
                historicalData,
                dateKeyPath: \.date,
                valueKeyPath: \.value,
                createPoint: createPoint
            )
        case .all:
            return ChartAggregationHelpers.aggregateByQuarter(
                historicalData,
                dateKeyPath: \.date,
                valueKeyPath: \.value,
                createPoint: createPoint
            )
        }
    }
    
    var body: some View {
        ZStack {
            AppStyle.Colors.bgDark.ignoresSafeArea()
            
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
                    TimeRangeSelector(selectedRange: $selectedTimeRange)
                        .onChange(of: selectedTimeRange) { _, _ in
                            Task {
                                await fetchData()
                            }
                        }
                    
                    // Stats Summary
                    if !historicalData.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(metricType.icon)
                                    .font(.caption)
                                Text(metricType.title.uppercased())
                                    .font(.caption)
                                    .foregroundStyle(AppStyle.Colors.accentPrimary)
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
                        EmptyStateView(
                            icon: "chart.line.downtrend.xyaxis",
                            title: "No data for this period"
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                        .padding()
                    } else {
                        let allXAxisLabels = getAllXAxisDates().map { formatXAxisLabel($0) }
                        
                        Chart {
                            ForEach(Array(aggregatedData.enumerated()), id: \.offset) { index, point in
                                LineMark(
                                    x: .value("Date", formatXAxisLabel(point.date)),
                                    y: .value("Value", point.value)
                                )
                                .foregroundStyle(AppStyle.Colors.accentPrimary)
                                .interpolationMethod(.catmullRom)
                                
                                PointMark(
                                    x: .value("Date", formatXAxisLabel(point.date)),
                                    y: .value("Value", point.value)
                                )
                                .foregroundStyle(AppStyle.Colors.accentPrimary)
                                .symbolSize(30)
                            }
                        }
                        .chartXScale(domain: allXAxisLabels)
                        .chartYScale(domain: calculateYDomain())
                        .chartXAxis {
                            AxisMarks(values: allXAxisLabels) { value in
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
                                    .foregroundColor(AppStyle.Colors.accentPrimary)
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
                            VStack(spacing: 0) {
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
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 16)
                                    .background(Color.white.opacity(0.05))
                                    .contentShape(Rectangle())
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            pointToDelete = point
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    
                                    if index < historicalData.count - 1 {
                                        Divider()
                                            .background(Color.white.opacity(0.1))
                                    }
                                }
                            }
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
                            .background(AppStyle.Colors.accentPrimary)
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
        let unit = metricType == .bodyFat ? "%" : (metricType == .bmi ? "" : "kg")
        return StatsFormatters.formatMin(historicalData, valueKeyPath: \.value, unit: unit)
    }

    private func formatMaxValue() -> String {
        let unit = metricType == .bodyFat ? "%" : (metricType == .bmi ? "" : "kg")
        return StatsFormatters.formatMax(historicalData, valueKeyPath: \.value, unit: unit)
    }

    private func formatAverageValue() -> String {
        let unit = metricType == .bodyFat ? "%" : (metricType == .bmi ? "" : "kg")
        return StatsFormatters.formatAverage(historicalData, valueKeyPath: \.value, unit: unit)
    }

    private func calculateYDomain() -> ClosedRange<Double> {
        StatsFormatters.calculateYDomain(
            for: historicalData,
            valueKeyPath: \.value,
            paddingPercent: 0.1,
            minPadding: 1.0,
            allowNegative: false
        )
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

        return DateFormatters.formatDateRange(from: first, to: last)
    }

    private func formatFullDate(_ date: Date) -> String {
        DateFormatters.formatFullDate(date)
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
    
    
    private func getAllXAxisDates() -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeRange {
        case .week:
            // Get the week containing the most recent measurement (or today if no data)
            let referenceDate = historicalData.last?.date ?? now
            var weekStart = calendar.startOfDay(for: referenceDate)
            let weekday = calendar.component(.weekday, from: weekStart)
            let daysToSubtract = weekday == 1 ? 6 : weekday - 2
            weekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: weekStart) ?? weekStart
            
            // Generate all 7 days (Mon-Sun)
            var dates: [Date] = []
            var currentDate = weekStart
            for _ in 0..<7 {
                dates.append(currentDate)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            return dates
            
        case .month:
            // Show last 4 weeks
            let referenceDate = historicalData.last?.date ?? now
            let endWeek = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start ?? calendar.startOfDay(for: referenceDate)
            
            var dates: [Date] = []
            var currentDate = calendar.date(byAdding: .weekOfYear, value: -3, to: endWeek) ?? endWeek
            
            for _ in 0..<4 {
                dates.append(currentDate)
                currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
            }
            return dates
            
        case .sixMonths:
            // Show 6 months
            let endMonth = calendar.dateInterval(of: .month, for: historicalData.last?.date ?? now)?.start ?? calendar.startOfDay(for: now)
            let startMonth = calendar.date(byAdding: .month, value: -5, to: endMonth) ?? endMonth
            
            var dates: [Date] = []
            var currentDate = startMonth
            for _ in 0..<6 {
                dates.append(currentDate)
                currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
            }
            return dates
            
        case .year:
            // Show 12 months
            let endMonth = calendar.dateInterval(of: .month, for: historicalData.last?.date ?? now)?.start ?? calendar.startOfDay(for: now)
            let startMonth = calendar.date(byAdding: .month, value: -11, to: endMonth) ?? endMonth
            
            var dates: [Date] = []
            var currentDate = startMonth
            for _ in 0..<12 {
                dates.append(currentDate)
                currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
            }
            return dates
            
        case .all:
            // For all view, show quarters based on actual data range
            guard let firstDate = historicalData.first?.date,
                  let lastDate = historicalData.last?.date else {
                return []
            }
            
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
            
            var dates: [Date] = []
            var currentDate = startQuarter
            while currentDate <= endQuarter {
                dates.append(currentDate)
                currentDate = calendar.date(byAdding: .month, value: 3, to: currentDate) ?? currentDate
            }
            return dates
        }
    }
    
    private func getXAxisValues() -> [String] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeRange {
        case .week:
            // Get the week containing the most recent measurement (or today if no data)
            let referenceDate = historicalData.last?.date ?? now
            var weekStart = calendar.startOfDay(for: referenceDate)
            let weekday = calendar.component(.weekday, from: weekStart)
            let daysToSubtract = weekday == 1 ? 6 : weekday - 2
            weekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: weekStart) ?? weekStart
            
            // Generate all 7 days (Mon-Sun)
            var dates: [String] = []
            var currentDate = weekStart
            for _ in 0..<7 {
                dates.append(formatXAxisLabel(currentDate))
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            return dates
            
        case .month:
            // Show 4-5 weeks based on actual data range
            let startDate = historicalData.first?.date ?? calendar.date(byAdding: .month, value: -1, to: now) ?? now
            let endDate = historicalData.last?.date ?? now
            
            let startWeek = calendar.dateInterval(of: .weekOfYear, for: startDate)?.start ?? startDate
            let endWeek = calendar.dateInterval(of: .weekOfYear, for: endDate)?.start ?? endDate
            
            var dates: [String] = []
            var currentDate = startWeek
            while currentDate <= endWeek {
                dates.append(formatXAxisLabel(currentDate))
                currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
            }
            return dates
            
        case .sixMonths:
            // Show 6 months
            let endMonth = calendar.dateInterval(of: .month, for: historicalData.last?.date ?? now)?.start ?? calendar.startOfDay(for: now)
            let startMonth = calendar.date(byAdding: .month, value: -5, to: endMonth) ?? endMonth
            
            var dates: [String] = []
            var currentDate = startMonth
            for _ in 0..<6 {
                dates.append(formatXAxisLabel(currentDate))
                currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
            }
            return dates
            
        case .year:
            // Show 12 months
            let endMonth = calendar.dateInterval(of: .month, for: historicalData.last?.date ?? now)?.start ?? calendar.startOfDay(for: now)
            let startMonth = calendar.date(byAdding: .month, value: -11, to: endMonth) ?? endMonth
            
            var dates: [String] = []
            var currentDate = startMonth
            for _ in 0..<12 {
                dates.append(formatXAxisLabel(currentDate))
                currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
            }
            return dates
            
        case .all:
            // For all view, show quarters based on actual data range
            guard let firstDate = historicalData.first?.date,
                  let lastDate = historicalData.last?.date else {
                return []
            }
            
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
            
            var dates: [String] = []
            var currentDate = startQuarter
            while currentDate <= endQuarter {
                dates.append(formatXAxisLabel(currentDate))
                currentDate = calendar.date(byAdding: .month, value: 3, to: currentDate) ?? currentDate
            }
            return dates
        }
    }
    
    private func formatXAxisLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        switch selectedTimeRange {
        case .week:
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
            
        case .month:
            // Show date ranges in 7-day spans (e.g., "27-2" for Oct 27 - Nov 2)
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
    
}

