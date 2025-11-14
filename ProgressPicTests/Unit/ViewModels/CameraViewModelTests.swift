import XCTest
@testable import ProgressPic

/// Test suite for CameraViewModel
/// Validates camera view state management, ghost overlay, timer, and error handling
@MainActor
final class CameraViewModelTests: XCTestCase {

    var viewModel: CameraViewModel!

    override func setUp() async throws {
        try await super.setUp()
        viewModel = CameraViewModel()
    }

    override func tearDown() async throws {
        viewModel.cleanup()
        viewModel = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInit_WithoutJourney_SetsDefaults() {
        XCTAssertNil(viewModel.selectedJourney)
        XCTAssertEqual(viewModel.photos.count, 0)
        XCTAssertNil(viewModel.latestPhotoThumbnail)
        XCTAssertFalse(viewModel.ghostEnabled)
        XCTAssertFalse(viewModel.timerActive)
        XCTAssertEqual(viewModel.selectedZoomLevel, 1.0)
        XCTAssertFalse(viewModel.gridEnabled)
        XCTAssertFalse(viewModel.showAdjust)
        XCTAssertFalse(viewModel.showErrorAlert)
    }

    func testInit_WithJourney_SetsJourney() {
        let journey = Journey(name: "Test Journey")
        let vm = CameraViewModel(journey: journey)

        XCTAssertNotNil(vm.selectedJourney)
        XCTAssertEqual(vm.selectedJourney?.name, "Test Journey")
    }

    // MARK: - Ghost Overlay Tests

    func testGhostEnabled_CanBeToggled() {
        XCTAssertFalse(viewModel.ghostEnabled)

        viewModel.ghostEnabled = true
        XCTAssertTrue(viewModel.ghostEnabled)

        viewModel.ghostEnabled = false
        XCTAssertFalse(viewModel.ghostEnabled)
    }

    func testGhostOpacity_DefaultValue() {
        XCTAssertEqual(
            viewModel.ghostOpacity,
            AppConstants.Camera.defaultGhostOpacity,
            "Ghost opacity should default to AppConstants value"
        )
    }

    func testGhostOpacity_CanBeChanged() {
        viewModel.ghostOpacity = 0.5
        XCTAssertEqual(viewModel.ghostOpacity, 0.5)

        viewModel.ghostOpacity = 0.8
        XCTAssertEqual(viewModel.ghostOpacity, 0.8)
    }

    func testUseFirst_DefaultFalse() {
        XCTAssertFalse(viewModel.useFirst, "Should default to using last photo")
    }

    func testToggleGhostPhoto_TogglesUseFirst() {
        XCTAssertFalse(viewModel.useFirst)

        viewModel.toggleGhostPhoto()
        XCTAssertTrue(viewModel.useFirst)

        viewModel.toggleGhostPhoto()
        XCTAssertFalse(viewModel.useFirst)
    }

    func testShowGhostControls_CanBeToggled() {
        XCTAssertFalse(viewModel.showGhostControls)

        viewModel.showGhostControls = true
        XCTAssertTrue(viewModel.showGhostControls)
    }

    func testLoadGhostOverlay_NoJourney_ClearsGhost() async {
        viewModel.lastGhost = createTestImage()
        XCTAssertNotNil(viewModel.lastGhost)

        await viewModel.loadGhostOverlay()

        XCTAssertNil(viewModel.lastGhost, "Should clear ghost when no journey selected")
    }

    func testUpdateJourney_SetsJourneyAndPhotos() {
        let journey = Journey(name: "Updated Journey")
        let photo1 = ProgressPhoto(
            journeyId: journey.id,
            date: Date(),
            assetLocalId: "asset-1",
            isFrontCamera: true
        )
        let photo2 = ProgressPhoto(
            journeyId: journey.id,
            date: Date(),
            assetLocalId: "asset-2",
            isFrontCamera: true
        )

        viewModel.updateJourney(journey, photos: [photo1, photo2])

        XCTAssertEqual(viewModel.selectedJourney?.name, "Updated Journey")
        XCTAssertEqual(viewModel.photos.count, 2)
    }

    // MARK: - Timer Tests

    func testTimerActive_DefaultFalse() {
        XCTAssertFalse(viewModel.timerActive)
    }

    func testTimerSeconds_DefaultZero() {
        XCTAssertEqual(viewModel.timerSeconds, 0)
    }

    func testCountdownSeconds_DefaultZero() {
        XCTAssertEqual(viewModel.countdownSeconds, 0)
    }

    func testStartCountdown_SetsSecondsAndActivatesTimer() {
        viewModel.startCountdown(seconds: 5)

        XCTAssertEqual(viewModel.countdownSeconds, 5)
        XCTAssertTrue(viewModel.timerActive)
    }

    func testCancelTimer_ResetsTimerState() {
        viewModel.startCountdown(seconds: 5)
        XCTAssertTrue(viewModel.timerActive)
        XCTAssertEqual(viewModel.countdownSeconds, 5)

        viewModel.cancelTimer()

        XCTAssertFalse(viewModel.timerActive)
        XCTAssertEqual(viewModel.countdownSeconds, 0)
    }

    func testTickCountdown_DecrementsSeconds() {
        viewModel.startCountdown(seconds: 3)

        viewModel.tickCountdown()
        XCTAssertEqual(viewModel.countdownSeconds, 2)
        XCTAssertTrue(viewModel.timerActive)

        viewModel.tickCountdown()
        XCTAssertEqual(viewModel.countdownSeconds, 1)
        XCTAssertTrue(viewModel.timerActive)

        viewModel.tickCountdown()
        XCTAssertEqual(viewModel.countdownSeconds, 0)
        XCTAssertFalse(viewModel.timerActive, "Timer should deactivate when countdown reaches 0")
    }

    func testTickCountdown_AtZero_DeactivatesTimer() {
        viewModel.startCountdown(seconds: 1)
        viewModel.tickCountdown()

        XCTAssertEqual(viewModel.countdownSeconds, 0)
        XCTAssertFalse(viewModel.timerActive)
    }

    func testShowTimerControls_CanBeToggled() {
        XCTAssertFalse(viewModel.showTimerControls)

        viewModel.showTimerControls = true
        XCTAssertTrue(viewModel.showTimerControls)
    }

    // MARK: - Camera Settings Tests

    func testSelectedZoomLevel_DefaultOne() {
        XCTAssertEqual(viewModel.selectedZoomLevel, 1.0)
    }

    func testSelectedZoomLevel_CanBeChanged() {
        viewModel.selectedZoomLevel = 2.5
        XCTAssertEqual(viewModel.selectedZoomLevel, 2.5)

        viewModel.selectedZoomLevel = 1.5
        XCTAssertEqual(viewModel.selectedZoomLevel, 1.5)
    }

    func testGridEnabled_DefaultFalse() {
        XCTAssertFalse(viewModel.gridEnabled)
    }

    func testGridEnabled_CanBeToggled() {
        viewModel.gridEnabled = true
        XCTAssertTrue(viewModel.gridEnabled)

        viewModel.gridEnabled = false
        XCTAssertFalse(viewModel.gridEnabled)
    }

    // MARK: - UI State Tests

    func testShowAdjust_DefaultFalse() {
        XCTAssertFalse(viewModel.showAdjust)
    }

    func testShowAdjust_CanBeToggled() {
        viewModel.showAdjust = true
        XCTAssertTrue(viewModel.showAdjust)
    }

    func testShowPhotoLibrary_DefaultFalse() {
        XCTAssertFalse(viewModel.showPhotoLibrary)
    }

    func testShowPhotoLibrary_CanBeToggled() {
        viewModel.showPhotoLibrary = true
        XCTAssertTrue(viewModel.showPhotoLibrary)
    }

    func testShowErrorAlert_DefaultFalse() {
        XCTAssertFalse(viewModel.showErrorAlert)
    }

    func testErrorMessage_DefaultEmpty() {
        XCTAssertEqual(viewModel.errorMessage, "")
    }

    // MARK: - Error Handling Tests

    func testShowError_SetsMessageAndShowsAlert() {
        viewModel.showError("Test error message")

        XCTAssertEqual(viewModel.errorMessage, "Test error message")
        XCTAssertTrue(viewModel.showErrorAlert)
    }

    func testClearError_ResetsErrorState() {
        viewModel.showError("Some error")
        XCTAssertTrue(viewModel.showErrorAlert)
        XCTAssertEqual(viewModel.errorMessage, "Some error")

        viewModel.clearError()

        XCTAssertEqual(viewModel.errorMessage, "")
        XCTAssertFalse(viewModel.showErrorAlert)
    }

    func testShowError_MultipleErrors_UpdatesMessage() {
        viewModel.showError("First error")
        XCTAssertEqual(viewModel.errorMessage, "First error")

        viewModel.showError("Second error")
        XCTAssertEqual(viewModel.errorMessage, "Second error")
        XCTAssertTrue(viewModel.showErrorAlert)
    }

    // MARK: - Photos Array Tests

    func testPhotos_InitiallyEmpty() {
        XCTAssertEqual(viewModel.photos.count, 0)
    }

    func testPhotos_CanBeSet() {
        let photo = ProgressPhoto(
            journeyId: UUID(),
            date: Date(),
            assetLocalId: "test-asset",
            isFrontCamera: true
        )

        viewModel.photos = [photo]

        XCTAssertEqual(viewModel.photos.count, 1)
        XCTAssertEqual(viewModel.photos.first?.assetLocalId, "test-asset")
    }

    func testLatestPhotoThumbnail_InitiallyNil() {
        XCTAssertNil(viewModel.latestPhotoThumbnail)
    }

    func testLatestPhotoThumbnail_CanBeSet() {
        let testImage = createTestImage()

        viewModel.latestPhotoThumbnail = testImage

        XCTAssertNotNil(viewModel.latestPhotoThumbnail)
        XCTAssertEqual(viewModel.latestPhotoThumbnail, testImage)
    }

    // MARK: - Cleanup Tests

    func testCleanup_CancelsGhostLoadTask() {
        // Start a ghost load task
        viewModel.ghostLoadTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        XCTAssertNotNil(viewModel.ghostLoadTask)

        viewModel.cleanup()

        XCTAssertNil(viewModel.ghostLoadTask)
    }

    func testCleanup_RemovesObservers() {
        // Set mock observers
        viewModel.orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: nil
        ) { _ in }

        viewModel.backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil
        ) { _ in }

