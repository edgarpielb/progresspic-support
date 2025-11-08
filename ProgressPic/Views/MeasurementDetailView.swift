import SwiftUI
import SwiftData
import Charts

struct MeasurementDetailView: View {
    let journey: Journey
    let initialMeasurementType: MeasurementType
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query private var allEntries: [MeasurementEntry]
    
    @State private var selectedTimeRange: MeasurementTimeRange = .all
    @State private var userProfile = UserProfile.load()
    @State private var selectedSide: MeasurementType
    @State private var showAddSheet = false
    @State private var entryToDelete: MeasurementEntry?
    @State private var showDeleteConfirmation = false
    @State private var showExportSheet = false
    @State private var exportFileURL: URL?
    
    init(journey: Journey, measurementType: MeasurementType) {
        self.journey = journey
        self.initialMeasurementType = measurementType
        let journeyId = journey.id
        _allEntries = Query(
            filter: #Predicate<MeasurementEntry> { entry in
                entry.journeyId == journeyId
            },
            sort: \MeasurementEntry.date,
            order: .forward
        )
        _selectedSide = State(initialValue: measurementType)
    }
    
    // Filter entries based on selected side
    private var entries: [MeasurementEntry] {
        allEntries.filter { $0.type == selectedSide }
    }
    
    // Get the current measurement type being displayed
    private var measurementType: MeasurementType {
        selectedSide
    }
    
    var filteredEntries: [MeasurementEntry] {
        let now = Date()
        switch selectedTimeRange {
        case .week:
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
            return entries.filter { $0.date >= weekAgo }
        case .month:
            let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now
            return entries.filter { $0.date >= monthAgo }
        case .sixMonths:
            let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: now) ?? now
            return entries.filter { $0.date >= sixMonthsAgo }
        case .year:
            let yearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
            return entries.filter { $0.date >= yearAgo }
        case .all:
            return entries
        }
    }
    
    var aggregatedEntries: [MeasurementEntry] {
        guard !filteredEntries.isEmpty else { return [] }
        
        switch selectedTimeRange {
        case .week:
            // Normalize to start of each day
            return aggregateEntriesByDay(filteredEntries)
        case .month:
            // Aggregate by week
            return aggregateEntriesByWeek(filteredEntries)
        case .sixMonths:
            // Aggregate by month
            return aggregateEntriesByMonth(filteredEntries)
        case .year:
            // Aggregate by month
            return aggregateEntriesByMonth(filteredEntries)
        case .all:
            // Aggregate by quarter
            return aggregateEntriesByQuarter(filteredEntries)
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
                        Text(initialMeasurementType.hasPairedVariant ? initialMeasurementType.baseName : measurementType.title)
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        // Export button
                        Button(action: {
                            exportToCSV()
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Left/Right Toggle (only for paired measurements)
                    if initialMeasurementType.hasPairedVariant, let pairedType = initialMeasurementType.pairedMeasurement {
                        HStack(spacing: 12) {
                            ForEach([initialMeasurementType, pairedType], id: \.self) { side in
                                Button(action: {
                                    selectedSide = side
                                }) {
                                    Text(side.isLeft ? "Left" : "Right")
                                        .font(.subheadline.bold())
                                        .foregroundColor(selectedSide == side ? .white : .white.opacity(0.6))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedSide == side ? Color.white.opacity(0.2) : Color.white.opacity(0.06))
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Time Range Selector
                    TimeRangeSelector(selectedRange: $selectedTimeRange)
                    
                    // Stats Summary
                    if !filteredEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("📏")
                                    .font(.caption)
                                Text(measurementType.title.uppercased())
                                    .font(.caption)
                                    .foregroundStyle(AppStyle.Colors.accentPrimary)
                            }
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(formatRange())
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                Text("cm")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text("Range • \(formatDateRange())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            // Min/Max/Average stats
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
                    if filteredEntries.isEmpty {
                        EmptyStateView(
                            icon: "chart.line.downtrend.xyaxis",
                            title: "No data for this period",
                            subtitle: "Add measurements to see your progress"
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                        .padding()
                    } else {
                        let allXAxisLabels = getAllXAxisDates().map { formatXAxisLabel($0) }
                        
                        Chart {
                            ForEach(Array(aggregatedEntries.enumerated()), id: \.offset) { index, entry in
                                LineMark(
                                    x: .value("Date", formatXAxisLabel(entry.date)),
                                    y: .value("Value", entry.value)
                                )
                                .foregroundStyle(AppStyle.Colors.accentPrimary)
                                .interpolationMethod(.catmullRom)
                                
                                PointMark(
                                    x: .value("Date", formatXAxisLabel(entry.date)),
                                    y: .value("Value", entry.value)
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
                                        Text(String(format: "%.0f", doubleValue))
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
                        Text(measurementType.title)
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        
                        Text(measurementType.description)
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    }
                    .padding()
                    .glassCard()
                    .padding(.horizontal)
                    
                    // Average Range Comparison
                    if let gender = userProfile.gender,
                       let age = userProfile.age,
                       let heightCm = userProfile.heightCm,
                       let latestEntry = filteredEntries.last {
                        let comparison = MeasurementRangeComparison(
                            measurementType: measurementType,
                            userValue: latestEntry.value,
                            userGender: gender,
                            userAge: age,
                            userHeight: heightCm
                        )
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(comparison.comparisonText)
                                        .font(.callout)
                                        .foregroundColor(.white)
                                    
                                    let range = comparison.averageRange
                                    Text("Average range: \(formatComparisonRange(range))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(comparison.comparisonColor.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(comparison.comparisonColor.opacity(0.3), lineWidth: 1)
                        )
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                        // All Recorded Data
                    if !filteredEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("All Recorded Data")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                ForEach(Array(filteredEntries.reversed().enumerated()), id: \.element.id) { index, entry in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(formatFullDate(entry.date))
                                                .font(.callout)
                                                .foregroundColor(.white)
                                            if let label = entry.label, !label.isEmpty {
                                                Text(label)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Text(String(format: "%.1f cm", entry.value))
                                            .font(.callout.bold())
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 16)
                                    .background(Color.white.opacity(0.05))
                                    .contentShape(Rectangle())
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            entryToDelete = entry
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    
                                    if index < filteredEntries.count - 1 {
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
                        showAddSheet = true
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
        .sheet(isPresented: $showAddSheet) {
            AddMeasurementSheet(journey: journey, measurementType: selectedSide)
        }
        .alert("Delete Data", isPresented: $showDeleteConfirmation, presenting: entryToDelete) { entry in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                ctx.delete(entry)
                try? ctx.save()
            }
        } message: { entry in
            Text("Are you sure you want to delete this measurement from \(formatFullDate(entry.date))?")
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = exportFileURL {
                ShareSheet(url: url)
            }
        }
    }
    
    private func exportToCSV() {
        // Haptic feedback
        HapticFeedback.medium()
        
        // Export filtered entries to CSV
        guard let csvData = ExportService.exportMeasurementsToCSV(entries: filteredEntries, journey: journey) else {
            AppConstants.Log.data.error("Failed to export measurements to CSV")
            return
        }
        
        // Create temporary file
        let filename = ExportService.generateCSVFilename(journey: journey, type: measurementType.title.replacingOccurrences(of: " ", with: "_"))
        
        do {
            let fileURL = try ExportService.createTemporaryFile(data: csvData, filename: filename)
            exportFileURL = fileURL
            showExportSheet = true
            AppConstants.Log.data.info("CSV export successful: \(filename)")
        } catch {
            AppConstants.Log.data.error("Failed to create temporary CSV file: \(error.localizedDescription)")
        }
    }
    
    private func formatRange() -> String {
        guard !filteredEntries.isEmpty else { return "--" }
        let values = filteredEntries.map { $0.value }
        let min = values.min() ?? 0
        let max = values.max() ?? 0
        
        return String(format: "%.1f-%.1f", min, max)
    }
    
    private func formatDateRange() -> String {
        guard let first = filteredEntries.first?.date,
              let last = filteredEntries.last?.date else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        
        return "\(formatter.string(from: first)) - \(formatter.string(from: last))"
    }
    
    private func formatMinValue() -> String {
        guard !filteredEntries.isEmpty else { return "--" }
        let values = filteredEntries.map { $0.value }
        let min = values.min() ?? 0
        return String(format: "%.1f cm", min)
    }
    
    private func formatMaxValue() -> String {
        guard !filteredEntries.isEmpty else { return "--" }
        let values = filteredEntries.map { $0.value }
        let max = values.max() ?? 0
        return String(format: "%.1f cm", max)
    }
    
    private func formatAverageValue() -> String {
        guard !filteredEntries.isEmpty else { return "--" }
        let values = filteredEntries.map { $0.value }
        let average = values.reduce(0, +) / Double(values.count)
        return String(format: "%.1f cm", average)
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
    
    private func formatComparisonRange(_ range: ClosedRange<Double>) -> String {
        return String(format: "%.1f-%.1f cm", range.lowerBound, range.upperBound)
    }
    
    private func calculateYDomain() -> ClosedRange<Double> {
        guard !aggregatedEntries.isEmpty else { return 0...100 }
        
        let values = aggregatedEntries.map { $0.value }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 100
        
        // Add some padding (10% on each side)
        let range = maxValue - minValue
        let padding = Swift.max(range * 0.1, 1.0) // At least 1 unit of padding
        
        let lowerBound = Swift.max(0, minValue - padding)
        let upperBound = maxValue + padding
        
        return lowerBound...upperBound
    }
    
    private func getAllXAxisDates() -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeRange {
        case .week:
            // Get the week containing the most recent measurement (or today if no data)
            let referenceDate = filteredEntries.last?.date ?? now
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
            let referenceDate = filteredEntries.last?.date ?? now
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
            let endMonth = calendar.dateInterval(of: .month, for: filteredEntries.last?.date ?? now)?.start ?? calendar.startOfDay(for: now)
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
            let endMonth = calendar.dateInterval(of: .month, for: filteredEntries.last?.date ?? now)?.start ?? calendar.startOfDay(for: now)
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
            guard let firstDate = filteredEntries.first?.date,
                  let lastDate = filteredEntries.last?.date else {
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
            let referenceDate = filteredEntries.last?.date ?? now
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
            let startDate = filteredEntries.first?.date ?? calendar.date(byAdding: .month, value: -1, to: now) ?? now
            let endDate = filteredEntries.last?.date ?? now
            
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
            let endMonth = calendar.dateInterval(of: .month, for: filteredEntries.last?.date ?? now)?.start ?? calendar.startOfDay(for: now)
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
            let endMonth = calendar.dateInterval(of: .month, for: filteredEntries.last?.date ?? now)?.start ?? calendar.startOfDay(for: now)
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
            guard let firstDate = filteredEntries.first?.date,
                  let lastDate = filteredEntries.last?.date else {
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
    
    private func aggregateEntriesByDay(_ entries: [MeasurementEntry]) -> [MeasurementEntry] {
        guard !entries.isEmpty else { return [] }
        
        let calendar = Calendar.current
        var dailyData: [Date: (values: [Double], journeyId: UUID, type: MeasurementType)] = [:]
        // Pre-allocate capacity for better performance
        dailyData.reserveCapacity(min(entries.count, 7))
        
        // Collect data points by day
        for entry in entries {
            let dayStart = calendar.startOfDay(for: entry.date)
            if dailyData[dayStart] == nil {
                dailyData[dayStart] = (values: [], journeyId: entry.journeyId, type: entry.type)
            }
            dailyData[dayStart]?.values.append(entry.value)
        }
        
        // Get the most recent date and find the week it belongs to
        guard let mostRecentDate = entries.map({ $0.date }).max() else {
            return []
        }
        
        // Find Monday of the week containing the most recent date
        var weekStart = calendar.startOfDay(for: mostRecentDate)
        let weekday = calendar.component(.weekday, from: weekStart)
        
        // Adjust to Monday (weekday 2 in Gregorian calendar, 1 = Sunday)
        let daysToSubtract = weekday == 1 ? 6 : weekday - 2
        weekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: weekStart) ?? weekStart
        
        // Generate results only for days that have data
        var results: [MeasurementEntry] = []
        var currentDate = weekStart
        
        for _ in 0..<7 {
            if let data = dailyData[currentDate] {
                let average = data.values.reduce(0, +) / Double(data.values.count)
                results.append(MeasurementEntry(journeyId: data.journeyId, date: currentDate, type: data.type, value: average, unit: .cm))
            }
            // Don't add interpolated points - only plot actual data
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return results
    }
    
    private func aggregateEntriesByWeek(_ entries: [MeasurementEntry]) -> [MeasurementEntry] {
        guard !entries.isEmpty else { return [] }

        let calendar = Calendar.current
        var weeklyData: [Date: (values: [Double], journeyId: UUID, type: MeasurementType)] = [:]
        
        // Collect data points by week
        for entry in entries {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: entry.date)?.start ?? entry.date
            if weeklyData[weekStart] == nil {
                weeklyData[weekStart] = (values: [], journeyId: entry.journeyId, type: entry.type)
            }
            weeklyData[weekStart]?.values.append(entry.value)
        }
        
        // Get the first and last dates
        guard let firstDate = entries.map({ $0.date }).min(),
              let lastDate = entries.map({ $0.date }).max() else {
            return []
        }
        
        let startWeek = calendar.dateInterval(of: .weekOfYear, for: firstDate)?.start ?? firstDate
        let endWeek = calendar.dateInterval(of: .weekOfYear, for: lastDate)?.start ?? lastDate
        
        // Generate all weeks in range
        var results: [MeasurementEntry] = []
        var currentDate = startWeek
        
        while currentDate <= endWeek {
            if let data = weeklyData[currentDate] {
                let average = data.values.reduce(0, +) / Double(data.values.count)
                results.append(MeasurementEntry(journeyId: data.journeyId, date: currentDate, type: data.type, value: average, unit: .cm))
            }
            // Don't add interpolated points - only plot actual data
            currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
        }
        
        return results
    }
    
    private func aggregateEntriesByMonth(_ entries: [MeasurementEntry]) -> [MeasurementEntry] {
        guard !entries.isEmpty else { return [] }

        let calendar = Calendar.current
        var monthlyData: [Date: (values: [Double], journeyId: UUID, type: MeasurementType)] = [:]
        
        // Collect data points by month
        for entry in entries {
            let monthStart = calendar.dateInterval(of: .month, for: entry.date)?.start ?? entry.date
            if monthlyData[monthStart] == nil {
                monthlyData[monthStart] = (values: [], journeyId: entry.journeyId, type: entry.type)
            }
            monthlyData[monthStart]?.values.append(entry.value)
        }
        
        // Get the most recent date and calculate 12 months back
        guard let mostRecentDate = entries.map({ $0.date }).max() else {
            return []
        }
        
        let endMonth = calendar.dateInterval(of: .month, for: mostRecentDate)?.start ?? mostRecentDate
        // Go back 11 months (12 months total including current)
        let startMonth = calendar.date(byAdding: .month, value: -11, to: endMonth) ?? endMonth
        
        // Generate only the most recent 12 months
        var results: [MeasurementEntry] = []
        var currentDate = startMonth
        
        while currentDate <= endMonth {
            if let data = monthlyData[currentDate] {
                let average = data.values.reduce(0, +) / Double(data.values.count)
                results.append(MeasurementEntry(journeyId: data.journeyId, date: currentDate, type: data.type, value: average, unit: .cm))
            }
            // Don't add interpolated points - only plot actual data
            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
        }
        
        return results
    }
    
    private func aggregateEntriesByQuarter(_ entries: [MeasurementEntry]) -> [MeasurementEntry] {
        guard !entries.isEmpty else { return [] }

        let calendar = Calendar.current
        var quarterlyData: [Date: (values: [Double], journeyId: UUID, type: MeasurementType)] = [:]
        
        // Collect data points by quarter
        for entry in entries {
            let components = calendar.dateComponents([.year, .month], from: entry.date)
            let month = components.month ?? 1
            let year = components.year ?? 2024
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            
            var quarterComponents = DateComponents()
            quarterComponents.year = year
            quarterComponents.month = quarterStartMonth
            quarterComponents.day = 1
            
            if let quarterStart = calendar.date(from: quarterComponents) {
                if quarterlyData[quarterStart] == nil {
                    quarterlyData[quarterStart] = (values: [], journeyId: entry.journeyId, type: entry.type)
                }
                quarterlyData[quarterStart]?.values.append(entry.value)
            }
        }
        
        // Get the first and last dates
        guard let firstDate = entries.map({ $0.date }).min(),
              let lastDate = entries.map({ $0.date }).max() else {
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
        var results: [MeasurementEntry] = []
        var currentDate = startQuarter
        
        while currentDate <= endQuarter {
            if let data = quarterlyData[currentDate] {
                let average = data.values.reduce(0, +) / Double(data.values.count)
                results.append(MeasurementEntry(journeyId: data.journeyId, date: currentDate, type: data.type, value: average, unit: .cm))
            }
            // Don't add interpolated points - only plot actual data
            currentDate = calendar.date(byAdding: .month, value: 3, to: currentDate) ?? currentDate
        }
        
        return results
    }
}

enum MeasurementTimeRange: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case sixMonths = "6 Months"
    case year = "Year"
    case all = "All"
    
    var id: String { rawValue }
}

// Extension for measurement type descriptions
extension MeasurementType {
    var description: String {
        switch self {
        case .weight:
            return "Track your body weight over time. Weight is one of the most basic and important health metrics."
        case .bodyFat:
            return "Body fat percentage indicates the proportion of fat in your body composition."
        case .chest:
            return "Chest measurement is taken around the fullest part of your chest, typically at nipple level."
        case .waist:
            return "Waist measurement is taken at the narrowest point of your torso, typically above your belly button."
        case .hips:
            return "Hip measurement is taken at the widest part of your hips and buttocks."
        case .neck:
            return "Neck measurement is taken around the middle of your neck, below the Adam's apple. A key metric for body composition tracking."
        case .bicepsLeft, .bicepsRight:
            return "Bicep measurement is taken around the largest part of your upper arm when flexed. Track both arms to monitor muscle development."
        case .forearmLeft, .forearmRight:
            return "Forearm measurement is taken around the widest part of your lower arm, typically near the elbow. Important for grip and arm strength."
        case .thighLeft, .thighRight:
            return "Thigh measurement is taken around the largest part of your upper leg. Essential for tracking lower body muscle development."
        case .calfLeft, .calfRight:
            return "Calf measurement is taken around the largest part of your lower leg. Important for overall leg development and athleticism."
        case .custom:
            return "Custom measurement for tracking any body part or metric you choose."
        }
    }
}

struct MeasurementRangeComparison {
    let measurementType: MeasurementType
    let userValue: Double
    let userGender: UserProfile.Gender
    let userAge: Int
    let userHeight: Double // in cm
    
    var averageRange: ClosedRange<Double> {
        switch measurementType {
        case .weight:
            return averageWeight()
        case .bodyFat:
            return averageBodyFat()
        case .chest:
            return averageChest()
        case .waist:
            return averageWaist()
        case .hips:
            return averageHips()
        case .neck:
            return averageNeck()
        case .bicepsLeft, .bicepsRight:
            return averageBiceps()
        case .forearmLeft, .forearmRight:
            return averageForearm()
        case .thighLeft, .thighRight:
            return averageThigh()
        case .calfLeft, .calfRight:
            return averageCalf()
        case .custom:
            return 0...100 // No comparison for custom measurements
        }
    }
    
    var comparisonText: String {
        // For custom measurements, don't show comparison
        if measurementType == .custom {
            return "Custom measurement"
        }
        
        let range = averageRange
        
        if userValue < range.lowerBound {
            return "Below average for your demographics"
        } else if userValue > range.upperBound {
            return "Above average for your demographics"
        } else {
            return "Within average range"
        }
    }
    
    var comparisonColor: Color {
        // Blue for informational (not a health judgment)
        return .blue
    }
    
    // Weight averages based on height (BMI-derived)
    private func averageWeight() -> ClosedRange<Double> {
        let heightM = userHeight / 100.0
        let heightSquared = heightM * heightM
        
        // BMI 20-25 is typical average range
        let minWeight = 20.0 * heightSquared
        let maxWeight = 25.0 * heightSquared
        
        return minWeight...maxWeight
    }
    
    // Body fat percentage averages
    private func averageBodyFat() -> ClosedRange<Double> {
        var baseRange: (lower: Double, upper: Double)
        
        switch userGender {
        case .male:
            baseRange = (15, 20) // Average male
        case .female:
            baseRange = (23, 28) // Average female
        }
        
        // Adjust for age - body fat tends to increase with age (more gradual increase)
        let ageAdjustment: Double
        switch userAge {
        case 18...29:
            ageAdjustment = -1.5  // Younger adults typically leaner
        case 30...39:
            ageAdjustment = 0.0   // Baseline age group
        case 40...49:
            ageAdjustment = 1.5   // Gradual increase
        case 50...59:
            ageAdjustment = 2.5   // Continued increase
        case 60...:
            ageAdjustment = 3.5   // More moderate than before
        default:
            ageAdjustment = -1.5
        }
        
        return (baseRange.lower + ageAdjustment)...(baseRange.upper + ageAdjustment)
    }
    
    // Chest measurement averages
    private func averageChest() -> ClosedRange<Double> {
        // Base measurements for average height (175.5cm male, 161.8cm female)
        var baseRange: (lower: Double, upper: Double)
        
        switch userGender {
        case .male:
            baseRange = (98, 110) // cm - Based on US average of 106.6cm
        case .female:
            baseRange = (88, 105) // cm - Based on US average of 100.1cm
        }
        
        // Scale based on height
        let heightRatio = userHeight / (userGender == .male ? 175.5 : 161.8)
        
        return (baseRange.lower * heightRatio)...(baseRange.upper * heightRatio)
    }
    
    // Waist measurement averages
    private func averageWaist() -> ClosedRange<Double> {
        var baseRange: (lower: Double, upper: Double)
        
        switch userGender {
        case .male:
            baseRange = (80, 95) // cm - Updated based on US average of 95cm
        case .female:
            baseRange = (70, 89) // cm - Updated based on US average of 89cm
        }
        
        // Adjust for age - waist tends to increase with age (more moderate adjustments)
        let ageAdjustment: Double
        switch userAge {
        case 18...29:
            ageAdjustment = -3.0  // Younger adults typically have smaller waists
        case 30...39:
            ageAdjustment = 0.0   // Baseline age group
        case 40...49:
            ageAdjustment = 2.0   // Moderate increase
        case 50...59:
            ageAdjustment = 4.0   // Continued increase
        case 60...:
            ageAdjustment = 5.0   // More moderate than before
        default:
            ageAdjustment = -3.0
        }
        
        // Scale based on height
        let heightRatio = userHeight / (userGender == .male ? 175.5 : 161.8)
        
        return ((baseRange.lower + ageAdjustment) * heightRatio)...((baseRange.upper + ageAdjustment) * heightRatio)
    }
    
    // Hip measurement averages
    private func averageHips() -> ClosedRange<Double> {
        var baseRange: (lower: Double, upper: Double)
        
        switch userGender {
        case .male:
            baseRange = (92, 104) // cm - Based on US average of 99.9cm
        case .female:
            baseRange = (94, 108) // cm - Based on US average of 101.4cm (women typically have wider hips)
        }
        
        // Scale based on height
        let heightRatio = userHeight / (userGender == .male ? 175.5 : 161.8)
        
        return (baseRange.lower * heightRatio)...(baseRange.upper * heightRatio)
    }
    
    // Biceps measurement averages (flexed)
    private func averageBiceps() -> ClosedRange<Double> {
        var baseRange: (lower: Double, upper: Double)
        
        switch userGender {
        case .male:
            baseRange = (31, 39) // cm - Average for adult males
        case .female:
            baseRange = (26, 34) // cm - Average for adult females
        }
        
        // Adjust for age - muscle mass tends to decrease with age (more moderate decline)
        let ageAdjustment: Double
        switch userAge {
        case 18...29:
            ageAdjustment = 0.5   // Peak muscle years
        case 30...39:
            ageAdjustment = 0.0   // Baseline
        case 40...49:
            ageAdjustment = -0.5  // Slight decline
        case 50...59:
            ageAdjustment = -1.0  // Moderate decline (sarcopenia begins)
        case 60...:
            ageAdjustment = -1.5  // More pronounced decline
        default:
            ageAdjustment = 0.0
        }
        
        return (baseRange.lower + ageAdjustment)...(baseRange.upper + ageAdjustment)
    }
    
    // Thigh measurement averages
    private func averageThigh() -> ClosedRange<Double> {
        var baseRange: (lower: Double, upper: Double)
        
        switch userGender {
        case .male:
            baseRange = (52, 62) // cm - Updated based on anthropometric data
        case .female:
            baseRange = (54, 64) // cm - Slightly larger due to body fat distribution
        }
        
        // Scale based on height
        let heightRatio = userHeight / (userGender == .male ? 175.5 : 161.8)
        
        return (baseRange.lower * heightRatio)...(baseRange.upper * heightRatio)
    }
    
    // Calf measurement averages
    private func averageCalf() -> ClosedRange<Double> {
        var baseRange: (lower: Double, upper: Double)
        
        switch userGender {
        case .male:
            baseRange = (36, 42) // cm - Updated based on anthropometric data
        case .female:
            baseRange = (34, 40) // cm - Updated based on anthropometric data
        }
        
        // Scale based on height
        let heightRatio = userHeight / (userGender == .male ? 175.5 : 161.8)
        
        return (baseRange.lower * heightRatio)...(baseRange.upper * heightRatio)
    }
    
    // Neck measurement averages
    private func averageNeck() -> ClosedRange<Double> {
        var baseRange: (lower: Double, upper: Double)
        
        switch userGender {
        case .male:
            baseRange = (38, 43) // cm - Updated based on anthropometric data
        case .female:
            baseRange = (32, 36) // cm - Updated based on anthropometric data
        }
        
        // Slight adjustment for age (neck can expand slightly with age due to weight gain)
        let ageAdjustment: Double
        switch userAge {
        case 18...29:
            ageAdjustment = -0.3  // Younger, typically leaner
        case 30...39:
            ageAdjustment = 0.0   // Baseline
        case 40...49:
            ageAdjustment = 0.3   // Slight increase
        case 50...:
            ageAdjustment = 0.5   // Modest increase
        default:
            ageAdjustment = -0.3
        }
        
        // Scale based on height
        let heightRatio = userHeight / (userGender == .male ? 175.5 : 161.8)
        
        return ((baseRange.lower + ageAdjustment) * heightRatio)...((baseRange.upper + ageAdjustment) * heightRatio)
    }
    
    // Forearm measurement averages
    private func averageForearm() -> ClosedRange<Double> {
        var baseRange: (lower: Double, upper: Double)
        
        switch userGender {
        case .male:
            baseRange = (27, 31) // cm - Updated based on anthropometric data
        case .female:
            baseRange = (23, 27) // cm - Updated based on anthropometric data
        }
        
        // Adjust for age - muscle mass tends to decrease with age (moderate decline)
        let ageAdjustment: Double
        switch userAge {
        case 18...29:
            ageAdjustment = 0.3   // Peak muscle years
        case 30...39:
            ageAdjustment = 0.0   // Baseline
        case 40...49:
            ageAdjustment = -0.3  // Slight decline
        case 50...59:
            ageAdjustment = -0.6  // Moderate decline
        case 60...:
            ageAdjustment = -1.0  // More pronounced decline
        default:
            ageAdjustment = 0.0
        }
        
        return (baseRange.lower + ageAdjustment)...(baseRange.upper + ageAdjustment)
    }
}

