import SwiftUI
import AVFoundation
import Photos
import PhotosUI
import UserNotifications
import HealthKit
import StoreKit

// MARK: - PhotoStore (Local file storage)
enum PhotoStore {
    /// Memory cache for loaded images to avoid repeated decoding
    /// Automatically evicts under memory pressure
    private static let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        // Limit cache to prevent unbounded memory growth
        cache.countLimit = 50  // Maximum 50 images in cache
        cache.totalCostLimit = 100 * 1024 * 1024  // 100 MB total
        return cache
    }()
    
    /// Generate a cache key from localId and optional target size
    private static func cacheKey(for localId: String, targetSize: CGSize?) -> String {
        if let size = targetSize {
            return "\(localId)_\(Int(size.width))x\(Int(size.height))"
        }
        return "\(localId)_full"
    }
    
    /// Clear the image cache (useful for memory warnings or testing)
    static func clearCache() {
        imageCache.removeAllObjects()
        print("🗑️ Cleared image cache")
    }
    
    static func requestAuthorization() async -> Bool {
        // Still needed for importing existing photos from photo library
        await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization { status in
                cont.resume(returning: status == .authorized || status == .limited)
            }
        }
    }
    
    /// Crop image to 4:5 aspect ratio (1200x1500 optimized)
    /// This ensures consistent cropping across all photos in the app
    /// Using smaller dimensions to reduce memory usage while maintaining quality
    static func cropTo4x5(_ image: UIImage) -> UIImage {
        let outW: CGFloat = 1200   // 4:5 canvas (optimized for memory)
        let outH: CGFloat = 1500
        let canvas = CGSize(width: outW, height: outH)

        // Calculate scale to fill the canvas (use max to ensure crop fills the frame)
        let baseScale = max(outW / image.size.width, outH / image.size.height)

        let renderer = UIGraphicsImageRenderer(size: canvas)
        return renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvas))

            // Center the image
            ctx.cgContext.translateBy(x: outW/2, y: outH/2)
            ctx.cgContext.scaleBy(x: baseScale, y: baseScale)

            let drawRect = CGRect(
                x: -image.size.width/2,
                y: -image.size.height/2,
                width: image.size.width,
                height: image.size.height
            )
            image.draw(in: drawRect)
        }
    }

    static func saveToAppDirectory(_ image: UIImage) async throws -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let photosDirectory = documentsPath.appendingPathComponent("Photos")

        // Create Photos directory if it doesn't exist
        try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true, attributes: nil)

        // Generate unique filename
        let filename = UUID().uuidString + ".jpg"
        let fileURL = photosDirectory.appendingPathComponent(filename)

        // Save image as JPEG
        guard let jpegData = image.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "PhotoStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not convert image to JPEG"])
        }

        try jpegData.write(to: fileURL)
        return filename // Return just the filename, not the full path
    }

    static func saveToLibrary(_ image: UIImage) async throws -> String {
        // Redirect to app directory storage instead of photo library
        return try await saveToAppDirectory(image)
    }
    
    static func saveToAppDirectoryAndLibrary(_ image: UIImage, saveToCameraRoll: Bool) async throws -> String {
        // Always save to app directory
        let filename = try await saveToAppDirectory(image)
        
        // Optionally save to photo library if setting is enabled
        if saveToCameraRoll {
            try await saveToPhotoLibrary(image)
        }
        
        return filename
    }
    
    private static func saveToPhotoLibrary(_ image: UIImage) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
    
    static func deleteFromAppDirectory(localId: String) async throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let photosDirectory = documentsPath.appendingPathComponent("Photos")
        let fileURL = photosDirectory.appendingPathComponent(localId)
        
        // Remove from cache
        imageCache.removeObject(forKey: localId as NSString)
        
        // Delete the file
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
            print("🗑️ Deleted photo file: \(localId)")
        } else {
            print("⚠️ Photo file not found: \(localId)")
        }
    }

    static func fetchUIImage(localId: String, targetSize: CGSize? = nil) async -> UIImage? {
        // Check cache first
        let key = cacheKey(for: localId, targetSize: targetSize)
        if let cachedImage = imageCache.object(forKey: key as NSString) {
            print("✅ Cache hit for: \(localId) (\(targetSize != nil ? "\(Int(targetSize!.width))x\(Int(targetSize!.height))" : "full"))")
            return cachedImage
        }
        
        // First try to load from app directory (new method)
        if let image = loadFromAppDirectory(filename: localId, targetSize: targetSize) {
            // Cache the loaded image
            imageCache.setObject(image, forKey: key as NSString)
            print("💾 Cached image: \(localId) (\(targetSize != nil ? "\(Int(targetSize!.width))x\(Int(targetSize!.height))" : "full"))")
            return image
        }
        
        // Fallback: try to load from photo library (for existing photos)
        if let image = await loadFromPhotoLibrary(localId: localId, targetSize: targetSize) {
            // Cache the loaded image
            imageCache.setObject(image, forKey: key as NSString)
            print("💾 Cached image from library: \(localId)")
            return image
        }
        
        return nil
    }
    
    static func loadFromAppDirectory(filename: String, targetSize: CGSize? = nil) -> UIImage? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let photosDirectory = documentsPath.appendingPathComponent("Photos")
        let fileURL = photosDirectory.appendingPathComponent(filename)
        
        // If no target size, load normally (for editing, etc.)
        guard let targetSize = targetSize else {
            return UIImage(contentsOfFile: fileURL.path)
        }
        
        // Use CGImageSource for efficient downsampling
        // This decodes only the pixels we need, avoiding memory spikes
        return downsampleImage(at: fileURL, to: targetSize)
    }
    
    /// Efficiently downsample an image using CGImageSource
    /// This avoids loading the full image into memory, preventing memory spikes
    private static func downsampleImage(at imageURL: URL, to targetSize: CGSize) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, imageSourceOptions) else {
            print("⚠️ Failed to create image source for: \(imageURL.lastPathComponent)")
            return nil
        }
        
        // Calculate the maximum dimension
        let maxDimensionInPixels = max(targetSize.width, targetSize.height)
        
        // Create thumbnail options
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary
        
        // Generate the thumbnail
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            print("⚠️ Failed to create thumbnail for: \(imageURL.lastPathComponent)")
            // Fallback to standard loading
            return UIImage(contentsOfFile: imageURL.path)
        }
        
        return UIImage(cgImage: downsampledImage)
    }
    
    static func loadFromPhotoLibrary(localId: String, targetSize: CGSize? = nil) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil).firstObject else { return nil }
        
        return await withTaskGroup(of: UIImage?.self) { group in
            group.addTask {
                await withCheckedContinuation { cont in
                    let manager = PHCachingImageManager.default()
                    let size = targetSize ?? CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
                    
                    // Configure options to ensure single callback
                    let options = PHImageRequestOptions()
                    options.deliveryMode = .highQualityFormat
                    options.isNetworkAccessAllowed = true
                    options.isSynchronous = false
                    
                    var hasResumed = false
                    
                    let requestID = manager.requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: options) { img, info in
                        // Ensure we only resume once
                        guard !hasResumed else { return }
                        
                        // Check if this is the final result
                        let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                        let isInCloud = info?[PHImageResultIsInCloudKey] as? Bool ?? false
                        let isCancelled = info?[PHImageCancelledKey] as? Bool ?? false
                        let hasError = info?[PHImageErrorKey] != nil
                        
                        if isCancelled || hasError {
                            hasResumed = true
                            cont.resume(returning: nil)
                            return
                        }
                        
                        // Only resume for high quality, non-degraded results
                        if !isDegraded && !isInCloud {
                            hasResumed = true
                            cont.resume(returning: img)
                        } else if img != nil && !isInCloud && !isDegraded {
                            // Accept non-cloud, non-degraded images
                            hasResumed = true
                            cont.resume(returning: img)
                        } else if img != nil && !hasResumed {
                            // Last resort: accept any image we get after some delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                if !hasResumed {
                                    hasResumed = true
                                    cont.resume(returning: img)
                                }
                            }
                        }
                    }
                    
                    // Set a timeout to prevent hanging
                    Task {
                        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                        if !hasResumed {
                            manager.cancelImageRequest(requestID)
                            hasResumed = true
                            cont.resume(returning: nil)
                        }
                    }
                }
            }
            
            // Return the first (and only) result
            for await result in group {
                return result
            }
            return nil
        }
    }

    static func creationDate(for localId: String) -> Date? {
        // First try to get creation date from local file
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let photosDirectory = documentsPath.appendingPathComponent("Photos")
        let fileURL = photosDirectory.appendingPathComponent(localId)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                return attributes[.creationDate] as? Date
            } catch {
                print("Error getting file creation date: \(error)")
            }
        }
        
        // Fallback to photo library for existing photos
        return PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil).firstObject?.creationDate
    }
}

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