        XCTAssertNotNil(viewModel.orientationObserver)
        XCTAssertNotNil(viewModel.backgroundObserver)

        viewModel.cleanup()

        XCTAssertNil(viewModel.orientationObserver)
        XCTAssertNil(viewModel.backgroundObserver)
    }

    // MARK: - State Combination Tests

    func testState_GhostEnabledWithTimer_BothActive() {
        viewModel.ghostEnabled = true
        viewModel.startCountdown(seconds: 3)

        XCTAssertTrue(viewModel.ghostEnabled)
        XCTAssertTrue(viewModel.timerActive)
        XCTAssertEqual(viewModel.countdownSeconds, 3)
    }

    func testState_MultipleControlPanelsOpen() {
        viewModel.showGhostControls = true
        viewModel.showTimerControls = true

        XCTAssertTrue(viewModel.showGhostControls)
        XCTAssertTrue(viewModel.showTimerControls)
    }

    func testState_ZoomAndGrid_BothEnabled() {
        viewModel.selectedZoomLevel = 2.0
        viewModel.gridEnabled = true

        XCTAssertEqual(viewModel.selectedZoomLevel, 2.0)
        XCTAssertTrue(viewModel.gridEnabled)
    }

    // MARK: - Edge Case Tests

    func testTimer_NegativeSeconds_HandlesGracefully() {
        // Should not crash with negative input
        viewModel.startCountdown(seconds: -5)

        // Countdown value should be set (even if negative)
        XCTAssertEqual(viewModel.countdownSeconds, -5)
        XCTAssertTrue(viewModel.timerActive)
    }

    func testTimer_ZeroSeconds_ActivatesAndImmediatelyDeactivates() {
        viewModel.startCountdown(seconds: 0)

        XCTAssertEqual(viewModel.countdownSeconds, 0)
        XCTAssertTrue(viewModel.timerActive)

        viewModel.tickCountdown()

        XCTAssertFalse(viewModel.timerActive)
    }

    func testTimer_LargeValue_HandlesCorrectly() {
        viewModel.startCountdown(seconds: 1000)

        XCTAssertEqual(viewModel.countdownSeconds, 1000)
        XCTAssertTrue(viewModel.timerActive)
    }

    func testZoom_ExtremeValues_CanBeSet() {
        viewModel.selectedZoomLevel = 0.1
        XCTAssertEqual(viewModel.selectedZoomLevel, 0.1)

        viewModel.selectedZoomLevel = 100.0
        XCTAssertEqual(viewModel.selectedZoomLevel, 100.0)
    }

    func testGhostOpacity_BoundaryValues() {
        viewModel.ghostOpacity = 0.0
        XCTAssertEqual(viewModel.ghostOpacity, 0.0)

        viewModel.ghostOpacity = 1.0
        XCTAssertEqual(viewModel.ghostOpacity, 1.0)
    }

    func testErrorMessage_VeryLongText_StoresCorrectly() {
        let longMessage = String(repeating: "A", count: 1000)
        viewModel.showError(longMessage)

        XCTAssertEqual(viewModel.errorMessage, longMessage)
        XCTAssertTrue(viewModel.showErrorAlert)
    }

    func testErrorMessage_EmptyString_IsValid() {
        viewModel.showError("")

        XCTAssertEqual(viewModel.errorMessage, "")
        XCTAssertTrue(viewModel.showErrorAlert)
    }

    // MARK: - ObservableObject Tests

    func testViewModel_IsObservableObject() {
        let vm = viewModel as Any
        XCTAssertTrue(vm is ObservableObject)
    }

    // MARK: - Multiple Updates Tests

    func testTimer_MultipleCountdowns_WorkCorrectly() {
        viewModel.startCountdown(seconds: 3)
        viewModel.tickCountdown()
        XCTAssertEqual(viewModel.countdownSeconds, 2)

        viewModel.cancelTimer()
        XCTAssertFalse(viewModel.timerActive)

        viewModel.startCountdown(seconds: 5)
        XCTAssertEqual(viewModel.countdownSeconds, 5)
        XCTAssertTrue(viewModel.timerActive)
    }

    func testUpdateJourney_MultipleTimes_UpdatesCorrectly() {
        let journey1 = Journey(name: "Journey 1")
        let journey2 = Journey(name: "Journey 2")

        viewModel.updateJourney(journey1, photos: [])
        XCTAssertEqual(viewModel.selectedJourney?.name, "Journey 1")

        viewModel.updateJourney(journey2, photos: [])
        XCTAssertEqual(viewModel.selectedJourney?.name, "Journey 2")
    }

    // MARK: - Helper Methods

    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Async Operation Tests

    func testLoadGhostOverlay_CancelsOnCleanup() async {
        let journey = Journey(name: "Test")
        viewModel.selectedJourney = journey

        // Start loading ghost
        Task {
            await viewModel.loadGhostOverlay()
        }

        // Immediately cleanup (should cancel the task)
        viewModel.cleanup()

        // Task should be nil after cleanup
        XCTAssertNil(viewModel.ghostLoadTask)
    }
}
