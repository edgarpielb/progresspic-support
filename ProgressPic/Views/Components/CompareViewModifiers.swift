import SwiftUI

// MARK: - Photo Change Modifier
struct PhotoChangeModifier: ViewModifier {
    let left: ProgressPhoto?
    let right: ProgressPhoto?
    let mode: JourneyCompareView.CompareMode
    let fitImage: Bool
    let showDates: Bool
    let dateFormat: DateFormat
    let datePosition: DatePosition
    let dateFont: DateFont
    let dateFontSize: DateFontSize
    let dateColor: Color
    let showDateBackground: Bool
    let onCapture: () -> Void

    func body(content: Content) -> some View {
        content
            .modifier(PhotoChangeGroup1(
                leftId: left?.id,
                rightId: right?.id,
                mode: mode,
                fitImage: fitImage,
                onCapture: onCapture
            ))
            .modifier(DateChangeGroup(
                showDates: showDates,
                dateFormat: dateFormat,
                datePosition: datePosition,
                dateFont: dateFont,
                dateFontSize: dateFontSize,
                dateColor: dateColor,
                showDateBackground: showDateBackground,
                onCapture: onCapture
            ))
    }
}

struct PhotoChangeGroup1: ViewModifier {
    let leftId: UUID?
    let rightId: UUID?
    let mode: JourneyCompareView.CompareMode
    let fitImage: Bool
    let onCapture: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: leftId) { _, _ in onCapture() }
            .onChange(of: rightId) { _, _ in onCapture() }
            .onChange(of: mode) { _, _ in onCapture() }
            .onChange(of: fitImage) { _, _ in onCapture() }
    }
}

struct DateChangeGroup: ViewModifier {
    let showDates: Bool
    let dateFormat: DateFormat
    let datePosition: DatePosition
    let dateFont: DateFont
    let dateFontSize: DateFontSize
    let dateColor: Color
    let showDateBackground: Bool
    let onCapture: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: showDates) { _, _ in onCapture() }
            .onChange(of: dateFormat) { _, _ in onCapture() }
            .onChange(of: datePosition) { _, _ in onCapture() }
            .onChange(of: dateFont) { _, _ in onCapture() }
            .onChange(of: dateFontSize) { _, _ in onCapture() }
            .onChange(of: dateColor) { _, _ in onCapture() }
            .onChange(of: showDateBackground) { _, _ in onCapture() }
    }
}
