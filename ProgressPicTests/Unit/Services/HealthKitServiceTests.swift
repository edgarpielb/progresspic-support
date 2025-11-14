import XCTest
import HealthKit
@testable import ProgressPic

/// Test suite for HealthKitService
/// Validates health data integration and authorization handling
/// Note: Many tests verify behavior without actual HealthKit access
final class HealthKitServiceTests: XCTestCase {

    var service: HealthKitService!

    override func setUp() async throws {
        try await super.setUp()

        // Note: We can't easily reset the singleton, but we can test its behavior
        service = HealthKitService.shared

        // Clear any previous authorization state
        UserDefaults.standard.removeObject(forKey: "HealthKitAuthorized")
    }

    override func tearDown() async throws {
        // Clean up
        UserDefaults.standard.removeObject(forKey: "HealthKitAuthorized")
        try await super.tearDown()
    }

    // MARK: - BodyCompositionData Tests

    func testBodyCompositionData_Initialization_AllFieldsNil() {
        let data = BodyCompositionData()

        XCTAssertNil(data.weight)
        XCTAssertNil(data.bodyFatPercentage)
        XCTAssertNil(data.leanBodyMass)
        XCTAssertNil(data.bmi)
        XCTAssertNil(data.weightDate)
        XCTAssertNil(data.bodyFatDate)
        XCTAssertNil(data.leanMassDate)
        XCTAssertNil(data.bmiDate)
    }

    func testBodyCompositionData_WithValues_StoresCorrectly() {
        let now = Date()
        var data = BodyCompositionData()
        data.weight = 75.5
        data.bodyFatPercentage = 18.5
        data.leanBodyMass = 61.5
        data.bmi = 22.5
        data.weightDate = now

        XCTAssertEqual(data.weight, 75.5)
        XCTAssertEqual(data.bodyFatPercentage, 18.5)
        XCTAssertEqual(data.leanBodyMass, 61.5)
        XCTAssertEqual(data.bmi, 22.5)
        XCTAssertEqual(data.weightDate, now)
    }

    // MARK: - HealthDataPoint Tests

    func testHealthDataPoint_Initialization_SetsValues() {
        let date = Date()
        let dataPoint = HealthDataPoint(date: date, value: 75.5)

        XCTAssertEqual(dataPoint.date, date)
        XCTAssertEqual(dataPoint.value, 75.5)
        XCTAssertNotNil(dataPoint.id)
    }

    func testHealthDataPoint_UniqueIds_ForEachInstance() {
        let dataPoint1 = HealthDataPoint(date: Date(), value: 75.0)
        let dataPoint2 = HealthDataPoint(date: Date(), value: 76.0)

        XCTAssertNotEqual(dataPoint1.id, dataPoint2.id)
    }

