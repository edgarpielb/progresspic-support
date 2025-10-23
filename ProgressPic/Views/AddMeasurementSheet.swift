import SwiftUI
import SwiftData

struct AddMeasurementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    let journey: Journey
    let measurementType: MeasurementType

    @State private var date: Date = .now
    @State private var unit: MeasureUnit = .cm
    @State private var valueString: String = ""
    @State private var userProfile = UserProfile.load()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 30/255, green: 32/255, blue: 35/255).ignoresSafeArea()
                
                Form {
                Section {
                    HStack {
                        Text("Type")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(measurementType.title)
                            .foregroundColor(.white)
                    }
                }

                Section("Value") {
                    HStack {
                        TextField("0.0", text: $valueString)
                            .keyboardType(.decimalPad)
                        Text(unit.rawValue.uppercased())
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                    }
                }

                Section("Date") {
                    DatePicker("When", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                Section("How to measure") { guide(for: measurementType) }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Measurement")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { 
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        guard let value = Double(valueString.replacingOccurrences(of: ",", with: ".")) else { return }
                        let entry = MeasurementEntry(
                            journeyId: journey.id,
                            date: date,
                            type: measurementType,
                            value: value,
                            unit: unit,
                            label: nil
                        )
                        ctx.insert(entry)
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .foregroundColor(valueString.isEmpty ? .gray : AppStyle.Colors.accentPrimary)
                    }
                    .disabled(valueString.isEmpty)
                }
            }
        }
        .onAppear { 
            // Use user's preferred unit if available, otherwise default
            if let preferredUnit = userProfile.preferredUnit, units(for: measurementType).contains(preferredUnit) {
                unit = preferredUnit
            } else {
                unit = defaultUnit(for: measurementType)
            }
        }
    }

    // Units per type
    func units(for t: MeasurementType) -> [MeasureUnit] {
        switch t {
        case .weight: return [.kg, .lb]
        case .bodyFat: return [.percent]
        case .chest, .waist, .hips, .neck,
             .bicepsLeft, .bicepsRight,
             .forearmLeft, .forearmRight,
             .thighLeft, .thighRight,
             .calfLeft, .calfRight: return [.cm, .inch]
        case .custom: return [.cm] // Fallback (shouldn't be reached)
        }
    }
    func defaultUnit(for t: MeasurementType) -> MeasureUnit { units(for: t).first ?? .cm }

    // Short, practical guides
    @ViewBuilder
    func guide(for t: MeasurementType) -> some View {
        switch t {
        case .weight:
            bullet("Weigh at the same time of day (ideally morning, after bathroom).")
            bullet("Use the same scale on a flat surface.")
        case .bodyFat:
            bullet("Use the same device/method each time (e.g., smart scale or calipers).")
            bullet("Measure under similar hydration conditions.")
        case .chest:
            bullet("Measure around the fullest part of your chest at nipple level.")
            bullet("Stand tall, breathe normally, keep tape snug but not tight.")
        case .waist:
            bullet("Measure at the narrowest point of your torso, above your belly button.")
            bullet("Stand naturally, don't suck in your abdomen.")
        case .hips:
            bullet("Measure at the widest part of your hips and buttocks.")
            bullet("Stand with feet together, weight evenly distributed.")
        case .neck:
            bullet("Measure around the middle of your neck, below the Adam's apple.")
            bullet("Keep the tape snug but comfortable, don't pull tight.")
        case .bicepsLeft, .bicepsRight:
            bullet("Measure around the largest part of your upper arm when flexed.")
            bullet("Flex your arm to show the peak of the muscle.")
        case .forearmLeft, .forearmRight:
            bullet("Measure around the widest part of your lower arm near the elbow.")
            bullet("Keep your arm relaxed at your side.")
        case .thighLeft, .thighRight:
            bullet("Measure around the largest part of your upper leg.")
            bullet("Stand upright, keep tape parallel to the floor.")
        case .calfLeft, .calfRight:
            bullet("Measure around the largest part of your lower leg.")
            bullet("Stand naturally, tape snug with even pressure all around.")
        case .custom:
            bullet("Custom measurement.") // Fallback (shouldn't be reached)
        }
    }
    func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(.white).frame(width: 6, height: 6).padding(.top, 6)
            Text(text)
        }
    }
}
