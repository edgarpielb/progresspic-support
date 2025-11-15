import SwiftUI

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
