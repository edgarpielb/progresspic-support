import SwiftUI
import SwiftData
import Photos
import AVFoundation

// MARK: - Journey Watch Sheet
struct JourneyWatchSheet: View {
    let journey: Journey
    let photos: [ProgressPhoto]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 30/255, green: 32/255, blue: 35/255)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: 24)

                    JourneyWatchView(journey: journey, photos: photos)
                        .padding()
                }
            }
            .navigationTitle("Watch Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

// MARK: - Journey Watch View
struct JourneyWatchView: View {
    let journey: Journey
    let photos: [ProgressPhoto]
    @State private var isPlaying = false
    @State private var currentIndex = 0
    @State private var playbackSpeed: Double = 1.0
    @State private var showExportSheet = false
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var exportedVideoURL: URL?
    
    // Reverse photos to show oldest → newest (chronological order), excluding hidden
    private var chronologicalPhotos: [ProgressPhoto] {
        photos.filter { !$0.isHidden }.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        VStack(spacing: AppStyle.Spacing.lg) {
            if chronologicalPhotos.isEmpty {
                emptyState
            } else if chronologicalPhotos.count == 1 {
                singlePhotoState
            } else {
                normalState
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                startPlayback()
            }
        }
        .onDisappear {
            isPlaying = false
        }
        .sheet(item: $exportedVideoURL) { url in
            if #available(iOS 16.0, *) {
                ShareSheet(url: url)
            }
        }
    }
    
    private var emptyState: some View {
        RoundedRectangle(cornerRadius: AppStyle.Corner.xl)
            .fill(AppStyle.Colors.panel)
            .frame(height: 200)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "play.rectangle")
                        .font(.title2)
                        .foregroundColor(AppStyle.Colors.textTertiary)
                    Text("Add photos to watch your progress")
                        .font(AppStyle.FontStyle.body)
                        .foregroundColor(AppStyle.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            )
    }
    
    private var singlePhotoState: some View {
        VStack(spacing: AppStyle.Spacing.lg) {
            PhotoGridItem(photo: chronologicalPhotos[0])
                .frame(maxWidth: .infinity)
                .frame(height: 500)
                .glassCard()
            
            Text("1 / 1 • \(chronologicalPhotos[0].date.formatted(date: .abbreviated, time: .omitted))")
                .font(AppStyle.FontStyle.caption)
                .foregroundColor(AppStyle.Colors.textSecondary)
            
            Text("Add more photos to create a slideshow")
                .font(AppStyle.FontStyle.caption)
                .foregroundColor(AppStyle.Colors.textTertiary)
        }
    }
    
    private var normalState: some View {
        VStack(spacing: AppStyle.Spacing.lg) {
            // Main photo display with overlay play button
            if currentIndex < chronologicalPhotos.count {
                ZStack {
                    PhotoGridItem(photo: chronologicalPhotos[currentIndex])
                        .frame(maxWidth: .infinity)
                        .glassCard()

                    // Overlay play button on the image (only when not playing)
                    if !isPlaying {
                        Button(action: {
                            isPlaying = true
                        }) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 2)
                        }
                        .accessibilityLabel("Play slideshow")
                        .accessibilityHint("Play through all \(chronologicalPhotos.count) photos from oldest to newest")
                    }
                }
            }

            // Position indicator: "1 / N • Date"
            Text("\(currentIndex + 1) / \(chronologicalPhotos.count) • \(chronologicalPhotos[currentIndex].date.formatted(date: .abbreviated, time: .omitted))")
                .font(AppStyle.FontStyle.caption)
                .foregroundColor(AppStyle.Colors.textSecondary)
            
            // Scrubber slider with skip buttons
            HStack(spacing: 12) {
                // Previous button
                Button(action: {
                    isPlaying = false  // Stop playback when manually navigating
                    if currentIndex > 0 {
                        currentIndex -= 1
                    }
                }) {
                    Image(systemName: "arrowtriangle.left.fill")
                        .font(.title3)
                        .foregroundColor(currentIndex == 0 ? AppStyle.Colors.textTertiary : AppStyle.Colors.textPrimary)
                        .frame(width: 30)
                }
                .disabled(currentIndex == 0)
                .accessibilityLabel("Previous photo")
                .accessibilityHint("Go to the previous photo in the slideshow")

                Text("1")
                    .font(AppStyle.FontStyle.caption)
                    .foregroundColor(AppStyle.Colors.textSecondary)
                    .frame(width: 20)

                Slider(value: Binding(
                    get: { Double(currentIndex) },
                    set: { newValue in
                        isPlaying = false  // Stop playback when manually scrubbing
                        currentIndex = Int(newValue)
                    }
                ), in: 0...Double(max(0, chronologicalPhotos.count - 1)), step: 1)
                .tint(AppStyle.Colors.accent)

                Text("\(chronologicalPhotos.count)")
                    .font(AppStyle.FontStyle.caption)
                    .foregroundColor(AppStyle.Colors.textSecondary)
                    .frame(width: 30, alignment: .trailing)

                // Next button
                Button(action: {
                    isPlaying = false  // Stop playback when manually navigating
                    if currentIndex < chronologicalPhotos.count - 1 {
                        currentIndex += 1
                    }
                }) {
                    Image(systemName: "arrowtriangle.right.fill")
                        .font(.title3)
                        .foregroundColor(currentIndex >= chronologicalPhotos.count - 1 ? AppStyle.Colors.textTertiary : AppStyle.Colors.textPrimary)
                        .frame(width: 30)
                }
                .disabled(currentIndex >= chronologicalPhotos.count - 1)
                .accessibilityLabel("Next photo")
                .accessibilityHint("Go to the next photo in the slideshow")
            }
            .padding(.horizontal)

            // Speed control
            VStack(spacing: 8) {
                Text("Playback Speed")
                    .font(AppStyle.FontStyle.caption)
                    .foregroundColor(AppStyle.Colors.textSecondary)

                HStack(spacing: 12) {
                    Button(action: { playbackSpeed = 0.5 }) {
                        Text("0.5x")
                            .font(AppStyle.FontStyle.caption.bold())
                            .foregroundColor(playbackSpeed == 0.5 ? AppStyle.Colors.accentCyan : AppStyle.Colors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(playbackSpeed == 0.5 ? AppStyle.Colors.accentCyan.opacity(0.2) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(playbackSpeed == 0.5 ? AppStyle.Colors.accentCyan : AppStyle.Colors.border, lineWidth: 1)
                                    )
                            )
                    }

                    Button(action: { playbackSpeed = 1.0 }) {
                        Text("1x")
                            .font(AppStyle.FontStyle.caption.bold())
                            .foregroundColor(playbackSpeed == 1.0 ? AppStyle.Colors.accentCyan : AppStyle.Colors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(playbackSpeed == 1.0 ? AppStyle.Colors.accentCyan.opacity(0.2) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(playbackSpeed == 1.0 ? AppStyle.Colors.accentCyan : AppStyle.Colors.border, lineWidth: 1)
                                    )
                            )
                    }

                    Button(action: { playbackSpeed = 2.0 }) {
                        Text("2x")
                            .font(AppStyle.FontStyle.caption.bold())
                            .foregroundColor(playbackSpeed == 2.0 ? AppStyle.Colors.accentCyan : AppStyle.Colors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(playbackSpeed == 2.0 ? AppStyle.Colors.accentCyan.opacity(0.2) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(playbackSpeed == 2.0 ? AppStyle.Colors.accentCyan : AppStyle.Colors.border, lineWidth: 1)
                                    )
                            )
                    }

                    Button(action: { playbackSpeed = 5.0 }) {
                        Text("5x")
                            .font(AppStyle.FontStyle.caption.bold())
                            .foregroundColor(playbackSpeed == 5.0 ? AppStyle.Colors.accentCyan : AppStyle.Colors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(playbackSpeed == 5.0 ? AppStyle.Colors.accentCyan.opacity(0.2) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(playbackSpeed == 5.0 ? AppStyle.Colors.accentCyan : AppStyle.Colors.border, lineWidth: 1)
                                    )
                            )
                    }

                    Button(action: { playbackSpeed = 10.0 }) {
                        Text("10x")
                            .font(AppStyle.FontStyle.caption.bold())
                            .foregroundColor(playbackSpeed == 10.0 ? AppStyle.Colors.accentCyan : AppStyle.Colors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(playbackSpeed == 10.0 ? AppStyle.Colors.accentCyan.opacity(0.2) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(playbackSpeed == 10.0 ? AppStyle.Colors.accentCyan : AppStyle.Colors.border, lineWidth: 1)
                                    )
                            )
                    }
                }
            }
            .padding(.horizontal)

            // Export button
            if isExporting {
                VStack(spacing: 8) {
                    ProgressView(value: exportProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(AppStyle.Colors.accentCyan)
                    
                    Text("Exporting: \(Int(exportProgress * 100))%")
                        .font(AppStyle.FontStyle.caption)
                        .foregroundColor(AppStyle.Colors.textSecondary)
                }
                .padding()
                .glassCard()
            } else {
                Button(action: {
                    Task {
                        await exportVideo()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: AppStyle.IconSize.lg))
                        Text("Export Video")
                            .font(AppStyle.FontStyle.headline)
                    }
                    .foregroundColor(AppStyle.Colors.textPrimary)
                    .padding(.horizontal, AppStyle.Spacing.xl)
                    .padding(.vertical, AppStyle.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppStyle.Corner.lg)
                            .fill(AppStyle.Colors.panel)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppStyle.Corner.lg)
                                    .stroke(AppStyle.Colors.border, lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func startPlayback() {
        guard isPlaying && !chronologicalPhotos.isEmpty else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + (1.0 / playbackSpeed)) {
            if self.isPlaying {
                if self.currentIndex < self.chronologicalPhotos.count - 1 {
                    self.currentIndex += 1
                    self.startPlayback()
                } else {
                    // Loop back to start
                    self.currentIndex = 0
                    self.startPlayback()
                }
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
        let speed = playbackSpeed

        // Run export on background queue
        let result = await Task.detached {
            return await VideoExporter.exportProgressVideo(
                photos: photosToExport,
                journeyName: journeyName,
                playbackSpeed: speed,
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

// MARK: - Video Exporter
actor VideoExporter {
    static func exportProgressVideo(
        photos: [ProgressPhoto],
        journeyName: String,
        playbackSpeed: Double = 1.0,
        progressCallback: @escaping (Double) -> Void
    ) async -> URL? {
        guard !photos.isEmpty else { return nil }

        // Configuration
        let fps = 30
        let frameDuration: Double = 1.0 / playbackSpeed  // Duration per photo based on speed
        let framesPerPhoto = Int(frameDuration * Double(fps))
        let resolution = CGSize(width: 1080, height: 1350)  // 4:5 aspect ratio
        
        // Create temp file
        let tempDir = FileManager.default.temporaryDirectory
        let timestamp = Date().timeIntervalSince1970
        let outputURL = tempDir.appendingPathComponent("progress_\(journeyName)_\(Int(timestamp)).mp4")
        
        // Remove if exists
        try? FileManager.default.removeItem(at: outputURL)
        
        guard let videoWriter = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            return nil
        }
        
        // Video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: resolution.width,
            AVVideoHeightKey: resolution.height
        ]
        
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: resolution.width,
                kCVPixelBufferHeightKey as String: resolution.height
            ]
        )
        
        guard videoWriter.canAdd(videoInput) else { return nil }
        videoWriter.add(videoInput)
        
        guard videoWriter.startWriting() else { return nil }
        videoWriter.startSession(atSourceTime: .zero)
        
        var frameCount = 0
        let totalFrames = photos.count * framesPerPhoto
        
        // Write frames
        for photo in photos {
            // Load image downsampled to target resolution
            guard let image = await PhotoStore.fetchUIImage(localId: photo.assetLocalId, targetSize: resolution) else {
                continue
            }
            
            // Render this image for the required number of frames
            for _ in 0..<framesPerPhoto {
                while !videoInput.isReadyForMoreMediaData {
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
                
                let presentationTime = CMTime(value: Int64(frameCount), timescale: Int32(fps))
                
                if let pixelBuffer = createPixelBuffer(from: image, size: resolution) {
                    adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                }
                
                frameCount += 1
                
                // Update progress
                let progress = Double(frameCount) / Double(totalFrames)
                progressCallback(progress)
            }
        }
        
        videoInput.markAsFinished()
        await videoWriter.finishWriting()
        
        return videoWriter.status == .completed ? outputURL : nil
    }
    
    private static func createPixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        
        guard let ctx = context, let cgImage = image.cgImage else {
            return nil
        }
        
        // Fill background
        ctx.setFillColor(UIColor(red: 30/255, green: 32/255, blue: 35/255, alpha: 1.0).cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        
        // Calculate letterbox rect
        let imageAspect = image.size.width / image.size.height
        let targetAspect = size.width / size.height
        
        let drawRect: CGRect
        if imageAspect > targetAspect {
            // Image is wider - fit width
            let height = size.width / imageAspect
            drawRect = CGRect(x: 0, y: (size.height - height) / 2, width: size.width, height: height)
        } else {
            // Image is taller - fit height
            let width = size.height * imageAspect
            drawRect = CGRect(x: (size.width - width) / 2, y: 0, width: width, height: size.height)
        }
        
        ctx.draw(cgImage, in: drawRect)
        
        return buffer
    }
}
