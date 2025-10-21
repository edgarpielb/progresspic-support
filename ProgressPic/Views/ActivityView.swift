import SwiftUI
import SwiftData
import Charts
import HealthKit

struct ActivityView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Journey.createdAt, order: .reverse) private var journeys: [Journey]
    @State private var showProfileSetup = false
    @State private var showProfileDetail = false
    @State private var showYearCalendar = false
    @State private var userProfile = UserProfile.load()
    @StateObject private var healthKit = HealthKitService.shared
    @State private var isLoadingHealthData = false
    
    private var isProfileComplete: Bool {
        userProfile.birthDate != nil && userProfile.heightCm != nil
    }

    var body: some View {
        NavigationStack {
        ZStack {
            Color(red: 30/255, green: 32/255, blue: 35/255).ignoresSafeArea()

                // Content state with ScrollView
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                    // Universal Week Ring with Streaks (combines all journeys)
                    Button(action: {
                        showYearCalendar = true
                    }) {
                        CombinedWeekAndStreakView(journeys: journeys)
                            .padding(12)
                            .glassCard()
                    }
                    .buttonStyle(.plain)

                    BodyCompositionSection(healthKit: healthKit, isLoading: isLoadingHealthData)
                                .padding(12)
                                .glassCard()

                    // Show measurement stats from first journey (or could combine all)
                    if let firstJourney = journeys.first {
                        AllMeasurementStatsSection(journey: firstJourney)
                            .padding(12)
                            .glassCard()
                        }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
                .padding(.top, 4)
            }
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Activity")
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if isProfileComplete {
                        showProfileDetail = true
                    } else {
                        showProfileSetup = true
                    }
                }) {
                    Image(systemName: "person.circle.fill")
                        .font(.title3)
                        .foregroundColor(.pink)
                }
            }
        }
        .sheet(isPresented: $showProfileSetup) {
            UserProfileSetupView { profile in
                userProfile = profile
            }
        }
        .sheet(isPresented: $showProfileDetail) {
            UserProfileDetailView()
                .onDisappear {
                    // Reload profile when detail view is dismissed
                    userProfile = UserProfile.load()
                }
        }
        .sheet(isPresented: $showYearCalendar) {
            YearCalendarSheet(journeys: journeys)
        }
        .onAppear {
            // Show profile setup if not completed (only on first launch)
            if !isProfileComplete {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showProfileSetup = true
                }
            }

            // Check if we should request a review based on current streak - run on background thread
            Task {
                let allPhotos = (try? ctx.fetch(FetchDescriptor<ProgressPhoto>(sortBy: [SortDescriptor(\.date, order: .forward)]))) ?? []
                let allMeasurements = (try? ctx.fetch(FetchDescriptor<MeasurementEntry>(sortBy: [SortDescriptor(\.date, order: .forward)]))) ?? []
                let currentStreak = calculateCurrentStreak(photos: allPhotos, measurements: allMeasurements)
                await MainActor.run {
                    ReviewRequestManager.checkAndRequestReview(currentStreak: currentStreak)
                }
            }
        }
            .task {
                // Only fetch data if already authorized
                if healthKit.isAuthorized {
                    isLoadingHealthData = true
                    await healthKit.fetchBodyComposition()
                    isLoadingHealthData = false
                }
            }
        }
    }
    
    private func calculateCurrentStreak(photos: [ProgressPhoto], measurements: [MeasurementEntry]) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        
        // Combine photo and measurement days (excluding future dates)
        var allActivityDays = Set<Date>()
        for photo in photos {
            let dayStart = cal.startOfDay(for: photo.date)
            if dayStart <= today {
                allActivityDays.insert(dayStart)
            }
        }
        for measurement in measurements {
            let dayStart = cal.startOfDay(for: measurement.date)
            if dayStart <= today {
                allActivityDays.insert(dayStart)
            }
        }
        
        guard !allActivityDays.isEmpty else { return 0 }
        
        let days = Array(allActivityDays).sorted()
        let lastActivityDay = days.last!
        
        // Check if last activity was today or yesterday
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        
        guard cal.isDate(lastActivityDay, inSameDayAs: today) || cal.isDate(lastActivityDay, inSameDayAs: yesterday) else {
            return 0
        }
        
        // Count backwards from last activity day
        var currentStreak = 1
        var checkDate = lastActivityDay
        
        for day in days.reversed().dropFirst() {
            if let prevDay = cal.date(byAdding: .day, value: -1, to: checkDate),
               cal.isDate(day, inSameDayAs: prevDay) {
                currentStreak += 1
                checkDate = day
            } else {
                break
            }
        }
        
        return currentStreak
    }
}