// MARK: - Review Request Manager
enum ReviewRequestManager {
    private static let lastReviewRequestStreakKey = "LastReviewRequestStreak"
    private static let hasRequestedFinalReviewKey = "HasRequestedFinalReview"
    
    static func checkAndRequestReview(currentStreak: Int) {
        // Don't request if we've already done the final request
        if UserDefaults.standard.bool(forKey: hasRequestedFinalReviewKey) {
            return
        }
        
        let lastRequestedStreak = UserDefaults.standard.integer(forKey: lastReviewRequestStreakKey)
        
        // Determine if we should request a review
        var shouldRequest = false
        var isFinalRequest = false
        
        if currentStreak >= 14 && lastRequestedStreak < 14 {
            shouldRequest = true
            isFinalRequest = true
        } else if currentStreak >= 7 && lastRequestedStreak < 7 {
            shouldRequest = true
        } else if currentStreak >= 3 && lastRequestedStreak < 3 {
            shouldRequest = true
        }
        
        if shouldRequest {
            // Import StoreKit at the top of the file
            if #available(iOS 14.0, *) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: windowScene)
                }
            } else {
                SKStoreReviewController.requestReview()
            }
            
            // Update last requested streak
            UserDefaults.standard.set(currentStreak, forKey: lastReviewRequestStreakKey)
            
