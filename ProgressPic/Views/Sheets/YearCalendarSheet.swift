import SwiftUI
import SwiftData

struct YearCalendarSheet: View {
    @Environment(\.dismiss) private var dismiss
    let journeys: [Journey]
    @Query private var allPhotos: [ProgressPhoto]
    @Query private var allMeasurements: [MeasurementEntry]
    
    @State private var selectedYear: Int
    @State private var cachedActiveDays: Set<Date>?
    @State private var cachedYearsWithData: Set<Int> = []
    @State private var cachedYearStats: (photoDays: Int, measurementDays: Int, totalActiveDays: Int, bothActivities: Int)?
    @State private var cachedUniqueDaysCount: Int = 0
    @State private var cachedBestMonth: String = "N/A"
    @State private var cachedAvgPhotosPerWeek: String = "0"
    @State private var cachedAvgMeasurementsPerWeek: String = "0"
    @State private var cachedFirstActivityDate: String = "N/A"
    
    init(journeys: [Journey]) {
        self.journeys = journeys
        _allPhotos = Query(sort: \ProgressPhoto.date, order: .forward)
        _allMeasurements = Query(sort: \MeasurementEntry.date, order: .forward)
        _selectedYear = State(initialValue: Calendar.current.component(.year, from: Date()))
    }
    
