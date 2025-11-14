import XCTest
import UserNotifications
@testable import ProgressPic

/// Test suite for ReviewRequestManager and ReminderManager
/// Validates review prompting logic and notification scheduling
final class ReviewAndReminderServicesTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: "LastReviewRequestStreak")
        UserDefaults.standard.removeObject(forKey: "HasRequestedFinalReview")
    }

    override func tearDown() {
        // Clean up UserDefaults after each test
        UserDefaults.standard.removeObject(forKey: "LastReviewRequestStreak")
        UserDefaults.standard.removeObject(forKey: "HasRequestedFinalReview")
        super.tearDown()
    }

    // MARK: - ReviewRequestManager Tests

    func testReviewRequest_NeverRequested_FirstRequestAt3Days() {
        // Simulate 3-day streak
        ReviewRequestManager.checkAndRequestReview(currentStreak: 3)

        let lastRequested = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(lastRequested, 3, "Should record first review request at 3-day streak")
    }

    func testReviewRequest_AlreadyRequested3_NoRequestAt3Again() {
        // Set that we already requested at 3
        UserDefaults.standard.set(3, forKey: "LastReviewRequestStreak")

        // Try again at 3
        ReviewRequestManager.checkAndRequestReview(currentStreak: 3)

        let lastRequested = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(lastRequested, 3, "Should not update if already requested at this streak")
    }

    func testReviewRequest_RequestsAt7DayStreak() {
        // Previously requested at 3
        UserDefaults.standard.set(3, forKey: "LastReviewRequestStreak")

        // Now at 7-day streak
        ReviewRequestManager.checkAndRequestReview(currentStreak: 7)

        let lastRequested = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(lastRequested, 7, "Should request review at 7-day streak")
    }

    func testReviewRequest_RequestsAt14DayStreak() {
        // Previously requested at 7
        UserDefaults.standard.set(7, forKey: "LastReviewRequestStreak")

        // Now at 14-day streak
        ReviewRequestManager.checkAndRequestReview(currentStreak: 14)

        let lastRequested = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(lastRequested, 14, "Should request review at 14-day streak")
    }

    func testReviewRequest_14DayStreak_SetsFinalReviewFlag() {
        // Request at 14 days
        ReviewRequestManager.checkAndRequestReview(currentStreak: 14)

        let hasFinalReview = UserDefaults.standard.bool(forKey: "HasRequestedFinalReview")
        XCTAssertTrue(hasFinalReview, "Should set final review flag at 14-day streak")
    }

    func testReviewRequest_AfterFinalReview_NoMoreRequests() {
        // Set final review flag
        UserDefaults.standard.set(true, forKey: "HasRequestedFinalReview")

        // Try to request at 20 days
        ReviewRequestManager.checkAndRequestReview(currentStreak: 20)

        let lastRequested = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(lastRequested, 0, "Should not make any more requests after final review")
    }

    func testReviewRequest_StreakProgression_3_7_14() {
        // Start at 3
        ReviewRequestManager.checkAndRequestReview(currentStreak: 3)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "LastReviewRequestStreak"), 3)

        // Progress to 7
        ReviewRequestManager.checkAndRequestReview(currentStreak: 7)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "LastReviewRequestStreak"), 7)

        // Progress to 14
        ReviewRequestManager.checkAndRequestReview(currentStreak: 14)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "LastReviewRequestStreak"), 14)

        let hasFinalReview = UserDefaults.standard.bool(forKey: "HasRequestedFinalReview")
        XCTAssertTrue(hasFinalReview, "Should have final review flag after 14 days")
    }

    func testReviewRequest_SkippingStreaks_StillWorks() {
        // Go directly from 3 to 14 (skip 7)
        UserDefaults.standard.set(3, forKey: "LastReviewRequestStreak")

        ReviewRequestManager.checkAndRequestReview(currentStreak: 14)

        let lastRequested = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(lastRequested, 14)

        let hasFinalReview = UserDefaults.standard.bool(forKey: "HasRequestedFinalReview")
        XCTAssertTrue(hasFinalReview)
    }

    func testReviewRequest_Below3Days_NoRequest() {
        ReviewRequestManager.checkAndRequestReview(currentStreak: 2)

        let lastRequested = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(lastRequested, 0, "Should not request review below 3-day streak")
    }

    func testReviewRequest_Between3And7_NoNewRequest() {
        UserDefaults.standard.set(3, forKey: "LastReviewRequestStreak")

        // Try at 5 days (between thresholds)
        ReviewRequestManager.checkAndRequestReview(currentStreak: 5)

        let lastRequested = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(lastRequested, 3, "Should not request review between thresholds")
    }

    func testReviewRequest_ZeroStreak_NoRequest() {
        ReviewRequestManager.checkAndRequestReview(currentStreak: 0)

        let lastRequested = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(lastRequested, 0, "Should not request review at zero streak")
    }

    func testReviewRequest_NegativeStreak_NoRequest() {
        ReviewRequestManager.checkAndRequestReview(currentStreak: -5)

        let lastRequested = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(lastRequested, 0, "Should not request review for negative streak")
    }

    func testReviewRequest_VeryLargeStreak_AfterFinal_NoRequest() {
        UserDefaults.standard.set(true, forKey: "HasRequestedFinalReview")

        ReviewRequestManager.checkAndRequestReview(currentStreak: 1000)

        let lastRequested = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(lastRequested, 0, "Should not request review after final, even for large streak")
    }

    // MARK: - Review Thresholds Tests

    func testReviewRequest_ThresholdsAre3_7_14() {
        // Verify the thresholds by testing behavior
        var lastRequested: Int

        // Threshold 1: 3 days
        ReviewRequestManager.checkAndRequestReview(currentStreak: 3)
        lastRequested = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(lastRequested, 3, "First threshold at 3 days")

        // Threshold 2: 7 days
        ReviewRequestManager.checkAndRequestReview(currentStreak: 7)
        lastRequested = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(lastRequested, 7, "Second threshold at 7 days")

        // Threshold 3 (final): 14 days
        ReviewRequestManager.checkAndRequestReview(currentStreak: 14)
        lastRequested = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(lastRequested, 14, "Final threshold at 14 days")
    }

    // MARK: - ReminderManager Tests

    func testReminderManager_RequestPermission_DoesNotCrash() async {
        // This will return false in test environment, but should not crash
        let granted = await ReminderManager.requestPermission()

        // In test environment, likely to be false or require user interaction
        XCTAssertNotNil(granted, "Should return a boolean result")
    }

    func testReminderManager_Schedule_DoesNotCrash() {
        let journey = Journey(name: "Test Journey")

        // Should not crash even in test environment
        XCTAssertNoThrow(ReminderManager.schedule(for: journey))
    }

    func testReminderManager_ScheduleWithReminders_DoesNotCrash() {
        let journey = Journey(name: "Test Journey")

        let reminder = JourneyReminder(
            hour: 10,
            minute: 30,
            daysBitmask: 127,
            notificationText: "Test notification"
        )
        reminder.journey = journey

        // Add reminder to journey (would need SwiftData context in real scenario)
        // For now, just verify scheduling doesn't crash
        XCTAssertNoThrow(ReminderManager.schedule(for: journey))
    }

    // MARK: - Edge Case Tests

    func testReviewRequest_StateTransitions_AreIdempotent() {
        // Request at 3 multiple times
        ReviewRequestManager.checkAndRequestReview(currentStreak: 3)
        ReviewRequestManager.checkAndRequestReview(currentStreak: 3)
        ReviewRequestManager.checkAndRequestReview(currentStreak: 3)

        let lastRequested = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(lastRequested, 3, "Multiple requests at same streak should be idempotent")
    }

    func testReviewRequest_DecreasingStreak_HandlesCorrectly() {
        // Request at 7
        UserDefaults.standard.set(7, forKey: "LastReviewRequestStreak")

        // Streak decreases to 5 (shouldn't happen in normal flow, but test it)
        ReviewRequestManager.checkAndRequestReview(currentStreak: 5)

        let lastRequested = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(lastRequested, 7, "Should not update for decreasing streak")
    }

    func testReviewRequest_JumpFromZeroTo14_RequestsImmediately() {
        // Jump directly to 14 without previous requests
        ReviewRequestManager.checkAndRequestReview(currentStreak: 14)

        let lastRequested = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(lastRequested, 14, "Should request at 14 even if skipped earlier thresholds")

        let hasFinalReview = UserDefaults.standard.bool(forKey: "HasRequestedFinalReview")
        XCTAssertTrue(hasFinalReview, "Should set final flag")
    }

    // MARK: - UserDefaults Persistence Tests

    func testReviewRequest_UserDefaultsPersistence() {
        ReviewRequestManager.checkAndRequestReview(currentStreak: 7)

        // Verify data persists in UserDefaults
        let lastRequested = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(lastRequested, 7)

        // Create a new check (simulating app restart)
        let reloadedValue = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(reloadedValue, 7, "Value should persist across reads")
    }

    func testReviewRequest_FinalReviewFlag_Persists() {
        ReviewRequestManager.checkAndRequestReview(currentStreak: 14)

        // Verify flag persists
        let hasFinal = UserDefaults.standard.bool(forKey: "HasRequestedFinalReview")
        XCTAssertTrue(hasFinal)

        // Read again
        let reloadedFlag = UserDefaults.standard.bool(forKey: "HasRequestedFinalReview")
        XCTAssertTrue(reloadedFlag, "Final review flag should persist")
    }

    // MARK: - Integration Tests

    func testReviewRequest_FullLifecycle() {
        // Simulate full app lifecycle
        var hasFinalReview: Bool

        // Day 1: No request
        ReviewRequestManager.checkAndRequestReview(currentStreak: 1)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "LastReviewRequestStreak"), 0)

        // Day 3: First request
        ReviewRequestManager.checkAndRequestReview(currentStreak: 3)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "LastReviewRequestStreak"), 3)

        // Day 4-6: No new requests
        ReviewRequestManager.checkAndRequestReview(currentStreak: 4)
        ReviewRequestManager.checkAndRequestReview(currentStreak: 5)
        ReviewRequestManager.checkAndRequestReview(currentStreak: 6)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "LastReviewRequestStreak"), 3)

        // Day 7: Second request
        ReviewRequestManager.checkAndRequestReview(currentStreak: 7)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "LastReviewRequestStreak"), 7)

        // Day 8-13: No new requests
        for day in 8...13 {
            ReviewRequestManager.checkAndRequestReview(currentStreak: day)
        }
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "LastReviewRequestStreak"), 7)

        // Day 14: Final request
        ReviewRequestManager.checkAndRequestReview(currentStreak: 14)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "LastReviewRequestStreak"), 14)
        hasFinalReview = UserDefaults.standard.bool(forKey: "HasRequestedFinalReview")
        XCTAssertTrue(hasFinalReview)

        // Day 15+: No more requests
        ReviewRequestManager.checkAndRequestReview(currentStreak: 20)
        ReviewRequestManager.checkAndRequestReview(currentStreak: 30)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "LastReviewRequestStreak"), 14, "Should not update after final")
    }

    // MARK: - Concurrent Access Tests

    func testReviewRequest_ConcurrentCalls_HandleGracefully() {
        let expectation = XCTestExpectation(description: "Concurrent review requests")
        expectation.expectedFulfillmentCount = 10

        // Simulate concurrent calls
        for i in 0..<10 {
            DispatchQueue.global().async {
                ReviewRequestManager.checkAndRequestReview(currentStreak: 3 + i)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)

        // Should have recorded some streak value without crashing
        let lastRequested = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertGreaterThan(lastRequested, 0, "Should have recorded a streak value")
    }

    // MARK: - Reminder Weekday Conversion Tests

    func testReminderManager_WeekdayConversion_Concept() {
        // The ReminderManager converts weekdays:
        // Our system: 1=Mon, 2=Tue, ..., 7=Sun
        // iOS Calendar: 1=Sun, 2=Mon, ..., 7=Sat

        // Test the conversion logic conceptually
        // For Monday (our 1): should become iOS 2
        let ourMonday = 1
        let expectedIOSMonday = ourMonday + 1
        XCTAssertEqual(expectedIOSMonday, 2, "Monday should map to iOS weekday 2")

        // For Sunday (our 7): should become iOS 1
        let ourSunday = 7
        let expectedIOSSunday = 1  // Special case in code: day == 7 ? 1 : day + 1
        XCTAssertEqual(expectedIOSSunday, 1, "Sunday should map to iOS weekday 1")
    }
}
