import SwiftUI

struct UserProfileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var userProfile = UserProfile.load()
    @State private var showEditSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 30/255, green: 32/255, blue: 35/255).ignoresSafeArea()
                
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
                            .background(Color.pink)
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
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.pink)
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

#Preview {
    UserProfileDetailView()
}

