import SwiftUI

struct SettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text("Settings")
                        .font(.largeTitle.bold())
                        .lineLimit(1)
                        .foregroundColor(ThemeColors.primaryText())
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                
                // Settings content
                VStack(spacing: 16) {
                    // App Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.headline)
                            .foregroundColor(ThemeColors.primaryText())
                        
                        Text("ProgressPic")
                            .font(.title2.bold())
                            .foregroundColor(ThemeColors.primaryText())
                        
                        Text("Version 1.0")
                            .font(.body)
                            .foregroundColor(ThemeColors.secondaryText())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ThemeColors.cardBackground())
                    )
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 60)
            .padding(.bottom, 120)
        }
        .background(ThemeColors.backgroundColor())
        .ignoresSafeArea(.container, edges: .top)
    }
}

#Preview {
    SettingsView()
}