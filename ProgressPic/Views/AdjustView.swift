import SwiftUI

struct AdjustView: View {
    let captured: UIImage
    let ghost: UIImage?
    let saveToCameraRoll: Bool
    var onSave: (_ savedLocalId: String, _ transform: AlignTransform, _ originalLocalId: String) -> Void

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var rotation: Angle = .zero
    @State private var opacity: Double = 0.5
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 30/255, green: 32/255, blue: 35/255).ignoresSafeArea()

                if let g = ghost {
                    Image(uiImage: g)
                        .resizable()
                        .scaledToFit()
                        .opacity(opacity)
                        .blendMode(.plusLighter)
                }

                Image(uiImage: captured)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .rotationEffect(rotation)
                    .offset(offset)
                    .gesture(dragZoomRotate)
                    .animation(.snappy, value: scale)
                    .animation(.snappy, value: offset)
                    .animation(.snappy, value: rotation)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { 
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .confirmationAction) { 
                    Button(action: { Task { await save() } }) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 14) {
                    if ghost != nil {
                        HStack {
                            Text("Ghost").font(.subheadline.bold())
                            Slider(value: $opacity, in: 0...1)
                        }.padding(.horizontal)
                    }
                    HStack {
                        Button("Revert") { scale = 1; offset = .zero; rotation = .zero }
                        Spacer()
                        Button("Undo") { /* reserved */ }
                    }
                    .font(.callout)
                    .padding(.horizontal)
                    .padding(.bottom, 14)
                }
                .background(
                    ZStack {
                        Color(red: 30/255, green: 32/255, blue: 35/255).opacity(0.9)
                        Rectangle()
                            .fill(.ultraThinMaterial)
                    }
                )
            }
        }
    }

    var dragZoomRotate: some Gesture {
        SimultaneousGesture(
            SimultaneousGesture(
                DragGesture().onChanged { offset = $0.translation },
                MagnificationGesture().onChanged { scale = $0 }
            ),
            RotationGesture().onChanged { rotation = $0 }
        )
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

            ctx.cgContext.translateBy(x: outW/2 + offset.width, y: outH/2 + offset.height)
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
