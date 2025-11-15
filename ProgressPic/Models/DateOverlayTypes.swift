import SwiftUI

// MARK: - Date Overlay Enums

enum DatePosition: String, CaseIterable {
    case topLeft = "Top Left"
    case topCenter = "Top Center"
    case topRight = "Top Right"
    case bottomLeft = "Bottom Left"
    case bottomCenter = "Bottom Center"
    case bottomRight = "Bottom Right"
}

enum DateFormat: String, CaseIterable {
    case classic = "Classic"
    case short = "Short"
    case medium = "Medium"
    case full = "Full"
    
    func format(_ date: Date) -> String {
        switch self {
        case .classic:
            return date.formatted(date: .abbreviated, time: .omitted)
        case .short:
            return date.formatted(.dateTime.month(.abbreviated).day())
        case .medium:
            return date.formatted(.dateTime.month(.wide).day().year())
        case .full:
            return date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
        }
    }
}

enum DateFont: String, CaseIterable {
    case system = "System"
    case rounded = "Rounded"
    case serif = "Serif"
    case mono = "Mono"
    
    var font: Font {
        switch self {
        case .system:
            return .system(.caption, design: .default, weight: .bold)
        case .rounded:
            return .system(.caption, design: .rounded, weight: .bold)
        case .serif:
            return .system(.caption, design: .serif, weight: .bold)
        case .mono:
            return .system(.caption, design: .monospaced, weight: .bold)
        }
    }
    
    func font(size: DateFontSize) -> Font {
        let uiSize: Font.TextStyle
        switch size {
        case .small:
            uiSize = .caption2
        case .medium:
            uiSize = .caption
        case .large:
            uiSize = .body
        case .extraLarge:
            uiSize = .title3
        }
        
        switch self {
        case .system:
            return .system(uiSize, design: .default, weight: .bold)
        case .rounded:
            return .system(uiSize, design: .rounded, weight: .bold)
        case .serif:
            return .system(uiSize, design: .serif, weight: .bold)
        case .mono:
            return .system(uiSize, design: .monospaced, weight: .bold)
        }
    }
}

enum DateFontSize: String, CaseIterable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case extraLarge = "Extra Large"
}
