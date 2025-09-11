import SwiftUI
import SwiftData
import Charts

struct ActivityView: View {
    @Query(sort: \Journey.createdAt, order: .reverse) private var journeys: [Journey]
    @State private var selectedJourney: Journey?
    @State private var showAvg = true
    @State private var showAddSheet = false
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            // Force dark background
            Color(red: 30/255, green: 32/255, blue: 35/255)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Journey picker
                    Menu {
                        ForEach(journeys) { j in Button(j.name) { selectedJourney = j } }
                    } label: {
                        Label(selectedJourney?.name ?? "Select Journey", systemImage: "rectangle.stack")
                            .foregroundColor(.white)
                            .padding(10).background(.ultraThinMaterial, in: Capsule())
                    }
                    .padding(.top, 12)

                if let j = selectedJourney {
                    // WEEK RING
                    WeekRingView(journey: j)

                    // STREAKS
                    StreakCards(journey: j)

                    // YEAR HEATMAP
                    YearHeatmapView(journey: j)

                    // MEASUREMENTS + CHART
                    MeasurementsSection(journey: j, showAvg: $showAvg)
                        .overlay(alignment: .topTrailing) {
                            Button {
                                showAddSheet = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .padding(10)
                            }
                        }
                } else {
                    Text("Select a journey to see your activity")
                        .foregroundColor(.white)
                }

                Spacer(minLength: 160)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120) // Space for custom tab bar
            }
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showAddSheet) {
            if let j = selectedJourney {
                AddMeasurementSheet(journey: j)
                    .presentationDetents([.medium, .large])
            }
        }
        .onAppear {
            if selectedJourney == nil { selectedJourney = journeys.first }
        }
    }
}

// -------- Streak cards (unchanged) --------
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
            Text(value).font(.title.bold())
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.15)))
    }
}

// -------- Measurements + Chart (minor tweak: header spacing) --------
struct MeasurementsSection: View {
    let journey: Journey
    @Query private var entries: [MeasurementEntry]
    @State private var type: MeasurementType = .bicepsRight
    @Binding var showAvg: Bool

    init(journey: Journey, showAvg: Binding<Bool>) {
        self.journey = journey
        _showAvg = showAvg
        let journeyId = journey.id
        _entries = Query(filter: #Predicate<MeasurementEntry> { $0.journeyId == journeyId },
                         sort: \MeasurementEntry.date, order: .forward)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Measurements").font(.title3.bold())
                Spacer()
                HStack(spacing: 8) {
                    Text("7-day avg").font(.caption).foregroundStyle(.secondary)
                    Toggle("", isOn: $showAvg).labelsHidden()
                }
            }

            Picker("", selection: $type) {
                ForEach(MeasurementType.allCases) { t in Text(t.title).tag(t) }
            }.pickerStyle(.segmented)

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
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.15)))
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
