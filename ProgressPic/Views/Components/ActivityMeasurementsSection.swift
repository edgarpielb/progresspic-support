import SwiftUI
import SwiftData

/// Section displaying all body measurement statistics for a journey
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
                        .foregroundColor(AppStyle.Colors.accentPrimary)
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

/// Section header for grouping measurements
private struct SectionHeader: View {
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

/// Row displaying a single measurement type with latest value
private struct MeasurementRow: View {
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
