import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text("Settings")
                        .font(.largeTitle.bold())
                        .lineLimit(1)
                        .foregroundColor(ThemeColors.primaryText(for: themeManager.effectiveColorScheme))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                
                // Settings content
                VStack(spacing: 16) {
                    // Theme Toggle
                    HStack {
                        Text("Dark Mode")
                            .foregroundColor(ThemeColors.primaryText(for: themeManager.effectiveColorScheme))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { themeManager.effectiveColorScheme == .dark },
                            set: { newValue in
                                themeManager.currentTheme = newValue ? .dark : .light
                            }
                        ))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ThemeColors.cardBackground(for: themeManager.effectiveColorScheme))
                    )
                    
                    // App Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.headline)
                            .foregroundColor(ThemeColors.primaryText(for: themeManager.effectiveColorScheme))
                        
                        Text("ProgressPic")
                            .font(.title2.bold())
                            .foregroundColor(ThemeColors.primaryText(for: themeManager.effectiveColorScheme))
                        
                        Text("Version 1.0")
                            .font(.body)
                            .foregroundColor(ThemeColors.secondaryText(for: themeManager.effectiveColorScheme))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ThemeColors.cardBackground(for: themeManager.effectiveColorScheme))
                    )
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 60)
            .padding(.bottom, 120)
        }
        .background(ThemeColors.backgroundColor(for: themeManager.effectiveColorScheme))
        .ignoresSafeArea(.container, edges: .top)
    }
}

#Preview {
    SettingsView()
        .environmentObject(ThemeManager())
}