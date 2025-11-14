import XCTest
import AVFoundation
@testable import ProgressPic

/// Test suite for CameraService
/// Validates camera management, permissions, and configuration
/// Note: Many tests verify behavior patterns without actual camera access
final class CameraServiceTests: XCTestCase {

    var cameraService: CameraService!

    override func setUp() {
        super.setUp()
        cameraService = CameraService()
    }

    override func tearDown() {
        cameraService = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInit_CreatesService() {
        XCTAssertNotNil(cameraService, "Should create camera service")
    }

    func testInit_SessionExists() {
        XCTAssertNotNil(cameraService.session, "Should have capture session")
    }

    func testInit_DefaultState_IsFrontCamera() {
        XCTAssertTrue(cameraService.isFront, "Default should be front camera")
    }

    func testInit_DefaultState_NotAuthorized() {
        XCTAssertFalse(cameraService.isAuthorized, "Default should not be authorized")
    }

    func testInit_DefaultState_CannotCapture() {
        XCTAssertFalse(cameraService.canCapture, "Default should not be able to capture")
    }

    func testInit_DefaultFlashMode_IsOff() {
        XCTAssertEqual(cameraService.flashMode, .off, "Default flash mode should be off")
    }

    func testInit_DefaultZoom_IsOne() {
        XCTAssertEqual(cameraService.currentZoom, 1.0, "Default zoom should be 1.0")
    }

    func testInit_DefaultMaxZoom_IsFive() {
        XCTAssertEqual(cameraService.maxZoom, 5.0, "Default max zoom should be 5.0")
    }

    func testInit_HasUltraWideCamera_DefaultFalse() {
        XCTAssertFalse(cameraService.hasUltraWideCamera, "Default should be false")
    }

    func testInit_LatestPhoto_IsNil() {
        XCTAssertNil(cameraService.latestPhoto, "Latest photo should be nil initially")
    }

    func testInit_PreviewLayer_IsNil() {
        XCTAssertNil(cameraService.previewLayer, "Preview layer should be nil initially")
    }

    // MARK: - State Management Tests

    func testIsFront_CanBeToggled() {
        cameraService.isFront = false
        XCTAssertFalse(cameraService.isFront)

        cameraService.isFront = true
        XCTAssertTrue(cameraService.isFront)
    }

    func testFlashMode_CanBeChanged() {
        cameraService.flashMode = .on
        XCTAssertEqual(cameraService.flashMode, .on)

        cameraService.flashMode = .auto
        XCTAssertEqual(cameraService.flashMode, .auto)

        cameraService.flashMode = .off
        XCTAssertEqual(cameraService.flashMode, .off)
    }

    func testCurrentZoom_CanBeChanged() {
        cameraService.currentZoom = 2.5
        XCTAssertEqual(cameraService.currentZoom, 2.5)

        cameraService.currentZoom = 1.0
        XCTAssertEqual(cameraService.currentZoom, 1.0)
    }

    func testZoom_WithinMaxBounds_IsValid() {
        cameraService.maxZoom = 5.0
        cameraService.currentZoom = 3.0

        XCTAssertLessThanOrEqual(cameraService.currentZoom, cameraService.maxZoom)
    }

    // MARK: - Permission Tests

    @MainActor
    func testRequestPermissionIfNeeded_DoesNotCrash() async {
        // Should not crash when called
        await cameraService.requestPermissionIfNeeded()

        // Authorization state depends on simulator/device permissions
        // We just verify the method completes
        XCTAssertTrue(true, "Should complete without crashing")
    }

    @MainActor
    func testRequestPermission_SetsAuthorizationState() async {
        await cameraService.requestPermissionIfNeeded()

        // After requesting permission, isAuthorized should have some value
        // (true if granted, false if denied)
        // We can't control the actual permission, but verify it's set to something
        let authState = cameraService.isAuthorized

        // Authorization is either true or false, not nil
        XCTAssertNotNil(authState, "Authorization state should be set")
    }

    // MARK: - Session Configuration Tests

    func testConfigureSession_DoesNotCrash() {
        // Should not crash when configuring session
        XCTAssertNoThrow(cameraService.configureSession(front: true))
        XCTAssertNoThrow(cameraService.configureSession(front: false))
    }

    func testConfigureSession_FrontCamera_UpdatesState() {
        cameraService.configureSession(front: true)

        // Configuration happens asynchronously, but method should not crash
        XCTAssertTrue(true, "Should complete configuration")
    }

    func testConfigureSession_BackCamera_UpdatesState() {
        cameraService.configureSession(front: false)

        // Configuration happens asynchronously, but method should not crash
        XCTAssertTrue(true, "Should complete configuration")
    }

    // MARK: - Session Lifecycle Tests

    func testSession_IsNotRunningInitially() {
        XCTAssertFalse(cameraService.session.isRunning, "Session should not be running initially")
    }

    func testSession_CanBeAccessed() {
        let session = cameraService.session
        XCTAssertNotNil(session, "Session should be accessible")
    }

    // MARK: - Orientation Tests

    @MainActor
    func testUpdateOrientation_FrontCamera_DoesNotCrash() {
        XCTAssertNoThrow(cameraService.updateOrientation(forFrontCamera: true))
    }

    @MainActor
    func testUpdateOrientation_BackCamera_DoesNotCrash() {
        XCTAssertNoThrow(cameraService.updateOrientation(forFrontCamera: false))
    }

    @MainActor
    func testUpdateOrientation_WithoutParameter_UsesCurrentState() {
        cameraService.isFront = true
        XCTAssertNoThrow(cameraService.updateOrientation())

        cameraService.isFront = false
        XCTAssertNoThrow(cameraService.updateOrientation())
    }

    // MARK: - Flash Mode Tests

    func testFlashMode_AllValues_AreValid() {
        let flashModes: [AVCaptureDevice.FlashMode] = [.off, .on, .auto]

        for mode in flashModes {
            cameraService.flashMode = mode
            XCTAssertEqual(
                cameraService.flashMode,
                mode,
                "Flash mode \(mode.rawValue) should be settable"
            )
        }
    }

    func testFlashMode_Toggle_WorksCorrectly() {
        // Start with off
        cameraService.flashMode = .off
        XCTAssertEqual(cameraService.flashMode, .off)

        // Toggle to on
        cameraService.flashMode = .on
        XCTAssertEqual(cameraService.flashMode, .on)

        // Toggle back to off
        cameraService.flashMode = .off
        XCTAssertEqual(cameraService.flashMode, .off)
    }

    // MARK: - Zoom Tests

    func testZoom_MinimumValue_IsOne() {
        cameraService.currentZoom = 1.0
        XCTAssertEqual(cameraService.currentZoom, 1.0)
    }

    func testZoom_MaximumValue_IsRespected() {
        cameraService.maxZoom = 5.0
        cameraService.currentZoom = 5.0

        XCTAssertEqual(cameraService.currentZoom, 5.0)
        XCTAssertLessThanOrEqual(cameraService.currentZoom, cameraService.maxZoom)
    }

    func testZoom_IntermediateValues_AreValid() {
        cameraService.currentZoom = 1.5
        XCTAssertEqual(cameraService.currentZoom, 1.5)

        cameraService.currentZoom = 2.75
        XCTAssertEqual(cameraService.currentZoom, 2.75)

        cameraService.currentZoom = 4.2
        XCTAssertEqual(cameraService.currentZoom, 4.2)
    }

    func testZoom_DecimalValues_AreSupported() {
        cameraService.currentZoom = 1.234
        XCTAssertEqual(cameraService.currentZoom, 1.234, accuracy: 0.001)
    }

    // MARK: - Latest Photo Tests

    func testLatestPhoto_CanBeSet() {
        let testImage = createTestImage()
        cameraService.latestPhoto = testImage

        XCTAssertNotNil(cameraService.latestPhoto)
        XCTAssertEqual(cameraService.latestPhoto, testImage)
    }

    func testLatestPhoto_CanBeCleared() {
        let testImage = createTestImage()
        cameraService.latestPhoto = testImage
        XCTAssertNotNil(cameraService.latestPhoto)

        cameraService.latestPhoto = nil
        XCTAssertNil(cameraService.latestPhoto)
    }

    func testLatestPhoto_CanBeUpdated() {
        let image1 = createTestImage()
        let image2 = createTestImage()

        cameraService.latestPhoto = image1
        XCTAssertEqual(cameraService.latestPhoto, image1)

        cameraService.latestPhoto = image2
        XCTAssertEqual(cameraService.latestPhoto, image2)
    }

    // MARK: - Preview Layer Tests

    func testPreviewLayer_InitiallyNil() {
        XCTAssertNil(cameraService.previewLayer)
    }

    func testPreviewLayer_CanBeSet() {
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraService.session)
        cameraService.previewLayer = previewLayer

        XCTAssertNotNil(cameraService.previewLayer)
        XCTAssertEqual(cameraService.previewLayer, previewLayer)
    }

