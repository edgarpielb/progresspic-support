import SwiftUI
import AVFoundation

// MARK: - CameraService (AVFoundation)
final class CameraService: NSObject, ObservableObject, @unchecked Sendable {
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var latestPhoto: UIImage?
    @Published var isFront = true
    @Published var isAuthorized = false
    @Published var canCapture = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var currentZoom: CGFloat = 1.0
    @Published var maxZoom: CGFloat = 5.0

    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()

    override init() {
        super.init()
        // Don't auto-start camera - wait for view to appear
        // This prevents camera from starting when app launches on non-camera tab
    }
    
    @MainActor
    func requestPermissionIfNeeded() async {
        await requestCameraPermission()
    }
    
    @MainActor
    private func requestCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("📹 Camera permission status: \(status)")
        
        switch status {
        case .authorized:
            print("✅ Camera already authorized")
            isAuthorized = true
            // Don't configure here - let start() handle it
        case .notDetermined:
            print("❓ Requesting camera permission...")
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            print("📹 Camera permission granted: \(granted)")
            isAuthorized = granted
            // Don't configure here - let start() handle it
        case .denied:
            print("❌ Camera permission denied")
            isAuthorized = false
        case .restricted:
            print("🚫 Camera access restricted")
            isAuthorized = false
        @unknown default:
            print("❓ Unknown camera permission status")
            isAuthorized = false
        }
    }

    @MainActor
    private func updateCaptureReadiness() {
        let active = session.isRunning &&
                     output.connections.contains { $0.isEnabled && $0.isActive }
        canCapture = active
    }
    
    @MainActor
    func updateOrientation(forFrontCamera: Bool? = nil) {
        guard let connection = previewLayer?.connection else {
            return
        }

        // Use explicit parameter if provided, otherwise use instance variable
        let isFrontCamera = forFrontCamera ?? isFront

        // Get the current interface orientation using modern API
        let interfaceOrientation: UIInterfaceOrientation
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            interfaceOrientation = windowScene.interfaceOrientation
        } else {
            interfaceOrientation = .portrait
        }

        // Use iOS 17+ rotation angle API when available
        if #available(iOS 17.0, *) {
            // Convert interface orientation to rotation angle in degrees
            // Front and back cameras have different sensor orientations
            let rotationAngle: CGFloat

            if isFrontCamera {
                // Front camera sensor orientation
                switch interfaceOrientation {
                case .portrait:
                    rotationAngle = 270  // Front camera needs 270° for correct portrait orientation
                case .portraitUpsideDown:
                    rotationAngle = 90
                case .landscapeLeft:
                    rotationAngle = 180
                case .landscapeRight:
                    rotationAngle = 0
                case .unknown:
                    rotationAngle = 270
                @unknown default:
                    rotationAngle = 270
                }
            } else {
                // Back camera sensor orientation
                switch interfaceOrientation {
                case .portrait:
                    rotationAngle = 90
                case .portraitUpsideDown:
                    rotationAngle = 270
                case .landscapeLeft:
                    rotationAngle = 180
                case .landscapeRight:
                    rotationAngle = 0
                case .unknown:
                    rotationAngle = 90
                @unknown default:
                    rotationAngle = 90
                }
            }

            if connection.isVideoRotationAngleSupported(rotationAngle) {
                connection.videoRotationAngle = rotationAngle
                print("🔄 Video rotation angle set to: \(rotationAngle)° for \(isFrontCamera ? "front" : "back") camera in \(interfaceOrientation)")
            }
        } else {
            // Fallback for iOS 16 and earlier
            #if compiler(>=5.9)
            // Suppress deprecation warning for iOS 16 compatibility
            if connection.isVideoOrientationSupported {
                let videoOrientation: AVCaptureVideoOrientation
                switch interfaceOrientation {
                case .portrait:
                    videoOrientation = .portrait
                case .portraitUpsideDown:
                    videoOrientation = .portraitUpsideDown
                case .landscapeLeft:
                    videoOrientation = .landscapeLeft
                case .landscapeRight:
                    videoOrientation = .landscapeRight
                case .unknown:
                    videoOrientation = .portrait
                @unknown default:
                    videoOrientation = .portrait
                }
                connection.videoOrientation = videoOrientation
                print("🔄 Video orientation updated to: \(videoOrientation.rawValue)")
            }
            #endif
        }

        // Mirror preview for front camera (like a mirror)
        // But capture will not be mirrored (normal photo)
        if connection.isVideoMirroringSupported {
            // IMPORTANT: Must disable automatic adjustment before manual control
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isFrontCamera
            print("🔄 Video mirroring set to: \(isFrontCamera ? "ON (front camera)" : "OFF (back camera)")")
        }
    }

    func configureSession(front: Bool) {
        print("🔧 Configuring camera session (front: \(front))...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            
            // Remove existing inputs
            self.session.inputs.forEach { self.session.removeInput($0) }
            print("🗑️ Removed existing inputs")
            
            // Add camera input
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: front ? .front : .back) else {
                print("❌ Could not find camera device")
                self.session.commitConfiguration()
                return
            }
            
            print("📷 Found camera device: \(device.localizedName)")
            
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    print("✅ Added camera input")
                } else {
                    print("❌ Cannot add camera input")
                }
            } catch {
                print("❌ Error creating camera input: \(error)")
            }
            
            // Add photo output if not already added
            if !self.session.outputs.contains(self.output) && self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
                print("✅ Added photo output")
            }
            
            self.session.commitConfiguration()
            print("✅ Session configuration complete")

            // DON'T start here - let start() method handle it
            // This prevents race conditions and multiple startRunning calls

            // Create preview layer and update UI on main thread
            DispatchQueue.main.async {
                if self.previewLayer == nil {
                    let layer = AVCaptureVideoPreviewLayer(session: self.session)
                    layer.videoGravity = .resizeAspectFill // Fill frame completely without gaps
                    self.previewLayer = layer
                } else {
                    self.previewLayer?.session = self.session
                }
                
                print("📹 Session inputs: \(self.session.inputs.count)")
                print("📹 Session outputs: \(self.session.outputs.count)")

                // Wait a moment for the connection to be ready, then set orientation
                // Pass the front parameter explicitly to ensure correct orientation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.updateOrientation(forFrontCamera: front)
                }

                // Now start the session
                self.startSessionAfterConfiguration()
            }
        }
    }
    
    private func startSessionAfterConfiguration() {
        DispatchQueue.global(qos: .userInitiated).async {
            if !self.session.isRunning {
                print("🎥 Starting camera session after configuration...")
                self.session.startRunning()
                DispatchQueue.main.async {
                    print("📹 Camera session started: \(self.session.isRunning)")
                    self.updateCaptureReadiness()
                }
            }
        }
    }

    func start() {
        guard isAuthorized else {
            print("❌ Camera not authorized - cannot start")
            return
        }

        print("🎥 Start called - configuring and starting session...")

        // Configure session first if not configured (no inputs)
        if session.inputs.isEmpty {
            print("📹 No inputs - configuring session first")
            configureSession(front: isFront)
            // configureSession will start the session automatically
        } else if !session.isRunning {
            // Session configured but not running - just start it
            startSessionAfterConfiguration()
        } else {
            print("📹 Camera session already running")
            DispatchQueue.main.async {
                self.updateCaptureReadiness()
            }
        }
    }

    func stopIfNotNeeded() {
        // Only stop if we're not on camera tab and session is running
        DispatchQueue.global(qos: .userInitiated).async {
            if self.session.isRunning {
                print("⏸️ Stopping camera session - not needed")
                self.session.stopRunning()
                DispatchQueue.main.async {
                    self.canCapture = false
                }
            }
        }
    }
    func stop() { 
        if session.isRunning { 
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.stopRunning() 
            }
        }
        Task { @MainActor in canCapture = false }
    }
    
    @MainActor
    func cleanup() {
        print("🧹 Cleaning up camera resources")
        // Remove preview layer from superlayer
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
        canCapture = false
        
        // Stop session if running
        DispatchQueue.global(qos: .userInitiated).async {
            if self.session.isRunning {
                self.session.stopRunning()
                print("🛑 Camera session stopped and cleaned up")
            }
        }
    }
    
    func flip() {
        let oldValue = isFront
        let newValue = !isFront
        print("🔄 Flipping camera (front: \(oldValue) -> \(newValue))")

        // Stop session before reconfiguring to prevent race conditions
        DispatchQueue.global(qos: .userInitiated).async {
            if self.session.isRunning {
                print("⏸️ Stopping session before flip")
                self.session.stopRunning()
            }

            // Wait a moment for the session to fully stop
            Thread.sleep(forTimeInterval: 0.1)

            // Now reconfigure with the new camera (this will update orientation correctly)
            self.configureSession(front: newValue)

            // Update isFront state on main thread after configuration starts
            DispatchQueue.main.async {
                self.isFront = newValue
            }

            // Force preview layer update on main thread
            DispatchQueue.main.async {
                // Trigger a rebinding by temporarily setting to nil, then back
                let currentSession = self.session
                self.previewLayer?.session = nil
                self.previewLayer?.session = currentSession
                print("🔄 Preview layer rebound to session")
            }
        }
    }
    
    func cycleFlashMode() {
        switch flashMode {
        case .off:
            flashMode = .on
        case .on:
            flashMode = .auto
        case .auto:
            flashMode = .off
        @unknown default:
            flashMode = .off
        }
        print("💡 Flash mode: \(flashMode.rawValue)")
    }
    
    func zoomIn() {
        guard let device = session.inputs.compactMap({ ($0 as? AVCaptureDeviceInput)?.device }).first else { return }
        
        do {
            try device.lockForConfiguration()
            let deviceMaxZoom = min(device.activeFormat.videoMaxZoomFactor, 5.0) // Cap at 5x
            let newZoom = min(device.videoZoomFactor * 1.5, deviceMaxZoom)
            device.videoZoomFactor = newZoom
            device.unlockForConfiguration()
            
            DispatchQueue.main.async {
                self.currentZoom = newZoom
                self.maxZoom = deviceMaxZoom
            }
            print("🔍 Zoom in: \(newZoom)x")
        } catch {
            print("❌ Zoom error: \(error)")
        }
    }
    
    func zoomOut() {
        guard let device = session.inputs.compactMap({ ($0 as? AVCaptureDeviceInput)?.device }).first else { return }
        
        do {
            try device.lockForConfiguration()
            let newZoom = max(device.videoZoomFactor / 1.5, 1.0)
            device.videoZoomFactor = newZoom
            device.unlockForConfiguration()
            
            DispatchQueue.main.async {
                self.currentZoom = newZoom
            }
            print("🔍 Zoom out: \(newZoom)x")
        } catch {
            print("❌ Zoom error: \(error)")
        }
    }
    
    func setZoom(_ level: CGFloat) {
        guard let device = session.inputs.compactMap({ ($0 as? AVCaptureDeviceInput)?.device }).first else { return }
        
        do {
            try device.lockForConfiguration()
            let deviceMaxZoom = min(device.activeFormat.videoMaxZoomFactor, 5.0)
            let newZoom = min(max(level, 1.0), deviceMaxZoom)
            device.videoZoomFactor = newZoom
            device.unlockForConfiguration()
            
            DispatchQueue.main.async {
                self.currentZoom = newZoom
                self.maxZoom = deviceMaxZoom
            }
            print("🔍 Zoom set to: \(newZoom)x")
        } catch {
            print("❌ Zoom error: \(error)")
        }
    }

    func capturePhoto() {
        guard isAuthorized, canCapture else {
            print("🚫 Not ready to capture")
            return
        }
        
        let settings = AVCapturePhotoSettings()
        
        // Configure flash if supported by the device
        if output.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
            print("💡 Flash mode set to: \(flashMode == .on ? "ON" : flashMode == .off ? "OFF" : "AUTO")")
        } else {
            print("⚠️ Flash mode \(flashMode.rawValue) not supported on this device")
        }
        
        output.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), var ui = UIImage(data: data) else { return }

        // For front camera, flip the image horizontally to match what user sees in preview
        // The rotation is already correct from the capture settings, we just need to mirror
        if isFront, let cgImage = ui.cgImage {
            // Flip horizontally while preserving the correct orientation
            UIGraphicsBeginImageContextWithOptions(ui.size, false, ui.scale)
            guard let context = UIGraphicsGetCurrentContext() else { return }

            // Flip the context horizontally
            context.translateBy(x: ui.size.width, y: 0)
            context.scaleBy(x: -1.0, y: 1.0)

            // Draw the image in the flipped context
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: ui.size.width, height: ui.size.height))

            if let flippedImage = UIGraphicsGetImageFromCurrentImageContext() {
                ui = flippedImage
                print("🔄 Front camera photo mirrored horizontally")
            }

            UIGraphicsEndImageContext()
        }

        latestPhoto = ui
    }
}

