import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case dark
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .dark: return "Dark"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        }
    }
}
