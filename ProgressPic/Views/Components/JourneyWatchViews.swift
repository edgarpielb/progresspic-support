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
    
    // Image preloading
    @State private var preloadedImages: [String: UIImage] = [:]
    @State private var isPreloading = false
    @State private var preloadProgress: Double = 0
    
    // Customization options
    @State private var showDateOverlay = true
    @State private var datePosition: DatePosition = .bottomLeft
    @State private var dateFormat: DateFormat = .classic
    @State private var dateFont: DateFont = .system
    @State private var dateColor: Color = .white
    @State private var dateFontSize: DateFontSize = .medium
    @State private var showDateBackground = true
    @State private var showWatermark = true
    @State private var reversePlayback = false
    @State private var useCrossfade = false
    @State private var activeSettingsPanel: SettingsPanel? = nil
    
    // Sheet pickers
    @State private var showDateSheet = false
    @State private var showColorPicker = false
    @State private var showFontPicker = false
    @State private var showPositionPicker = false
    @State private var showFontSizePicker = false
    
    enum SettingsPanel: String {
        case speed, watermark
    }

    // Reverse photos to show oldest → newest (chronological order), excluding hidden
    private var chronologicalPhotos: [ProgressPhoto] {
        photos.filter { !$0.isHidden }.sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if chronologicalPhotos.isEmpty {
                    emptyState
                } else if chronologicalPhotos.count == 1 {
                    singlePhotoState
                } else {
                    normalState
                }
            }
            .padding(.top, 8)
        }
        .task {
            await preloadImages()
        }
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
        .sheet(isPresented: $showDateSheet) {
            DateSettingsSheet(
                showDateOverlay: $showDateOverlay,
                dateFormat: $dateFormat,
                datePosition: $datePosition,
                dateFont: $dateFont,
                dateFontSize: $dateFontSize,
                dateColor: $dateColor,
                showDateBackground: $showDateBackground
            )
        }
        .sheet(isPresented: $showColorPicker) {
            ColorPickerSheet(selectedColor: $dateColor)
        }
        .sheet(isPresented: $showFontPicker) {
            FontPickerSheet(selectedFont: $dateFont)
        }
        .sheet(isPresented: $showPositionPicker) {
            PositionPickerSheet(selectedPosition: $datePosition)
        }
        .sheet(isPresented: $showFontSizePicker) {
            FontSizePickerSheet(selectedSize: $dateFontSize)
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
            // Show loading state while preloading
            if isPreloading {
                VStack(spacing: 16) {
                    ProgressView(value: preloadProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(.cyan)
                        .frame(maxWidth: 300)
                    
                    Text("Loading photos...")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("\(Int(preloadProgress * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, minHeight: 400)
            } else if currentIndex < chronologicalPhotos.count {
                let displayIndex = reversePlayback ? (chronologicalPhotos.count - 1 - currentIndex) : currentIndex
                let displayPhoto = chronologicalPhotos[displayIndex]

                ZStack(alignment: .bottomTrailing) {
                    // Photo display using preloaded images
                    if let cachedImage = preloadedImages[displayPhoto.assetLocalId] {
                        PreloadedPhotoView(
                            image: cachedImage
                        )
                        .frame(maxWidth: .infinity)
                        .animation(useCrossfade ? .easeInOut(duration: min(0.3, 0.8 / playbackSpeed)) : nil, value: displayPhoto.id)
                    } else {
                        // Fallback if image isn't preloaded (shouldn't happen)
                        PhotoGridItem(photo: displayPhoto)
                            .frame(maxWidth: .infinity)
                    }
                    
                    // Date overlay
                    if showDateOverlay {
                        GeometryReader { geometry in
                            let dateText = dateFormat.format(displayPhoto.date)
                            let xPosition: CGFloat = {
                                switch datePosition {
                                case .topLeft, .bottomLeft:
                                    return 16
                                case .topCenter, .bottomCenter:
                                    return geometry.size.width / 2
                                case .topRight, .bottomRight:
                                    return geometry.size.width - 16
                                }
                            }()
                            let yPosition: CGFloat = {
                                switch datePosition {
                                case .topLeft, .topCenter, .topRight:
                                    return 40
                                case .bottomLeft, .bottomCenter, .bottomRight:
                                    return geometry.size.height - 40
                                }
                            }()
                            
                            let xOffset: CGFloat = {
                                switch datePosition {
                                case .topLeft, .bottomLeft:
                                    return 60  // Offset right from left edge
                                case .topCenter, .bottomCenter:
                                    return 0   // No offset for center
                                case .topRight, .bottomRight:
                                    return -60 // Offset left from right edge
                                }
                            }()
                            
                            Text(dateText)
                                .font(dateFont.font(size: dateFontSize))
                                .foregroundColor(dateColor)
                                .padding(.horizontal, showDateBackground ? 12 : 0)
                                .padding(.vertical, showDateBackground ? 6 : 0)
                                .background(
                                    Group {
                                        if showDateBackground {
                                            Capsule()
                                                .fill(Color.black.opacity(0.5))
                                        }
                                    }
                                )
                                .position(x: xPosition + xOffset, y: yPosition)
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
                .padding(.bottom, 20)
            }

            // Controls section with padding
            VStack(spacing: 20) {
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
            HStack(spacing: 8) {
                // Date overlay settings
                ControlIconButton(
                    icon: "calendar.badge.clock",
                    label: "Date",
                    isActive: showDateOverlay,
                    action: {
                        showDateOverlay = true
                        showDateSheet = true
                    }
                )
                
                // Speed control icon
                ControlIconButton(
                    icon: "speedometer",
                    label: "Speed",
                    isActive: activeSettingsPanel == .speed,
                    action: {
                        activeSettingsPanel = activeSettingsPanel == .speed ? nil : .speed
                    }
                )
                
                // Fade toggle
                ControlIconButton(
                    icon: "wand.and.rays",
                    label: "Fade",
                    isActive: useCrossfade,
                    action: {
                        useCrossfade.toggle()
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
                            .tint(AppStyle.Colors.accentPrimary)

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
        HStack(spacing: 6) {
            ForEach([0.5, 1.0, 2.0, 5.0, 10.0, 20.0], id: \.self) { speed in
                Button(action: { playbackSpeed = speed }) {
                    Text(speed < 1.0 ? String(format: "%.1fx", speed) : "\(Int(speed))x")
                        .font(AppStyle.FontStyle.caption.bold())
                        .foregroundColor(playbackSpeed == speed ? AppStyle.Colors.accentPrimary : AppStyle.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(playbackSpeed == speed ? AppStyle.Colors.accentPrimary.opacity(0.2) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(playbackSpeed == speed ? AppStyle.Colors.accentPrimary : AppStyle.Colors.border, lineWidth: 1)
                                )
                        )
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
                    .tint(AppStyle.Colors.accentPrimary)
                    .scaleEffect(0.8)
            }
            
            if showDateOverlay {
                // Format selector (keep inline as it's compact)
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
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(dateFormat == format ? AppStyle.Colors.accentPrimary : Color.white.opacity(0.08))
                                    )
                            }
                        }
                    }
                }
                
                // Position button - opens sheet
                Button(action: { showPositionPicker = true }) {
                    HStack {
                        Text("Position")
                            .font(AppStyle.FontStyle.body)
                            .foregroundColor(AppStyle.Colors.textSecondary)
                        Spacer()
                        Text(datePosition.rawValue)
                            .font(AppStyle.FontStyle.body)
                            .foregroundColor(AppStyle.Colors.accentPrimary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppStyle.Colors.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
                
                // Font button - opens sheet
                Button(action: { showFontPicker = true }) {
                    HStack {
                        Text("Font")
                            .font(AppStyle.FontStyle.body)
                            .foregroundColor(AppStyle.Colors.textSecondary)
                        Spacer()
                        Text(dateFont.rawValue)
                            .font(AppStyle.FontStyle.body)
                            .foregroundColor(AppStyle.Colors.accentPrimary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppStyle.Colors.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
                
                // Font Size button - opens sheet
                Button(action: { showFontSizePicker = true }) {
                    HStack {
                        Text("Font Size")
                            .font(AppStyle.FontStyle.body)
                            .foregroundColor(AppStyle.Colors.textSecondary)
                        Spacer()
                        Text(dateFontSize.rawValue)
                            .font(AppStyle.FontStyle.body)
                            .foregroundColor(AppStyle.Colors.accentPrimary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppStyle.Colors.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
                
                // Color button - opens sheet
                Button(action: { showColorPicker = true }) {
                    HStack {
                        Text("Color")
                            .font(AppStyle.FontStyle.body)
                            .foregroundColor(AppStyle.Colors.textSecondary)
                        Spacer()
                        Circle()
                            .fill(dateColor)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppStyle.Colors.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
                
                // Background toggle
                HStack {
                    Text("Show Background")
                        .font(AppStyle.FontStyle.body)
                        .foregroundColor(AppStyle.Colors.textSecondary)
                    Spacer()
                    Toggle("", isOn: $showDateBackground)
                        .labelsHidden()
                        .tint(AppStyle.Colors.accentPrimary)
                        .scaleEffect(0.8)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.06))
                )
            }
        }
    }
    
    private func preloadImages() async {
        guard !chronologicalPhotos.isEmpty else { return }

        await MainActor.run {
            isPreloading = true
            preloadProgress = 0
        }

        let totalPhotos = chronologicalPhotos.count
        var loadedImages: [String: UIImage] = [:]

        for (index, photo) in chronologicalPhotos.enumerated() {
            // Always load from assetLocalId for display (already transformed)
            if let image = await PhotoStore.fetchUIImage(localId: photo.assetLocalId, targetSize: CGSize(width: 2400, height: 2400)) {
                loadedImages[photo.assetLocalId] = image
                print("📸 Loaded image for watch view")
            }

            let progress = Double(index + 1) / Double(totalPhotos)
            await MainActor.run {
                preloadProgress = progress
            }
        }

        await MainActor.run {
            preloadedImages = loadedImages
            isPreloading = false
            print("✅ Preloaded \(loadedImages.count) images for watch view")
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

