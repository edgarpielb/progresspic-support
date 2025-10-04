import SwiftUI
import AVFoundation
import Photos
import PhotosUI
import UserNotifications

// MARK: - PhotoStore (Local file storage)
enum PhotoStore {
    static func requestAuthorization() async -> Bool {
        // Still needed for importing existing photos from photo library
        await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization { status in
                cont.resume(returning: status == .authorized || status == .limited)
            }
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

    static func fetchUIImage(localId: String, targetSize: CGSize? = nil) async -> UIImage? {
        // First try to load from app directory (new method)
        if let image = loadFromAppDirectory(filename: localId, targetSize: targetSize) {
            return image
        }
        
        // Fallback: try to load from photo library (for existing photos)
        return await loadFromPhotoLibrary(localId: localId, targetSize: targetSize)
    }
    
    static func loadFromAppDirectory(filename: String, targetSize: CGSize? = nil) -> UIImage? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let photosDirectory = documentsPath.appendingPathComponent("Photos")
        let fileURL = photosDirectory.appendingPathComponent(filename)
        
        guard let image = UIImage(contentsOfFile: fileURL.path) else {
            return nil
        }
        
        // If no target size specified, return original image
        guard let targetSize = targetSize else { return image }
        
        // Resize image if target size is specified
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
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
final class CameraService: NSObject, ObservableObject {
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var latestPhoto: UIImage?
    @Published var isFront = true
    @Published var isAuthorized = false
    @Published var canCapture = false

    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()

    override init() {
        super.init()
        Task {
            await requestCameraPermission()
        }
    }
    
    @MainActor
    private func requestCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("📹 Camera permission status: \(status)")
        
        switch status {
        case .authorized:
            print("✅ Camera already authorized")
            isAuthorized = true
            configureSession(front: true)
        case .notDetermined:
            print("❓ Requesting camera permission...")
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            print("📹 Camera permission granted: \(granted)")
            isAuthorized = granted
            if granted {
                configureSession(front: true)
            }
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

            // Start the session immediately after configuration is committed (on same background queue)
            if !self.session.isRunning {
                print("🎥 Starting camera session after configuration...")
                self.session.startRunning()
                print("📹 Camera session started: \(self.session.isRunning)")
            }

            // Create preview layer and update UI on main thread
            DispatchQueue.main.async {
                if self.previewLayer == nil {
                    let layer = AVCaptureVideoPreviewLayer(session: self.session)
                    layer.videoGravity = .resizeAspectFill
                    self.previewLayer = layer
                } else {
                    self.previewLayer?.session = self.session
                }
                
                print("📹 Session inputs: \(self.session.inputs.count)")
                print("📹 Session outputs: \(self.session.outputs.count)")
                self.updateCaptureReadiness()
            }
        }
    }

    func start() { 
        guard isAuthorized else { 
            print("❌ Camera not authorized")
            return 
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Only start if not already running and not in configuration
            if !self.session.isRunning {
                print("🎥 Starting camera session...")
                self.session.startRunning()
                
                DispatchQueue.main.async {
                    print("📹 Camera session running: \(self.session.isRunning)")
                    print("📹 Session inputs: \(self.session.inputs.count)")
                    print("📹 Session outputs: \(self.session.outputs.count)")
                    self.updateCaptureReadiness()
                }
            } else {
                print("📹 Camera session already running")
                DispatchQueue.main.async {
                    self.updateCaptureReadiness()
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
    func flip() {
        isFront.toggle()
        configureSession(front: isFront)
    }

    func capturePhoto() {
        guard isAuthorized, canCapture else {
            print("🚫 Not ready to capture")
            return
        }
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let ui = UIImage(data: data) else { return }
        latestPhoto = ui
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
        // cancel old
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [journey.id.uuidString])
        // schedule a daily notification for each time
        for (idx, comps) in journey.reminderTimes.enumerated() {
            var dc = DateComponents()
            dc.hour = comps.hour
            dc.minute = comps.minute
            let content = UNMutableNotificationContent()
            content.title = "Time for a new photo"
            content.body = "Add today’s photo to \(journey.name)."
            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            let id = "\(journey.id.uuidString)-\(idx)"
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }
}
