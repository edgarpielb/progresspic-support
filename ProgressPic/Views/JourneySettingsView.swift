import SwiftUI
import SwiftData

struct JourneySettingsView: View {
    let journey: Journey
    let onJourneyDeleted: ((Bool) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    
    init(journey: Journey, onJourneyDeleted: ((Bool) -> Void)? = nil) {
        self.journey = journey
        self.onJourneyDeleted = onJourneyDeleted
    }
    @State private var journeyName: String = ""
    @State private var saveToCameraRoll: Bool = true
    @State private var showDeleteAlert = false
    @State private var showEditReminder = false
    @State private var reminderTimes: [DateComponents] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 30/255, green: 32/255, blue: 35/255).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        journeyInfoSection
                        journeyNameSection
                        remindersSection
                        settingsSection
                        dangerZoneSection
                        
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
                        Text("Edit Journey")
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { saveSettings() }) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .onAppear {
            journeyName = journey.name
            saveToCameraRoll = journey.saveToCameraRoll
            reminderTimes = journey.reminderTimes
        }
        .alert("Delete Journey", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteJourney()
            }
        } message: {
            Text("Are you sure you want to delete this journey? This will permanently delete all photos and measurements. This action cannot be undone.")
        }
        .sheet(isPresented: $showEditReminder) {
            EditReminderView(reminderTimes: $reminderTimes)
        }
    }
    
    private var journeyNameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Name")
                .font(.title2)
                .foregroundColor(.white)
            
            TextField("Journey name", text: $journeyName)
                .font(.title3)
                .foregroundColor(.white)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
        }
    }
    
    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reminders")
                .font(.title2)
                .foregroundColor(.white)
            
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
                    Button(role: .destructive) { 
                        reminderTimes.remove(at: idx)
                    } label: { 
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
            .buttonStyle(.plain)
        }
    }
    
    private var settingsSection: some View {
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
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Toggle("", isOn: $saveToCameraRoll)
                    .labelsHidden()
                    .tint(.blue)
            }
        }
    }
    
    private var journeyInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Journey Info")
                .font(.title2)
                .foregroundColor(.white)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Created")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(journey.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.body)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Photos")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(journey.photos?.count ?? 0)")
                        .font(.body)
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Danger Zone")
                .font(.title2)
                .foregroundColor(.red)
            
            Button(action: {
                showDeleteAlert = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "trash")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delete Journey")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text("This will delete all photos and data permanently")
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.5))
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
    
    private func saveSettings() {
        journey.name = journeyName.trimmingCharacters(in: .whitespacesAndNewlines)
        journey.saveToCameraRoll = saveToCameraRoll
        journey.reminderTimes = reminderTimes
        
        // Reschedule reminders with updated times
        ReminderManager.schedule(for: journey)
        
        try? ctx.save()
        dismiss()
    }
    
    private func deleteJourney() {
        ctx.delete(journey)
        try? ctx.save()
        onJourneyDeleted?(true)
        dismiss()
    }
}
