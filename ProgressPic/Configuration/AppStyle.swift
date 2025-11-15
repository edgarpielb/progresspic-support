import SwiftUI

/// Centralized design tokens for ProgressPic
/// All colors, spacing, sizing, and styling constants in one place
enum AppStyle {
    
    // MARK: - Colors
    enum Colors {
        /// Main background color - dark gray
        static let bgDark = Color(red: 30/255, green: 32/255, blue: 35/255)

        /// Panel/card background - slightly lighter
        static let panel = Color.white.opacity(0.06)

        /// Panel with blur overlay
        static let panelOverlay = bgDark.opacity(0.8)

        /// Primary text - white
        static let textPrimary = Color.white

        /// Secondary text - light gray
        static let textSecondary = Color.white.opacity(0.7)

        /// Tertiary text - lighter gray
        static let textTertiary = Color.white.opacity(0.5)

        /// Accent color - cyan/white for highlights
        static let accent = Color.white

        /// Accent color - red for destructive actions
        static let accentRed = Color.red

        /// Accent color - cyan for selection
        static let accentCyan = Color.cyan

        /// Primary accent color - dynamically chosen based on user preference (cyan or pink)
        static var accentPrimary: Color {
            let profile = UserProfile.load()
            switch profile.colorScheme {
            case .cyan:
                return Color.cyan
            case .pink:
                return Color.pink
            case .none:
                return Color.pink // Default to pink for backwards compatibility
            }
        }

        /// Border color - subtle white
        static let border = Color.white.opacity(0.14)

        /// Border color - stronger
        static let borderStrong = Color.white.opacity(0.25)

        /// Glass overlay
        static let glassOverlay = bgDark.opacity(0.9)
    }
    
    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }
    
    // MARK: - Corner Radius
    enum Corner {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let capsule: CGFloat = 999
    }
    
    // MARK: - Icon Sizes
    enum IconSize {
        static let sm: CGFloat = 16
        static let md: CGFloat = 18
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
    
    // MARK: - Button Sizes
    enum ButtonSize {
        static let sm: CGFloat = 32
        static let md: CGFloat = 40
        static let lg: CGFloat = 48
        static let xl: CGFloat = 56
        static let shutter: CGFloat = 84
    }
    
    // MARK: - Font Styles
    enum FontStyle {
        static let caption = Font.caption
        static let caption2 = Font.caption2
        static let body = Font.body
        static let headline = Font.headline
        static let title3 = Font.title3
        static let title2 = Font.title2
        static let title = Font.title
        
        static let captionBold = Font.caption.bold()
        static let bodyBold = Font.body.bold()
        static let headlineBold = Font.headline.bold()
        static let title3Bold = Font.title3.bold()
    }
    
    // MARK: - Shadows
    enum Shadow {
        static let sm = (color: Color.black.opacity(0.2), radius: CGFloat(4), y: CGFloat(2))
        static let md = (color: Color.black.opacity(0.3), radius: CGFloat(10), y: CGFloat(6))
        static let lg = (color: Color.black.opacity(0.35), radius: CGFloat(18), y: CGFloat(10))
    }
}
