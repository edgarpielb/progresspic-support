import SwiftUI
import SwiftData
import Photos
import AVFoundation
// MARK: - Preloaded Photo View
struct PreloadedPhotoView: View {
    let image: UIImage
    
    var body: some View {
        GeometryReader { geometry in
            let itemHeight = geometry.size.width * 5.0/4.0 // 4:5 ratio height
            
            // Image is already transformed when loaded from assetLocalId
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: itemHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .aspectRatio(4.0/5.0, contentMode: .fit)
    }
}

// MARK: - Control Icon Button
struct ControlIconButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isActive ? AppStyle.Colors.accentPrimary : AppStyle.Colors.textSecondary)

                Text(label)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(isActive ? AppStyle.Colors.accentPrimary : AppStyle.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? AppStyle.Colors.accentPrimary.opacity(0.15) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isActive ? AppStyle.Colors.accentPrimary : Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}