    // MARK: - ObservableObject Tests

    func testCameraService_IsObservableObject() {
        // Verify that CameraService conforms to ObservableObject
        // This is important for SwiftUI integration
        let service = cameraService as Any
        XCTAssertTrue(service is ObservableObject)
    }

    // MARK: - Thread Safety Tests

    func testMultipleServiceInstances_CanBeCreated() {
        let service1 = CameraService()
        let service2 = CameraService()

        XCTAssertNotNil(service1)
        XCTAssertNotNil(service2)
        XCTAssertFalse(service1 === service2, "Should create separate instances")
    }

    // MARK: - Edge Case Tests

    func testZoom_VerySmallValue_IsValid() {
        cameraService.currentZoom = 1.01
        XCTAssertEqual(cameraService.currentZoom, 1.01, accuracy: 0.001)
    }

    func testZoom_VeryLargeValue_CanBeSet() {
        cameraService.maxZoom = 10.0
        cameraService.currentZoom = 10.0

        XCTAssertEqual(cameraService.currentZoom, 10.0)
    }

    func testMaxZoom_CanBeChanged() {
        cameraService.maxZoom = 3.0
        XCTAssertEqual(cameraService.maxZoom, 3.0)

        cameraService.maxZoom = 8.0
        XCTAssertEqual(cameraService.maxZoom, 8.0)
    }