// Universal components that work across all journeys
struct CombinedWeekAndStreakView: View {
    let journeys: [Journey]
    @Query private var allPhotos: [ProgressPhoto]
    @Query private var allMeasurements: [MeasurementEntry]
    
    @State private var cachedTakenDays: Set<Date> = []
    @State private var cachedCurrentStreak: Int = 0
    @State private var cachedLongestStreak: Int = 0
    
    init(journeys: [Journey]) {
        self.journeys = journeys
        _allPhotos = Query(sort: \ProgressPhoto.date, order: .forward)
        _allMeasurements = Query(sort: \MeasurementEntry.date, order: .forward)
    }
    
    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear,.weekOfYear], from: today)) ?? today
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
        
        return VStack(alignment: .leading, spacing: 16) {
            // Week section
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.title3)
                        .foregroundColor(.pink)
                    Text("My Week")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }
                HStack(spacing: 10) {
                    ForEach(days, id: \.self) { d in
                        EnhancedDayBubble(date: d,
                                         isToday: cal.isDate(d, inSameDayAs: today),
                                         done: cachedTakenDays.contains(d))
                    }
                }
            }
            
            // Streaks section
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.title3)
                        .foregroundStyle(.pink)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(cachedCurrentStreak) day\(cachedCurrentStreak == 1 ? "" : "s")")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.title3)
                        .foregroundStyle(.pink)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Longest")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(cachedLongestStreak) day\(cachedLongestStreak == 1 ? "" : "s")")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            calculateAndCacheData()
        }
        .onChange(of: allPhotos.count) { _, _ in
            calculateAndCacheData()
        }
        .onChange(of: allMeasurements.count) { _, _ in
            calculateAndCacheData()
        }
    }
    
    private func calculateAndCacheData() {
        cachedTakenDays = calculateTakenDays()
        let streaks = calculateStreaks()
        cachedCurrentStreak = streaks.0
        cachedLongestStreak = streaks.1
    }
    
    private func calculateTakenDays() -> Set<Date> {
        let cal = Calendar.current
        let now = Date()
        var takenSet: Set<Date> = Set()
        
        for photo in allPhotos {
            let dayStart = cal.startOfDay(for: photo.date)
            // Only include if not in the future
            if dayStart <= cal.startOfDay(for: now) {
                takenSet.insert(dayStart)
            }
        }
        for measurement in allMeasurements {
            let dayStart = cal.startOfDay(for: measurement.date)
            // Only include if not in the future
            if dayStart <= cal.startOfDay(for: now) {
                takenSet.insert(dayStart)
            }
        }
        
        return takenSet
    }
    
    private func calculateStreaks() -> (current: Int, longest: Int) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        
        // Use the cached taken days to avoid recalculating
        let allActivityDays = cachedTakenDays.isEmpty ? calculateTakenDays() : cachedTakenDays
        
        guard !allActivityDays.isEmpty else { return (0, 0) }
        
        let days = Array(allActivityDays).sorted()
        var currentStreak = 0
        var longestStreak = 0
        var tempStreak = 1
        
        // Calculate longest streak in one pass
        for i in 0..<days.count {
            if i > 0 {
                let daysDiff = cal.dateComponents([.day], from: days[i-1], to: days[i]).day ?? 0
                if daysDiff == 1 {
                    tempStreak += 1
                } else {
                    longestStreak = max(longestStreak, tempStreak)
                    tempStreak = 1
                }
            }
        }
        longestStreak = max(longestStreak, tempStreak)
        
        // Calculate current streak (must include today or yesterday)
        guard let lastActivityDay = days.last else { return (0, longestStreak) }
        
        // Check if last activity was today or yesterday
        let daysSinceLastActivity = cal.dateComponents([.day], from: lastActivityDay, to: today).day ?? 0
        
        if daysSinceLastActivity <= 1 {
            // Count backwards from last activity day
            currentStreak = 1
            var checkDate = lastActivityDay
            
            for day in days.reversed().dropFirst() {
                let daysDiff = cal.dateComponents([.day], from: day, to: checkDate).day ?? 0
                if daysDiff == 1 {
                    currentStreak += 1
                    checkDate = day
                } else {
                    break
                }
            }
        }
        
        return (currentStreak, longestStreak)
    }
}

