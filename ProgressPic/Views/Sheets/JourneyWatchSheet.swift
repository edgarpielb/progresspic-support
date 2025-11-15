import SwiftUI
import SwiftData
import Photos
import AVFoundation

/// Sheet for watching journey progress as a slideshow with video export
struct JourneyWatchSheet: View {
    let journey: Journey
    let photos: [ProgressPhoto]
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var exportedVideoURL: URL?

    // Reverse photos to show oldest → newest (chronological order), excluding hidden
    private var chronologicalPhotos: [ProgressPhoto] {
        photos.filter { !$0.isHidden }.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                AppStyle.Colors.bgDark
                    .ignoresSafeArea()

                JourneyWatchView(
                    journey: journey,
                    photos: photos,
                    isExporting: $isExporting,
                    exportProgress: $exportProgress,
                    exportedVideoURL: $exportedVideoURL
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle("Watch Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        Task {
                            await exportVideo()
                        }
                    }) {
                        if isExporting {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white)
                                .font(.title3)
                        }
                    }
                    .disabled(isExporting || chronologicalPhotos.count < 2)
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
        }
        .sheet(item: $exportedVideoURL) { url in
            if #available(iOS 16.0, *) {
                ShareSheet(url: url)
            }
        }
    }

    private func exportVideo() async {
        await MainActor.run {
            isExporting = true
            exportProgress = 0
        }

        // Capture needed data before detached task to avoid Sendable warnings
        let photosToExport = chronologicalPhotos
        let journeyName = journey.name

        // Run export on background queue
        let result = await Task.detached {
            return await VideoExporter.exportProgressVideo(
                photos: photosToExport,
                journeyName: journeyName,
                playbackSpeed: 1.0,
                progressCallback: { progress in
                    Task { @MainActor in
                        exportProgress = progress
                    }
                }
            )
        }.value

        await MainActor.run {
            isExporting = false
            if let url = result {
                exportedVideoURL = url
            }
        }
    }
}
