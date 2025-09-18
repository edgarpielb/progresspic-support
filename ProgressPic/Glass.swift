import SwiftUI

// Reusable glass styles
struct GlassCard: ViewModifier {
    var corner: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
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
            .background(.ultraThinMaterial, in: Capsule())
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
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
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
