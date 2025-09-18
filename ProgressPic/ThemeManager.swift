import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    @Published var currentTheme: AppAppearance = .dark
    @Published var effectiveColorScheme: ColorScheme = .dark
    
    init() {
        // Always use dark mode
        currentTheme = .dark
        effectiveColorScheme = .dark
    }
}
