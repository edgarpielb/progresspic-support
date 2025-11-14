import XCTest
@testable import ProgressPic

/// Test suite for AlignTransform struct
/// Validates transform data structure and identity transform
final class AlignTransformTests: XCTestCase {

    // MARK: - Identity Tests

    func testIdentity_HasExpectedValues() {
        let identity = AlignTransform.identity

        XCTAssertEqual(identity.scale, 1.0, "Identity scale should be 1.0")
        XCTAssertEqual(identity.offsetX, 0.0, "Identity offsetX should be 0.0")
        XCTAssertEqual(identity.offsetY, 0.0, "Identity offsetY should be 0.0")
        XCTAssertEqual(identity.rotation, 0.0, "Identity rotation should be 0.0")
    }

    // MARK: - Initialization Tests

    func testInit_CustomValues_StoresCorrectly() {
        let transform = AlignTransform(scale: 2.0, offsetX: 10.5, offsetY: -5.5, rotation: 1.57)

        XCTAssertEqual(transform.scale, 2.0)
        XCTAssertEqual(transform.offsetX, 10.5)
        XCTAssertEqual(transform.offsetY, -5.5)
        XCTAssertEqual(transform.rotation, 1.57)
    }

    // MARK: - Codable Tests

    func testCodable_EncodeDecode_RoundTrip() throws {
        let original = AlignTransform(scale: 1.5, offsetX: 20.0, offsetY: -10.0, rotation: 3.14)

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AlignTransform.self, from: data)

