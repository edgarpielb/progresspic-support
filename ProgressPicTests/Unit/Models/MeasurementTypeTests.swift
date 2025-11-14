import XCTest
@testable import ProgressPic

/// Test suite for MeasurementType enum
/// Validates paired measurement logic and naming conventions
final class MeasurementTypeTests: XCTestCase {

    // MARK: - Title Tests

    func testTitle_AllCases_HaveCorrectTitles() {
        XCTAssertEqual(MeasurementType.weight.title, "Weight")
        XCTAssertEqual(MeasurementType.bodyFat.title, "Body Fat %")
        XCTAssertEqual(MeasurementType.chest.title, "Chest")
        XCTAssertEqual(MeasurementType.waist.title, "Waist")
        XCTAssertEqual(MeasurementType.hips.title, "Hips")
        XCTAssertEqual(MeasurementType.neck.title, "Neck")
        XCTAssertEqual(MeasurementType.bicepsLeft.title, "Biceps (L)")
        XCTAssertEqual(MeasurementType.bicepsRight.title, "Biceps (R)")
        XCTAssertEqual(MeasurementType.forearmLeft.title, "Forearm (L)")
        XCTAssertEqual(MeasurementType.forearmRight.title, "Forearm (R)")
        XCTAssertEqual(MeasurementType.thighLeft.title, "Thigh (L)")
        XCTAssertEqual(MeasurementType.thighRight.title, "Thigh (R)")
        XCTAssertEqual(MeasurementType.calfLeft.title, "Calf (L)")
        XCTAssertEqual(MeasurementType.calfRight.title, "Calf (R)")
        XCTAssertEqual(MeasurementType.custom.title, "Custom")
    }

    // MARK: - pairedMeasurement Tests

    func testPairedMeasurement_BicepsLeft_ReturnsBicepsRight() {
        XCTAssertEqual(
            MeasurementType.bicepsLeft.pairedMeasurement,
            .bicepsRight,
            "Biceps left should pair with biceps right"
        )
    }

    func testPairedMeasurement_BicepsRight_ReturnsBicepsLeft() {
        XCTAssertEqual(
            MeasurementType.bicepsRight.pairedMeasurement,
            .bicepsLeft,
            "Biceps right should pair with biceps left"
        )
    }

    func testPairedMeasurement_ForearmLeft_ReturnsForearmRight() {
        XCTAssertEqual(
            MeasurementType.forearmLeft.pairedMeasurement,
            .forearmRight,
            "Forearm left should pair with forearm right"
        )
    }

    func testPairedMeasurement_ForearmRight_ReturnsForearmLeft() {
        XCTAssertEqual(
            MeasurementType.forearmRight.pairedMeasurement,
            .forearmLeft,
            "Forearm right should pair with forearm left"
        )
    }

    func testPairedMeasurement_ThighLeft_ReturnsThighRight() {
        XCTAssertEqual(
            MeasurementType.thighLeft.pairedMeasurement,
            .thighRight,
            "Thigh left should pair with thigh right"
        )
    }

    func testPairedMeasurement_ThighRight_ReturnsThighLeft() {
        XCTAssertEqual(
            MeasurementType.thighRight.pairedMeasurement,
            .thighLeft,
            "Thigh right should pair with thigh left"
        )
    }

    func testPairedMeasurement_CalfLeft_ReturnsCalfRight() {
        XCTAssertEqual(
            MeasurementType.calfLeft.pairedMeasurement,
            .calfRight,
            "Calf left should pair with calf right"
        )
    }

    func testPairedMeasurement_CalfRight_ReturnsCalfLeft() {
        XCTAssertEqual(
            MeasurementType.calfRight.pairedMeasurement,
            .calfLeft,
            "Calf right should pair with calf left"
        )
    }

    func testPairedMeasurement_NonPairedMeasurements_ReturnNil() {
        XCTAssertNil(MeasurementType.weight.pairedMeasurement, "Weight should not have paired measurement")
        XCTAssertNil(MeasurementType.bodyFat.pairedMeasurement, "Body fat should not have paired measurement")
        XCTAssertNil(MeasurementType.chest.pairedMeasurement, "Chest should not have paired measurement")
        XCTAssertNil(MeasurementType.waist.pairedMeasurement, "Waist should not have paired measurement")
        XCTAssertNil(MeasurementType.hips.pairedMeasurement, "Hips should not have paired measurement")
        XCTAssertNil(MeasurementType.neck.pairedMeasurement, "Neck should not have paired measurement")
        XCTAssertNil(MeasurementType.custom.pairedMeasurement, "Custom should not have paired measurement")
    }

    // MARK: - hasPairedVariant Tests