            // Mark if this was the final request
            if isFinalRequest {
                UserDefaults.standard.set(true, forKey: hasRequestedFinalReviewKey)
            }
        }
    }
}

// MARK: - Reminder scheduling
enum ReminderManager {
    static func requestPermission() async -> Bool {
        await withCheckedContinuation { cont in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
                cont.resume(returning: ok)
            }
        }
    }

    static func schedule(for journey: Journey) {
        // Request permission first, then schedule
        Task {
            // Request permission when first reminder is being scheduled
            let granted = await requestPermission()

            guard granted else {
                print("⚠️ Notification permission not granted")
                return
            }

            // Cancel all old notifications for this journey
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let journeyIds = requests
                    .filter { $0.identifier.hasPrefix(journey.id.uuidString) }
                    .map { $0.identifier }
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: journeyIds)
            }

            // Schedule notifications for each reminder
            guard let reminders = journey.reminders else { return }

            for reminder in reminders {
                let selectedDays = reminder.selectedDays

                // Schedule a separate notification for each selected day
                for day in selectedDays {
                    var dc = DateComponents()
                    dc.hour = reminder.hour
                    dc.minute = reminder.minute
                    dc.weekday = day // 1 = Sunday, 2 = Monday, etc. in Calendar, but we use 1 = Monday

                    // Adjust weekday: our system uses 1=Mon...7=Sun, iOS uses 1=Sun...7=Sat
                    let adjustedWeekday = day == 7 ? 1 : day + 1
                    dc.weekday = adjustedWeekday

                    let content = UNMutableNotificationContent()
                    content.title = reminder.notificationText
                    content.body = "Add today's photo to \(journey.name)."
                    content.sound = .default

                    let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                    let id = "\(journey.id.uuidString)-\(reminder.id.uuidString)-\(day)"

                    try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                }
            }
        }
    }
}

// MARK: - HealthKit Service
struct BodyCompositionData {
    var weight: Double?
    var bodyFatPercentage: Double?
    var leanBodyMass: Double?
    var bmi: Double?
    var weightDate: Date?
    var bodyFatDate: Date?
    var leanMassDate: Date?
    var bmiDate: Date?
}

struct HealthDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

