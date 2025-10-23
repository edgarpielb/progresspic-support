import SwiftUI
import SwiftData
import AVFoundation

struct CameraHostView: View {
    @EnvironmentObject private var camera: CameraService
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Journey.createdAt, order: .reverse) private var journeys: [Journey]

    @State private var selectedJourney: Journey?
    @State private var ghostOpacity: Double = 0.32
    @State private var useFirst = false
    @State private var showAdjust = false
    @State private var lastGhost: UIImage?
    @State private var latestPhotoThumbnail: UIImage?
    @State private var showPhotoLibrary = false
    @State private var timerSeconds = 0
    @State private var timerActive = false
    @State private var countdownSeconds = 0
    @State private var ghostEnabled = false
    @State private var showGhostControls = false
    @State private var showTimerControls = false
    @State private var orientationObserver: NSObjectProtocol?
    @State private var ghostLoadTask: Task<Void, Never>?
    @State private var backgroundObserver: NSObjectProtocol?
    @State private var photos: [ProgressPhoto] = []
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var gridEnabled = false
    @State private var selectedZoomLevel: CGFloat = 1.0

    init(journey: Journey? = nil) {
        self._selectedJourney = State(initialValue: journey)
    }
    
    // MARK: - Properties
    
    private var zoomLevels: [CGFloat] {
        // Only show 0.5x if ultra-wide camera is available
        return camera.hasUltraWideCamera ? [0.5, 1.0, 2.0] : [1.0, 2.0]
    }
    
    // MARK: - Computed Views
    
    @ViewBuilder
    private var zoomControlsView: some View {
        if !camera.isFront {
            // Use HStack directly with proper alignment
            HStack(spacing: 15) {
                ForEach(zoomLevels, id: \.self) { level in
                    Button(action: { selectZoomLevel(level) }) {
                        Text(formatZoomLevel(level))
                            .font(.system(size: 14, weight: selectedZoomLevel == level ? .semibold : .regular))
                            .foregroundColor(selectedZoomLevel == level ? .yellow : .white.opacity(0.6))
                            .frame(width: 44, height: 44)  // Larger tap area
                            .contentShape(Rectangle())  // Make entire frame tappable
                            .scaleEffect(selectedZoomLevel == level ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedZoomLevel)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 15)
        }
    }
    
    private var cameraPreviewSection: some View {
        GeometryReader { geometry in
            let dimensions = calculateCameraDimensions(geometry: geometry)
            cameraPreviewContent(cropW: dimensions.width, cropH: dimensions.height, geometry: geometry)
        }
    }
    
    private func calculateCameraDimensions(geometry: GeometryProxy) -> (width: CGFloat, height: CGFloat) {
        // Fullscreen immersive view - use entire available space
        return (geometry.size.width, geometry.size.height)
    }
    
    @ViewBuilder
    private func cameraPreviewContent(cropW: CGFloat, cropH: CGFloat, geometry: GeometryProxy) -> some View {
        if camera.isAuthorized {
            // Fullscreen immersive camera view
            ZStack {
                // Camera preview - fullscreen
                CameraPreviewLayerView(layer: $camera.previewLayer, cameraService: camera)
                    .frame(width: cropW, height: cropH)
                    .clipped()

                // Ghost overlay (previous or first)
                if ghostEnabled, let img = lastGhost {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cropW, height: cropH)
                        .clipped()
                        .opacity(ghostOpacity)
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                }
                
                // Grid overlay
                if gridEnabled {
                    GridOverlay()
                        .frame(width: cropW, height: cropH)
                }
                
                // Timer countdown overlay
                if timerActive && countdownSeconds > 0 {
                    Text("\(countdownSeconds)")
                        .font(.system(size: 120, weight: .bold))
                        .foregroundColor(.yellow)
                        .shadow(color: .black.opacity(0.5), radius: 15, x: 0, y: 2)
                }
                
                // Overlaid ghost and timer controls on the left side
                HStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Spacer()
                        
                        // Ghost controls (when active) - on the left
                        if showGhostControls && ghostEnabled {
                            ghostControlsView
                        }
                        
                        // Timer controls (when active) - on the left
                        if showTimerControls {
                            timerControlsView
                        }
                    }
                    .padding(.leading, AppStyle.Spacing.lg)
                    .padding(.bottom, 200) // Position above bottom controls
                    
                    Spacer()
                }
                .frame(width: cropW, height: cropH)
            }
            .frame(width: cropW, height: cropH)
        } else {
            // Camera permission not granted - fullscreen
            VStack(spacing: 20) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.6))
                
                Text("Camera Access Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Please allow camera access in Settings to take progress photos.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button("Open Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.2))
                .cornerRadius(10)
            }
            .frame(width: cropW, height: cropH)
            .background(AppStyle.Colors.bgDark.opacity(0.8))
        }
    }

    var body: some View {
        ZStack {
            // Fullscreen camera preview
            cameraPreviewSection
                .ignoresSafeArea()
            
            // Overlaid UI elements
            VStack(spacing: 0) {
                // Top bar with journey selector (no time)
                HStack(spacing: AppStyle.Spacing.md) {
                    // Journey selector dropdown
                    Menu {
                        ForEach(journeys) { journey in
                            Button(journey.name) {
                                selectedJourney = journey
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "folder")
                                .font(.system(size: AppStyle.IconSize.md))
                            Text(selectedJourney?.name ?? "Select Journey")
                                .font(AppStyle.FontStyle.caption)
                            Image(systemName: "chevron.down")
                                .font(.system(size: AppStyle.IconSize.sm))
                        }
                        .foregroundColor(AppStyle.Colors.textPrimary)
                        .padding(.horizontal, AppStyle.Spacing.md)
                        .padding(.vertical, AppStyle.Spacing.sm)
                        .background(AppStyle.Colors.panelOverlay)
                        .cornerRadius(AppStyle.Corner.md)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, AppStyle.Spacing.lg)
                .padding(.top, AppStyle.Spacing.lg)
                
                Spacer()
            }
            
            // Right-side vertical tool icons at bottom (inside preview)
            HStack {
                Spacer()
                
                VStack(spacing: AppStyle.Spacing.md) {
                    Spacer()
                    
                    // Flash toggle
                    Button(action: { camera.cycleFlashMode() }) {
                        Image(systemName: camera.flashMode == .on ? "bolt.fill" : (camera.flashMode == .auto ? "bolt.badge.automatic" : "bolt.slash"))
                            .font(.system(size: AppStyle.IconSize.xl))
                            .foregroundColor(camera.flashMode == .off ? AppStyle.Colors.textPrimary : .yellow)
                            .frame(width: AppStyle.ButtonSize.lg, height: AppStyle.ButtonSize.lg)
                    }
                    
                    // Camera flip
                    Button(action: { camera.flip() }) {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: AppStyle.IconSize.xl))
                            .foregroundColor(AppStyle.Colors.textPrimary)
                            .frame(width: AppStyle.ButtonSize.lg, height: AppStyle.ButtonSize.lg)
                    }
                    
                    // Timer
                    Button(action: {
                        showTimerControls.toggle()
                        if showTimerControls { showGhostControls = false }
                    }) {
                        Image(systemName: "timer")
                            .font(.system(size: AppStyle.IconSize.xl))
                            .foregroundColor((timerSeconds > 0 || timerActive) ? .yellow : AppStyle.Colors.textPrimary)
                            .frame(width: AppStyle.ButtonSize.lg, height: AppStyle.ButtonSize.lg)
                    }
                    
                    // Grid toggle
                    Button(action: { gridEnabled.toggle() }) {
                        Image(systemName: gridEnabled ? "grid.circle.fill" : "grid")
                            .font(.system(size: AppStyle.IconSize.xl))
                            .foregroundColor(gridEnabled ? .white : AppStyle.Colors.textPrimary)
                            .frame(width: AppStyle.ButtonSize.lg, height: AppStyle.ButtonSize.lg)
                    }
                    
                    // Ghost overlay
                    Button(action: { toggleGhostMode() }) {
                        Image(systemName: ghostEnabled ? "eye.fill" : "eye")
                            .font(.system(size: AppStyle.IconSize.xl))
                            .foregroundColor(ghostEnabled ? AppStyle.Colors.accentPrimary : AppStyle.Colors.textPrimary)
                            .frame(width: AppStyle.ButtonSize.lg, height: AppStyle.ButtonSize.lg)
                    }
                }
                .padding(.trailing, AppStyle.Spacing.lg)
                .padding(.bottom, 120) // Position above shutter button
            }
            
            // Bottom center controls - shutter button and thumbnail (above tab bar)
            VStack {
                Spacer()
                
                // Zoom controls - only show for back camera
                zoomControlsView
                
                HStack(spacing: AppStyle.Spacing.xxxl) {
                    // Left: Thumbnail preview
                    if let thumbnail = latestPhotoThumbnail {
                        Button(action: { showPhotoLibrary = true }) {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: AppStyle.Corner.md))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppStyle.Corner.md)
                                        .stroke(AppStyle.Colors.textPrimary, lineWidth: 2)
                                )
                        }
                    } else {
                        // Placeholder
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 60, height: 60)
                    }
                    
                    // Center: Large shutter button
                    Button {
                        if timerSeconds > 0 {
                            startTimerCapture()
                        } else {
                            capturePhoto()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.5), lineWidth: 4)
                                .frame(width: AppStyle.ButtonSize.shutter, height: AppStyle.ButtonSize.shutter)
                            
                            Circle()
                                .fill(AppStyle.Colors.textPrimary)
                                .frame(width: 70, height: 70)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!camera.canCapture)
                    .opacity(camera.canCapture ? 1 : 0.6)
                    
                    // Right: Additional controls (placeholder for symmetry)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 60, height: 60)
                }
                .padding(.bottom, 30) // Right above tab bar
            }
        }
        .background(AppStyle.Colors.bgDark)
        .onAppear {
            print("👁️ CameraHostView appeared")

            // Initialize camera when view appears
            Task {
                // Setup journey first (sync, fast)
                if selectedJourney == nil, let firstJourney = journeys.first {
                    selectedJourney = firstJourney
                }
                fetchPhotosForSelectedJourney()

                // Request camera permission if needed (first time only)
                if !camera.isAuthorized {
                    print("🔐 Requesting camera permission...")
                    await camera.requestPermissionIfNeeded()
                }

                // Start camera session if authorized and not already running
                // This handles initial app launch on camera tab
                if camera.isAuthorized && !camera.session.isRunning {
                    print("▶️ Starting camera session on appear...")
                    camera.start()
                }

                // Load thumbnails (no permission needed for app directory)
                startLoadingGhost()
                await loadLatestThumbnail()
                
                // Initialize zoom button position and ensure 1x is selected
                if !camera.isFront {
                    selectedZoomLevel = 1.0
                }
            }
            
            // Observe device orientation changes
            orientationObserver = NotificationCenter.default.addObserver(
                forName: UIDevice.orientationDidChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    camera.updateOrientation()
                }
            }
            
            // Observe app going to background to free memory
            backgroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { _ in
                print("📱 App entered background, releasing ghost image")
                ghostLoadTask?.cancel()
                lastGhost = nil
            }
            
            // Observe memory warnings to clear cache
            NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: .main
            ) { _ in
                print("⚠️ Memory warning received, clearing image cache")
                PhotoStore.clearCache()
                // Also release ghost if not actively visible
                if !ghostEnabled {
                    lastGhost = nil
                }
            }
            
            // Observe zoom changes from pinch gesture
            NotificationCenter.default.addObserver(
                forName: Notification.Name("CameraZoomChanged"),
                object: nil,
                queue: .main
            ) { notification in
                if let zoom = notification.userInfo?["zoom"] as? CGFloat {
                    // Determine which zoom button to highlight based on actual zoom
                    let buttonToHighlight: CGFloat
                    if zoom < 0.75 {
                        buttonToHighlight = 0.5
                    } else if zoom < 1.5 {
                        buttonToHighlight = 1.0
                    } else {
                        buttonToHighlight = 2.0
                    }
                    
                    // Only update if it exists in our zoom levels
                    if zoomLevels.contains(buttonToHighlight) && selectedZoomLevel != buttonToHighlight {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedZoomLevel = buttonToHighlight
                        }
                    }
                }
            }
        }
        .onDisappear {
            print("👋 CameraHostView disappeared - clearing resources")

            // Cancel any ongoing ghost load
            ghostLoadTask?.cancel()
            ghostLoadTask = nil

            // Clear large images to free memory
            lastGhost = nil
            latestPhotoThumbnail = nil

            // Remove orientation observer
            if let observer = orientationObserver {
                NotificationCenter.default.removeObserver(observer)
                orientationObserver = nil
            }

            // Remove background observer
            if let observer = backgroundObserver {
                NotificationCenter.default.removeObserver(observer)
                backgroundObserver = nil
            }

            // Stop camera session when leaving camera view
            camera.stop()
        }
        .onChange(of: camera.isAuthorized) { _, ok in
            // Camera start is handled in onAppear task
            // This prevents duplicate start calls
            print("📹 Camera authorization changed: \(ok)")
        }
        .onChange(of: selectedJourney) { _, newJourney in
            // Fetch photos when journey changes - do it async to avoid blocking UI during menu interaction
            // This makes the Menu dismiss smoothly
            Task { @MainActor in
                // Small delay to let the menu dismiss animation complete
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

                // Fetch photos (must be on main actor for SwiftData)
                fetchPhotosForSelectedJourney()

                // Load ghost and thumbnail in background (these are already async)
                startLoadingGhost()
                await loadLatestThumbnail()
            }
        }
        .onChange(of: camera.isFront) { _, isFront in
            // Reset zoom when switching cameras
            if isFront {
                selectedZoomLevel = 1.0
                camera.setZoom(1.0)
            } else {
                // Initialize zoom controls position for back camera
                selectedZoomLevel = 1.0
                camera.setZoom(1.0)
            }
        }
        .onChange(of: camera.latestPhoto) { _, newPhoto in
            // Reactively show adjust view when photo is captured
            if newPhoto != nil {
                print("✅ Photo captured, showing adjust view")
                showAdjust = true
            }
        }
        .sheet(isPresented: $showAdjust) {
            if let latest = camera.latestPhoto {
                AdjustView(captured: latest, ghost: lastGhost, saveToCameraRoll: selectedJourney?.saveToCameraRoll ?? false, onSave: { savedId, transform, originalId in
                    if let journey = selectedJourney {
                        let date = PhotoStore.creationDate(for: savedId) ?? Date()
                        let p = ProgressPhoto(journeyId: journey.id, date: date, assetLocalId: savedId, isFrontCamera: camera.isFront, alignTransform: transform, originalAssetLocalId: originalId)
                        p.journey = journey  // Set the relationship
                        ctx.insert(p)
                        if journey.coverAssetLocalId == nil { journey.coverAssetLocalId = savedId }
                        
                        // Save context and handle errors
                        do {
                            try ctx.save()
                            print("✅ Photo saved to SwiftData")
                        } catch {
                            print("❌ Error saving photo: \(error)")
                            errorMessage = "Failed to save photo: \(error.localizedDescription)"
                            showErrorAlert = true
                        }
                        
                        // Refresh photos list to include new photo
                        fetchPhotosForSelectedJourney()
                        
                        // Clear latestPhoto to free memory and prepare for next capture
                        camera.latestPhoto = nil
                        print("🧹 Cleared latestPhoto after save")
                        
                        // Refresh ghost and thumbnail to show the newly captured photo
                        Task {
                            await loadLatestThumbnail()
                        }
                        startLoadingGhost()
                        print("🔄 Refreshed ghost and thumbnail after capture")
                    }
                })
            }
        }
        .sheet(isPresented: $showPhotoLibrary) {
            if let journey = selectedJourney {
                JourneyDetailView(journey: journey)
            } else {
                Text("Select a journey to view photos")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 30/255, green: 32/255, blue: 35/255))
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    /// Fetch photos for the currently selected journey using a scoped query
    /// This is more efficient than fetching all photos and filtering in memory
    func fetchPhotosForSelectedJourney() {
        guard let journeyId = selectedJourney?.id else {
            photos = []
            return
        }
        
        // Use a filtered fetch descriptor for efficient querying
        let descriptor = FetchDescriptor<ProgressPhoto>(
            predicate: #Predicate { $0.journeyId == journeyId },
            sortBy: [SortDescriptor(\ProgressPhoto.date, order: .forward)]
        )
        
        do {
            photos = try ctx.fetch(descriptor)
            print("📸 Fetched \(photos.count) photos for journey: \(selectedJourney?.name ?? "unknown")")
        } catch {
            print("❌ Error fetching photos: \(error)")
            photos = []
        }
    }
    
    func startLoadingGhost() {
        // Cancel any previous ghost loading task to prevent overlapping loads
        ghostLoadTask?.cancel()
        
        ghostLoadTask = Task {
            await loadGhost()
        }
    }
    
    func loadGhost() async {
        guard selectedJourney != nil else { 
            lastGhost = nil
            return 
        }
        
        // Calculate appropriate target size for ghost image (screen resolution)
        let screenSize = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        // Use actual pixel dimensions for better quality on retina displays
        let targetSize = CGSize(
            width: screenSize.width * scale,
            height: screenSize.height * scale
        )
        
        print("👻 Loading ghost image at target size: \(Int(targetSize.width))x\(Int(targetSize.height))")
        
        // Check if task was cancelled before loading
        guard !Task.isCancelled else {
            print("👻 Ghost load cancelled")
            return
        }
        
        if useFirst, let first = photos.first {
            lastGhost = await PhotoStore.fetchUIImage(localId: first.assetLocalId, targetSize: targetSize)
            print("👻 Loaded first photo as ghost")
        } else if let last = photos.last {
            lastGhost = await PhotoStore.fetchUIImage(localId: last.assetLocalId, targetSize: targetSize)
            print("👻 Loaded last photo as ghost")
        } else {
            lastGhost = nil
            print("👻 No photos available for ghost")
        }
    }
    
    func loadLatestThumbnail() async {
        if let latest = photos.last {
            latestPhotoThumbnail = await PhotoStore.fetchUIImage(localId: latest.assetLocalId, targetSize: CGSize(width: 100, height: 100))
        } else {
            latestPhotoThumbnail = nil
        }
    }
    
    func toggleFlash() {
        camera.flashMode = camera.flashMode == .off ? .on : .off
        print("💡 Flash toggled to: \(camera.flashMode == .on ? "ON" : "OFF")")
    }
    
    func toggleGhostMode() {
        print("👻 Ghost mode toggled: \(ghostEnabled) -> \(!ghostEnabled)")
        ghostEnabled.toggle()
        if ghostEnabled {
            showGhostControls = true
            showTimerControls = false // Close timer controls when opening ghost
            startLoadingGhost()
        } else {
            showGhostControls = false
            ghostLoadTask?.cancel()  // Cancel any ongoing ghost load
            lastGhost = nil
        }
    }
    
    func formatZoomLevel(_ level: CGFloat) -> String {
        if level == 1.0 {
            return "1×"
        } else if level < 1.0 {
            return String(format: "%.1f×", level)
        } else {
            return String(format: "%.0f×", level)
        }
    }
    
    func selectZoomLevel(_ level: CGFloat) {
        print("🎯 User selected zoom level: \(level)x")
        
        // Update UI immediately
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedZoomLevel = level
        }
        
        // Trigger camera zoom change
        camera.setZoom(level)
    }
    
    func capturePhoto() {
        print("📸 Capture button pressed")
        camera.capturePhoto()
        // Note: showAdjust will be triggered by onChange(of: camera.latestPhoto)
    }
    
    func startTimerCapture() {
        guard timerSeconds > 0 else {
            capturePhoto()
            return
        }
        
        timerActive = true
        countdownSeconds = timerSeconds
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            DispatchQueue.main.async {
                self.countdownSeconds -= 1
                if self.countdownSeconds <= 0 {
                    timer.invalidate()
                    self.timerActive = false
                    self.capturePhoto()
                }
            }
        }
    }
    
    var timerControlsView: some View {
        VStack(spacing: AppStyle.Spacing.md) {
            ForEach([0,3,5,10], id: \.self) { sec in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        timerSeconds = sec
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showTimerControls = false
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(sec == timerSeconds ? Color.yellow.opacity(0.15) : Color.black.opacity(0.25))
                            .frame(width: AppStyle.ButtonSize.lg, height: AppStyle.ButtonSize.lg)
                        
                        Circle()
                            .strokeBorder(sec == timerSeconds ? Color.yellow : Color.white.opacity(0.2), lineWidth: 1)
                            .frame(width: AppStyle.ButtonSize.lg, height: AppStyle.ButtonSize.lg)
                        
                        Text(sec == 0 ? "Off" : "\(sec)s")
                            .font(.system(size: 14, weight: sec == timerSeconds ? .semibold : .medium))
                            .foregroundColor(sec == timerSeconds ? Color.yellow : AppStyle.Colors.textPrimary)
                    }
                    .scaleEffect(sec == timerSeconds ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: timerSeconds)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    var ghostControlsView: some View {
        VStack(spacing: AppStyle.Spacing.md) {
            // Ghost opacity slider - vertical orientation
            VStack(spacing: 8) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 15))
                    .foregroundColor(AppStyle.Colors.textPrimary)
                Slider(value: $ghostOpacity, in: 0...1)
                    .frame(width: 140)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 30, height: 140)
                    .accentColor(AppStyle.Colors.accentPrimary)
                Image(systemName: "eye.slash")
                    .font(.system(size: 15))
                    .foregroundColor(AppStyle.Colors.textPrimary)
            }
            .padding(.vertical, AppStyle.Spacing.md)
            .padding(.horizontal, AppStyle.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppStyle.Corner.md)
                    .fill(Color.black.opacity(0.25))
            )
            
            // First/Last toggle
            Button(action: {
                useFirst.toggle()
                startLoadingGhost()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: useFirst ? "1.circle.fill" : "arrow.clockwise")
                        .font(.system(size: 16))
                    Text(useFirst ? "First" : "Last")
                        .font(AppStyle.FontStyle.caption)
                }
                .foregroundColor(AppStyle.Colors.textPrimary)
                .frame(width: 50)
                .padding(.vertical, AppStyle.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppStyle.Corner.md)
                        .fill(Color.black.opacity(0.25))
                )
            }
        }
    }
}

