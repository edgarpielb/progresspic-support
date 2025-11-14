import XCTest
@testable import ProgressPic

/// Test suite for HapticFeedback utility
/// Validates that haptic feedback methods can be called without crashing
/// Note: Actual haptic feedback cannot be verified in unit tests,
/// but we ensure the API is functional and doesn't cause crashes
final class HapticFeedbackTests: XCTestCase {

    // MARK: - Impact Feedback Tests

    func testImpact_DefaultStyle_DoesNotCrash() {
        // Should not crash when called
        XCTAssertNoThrow(HapticFeedback.impact())
    }

    func testImpact_LightStyle_DoesNotCrash() {
        XCTAssertNoThrow(HapticFeedback.impact(.light))
    }

    func testImpact_MediumStyle_DoesNotCrash() {
        XCTAssertNoThrow(HapticFeedback.impact(.medium))
    }

    func testImpact_HeavyStyle_DoesNotCrash() {
        XCTAssertNoThrow(HapticFeedback.impact(.heavy))
    }

    func testImpact_SoftStyle_DoesNotCrash() {
        XCTAssertNoThrow(HapticFeedback.impact(.soft))
    }

    func testImpact_RigidStyle_DoesNotCrash() {
        XCTAssertNoThrow(HapticFeedback.impact(.rigid))
    }

    // MARK: - Notification Feedback Tests

    func testNotification_SuccessType_DoesNotCrash() {
        XCTAssertNoThrow(HapticFeedback.notification(.success))
    }

    func testNotification_WarningType_DoesNotCrash() {
        XCTAssertNoThrow(HapticFeedback.notification(.warning))
    }

    func testNotification_ErrorType_DoesNotCrash() {
        XCTAssertNoThrow(HapticFeedback.notification(.error))
    }

    // MARK: - Selection Feedback Tests

    func testSelection_DoesNotCrash() {
        XCTAssertNoThrow(HapticFeedback.selection())
    }

    // MARK: - Convenience Method Tests

    func testSuccess_DoesNotCrash() {
        XCTAssertNoThrow(HapticFeedback.success())
    }

    func testError_DoesNotCrash() {
        XCTAssertNoThrow(HapticFeedback.error())
    }

    func testWarning_DoesNotCrash() {
        XCTAssertNoThrow(HapticFeedback.warning())
    }

    func testLight_DoesNotCrash() {
        XCTAssertNoThrow(HapticFeedback.light())
    }

    func testMedium_DoesNotCrash() {
        XCTAssertNoThrow(HapticFeedback.medium())
    }

    func testHeavy_DoesNotCrash() {
        XCTAssertNoThrow(HapticFeedback.heavy())
    }

    // MARK: - Multiple Calls Tests

    func testMultipleCalls_DoNotCrash() {
        // Simulate rapid haptic feedback calls (common in UI interactions)
        XCTAssertNoThrow({
            HapticFeedback.light()
            HapticFeedback.medium()
            HapticFeedback.heavy()
        }())
    }

    func testSequentialNotifications_DoNotCrash() {
        XCTAssertNoThrow({
            HapticFeedback.success()
            HapticFeedback.warning()
            HapticFeedback.error()
        }())
    }

    func testMixedFeedbackTypes_DoNotCrash() {
        XCTAssertNoThrow({
            HapticFeedback.impact(.light)
            HapticFeedback.selection()
            HapticFeedback.notification(.success)
            HapticFeedback.impact(.heavy)
        }())
    }

    // MARK: - Performance Tests

    func testImpactPerformance_CompletesQuickly() {
        // Haptic feedback should be very fast
        measure {
            for _ in 0..<100 {
                HapticFeedback.impact()
            }
        }
    }

    func testNotificationPerformance_CompletesQuickly() {
        measure {
            for _ in 0..<100 {
                HapticFeedback.notification(.success)
            }
        }
    }

    func testSelectionPerformance_CompletesQuickly() {
        measure {
            for _ in 0..<100 {
                HapticFeedback.selection()
            }
        }
    }

    // MARK: - API Consistency Tests

    func testConvenienceMethods_MatchBaseImplementation() {
        // Verify convenience methods are properly mapped
        // We can't verify the actual haptic output, but we can ensure methods exist and are callable

        // These should all complete without error
        XCTAssertNoThrow(HapticFeedback.light(), "light() should call impact(.light)")
        XCTAssertNoThrow(HapticFeedback.medium(), "medium() should call impact(.medium)")
        XCTAssertNoThrow(HapticFeedback.heavy(), "heavy() should call impact(.heavy)")

        XCTAssertNoThrow(HapticFeedback.success(), "success() should call notification(.success)")
        XCTAssertNoThrow(HapticFeedback.warning(), "warning() should call notification(.warning)")
        XCTAssertNoThrow(HapticFeedback.error(), "error() should call notification(.error)")
    }

    // MARK: - Thread Safety Tests

    func testConcurrentCalls_DoNotCrash() {
        let expectation = XCTestExpectation(description: "Concurrent haptic calls complete")
        expectation.expectedFulfillmentCount = 10

        // Simulate concurrent haptic feedback from multiple threads
        for i in 0..<10 {
            DispatchQueue.global(qos: .userInitiated).async {
                if i % 3 == 0 {
                    HapticFeedback.impact()
                } else if i % 3 == 1 {
                    HapticFeedback.notification(.success)
                } else {
                    HapticFeedback.selection()
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Edge Case Tests

    func testRapidSuccessiveCalls_DoNotCrash() {
        // Test very rapid successive calls (e.g., during fast scrolling)
        XCTAssertNoThrow({
            for _ in 0..<1000 {
                HapticFeedback.selection()
            }
        }())
    }

    func testAllImpactStyles_Exhaustive() {
        let styles: [UIImpactFeedbackGenerator.FeedbackStyle] = [
            .light, .medium, .heavy, .soft, .rigid
        ]

        for style in styles {
            XCTAssertNoThrow(
                HapticFeedback.impact(style),
                "Impact with style \(style) should not crash"
            )
        }
    }

    func testAllNotificationTypes_Exhaustive() {
        let types: [UINotificationFeedbackGenerator.FeedbackType] = [
            .success, .warning, .error
        ]

        for type in types {
            XCTAssertNoThrow(
                HapticFeedback.notification(type),
                "Notification with type \(type) should not crash"
            )
        }
    }
}
