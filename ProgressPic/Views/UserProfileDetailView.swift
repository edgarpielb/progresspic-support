import SwiftUI

struct UserProfileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var userProfile = UserProfile.load()
    @State private var showEditSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppStyle.Colors.bgDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Profile")
                                .font(.largeTitle.bold())
                                .foregroundColor(.white)
                            
                            Text("Your personal health information")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                        .padding(.horizontal, 24)
                        
                        // Profile Details
                        VStack(spacing: 16) {
                            // Age
                            if let age = userProfile.age {
                                ProfileDetailRow(
                                    icon: "calendar",
                                    title: "Age",
                                    value: "\(age) years old"
                                )
                            }
                            
                            // Birth Date
                            if let birthDate = userProfile.birthDate {
                                ProfileDetailRow(
                                    icon: "calendar",
                                    title: "Birth Date",
                                    value: formatDate(birthDate)
                                )
                            }
                            
                            // Height
                            if let height = userProfile.heightCm {
                                let displayValue = userProfile.preferredUnit == .inch
                                    ? String(format: "%.1f in", height / 2.54)
                                    : String(format: "%.1f cm", height)
                                
                                ProfileDetailRow(
                                    icon: "ruler",
                                    title: "Height",
                                    value: displayValue
                                )
                            }
                            
                            // Gender
                            if let gender = userProfile.gender {
                                ProfileDetailRow(
                                    icon: "person",
                                    title: "Gender",
                                    value: gender.rawValue
                                )
                            }
                            
                            // Preferred Unit
                            if let unit = userProfile.preferredUnit {
                                ProfileDetailRow(
                                    icon: "ruler.fill",
                                    title: "Preferred Unit",
                                    value: unit == .cm ? "Centimeters" : "Inches"
                                )
                            }

                            // Color Scheme
                            ColorSchemePickerRow(
                                selectedScheme: Binding(
                                    get: { userProfile.colorScheme ?? .pink },
                                    set: { newScheme in
                                        userProfile.colorScheme = newScheme
                                        userProfile.save()
                                    }
                                )
                            )
                        }
                        .padding(.horizontal, 24)
                        
                        // Edit Button
                        Button(action: { showEditSheet = true }) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit Profile")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppStyle.Colors.accentPrimary)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .foregroundColor(AppStyle.Colors.accentPrimary)
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                UserProfileSetupView { profile in
                    userProfile = profile
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}

struct ProfileDetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(.white)

            Text(value)
                .font(.title3)
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
        }
    }
}

struct ColorSchemePickerRow: View {
    @Binding var selectedScheme: UserProfile.ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Theme Color", systemImage: "paintpalette.fill")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 12) {
                ForEach(UserProfile.ColorScheme.allCases, id: \.self) { scheme in
                    Button(action: {
                        selectedScheme = scheme
                    }) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(scheme == .cyan ? Color.cyan : Color.pink)
                                .frame(width: 24, height: 24)

                            Text(scheme.rawValue)
                                .font(.body)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(selectedScheme == scheme ? 0.2 : 0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            selectedScheme == scheme
                                                ? (scheme == .cyan ? Color.cyan : Color.pink)
                                                : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    UserProfileDetailView()
}

