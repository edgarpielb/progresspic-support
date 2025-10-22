import SwiftUI
import SwiftData
import Photos
import AVFoundation

// MARK: - Journey Watch Sheet
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
            ZStack {
                Color(red: 30/255, green: 32/255, blue: 35/255)
                    .ignoresSafeArea()

                JourneyWatchView(
                    journey: journey,
                    photos: photos,
                    isExporting: $isExporting,
                    exportProgress: $exportProgress,
                    exportedVideoURL: $exportedVideoURL
                )
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
                            .foregroundColor(.pink)
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

// MARK: - Journey Watch View
struct JourneyWatchView: View {
    let journey: Journey
    let photos: [ProgressPhoto]
    @Binding var isExporting: Bool
    @Binding var exportProgress: Double
    @Binding var exportedVideoURL: URL?

    @State private var isPlaying = false
    @State private var currentIndex = 0
    @State private var playbackSpeed: Double = 1.0
    
    // Customization options
    @State private var showDateOverlay = false
    @State private var datePosition: DatePosition = .bottomLeft
    @State private var dateFormat: DateFormat = .classic
    @State private var dateFont: DateFont = .system
    @State private var dateColor: Color = .white
    @State private var showWatermark = true
    @State private var reversePlayback = false
    @State private var useCrossfade = false
    @State private var activeSettingsPanel: SettingsPanel? = nil
    
    enum SettingsPanel: String {
        case speed, date, animation, watermark
    }
    
    enum DatePosition: String, CaseIterable {
        case topLeft = "Top Left"
        case topRight = "Top Right"
        case bottomLeft = "Bottom Left"
        case bottomRight = "Bottom Right"
    }
    
    enum DateFormat: String, CaseIterable {
        case classic = "Classic"
        case short = "Short"
        case medium = "Medium"
        case full = "Full"
        
        func format(_ date: Date) -> String {
            switch self {
            case .classic:
                return date.formatted(date: .abbreviated, time: .omitted)
            case .short:
                return date.formatted(.dateTime.month(.abbreviated).day())
            case .medium:
                return date.formatted(.dateTime.month(.wide).day().year())
            case .full:
                return date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
            }
        }
    }
    
    enum DateFont: String, CaseIterable {
        case system = "System"
        case rounded = "Rounded"
        case serif = "Serif"
        case mono = "Mono"
        
        var font: Font {
            switch self {
            case .system:
                return .system(.caption, design: .default, weight: .bold)
            case .rounded:
                return .system(.caption, design: .rounded, weight: .bold)
            case .serif:
                return .system(.caption, design: .serif, weight: .bold)
            case .mono:
                return .system(.caption, design: .monospaced, weight: .bold)
            }
        }
    }

    // Reverse photos to show oldest → newest (chronological order), excluding hidden
    private var chronologicalPhotos: [ProgressPhoto] {
        photos.filter { !$0.isHidden }.sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            if chronologicalPhotos.isEmpty {
                emptyState
            } else if chronologicalPhotos.count == 1 {
                singlePhotoState
            } else {
                normalState
            }

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onChange(of: isPlaying) { _, playing in
            if playing {
                startPlayback()
            }
        }
        .onChange(of: reversePlayback) { _, _ in
            // When changing direction, make sure we're within bounds
            if currentIndex >= chronologicalPhotos.count && !chronologicalPhotos.isEmpty {
                currentIndex = chronologicalPhotos.count - 1
            }
        }
        .onDisappear {
            isPlaying = false
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
        VStack(spacing: 8) {
            PhotoGridItem(photo: chronologicalPhotos[0])
                .frame(maxWidth: .infinity)
            
            Text("1 / 1 • \(chronologicalPhotos[0].date.formatted(date: .abbreviated, time: .omitted))")
                .font(AppStyle.FontStyle.caption)
                .foregroundColor(AppStyle.Colors.textSecondary)
            
            Text("Add more photos to create a slideshow")
                .font(AppStyle.FontStyle.caption)
                .foregroundColor(AppStyle.Colors.textTertiary)
        }
    }
    
    private var normalState: some View {
        VStack(spacing: 0) {
            // Main photo display with overlay play/pause button - pinned to top
            if currentIndex < chronologicalPhotos.count {
                let displayIndex = reversePlayback ? (chronologicalPhotos.count - 1 - currentIndex) : currentIndex
                let displayPhoto = chronologicalPhotos[displayIndex]

                ZStack(alignment: .bottomTrailing) {
                    // Photo display - instant or crossfade
                    PhotoGridItem(photo: displayPhoto)
                        .frame(maxWidth: .infinity)
                        .id(displayPhoto.id)
                        .transition(.opacity)
                        .animation(useCrossfade ? .easeInOut(duration: min(0.3, 0.8 / playbackSpeed)) : nil, value: displayPhoto.id)
                        .drawingGroup() // Optimize rendering
                    
                    // Date overlay
                    if showDateOverlay {
                        GeometryReader { geometry in
                            let dateText = dateFormat.format(displayPhoto.date)
                            let xPosition: CGFloat = {
                                switch datePosition {
                                case .topLeft, .bottomLeft:
                                    return 16
                                case .topRight, .bottomRight:
                                    return geometry.size.width - 16
                                }
                            }()
                            let yPosition: CGFloat = {
                                switch datePosition {
                                case .topLeft, .topRight:
                                    return 16
                                case .bottomLeft, .bottomRight:
                                    return geometry.size.height - 40
                                }
                            }()
                            
                            Text(dateText)
                                .font(dateFont.font)
                                .foregroundColor(dateColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.5))
                                )
                                .position(x: xPosition + (datePosition == .topRight || datePosition == .bottomRight ? -60 : 60), 
                                         y: yPosition)
                        }
                    }
                    
                    // Watermark
                    if showWatermark {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("ProgressPic")
                                    .font(.system(.caption2, design: .rounded, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                            }
                        }
                        .padding(12)
                    }

                    // Overlay play/pause button in bottom right corner
                    Button(action: {
                        isPlaying.toggle()
                    }) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 2)
                    }
                    .padding(16)
                    .accessibilityLabel(isPlaying ? "Pause slideshow" : "Play slideshow")
                    .accessibilityHint(isPlaying ? "Pause the slideshow" : "Play through all \(chronologicalPhotos.count) photos")
                }
            }

            // Controls section with padding
            VStack(spacing: 8) {
                // Position indicator: "1 / N • Date"
                let displayIdx = reversePlayback ? (chronologicalPhotos.count - 1 - currentIndex) : currentIndex
                Text("\(currentIndex + 1) / \(chronologicalPhotos.count) • \(chronologicalPhotos[displayIdx].date.formatted(date: .abbreviated, time: .omitted))")
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

            // Control icons
            HStack(spacing: 16) {
                // Speed control icon
                ControlIconButton(
                    icon: "speedometer",
                    label: "Speed",
                    isActive: activeSettingsPanel == .speed,
                    action: {
                        activeSettingsPanel = activeSettingsPanel == .speed ? nil : .speed
                    }
                )
                
                // Reverse playback toggle
                ControlIconButton(
                    icon: "arrow.uturn.backward",
                    label: "Reverse",
                    isActive: reversePlayback,
                    action: {
                        reversePlayback.toggle()
                        // Reset to appropriate index when toggling
                        if reversePlayback && currentIndex == chronologicalPhotos.count - 1 {
                            currentIndex = 0
                        } else if !reversePlayback && currentIndex == 0 {
                            currentIndex = chronologicalPhotos.count - 1
                        }
                    }
                )
                
                // Animation settings
                ControlIconButton(
                    icon: "wand.and.rays",
                    label: "Effects",
                    isActive: activeSettingsPanel == .animation,
                    action: {
                        activeSettingsPanel = activeSettingsPanel == .animation ? nil : .animation
                    }
                )
                
                // Date overlay settings
                ControlIconButton(
                    icon: "calendar.badge.clock",
                    label: "Date",
                    isActive: showDateOverlay || activeSettingsPanel == .date,
                    action: {
                        if !showDateOverlay {
                            showDateOverlay = true
                            activeSettingsPanel = .date
                        } else {
                            activeSettingsPanel = activeSettingsPanel == .date ? nil : .date
                        }
                    }
                )
                
                // Watermark toggle
                ControlIconButton(
                    icon: "drop.fill",
                    label: "Watermark",
                    isActive: showWatermark,
                    action: {
                        showWatermark.toggle()
                    }
                )
            }
            
            // Expandable settings panels
            if let panel = activeSettingsPanel {
                VStack(spacing: 10) {
                    switch panel {
                    case .speed:
                        speedSettingsPanel
                    case .date:
                        dateSettingsPanel
                    case .animation:
                        animationSettingsPanel
                    case .watermark:
                        EmptyView()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }

                // Export progress indicator (only shows when exporting)
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
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
    }
    
    // Settings panels
    private var speedSettingsPanel: some View {
        VStack(spacing: 6) {
            Text("Playback Speed")
                .font(AppStyle.FontStyle.caption)
                .foregroundColor(AppStyle.Colors.textSecondary)
            
            HStack(spacing: 6) {
                ForEach([0.5, 1.0, 2.0, 5.0, 10.0, 20.0], id: \.self) { speed in
                    Button(action: { playbackSpeed = speed }) {
                        Text(speed < 1.0 ? String(format: "%.1fx", speed) : "\(Int(speed))x")
                            .font(AppStyle.FontStyle.caption.bold())
                            .foregroundColor(playbackSpeed == speed ? AppStyle.Colors.accentCyan : AppStyle.Colors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(playbackSpeed == speed ? AppStyle.Colors.accentCyan.opacity(0.2) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(playbackSpeed == speed ? AppStyle.Colors.accentCyan : AppStyle.Colors.border, lineWidth: 1)
                                    )
                            )
                    }
                }
            }
        }
    }
    
    private var dateSettingsPanel: some View {
        VStack(spacing: 10) {
            // Date on/off toggle
            HStack {
                Text("Show Date")
                    .font(AppStyle.FontStyle.caption)
                    .foregroundColor(AppStyle.Colors.textSecondary)
                Spacer()
                Toggle("", isOn: $showDateOverlay)
                    .labelsHidden()
                    .tint(AppStyle.Colors.accentCyan)
                    .scaleEffect(0.8)
            }
            
            if showDateOverlay {
                // Position selector
                VStack(alignment: .leading, spacing: 4) {
                    Text("Position")
                        .font(AppStyle.FontStyle.caption)
                        .foregroundColor(AppStyle.Colors.textTertiary)
                    
                    HStack(spacing: 6) {
                        ForEach(DatePosition.allCases, id: \.self) { position in
                            Button(action: { datePosition = position }) {
                                Text(position.rawValue)
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundColor(datePosition == position ? .white : AppStyle.Colors.textSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(datePosition == position ? AppStyle.Colors.accentCyan : Color.white.opacity(0.08))
                                    )
                            }
                        }
                    }
                }
                
                // Format selector
                VStack(alignment: .leading, spacing: 4) {
                    Text("Format")
                        .font(AppStyle.FontStyle.caption)
                        .foregroundColor(AppStyle.Colors.textTertiary)
                    
                    HStack(spacing: 6) {
                        ForEach(DateFormat.allCases, id: \.self) { format in
                            Button(action: { dateFormat = format }) {
                                Text(format.rawValue)
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundColor(dateFormat == format ? .white : AppStyle.Colors.textSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(dateFormat == format ? AppStyle.Colors.accentCyan : Color.white.opacity(0.08))
                                    )
                            }
                        }
                    }
                }
                
                // Font selector
                VStack(alignment: .leading, spacing: 4) {
                    Text("Font")
                        .font(AppStyle.FontStyle.caption)
                        .foregroundColor(AppStyle.Colors.textTertiary)
                    
                    HStack(spacing: 6) {
                        ForEach(DateFont.allCases, id: \.self) { font in
                            Button(action: { dateFont = font }) {
                                Text(font.rawValue)
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundColor(dateFont == font ? .white : AppStyle.Colors.textSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(dateFont == font ? AppStyle.Colors.accentCyan : Color.white.opacity(0.08))
                                    )
                            }
                        }
                    }
                }
                
                // Color selector
                VStack(alignment: .leading, spacing: 4) {
                    Text("Color")
                        .font(AppStyle.FontStyle.caption)
                        .foregroundColor(AppStyle.Colors.textTertiary)
                    
                    HStack(spacing: 6) {
                        ForEach([Color.white, Color.black, Color.cyan, Color.pink, Color.yellow], id: \.self) { color in
                            Button(action: { dateColor = color }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Circle()
                                            .stroke(dateColor == color ? AppStyle.Colors.accentCyan : Color.white.opacity(0.2), lineWidth: 2)
                                    )
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var animationSettingsPanel: some View {
        VStack(spacing: 10) {
            // Crossfade toggle
            HStack {
                Text("Crossfade")
                    .font(AppStyle.FontStyle.caption)
                    .foregroundColor(AppStyle.Colors.textSecondary)
                Spacer()
                Toggle("", isOn: $useCrossfade)
                    .labelsHidden()
                    .tint(AppStyle.Colors.accentCyan)
                    .scaleEffect(0.8)
            }
            
            Text("More effects coming soon")
                .font(AppStyle.FontStyle.caption)
                .foregroundColor(AppStyle.Colors.textTertiary)
        }
    }
    
    private func startPlayback() {
        guard isPlaying && !chronologicalPhotos.isEmpty else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + (1.0 / playbackSpeed)) {
            if self.isPlaying {
                if self.reversePlayback {
                    // Reverse playback
                    if self.currentIndex < self.chronologicalPhotos.count - 1 {
                        self.currentIndex += 1
                    } else {
                        self.currentIndex = 0
                    }
                } else {
                    // Normal playback
                    if self.currentIndex < self.chronologicalPhotos.count - 1 {
                        self.currentIndex += 1
                    } else {
                        self.currentIndex = 0
                    }
                }
                self.startPlayback()
            }
        }
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
                    .font(.system(size: 17))
                    .foregroundColor(isActive ? AppStyle.Colors.accentCyan : AppStyle.Colors.textSecondary)

                Text(label)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(isActive ? AppStyle.Colors.accentCyan : AppStyle.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? AppStyle.Colors.accentCyan.opacity(0.15) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isActive ? AppStyle.Colors.accentCyan : Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
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
