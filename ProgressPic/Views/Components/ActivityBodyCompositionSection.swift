import SwiftUI

/// Section displaying HealthKit body composition data
struct BodyCompositionSection: View {
    @ObservedObject var healthKit: HealthKitService
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "heart.text.square")
                        .font(.title3)
                        .foregroundColor(AppStyle.Colors.accentPrimary)
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

/// Row displaying a health metric with value and unit
private struct MetricRow: View {
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
