import SwiftUI

struct SettingsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Settings content
                VStack(spacing: 16) {
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
    }
}

#Preview {
    SettingsView()
}