    func testHasPairedVariant_PairedMeasurements_ReturnsTrue() {
        XCTAssertTrue(MeasurementType.bicepsLeft.hasPairedVariant, "Biceps left should have paired variant")
        XCTAssertTrue(MeasurementType.bicepsRight.hasPairedVariant, "Biceps right should have paired variant")
        XCTAssertTrue(MeasurementType.forearmLeft.hasPairedVariant, "Forearm left should have paired variant")
        XCTAssertTrue(MeasurementType.forearmRight.hasPairedVariant, "Forearm right should have paired variant")
        XCTAssertTrue(MeasurementType.thighLeft.hasPairedVariant, "Thigh left should have paired variant")
        XCTAssertTrue(MeasurementType.thighRight.hasPairedVariant, "Thigh right should have paired variant")
        XCTAssertTrue(MeasurementType.calfLeft.hasPairedVariant, "Calf left should have paired variant")
        XCTAssertTrue(MeasurementType.calfRight.hasPairedVariant, "Calf right should have paired variant")
    }

    func testHasPairedVariant_NonPairedMeasurements_ReturnsFalse() {
        XCTAssertFalse(MeasurementType.weight.hasPairedVariant, "Weight should not have paired variant")
        XCTAssertFalse(MeasurementType.bodyFat.hasPairedVariant, "Body fat should not have paired variant")
        XCTAssertFalse(MeasurementType.chest.hasPairedVariant, "Chest should not have paired variant")
        XCTAssertFalse(MeasurementType.waist.hasPairedVariant, "Waist should not have paired variant")
        XCTAssertFalse(MeasurementType.hips.hasPairedVariant, "Hips should not have paired variant")
        XCTAssertFalse(MeasurementType.neck.hasPairedVariant, "Neck should not have paired variant")
        XCTAssertFalse(MeasurementType.custom.hasPairedVariant, "Custom should not have paired variant")
    }

    // MARK: - baseName Tests

    func testBaseName_BicepsMeasurements_ReturnsBiceps() {
        XCTAssertEqual(MeasurementType.bicepsLeft.baseName, "Biceps", "Biceps left base name should be 'Biceps'")
        XCTAssertEqual(MeasurementType.bicepsRight.baseName, "Biceps", "Biceps right base name should be 'Biceps'")
    }

    func testBaseName_ForearmMeasurements_ReturnsForearm() {
        XCTAssertEqual(MeasurementType.forearmLeft.baseName, "Forearm", "Forearm left base name should be 'Forearm'")
        XCTAssertEqual(MeasurementType.forearmRight.baseName, "Forearm", "Forearm right base name should be 'Forearm'")
    }

    func testBaseName_ThighMeasurements_ReturnsThigh() {
        XCTAssertEqual(MeasurementType.thighLeft.baseName, "Thigh", "Thigh left base name should be 'Thigh'")
        XCTAssertEqual(MeasurementType.thighRight.baseName, "Thigh", "Thigh right base name should be 'Thigh'")
    }

    func testBaseName_CalfMeasurements_ReturnsCalf() {
        XCTAssertEqual(MeasurementType.calfLeft.baseName, "Calf", "Calf left base name should be 'Calf'")
        XCTAssertEqual(MeasurementType.calfRight.baseName, "Calf", "Calf right base name should be 'Calf'")
    }

    func testBaseName_NonPairedMeasurements_ReturnsTitle() {
        XCTAssertEqual(MeasurementType.weight.baseName, "Weight", "Weight base name should be title")
        XCTAssertEqual(MeasurementType.bodyFat.baseName, "Body Fat %", "Body fat base name should be title")
        XCTAssertEqual(MeasurementType.chest.baseName, "Chest", "Chest base name should be title")
        XCTAssertEqual(MeasurementType.waist.baseName, "Waist", "Waist base name should be title")
        XCTAssertEqual(MeasurementType.hips.baseName, "Hips", "Hips base name should be title")
        XCTAssertEqual(MeasurementType.neck.baseName, "Neck", "Neck base name should be title")
        XCTAssertEqual(MeasurementType.custom.baseName, "Custom", "Custom base name should be title")
    }

    // MARK: - isLeft Tests

    func testIsLeft_LeftMeasurements_ReturnsTrue() {
        XCTAssertTrue(MeasurementType.bicepsLeft.isLeft, "Biceps left should be left")
        XCTAssertTrue(MeasurementType.forearmLeft.isLeft, "Forearm left should be left")
        XCTAssertTrue(MeasurementType.thighLeft.isLeft, "Thigh left should be left")
        XCTAssertTrue(MeasurementType.calfLeft.isLeft, "Calf left should be left")
    }

