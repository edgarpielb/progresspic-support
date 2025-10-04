import SwiftUI
import SwiftData

struct NewJourneySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    @State private var name = ""
    @State private var saveToCameraRoll = true
    @State private var reminderTimes: [DateComponents] = []
    @State private var timeDraft: Date = Date()
    @State private var showEditReminder = false

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
                            ForEach(Array(reminderTimes.enumerated()), id: \.offset) { idx, comps in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(String(format: "%02d", comps.hour ?? 0)):\(String(format: "%02d", comps.minute ?? 0))")
                                            .foregroundColor(.white)
                                            .font(.body)
                                        Text(ReminderDaysFormatter.formatDaysInfo(for: comps))
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                    }
                                    Spacer()
                                    Button(role: .destructive) { reminderTimes.remove(at: idx) } label: { 
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                            }
                            
                            // Add reminder button
                            Button(action: {
                                showEditReminder = true
                            }) {
                                HStack {
                                    Image(systemName: "plus")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                    Text("ADD REMINDER")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.gray)
                                    Spacer()
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                            }
                            
                            // Hidden time picker (we'll show a proper time picker when button is tapped)
                            DatePicker("", selection: $timeDraft, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .opacity(0)
                                .frame(height: 0)
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
                                        saveToCameraRoll: saveToCameraRoll,
                                        reminderTimes: reminderTimes)
                        ctx.insert(j)
                        Task { _ = await ReminderManager.requestPermission(); ReminderManager.schedule(for: j) }
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showEditReminder) {
                EditReminderView(reminderTimes: $reminderTimes)
            }
        }
    }
}