    // Computed property to get all years with data - now uses cached value
    private var yearsWithData: Set<Int> {
        return cachedYearsWithData
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppStyle.Colors.bgDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Year Picker
                        yearPickerSection
                        
                        // Stats Summary
                        statsSummarySection
                        
                        // Calendar Grid
                        if let activeDays = cachedActiveDays {
                            calendarSection(activeDays: activeDays)
                        }
                        
                        // Fun Stats
                        funStatsSection
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Activity Calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
            }
            .onAppear {
                // Calculate all cached values once on appear
                calculateAndCacheAllData()
            }
            .onChange(of: selectedYear) { _, _ in
                // Only recalculate year-specific data when year changes
                cachedActiveDays = calculateActiveDaysSet()
                cachedYearStats = calculateYearStats()
            }
            .onChange(of: allPhotos.count) { _, _ in
                // Recalculate when data changes
                calculateAndCacheAllData()
            }
            .onChange(of: allMeasurements.count) { _, _ in
                // Recalculate when data changes
                calculateAndCacheAllData()
            }
        }
    }
    
    private var yearPickerSection: some View {
        let hasPreviousYear = yearsWithData.contains(selectedYear - 1)
        let hasNextYear = yearsWithData.contains(selectedYear + 1)
        
        return HStack {
            Button(action: {
                selectedYear -= 1
            }) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(hasPreviousYear ? .white.opacity(0.7) : .white.opacity(0.2))
            }
            .disabled(!hasPreviousYear)
            
            Spacer()
            
            Text(String(selectedYear))
                .font(.title.bold())
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {
                selectedYear += 1
            }) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(hasNextYear ? .white.opacity(0.7) : .white.opacity(0.2))
            }
            .disabled(!hasNextYear)
        }
        .padding()
        .glassCard()
    }
    
    private var statsSummarySection: some View {
        // Use cached stats instead of recalculating
        let stats = cachedYearStats ?? (photoDays: 0, measurementDays: 0, totalActiveDays: 0, bothActivities: 0)
        
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.title3)
                        .foregroundStyle(AppStyle.Colors.accentPrimary)
                    Text("\(stats.totalActiveDays)")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("Active Days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 90)
                .glassCard()
                
                VStack(spacing: 8) {
                    Image(systemName: "photo.fill")
                        .font(.title3)
                        .foregroundStyle(AppStyle.Colors.accentPrimary)
                    Text("\(stats.photoDays)")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("Photo Days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 90)
                .glassCard()
            }
            
            HStack(spacing: 12) {
                VStack(spacing: 8) {
                    Image(systemName: "ruler.fill")
                        .font(.title3)
                        .foregroundStyle(AppStyle.Colors.accentPrimary)
                    Text("\(stats.measurementDays)")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("Measurement Days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 90)
                .glassCard()
                
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title3)
                        .foregroundStyle(AppStyle.Colors.accentPrimary)
                    Text("\(stats.bothActivities)")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("Both Activities")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 90)
                .glassCard()
            }
        }
    }
    
    private func calendarSection(activeDays: Set<Date>) -> some View {
        let cal = Calendar.current
        
        // Create a date formatter once instead of 12 times
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        
        let months = (1...12).compactMap { month -> (name: String, days: [Date], id: String) in
            guard let monthStart = cal.date(from: DateComponents(year: selectedYear, month: month, day: 1)) else {
                return ("", [], "")
            }
            
            let range = cal.range(of: .day, in: .month, for: monthStart)!
            let days = (1...range.count).compactMap { day -> Date? in
                cal.date(from: DateComponents(year: selectedYear, month: month, day: day))
            }
            
            let monthName = formatter.string(from: monthStart)
            return (monthName, days, "\(selectedYear)-\(month)")
        }
        
        return VStack(alignment: .leading, spacing: 16) {
            // Create 4 rows of 3 months each with stable IDs
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { col in
                        let index = row * 3 + col
                        if index < months.count {
                            MonthView(
                                monthName: months[index].name,
                                days: months[index].days,
                                activeDays: activeDays
                            )
                            .frame(maxWidth: .infinity)
                            .id(months[index].id)  // Add stable ID for better diffing
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Calculations
    
    private func calculateAndCacheAllData() {
        // Calculate all data once and cache it
        let cal = Calendar.current
        
        // Calculate years with data
        var years = Set<Int>()
        for photo in allPhotos {
            years.insert(cal.component(.year, from: photo.date))
        }
        for measurement in allMeasurements {
            years.insert(cal.component(.year, from: measurement.date))
        }
        cachedYearsWithData = years
        
        // Calculate year-specific data
        cachedActiveDays = calculateActiveDaysSet()
        cachedYearStats = calculateYearStats()
        
        // Calculate global stats (not year-specific)
        cachedUniqueDaysCount = calculateUniqueDaysCount()
        cachedBestMonth = calculateBestMonth()
        cachedAvgPhotosPerWeek = calculateAveragePhotosPerWeek()
        cachedAvgMeasurementsPerWeek = calculateAverageMeasurementsPerWeek()
        cachedFirstActivityDate = calculateFirstActivityDate()
    }
    
    private func calculateActiveDaysSet() -> Set<Date> {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var days = Set<Date>()
        
        // Add photo days (excluding future dates)
        for photo in allPhotos where cal.component(.year, from: photo.date) == selectedYear {
            let day = cal.startOfDay(for: photo.date)
            if day <= today {
                days.insert(day)
            }
        }
        
        // Add measurement days (excluding future dates)
        for measurement in allMeasurements where cal.component(.year, from: measurement.date) == selectedYear {
            let day = cal.startOfDay(for: measurement.date)
            if day <= today {
                days.insert(day)
            }
        }
        
        return days
    }
    
    private func calculateYearStats() -> (photoDays: Int, measurementDays: Int, totalActiveDays: Int, bothActivities: Int) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        
        var photoDays = Set<Date>()
        var measurementDays = Set<Date>()
        
        // Optimized: Only iterate through photos/measurements for selected year
        for photo in allPhotos {
            if cal.component(.year, from: photo.date) == selectedYear {
                let day = cal.startOfDay(for: photo.date)
                if day <= today {
                    photoDays.insert(day)
                }
            }
        }
        
        for measurement in allMeasurements {
            if cal.component(.year, from: measurement.date) == selectedYear {
                let day = cal.startOfDay(for: measurement.date)
                if day <= today {
                    measurementDays.insert(day)
                }
            }
        }
        
        let totalActiveDays = photoDays.union(measurementDays).count
        let bothActivities = photoDays.intersection(measurementDays).count
        
        return (photoDays.count, measurementDays.count, totalActiveDays, bothActivities)
    }
    
    private var funStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fun Stats")
                .font(.title3.bold())
                .foregroundColor(.white)
            
            VStack(spacing: 10) {
                StatRow(icon: "photo.fill", label: "Total Photos", value: "\(allPhotos.count)")
                StatRow(icon: "ruler.fill", label: "Total Measurements", value: "\(allMeasurements.count)")
                StatRow(icon: "calendar.badge.checkmark", label: "Active Days", value: "\(cachedUniqueDaysCount)")
                StatRow(icon: "star.fill", label: "Best Month", value: cachedBestMonth)
                StatRow(icon: "chart.line.uptrend.xyaxis", label: "Avg Photos/Week", value: cachedAvgPhotosPerWeek)
                StatRow(icon: "chart.bar.fill", label: "Avg Measurements/Week", value: cachedAvgMeasurementsPerWeek)
                StatRow(icon: "sparkles", label: "First Activity", value: cachedFirstActivityDate)
            }
            .padding(12)
            .glassCard()
        }
    }
    
    private func calculateUniqueDaysCount() -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var days = Set<Date>()
        
        for photo in allPhotos {
            let day = cal.startOfDay(for: photo.date)
            if day <= today {
                days.insert(day)
            }
        }
        for measurement in allMeasurements {
            let day = cal.startOfDay(for: measurement.date)
            if day <= today {
                days.insert(day)
            }
        }
        return days.count
    }
    
    private func calculateBestMonth() -> String {
        let cal = Calendar.current
        
        // Combine photos and measurements by month
        var monthCounts: [Int: Int] = [:]
        
        for photo in allPhotos {
            let month = cal.component(.month, from: photo.date)
            monthCounts[month, default: 0] += 1
        }
        
        for measurement in allMeasurements {
            let month = cal.component(.month, from: measurement.date)
            monthCounts[month, default: 0] += 1
        }
        
        guard let bestMonthNum = monthCounts.max(by: { $0.value < $1.value })?.key else {
            return "N/A"
        }
        
        let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return monthNames[bestMonthNum - 1]
    }
    
    private func calculateAveragePhotosPerWeek() -> String {
        guard !allPhotos.isEmpty else { return "0" }
        
        let cal = Calendar.current
        let firstDate = allPhotos.first?.date ?? Date()
        let weeks = max(1, cal.dateComponents([.weekOfYear], from: firstDate, to: Date()).weekOfYear ?? 1)
        let avg = Double(allPhotos.count) / Double(weeks)
        
        return String(format: "%.1f", avg)
    }
    
    private func calculateAverageMeasurementsPerWeek() -> String {
        guard !allMeasurements.isEmpty else { return "0" }
        
        let cal = Calendar.current
        let firstDate = allMeasurements.first?.date ?? Date()
        let weeks = max(1, cal.dateComponents([.weekOfYear], from: firstDate, to: Date()).weekOfYear ?? 1)
        let avg = Double(allMeasurements.count) / Double(weeks)
        
        return String(format: "%.1f", avg)
    }
    
    private func calculateFirstActivityDate() -> String {
        let photoDate = allPhotos.first?.date
        let measurementDate = allMeasurements.first?.date
        
        let first: Date?
        if let photoDate = photoDate, let measurementDate = measurementDate {
            first = min(photoDate, measurementDate)
        } else {
            first = photoDate ?? measurementDate
        }
        
        guard let first = first else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: first)
    }
}