    func testIsLeft_RightMeasurements_ReturnsFalse() {
        XCTAssertFalse(MeasurementType.bicepsRight.isLeft, "Biceps right should not be left")
        XCTAssertFalse(MeasurementType.forearmRight.isLeft, "Forearm right should not be left")
        XCTAssertFalse(MeasurementType.thighRight.isLeft, "Thigh right should not be left")
        XCTAssertFalse(MeasurementType.calfRight.isLeft, "Calf right should not be left")
    }

    func testIsLeft_NonPairedMeasurements_ReturnsFalse() {
        XCTAssertFalse(MeasurementType.weight.isLeft, "Weight should not be left")
        XCTAssertFalse(MeasurementType.bodyFat.isLeft, "Body fat should not be left")
        XCTAssertFalse(MeasurementType.chest.isLeft, "Chest should not be left")
        XCTAssertFalse(MeasurementType.waist.isLeft, "Waist should not be left")
        XCTAssertFalse(MeasurementType.hips.isLeft, "Hips should not be left")
        XCTAssertFalse(MeasurementType.neck.isLeft, "Neck should not be left")
        XCTAssertFalse(MeasurementType.custom.isLeft, "Custom should not be left")
    }

    // MARK: - Identifiable Tests

    func testId_MatchesRawValue() {
        for measurementType in MeasurementType.allCases {
            XCTAssertEqual(
                measurementType.id,
                measurementType.rawValue,
                "\(measurementType) id should match raw value"
            )
        }
    }

    // MARK: - CaseIterable Tests

    func testAllCases_ContainsAllMeasurementTypes() {
        let allCases = MeasurementType.allCases
        XCTAssertTrue(allCases.contains(.weight))
        XCTAssertTrue(allCases.contains(.bodyFat))
        XCTAssertTrue(allCases.contains(.chest))
        XCTAssertTrue(allCases.contains(.waist))
        XCTAssertTrue(allCases.contains(.hips))
        XCTAssertTrue(allCases.contains(.neck))
        XCTAssertTrue(allCases.contains(.bicepsLeft))
        XCTAssertTrue(allCases.contains(.bicepsRight))
        XCTAssertTrue(allCases.contains(.forearmLeft))
        XCTAssertTrue(allCases.contains(.forearmRight))
        XCTAssertTrue(allCases.contains(.thighLeft))
        XCTAssertTrue(allCases.contains(.thighRight))
        XCTAssertTrue(allCases.contains(.calfLeft))
        XCTAssertTrue(allCases.contains(.calfRight))
        XCTAssertTrue(allCases.contains(.custom))
    }

    func testAllCases_HasCorrectCount() {
        XCTAssertEqual(MeasurementType.allCases.count, 15, "Should have exactly 15 measurement types")
    }

    // MARK: - Pairing Symmetry Tests

    func testPairing_IsSymmetric() {
        // For all paired measurements, verify that pairing is symmetric
        let pairedTypes: [(MeasurementType, MeasurementType)] = [
            (.bicepsLeft, .bicepsRight),
            (.forearmLeft, .forearmRight),
            (.thighLeft, .thighRight),
            (.calfLeft, .calfRight)
        ]

        for (left, right) in pairedTypes {
            XCTAssertEqual(
                left.pairedMeasurement,
                right,
                "\(left) should pair with \(right)"
            )
            XCTAssertEqual(
                right.pairedMeasurement,
                left,
                "\(right) should pair with \(left)"
            )
        }
    }

    // MARK: - Raw Value Tests

    func testRawValue_AllCases_AreUnique() {
        let rawValues = MeasurementType.allCases.map { $0.rawValue }
        let uniqueRawValues = Set(rawValues)
        XCTAssertEqual(
            rawValues.count,
            uniqueRawValues.count,
            "All raw values should be unique"
        )
    }

    func testRawValue_InitializationRoundTrip() {
        for measurementType in MeasurementType.allCases {
            let rawValue = measurementType.rawValue
            let reconstructed = MeasurementType(rawValue: rawValue)
            XCTAssertEqual(
                reconstructed,
                measurementType,
                "Should be able to reconstruct \(measurementType) from raw value"
            )
        }
    }

    // MARK: - Edge Case Tests

    func testBaseName_ConsistentWithPairing() {
        // Verify that paired measurements have the same base name
        let pairedTypes: [(MeasurementType, MeasurementType)] = [
            (.bicepsLeft, .bicepsRight),
            (.forearmLeft, .forearmRight),
            (.thighLeft, .thighRight),
            (.calfLeft, .calfRight)
        ]

        for (left, right) in pairedTypes {
            XCTAssertEqual(
                left.baseName,
                right.baseName,
                "Paired measurements \(left) and \(right) should have same base name"
            )
        }
    }
}
