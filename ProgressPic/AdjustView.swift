import SwiftUI

struct AdjustView: View {
    let captured: UIImage
    let ghost: UIImage?
    var onSave: (_ savedLocalId: String, _ transform: AlignTransform) -> Void

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var rotation: Angle = .zero
    @State private var opacity: Double = 0.5
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.85).ignoresSafeArea()
                if let g = ghost {
                    Image(uiImage: g).resizable().scaledToFit().opacity(opacity).blendMode(.plusLighter)
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
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } } }
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
                        Button("Revert") {
                            scale = 1; offset = .zero; rotation = .zero
                        }
                        Spacer()
                        Button("Undo") { /* left empty for MVP */ }
                    }
                    .font(.callout)
                    .padding(.horizontal)
                    .padding(.bottom, 14)
                }
                .background(.ultraThinMaterial)
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

    func save() async {
        guard let localId = try? await PhotoStore.saveToLibrary(captured) else { return }
        let transform = AlignTransform(scale: scale, offsetX: offset.width, offsetY: offset.height, rotation: rotation.radians)
        onSave(localId, transform)
        dismiss()
    }
}