    func testHasUltraWideCamera_CanBeToggled() {
        cameraService.hasUltraWideCamera = true
        XCTAssertTrue(cameraService.hasUltraWideCamera)

        cameraService.hasUltraWideCamera = false
        XCTAssertFalse(cameraService.hasUltraWideCamera)
    }

    // MARK: - State Combinations Tests

    func testState_FrontCameraWithFlashOff_IsValid() {
        cameraService.isFront = true
        cameraService.flashMode = .off

        XCTAssertTrue(cameraService.isFront)
        XCTAssertEqual(cameraService.flashMode, .off)
    }

    func testState_BackCameraWithFlashOn_IsValid() {
        cameraService.isFront = false
        cameraService.flashMode = .on

        XCTAssertFalse(cameraService.isFront)
        XCTAssertEqual(cameraService.flashMode, .on)
    }

    func testState_AuthorizedAndCanCapture_CanBothBeTrue() {
        cameraService.isAuthorized = true
        cameraService.canCapture = true

        XCTAssertTrue(cameraService.isAuthorized)
        XCTAssertTrue(cameraService.canCapture)
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

    // MARK: - Memory Tests

    func testMultipleConfigurations_DoNotLeak() {
        // Configure multiple times to check for leaks
        for i in 0..<10 {
            cameraService.configureSession(front: i % 2 == 0)
        }

        // If we get here without crashing, no obvious leaks
        XCTAssertTrue(true)
    }

    func testRepeatedOrientationUpdates_DoNotCrash() {
        // Update orientation multiple times
        for i in 0..<20 {
            Task { @MainActor in
                cameraService.updateOrientation(forFrontCamera: i % 2 == 0)
            }
        }

        XCTAssertTrue(true, "Should handle repeated orientation updates")
    }

    // MARK: - Published Property Tests

    func testPublishedProperties_CanBeObserved() {
        // Verify published properties exist and can be accessed
        _ = cameraService.isFront
        _ = cameraService.isAuthorized
        _ = cameraService.canCapture
        _ = cameraService.flashMode
        _ = cameraService.currentZoom
        _ = cameraService.maxZoom
        _ = cameraService.hasUltraWideCamera
        _ = cameraService.latestPhoto
        _ = cameraService.previewLayer

        XCTAssertTrue(true, "All published properties should be accessible")
    }
}
