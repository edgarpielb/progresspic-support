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

// MARK: - Date Settings Sheet
struct DateSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var showDateOverlay: Bool
    @Binding var dateFormat: DateFormat
    @Binding var datePosition: DatePosition
    @Binding var dateFont: DateFont
    @Binding var dateFontSize: DateFontSize
    @Binding var dateColor: Color
    @Binding var showDateBackground: Bool
    
    @State private var showFormatPicker = false
    @State private var showFontPicker = false
    @State private var showColorPicker = false
    @State private var showPositionPicker = false
    @State private var showFontSizePicker = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppStyle.Colors.bgDark
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        if showDateOverlay {
                            // Main control buttons in 2x3 grid
                            VStack(spacing: 12) {
                                // First row
                                HStack(spacing: 12) {
                                    // Format button
                                    SettingButton(
                                        title: "Format",
                                        value: dateFormat.rawValue,
                                        iconType: .systemIcon("textformat"),
                                        action: { showFormatPicker = true }
                                    )
                                    
                                    // Font button
                                    SettingButton(
                                        title: "Font",
                                        value: dateFont.rawValue,
                                        iconType: .text("Aa", dateFont.font),
                                        action: { showFontPicker = true }
                                    )
                                    
                                    // Color button
                                    SettingButton(
                                        title: "Color",
                                        value: getColorName(dateColor),
                                        iconType: .colorCircle(dateColor),
                                        action: { showColorPicker = true }
                                    )
                                }
                                
                                // Second row
                                HStack(spacing: 12) {
                                    // Position button
                                    SettingButton(
                                        title: "Position",
                                        value: datePosition.rawValue,
                                        iconType: .systemIcon("square.grid.2x2"),
                                        action: { showPositionPicker = true }
                                    )
                                    
                                    // Background button
                                    SettingButton(
                                        title: "Background",
                                        value: showDateBackground ? "On" : "Off",
                                        iconType: .systemIcon("square.fill"),
                                        isSelected: showDateBackground,
                                        action: { showDateBackground.toggle() }
                                    )
                                    
                                    // Size button
                                    SettingButton(
                                        title: "Size",
                                        value: dateFontSize.rawValue,
                                        iconType: .systemIcon("textformat.size"),
                                        action: { showFontSizePicker = true }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            // Message when date is off
                            VStack(spacing: 16) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 48))
                                    .foregroundColor(AppStyle.Colors.textTertiary)
                                
                                Text("Date overlay is off")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("Toggle the switch above to enable date settings")
                                    .font(.subheadline)
                                    .foregroundColor(AppStyle.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        Text("Date")
                            .font(.headline)
                            .foregroundColor(.white)
                        Toggle("", isOn: $showDateOverlay)
                            .labelsHidden()
                            .tint(AppStyle.Colors.accentPrimary)
                            .scaleEffect(0.9)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppStyle.Colors.accentPrimary)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.fraction(0.4)])
        .sheet(isPresented: $showFormatPicker) {
            FormatPickerSheet(selectedFormat: $dateFormat)
        }
        .sheet(isPresented: $showFontPicker) {
            FontPickerSheet(selectedFont: $dateFont)
        }
        .sheet(isPresented: $showColorPicker) {
            ColorPickerSheet(selectedColor: $dateColor)
        }
        .sheet(isPresented: $showPositionPicker) {
            PositionPickerSheet(selectedPosition: $datePosition)
        }
        .sheet(isPresented: $showFontSizePicker) {
            FontSizePickerSheet(selectedSize: $dateFontSize)
        }
    }
    
    // Helper to get color name
    private func getColorName(_ color: Color) -> String {
        // Compare with known colors
        if color == .white { return "White" }
        if color == .black { return "Black" }
        if color == .pink { return "Pink" }
        if color == .yellow { return "Yellow" }
        if color == .red { return "Red" }
        if color == .orange { return "Orange" }
        if color == .green { return "Green" }
        if color == .blue { return "Blue" }
        if color == .purple { return "Purple" }
        
        // Check for cyan (custom color)
        let cyanColor = Color(red: 0.24, green: 0.85, blue: 0.80)
        if color.description == cyanColor.description {
            return "Cyan"
        }
        
        return "Custom"
    }
}

// MARK: - Helper Views
struct SettingButton: View {
    let title: String
    var value: String? = nil
    var iconType: IconType = .systemIcon("textformat")
    var isSelected: Bool = false
    let action: () -> Void
    
    enum IconType {
        case systemIcon(String)
        case colorCircle(Color)
        case text(String, Font?)
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Icon area - same height for all types
                ZStack {
                    switch iconType {
                    case .colorCircle(let color):
                        Circle()
                            .fill(color)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                    case .systemIcon(let name):
                        Image(systemName: name)
                            .font(.title3)
                            .foregroundColor(AppStyle.Colors.accentPrimary)
                    case .text(let text, let font):
                        Text(text)
                            .font(font ?? .title3)
                            .foregroundColor(AppStyle.Colors.accentPrimary)
                    }
                }
                .frame(height: 24)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(AppStyle.Colors.textSecondary)
                
