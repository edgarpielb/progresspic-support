import SwiftUI

struct EditReminderView: View {
    @Binding var reminderTimes: [DateComponents]
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedHour = 10
    @State private var selectedMinute = 0
    @State private var selectedDays: Set<Int> = [1, 2, 3, 4, 5, 6, 7] // All days selected by default
    
    private let days = [
        (1, "Monday"),
        (2, "Tuesday"), 
        (3, "Wednesday"),
        (4, "Thursday"),
        (5, "Friday"),
        (6, "Saturday"),
        (7, "Sunday")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 30/255, green: 32/255, blue: 35/255).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Spacer()
                            .frame(height: 20) // Add some top padding
                        
                        // Reminder Time Picker
                        VStack(alignment: .leading, spacing: 8) {
                                Text("Reminder Time")
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                
                                HStack(spacing: 0) {
                                    // Hour picker (00-23)
                                    Picker("Hour", selection: $selectedHour) {
                                        ForEach(0..<24, id: \.self) { hour in
                                            Text(String(format: "%02d", hour))
                                                .foregroundColor(.white)
                                                .tag(hour)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(maxWidth: .infinity)
                                    
                                    // Minute picker (00-59)
                                    Picker("Minute", selection: $selectedMinute) {
                                        ForEach(0..<60, id: \.self) { minute in
                                            Text(String(format: "%02d", minute))
                                                .foregroundColor(.white)
                                                .tag(minute)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(maxWidth: .infinity)
                                }
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                                .padding(.horizontal, 20)
                            }
                            
                            // Quick Select
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Quick Select")
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                
                                HStack(spacing: 8) {
                                    Button("Every Day") {
                                        selectedDays = Set(1...7)
                                    }
                                    .buttonStyle(QuickSelectButtonStyle(isSelected: selectedDays.count == 7))
                                    
                                    Button("Weekdays") {
                                        selectedDays = Set(1...5)
                                    }
                                    .buttonStyle(QuickSelectButtonStyle(isSelected: selectedDays == Set(1...5)))
                                    
                                    Button("Weekends") {
                                        selectedDays = Set([6, 7])
                                    }
                                    .buttonStyle(QuickSelectButtonStyle(isSelected: selectedDays == Set([6, 7])))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 20)
                            }
                            
                            // Reminder Days
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Reminder Days")
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                
                                Text("Choose which days you want to be reminded")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 20)
                                
                                VStack(spacing: 4) {
                                    ForEach(days, id: \.0) { dayNumber, dayName in
                                        Button(action: {
                                            if selectedDays.contains(dayNumber) {
                                                selectedDays.remove(dayNumber)
                                            } else {
                                                selectedDays.insert(dayNumber)
                                            }
                                        }) {
                                            HStack {
                                                Text(dayName)
                                                    .foregroundColor(.white)
                                                    .font(.body)
                                                Spacer()
                                            }
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 20)
                                            .background(selectedDays.contains(dayNumber) ? Color.blue.opacity(0.1) : Color.white.opacity(0.05))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(selectedDays.contains(dayNumber) ? Color.blue : Color.clear, lineWidth: 1)
                                            )
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        
                        Spacer(minLength: 50)
                    }
                }
            }
            .navigationTitle("Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        saveReminder()
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
    
    private func saveReminder() {
        guard !selectedDays.isEmpty else { return }
        
        var components = DateComponents(hour: selectedHour, minute: selectedMinute)
        // Encode selected days into the nanosecond field as a bitmask
        let daysBitmask = selectedDays.reduce(0) { result, day in
            result | (1 << (day - 1))
        }
        components.nanosecond = daysBitmask
        
        reminderTimes.append(components)
    }
    
    private func formatDaysInfo(for components: DateComponents) -> String {
        return ReminderDaysFormatter.formatDaysInfo(for: components)
    }
}

// Helper struct for formatting reminder days information
struct ReminderDaysFormatter {
    static func formatDaysInfo(for components: DateComponents) -> String {
        guard let daysBitmask = components.nanosecond else { return "Every Day" }
        
        // Decode selected days from bitmask
        var selectedDays: Set<Int> = []
        for day in 1...7 {
            if daysBitmask & (1 << (day - 1)) != 0 {
                selectedDays.insert(day)
            }
        }
        
        let sortedDays = Array(selectedDays).sorted()
        
        // Check for quick select patterns
        if sortedDays == [1, 2, 3, 4, 5, 6, 7] {
            return "Every Day"
        } else if sortedDays == [1, 2, 3, 4, 5] {
            return "Weekdays"
        } else if sortedDays == [6, 7] {
            return "Weekends"
        } else {
            // Format individual days
            let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            let selectedDayNames = sortedDays.map { dayNames[$0 - 1] }
            return selectedDayNames.joined(separator: ", ")
        }
    }
}

struct QuickSelectButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.medium))
            .foregroundColor(isSelected ? .white : .gray)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minWidth: 80)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.white.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
            )
            .cornerRadius(20)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}
