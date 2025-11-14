# ProgressPic Test Suite

Comprehensive test coverage for the ProgressPic iOS application.

## Test Structure

```
ProgressPicTests/
├── Unit/
│   ├── Utilities/
│   │   ├── StatsFormattersTests.swift       (32 tests)
│   │   ├── DateFormattersTests.swift        (35 tests)
│   │   └── HapticFeedbackTests.swift        (18 tests)
│   └── Models/
│       ├── MeasurementTypeTests.swift       (25 tests)
│       ├── UserProfileTests.swift           (30 tests)
│       └── AlignTransformTests.swift        (25 tests)
└── Integration/
    └── PhotoStoreTests.swift                (30 tests)

Total: ~195 unit and integration tests
```

## Coverage Summary

| Component | Test File | Tests | Coverage Target |
|-----------|-----------|-------|-----------------|
| **Utilities** | | | |
| StatsFormatters | StatsFormattersTests.swift | 32 | 95%+ |
| DateFormatters | DateFormattersTests.swift | 35 | 95%+ |
| HapticFeedback | HapticFeedbackTests.swift | 18 | 90%+ |
| **Models** | | | |
| MeasurementType | MeasurementTypeTests.swift | 25 | 95%+ |
| UserProfile | UserProfileTests.swift | 30 | 90%+ |
| AlignTransform | AlignTransformTests.swift | 25 | 95%+ |
| **Services** | | | |
| PhotoStore | PhotoStoreTests.swift | 30 | 80%+ |

## Running Tests

### Xcode
1. Open `ProgressPic.xcodeproj`
2. Select the test target
3. Press `Cmd+U` to run all tests
4. Or use `Cmd+Ctrl+U` to run tests with code coverage

### Command Line
```bash
# Run all tests
xcodebuild test -scheme ProgressPic -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -scheme ProgressPic -only-testing:ProgressPicTests/StatsFormattersTests

# Generate code coverage
xcodebuild test -scheme ProgressPic -enableCodeCoverage YES
```

## Test Highlights

### Critical Tests (Data Loss Prevention)

#### PhotoStoreTests ⚠️ CRITICAL
- **Purpose**: Prevent data loss from file I/O operations
- **Key Tests**:
  - File save/load operations
  - Image cache management
  - Concurrent access safety
  - JPEG compression quality
  - Directory creation

#### UserProfileTests
- **Purpose**: Ensure user data persistence
- **Key Tests**:
  - Save/load round trips
  - Age calculation edge cases
  - Codable serialization
  - Corrupted data handling

### High-Value Unit Tests

#### StatsFormattersTests
- **Purpose**: Validate statistical calculations for charts
- **Coverage**: All formatting and calculation methods
- **Key Tests**:
  - Min/max/average calculations
  - Y-domain calculation with padding
  - Empty data handling
  - Percentage and change formatting

#### DateFormattersTests
- **Purpose**: Ensure consistent date formatting across UI
- **Coverage**: All date formatters and parsing methods
- **Key Tests**:
  - Date range formatting
  - Relative date formatting (Today, Yesterday)
  - EXIF date parsing
  - GPS datetime parsing

#### MeasurementTypeTests
- **Purpose**: Validate paired measurement logic
- **Coverage**: All measurement type properties and methods
- **Key Tests**:
  - Paired measurement mapping (left ↔ right)
  - Base name extraction
  - Symmetry verification

## Test Categories

### 1. Unit Tests
Pure function tests with no external dependencies:
- StatsFormatters: Statistical calculations
- DateFormatters: Date formatting
- MeasurementType: Enum logic
- AlignTransform: Data structure

### 2. Integration Tests
Tests involving file system, caching, or system frameworks:
- PhotoStore: File I/O, caching, image processing
- UserProfile: UserDefaults persistence

### 3. Behavioral Tests
Tests verifying expected behavior without side effects:
- HapticFeedback: API consistency, no crashes

## Known Limitations

### Not Currently Tested
1. **SwiftData Relationships**: Cascade deletes require SwiftData context
2. **CameraService**: Requires device/simulator with camera
3. **HealthKitService**: Requires HealthKit mocking
4. **UI Components**: Require XCUITest framework
5. **CloudKit Sync**: Requires CloudKit environment

### Future Test Additions
- SwiftData model relationship tests
- Camera capture workflow tests
- HealthKit data fetching tests
- UI automation tests with XCUITest
- Performance benchmarks

## Test Best Practices

### Writing New Tests
1. **Naming**: Use descriptive test names: `test[Method]_[Scenario]_[ExpectedResult]`
2. **Arrange-Act-Assert**: Structure tests clearly
3. **One Assertion Focus**: Each test should verify one specific behavior
4. **Edge Cases**: Always test boundary conditions
5. **Cleanup**: Use `setUp()` and `tearDown()` for test isolation

### Example Test Structure
```swift
func testFormatMin_EmptyArray_ReturnsPlaceholder() {
    // Arrange
    let data: [TestDataPoint] = []

    // Act
    let result = StatsFormatters.formatMin(data, valueKeyPath: \.value, unit: "kg")

    // Assert
    XCTAssertEqual(result, "--", "Empty array should return placeholder")
}
```

## Continuous Integration

### GitHub Actions (Recommended)
```yaml
- name: Run tests
  run: |
    xcodebuild test \
      -scheme ProgressPic \
      -destination 'platform=iOS Simulator,name=iPhone 15' \
      -enableCodeCoverage YES
```

### Code Coverage Goals
- **Overall Target**: 75%+
- **Utilities**: 95%+
- **Models**: 90%+
- **Services**: 80%+
- **Views**: 60%+ (when UI tests added)

## Debugging Failed Tests

### Common Issues

1. **Async Test Timeouts**
   - Increase timeout in `wait(for:timeout:)` calls
   - Check for deadlocks in async code

2. **File System Issues**
   - Ensure proper cleanup in `tearDown()`
   - Use temp directories for test files

3. **Cache Issues**
   - Clear caches in `setUp()`
   - Verify cache invalidation logic

4. **Timing Issues**
   - Use expectations for async operations
   - Avoid sleep() in tests

## Test Metrics

Run these commands to analyze test coverage:

```bash
# Generate coverage report
xcodebuild test -scheme ProgressPic -enableCodeCoverage YES

# View coverage in Xcode
# Product > Test > Show Code Coverage (Cmd+9)

# Export coverage report
xcrun xccov view --report *.xccovreport
```

## Contributing

When adding new features:
1. Write tests first (TDD approach)
2. Ensure all tests pass before committing
3. Aim for 80%+ coverage on new code
4. Update this README if adding new test files

## Support

For test-related issues:
- Review existing test patterns
- Check test documentation comments
- Refer to XCTest documentation: https://developer.apple.com/documentation/xctest