                if let value = value {
                    Text(value)
                        .font(.caption2.bold())
                        .foregroundColor(AppStyle.Colors.accentPrimary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? AppStyle.Colors.accentPrimary : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct SettingRow: View {
    let title: String
    let value: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundColor(.white)
                Spacer()
                Text(value)
                    .font(.body)
                    .foregroundColor(AppStyle.Colors.accentPrimary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppStyle.Colors.textTertiary)
            }
            .padding()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Picker Sheets
struct FormatPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFormat: DateFormat
    
    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    
    var body: some View {
        NavigationView {
            ZStack {
                AppStyle.Colors.bgDark.ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(DateFormat.allCases, id: \.self) { format in
                            Button(action: {
                                selectedFormat = format
                                dismiss()
                            }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(format.rawValue)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(format.format(Date()))
                                        .font(.caption)
                                        .foregroundColor(AppStyle.Colors.textSecondary)
                                        .lineLimit(2)
                                    
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .frame(height: 100)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedFormat == format ? AppStyle.Colors.accentPrimary.opacity(0.2) : Color.white.opacity(0.06))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedFormat == format ? AppStyle.Colors.accentPrimary : Color.clear, lineWidth: 2)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
            }
            .navigationTitle("Date Format")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppStyle.Colors.accentPrimary)
                }
            }
        }
        .presentationDetents([.fraction(0.4)])
    }
}

struct ColorPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedColor: Color
    
    let colors: [(Color, String)] = [
        (.white, "White"),
        (.black, "Black"),
        (Color(red: 0.24, green: 0.85, blue: 0.80), "Cyan"),
        (.pink, "Pink"),
        (.yellow, "Yellow"),
        (.red, "Red"),
        (.orange, "Orange"),
        (.green, "Green"),
        (.blue, "Blue"),
        (.purple, "Purple")
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                AppStyle.Colors.bgDark.ignoresSafeArea()
                
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                        ForEach(colors, id: \.1) { color, name in
                            Button(action: {
                                selectedColor = color
                                dismiss()
                            }) {
                                VStack(spacing: 8) {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedColor == color ? AppStyle.Colors.accentPrimary : Color.white.opacity(0.2), lineWidth: 3)
                                        )
                                    
                                    Text(name)
                                        .font(.caption)
                                        .foregroundColor(selectedColor == color ? AppStyle.Colors.accentPrimary : AppStyle.Colors.textSecondary)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Date Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppStyle.Colors.accentPrimary)
                }
            }
        }
        .presentationDetents([.fraction(0.4)])
    }
}

struct FontPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFont: DateFont
    
    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    
    var body: some View {
        NavigationView {
            ZStack {
                AppStyle.Colors.bgDark.ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(DateFont.allCases, id: \.self) { font in
                            Button(action: {
                                selectedFont = font
                                dismiss()
                            }) {
                                VStack(spacing: 12) {
                                    Text("Aa")
                                        .font(font.font)
                                        .foregroundColor(.white)
                                        .font(.system(size: 32, weight: .bold))
                                    
                                    Text(font.rawValue)
                                        .font(.caption)
                                        .foregroundColor(AppStyle.Colors.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .frame(height: 120)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedFont == font ? AppStyle.Colors.accentPrimary.opacity(0.2) : Color.white.opacity(0.06))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedFont == font ? AppStyle.Colors.accentPrimary : Color.clear, lineWidth: 2)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
            }
            .navigationTitle("Date Font")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppStyle.Colors.accentPrimary)
                }
            }
        }
        .presentationDetents([.fraction(0.4)])
    }
}

struct PositionPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedPosition: DatePosition
    
    // Define the 2x3 grid layout
    let positions: [[DatePosition]] = [
        [.topLeft, .topCenter, .topRight],
        [.bottomLeft, .bottomCenter, .bottomRight]
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                AppStyle.Colors.bgDark.ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Visual grid
                    VStack(spacing: 30) {
                        ForEach(0..<positions.count, id: \.self) { row in
                            HStack(spacing: 40) {
                                ForEach(positions[row], id: \.self) { position in
                                    Button(action: {
                                        selectedPosition = position
                                        dismiss()
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(selectedPosition == position ? AppStyle.Colors.accentPrimary : Color.white.opacity(0.1))
                                                .frame(width: 60, height: 60)
                                            
                                            Circle()
                                                .stroke(selectedPosition == position ? AppStyle.Colors.accentPrimary : Color.white.opacity(0.3), lineWidth: 2)
                                                .frame(width: 60, height: 60)
                                            
                                            if selectedPosition == position {
                                                Image(systemName: "checkmark")
                                                    .font(.title3.bold())
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 40)
                    
                    // Position name below
                    Text(selectedPosition.rawValue)
                        .font(.headline)
                        .foregroundColor(AppStyle.Colors.accentPrimary)
                    
                    Spacer()
                }
            }
            .navigationTitle("Date Position")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppStyle.Colors.accentPrimary)
                }
            }
        }
        .presentationDetents([.fraction(0.4)])
    }
}

struct FontSizePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSize: DateFontSize
    
    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    
    var body: some View {
        NavigationView {
            ZStack {
                AppStyle.Colors.bgDark.ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(DateFontSize.allCases, id: \.self) { size in
                            Button(action: {
                                selectedSize = size
                                dismiss()
                            }) {
                                VStack(spacing: 12) {
                                    Text("Aa")
                                        .foregroundColor(.white)
                                        .font(getFontForPreview(size))
                                    
                                    Text(size.rawValue)
                                        .font(.caption)
                                        .foregroundColor(AppStyle.Colors.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .frame(height: 120)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedSize == size ? AppStyle.Colors.accentPrimary.opacity(0.2) : Color.white.opacity(0.06))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedSize == size ? AppStyle.Colors.accentPrimary : Color.clear, lineWidth: 2)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
            }
            .navigationTitle("Font Size")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppStyle.Colors.accentPrimary)
                }
            }
        }
        .presentationDetents([.fraction(0.4)])
    }
    
    private func getFontForPreview(_ size: DateFontSize) -> Font {
        switch size {
        case .small:
            return .system(size: 18, weight: .bold)
        case .medium:
            return .system(size: 24, weight: .bold)
        case .large:
            return .system(size: 32, weight: .bold)
        case .extraLarge:
            return .system(size: 40, weight: .bold)
        }
    }
}

