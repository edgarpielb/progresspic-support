import SwiftUI

private let accent = Color(red: 0.24, green: 0.85, blue: 0.80)   // mint
private let accentCyan = Color(red: 0.23, green: 0.83, blue: 1)  // cyan

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(icon: "rectangle.stack", title: "Journeys", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            Spacer()
            TabBarButton(icon: "flame", title: "Activity", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
            Spacer()
            TabBarButton(icon: "camera.fill", title: "Camera", isSelected: selectedTab == 2) {
                selectedTab = 2
            }
            Spacer()
            TabBarButton(icon: "square.split.2x1", title: "Compare", isSelected: selectedTab == 3) {
                selectedTab = 3
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(ThemeColors.cardBackground(for: themeManager.effectiveColorScheme))
                .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
}

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    var action: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : ThemeColors.secondaryText(for: themeManager.effectiveColorScheme))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? .white : ThemeColors.secondaryText(for: themeManager.effectiveColorScheme))
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? .white.opacity(0.35) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
