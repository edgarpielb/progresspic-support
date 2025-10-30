import SwiftUI

struct SettingsView: View {
    @State private var isICloudAvailable = FileManager.default.ubiquityIdentityToken != nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Settings content
                VStack(spacing: 16) {
                    // iCloud Sync Status
                    VStack(alignment: .leading, spacing: 8) {
                        Text("iCloud Sync")
                            .font(.headline)
                            .foregroundColor(AppStyle.Colors.textPrimary)
                        
                        HStack {
                            Image(systemName: isICloudAvailable ? "icloud.fill" : "icloud.slash.fill")
                                .font(.title2)
                                .foregroundColor(isICloudAvailable ? AppStyle.Colors.accentPrimary : .red)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(isICloudAvailable ? "Enabled" : "Disabled")
                                    .font(.body.bold())
                                    .foregroundColor(isICloudAvailable ? AppStyle.Colors.accentPrimary : .red)
                                
                                Text(isICloudAvailable ? "Your data syncs across all your devices" : "Sign in to iCloud in Settings to enable sync")
                                    .font(.caption)
                                    .foregroundColor(AppStyle.Colors.textSecondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppStyle.Colors.panel)
                        )
                        
                        if !isICloudAvailable {
                            Button(action: {
                                if let url = URL(string: "App-prefs:CASTLE") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text("Open iCloud Settings")
                                    .font(.callout.bold())
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppStyle.Colors.panel)
                    )
                    
                    // App Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.headline)
                            .foregroundColor(AppStyle.Colors.textPrimary)
                        
                        Text("ProgressPic")
                            .font(.title2.bold())
                            .foregroundColor(AppStyle.Colors.textPrimary)
                        
                        Text("Version 1.0")
                            .font(.body)
                            .foregroundColor(AppStyle.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppStyle.Colors.panel)
                    )
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 20)
            .padding(.bottom, 120)
        }
        .background(AppStyle.Colors.bgDark)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Check iCloud status when view appears
            isICloudAvailable = FileManager.default.ubiquityIdentityToken != nil
        }
    }
}

#Preview {
    SettingsView()
}