@MainActor
class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    private let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var bodyComposition = BodyCompositionData()

    private init() {
        // Check authorization status on init
        checkAuthorizationStatus()
    }

    private func checkAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            isAuthorized = false
            return
        }

        // Check if we have authorization by trying to get the status
        // Note: HealthKit doesn't provide a direct way to check read authorization
        // but we can infer it from UserDefaults or by attempting to read data
        let hasAuthorized = UserDefaults.standard.bool(forKey: "HealthKitAuthorized")
        isAuthorized = hasAuthorized
        print("📊 HealthKit authorization status: \(isAuthorized)")
    }
    
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit is not available on this device")
            return false
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKObjectType.quantityType(forIdentifier: .leanBodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyMassIndex)!
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            isAuthorized = true
            // Save authorization status to persist across app launches
            UserDefaults.standard.set(true, forKey: "HealthKitAuthorized")
            print("✅ HealthKit authorization granted")
            return true
        } catch {
            print("❌ HealthKit authorization failed: \(error)")
            isAuthorized = false
            UserDefaults.standard.set(false, forKey: "HealthKitAuthorized")
            return false
        }
    }
    
    func fetchBodyComposition() async {
        guard isAuthorized else {
            print("⚠️ HealthKit not authorized")
            return
        }
        
        async let weight = fetchMostRecent(.bodyMass)
        async let bodyFat = fetchMostRecent(.bodyFatPercentage)
        async let leanMass = fetchMostRecent(.leanBodyMass)
        async let bmi = fetchMostRecent(.bodyMassIndex)
        
        let results = await (weight, bodyFat, leanMass, bmi)
        
        bodyComposition = BodyCompositionData(
            weight: results.0?.value,
            bodyFatPercentage: results.0?.value != nil ? (results.1?.value ?? 0) * 100 : nil, // Convert to percentage
            leanBodyMass: results.2?.value,
            bmi: results.3?.value,
            weightDate: results.0?.date,
            bodyFatDate: results.1?.date,
            leanMassDate: results.2?.date,
            bmiDate: results.3?.date
        )
        
        print("📊 Body composition fetched:")
        print("  Weight: \(bodyComposition.weight ?? 0) kg")
        print("  Body Fat: \(bodyComposition.bodyFatPercentage ?? 0)%")
        print("  Lean Mass: \(bodyComposition.leanBodyMass ?? 0) kg")
        print("  BMI: \(bodyComposition.bmi ?? 0)")
    }
    
    private func fetchMostRecent(_ identifier: HKQuantityTypeIdentifier) async -> (value: Double, date: Date)? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return nil
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let wrappedQuery = HKSampleQuery(
                sampleType: quantityType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard error == nil,
                      let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let unit: HKUnit
                switch identifier {
                case .bodyMass, .leanBodyMass:
                    unit = .gramUnit(with: .kilo)
                case .bodyFatPercentage:
                    unit = .percent()
                case .bodyMassIndex:
                    unit = .count()
                default:
                    unit = .count()
                }
                
                let value = sample.quantity.doubleValue(for: unit)
                continuation.resume(returning: (value: value, date: sample.endDate))
            }
            
            healthStore.execute(wrappedQuery)
        }
    }
    
    func fetchHistoricalData(for identifier: HKQuantityTypeIdentifier, timeRange: TimeRange) async -> [HealthDataPoint] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return []
        }

        let endDate = Date()
        let startDate: Date

        switch timeRange {
        case .week:
            startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            startDate = Calendar.current.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        case .sixMonths:
            startDate = Calendar.current.date(byAdding: .month, value: -6, to: endDate) ?? endDate
        case .year:
            startDate = Calendar.current.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        case .all:
            startDate = Calendar.current.date(byAdding: .year, value: -10, to: endDate) ?? endDate
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

        // Add reasonable limit for large datasets to prevent memory issues
        let limit = timeRange == .all ? 1000 : HKObjectQueryNoLimit

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard error == nil,
                      let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let unit: HKUnit
                switch identifier {
                case .bodyMass, .leanBodyMass:
                    unit = .gramUnit(with: .kilo)
                case .bodyFatPercentage:
                    unit = .percent()
                case .bodyMassIndex:
                    unit = .count()
                default:
                    unit = .count()
                }

                let dataPoints = samples.map { sample in
                    var value = sample.quantity.doubleValue(for: unit)
                    // Convert body fat percentage to percentage (0-100)
                    if identifier == .bodyFatPercentage {
                        value *= 100
                    }
                    return HealthDataPoint(date: sample.endDate, value: value)
                }

                continuation.resume(returning: dataPoints)
            }

            healthStore.execute(query)
        }
    }
    
    func saveHealthData(type: HKQuantityTypeIdentifier, value: Double, date: Date) async -> Bool {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: type) else {
            print("⚠️ Unable to get quantity type for \(type)")
            return false
        }
        
        // Create the appropriate unit based on the type
        let unit: HKUnit
        switch type {
        case .bodyFatPercentage:
            unit = .percent()
        case .bodyMassIndex:
            unit = .count()
        case .leanBodyMass, .bodyMass:
            unit = .gramUnit(with: .kilo)
        default:
            unit = .count()
        }
        
        let quantity = HKQuantity(unit: unit, doubleValue: value)
        let sample = HKQuantitySample(type: quantityType, quantity: quantity, start: date, end: date)
        
        do {
            try await healthStore.save(sample)
            print("✅ Successfully saved \(type.rawValue) data to HealthKit")
            return true
        } catch {
            print("❌ Error saving to HealthKit: \(error.localizedDescription)")
            return false
        }
    }
    
    func deleteHealthData(identifier: HKQuantityTypeIdentifier, date: Date) async -> Bool {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            print("⚠️ Unable to get quantity type for \(identifier)")
            return false
        }
        
        // Create a predicate to find samples at the specific date
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: quantityType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    print("❌ Error querying samples to delete: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                    return
                }
                
                guard let samples = samples, !samples.isEmpty else {
                    print("⚠️ No samples found to delete")
                    continuation.resume(returning: false)
                    return
                }
                
                self.healthStore.delete(samples) { success, error in
                    if let error = error {
                        print("❌ Error deleting samples: \(error.localizedDescription)")
                        continuation.resume(returning: false)
                    } else if success {
                        print("✅ Successfully deleted \(samples.count) sample(s)")
                        continuation.resume(returning: true)
                    } else {
                        continuation.resume(returning: false)
                    }
                }
            }
            
            self.healthStore.execute(query)
        }
    }
}

enum TimeRange: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case sixMonths = "6 Months"
    case year = "Year"
    case all = "All"
    
    var id: String { rawValue }
}
