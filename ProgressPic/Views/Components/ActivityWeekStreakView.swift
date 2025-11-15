import SwiftUI
import SwiftData

/// Universal week ring and streak tracking view that combines all journeys
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
                        .foregroundColor(AppStyle.Colors.accentPrimary)
                    Text("My Week")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppStyle.Colors.textTertiary)
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
                        .foregroundStyle(AppStyle.Colors.accentPrimary)
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
                        .foregroundStyle(AppStyle.Colors.accentPrimary)
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

/// Enhanced day bubble component for week view
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
                                colors: [AppStyle.Colors.accentPrimary, AppStyle.Colors.accentPrimary.opacity(0.8)],
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