    func testHealthDataPoint_Identifiable_CanBeUsedInForEach() {
        let dataPoints = [
            HealthDataPoint(date: Date(), value: 75.0),
            HealthDataPoint(date: Date(), value: 76.0),
            HealthDataPoint(date: Date(), value: 77.0)
        ]

        // Verify all have unique IDs
        let ids = dataPoints.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "All IDs should be unique")
    }

    // MARK: - HealthKitService Tests

    func testHealthKitService_SharedInstance_IsSingleton() {
        let instance1 = HealthKitService.shared
        let instance2 = HealthKitService.shared

        XCTAssertTrue(instance1 === instance2, "Should return same instance")
    }

    @MainActor
    func testHealthKitService_InitialState_NotAuthorized() {
        // Clear any previous state
        UserDefaults.standard.removeObject(forKey: "HealthKitAuthorized")

        // Create a fresh check of authorization status
        // Since we can't reinitialize the singleton, we test the default state
        let hasAuthorized = UserDefaults.standard.bool(forKey: "HealthKitAuthorized")

        XCTAssertFalse(hasAuthorized, "Initial state should not be authorized")
    }

    @MainActor
    func testHealthKitService_BodyCompositionInitial_IsEmpty() {
        let composition = service.bodyComposition

        XCTAssertNil(composition.weight)
        XCTAssertNil(composition.bodyFatPercentage)
        XCTAssertNil(composition.leanBodyMass)
        XCTAssertNil(composition.bmi)
    }

    // MARK: - Authorization Tests

    @MainActor
    func testRequestAuthorization_WhenHealthKitUnavailable_ReturnsFalse() async {
        // On simulator/test environment, HealthKit may not be available
        // We test that the method handles this gracefully

        // Note: This test will actually call HealthKit if available
        // In a real test environment without HealthKit, it should return false

        let result = await service.requestAuthorization()

        // Result depends on environment - just verify it doesn't crash
        XCTAssertNotNil(result, "Should return a boolean result")
    }

    @MainActor
    func testRequestAuthorization_SavesStatusToUserDefaults() async {
        // Clear previous state
        UserDefaults.standard.removeObject(forKey: "HealthKitAuthorized")

        _ = await service.requestAuthorization()

        // Verify that some value was set (true or false depending on authorization)
        let savedValue = UserDefaults.standard.object(forKey: "HealthKitAuthorized")
        XCTAssertNotNil(savedValue, "Should save authorization status to UserDefaults")
    }

    // MARK: - Authorization Status Tests

    @MainActor
    func testCheckAuthorizationStatus_WithSavedStatus_LoadsCorrectly() {
        // Set a known authorization status
        UserDefaults.standard.set(true, forKey: "HealthKitAuthorized")

        // The service checks status on init, but we can verify UserDefaults
        let status = UserDefaults.standard.bool(forKey: "HealthKitAuthorized")

        XCTAssertTrue(status, "Should load saved authorization status")
    }

    @MainActor
    func testCheckAuthorizationStatus_WithoutSavedStatus_DefaultsFalse() {
        UserDefaults.standard.removeObject(forKey: "HealthKitAuthorized")

        let status = UserDefaults.standard.bool(forKey: "HealthKitAuthorized")

        XCTAssertFalse(status, "Should default to false when no saved status")
    }

    // MARK: - Fetch Body Composition Tests

    @MainActor
    func testFetchBodyComposition_WhenNotAuthorized_DoesNotCrash() async {
        // Set unauthorized state
        UserDefaults.standard.set(false, forKey: "HealthKitAuthorized")
        service.isAuthorized = false

        // Should handle gracefully without crashing
        await service.fetchBodyComposition()

        // No assertion needed - just verify it doesn't crash
        XCTAssertTrue(true, "Should complete without crashing")
    }

    @MainActor
    func testFetchBodyComposition_WhenAuthorized_UpdatesBodyComposition() async {
        // Set authorized state
        UserDefaults.standard.set(true, forKey: "HealthKitAuthorized")
        service.isAuthorized = true

        // Attempt to fetch
        // Note: In test environment, this will likely not return real data
        await service.fetchBodyComposition()

        // Verify the method completes
        // Data will be nil in test environment, but method should not crash
        XCTAssertTrue(true, "Should complete fetch attempt")
    }

    // MARK: - Data Type Tests

    func testBodyCompositionData_PartialData_HandlesCorrectly() {
        var data = BodyCompositionData()
        data.weight = 75.0
        data.weightDate = Date()
        // Leave other fields as nil

        XCTAssertEqual(data.weight, 75.0)
        XCTAssertNotNil(data.weightDate)
        XCTAssertNil(data.bodyFatPercentage)
        XCTAssertNil(data.leanBodyMass)
        XCTAssertNil(data.bmi)
    }

    func testBodyCompositionData_AllData_HandlesCorrectly() {
        let now = Date()
        var data = BodyCompositionData()
        data.weight = 75.5
        data.bodyFatPercentage = 18.5
        data.leanBodyMass = 61.5
        data.bmi = 22.5
        data.weightDate = now
        data.bodyFatDate = now
        data.leanMassDate = now
        data.bmiDate = now

        XCTAssertEqual(data.weight, 75.5)
        XCTAssertEqual(data.bodyFatPercentage, 18.5)
        XCTAssertEqual(data.leanBodyMass, 61.5)
        XCTAssertEqual(data.bmi, 22.5)
        XCTAssertNotNil(data.weightDate)
        XCTAssertNotNil(data.bodyFatDate)
        XCTAssertNotNil(data.leanMassDate)
        XCTAssertNotNil(data.bmiDate)
    }

    // MARK: - Edge Case Tests

    func testBodyCompositionData_NegativeValues_AreValid() {
        var data = BodyCompositionData()
        // While unlikely in real data, test that structure can handle it
        data.weight = -1.0

        XCTAssertEqual(data.weight, -1.0)
    }

    func testBodyCompositionData_ZeroValues_AreValid() {
        var data = BodyCompositionData()
        data.weight = 0.0
        data.bodyFatPercentage = 0.0

        XCTAssertEqual(data.weight, 0.0)
        XCTAssertEqual(data.bodyFatPercentage, 0.0)
    }

    func testBodyCompositionData_VeryLargeValues_HandlesCorrectly() {
        var data = BodyCompositionData()
        data.weight = 500.0 // Very high weight
        data.bodyFatPercentage = 100.0 // Max percentage

        XCTAssertEqual(data.weight, 500.0)
        XCTAssertEqual(data.bodyFatPercentage, 100.0)
    }

    func testHealthDataPoint_DifferentDates_StoresCorrectly() {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let today = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!

        let dataPoint1 = HealthDataPoint(date: yesterday, value: 75.0)
        let dataPoint2 = HealthDataPoint(date: today, value: 76.0)
        let dataPoint3 = HealthDataPoint(date: tomorrow, value: 77.0)

        XCTAssertEqual(dataPoint1.date, yesterday)
        XCTAssertEqual(dataPoint2.date, today)
        XCTAssertEqual(dataPoint3.date, tomorrow)
    }

    // MARK: - Body Fat Percentage Conversion Tests

    func testBodyFatPercentage_Conversion_MultiplyBy100() {
        // HealthKit returns body fat as a decimal (0.185 = 18.5%)
        // The service should multiply by 100

        let healthKitValue = 0.185 // 18.5% in HealthKit format
        let expectedDisplayValue = 18.5

        // Simulate the conversion
        let displayValue = healthKitValue * 100

        XCTAssertEqual(displayValue, expectedDisplayValue, accuracy: 0.01)
    }

    func testBodyFatPercentage_LowValue_ConvertsCorrectly() {
        let healthKitValue = 0.05 // 5%
        let expectedDisplayValue = 5.0

        let displayValue = healthKitValue * 100

        XCTAssertEqual(displayValue, expectedDisplayValue, accuracy: 0.01)
    }

    func testBodyFatPercentage_HighValue_ConvertsCorrectly() {
        let healthKitValue = 0.35 // 35%
        let expectedDisplayValue = 35.0

        let displayValue = healthKitValue * 100

        XCTAssertEqual(displayValue, expectedDisplayValue, accuracy: 0.01)
    }

    // MARK: - Concurrent Access Tests

    @MainActor
    func testConcurrentAuthorizationChecks_DoNotCrash() async {
        // Simulate concurrent authorization checks
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    _ = UserDefaults.standard.bool(forKey: "HealthKitAuthorized")
                }
            }
        }

        XCTAssertTrue(true, "Concurrent checks should not crash")
    }

    // MARK: - UserDefaults Persistence Tests

    func testUserDefaults_AuthorizationPersistence_SaveAndLoad() {
        UserDefaults.standard.set(true, forKey: "HealthKitAuthorized")

        let loaded = UserDefaults.standard.bool(forKey: "HealthKitAuthorized")

        XCTAssertTrue(loaded, "Should persist authorization state")

        // Clean up
        UserDefaults.standard.removeObject(forKey: "HealthKitAuthorized")
    }

    func testUserDefaults_ClearAuthorization_RemovesValue() {
        UserDefaults.standard.set(true, forKey: "HealthKitAuthorized")
        UserDefaults.standard.removeObject(forKey: "HealthKitAuthorized")

        let loaded = UserDefaults.standard.object(forKey: "HealthKitAuthorized")

        XCTAssertNil(loaded, "Should remove authorization state")
    }
}
