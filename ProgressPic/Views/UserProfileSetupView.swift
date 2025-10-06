import SwiftUI

struct UserProfileSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var birthDate = Date()
    @State private var heightCm: String = ""
    @State private var selectedGender: UserProfile.Gender = .male
    
    var onComplete: (UserProfile) -> Void
    
    var body: some View {
        ZStack {
            Color(red: 30/255, green: 32/255, blue: 35/255).ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Set Up Your Profile")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)
                        
                        Text("Help us provide better health insights by adding your information")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Birth Date
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Birth Date", systemImage: "calendar")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        DatePicker(
                            "Select date",
                            selection: $birthDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .colorScheme(.dark)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Height
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Height (cm)", systemImage: "ruler")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        TextField("Enter height", text: $heightCm)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                    }
                    
                    // Gender
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Gender", systemImage: "person")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Picker("Gender", selection: $selectedGender) {
                            ForEach(UserProfile.Gender.allCases, id: \.self) { gender in
                                Text(gender.rawValue).tag(gender)
                            }
                        }
                        .pickerStyle(.segmented)
                        .colorScheme(.dark)
                    }
                    
                    // Info box
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Why we need this")
                                .font(.callout.bold())
                                .foregroundColor(.white)
                        }
                        
                        Text("This information helps us show how your health metrics compare to average ranges for your age group. All data is stored locally on your device.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    Spacer(minLength: 40)
                    
                    // Buttons
                    VStack(spacing: 12) {
                        Button(action: saveProfile) {
                            Text("Continue")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isValidInput ? Color.pink : Color.gray.opacity(0.3))
                                .cornerRadius(12)
                        }
                        .disabled(!isValidInput)
                        
                        Button(action: skipSetup) {
                            Text("Skip for now")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    private var isValidInput: Bool {
        guard let height = Double(heightCm) else { return false }
        return height > 0 && height < 300
    }
    
    private func saveProfile() {
        var profile = UserProfile()
        profile.birthDate = birthDate
        profile.heightCm = Double(heightCm)
        profile.gender = selectedGender
        profile.save()
        onComplete(profile)
        dismiss()
    }
    
    private func skipSetup() {
        dismiss()
    }
}

