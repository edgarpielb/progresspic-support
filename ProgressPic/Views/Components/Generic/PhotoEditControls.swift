import SwiftUI

// MARK: - Helper Components for Photo Edit Controls

/// Compact icon-only button for photo edit controls
struct IconButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isActive ? AppStyle.Colors.accentPrimary : .white.opacity(0.7))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isActive ? AppStyle.Colors.accentPrimary.opacity(0.2) : Color.white.opacity(0.1))
                )
        }
    }
}

/// Expandable slider control for photo edit adjustments
struct SliderControl: View {
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 20)

            // Minus button
            Button(action: {
                let newValue = value - step
                if newValue >= range.lowerBound {
                    value = newValue
                }
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white.opacity(0.15)))
            }
            .disabled(value <= range.lowerBound)

            Slider(value: $value, in: range, step: step)
                .tint(AppStyle.Colors.accentPrimary)

            // Plus button
            Button(action: {
                let newValue = value + step
                if newValue <= range.upperBound {
                    value = newValue
                }
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white.opacity(0.15)))
            }
            .disabled(value >= range.upperBound)

            Text("\(Int(value))\(unit)")
                .font(.caption.monospacedDigit())
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 50, alignment: .trailing)
        }
    }
}
