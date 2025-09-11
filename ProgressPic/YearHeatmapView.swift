import SwiftUI
import SwiftData

struct YearHeatmapView: View {
    let journey: Journey
    @Query private var photos: [ProgressPhoto]

    init(journey: Journey) {
        self.journey = journey
        let journeyId = journey.id
        _photos = Query(filter: #Predicate<ProgressPhoto> { $0.journeyId == journeyId })
    }

    var body: some View {
        let cal = Calendar.current
        let yearStart = cal.date(from: DateComponents(year: cal.component(.year, from: Date()), month: 1, day: 1))!
        let yearEnd = cal.date(from: DateComponents(year: cal.component(.year, from: Date()) + 1, month: 1, day: 1))!
        let days = stride(from: yearStart, to: yearEnd, by: 60 * 60 * 24).map { cal.startOfDay(for: $0) }

        // Count photos per day (usually 0/1, but we allow >1)
        let counts = Dictionary(grouping: photos, by: { cal.startOfDay(for: $0.date) })
            .mapValues { $0.count }

        VStack(alignment: .leading, spacing: 10) {
            Text("My Year").font(.title3.bold())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    // Columns by week (Mon-first)
                    let weeks = heatmapColumns(days: days, calendar: cal)
                    ForEach(weeks.indices, id: \.self) { col in
                        VStack(spacing: 4) {
                            ForEach(0..<7, id: \.self) { row in
                                if let day = weeks[col][row] {
                                    let c = counts[day] ?? 0
                                    HeatSquare(level: c)
                                        .help(day.formatted(date: .abbreviated, time: .omitted))
                                } else {
                                    Color.clear.frame(width: 12, height: 12)
                                }
                            }
                        }
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.15)))
            }
        }
    }

    // Build 53-ish columns of 7 rows (like GitHub)
    func heatmapColumns(days: [Date], calendar cal: Calendar) -> [[Date?]] {
        var cols: [[Date?]] = []
        var col: [Date?] = Array(repeating: nil, count: 7)

        for day in days {
            let idx = (cal.component(.weekday, from: day) + 5) % 7 // Make Monday=0
            col[idx] = day
            if idx == 6 {
                cols.append(col)
                col = Array(repeating: nil, count: 7)
            }
        }
        if col.contains(where: { $0 != nil }) { cols.append(col) }
        return cols
    }
}

private struct HeatSquare: View {
    let level: Int
    var body: some View {
        let intensity = min(level, 4)
        let base = Color.white
        let color = switch intensity {
        case 0: Color.black.opacity(0.18)
        case 1: base.opacity(0.30)
        case 2: base.opacity(0.55)
        case 3: base.opacity(0.75)
        default: base
        }
        return RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .frame(width: 12, height: 12)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.05), lineWidth: 0.5))
    }
}
