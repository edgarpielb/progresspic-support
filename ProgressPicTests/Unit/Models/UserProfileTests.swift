import XCTest
@testable import ProgressPic

/// Test suite for UserProfile struct
/// Validates user profile data persistence and age calculation
final class UserProfileTests: XCTestCase {

    let testUserDefaultsKey = "TestUserProfile"

    override func setUp() {
        super.setUp()
        // Clean up any existing test data
        UserDefaults.standard.removeObject(forKey: "UserProfile")
        UserDefaults.standard.removeObject(forKey: testUserDefaultsKey)
    }

    override func tearDown() {
        // Clean up test data
        UserDefaults.standard.removeObject(forKey: "UserProfile")
        UserDefaults.standard.removeObject(forKey: testUserDefaultsKey)
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInit_DefaultProfile_AllFieldsNil() {
        let profile = UserProfile()

        XCTAssertNil(profile.birthDate, "Default profile should have nil birthDate")
        XCTAssertNil(profile.heightCm, "Default profile should have nil heightCm")
        XCTAssertNil(profile.gender, "Default profile should have nil gender")
        XCTAssertNil(profile.preferredUnit, "Default profile should have nil preferredUnit")
        XCTAssertNil(profile.colorScheme, "Default profile should have nil colorScheme")
    }

    func testInit_WithValues_StoresCorrectly() {
        let birthDate = Date()
        var profile = UserProfile()
        profile.birthDate = birthDate
        profile.heightCm = 175.5
        profile.gender = .male
        profile.preferredUnit = .kg
        profile.colorScheme = .cyan

        XCTAssertEqual(profile.birthDate, birthDate)
        XCTAssertEqual(profile.heightCm, 175.5)
        XCTAssertEqual(profile.gender, .male)
        XCTAssertEqual(profile.preferredUnit, .kg)
        XCTAssertEqual(profile.colorScheme, .cyan)
    }

    // MARK: - Age Calculation Tests

    func testAge_NoBirthDate_ReturnsNil() {
        let profile = UserProfile()
        XCTAssertNil(profile.age, "Age should be nil when birthDate is not set")
    }

    func testAge_WithBirthDate_CalculatesCorrectAge() {
        let calendar = Calendar.current
        var profile = UserProfile()

        // Create a birthdate 25 years ago
        let birthDate = calendar.date(byAdding: .year, value: -25, to: Date())!
        profile.birthDate = birthDate

        XCTAssertEqual(profile.age, 25, "Should calculate age as 25 years")
    }

    func testAge_BirthdayToday_CalculatesCorrectAge() {
        let calendar = Calendar.current
        var profile = UserProfile()

        // Create a birthdate exactly 30 years ago (same month and day as today)
        let today = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: today)
        components.year! -= 30
        profile.birthDate = calendar.date(from: components)!

        XCTAssertEqual(profile.age, 30, "Should calculate age as 30 when birthday is today")
    }

    func testAge_BirthdayNotYetThisYear_CalculatesCorrectAge() {
        let calendar = Calendar.current
        var profile = UserProfile()

        // Create a birthdate: born 25 years ago but birthday hasn't happened yet this year
        let today = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: today)
        components.year! -= 25
        // Add 1 month to ensure birthday is in the future this year
        components.month! += 1
        if components.month! > 12 {
            components.month! = 1
        }

