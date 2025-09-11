import SwiftUI

// MARK: - Theme Colors
struct ThemeColors {
    static func backgroundColor(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            return Color(red: 235/255, green: 235/255, blue: 240/255) // Darker gray background
        case .dark:
            return Color(red: 30/255, green: 32/255, blue: 35/255) // Current dark background
        @unknown default:
            return Color(red: 30/255, green: 32/255, blue: 35/255)
        }
    }
    
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            return Color(red: 220/255, green: 220/255, blue: 225/255) // Much darker gray instead of white
        case .dark:
            return Color(red: 30/255, green: 32/255, blue: 35/255).opacity(0.8)
        @unknown default:
            return Color(red: 30/255, green: 32/255, blue: 35/255).opacity(0.8)
        }
    }
    
    static func primaryText(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            return Color.black
        case .dark:
            return Color(red: 245/255, green: 245/255, blue: 247/255) // Light gray instead of white
        @unknown default:
            return Color(red: 245/255, green: 245/255, blue: 247/255)
        }
    }
    
    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            return Color.black.opacity(0.6)
        case .dark:
            return Color(red: 245/255, green: 245/255, blue: 247/255).opacity(0.6) // Light gray instead of white
        @unknown default:
            return Color(red: 245/255, green: 245/255, blue: 247/255).opacity(0.6)
        }
    }
}
