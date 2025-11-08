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
    @Published var hasUltraWideCamera = false

    let session = AVCaptureSession() // Made internal for access in ContentView
    private let output = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?

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
        AppConstants.Log.camera.debug("Camera permission status: \(status.rawValue)")
        
        switch status {
        case .authorized:
            AppConstants.Log.camera.info("Camera already authorized")
            isAuthorized = true
            // Don't configure here - let start() handle it
        case .notDetermined:
            AppConstants.Log.camera.info("Requesting camera permission...")
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            AppConstants.Log.camera.info("Camera permission granted: \(granted)")
            isAuthorized = granted
            // Don't configure here - let start() handle it
        case .denied:
            AppConstants.Log.camera.warning("Camera permission denied")
            isAuthorized = false
        case .restricted:
            AppConstants.Log.camera.warning("Camera access restricted")
            isAuthorized = false
        @unknown default:
            AppConstants.Log.camera.warning("Unknown camera permission status")
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

        // Let AVFoundation handle rotation automatically - just set mirroring
        // Mirror preview for front camera (like a mirror) but keep capture normal
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isFrontCamera
            AppConstants.Log.camera.debug("🔄 Video mirroring set to: \(isFrontCamera ? "ON (front camera)" : "OFF (back camera)")")
        }
    }

    func configureSession(front: Bool) {
        AppConstants.Log.camera.debug("🔧 Configuring camera session (front: \(front))...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            
            // Remove existing inputs
            self.session.inputs.forEach { self.session.removeInput($0) }
            AppConstants.Log.camera.debug("🗑️ Removed existing inputs")
            
            // Check for ultra-wide camera availability (only on back)
            if !front {
                let ultraWide = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
                DispatchQueue.main.async {
                    self.hasUltraWideCamera = ultraWide != nil
                    AppConstants.Log.camera.debug("📷 Ultra-wide camera available: \(ultraWide != nil)")
                }
            } else {
                DispatchQueue.main.async {
                    self.hasUltraWideCamera = false
                }
            }
            
            // Add camera input - start with wide angle camera
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: front ? .front : .back) else {
                AppConstants.Log.camera.debug("❌ Could not find camera device")
                self.session.commitConfiguration()
                return
            }
            
            AppConstants.Log.camera.debug("📷 Found camera device: \(device.localizedName)")
            
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.currentDevice = device  // Keep track of current device
                    AppConstants.Log.camera.debug("✅ Added camera input")
                } else {
                    AppConstants.Log.camera.debug("❌ Cannot add camera input")
                }
            } catch {
                AppConstants.Log.camera.debug("❌ Error creating camera input: \(error)")
            }
            
            // Add photo output if not already added
            if !self.session.outputs.contains(self.output) && self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
                AppConstants.Log.camera.debug("✅ Added photo output")
            }
            
            self.session.commitConfiguration()
            AppConstants.Log.camera.debug("✅ Session configuration complete")

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
                
                AppConstants.Log.camera.debug("📹 Session inputs: \(self.session.inputs.count)")
                AppConstants.Log.camera.debug("📹 Session outputs: \(self.session.outputs.count)")

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
                AppConstants.Log.camera.debug("🎥 Starting camera session after configuration...")
                self.session.startRunning()
                DispatchQueue.main.async {
                    AppConstants.Log.camera.debug("📹 Camera session started: \(self.session.isRunning)")
                    self.updateCaptureReadiness()
                }
            }
        }
    }

    func start() {
        guard isAuthorized else {
            AppConstants.Log.camera.debug("❌ Camera not authorized - cannot start")
            return
        }

        AppConstants.Log.camera.debug("🎥 Start called - configuring and starting session...")

        // Configure session first if not configured (no inputs)
        if session.inputs.isEmpty {
            AppConstants.Log.camera.debug("📹 No inputs - configuring session first")
            configureSession(front: isFront)
            // configureSession will start the session automatically
        } else if !session.isRunning {
            // Session configured but not running - just start it
            startSessionAfterConfiguration()
        } else {
            AppConstants.Log.camera.debug("📹 Camera session already running")
            DispatchQueue.main.async {
                self.updateCaptureReadiness()
            }
        }
    }

    func stopIfNotNeeded() {
        // Only stop if we're not on camera tab and session is running
        DispatchQueue.global(qos: .userInitiated).async {
            if self.session.isRunning {
                AppConstants.Log.camera.debug("⏸️ Stopping camera session - not needed")
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
        AppConstants.Log.camera.debug("🧹 Cleaning up camera resources")
        // Remove preview layer from superlayer
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
        canCapture = false
        
        // Stop session if running
        DispatchQueue.global(qos: .userInitiated).async {
            if self.session.isRunning {
                self.session.stopRunning()
                AppConstants.Log.camera.debug("🛑 Camera session stopped and cleaned up")
            }
        }
    }
    
    func flip() {
        let oldValue = isFront
        let newValue = !isFront
        AppConstants.Log.camera.debug("🔄 Flipping camera (front: \(oldValue) -> \(newValue))")

        // Stop session before reconfiguring to prevent race conditions
        Task {
            if self.session.isRunning {
                AppConstants.Log.camera.debug("⏸️ Stopping session before flip")
                self.session.stopRunning()
            }

            // Wait a moment for the session to fully stop (non-blocking)
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

            // Now reconfigure with the new camera (this will update orientation correctly)
            self.configureSession(front: newValue)

            // Update isFront state on main thread after configuration starts
            await MainActor.run {
                self.isFront = newValue
                self.currentDevice = nil  // Reset currentDevice when flipping cameras
            }

            // Force preview layer update on main thread
            await MainActor.run {
                // Trigger a rebinding by temporarily setting to nil, then back
                let currentSession = self.session
                self.previewLayer?.session = nil
                self.previewLayer?.session = currentSession
                AppConstants.Log.camera.debug("🔄 Preview layer rebound to session")
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
        AppConstants.Log.camera.debug("💡 Flash mode: \(self.flashMode.rawValue)")
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
            AppConstants.Log.camera.debug("🔍 Zoom in: \(newZoom)x")
        } catch {
            AppConstants.Log.camera.debug("❌ Zoom error: \(error)")
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
            AppConstants.Log.camera.debug("🔍 Zoom out: \(newZoom)x")
        } catch {
            AppConstants.Log.camera.debug("❌ Zoom error: \(error)")
        }
    }
    
    private var isSwitchingCamera = false
    
    func setZoom(_ level: CGFloat) {
        AppConstants.Log.camera.debug("🔍 Setting zoom to: \(level)x")
        
        // Prevent multiple simultaneous switches
        guard !isSwitchingCamera else {
            AppConstants.Log.camera.debug("⚠️ Camera switch already in progress")
            return
        }
        
        // Determine which camera we need
        if level == 0.5 && hasUltraWideCamera {
            // Use ultra-wide camera for 0.5x
            performCameraSwitch(to: .builtInUltraWideCamera, targetZoom: level)
        } else if level >= 1.0 {
            // Use wide camera for 1x and 2x
            performCameraSwitch(to: .builtInWideAngleCamera, targetZoom: level)
        }
    }
    
    private func performCameraSwitch(to type: AVCaptureDevice.DeviceType, targetZoom: CGFloat) {
        // Reset the flag after a timeout to prevent getting stuck
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.isSwitchingCamera {
                AppConstants.Log.camera.debug("⚠️ Camera switch timeout - resetting flag")
                self.isSwitchingCamera = false
            }
        }
        
        isSwitchingCamera = true
        
        // Get current device from session
        let currentDevice = session.inputs.compactMap({ ($0 as? AVCaptureDeviceInput)?.device }).first
        let currentType = currentDevice?.deviceType
        
        AppConstants.Log.camera.debug("📷 Current camera: \(currentType?.rawValue ?? "none"), target: \(type.rawValue), zoom: \(targetZoom)x")
        
        // If already on the right camera, just adjust zoom
        if currentType == type {
            AppConstants.Log.camera.debug("📷 Already on \(type.rawValue), adjusting zoom to \(targetZoom)x")
            
            guard let device = currentDevice else {
                AppConstants.Log.camera.debug("❌ No current device found")
                isSwitchingCamera = false
                return
            }
            
            do {
                try device.lockForConfiguration()
                if type == .builtInUltraWideCamera {
                    device.videoZoomFactor = 1.0
                } else {
                    let deviceMaxZoom = min(device.activeFormat.videoMaxZoomFactor, 5.0)
                    let newZoom = min(max(targetZoom, 1.0), deviceMaxZoom)
                    device.videoZoomFactor = newZoom
                }
                device.unlockForConfiguration()
                
                DispatchQueue.main.async {
                    self.currentZoom = targetZoom
                    self.isSwitchingCamera = false
                    AppConstants.Log.camera.debug("✅ Zoom updated to \(targetZoom)x on \(type.rawValue)")
                }
            } catch {
                AppConstants.Log.camera.debug("❌ Error adjusting zoom: \(error)")
                isSwitchingCamera = false
            }
            return
        }
        
        // Need to switch cameras
        AppConstants.Log.camera.debug("🔄 Switching from \(currentType?.rawValue ?? "none") to \(type.rawValue)")
        
        guard let newDevice = AVCaptureDevice.default(type, for: .video, position: .back) else {
            AppConstants.Log.camera.debug("❌ Camera type \(type.rawValue) not available")
            isSwitchingCamera = false
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Begin configuration first
            self.session.beginConfiguration()
            
            // Remove ALL current inputs
            let inputs = self.session.inputs
            AppConstants.Log.camera.debug("🗑️ Removing \(inputs.count) input(s)")
            for input in inputs {
                self.session.removeInput(input)
            }
            
            // Make sure output is still connected
            if !self.session.outputs.contains(self.output) {
                AppConstants.Log.camera.debug("⚠️ Photo output not in session, re-adding it")
                if self.session.canAddOutput(self.output) {
                    self.session.addOutput(self.output)
                }
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: newDevice)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.currentDevice = newDevice
                    
                    // Set appropriate zoom
                    try newDevice.lockForConfiguration()
                    if type == .builtInUltraWideCamera {
                        newDevice.videoZoomFactor = 1.0
                        AppConstants.Log.camera.debug("📷 Ultra-wide zoom set to 1.0 (represents 0.5x)")
                    } else {
                        let deviceMaxZoom = min(newDevice.activeFormat.videoMaxZoomFactor, 5.0)
                        let newZoom = min(max(targetZoom, 1.0), deviceMaxZoom)
                        newDevice.videoZoomFactor = newZoom
                        AppConstants.Log.camera.debug("📷 Wide camera zoom set to \(newZoom)x")
                    }
                    newDevice.unlockForConfiguration()
                    
                    AppConstants.Log.camera.debug("✅ Successfully added \(type.rawValue) to session")
                    AppConstants.Log.camera.debug("📹 Session now has \(self.session.inputs.count) input(s) and \(self.session.outputs.count) output(s)")
                    
                    // Commit configuration
                    self.session.commitConfiguration()
                    AppConstants.Log.camera.debug("✅ Session configuration committed")
                    
                    // Ensure session is running
                    if !self.session.isRunning {
                        self.session.startRunning()
                        AppConstants.Log.camera.debug("▶️ Started session after camera switch")
                    }
                    
                    // Update UI on main thread
                    DispatchQueue.main.async {
                        self.currentZoom = targetZoom
                        self.updateCaptureReadiness()
                        
                        // Force preview layer update
                        if let layer = self.previewLayer {
                            CATransaction.begin()
                            CATransaction.setDisableActions(true)
                            layer.session = self.session
                            CATransaction.commit()
                            AppConstants.Log.camera.debug("📱 Preview layer updated")
                        }
                        
                        // Reset switching flag
                        self.isSwitchingCamera = false
                        AppConstants.Log.camera.debug("✅ Camera switch completed to \(type.rawValue) at \(targetZoom)x")
                    }
                } else {
                    AppConstants.Log.camera.debug("❌ Cannot add camera input to session")
                    self.session.commitConfiguration()
                    
                    DispatchQueue.main.async {
                        self.isSwitchingCamera = false
                    }
                }
            } catch {
                AppConstants.Log.camera.debug("❌ Error switching camera: \(error)")
                self.session.commitConfiguration()
                
                DispatchQueue.main.async {
                    self.isSwitchingCamera = false
                }
            }
        }
    }

    func capturePhoto() {
        guard isAuthorized, canCapture else {
            AppConstants.Log.camera.debug("🚫 Not ready to capture")
            return
        }

        let settings = AVCapturePhotoSettings()

        // Configure flash if supported by the device
        if output.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
            AppConstants.Log.camera.debug("💡 Flash mode set to: \(self.flashMode == .on ? "ON" : self.flashMode == .off ? "OFF" : "AUTO")")
        } else {
            AppConstants.Log.camera.debug("⚠️ Flash mode \(self.flashMode.rawValue) not supported on this device")
        }

        // Let AVFoundation handle orientation automatically via EXIF metadata
        output.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let originalImage = UIImage(data: data) else { return }

        // For front camera, flip the image horizontally to match what user sees in preview
        // Move this expensive operation off the main thread
        if isFront {
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self = self else { return }

                let flippedImage = await Task {
                    // Flip horizontally while preserving the correct orientation
                    guard let cgImage = originalImage.cgImage else { return originalImage }

                    UIGraphicsBeginImageContextWithOptions(originalImage.size, false, originalImage.scale)
                    guard let context = UIGraphicsGetCurrentContext() else { return originalImage }

                    // Flip the context horizontally
                    context.translateBy(x: originalImage.size.width, y: 0)
                    context.scaleBy(x: -1.0, y: 1.0)

                    // Draw the image in the flipped context
                    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: originalImage.size.width, height: originalImage.size.height))

                    let result = UIGraphicsGetImageFromCurrentImageContext() ?? originalImage
                    UIGraphicsEndImageContext()

                    AppConstants.Log.camera.debug("Front camera photo mirrored horizontally")
                    return result
                }.value

                await MainActor.run {
                    self.latestPhoto = flippedImage
                }
            }
        } else {
            // Back camera - no flipping needed
            latestPhoto = originalImage
        }
    }
}

