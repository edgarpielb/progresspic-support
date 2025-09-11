import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    @Published var currentTheme: AppAppearance = .dark
    @Published var effectiveColorScheme: ColorScheme = .dark
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Load saved theme preference
        if let savedTheme = UserDefaults.standard.string(forKey: "app_theme"),
           let theme = AppAppearance(rawValue: savedTheme) {
            currentTheme = theme
        }
        
        // Update effective color scheme when theme changes
        $currentTheme
            .sink { [weak self] theme in
                self?.updateEffectiveColorScheme(for: theme)
                UserDefaults.standard.set(theme.rawValue, forKey: "app_theme")
            }
            .store(in: &cancellables)
        
        // Initial update
        updateEffectiveColorScheme(for: currentTheme)
    }
    
    private func updateEffectiveColorScheme(for theme: AppAppearance) {
        switch theme {
        case .light:
            effectiveColorScheme = .light
        case .dark:
            effectiveColorScheme = .dark
        case .system:
            // For system mode, effectiveColorScheme will be updated via updateForSystemAppearance
            // from the scene's environment. Default to dark until first environment update.
            break
        }
    }
    
    func updateForSystemAppearance(_ colorScheme: ColorScheme) {
        if currentTheme == .system {
            effectiveColorScheme = colorScheme
        }
    }
    
    /// Initialize system color scheme - called from the app's scene after environment is available
    func initializeSystemColorScheme(_ colorScheme: ColorScheme) {
        if currentTheme == .system {
            effectiveColorScheme = colorScheme
        }
    }
}
