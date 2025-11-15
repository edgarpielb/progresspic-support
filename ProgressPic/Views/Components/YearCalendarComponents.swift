import SwiftUI

struct MonthView: View {
    let monthName: String
    let days: [Date]
    let activeDays: Set<Date>
    
    // Cache these values to avoid recalculating on every render
    @State private var weeks: [[Date?]] = []
    @State private var today: Date = Date()
    
    private func calculateWeeks() -> [[Date?]] {
        guard !days.isEmpty, let firstDay = days.first else { return [] }
        let cal = Calendar.current
        let firstWeekday = cal.component(.weekday, from: firstDay)
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

struct DayCell: View {
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

struct StatRow: View {
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

