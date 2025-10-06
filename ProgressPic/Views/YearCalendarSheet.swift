import SwiftUI
import SwiftData

struct YearCalendarSheet: View {
    @Environment(\.dismiss) private var dismiss
    let journeys: [Journey]
    @Query private var allPhotos: [ProgressPhoto]
    @Query private var allMeasurements: [MeasurementEntry]
    
    @State private var selectedYear: Int
    @State private var cachedActiveDays: Set<Date>?
    
    init(journeys: [Journey]) {
        self.journeys = journeys
        _allPhotos = Query(sort: \ProgressPhoto.date, order: .forward)
        _allMeasurements = Query(sort: \MeasurementEntry.date, order: .forward)
        _selectedYear = State(initialValue: Calendar.current.component(.year, from: Date()))
    }
    
    // Computed property to get all years with data
    private var yearsWithData: Set<Int> {
        let cal = Calendar.current
        var years = Set<Int>()
        
        for photo in allPhotos {
            years.insert(cal.component(.year, from: photo.date))
        }
        
        for measurement in allMeasurements {
            years.insert(cal.component(.year, from: measurement.date))
        }
        
        return years
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 30/255, green: 32/255, blue: 35/255).ignoresSafeArea()
                
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
                cachedActiveDays = calculateActiveDaysSet()
            }
            .onChange(of: selectedYear) { _, _ in
                cachedActiveDays = calculateActiveDaysSet()
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
        let stats = calculateYearStats()
        
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.title3)
                        .foregroundStyle(.pink)
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
                        .foregroundStyle(.pink)
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
                        .foregroundStyle(.pink)
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
                        .foregroundStyle(.pink)
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
        let months = (1...12).compactMap { month -> (name: String, days: [Date]) in
            guard let monthStart = cal.date(from: DateComponents(year: selectedYear, month: month, day: 1)) else {
                return ("", [])
            }
            
            let range = cal.range(of: .day, in: .month, for: monthStart)!
            let days = (1...range.count).compactMap { day -> Date? in
                cal.date(from: DateComponents(year: selectedYear, month: month, day: day))
            }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM"
            return (formatter.string(from: monthStart), days)
        }
        
        return VStack(alignment: .leading, spacing: 16) {
            // Create 4 rows of 3 months each
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
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Calculations
    
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
        
        for photo in allPhotos where cal.component(.year, from: photo.date) == selectedYear {
            let day = cal.startOfDay(for: photo.date)
            if day <= today {
                photoDays.insert(day)
            }
        }
        
        for measurement in allMeasurements where cal.component(.year, from: measurement.date) == selectedYear {
            let day = cal.startOfDay(for: measurement.date)
            if day <= today {
                measurementDays.insert(day)
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
                StatRow(icon: "calendar.badge.checkmark", label: "Active Days", value: "\(uniqueDaysCount)")
                StatRow(icon: "star.fill", label: "Best Month", value: bestMonth)
                StatRow(icon: "chart.line.uptrend.xyaxis", label: "Avg Photos/Week", value: averagePhotosPerWeek)
                StatRow(icon: "chart.bar.fill", label: "Avg Measurements/Week", value: averageMeasurementsPerWeek)
                StatRow(icon: "sparkles", label: "First Activity", value: firstActivityDate)
            }
            .padding(12)
            .glassCard()
        }
    }
    
    private var uniqueDaysCount: Int {
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
    
    private var bestMonth: String {
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
    
    private var averagePhotosPerWeek: String {
        guard !allPhotos.isEmpty else { return "0" }
        
        let cal = Calendar.current
        let firstDate = allPhotos.map { $0.date }.min() ?? Date()
        let weeks = max(1, cal.dateComponents([.weekOfYear], from: firstDate, to: Date()).weekOfYear ?? 1)
        let avg = Double(allPhotos.count) / Double(weeks)
        
        return String(format: "%.1f", avg)
    }
    
    private var averageMeasurementsPerWeek: String {
        guard !allMeasurements.isEmpty else { return "0" }
        
        let cal = Calendar.current
        let firstDate = allMeasurements.map { $0.date }.min() ?? Date()
        let weeks = max(1, cal.dateComponents([.weekOfYear], from: firstDate, to: Date()).weekOfYear ?? 1)
        let avg = Double(allMeasurements.count) / Double(weeks)
        
        return String(format: "%.1f", avg)
    }
    
    private var firstActivityDate: String {
        let allDates = allPhotos.map { $0.date } + allMeasurements.map { $0.date }
        guard let first = allDates.min() else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: first)
    }
}

private struct MonthView: View {
    let monthName: String
    let days: [Date]
    let activeDays: Set<Date>
    
    private var weeks: [[Date?]] {
        let cal = Calendar.current
        let firstWeekday = cal.component(.weekday, from: days.first ?? Date())
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
                
                // Days grid - simplified
                let cal = Calendar.current
                let today = cal.startOfDay(for: Date())
                
                // Always show 6 rows to ensure consistent height
                ForEach(0..<6, id: \.self) { weekIndex in
                    HStack(spacing: 2) {
                        ForEach(0..<7) { dayIndex in
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
                    .fill(Color.pink)
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
                .foregroundStyle(.pink)
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