        if let birthDate = calendar.date(from: components) {
            // Only test if the future birthday is valid
            if birthDate > today {
                profile.birthDate = birthDate
                XCTAssertEqual(profile.age, 24, "Should be 24 if birthday hasn't occurred yet this year")
            }
        }
    }

    func testAge_BirthdayAlreadyHappenedThisYear_CalculatesCorrectAge() {
        let calendar = Calendar.current
        var profile = UserProfile()

        // Create a birthdate: born 25 years ago and birthday already happened this year
        let today = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: today)
        components.year! -= 25
        // Subtract 1 month to ensure birthday was in the past this year
        components.month! -= 1
        if components.month! < 1 {
            components.month! = 12
        }

        if let birthDate = calendar.date(from: components) {
            // Only test if the past birthday is valid
            if birthDate < today {
                profile.birthDate = birthDate
                XCTAssertEqual(profile.age, 25, "Should be 25 if birthday already occurred this year")
            }
        }
    }

    func testAge_LeapYearBirthdate_CalculatesCorrectly() {
        let calendar = Calendar.current
        var profile = UserProfile()

        // Create a birthdate on Feb 29, 2000 (leap year)
        var components = DateComponents()
        components.year = 2000
        components.month = 2
        components.day = 29

        if let leapBirthDate = calendar.date(from: components) {
            profile.birthDate = leapBirthDate

            // Calculate expected age
            let currentYear = calendar.component(.year, from: Date())
            let expectedAge = currentYear - 2000

            // Age should be within 1 year (depending on whether Feb 29 has passed this year)
            XCTAssertTrue(
                profile.age == expectedAge || profile.age == expectedAge - 1,
                "Leap year birthday should calculate age correctly"
            )
        }
    }

    func testAge_InfantAge_CalculatesAsZero() {
        let calendar = Calendar.current
        var profile = UserProfile()

        // Create a birthdate 6 months ago
        let birthDate = calendar.date(byAdding: .month, value: -6, to: Date())!
        profile.birthDate = birthDate

        XCTAssertEqual(profile.age, 0, "Infant (< 1 year) should have age 0")
    }

    // MARK: - Save and Load Tests

    func testSave_PersistsToUserDefaults() {
        var profile = UserProfile()
        profile.heightCm = 180.0
        profile.gender = .female
        profile.preferredUnit = .lb
        profile.colorScheme = .pink

        profile.save()

        // Verify data was saved to UserDefaults
        let savedData = UserDefaults.standard.data(forKey: "UserProfile")
        XCTAssertNotNil(savedData, "Profile should be saved to UserDefaults")
    }

    func testLoad_WithNoSavedData_ReturnsDefaultProfile() {
        // Ensure no data exists
        UserDefaults.standard.removeObject(forKey: "UserProfile")

        let loadedProfile = UserProfile.load()

        XCTAssertNil(loadedProfile.birthDate)
        XCTAssertNil(loadedProfile.heightCm)
        XCTAssertNil(loadedProfile.gender)
        XCTAssertNil(loadedProfile.preferredUnit)
        XCTAssertNil(loadedProfile.colorScheme)
    }

    func testSaveAndLoad_RoundTrip_PreservesData() {
        let calendar = Calendar.current
        var originalProfile = UserProfile()

        let birthDate = calendar.date(byAdding: .year, value: -30, to: Date())!
        originalProfile.birthDate = birthDate
        originalProfile.heightCm = 175.5
        originalProfile.gender = .male
        originalProfile.preferredUnit = .kg
        originalProfile.colorScheme = .cyan

        // Save
        originalProfile.save()

        // Load
        let loadedProfile = UserProfile.load()

        // Verify all fields match
        XCTAssertEqual(loadedProfile.birthDate?.timeIntervalSince1970, birthDate.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(loadedProfile.heightCm, 175.5)
        XCTAssertEqual(loadedProfile.gender, .male)
        XCTAssertEqual(loadedProfile.preferredUnit, .kg)
        XCTAssertEqual(loadedProfile.colorScheme, .cyan)
        XCTAssertEqual(loadedProfile.age, 30)
    }

    func testSaveAndLoad_PartialData_PreservesNilFields() {
        var profile = UserProfile()
        profile.gender = .female
        // Leave other fields as nil

        profile.save()
        let loadedProfile = UserProfile.load()

        XCTAssertNil(loadedProfile.birthDate)
        XCTAssertNil(loadedProfile.heightCm)
        XCTAssertEqual(loadedProfile.gender, .female)
        XCTAssertNil(loadedProfile.preferredUnit)
        XCTAssertNil(loadedProfile.colorScheme)
    }

    func testSaveAndLoad_OverwriteExisting_UpdatesData() {
        // Save first profile
        var profile1 = UserProfile()
        profile1.heightCm = 170.0
        profile1.gender = .male
        profile1.save()

        // Save second profile (should overwrite)
        var profile2 = UserProfile()
        profile2.heightCm = 180.0
        profile2.gender = .female
        profile2.save()

        // Load and verify it's the second profile
        let loadedProfile = UserProfile.load()
        XCTAssertEqual(loadedProfile.heightCm, 180.0)
        XCTAssertEqual(loadedProfile.gender, .female)
    }

    // MARK: - Codable Tests

    func testCodable_Encode_ProducesValidJSON() throws {
        var profile = UserProfile()
        profile.heightCm = 175.0
        profile.gender = .male
        profile.preferredUnit = .kg
        profile.colorScheme = .cyan

        let encoder = JSONEncoder()
        let data = try encoder.encode(profile)

        XCTAssertFalse(data.isEmpty, "Encoded data should not be empty")
    }

    func testCodable_Decode_ReconstructsProfile() throws {
        var originalProfile = UserProfile()
        originalProfile.heightCm = 175.0
        originalProfile.gender = .male
        originalProfile.preferredUnit = .kg
        originalProfile.colorScheme = .cyan

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalProfile)

        let decoder = JSONDecoder()
        let decodedProfile = try decoder.decode(UserProfile.self, from: data)

        XCTAssertEqual(decodedProfile.heightCm, 175.0)
        XCTAssertEqual(decodedProfile.gender, .male)
        XCTAssertEqual(decodedProfile.preferredUnit, .kg)
        XCTAssertEqual(decodedProfile.colorScheme, .cyan)
    }

    // MARK: - Gender Enum Tests

    func testGender_AllCases_HaveCorrectRawValues() {
        XCTAssertEqual(UserProfile.Gender.male.rawValue, "Male")
        XCTAssertEqual(UserProfile.Gender.female.rawValue, "Female")
    }

    func testGender_AllCases_Count() {
        XCTAssertEqual(UserProfile.Gender.allCases.count, 2)
    }

    func testGender_Codable_RoundTrip() throws {
        let genders: [UserProfile.Gender] = [.male, .female]

        for gender in genders {
            let encoder = JSONEncoder()
            let data = try encoder.encode(gender)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(UserProfile.Gender.self, from: data)

            XCTAssertEqual(decoded, gender, "\(gender) should survive encode/decode round trip")
        }
    }

    // MARK: - ColorScheme Enum Tests

    func testColorScheme_AllCases_HaveCorrectRawValues() {
        XCTAssertEqual(UserProfile.ColorScheme.cyan.rawValue, "Cyan")
        XCTAssertEqual(UserProfile.ColorScheme.pink.rawValue, "Pink")
    }

    func testColorScheme_AllCases_Count() {
        XCTAssertEqual(UserProfile.ColorScheme.allCases.count, 2)
    }

    func testColorScheme_Codable_RoundTrip() throws {
        let colorSchemes: [UserProfile.ColorScheme] = [.cyan, .pink]

        for colorScheme in colorSchemes {
            let encoder = JSONEncoder()
            let data = try encoder.encode(colorScheme)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(UserProfile.ColorScheme.self, from: data)

            XCTAssertEqual(decoded, colorScheme, "\(colorScheme) should survive encode/decode round trip")
        }
    }

    // MARK: - Edge Case Tests

    func testSave_InvalidData_HandlesGracefully() {
        // This test ensures save() handles encoding errors gracefully
        // Since UserProfile is simple, it should never fail, but we test the pattern
        var profile = UserProfile()
        profile.heightCm = Double.infinity // Edge case value

        // Should not crash
        profile.save()

        // Load and verify
        let loadedProfile = UserProfile.load()
        // infinity should be preserved
        XCTAssertEqual(loadedProfile.heightCm, Double.infinity)
    }

    func testLoad_CorruptedData_ReturnsDefaultProfile() {
        // Save corrupted data to UserDefaults
        let corruptedData = "not valid JSON".data(using: .utf8)!
        UserDefaults.standard.set(corruptedData, forKey: "UserProfile")

        // Should return default profile instead of crashing
        let loadedProfile = UserProfile.load()

        XCTAssertNil(loadedProfile.birthDate)
        XCTAssertNil(loadedProfile.heightCm)
    }

    func testBirthDate_DistantPast_CalculatesVeryOldAge() {
        let calendar = Calendar.current
        var profile = UserProfile()

        // Create a birthdate 150 years ago
        let birthDate = calendar.date(byAdding: .year, value: -150, to: Date())!
        profile.birthDate = birthDate

        XCTAssertEqual(profile.age, 150, "Should handle very old ages")
    }

    func testBirthDate_FutureDate_CalculatesNegativeAge() {
        let calendar = Calendar.current
        var profile = UserProfile()

        // Create a birthdate 5 years in the future
        let futureDate = calendar.date(byAdding: .year, value: 5, to: Date())!
        profile.birthDate = futureDate

        // Age should be negative
        XCTAssertEqual(profile.age, -5, "Should handle future birthdates (negative age)")
    }
}