private struct MonthView: View {
    let monthName: String
    let days: [Date]
    let activeDays: Set<Date>
    
    // Cache these values to avoid recalculating on every render
    @State private var weeks: [[Date?]] = []
    @State private var today: Date = Date()
    
    private func calculateWeeks() -> [[Date?]] {
        guard !days.isEmpty else { return [] }
        let cal = Calendar.current
        let firstWeekday = cal.component(.weekday, from: days.first!)
        let startingColumn = (firstWeekday + 5) % 7
        return createWeeks(days: days, startingColumn: startingColumn)
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Text(monthName)
                .font(.subheadline.bold())
                .foregroundColor(.white)
            
            VStack(spacing: 6) {
                // Day headers
                HStack(spacing: 2) {
                    ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                        Text(day)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Days grid - use cached values for better performance
                let cal = Calendar.current
                
                // Always show 6 rows to ensure consistent height
                ForEach(0..<6, id: \.self) { weekIndex in
                    HStack(spacing: 2) {
                        ForEach(0..<7, id: \.self) { dayIndex in
                            if weekIndex < weeks.count, let day = weeks[weekIndex][dayIndex] {
                                let dayStart = cal.startOfDay(for: day)
                                DayCell(
                                    isActive: activeDays.contains(dayStart),
                                    isToday: dayStart == today
                                )
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
            }
            .padding(8)
            .glassCard()
        }
        .onAppear {
            weeks = calculateWeeks()
            today = Calendar.current.startOfDay(for: Date())
        }
    }
    
    private func createWeeks(days: [Date], startingColumn: Int) -> [[Date?]] {
        var weeks: [[Date?]] = []
        var currentWeek: [Date?] = Array(repeating: nil, count: 7)
        var column = startingColumn
        
        for day in days {
            currentWeek[column] = day
            column += 1
            
            if column == 7 {
                weeks.append(currentWeek)
                currentWeek = Array(repeating: nil, count: 7)
                column = 0
            }
        }
        
        if currentWeek.contains(where: { $0 != nil }) {
            weeks.append(currentWeek)
        }
        
        return weeks
    }
}

private struct DayCell: View {
    let isActive: Bool
    let isToday: Bool
    
    var body: some View {
        ZStack {
            if isActive {
                Circle()
                    .fill(AppStyle.Colors.accentPrimary)
            } else {
                Circle()
                    .fill(Color.white.opacity(0.05))
            }
            
            if isToday {
                Circle()
                    .stroke(Color.white, lineWidth: 1.5)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(AppStyle.Colors.accentPrimary)
                .frame(width: 24)
            
            Text(label)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .font(.body.bold())
                .foregroundColor(.white)
        }
    }
}

