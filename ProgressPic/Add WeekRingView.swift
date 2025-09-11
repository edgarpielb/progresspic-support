import SwiftUI
import SwiftData

struct WeekRingView: View {
    let journey: Journey
    @Query private var photos: [ProgressPhoto]

    init(journey: Journey) {
        self.journey = journey
        let journeyId = journey.id
        _photos = Query(filter: #Predicate<ProgressPhoto> { $0.journeyId == journeyId },
                        sort: \ProgressPhoto.date, order: .forward)
    }

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear,.weekOfYear], from: today)) ?? today
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
        let takenSet: Set<Date> = Set(photos.map { cal.startOfDay(for: $0.date) })

        VStack(alignment: .leading, spacing: 10) {
            Text("My Week").font(.title3.bold())
            HStack(spacing: 10) {
                ForEach(days, id: \.self) { d in
                    DayBubble(date: d,
                              isToday: cal.isDate(d, inSameDayAs: today),
                              done: takenSet.contains(d))
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DayBubble: View {
    let date: Date
    let isToday: Bool
    let done: Bool
    var body: some View {
        let letter = date.formatted(.dateTime.weekday(.narrow)) // M T W …
        VStack(spacing: 6) {
            Text(letter)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            ZStack {
                Circle().fill(Color.black.opacity(0.15))
                if done {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                }
            }
            .overlay(
                Circle().stroke(isToday ? .white : .white.opacity(0.06), lineWidth: 2)
            )
        }
        .frame(width: 44, height: 56)
    }
}
