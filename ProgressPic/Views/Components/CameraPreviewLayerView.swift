import SwiftUI
import AVFoundation

/// UIViewRepresentable wrapper for AVCaptureVideoPreviewLayer
/// Handles camera preview rendering with pinch-to-zoom gesture
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
                AppConstants.Log.camera.debug("❌ Zoom error: \(error)")
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
            AppConstants.Log.camera.debug("🧹 Removing \(layersToRemove.count) old preview layer(s)")
            layersToRemove.forEach { $0.removeFromSuperlayer() }
        }

        // Add or update the preview layer
        if previewLayer.superlayer !== uiView.layer {
            AppConstants.Log.camera.debug("➕ Adding preview layer to view hierarchy")
            // Use resizeAspectFill to fill the 4:5 frame completely
            // The frame constraint in CameraHostView ensures we show exactly what will be captured
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
