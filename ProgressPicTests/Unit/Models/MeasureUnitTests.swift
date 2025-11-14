import XCTest
@testable import ProgressPic

/// Test suite for MeasureUnit enum
/// Validates measurement unit types and identifiability
final class MeasureUnitTests: XCTestCase {

    // MARK: - All Cases Tests

    func testAllCases_Contains AllExpectedUnits() {
        let allCases = MeasureUnit.allCases

        XCTAssertTrue(allCases.contains(.kg), "Should contain kg")
        XCTAssertTrue(allCases.contains(.lb), "Should contain lb")
        XCTAssertTrue(allCases.contains(.cm), "Should contain cm")
        XCTAssertTrue(allCases.contains(.inch), "Should contain inch")
        XCTAssertTrue(allCases.contains(.percent), "Should contain percent")
    }

    func testAllCases_HasCorrectCount() {
        XCTAssertEqual(MeasureUnit.allCases.count, 5, "Should have exactly 5 measurement units")
    }

    // MARK: - Raw Value Tests

    func testRawValue_AllUnits_MatchEnumName() {
        XCTAssertEqual(MeasureUnit.kg.rawValue, "kg")
        XCTAssertEqual(MeasureUnit.lb.rawValue, "lb")
        XCTAssertEqual(MeasureUnit.cm.rawValue, "cm")
        XCTAssertEqual(MeasureUnit.inch.rawValue, "inch")
        XCTAssertEqual(MeasureUnit.percent.rawValue, "percent")
    }

    func testRawValue_Initialization_WorksForAllCases() {
        XCTAssertEqual(MeasureUnit(rawValue: "kg"), .kg)
        XCTAssertEqual(MeasureUnit(rawValue: "lb"), .lb)
        XCTAssertEqual(MeasureUnit(rawValue: "cm"), .cm)
        XCTAssertEqual(MeasureUnit(rawValue: "inch"), .inch)
        XCTAssertEqual(MeasureUnit(rawValue: "percent"), .percent)
    }

    func testRawValue_InvalidString_ReturnsNil() {
        XCTAssertNil(MeasureUnit(rawValue: "invalid"))
        XCTAssertNil(MeasureUnit(rawValue: "meter"))
        XCTAssertNil(MeasureUnit(rawValue: ""))
    }

    func testRawValue_CaseSensitive() {
        XCTAssertNil(MeasureUnit(rawValue: "KG"), "Raw value should be case-sensitive")
        XCTAssertNil(MeasureUnit(rawValue: "Kg"), "Raw value should be case-sensitive")
        XCTAssertEqual(MeasureUnit(rawValue: "kg"), .kg, "Lowercase should work")
    }

    // MARK: - Identifiable Tests

    func testId_MatchesRawValue() {
        for unit in MeasureUnit.allCases {
            XCTAssertEqual(
                unit.id,
                unit.rawValue,
                "\(unit) id should match raw value"
            )
        }
    }

    func testId_AllUnitsHaveUniqueIds() {
        let ids = MeasureUnit.allCases.map { $0.id }
        let uniqueIds = Set(ids)

        XCTAssertEqual(
            ids.count,
            uniqueIds.count,
            "All measurement units should have unique IDs"
        )
    }

    // MARK: - Codable Tests

