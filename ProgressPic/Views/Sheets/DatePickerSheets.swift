import SwiftUI

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

