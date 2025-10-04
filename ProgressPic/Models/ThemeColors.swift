import SwiftUI

// MARK: - Theme Colors (Dark Mode Only)
struct ThemeColors {
    static func backgroundColor(for colorScheme: ColorScheme = .dark) -> Color {
        return Color(red: 30/255, green: 32/255, blue: 35/255)
    }
    
    static func cardBackground(for colorScheme: ColorScheme = .dark) -> Color {
        return Color(red: 30/255, green: 32/255, blue: 35/255).opacity(0.8)
    }
    
    static func primaryText(for colorScheme: ColorScheme = .dark) -> Color {
        return Color(red: 245/255, green: 245/255, blue: 247/255)
    }
    
    static func secondaryText(for colorScheme: ColorScheme = .dark) -> Color {
        return Color(red: 245/255, green: 245/255, blue: 247/255).opacity(0.6)
    }
}
