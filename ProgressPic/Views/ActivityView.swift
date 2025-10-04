import SwiftUI
import SwiftData
import Charts

struct ActivityView: View {
    @Query(sort: \Journey.createdAt, order: .reverse) private var journeys: [Journey]
    @State private var selectedJourney: Journey?
    @State private var showAddSheet = false

    var body: some View {
        ZStack {
            Color(red: 30/255, green: 32/255, blue: 35/255).ignoresSafeArea()

            if selectedJourney == nil {
                // Empty state without ScrollView
                VStack(spacing: 20) {
                    // Journey picker at top
                    Menu {
                        ForEach(journeys) { j in Button(j.name) { selectedJourney = j } }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.stack")
                            Text("Select Journey")
                        }
                        .foregroundColor(.white)
                        .glassCapsule()
                        .contentShape(Rectangle())
                    }
                    .padding(.top, 12)
                    
                    Spacer()
                    
                    // Centered message
                    Text("Select a journey to see your activity")
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .font(.body)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
            } else {
                // Content state with ScrollView
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Journey picker as a glass capsule (larger tap area)
                        Menu {
                            ForEach(journeys) { j in Button(j.name) { selectedJourney = j } }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "rectangle.stack")
                                Text(selectedJourney?.name ?? "Select Journey")
                            }
                            .foregroundColor(.white)
                            .glassCapsule()
                            .contentShape(Rectangle())
                        }
                        .padding(.top, 12)

                        if let j = selectedJourney {
                            WeekRingView(journey: j)
                                .padding(12)
                                .glassCard()

                            StreakCards(journey: j)
                                .padding(12)
                                .glassCard()

                            YearHeatmapView(journey: j)
                                .padding(12)
                                .glassCard()

                            MeasurementsSection(journey: j) {
                                showAddSheet = true
                            }
                            .padding(12)
                            .glassCard()
                        }

                        Spacer(minLength: 160)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 120)
                }
            }
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .fullScreenCover(isPresented: $showAddSheet) {
            if let j = selectedJourney {
                AddMeasurementSheet(journey: j)
            }
        }
        .onAppear {
            if selectedJourney == nil, let firstJourney = journeys.first {
                selectedJourney = firstJourney
            }
        }
    }
}

// Unchanged logic — only small style tweaks inside components if needed.
struct StreakCards: View {
    let journey: Journey
    @Query private var photos: [ProgressPhoto]

    init(journey: Journey) {
        self.journey = journey
        let journeyId = journey.id
        _photos = Query(filter: #Predicate<ProgressPhoto> { $0.journeyId == journeyId },
                        sort: \ProgressPhoto.date, order: .forward)
    }

    var body: some View {
        let (current, longest) = streaks()
        HStack(spacing: 12) {
            Card("Current", value: "\(current) day\(current == 1 ? "" : "s")")
            Card("Longest", value: "\(longest) day\(longest == 1 ? "" : "s")")
        }
    }

    func streaks() -> (Int, Int) {
        let days = photos.map { Calendar.current.startOfDay(for: $0.date) }.sorted()
        var cur = 0, maxS = 0
        var last: Date?
        for d in days {
            if let l = last, Calendar.current.date(byAdding: .day, value: 1, to: l) == d { cur += 1 } else { cur = 1 }
            maxS = max(maxS, cur); last = d
        }
        return (cur, maxS)
    }

    func Card(_ title: String, value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.callout).foregroundStyle(.secondary)
            Text(value).font(.title.bold()).foregroundColor(.white)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .glassTile()
    }
}

struct MeasurementsSection: View {
    let journey: Journey
    var onAddTap: () -> Void
    @Query private var entries: [MeasurementEntry]
    @State private var type: MeasurementType = .bicepsRight
    @State private var showAvg = true

    init(journey: Journey, onAddTap: @escaping () -> Void) {
        self.journey = journey
        self.onAddTap = onAddTap
        let journeyId = journey.id
        _entries = Query(filter: #Predicate<MeasurementEntry> { $0.journeyId == journeyId },
                         sort: \MeasurementEntry.date, order: .forward)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Measurements")
                    .font(.title3.bold()).foregroundColor(.white)
                Spacer()
                Button(action: onAddTap) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }

            // Replace the segmented Picker with chips:
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(MeasurementType.allCases) { t in
                        Button {
                            type = t
                        } label: {
                            Text(t.title)
                                .font(.caption.bold())
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(t == type ? Color.white.opacity(0.10) : Color.white.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(t == type ? Color.white.opacity(0.35) : Color.white.opacity(0.15), lineWidth: 1)
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            Chart {
                ForEach(series()) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Value", point.value))
                    PointMark(x: .value("Date", point.date), y: .value("Value", point.value))
                }
                if showAvg {
                    ForEach(movingAverage(series(), n: 7)) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Avg", point.value))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 240)
            .glassTile(corner: 18)
        }
    }

    struct Pt: Identifiable { let id = UUID(); let date: Date; let value: Double }
    func series() -> [Pt] {
        entries.filter { $0.type == type }.map { Pt(date: $0.date, value: $0.value) }.sorted { $0.date < $1.date }
    }
    func movingAverage(_ arr: [Pt], n: Int) -> [Pt] {
        guard n > 1, arr.count >= n else { return [] }
        var res: [Pt] = []
        for i in (n-1)..<arr.count {
            let slice = arr[(i-n+1)...i]
            let avg = slice.map { $0.value }.reduce(0, +) / Double(slice.count)
            res.append(Pt(date: arr[i].date, value: avg))
        }
        return res
    }
}
