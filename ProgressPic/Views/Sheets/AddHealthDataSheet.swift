import SwiftUI

/// Sheet for adding manual health data entries
struct AddHealthDataSheet: View {
    let metricType: BodyMetricType
    @ObservedObject var healthKit: HealthKitService
    var onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var value: String = ""
    @State private var selectedDate = Date()
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])

                    HStack {
                        Text(metricType.title)
                        Spacer()
                        TextField("Value", text: $value)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text(unit)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Add \(metricType.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveData()
                        }
                    }
                    .disabled(value.isEmpty || isSaving)
                }
            }
        }
    }

    private var unit: String {
        switch metricType {
        case .bodyFat: return "%"
        case .bmi: return ""
        case .leanMass, .weight: return "kg"
        }
    }

    private func saveData() async {
        guard let doubleValue = Double(value) else { return }
        isSaving = true

        let success = await healthKit.saveHealthData(
            type: metricType.identifier,
            value: doubleValue,
            date: selectedDate
        )

        isSaving = false

        if success {
            onSave()
            dismiss()
        }
    }
}
