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

        // Let AVFoundation handle rotation automatically - just set mirroring
        // Mirror preview for front camera (like a mirror) but keep capture normal
        if connection.isVideoMirroringSupported {
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
            
            // Check for ultra-wide camera availability (only on back)
            if !front {
                let ultraWide = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
                DispatchQueue.main.async {
                    self.hasUltraWideCamera = ultraWide != nil
                    print("📷 Ultra-wide camera available: \(ultraWide != nil)")
                }
            } else {
                DispatchQueue.main.async {
                    self.hasUltraWideCamera = false
                }
            }
            
            // Add camera input - start with wide angle camera
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
                    self.currentDevice = device  // Keep track of current device
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
                self.currentDevice = nil  // Reset currentDevice when flipping cameras
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
    
    private var isSwitchingCamera = false
    
    func setZoom(_ level: CGFloat) {
        print("🔍 Setting zoom to: \(level)x")
        
        // Prevent multiple simultaneous switches
        guard !isSwitchingCamera else {
            print("⚠️ Camera switch already in progress")
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
                print("⚠️ Camera switch timeout - resetting flag")
                self.isSwitchingCamera = false
            }
        }
        
        isSwitchingCamera = true
        
        // Get current device from session
        let currentDevice = session.inputs.compactMap({ ($0 as? AVCaptureDeviceInput)?.device }).first
        let currentType = currentDevice?.deviceType
        
        print("📷 Current camera: \(currentType?.rawValue ?? "none"), target: \(type.rawValue), zoom: \(targetZoom)x")
        
        // If already on the right camera, just adjust zoom
        if currentType == type {
            print("📷 Already on \(type.rawValue), adjusting zoom to \(targetZoom)x")
            
            guard let device = currentDevice else {
                print("❌ No current device found")
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
                    print("✅ Zoom updated to \(targetZoom)x on \(type.rawValue)")
                }
            } catch {
                print("❌ Error adjusting zoom: \(error)")
                isSwitchingCamera = false
            }
            return
        }
        
        // Need to switch cameras
        print("🔄 Switching from \(currentType?.rawValue ?? "none") to \(type.rawValue)")
        
        guard let newDevice = AVCaptureDevice.default(type, for: .video, position: .back) else {
            print("❌ Camera type \(type.rawValue) not available")
            isSwitchingCamera = false
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Begin configuration first
            self.session.beginConfiguration()
            
            // Remove ALL current inputs
            let inputs = self.session.inputs
            print("🗑️ Removing \(inputs.count) input(s)")
            for input in inputs {
                self.session.removeInput(input)
            }
            
            // Make sure output is still connected
            if !self.session.outputs.contains(self.output) {
                print("⚠️ Photo output not in session, re-adding it")
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
                        print("📷 Ultra-wide zoom set to 1.0 (represents 0.5x)")
                    } else {
                        let deviceMaxZoom = min(newDevice.activeFormat.videoMaxZoomFactor, 5.0)
                        let newZoom = min(max(targetZoom, 1.0), deviceMaxZoom)
                        newDevice.videoZoomFactor = newZoom
                        print("📷 Wide camera zoom set to \(newZoom)x")
                    }
                    newDevice.unlockForConfiguration()
                    
                    print("✅ Successfully added \(type.rawValue) to session")
                    print("📹 Session now has \(self.session.inputs.count) input(s) and \(self.session.outputs.count) output(s)")
                    
                    // Commit configuration
                    self.session.commitConfiguration()
                    print("✅ Session configuration committed")
                    
                    // Ensure session is running
                    if !self.session.isRunning {
                        self.session.startRunning()
                        print("▶️ Started session after camera switch")
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
                            print("📱 Preview layer updated")
                        }
                        
                        // Reset switching flag
                        self.isSwitchingCamera = false
                        print("✅ Camera switch completed to \(type.rawValue) at \(targetZoom)x")
                    }
                } else {
                    print("❌ Cannot add camera input to session")
                    self.session.commitConfiguration()
                    
                    DispatchQueue.main.async {
                        self.isSwitchingCamera = false
                    }
                }
            } catch {
                print("❌ Error switching camera: \(error)")
                self.session.commitConfiguration()
                
                DispatchQueue.main.async {
                    self.isSwitchingCamera = false
                }
            }
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

        // Let AVFoundation handle orientation automatically via EXIF metadata
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