    func testCodable_Encode_ProducesCorrectJSON() throws {
        let unit = MeasureUnit.kg

        let encoder = JSONEncoder()
        let data = try encoder.encode(unit)
        let jsonString = String(data: data, encoding: .utf8)

        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString?.contains("kg") ?? false, "Should encode to raw value")
    }

    func testCodable_Decode_ReconstructsUnit() throws {
        let originalUnit = MeasureUnit.lb

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalUnit)

        let decoder = JSONDecoder()
        let decodedUnit = try decoder.decode(MeasureUnit.self, from: data)

        XCTAssertEqual(decodedUnit, originalUnit)
    }

    func testCodable_AllUnits_RoundTrip() throws {
        for unit in MeasureUnit.allCases {
            let encoder = JSONEncoder()
            let data = try encoder.encode(unit)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(MeasureUnit.self, from: data)

            XCTAssertEqual(
                decoded,
                unit,
                "\(unit) should survive encode/decode round trip"
            )
        }
    }

    // MARK: - Unit Category Tests

    func testWeightUnits_AreDistinct() {
        let weightUnits: [MeasureUnit] = [.kg, .lb]

        XCTAssertEqual(weightUnits.count, 2)
        XCTAssertNotEqual(MeasureUnit.kg, MeasureUnit.lb)
    }

    func testLengthUnits_AreDistinct() {
        let lengthUnits: [MeasureUnit] = [.cm, .inch]

        XCTAssertEqual(lengthUnits.count, 2)
        XCTAssertNotEqual(MeasureUnit.cm, MeasureUnit.inch)
    }

    func testPercentUnit_IsUnique() {
        let percentUnit = MeasureUnit.percent

        // Percent is not a weight or length unit
        XCTAssertNotEqual(percentUnit, .kg)
        XCTAssertNotEqual(percentUnit, .lb)
        XCTAssertNotEqual(percentUnit, .cm)
        XCTAssertNotEqual(percentUnit, .inch)
    }

    // MARK: - Equality Tests

    func testEquality_SameUnit_AreEqual() {
        XCTAssertEqual(MeasureUnit.kg, .kg)
        XCTAssertEqual(MeasureUnit.lb, .lb)
        XCTAssertEqual(MeasureUnit.cm, .cm)
        XCTAssertEqual(MeasureUnit.inch, .inch)
        XCTAssertEqual(MeasureUnit.percent, .percent)
    }

    func testEquality_DifferentUnits_AreNotEqual() {
        XCTAssertNotEqual(MeasureUnit.kg, .lb)
        XCTAssertNotEqual(MeasureUnit.cm, .inch)
        XCTAssertNotEqual(MeasureUnit.kg, .cm)
        XCTAssertNotEqual(MeasureUnit.percent, .kg)
    }

    // MARK: - Hashable Tests

    func testHashable_CanBeUsedInSet() {
        var unitSet = Set<MeasureUnit>()
        unitSet.insert(.kg)
        unitSet.insert(.lb)
        unitSet.insert(.kg) // Duplicate

        XCTAssertEqual(unitSet.count, 2, "Set should contain 2 unique units")
        XCTAssertTrue(unitSet.contains(.kg))
        XCTAssertTrue(unitSet.contains(.lb))
    }

    func testHashable_CanBeUsedAsDictionaryKey() {
        var unitDict: [MeasureUnit: String] = [:]
        unitDict[.kg] = "kilograms"
        unitDict[.lb] = "pounds"
        unitDict[.cm] = "centimeters"

        XCTAssertEqual(unitDict[.kg], "kilograms")
        XCTAssertEqual(unitDict[.lb], "pounds")
        XCTAssertEqual(unitDict[.cm], "centimeters")
    }

    func testHashable_EqualUnits_HaveSameHash() {
        let unit1 = MeasureUnit.kg
        let unit2 = MeasureUnit.kg

        XCTAssertEqual(unit1, unit2)
        XCTAssertEqual(unit1.hashValue, unit2.hashValue)
    }

    // MARK: - Usage Pattern Tests

    func testMeasureUnit_CanBeUsedInSwitch() {
        let unit = MeasureUnit.kg

        var result = ""
        switch unit {
        case .kg:
            result = "weight-metric"
        case .lb:
            result = "weight-imperial"
        case .cm:
            result = "length-metric"
        case .inch:
            result = "length-imperial"
        case .percent:
            result = "percentage"
        }

        XCTAssertEqual(result, "weight-metric")
    }

    func testMeasureUnit_CanBeStoredInArray() {
        let units: [MeasureUnit] = [.kg, .lb, .cm]

        XCTAssertEqual(units.count, 3)
        XCTAssertEqual(units[0], .kg)
        XCTAssertEqual(units[1], .lb)
        XCTAssertEqual(units[2], .cm)
    }

    // MARK: - Conversion Logic Tests (Conceptual)

    func testWeightUnits_KgToLbConversion_Concept() {
        // Conceptual test: 1 kg ≈ 2.20462 lb
        let kgValue = 75.0
        let expectedLbValue = kgValue * 2.20462

        // Verify the conversion factor is reasonable
        XCTAssertEqual(expectedLbValue, 165.3465, accuracy: 0.001)
    }

    func testLengthUnits_CmToInchConversion_Concept() {
        // Conceptual test: 1 inch = 2.54 cm
        let cmValue = 100.0
        let expectedInchValue = cmValue / 2.54

        // Verify the conversion factor is reasonable
        XCTAssertEqual(expectedInchValue, 39.37, accuracy: 0.01)
    }

    // MARK: - Display Tests (Conceptual)

    func testMeasureUnit_DisplayString_Concept() {
        // These tests verify that raw values could be used for display

        XCTAssertEqual(MeasureUnit.kg.rawValue, "kg")
        XCTAssertEqual(MeasureUnit.lb.rawValue, "lb")
        XCTAssertEqual(MeasureUnit.cm.rawValue, "cm")
        XCTAssertEqual(MeasureUnit.inch.rawValue, "inch")
        XCTAssertEqual(MeasureUnit.percent.rawValue, "percent")
    }

    // MARK: - Sorting Tests

    func testMeasureUnit_CanBeSorted() {
        let units: [MeasureUnit] = [.percent, .kg, .cm, .lb, .inch]

        // Sort by raw value
        let sorted = units.sorted { $0.rawValue < $1.rawValue }

        XCTAssertEqual(sorted[0], .cm) // "cm"
        XCTAssertEqual(sorted[1], .inch) // "inch"
        XCTAssertEqual(sorted[2], .kg) // "kg"
        XCTAssertEqual(sorted[3], .lb) // "lb"
        XCTAssertEqual(sorted[4], .percent) // "percent"
    }

    // MARK: - Filter Tests

    func testMeasureUnit_CanBeFiltered() {
        let allUnits = MeasureUnit.allCases

        // Filter weight units (kg, lb)
        let weightUnits = allUnits.filter { $0 == .kg || $0 == .lb }

        XCTAssertEqual(weightUnits.count, 2)
        XCTAssertTrue(weightUnits.contains(.kg))
        XCTAssertTrue(weightUnits.contains(.lb))
    }

    // MARK: - Edge Case Tests

    func testMeasureUnit_EmptyArrayOperations() {
        let emptyUnits: [MeasureUnit] = []

        XCTAssertEqual(emptyUnits.count, 0)
        XCTAssertFalse(emptyUnits.contains(.kg))
    }

    func testMeasureUnit_OptionalHandling() {
        let optionalUnit: MeasureUnit? = .kg

        XCTAssertNotNil(optionalUnit)
        XCTAssertEqual(optionalUnit, .kg)

        let nilUnit: MeasureUnit? = nil
        XCTAssertNil(nilUnit)
    }

    func testMeasureUnit_JSONDecoding_InvalidValue_ThrowsError() {
        let invalidJSON = "\"invalid_unit\"".data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(MeasureUnit.self, from: invalidJSON)) { error in
            // Should throw a decoding error for invalid raw value
            XCTAssertTrue(error is DecodingError)
        }
    }
}