struct CameraPreviewLayerView: UIViewRepresentable {
    @Binding var layer: AVCaptureVideoPreviewLayer?
    @ObservedObject var cameraService: CameraService

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor(red: 30/255, green: 32/255, blue: 35/255, alpha: 1.0)
        
        // Add pinch gesture for native zoom
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        view.addGestureRecognizer(pinchGesture)
        
        return view
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(layer: $layer, cameraService: cameraService)
    }
    
    class Coordinator: NSObject {
        var layer: Binding<AVCaptureVideoPreviewLayer?>
        var cameraService: CameraService
        var initialZoom: CGFloat = 1.0
        
        init(layer: Binding<AVCaptureVideoPreviewLayer?>, cameraService: CameraService) {
            self.layer = layer
            self.cameraService = cameraService
        }
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let layer = layer.wrappedValue,
                  let device = layer.session?.inputs.compactMap({ ($0 as? AVCaptureDeviceInput)?.device }).first else {
                return
            }
            
            if gesture.state == .began {
                initialZoom = device.videoZoomFactor
            }
            
            do {
                try device.lockForConfiguration()
                
                let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 5.0)
                let newZoom = min(max(initialZoom * gesture.scale, 1.0), maxZoom)
                device.videoZoomFactor = newZoom
                
                device.unlockForConfiguration()
                
                // Update published zoom values and sync with parent view
                if gesture.state == .ended || gesture.state == .changed {
                    DispatchQueue.main.async {
                        self.cameraService.currentZoom = newZoom
                        self.cameraService.maxZoom = maxZoom
                        
                        // Update selected zoom level in parent view to sync the buttons
                        NotificationCenter.default.post(
                            name: Notification.Name("CameraZoomChanged"),
                            object: nil,
                            userInfo: ["zoom": newZoom]
                        )
                    }
                }
            } catch {
                print("❌ Zoom error: \(error)")
            }
        }
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let previewLayer = layer else {
            // Remove all preview layers if layer is nil
            uiView.layer.sublayers?.removeAll(where: { $0 is AVCaptureVideoPreviewLayer })
            return
        }

        // Only remove other preview layers, not the current one
        let layersToRemove = uiView.layer.sublayers?.filter {
            ($0 is AVCaptureVideoPreviewLayer) && ($0 !== previewLayer)
        } ?? []
        
        // Remove old layers only if there are any
        if !layersToRemove.isEmpty {
            print("🧹 Removing \(layersToRemove.count) old preview layer(s)")
            layersToRemove.forEach { $0.removeFromSuperlayer() }
        }

        // Add or update the preview layer
        if previewLayer.superlayer !== uiView.layer {
            print("➕ Adding preview layer to view hierarchy")
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = uiView.bounds
            uiView.layer.insertSublayer(previewLayer, at: 0) // Insert at bottom
        } else {
            // Just update the frame if already attached (happens on rotation/resize)
            if !previewLayer.frame.equalTo(uiView.bounds) {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}

// Grid overlay for camera view
struct GridOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { p in
                // Vertical lines
                for i in 1..<3 {
                    let x = w * CGFloat(i) / 3
                    p.move(to: .init(x: x, y: 0))
                    p.addLine(to: .init(x: x, y: h))
                }
                // Horizontal lines
                for i in 1..<3 {
                    let y = h * CGFloat(i) / 3
                    p.move(to: .init(x: 0, y: y))
                    p.addLine(to: .init(x: w, y: y))
                }
            }
            .stroke(Color.white.opacity(0.3), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

// subtle "eyes/nose" crosshair + grid
struct GuidelinesOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { p in
                p.move(to: .init(x: w/2, y: h*0.25)); p.addLine(to: .init(x: w/2, y: h*0.75))
                p.move(to: .init(x: w*0.2, y: h*0.5)); p.addLine(to: .init(x: w*0.8, y: h*0.5))
            }
            .stroke(Color.white.opacity(0.7), lineWidth: 2)

            Path { p in // grid
                for i in 1..<3 {
                    let x = w * CGFloat(i) / 3
                    let y = h * CGFloat(i) / 3
                    p.move(to: .init(x: x, y: 0)); p.addLine(to: .init(x: x, y: h))
                    p.move(to: .init(x: 0, y: y)); p.addLine(to: .init(x: w, y: y))
                }
            }
            .stroke(Color.white.opacity(0.15), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

