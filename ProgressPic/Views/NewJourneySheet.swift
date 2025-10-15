import SwiftUI
import SwiftData

struct TempReminder: Identifiable {
    let id = UUID()
    var hour: Int
    var minute: Int
    var daysBitmask: Int
    var notificationText: String
}

struct NewJourneySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    @State private var name = ""
    @State private var saveToCameraRoll = false
    @State private var tempReminders: [TempReminder] = []
    @State private var showEditReminder = false
    @State private var editingReminder: TempReminder? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 30/255, green: 32/255, blue: 35/255).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Name section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.title2)
                                .foregroundColor(.white)
                            TextField("Journey name", text: $name)
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        // Reminders section
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Reminders")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                
                                Text("Set up reminders to help you crush your new habit goals.")
                                    .font(.body)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            // Existing reminders
                            ForEach(tempReminders) { reminder in
                                Button(action: {
                                    editingReminder = reminder
                                    showEditReminder = true
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(String(format: "%02d", reminder.hour)):\(String(format: "%02d", reminder.minute))")
                                                .foregroundColor(.white)
                                                .font(.body)
                                            Text(formatDays(reminder.daysBitmask))
                                                .foregroundColor(.gray)
                                                .font(.caption)
                                            Text(reminder.notificationText)
                                                .foregroundColor(.gray)
                                                .font(.caption2)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Button(role: .destructive) {
                                            tempReminders.removeAll { $0.id == reminder.id }
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // Add reminder button
                            Button(action: {
                                editingReminder = nil
                                showEditReminder = true
                            }) {
                                HStack {
                                    Image(systemName: "plus")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                    Text("Add Reminder")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.gray)
                                    Spacer()
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        
                        // Settings section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Settings")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Save to Camera Roll")
                                        .font(.body)
                                        .foregroundColor(.white)
                                    Text("Automatically save photos to your photo library")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Toggle("", isOn: $saveToCameraRoll)
                                    .labelsHidden()
                                    .tint(.blue)
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 4) {
                        Text("New Journey")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("SETTINGS")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                            .tracking(1.2)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { 
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        let j = Journey(name: name.isEmpty ? "My Journey" : name,
                                        saveToCameraRoll: saveToCameraRoll)
                        ctx.insert(j)
                        
                        // Add reminders to the journey
                        for tempReminder in tempReminders {
                            let reminder = JourneyReminder(
                                hour: tempReminder.hour,
                                minute: tempReminder.minute,
                                daysBitmask: tempReminder.daysBitmask,
                                notificationText: tempReminder.notificationText
                            )
                            ctx.insert(reminder)
                            reminder.journey = j
                        }
                        
                        ReminderManager.schedule(for: j)
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showEditReminder) {
                NewJourneyEditReminderView(
                    tempReminders: $tempReminders,
                    editingReminder: editingReminder
                )
            }
        }
    }
    
    func formatDays(_ bitmask: Int) -> String {
        var selectedDays: Set<Int> = []
        for day in 1...7 {
            if bitmask & (1 << (day - 1)) != 0 {
                selectedDays.insert(day)
            }
        }
        
        let sortedDays = Array(selectedDays).sorted()
        
        if sortedDays == [1, 2, 3, 4, 5, 6, 7] {
            return "Every Day"
        } else if sortedDays == [1, 2, 3, 4, 5] {
            return "Weekdays"
        } else if sortedDays == [6, 7] {
            return "Weekends"
        } else {
            let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            let selectedDayNames = sortedDays.map { dayNames[$0 - 1] }
            return selectedDayNames.joined(separator: ", ")
        }
    }
}

// Simplified EditReminderView for NewJourneySheet (before journey exists)
struct NewJourneyEditReminderView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var tempReminders: [TempReminder]
    let editingReminder: TempReminder?
    
    @State private var selectedHour = 10
    @State private var selectedMinute = 0
    @State private var selectedDays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    @State private var notificationText = "Time for a new photo!"
    
    init(tempReminders: Binding<[TempReminder]>, editingReminder: TempReminder?) {
        self._tempReminders = tempReminders
        self.editingReminder = editingReminder
        
        if let reminder = editingReminder {
            _selectedHour = State(initialValue: reminder.hour)
            _selectedMinute = State(initialValue: reminder.minute)
            _notificationText = State(initialValue: reminder.notificationText)
            
            // Decode days from bitmask
            var days: Set<Int> = []
            for day in 1...7 {
                if reminder.daysBitmask & (1 << (day - 1)) != 0 {
                    days.insert(day)
                }
            }
            _selectedDays = State(initialValue: days)
        }
    }
    
    private let days = [
        (1, "Monday"), (2, "Tuesday"), (3, "Wednesday"),
        (4, "Thursday"), (5, "Friday"), (6, "Saturday"), (7, "Sunday")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 30/255, green: 32/255, blue: 35/255).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Spacer().frame(height: 20)
                        
                        // Notification Text
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notification Message")
                                .font(.body)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                            
                            TextField("Time for a new photo!", text: $notificationText)
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                        }
                        
                        // Reminder Time Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reminder Time")
                                .font(.body)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                            
                            HStack(spacing: 0) {
                                Picker("Hour", selection: $selectedHour) {
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text(String(format: "%02d", hour))
                                            .foregroundColor(.white)
                                            .tag(hour)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxWidth: .infinity)
                                
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
                                Button("Every Day") { selectedDays = Set(1...7) }
                                    .buttonStyle(QuickSelectButtonStyle(isSelected: selectedDays.count == 7))
                                
                                Button("Weekdays") { selectedDays = Set(1...5) }
                                    .buttonStyle(QuickSelectButtonStyle(isSelected: selectedDays == Set(1...5)))
                                
                                Button("Weekends") { selectedDays = Set([6, 7]) }
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
            .navigationTitle(editingReminder == nil ? "Add Reminder" : "Edit Reminder")
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
                    .disabled(notificationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedDays.isEmpty)
                }
            }
        }
    }
    
    private func saveReminder() {
        guard !selectedDays.isEmpty else { return }
        
        let daysBitmask = selectedDays.reduce(0) { result, day in
            result | (1 << (day - 1))
        }
        
        if let existing = editingReminder {
            // Update existing reminder in the array
            if let index = tempReminders.firstIndex(where: { $0.id == existing.id }) {
                tempReminders[index] = TempReminder(
                    hour: selectedHour,
                    minute: selectedMinute,
                    daysBitmask: daysBitmask,
                    notificationText: notificationText
                )
            }
        } else {
            // Add new reminder
            let newReminder = TempReminder(
                hour: selectedHour,
                minute: selectedMinute,
                daysBitmask: daysBitmask,
                notificationText: notificationText
            )
            tempReminders.append(newReminder)
        }
    }
}
