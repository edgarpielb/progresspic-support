import SwiftUI
import SwiftData

/// Sheet for comparing journey photos side-by-side with share functionality
struct JourneyCompareSheet: View {
    let journey: Journey
    let photos: [ProgressPhoto]
    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: UIImage?
    @State private var shareURL: URL?
    @State private var showShareSheet = false

    var body: some View {
        NavigationView {
            ZStack {
                AppStyle.Colors.bgDark
                    .ignoresSafeArea()

                JourneyCompareView(journey: journey, photos: photos, shareImage: $shareImage)
            }
            .navigationTitle("Compare Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        prepareShareImage()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .foregroundColor(AppStyle.Colors.accentPrimary)
                    }
                }
            }
            .sheet(item: $shareURL) { url in
                ShareSheet(url: url)
            }
        }
    }

    private func prepareShareImage() {
        guard let image = shareImage else { return }

        // Save image to temporary directory
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "comparison_\(Date().timeIntervalSince1970).jpg"
        let fileURL = tempDir.appendingPathComponent(fileName)

        if let imageData = image.jpegData(compressionQuality: 0.9) {
            try? imageData.write(to: fileURL)
            shareURL = fileURL
            showShareSheet = true
        }
    }
}
