import SwiftUI
import SwiftData
import AVFoundation

struct CameraHostView: View {
    @StateObject private var camera = CameraService()
    @Environment(\.modelContext) private var ctx
    @EnvironmentObject private var themeManager: ThemeManager

    var journey: Journey?   // nil on "Camera" tab (quick capture without binding to a journey)

    @Query private var photos: [ProgressPhoto]
    @State private var ghostOpacity: Double = 0.32
    @State private var useFirst = false
    @State private var showAdjust = false
    @State private var lastGhost: UIImage?

    init(journey: Journey? = nil) {
        self.journey = journey
        if let journey = journey {
            let journeyId = journey.id
            _photos = Query(filter: #Predicate<ProgressPhoto> { $0.journeyId == journeyId },
                            sort: \ProgressPhoto.date, order: .forward)
        } else {
            _photos = Query()
        }
    }

    var body: some View {
        ZStack {
            // Dark background
            Color(red: 30/255, green: 32/255, blue: 35/255)
                .ignoresSafeArea()
            
            if camera.isAuthorized {
                CameraPreviewLayerView(layer: $camera.previewLayer)
                    .ignoresSafeArea()

                // Ghost overlay (previous or first)
                if let img = lastGhost {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .opacity(ghostOpacity)
                        .blendMode(.plusLighter)
                        .ignoresSafeArea()
                }

                // Guidelines
                GuidelinesOverlay()
            } else {
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

            if camera.isAuthorized {
                VStack {
                    HStack {
                        Spacer()
                        Button { camera.flip() } label: { Image(systemName: "camera.rotate").font(.title3) }
                            .padding(10).background(.ultraThinMaterial, in: Circle())
                            .padding(.trailing, 16).padding(.top, 20)
                    }
                    Spacer()
                    bottomBar
                }
            }
        }
        .onAppear {
            camera.start()
            Task { await loadGhost() }
        }
        .onDisappear { camera.stop() }
        .sheet(isPresented: $showAdjust) {
            if let latest = camera.latestPhoto {
                AdjustView(captured: latest, ghost: lastGhost, onSave: { savedId, transform in
                    if let journey {
                        let date = PhotoStore.creationDate(for: savedId) ?? Date()
                        let p = ProgressPhoto(journeyId: journey.id, date: date, assetLocalId: savedId, isFrontCamera: camera.isFront, alignTransform: transform)
                        ctx.insert(p)
                        if journey.coverAssetLocalId == nil { journey.coverAssetLocalId = savedId }
                    }
                })
            }
        }
    }

    var bottomBar: some View {
        HStack(spacing: 18) {
            Button { useFirst.toggle(); Task { await loadGhost() } } label: {
                Text(useFirst ? "1st" : "Last").font(.subheadline.bold())
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            Spacer()
            Button {
                camera.capturePhoto()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { showAdjust = true }
            } label: {
                Circle().strokeBorder(.white, lineWidth: 6).frame(width: 84, height: 84)
            }
            Spacer()
            HStack {
                Image(systemName: "ghost").font(.subheadline.bold())
                Slider(value: $ghostOpacity, in: 0...1)
                    .frame(width: 140)
            }
            .padding(8)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 120) // Space for custom tab bar
        .navigationTitle("Camera")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    func loadGhost() async {
        guard journey != nil else { lastGhost = nil; return }
        if useFirst, let first = photos.first {
            lastGhost = await PhotoStore.fetchUIImage(localId: first.assetLocalId)
        } else if let last = photos.last {
            lastGhost = await PhotoStore.fetchUIImage(localId: last.assetLocalId)
        } else {
            lastGhost = nil
        }
    }
}

struct CameraPreviewLayerView: UIViewRepresentable {
    @Binding var layer: AVCaptureVideoPreviewLayer?

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .black
        return v
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = layer, layer.superlayer == nil {
            layer.frame = uiView.bounds
            uiView.layer.addSublayer(layer)
        }
        uiView.layer.sublayers?.first?.frame = uiView.bounds
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
