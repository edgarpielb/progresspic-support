import SwiftUI
import SwiftData

// Helper to save/load last measurement values
struct MeasurementMemory {
    private static let key = "LastMeasurementValues"
    
    static func save(type: MeasurementType, value: Double) {
        var saved = load()
        saved[type.rawValue] = value
        UserDefaults.standard.set(saved, forKey: key)
    }
    
    static func load() -> [String: Double] {
        UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
    }
    
    static func get(type: MeasurementType) -> Double? {
        load()[type.rawValue]
    }
}

struct BulkMeasurementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    
    let journey: Journey
    
    @State private var date: Date = .now
    @State private var unit: MeasureUnit = .cm
    @State private var userProfile = UserProfile.load()
    @State private var useLastValues = false
    
    // All measurement values as optional strings
    @State private var chest: String = ""
    @State private var waist: String = ""
    @State private var hips: String = ""
    @State private var neck: String = ""
    @State private var bicepsLeft: String = ""
    @State private var bicepsRight: String = ""
    @State private var forearmLeft: String = ""
    @State private var forearmRight: String = ""
    @State private var thighLeft: String = ""
    @State private var thighRight: String = ""
    @State private var calfLeft: String = ""
    @State private var calfRight: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppStyle.Colors.bgDark.ignoresSafeArea()
                
                Form {
                    Section {
                        Text("For detailed instructions on how to take each measurement, go back and tap on the specific body part.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Quick fill button if we have saved values
                        if hasLastValues {
                            Button(action: loadLastValues) {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.title3)
                                    Text("Load Last Values")
                                        .font(.callout.bold())
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                                .foregroundColor(AppStyle.Colors.accentPrimary)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    Section("Date") {
                        DatePicker("When", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        
                        HStack {
                            Text("Unit")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(unit.rawValue.uppercased())
                                .foregroundColor(.white)
                        }
                    }
                    
                    Section("Torso") {
                        MeasurementField(label: "Chest", value: $chest)
                        MeasurementField(label: "Waist", value: $waist)
                        MeasurementField(label: "Hips", value: $hips)
                        MeasurementField(label: "Neck", value: $neck)
                    }
                    
                    Section("Arms") {
                        MeasurementField(label: "Left Biceps", value: $bicepsLeft)
                        MeasurementField(label: "Right Biceps", value: $bicepsRight)
                        MeasurementField(label: "Left Forearm", value: $forearmLeft)
                        MeasurementField(label: "Right Forearm", value: $forearmRight)
                    }
                    
                    Section("Legs") {
                        MeasurementField(label: "Left Thigh", value: $thighLeft)
                        MeasurementField(label: "Right Thigh", value: $thighRight)
                        MeasurementField(label: "Left Calf", value: $calfLeft)
                        MeasurementField(label: "Right Calf", value: $calfRight)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add All Measurements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveAllMeasurements) {
                        Image(systemName: "checkmark")
                            .foregroundColor(hasAnyValue ? AppStyle.Colors.accentPrimary : .gray)
                    }
                    .disabled(!hasAnyValue)
                }
            }
        }
        .onAppear {
            unit = userProfile.preferredUnit ?? .cm
        }
    }
    
    var hasAnyValue: Bool {
        !chest.isEmpty || !waist.isEmpty || !hips.isEmpty || !neck.isEmpty ||
        !bicepsLeft.isEmpty || !bicepsRight.isEmpty ||
        !forearmLeft.isEmpty || !forearmRight.isEmpty ||
        !thighLeft.isEmpty || !thighRight.isEmpty ||
        !calfLeft.isEmpty || !calfRight.isEmpty
    }
    
    var hasLastValues: Bool {
        !MeasurementMemory.load().isEmpty
    }
    
    func loadLastValues() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Load saved values
        if let value = MeasurementMemory.get(type: .chest) {
            chest = String(format: "%.1f", value)
        }
        if let value = MeasurementMemory.get(type: .waist) {
            waist = String(format: "%.1f", value)
        }
        if let value = MeasurementMemory.get(type: .hips) {
            hips = String(format: "%.1f", value)
        }
        if let value = MeasurementMemory.get(type: .neck) {
            neck = String(format: "%.1f", value)
        }
        if let value = MeasurementMemory.get(type: .bicepsLeft) {
            bicepsLeft = String(format: "%.1f", value)
        }
        if let value = MeasurementMemory.get(type: .bicepsRight) {
            bicepsRight = String(format: "%.1f", value)
        }
        if let value = MeasurementMemory.get(type: .forearmLeft) {
            forearmLeft = String(format: "%.1f", value)
        }
        if let value = MeasurementMemory.get(type: .forearmRight) {
            forearmRight = String(format: "%.1f", value)
        }
        if let value = MeasurementMemory.get(type: .thighLeft) {
            thighLeft = String(format: "%.1f", value)
        }
        if let value = MeasurementMemory.get(type: .thighRight) {
            thighRight = String(format: "%.1f", value)
        }
        if let value = MeasurementMemory.get(type: .calfLeft) {
            calfLeft = String(format: "%.1f", value)
        }
        if let value = MeasurementMemory.get(type: .calfRight) {
            calfRight = String(format: "%.1f", value)
        }
    }
    
    func saveAllMeasurements() {
        saveMeasurement(type: .chest, value: chest)
        saveMeasurement(type: .waist, value: waist)
        saveMeasurement(type: .hips, value: hips)
        saveMeasurement(type: .neck, value: neck)
        saveMeasurement(type: .bicepsLeft, value: bicepsLeft)
        saveMeasurement(type: .bicepsRight, value: bicepsRight)
        saveMeasurement(type: .forearmLeft, value: forearmLeft)
        saveMeasurement(type: .forearmRight, value: forearmRight)
        saveMeasurement(type: .thighLeft, value: thighLeft)
        saveMeasurement(type: .thighRight, value: thighRight)
        saveMeasurement(type: .calfLeft, value: calfLeft)
        saveMeasurement(type: .calfRight, value: calfRight)
        
        // Haptic success feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        dismiss()
    }
    
    func saveMeasurement(type: MeasurementType, value: String) {
        guard let doubleValue = Double(value.replacingOccurrences(of: ",", with: ".")) else { return }
        
        // Save to measurement memory for next time
        MeasurementMemory.save(type: type, value: doubleValue)
        
        let entry = MeasurementEntry(
            journeyId: journey.id,
            date: date,
            type: type,
            value: doubleValue,
            unit: unit,
            label: nil
        )
        ctx.insert(entry)
    }
}

struct MeasurementField: View {
    let label: String
    @Binding var value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.white)
            Spacer()
            TextField("Optional", text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
        }
    }
}

