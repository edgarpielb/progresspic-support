//
//  CameraViewModel.swift
//  ProgressPic
//
//  Manages camera view state and business logic
//  Extracted from CameraHostView to reduce complexity
//

import SwiftUI
import SwiftData
import AVFoundation
import Combine

@MainActor
class CameraViewModel: ObservableObject {
    // MARK: - Journey & Photos
    @Published var selectedJourney: Journey?
    @Published var photos: [ProgressPhoto] = []
    @Published var latestPhotoThumbnail: UIImage?

    // MARK: - Ghost Overlay Settings
    @Published var ghostEnabled = false
    @Published var ghostOpacity: Double = AppConstants.Camera.defaultGhostOpacity
    @Published var useFirst = false
    @Published var lastGhost: UIImage?
    @Published var showGhostControls = false
    var ghostLoadTask: Task<Void, Never>?

    // MARK: - Timer Settings
    @Published var timerActive = false
    @Published var timerSeconds = 0
    @Published var countdownSeconds = 0
    @Published var showTimerControls = false

    // MARK: - Camera Settings
    @Published var selectedZoomLevel: CGFloat = 1.0
    @Published var gridEnabled = false

    // MARK: - UI State
    @Published var showAdjust = false
    @Published var showPhotoLibrary = false
    @Published var showErrorAlert = false
    @Published var errorMessage = ""

    // MARK: - Observers
    var orientationObserver: NSObjectProtocol?
    var backgroundObserver: NSObjectProtocol?

    // MARK: - Initialization
    init(journey: Journey? = nil) {
        self.selectedJourney = journey
    }

    // MARK: - Ghost Overlay

    /// Load ghost overlay image from selected journey
    func loadGhostOverlay() async {
        guard let journey = selectedJourney else {
            await MainActor.run {
                lastGhost = nil
            }
            return
        }

        // Cancel previous load task
        ghostLoadTask?.cancel()

        ghostLoadTask = Task {
            guard let photos = journey.photos, !photos.isEmpty else {
                await MainActor.run {
                    lastGhost = nil
                }
                return
            }

            let sortedPhotos = photos.sorted { $0.date < $1.date }
            let targetPhoto = useFirst ? sortedPhotos.first : sortedPhotos.last

            guard let photo = targetPhoto,
                  let img = await PhotoStore.loadFromPhotoLibrary(localId: photo.assetLocalId) else {
                await MainActor.run {
                    lastGhost = nil
                }
                return
            }

            // Check if task was cancelled
            guard !Task.isCancelled else { return }

            await MainActor.run {
                lastGhost = img
            }
        }
    }

    /// Toggle between first and last photo for ghost overlay
    func toggleGhostPhoto() {
        useFirst.toggle()
        Task {
            await loadGhostOverlay()
        }
    }

    /// Update ghost overlay when journey changes
    func updateJourney(_ journey: Journey, photos: [ProgressPhoto]) {
        self.selectedJourney = journey
        self.photos = photos

        if ghostEnabled {
            Task {
                await loadGhostOverlay()
            }
        }
    }

    // MARK: - Timer

    /// Start countdown timer
    func startCountdown(seconds: Int) {
        countdownSeconds = seconds
        timerActive = true
    }

    /// Cancel active timer
    func cancelTimer() {
        timerActive = false
        countdownSeconds = 0
    }

    /// Tick countdown (call every second)
    func tickCountdown() {
        if countdownSeconds > 0 {
            countdownSeconds -= 1
        } else {
            timerActive = false
        }
    }

    // MARK: - Error Handling

    /// Show error alert with message
    func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }

    /// Clear error state
    func clearError() {
        errorMessage = ""
        showErrorAlert = false
    }

    // MARK: - Cleanup

    /// Clean up resources when view disappears
    func cleanup() {
        ghostLoadTask?.cancel()
        ghostLoadTask = nil

        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
            orientationObserver = nil
        }

        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
            backgroundObserver = nil
        }
    }

    nonisolated deinit {
        Task { @MainActor in
            cleanup()
        }
    }
}