private struct EnhancedDayBubble: View {
    let date: Date
    let isToday: Bool
    let done: Bool
    
    var body: some View {
        let letter = date.formatted(.dateTime.weekday(.narrow))
        VStack(spacing: 6) {
            Text(letter)
                .font(.caption2.bold())
                .foregroundStyle(isToday ? .white : .secondary)
            
            ZStack {
                // Background gradient for completed days
                if done {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.pink, Color.pink.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                }
                
                if done {
                    Image(systemName: "checkmark")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: done)
                }
            }
            .frame(width: 44, height: 44)
            .overlay(
                Circle()
                    .stroke(isToday ? Color.white : Color.clear, lineWidth: 2.5)
            )
        }
        .frame(width: 44, height: 60)
    }
}

struct AllMeasurementStatsSection: View {
    let journey: Journey
    @Query private var entries: [MeasurementEntry]
    @State private var showBulkAddSheet = false

    init(journey: Journey) {
        self.journey = journey
        let journeyId = journey.id
        _entries = Query(filter: #Predicate<MeasurementEntry> { $0.journeyId == journeyId },
                         sort: \MeasurementEntry.date, order: .forward)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "ruler")
                        .font(.title3)
                        .foregroundColor(.pink)
                    Text("Body Measurements")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }
                Spacer()
                Button(action: {
                    showBulkAddSheet = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }

            VStack(spacing: 10) {
                // Arms
                SectionHeader(title: "Arms")
                
                MeasurementRow(
                    title: "Biceps",
                    type: .bicepsLeft,
                    count: countForType(.bicepsLeft) + countForType(.bicepsRight),
                    latestValue: latestValueForType(.bicepsLeft) ?? latestValueForType(.bicepsRight),
                    journey: journey
                )
                
                MeasurementRow(
                    title: "Forearm",
                    type: .forearmLeft,
                    count: countForType(.forearmLeft) + countForType(.forearmRight),
                    latestValue: latestValueForType(.forearmLeft) ?? latestValueForType(.forearmRight),
                    journey: journey
                )
                
                // Legs
                SectionHeader(title: "Legs")
                
                MeasurementRow(
                    title: "Calf",
                    type: .calfLeft,
                    count: countForType(.calfLeft) + countForType(.calfRight),
                    latestValue: latestValueForType(.calfLeft) ?? latestValueForType(.calfRight),
                    journey: journey
                )
                
                MeasurementRow(
                    title: "Thigh",
                    type: .thighLeft,
                    count: countForType(.thighLeft) + countForType(.thighRight),
                    latestValue: latestValueForType(.thighLeft) ?? latestValueForType(.thighRight),
                    journey: journey
                )
                
                // Torso
                SectionHeader(title: "Torso")
                
                MeasurementRow(
                    title: "Neck",
                    type: .neck,
                    count: countForType(.neck),
                    latestValue: latestValueForType(.neck),
                    journey: journey
                )
                
                MeasurementRow(
                    title: "Chest/Bust",
                    type: .chest,
                    count: countForType(.chest),
                    latestValue: latestValueForType(.chest),
                    journey: journey
                )
                
                MeasurementRow(
                    title: "Hip",
                    type: .hips,
                    count: countForType(.hips),
                    latestValue: latestValueForType(.hips),
                    journey: journey
                )
                
                MeasurementRow(
                    title: "Waist",
                    type: .waist,
                    count: countForType(.waist),
                    latestValue: latestValueForType(.waist),
                    journey: journey
                )
            }
        }
        .sheet(isPresented: $showBulkAddSheet) {
            BulkMeasurementSheet(journey: journey)
        }
    }
    
    func countForType(_ type: MeasurementType) -> Int {
        entries.filter { $0.type == type }.count
    }
    
    func latestValueForType(_ type: MeasurementType) -> (Double, Date)? {
        let filtered = entries.filter { $0.type == type }.sorted { $0.date > $1.date }
        guard let latest = filtered.first else { return nil }
        return (latest.value, latest.date)
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }
}

