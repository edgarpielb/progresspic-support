import SwiftUI

// Reusable glass styles with proper dark backgrounds to prevent purple tint
struct GlassCard: ViewModifier {
    var corner: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Dark base layer to prevent purple tint
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(AppStyle.Colors.bgDark.opacity(0.8))
                    // Material blur on top
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.6)
            )
            .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
    }
}
struct GlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(
                ZStack {
                    // Dark base layer to prevent purple tint
                    Capsule()
                        .fill(AppStyle.Colors.bgDark.opacity(0.8))
                    // Material blur on top
                    Capsule()
                        .fill(.ultraThinMaterial)
                }
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.7)
            )
            .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
    }
}
struct GlassTile: ViewModifier {
    var corner: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Dark base layer to prevent purple tint
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(AppStyle.Colors.bgDark.opacity(0.8))
                    // Material blur on top
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
    }
}

extension View {
    func glassCard(corner: CGFloat = 20) -> some View { modifier(GlassCard(corner: corner)) }
    func glassCapsule() -> some View { modifier(GlassCapsule()) }
    func glassTile(corner: CGFloat = 16) -> some View { modifier(GlassTile(corner: corner)) }
}