        XCTAssertEqual(decoded.scale, original.scale, accuracy: 0.0001)
        XCTAssertEqual(decoded.offsetX, original.offsetX, accuracy: 0.0001)
        XCTAssertEqual(decoded.offsetY, original.offsetY, accuracy: 0.0001)
        XCTAssertEqual(decoded.rotation, original.rotation, accuracy: 0.0001)
    }

    func testCodable_Identity_RoundTrip() throws {
        let original = AlignTransform.identity

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AlignTransform.self, from: data)

        XCTAssertEqual(decoded.scale, 1.0)
        XCTAssertEqual(decoded.offsetX, 0.0)
        XCTAssertEqual(decoded.offsetY, 0.0)
        XCTAssertEqual(decoded.rotation, 0.0)
    }

    // MARK: - Hashable Tests

    func testHashable_EqualTransforms_HaveSameHash() {
        let transform1 = AlignTransform(scale: 2.0, offsetX: 10.0, offsetY: 5.0, rotation: 1.0)
        let transform2 = AlignTransform(scale: 2.0, offsetX: 10.0, offsetY: 5.0, rotation: 1.0)

        XCTAssertEqual(transform1, transform2, "Equal transforms should be equal")
        XCTAssertEqual(transform1.hashValue, transform2.hashValue, "Equal transforms should have same hash")
    }

    func testHashable_DifferentTransforms_HaveDifferentHash() {
        let transform1 = AlignTransform(scale: 2.0, offsetX: 10.0, offsetY: 5.0, rotation: 1.0)
        let transform2 = AlignTransform(scale: 1.0, offsetX: 10.0, offsetY: 5.0, rotation: 1.0)

        XCTAssertNotEqual(transform1, transform2, "Different transforms should not be equal")
        // Hash values might collide, so we don't test inequality of hashes
    }

    func testHashable_CanBeUsedInSet() {
        let transform1 = AlignTransform(scale: 2.0, offsetX: 10.0, offsetY: 5.0, rotation: 1.0)
        let transform2 = AlignTransform(scale: 1.0, offsetX: 10.0, offsetY: 5.0, rotation: 1.0)
        let transform3 = AlignTransform(scale: 2.0, offsetX: 10.0, offsetY: 5.0, rotation: 1.0)

        var transformSet = Set<AlignTransform>()
        transformSet.insert(transform1)
        transformSet.insert(transform2)
        transformSet.insert(transform3)

        // transform1 and transform3 are equal, so set should have 2 elements
        XCTAssertEqual(transformSet.count, 2, "Set should contain 2 unique transforms")
    }

    func testHashable_CanBeUsedAsDictionaryKey() {
        let transform1 = AlignTransform(scale: 2.0, offsetX: 10.0, offsetY: 5.0, rotation: 1.0)
        let transform2 = AlignTransform(scale: 1.0, offsetX: 10.0, offsetY: 5.0, rotation: 1.0)

        var dictionary: [AlignTransform: String] = [:]
        dictionary[transform1] = "first"
        dictionary[transform2] = "second"

        XCTAssertEqual(dictionary[transform1], "first")
        XCTAssertEqual(dictionary[transform2], "second")
    }

    // MARK: - Equality Tests

    func testEquality_IdenticalValues_AreEqual() {
        let transform1 = AlignTransform(scale: 1.5, offsetX: 10.0, offsetY: -5.0, rotation: 2.0)
        let transform2 = AlignTransform(scale: 1.5, offsetX: 10.0, offsetY: -5.0, rotation: 2.0)

        XCTAssertEqual(transform1, transform2)
    }

    func testEquality_DifferentScale_AreNotEqual() {
        let transform1 = AlignTransform(scale: 1.5, offsetX: 10.0, offsetY: -5.0, rotation: 2.0)
        let transform2 = AlignTransform(scale: 2.0, offsetX: 10.0, offsetY: -5.0, rotation: 2.0)

        XCTAssertNotEqual(transform1, transform2)
    }

    func testEquality_DifferentOffsetX_AreNotEqual() {
        let transform1 = AlignTransform(scale: 1.5, offsetX: 10.0, offsetY: -5.0, rotation: 2.0)
        let transform2 = AlignTransform(scale: 1.5, offsetX: 15.0, offsetY: -5.0, rotation: 2.0)

        XCTAssertNotEqual(transform1, transform2)
    }

    func testEquality_DifferentOffsetY_AreNotEqual() {
        let transform1 = AlignTransform(scale: 1.5, offsetX: 10.0, offsetY: -5.0, rotation: 2.0)
        let transform2 = AlignTransform(scale: 1.5, offsetX: 10.0, offsetY: 5.0, rotation: 2.0)

        XCTAssertNotEqual(transform1, transform2)
    }

    func testEquality_DifferentRotation_AreNotEqual() {
        let transform1 = AlignTransform(scale: 1.5, offsetX: 10.0, offsetY: -5.0, rotation: 2.0)
        let transform2 = AlignTransform(scale: 1.5, offsetX: 10.0, offsetY: -5.0, rotation: 3.0)

        XCTAssertNotEqual(transform1, transform2)
    }

    // MARK: - Edge Case Tests

    func testTransform_NegativeScale_IsValid() {
        let transform = AlignTransform(scale: -1.0, offsetX: 0.0, offsetY: 0.0, rotation: 0.0)

        XCTAssertEqual(transform.scale, -1.0, "Negative scale should be allowed")
    }

    func testTransform_ZeroScale_IsValid() {
        let transform = AlignTransform(scale: 0.0, offsetX: 0.0, offsetY: 0.0, rotation: 0.0)

        XCTAssertEqual(transform.scale, 0.0, "Zero scale should be allowed")
    }

    func testTransform_VeryLargeValues_HandlesCorrectly() {
        let transform = AlignTransform(
            scale: 1000.0,
            offsetX: 10000.0,
            offsetY: -10000.0,
            rotation: 360.0
        )

        XCTAssertEqual(transform.scale, 1000.0)
        XCTAssertEqual(transform.offsetX, 10000.0)
        XCTAssertEqual(transform.offsetY, -10000.0)
        XCTAssertEqual(transform.rotation, 360.0)
    }

    func testTransform_VerySmallValues_HandlesCorrectly() {
        let transform = AlignTransform(
            scale: 0.001,
            offsetX: 0.001,
            offsetY: -0.001,
            rotation: 0.001
        )

        XCTAssertEqual(transform.scale, 0.001, accuracy: 0.0001)
        XCTAssertEqual(transform.offsetX, 0.001, accuracy: 0.0001)
        XCTAssertEqual(transform.offsetY, -0.001, accuracy: 0.0001)
        XCTAssertEqual(transform.rotation, 0.001, accuracy: 0.0001)
    }

    func testTransform_InfiniteValues_EncodesAndDecodes() throws {
        let transform = AlignTransform(
            scale: Double.infinity,
            offsetX: -Double.infinity,
            offsetY: 0.0,
            rotation: 0.0
        )

        // Should be able to encode/decode infinity
        let encoder = JSONEncoder()
        let data = try encoder.encode(transform)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AlignTransform.self, from: data)

        XCTAssertEqual(decoded.scale, Double.infinity)
        XCTAssertEqual(decoded.offsetX, -Double.infinity)
    }

    // MARK: - Rotation Tests

    func testRotation_PositiveValue_IsValid() {
        let transform = AlignTransform(scale: 1.0, offsetX: 0.0, offsetY: 0.0, rotation: 3.14159)

        XCTAssertEqual(transform.rotation, 3.14159, accuracy: 0.00001)
    }

    func testRotation_NegativeValue_IsValid() {
        let transform = AlignTransform(scale: 1.0, offsetX: 0.0, offsetY: 0.0, rotation: -1.57)

        XCTAssertEqual(transform.rotation, -1.57, accuracy: 0.01)
    }

    func testRotation_FullCircle_IsValid() {
        // 2π radians (full circle)
        let fullCircle = 2.0 * Double.pi
        let transform = AlignTransform(scale: 1.0, offsetX: 0.0, offsetY: 0.0, rotation: fullCircle)

        XCTAssertEqual(transform.rotation, fullCircle, accuracy: 0.00001)
    }
}
