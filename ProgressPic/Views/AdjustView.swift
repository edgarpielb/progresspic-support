import SwiftUI

struct AdjustView: View {
    let captured: UIImage
    let ghost: UIImage?
    let saveToCameraRoll: Bool
    var onSave: (_ savedLocalId: String, _ transform: AlignTransform, _ originalLocalId: String) -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var rotation: Angle = .zero
    @State private var lastRotation: Angle = .zero
    @State private var opacity: Double = 0.5
    @State private var minScale: CGFloat = 1
    @State private var hasCalculatedInitialScale = false
    @State private var showGhost = false
    @State private var showRotationControls = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 30/255, green: 32/255, blue: 35/255).ignoresSafeArea()

                GeometryReader { geo in
                    let cropW = geo.size.width
                    let cropH = cropW * 5/4

                    ZStack {
                        // Single transformed image for entire view
                        Image(uiImage: captured)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .rotationEffect(rotation)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .opacity(showGhost ? (1 - opacity) : 1)
                            .overlay(
                                // Dimming overlay everywhere EXCEPT the crop area
                                Rectangle()
                                    .fill(Color.black.opacity(0.7))
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .mask(
                                        ZStack {
                                            Rectangle()
                                                .fill(Color.white)
                                            Rectangle()
                                                .fill(Color.black)
                                                .frame(width: cropW, height: cropH)
                                                .position(x: geo.size.width/2, y: geo.size.height/2)
                                                .blendMode(.destinationOut)
                                        }
                                        .compositingGroup()
                                    )
                                    .allowsHitTesting(false)
                            )

                        // Ghost overlay (if enabled)
                        if showGhost, let g = ghost {
                            Image(uiImage: g)
                                .resizable()
                                .scaledToFit()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .opacity(opacity)
                                .allowsHitTesting(false)
                        }
                        
                        // Border on crop area
                        Rectangle()
                            .stroke(Color.white.opacity(0.5), lineWidth: 2)
                            .frame(width: cropW, height: cropH)
                            .position(x: geo.size.width/2, y: geo.size.height/2)
                            .allowsHitTesting(false)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        SimultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                },
                            MagnificationGesture()
                                .onChanged { value in
                                    let newScale = lastScale * value
                                    scale = max(minScale, newScale)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                }
                        )
                    )
                    .simultaneousGesture(
                        RotationGesture()
                            .onChanged { value in
                                rotation = lastRotation + value
                            }
                            .onEnded { _ in
                                lastRotation = rotation
                            }
                    )
                    .onChange(of: geo.size) { _, newSize in
                        // Recalculate scale when geometry changes (e.g., rotation)
                        if hasCalculatedInitialScale {
                            calculateInitialScale(imageSize: captured.size, cropSize: CGSize(width: newSize.width, height: newSize.width * 5/4))
                        }
                    }
                    .task {
                        // Calculate initial scale when image loads
                        if !hasCalculatedInitialScale {
                            calculateInitialScale(imageSize: captured.size, cropSize: CGSize(width: cropW, height: cropH))
                            hasCalculatedInitialScale = true
                        }
                    }
                    }
                }
            .navigationTitle("Edit Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar, .bottomBar)
            .toolbarBackground(.visible, for: .navigationBar, .bottomBar)
            .toolbarColorScheme(.dark, for: .navigationBar, .bottomBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Task { await save() }
                    }) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.pink)
                            .font(.body.weight(.semibold))
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 12)
                    
                    // Rotation controls
                    HStack(spacing: 20) {
                        // Rotation toggle button
                        Button(action: { 
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showRotationControls.toggle()
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "rotate.left")
                                Text("Rotate")
                                    .font(.subheadline.weight(.medium))
                            }
                            .foregroundColor(showRotationControls ? .pink : .white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        // Reset button
                        Button(action: resetTransform) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset")
                                    .font(.subheadline.weight(.medium))
                            }
                            .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    // Rotation controls
                    if showRotationControls {
                        Spacer().frame(height: 8)
                        VStack(spacing: 12) {
                            // Rotation slider
                            HStack {
                                Image(systemName: "rotate.left")
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 20)
                                
                                Slider(value: Binding(
                                    get: { rotation.degrees },
                                    set: { newValue in 
                                        rotation = .degrees(newValue)
                                        lastRotation = rotation
                                    }
                                ), in: -45...45, step: 1)
                                .tint(.pink)
                                
                                Text("\(Int(rotation.degrees))°")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 45, alignment: .trailing)
                            }
                        }
                    }
                    
                    // Ghost Overlay controls
                    if ghost != nil {
                        Spacer().frame(height: 12)
                        
                        HStack(spacing: 16) {
                            Button(action: { 
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showGhost.toggle()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: showGhost ? "eye.fill" : "eye.slash.fill")
                                    Text("Ghost Overlay")
                                        .font(.subheadline.weight(.medium))
                                }
                                .foregroundColor(showGhost ? .cyan : .white.opacity(0.7))
                            }

                            Spacer()
                        }

                        // Slider
                        if showGhost {
                            HStack {
                                Image(systemName: "circle.lefthalf.filled")
                                    .foregroundColor(.white.opacity(0.7))
                                Slider(value: $opacity, in: 0...1)
                                    .tint(.cyan)
                                Text("\(Int(opacity * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 40)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
                .background(
                    ZStack {
                        Color(red: 30/255, green: 32/255, blue: 35/255).opacity(0.9)
                        Rectangle()
                            .fill(.ultraThinMaterial)
                    }
                    .ignoresSafeArea(edges: .bottom)
                )
            }
        }
    }

    private func resetTransform() {
        withAnimation(.easeInOut(duration: 0.3)) {
            // Reset to initial fill scale
            let geo = UIScreen.main.bounds
            let cropW = geo.width
            let cropH = cropW * 5/4
            calculateInitialScale(imageSize: captured.size, cropSize: CGSize(width: cropW, height: cropH))
            scale = minScale
            lastScale = minScale
            offset = .zero
            lastOffset = .zero
            rotation = .zero
            lastRotation = .zero
        }
    }
    
    private func calculateInitialScale(imageSize: CGSize, cropSize: CGSize) {
        // Image will be .scaledToFit() within the crop area
        // Then we apply scaleEffect to zoom it to fill

        let imageAspect = imageSize.width / imageSize.height
        let cropAspect = cropSize.width / cropSize.height  // 4:5 = 0.8

        // ScaledToFit will constrain by the limiting dimension
        // To fill, we need to scale by the ratio of the crop aspect to image aspect
        let fillScale: CGFloat
        if imageAspect > cropAspect {
            // Image is wider than crop - fits by width, needs to scale by height ratio
            fillScale = imageAspect / cropAspect
        } else {
            // Image is taller than crop - fits by height, needs to scale by width ratio
            fillScale = cropAspect / imageAspect
        }

        // Always update minScale to the fill scale
        minScale = fillScale

        // Only set initial scale if we haven't loaded a saved transform
        if !hasCalculatedInitialScale {
            scale = fillScale
            lastScale = fillScale
        }
    }

    // Render to strict 4:5 based on current transform
    func makeCroppedImage() -> UIImage {
        let outW: CGFloat = 1200   // 4:5 canvas (optimized for memory)
        let outH: CGFloat = 1500
        let canvas = CGSize(width: outW, height: outH)

        let baseScale = min(outW / captured.size.width, outH / captured.size.height)
        let finalScale = baseScale * max(scale, 0.001)

        let renderer = UIGraphicsImageRenderer(size: canvas)
        return renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvas))

            ctx.cgContext.translateBy(x: outW/2 + offset.width * baseScale, y: outH/2 + offset.height * baseScale)
            ctx.cgContext.rotate(by: rotation.radians)
            ctx.cgContext.scaleBy(x: finalScale, y: finalScale)

            let drawRect = CGRect(
                x: -captured.size.width/2,
                y: -captured.size.height/2,
                width: captured.size.width,
                height: captured.size.height
            )
            captured.draw(in: drawRect)
        }
    }

    func save() async {
        // Save original image first
        guard let originalId = try? await PhotoStore.saveToAppDirectory(captured) else { return }
        print("💾 Saved original image")

        // Save cropped image
        let cropped = makeCroppedImage()
        guard let localId = try? await PhotoStore.saveToAppDirectoryAndLibrary(cropped, saveToCameraRoll: saveToCameraRoll) else { return }
        print("✂️ Saved cropped image")

        let transform = AlignTransform(scale: scale, offsetX: offset.width, offsetY: offset.height, rotation: rotation.radians)
        onSave(localId, transform, originalId)
        dismiss()
    }
}
