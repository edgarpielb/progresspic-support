import SwiftUI
import AVFoundation
import Photos
import PhotosUI
import UserNotifications

// MARK: - PhotoStore (PHAsset access + saving)
enum PhotoStore {
    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization { status in
                cont.resume(returning: status == .authorized || status == .limited)
            }
        }
    }

    static func saveToLibrary(_ image: UIImage) async throws -> String {
        var localId: String?
        try await PHPhotoLibrary.shared().performChanges {
            let req = PHAssetChangeRequest.creationRequestForAsset(from: image)
            if let placeholder = req.placeholderForCreatedAsset {
                localId = placeholder.localIdentifier
            }
        }
        return localId ?? ""
    }

    static func fetchUIImage(localId: String, targetSize: CGSize? = nil) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil).firstObject else { return nil }
        return await withCheckedContinuation { cont in
            let manager = PHCachingImageManager.default()
            let size = targetSize ?? CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
            manager.requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: nil) { img, _ in
                cont.resume(returning: img)
            }
        }
    }

    static func creationDate(for localId: String) -> Date? {
        PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil).firstObject?.creationDate
    }
}

// MARK: - CameraService (AVFoundation)
final class CameraService: NSObject, ObservableObject {
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var latestPhoto: UIImage?
    @Published var isFront = true
    @Published var isAuthorized = false

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
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            configureSession(front: true)
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            isAuthorized = granted
            if granted {
                configureSession(front: true)
            }
        case .denied, .restricted:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }

    func configureSession(front: Bool) {
        session.beginConfiguration()
        session.sessionPreset = .photo
        session.inputs.forEach { session.removeInput($0) }
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: front ? .front : .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()

        if previewLayer == nil {
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            previewLayer = layer
        }
    }

    func start() { 
        guard isAuthorized else { return }
        if !session.isRunning { 
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning() 
            }
        } 
    }
    func stop() { 
        if session.isRunning { 
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.stopRunning() 
            }
        } 
    }
    func flip() {
        isFront.toggle()
        configureSession(front: isFront)
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.maxPhotoDimensions = output.maxPhotoDimensions
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