struct MeasurementRow: View {
    let title: String
    let type: MeasurementType
    let count: Int
    let latestValue: (Double, Date)?
    let journey: Journey
    
    var body: some View {
        NavigationLink(destination: MeasurementDetailView(journey: journey, measurementType: type)) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.callout)
                            .foregroundStyle(.white)
                        if latestValue != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green.opacity(0.8))
                        }
                    }
                    if let (_, date) = latestValue {
                        Text(formatDate(date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let (value, _) = latestValue {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", value))
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            Text("cm")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .glassTile()
        }
        .buttonStyle(.plain)
    }
    
    func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            return formatter.string(from: date)
        }
    }
}

struct BodyCompositionSection: View {
    @ObservedObject var healthKit: HealthKitService
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "heart.text.square")
                        .font(.title3)
                        .foregroundColor(.pink)
                    Text("Body Composition")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }
                Spacer()
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.7)
                } else {
                    Button(action: {
                        Task {
                            await healthKit.fetchBodyComposition()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                }
            }
            
            if !healthKit.isAuthorized {
                VStack(spacing: 12) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.3))
                    Text("Connect Apple Health")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Allow access to view your body composition data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button(action: {
                        Task {
                            _ = await healthKit.requestAuthorization()
                            if healthKit.isAuthorized {
                                await healthKit.fetchBodyComposition()
                            }
                        }
                    }) {
                        Text("Connect")
                            .font(.callout.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(20)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 10) {
                    if let bodyFat = healthKit.bodyComposition.bodyFatPercentage {
                        NavigationLink(destination: BodyCompositionDetailView(metricType: .bodyFat, healthKit: healthKit)) {
                            MetricRow(
                                title: "Body Fat Percentage",
                                value: String(format: "%.1f", bodyFat),
                                unit: "%",
                                date: healthKit.bodyComposition.bodyFatDate
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if let bmi = healthKit.bodyComposition.bmi {
                        NavigationLink(destination: BodyCompositionDetailView(metricType: .bmi, healthKit: healthKit)) {
                            MetricRow(
                                title: "Body Mass Index",
                                value: String(format: "%.0f", bmi),
                                unit: "BMI",
                                date: healthKit.bodyComposition.bmiDate
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if let leanMass = healthKit.bodyComposition.leanBodyMass {
                        NavigationLink(destination: BodyCompositionDetailView(metricType: .leanMass, healthKit: healthKit)) {
                            MetricRow(
                                title: "Lean Mass",
                                value: String(format: "%.1f", leanMass),
                                unit: "kg",
                                date: healthKit.bodyComposition.leanMassDate
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if let weight = healthKit.bodyComposition.weight {
                        NavigationLink(destination: BodyCompositionDetailView(metricType: .weight, healthKit: healthKit)) {
                            MetricRow(
                                title: "Weight",
                                value: String(format: "%.1f", weight),
                                unit: "kg",
                                date: healthKit.bodyComposition.weightDate
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if healthKit.bodyComposition.weight == nil &&
                       healthKit.bodyComposition.bodyFatPercentage == nil &&
                       healthKit.bodyComposition.leanBodyMass == nil &&
                       healthKit.bodyComposition.bmi == nil {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.line.downtrend.xyaxis")
                                .font(.system(size: 36))
                                .foregroundColor(.white.opacity(0.3))
                            Text("No Data Available")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Add body composition data in the Health app")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                }
            }
        }
    }
}

struct MetricRow: View {
    let title: String
    let value: String
    let unit: String
    let date: Date?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.callout)
                        .foregroundStyle(.white)
                    if date != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green.opacity(0.8))
                    }
                }
                if let date = date {
                    Text(formatDate(date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text(unit)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .glassTile()
    }
    
    func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            return formatter.string(from: date)
        }
    }
}

