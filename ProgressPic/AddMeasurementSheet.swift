import SwiftUI
import SwiftData

struct AddMeasurementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    let journey: Journey

    @State private var type: MeasurementType = .bicepsRight
    @State private var date: Date = .now
    @State private var unit: MeasureUnit = .cm
    @State private var valueString: String = ""
    @State private var customLabel: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Measurement", selection: $type) {
                        ForEach(MeasurementType.allCases) { t in Text(t.title).tag(t) }
                    }
                    .onChange(of: type) { _ in unit = defaultUnit(for: type) }
                }

                if type == .custom {
                    Section("Custom name") { TextField("e.g. Neck", text: $customLabel) }
                }

                Section("Value") {
                    HStack {
                        TextField("0.0", text: $valueString)
                            .keyboardType(.decimalPad)
                        Picker("", selection: $unit) {
                            ForEach(units(for: type)) { u in Text(u.rawValue.uppercased()).tag(u) }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 220)
                    }
                }

                Section("Date") {
                    DatePicker("When", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                Section("How to measure") { guide(for: type) }
            }
            .navigationTitle("Add Measurement")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let value = Double(valueString.replacingOccurrences(of: ",", with: ".")) else { return }
                        let entry = MeasurementEntry(
                            journeyId: journey.id,
                            date: date,
                            type: type,
                            value: value,
                            unit: unit,
                            label: type == .custom ? (customLabel.isEmpty ? "Custom" : customLabel) : nil
                        )
                        ctx.insert(entry)
                        dismiss()
                    }
                }
            }
        }
        .onAppear { unit = defaultUnit(for: type) }
    }

    // Units per type
    func units(for t: MeasurementType) -> [MeasureUnit] {
        switch t {
        case .weight: return [.kg, .lb]
        case .bodyFat: return [.percent]
        case .chest, .waist, .hips, .bicepsLeft, .bicepsRight, .thigh, .calf: return [.cm, .inch]
        case .custom: return [.kg, .lb, .cm, .inch, .percent]
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
            bullet("Tape around chest at nipple line, under armpits.")
            bullet("Stand tall; exhale normally; tape snug, not tight.")
        case .waist:
            bullet("Find the narrowest point above the navel.")
            bullet("Relax abdomen; don’t suck in.")
        case .hips:
            bullet("Around the widest part of butt/hips.")
            bullet("Stand feet together, weight evenly distributed.")
        case .bicepsLeft, .bicepsRight:
            bullet("Halfway between shoulder and elbow.")
            bullet("Arm relaxed by your side; use same side each time.")
        case .thigh:
            bullet("About 15 cm above the top of the kneecap.")
            bullet("Stand upright; tape parallel to the floor.")
        case .calf:
            bullet("At the widest point of the calf.")
            bullet("Even pressure all around the limb.")
        case .custom:
            bullet("Define a clear landmark and always measure at the same spot.")
            bullet("Keep tape snug, parallel to the floor when applicable.")
        }
    }
    func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(.white).frame(width: 6, height: 6).padding(.top, 6)
            Text(text)
        }
    }
}
