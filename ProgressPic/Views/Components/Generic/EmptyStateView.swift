import SwiftUI

/// Reusable empty state view component
/// Eliminates ~60 lines of duplicated empty state UI across views
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String?
    let iconSize: CGFloat
    let spacing: CGFloat

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        iconSize: CGFloat = 48,
        spacing: CGFloat = 12
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.iconSize = iconSize
        self.spacing = spacing
    }

    var body: some View {
        VStack(spacing: spacing) {
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundColor(.white.opacity(0.3))

            Text(title)
                .font(.headline)
                .foregroundColor(.white)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle ?? "")")
    }
}

/// Loading state view component
struct LoadingStateView: View {
    let message: String?
    let scale: CGFloat

    init(message: String? = nil, scale: CGFloat = 1.0) {
        self.message = message
        self.scale = scale
    }

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.white)
                .scaleEffect(scale)

            if let message = message {
                Text(message)
                    .foregroundColor(.white.opacity(0.7))
                    .font(.subheadline)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message ?? "Loading")
    }
}

// MARK: - Previews

#Preview("Empty State") {
    ZStack {
        Color.black
            .ignoresSafeArea()

        EmptyStateView(
            icon: "photo.on.rectangle.angled",
            title: "No photos yet",
            subtitle: "Take your first photo to start your journey!",
            iconSize: 64
        )
    }
}

#Preview("Loading State") {
    ZStack {
        Color.black
            .ignoresSafeArea()

        LoadingStateView(message: "Loading photos...", scale: 1.2)
    }
}
