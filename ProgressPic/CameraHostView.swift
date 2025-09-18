import SwiftUI
import SwiftData
import AVFoundation

struct CameraHostView: View {
    @StateObject private var camera = CameraService()
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Journey.createdAt, order: .reverse) private var journeys: [Journey]

    @State private var selectedJourney: Journey?
    @State private var ghostOpacity: Double = 0.32
    @State private var useFirst = false
    @State private var showAdjust = false
    @State private var lastGhost: UIImage?
    @State private var latestPhotoThumbnail: UIImage?
    @State private var showPhotoLibrary = false
    @State private var flashMode: AVCaptureDevice.FlashMode = .off
    @State private var timerSeconds = 0
    @State private var timerActive = false
    @State private var countdownSeconds = 0
    @State private var ghostEnabled = true
    @State private var showGhostControls = false
    @State private var showTimerControls = false

    @Query private var allPhotos: [ProgressPhoto]
    
    var photos: [ProgressPhoto] {
        guard let journeyId = selectedJourney?.id else { return [] }
        return allPhotos.filter { $0.journeyId == journeyId }
    }

    init(journey: Journey? = nil) {
        self.selectedJourney = journey
        _allPhotos = Query(sort: \ProgressPhoto.date, order: .forward)
    }

    var body: some View {
        ZStack {
            // Full screen camera preview
            if camera.isAuthorized {
                CameraPreviewLayerView(layer: $camera.previewLayer)
                    .ignoresSafeArea()

                // Ghost overlay (previous or first)
                if ghostEnabled, let img = lastGhost {
                    GeometryReader { geometry in
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .opacity(ghostOpacity)
                            .blendMode(.plusLighter)
                    }
                    .ignoresSafeArea()
                }
            } else {
                // Dark background when no camera access
                Color(red: 30/255, green: 32/255, blue: 35/255).ignoresSafeArea()
                
                // Camera permission not granted
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
            }

            // UI Overlay
            VStack(spacing: 0) {
                // Top section with journey selector
                HStack {
                    // Journey selector dropdown
                    Menu {
                        ForEach(journeys) { journey in
                            Button(journey.name) {
                                selectedJourney = journey
                                Task { await loadGhost() }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "folder")
                            Text(selectedJourney?.name ?? "Select Journey")
                            Image(systemName: "chevron.down")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    // Camera flip button
                    Button { camera.flip() } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                // Timer countdown overlay
                if timerActive && countdownSeconds > 0 {
                    VStack {
                        Spacer()
                        Text("\(countdownSeconds)")
                            .font(.system(size: 120, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 10)
                        Spacer()
                    }
                }
                
                // Ghost controls overlay (bottom-right)
                if showGhostControls && ghostEnabled {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ghostControlsView
                                .padding(.trailing, 24)
                                .padding(.bottom, 200)
                        }
                    }
                }
                
                // Timer controls overlay (compact, bottom-right)
                if showTimerControls {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            timerControlsView
                                .padding(.trailing, 24)
                                .padding(.bottom, 200)
                        }
                    }
                }
                
                // Bottom camera controls
                cameraControls
                    .padding(.bottom, 140) // Space for tab bar
            }
        }
        .onAppear {
            camera.start()
            if selectedJourney == nil, let firstJourney = journeys.first {
                selectedJourney = firstJourney
            }
            Task {
                _ = await PhotoStore.requestAuthorization()
                await loadGhost()
                await loadLatestThumbnail()
            }
        }
        .onDisappear { camera.stop() }
        .onChange(of: camera.isAuthorized) { _, ok in     // <- start when auth flips to true
            if ok { camera.start() }
        }
        .sheet(isPresented: $showAdjust) {
            if let latest = camera.latestPhoto {
                AdjustView(captured: latest, ghost: lastGhost, saveToCameraRoll: selectedJourney?.saveToCameraRoll ?? false, onSave: { savedId, transform in
                    if let journey = selectedJourney {
                        let date = PhotoStore.creationDate(for: savedId) ?? Date()
                        let p = ProgressPhoto(journeyId: journey.id, date: date, assetLocalId: savedId, isFrontCamera: camera.isFront, alignTransform: transform)
                        p.journey = journey  // Set the relationship
                        ctx.insert(p)
                        if journey.coverAssetLocalId == nil { journey.coverAssetLocalId = savedId }
                        Task { await loadLatestThumbnail() }
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
    }

    var cameraControls: some View {
        HStack {
            // Left: Photo thumbnail
            Button(action: {
                showPhotoLibrary = true
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    if let thumbnail = latestPhotoThumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipped()
                            .cornerRadius(8)
                    } else {
                        Image(systemName: "photo")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }
            }
            
            Spacer()
            
            // Center: Large capture button
            Button {
                if timerSeconds > 0 {
                    startTimerCapture()
                } else {
                    capturePhoto()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .strokeBorder(Color.black.opacity(0.1), lineWidth: 2)
                        .frame(width: 80, height: 80)
                }
            }
            .buttonStyle(.plain)
            .disabled(!camera.canCapture)
            .opacity(camera.canCapture ? 1 : 0.6)
            
            Spacer()
            
            // Right: Settings/Options
            VStack(spacing: 16) {
                // Ghost mode toggle button
                Button(action: {
                    toggleGhostMode()
                }) {
                    Image(systemName: ghostEnabled ? "eye.fill" : "eye")
                        .foregroundColor(ghostEnabled ? .cyan : .white)
                        .font(.title2)
                        .frame(width: 50, height: 50)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                
                // Timer button
                Button(action: {
                    showTimerControls.toggle()
                }) {
                    Image(systemName: timerActive ? "timer.circle.fill" : "timer")
                        .foregroundColor(timerActive ? .orange : .white)
                        .font(.title2)
                        .frame(width: 50, height: 50)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 30)
    }


    func loadGhost() async {
        guard selectedJourney != nil else { lastGhost = nil; return }
        if useFirst, let first = photos.first {
            lastGhost = await PhotoStore.fetchUIImage(localId: first.assetLocalId)
        } else if let last = photos.last {
            lastGhost = await PhotoStore.fetchUIImage(localId: last.assetLocalId)
        } else {
            lastGhost = nil
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
        flashMode = flashMode == .off ? .on : .off
        // Note: Flash control would need to be implemented in CameraService
        // For now, this just toggles the UI state
    }
    
    func toggleGhostMode() {
        print("👻 Ghost mode toggled: \(ghostEnabled) -> \(!ghostEnabled)")
        ghostEnabled.toggle()
        if ghostEnabled {
            showGhostControls = true
            Task { await loadGhost() }
            
            // Auto-hide controls after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if self.ghostEnabled {
                    self.showGhostControls = false
                }
            }
        } else {
            showGhostControls = false
            lastGhost = nil
        }
    }
    
    func capturePhoto() {
        print("📸 Capture button pressed")
        camera.capturePhoto()
        
        // Wait for photo to be captured before showing adjust view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.camera.latestPhoto != nil {
                print("✅ Photo captured, showing adjust view")
                self.showAdjust = true
            } else {
                print("⚠️ No photo captured, retrying...")
                // Retry after a bit more time
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if self.camera.latestPhoto != nil {
                        print("✅ Photo captured on retry, showing adjust view")
                        self.showAdjust = true
                    } else {
                        print("❌ Photo capture failed")
                    }
                }
            }
        }
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
        HStack(spacing: 10) {
            ForEach([0,3,5,10], id: \.self) { sec in
                Button {
                    timerSeconds = sec
                    showTimerControls = false
                } label: {
                    Text(sec == 0 ? "Off" : "\(sec)s")
                        .font(.caption.bold())
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(sec == timerSeconds ? Color.white.opacity(0.12) : Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(sec == timerSeconds ? Color.white.opacity(0.35) : Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .background(.ultraThinMaterial, in: Capsule())
    }
    
    var ghostControlsView: some View {
        HStack(spacing: 20) {
            // Ghost opacity slider
            HStack(spacing: 8) {
                Image(systemName: "eye.slash")
                    .foregroundColor(.white)
                Slider(value: $ghostOpacity, in: 0...1)
                    .frame(width: 120)
                    .accentColor(.cyan)
                Image(systemName: "eye.fill")
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            
            // First/Last toggle
            Button(action: {
                useFirst.toggle()
                Task { await loadGhost() }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: useFirst ? "1.circle.fill" : "arrow.clockwise")
                    Text(useFirst ? "First" : "Last")
                        .font(.caption.bold())
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
            }
        }
    }
}

struct CameraPreviewLayerView: UIViewRepresentable {
    @Binding var layer: AVCaptureVideoPreviewLayer?

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor(red: 30/255, green: 32/255, blue: 35/255, alpha: 1.0)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let previewLayer = layer else { return }

        // Remove any previous preview layer (but only those, and not if it's the same)
        uiView.layer.sublayers?.removeAll(where: {
            ($0 is AVCaptureVideoPreviewLayer) && ($0 !== previewLayer)
        })

        if previewLayer.superlayer !== uiView.layer {
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = uiView.bounds
            uiView.layer.addSublayer(previewLayer)
        } else {
            previewLayer.frame = uiView.bounds
        }
    }
}

// subtle “eyes/nose” crosshair + grid
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

