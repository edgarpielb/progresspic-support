import UIKit

/// Centralized haptic feedback utility
/// Provides a clean API for triggering haptic feedback throughout the app
enum HapticFeedback {

    /// Trigger an impact haptic feedback
    /// - Parameter style: The intensity of the impact (.light, .medium, .heavy, .soft, .rigid)
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    /// Trigger a notification haptic feedback
    /// - Parameter type: The type of notification (.success, .warning, .error)
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    /// Trigger a selection changed haptic feedback
    /// Use for UI elements like pickers and segmented controls
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    // Convenience methods for common scenarios
    static func success() {
        notification(.success)
    }

    static func error() {
        notification(.error)
    }

    static func warning() {
        notification(.warning)
    }

    static func light() {
        impact(.light)
    }

    static func medium() {
        impact(.medium)
    }

    static func heavy() {
        impact(.heavy)
    }
}
