import XCTest
@testable import ProgressPic

/// Performance benchmark tests for ProgressPic
/// Validates that critical operations meet performance requirements
final class PerformanceBenchmarkTests: XCTestCase {

    // MARK: - StatsFormatters Performance Tests

    func testStatsFormatters_FormatMin_Performance() {
        let data = (0..<1000).map { TestDataPoint(value: Double($0)) }

        measure {
            for _ in 0..<100 {
                _ = StatsFormatters.formatMin(data, valueKeyPath: \.value, unit: "kg")
            }
        }
    }

    func testStatsFormatters_FormatMax_Performance() {
        let data = (0..<1000).map { TestDataPoint(value: Double($0)) }

        measure {
            for _ in 0..<100 {
                _ = StatsFormatters.formatMax(data, valueKeyPath: \.value, unit: "kg")
            }
        }
    }

    func testStatsFormatters_FormatAverage_Performance() {
        let data = (0..<1000).map { TestDataPoint(value: Double($0)) }

        measure {
            for _ in 0..<100 {
                _ = StatsFormatters.formatAverage(data, valueKeyPath: \.value, unit: "kg")
            }
        }
    }

    func testStatsFormatters_CalculateYDomain_Performance() {
        let data = (0..<1000).map { TestDataPoint(value: Double($0)) }

        measure {
            for _ in 0..<100 {
                _ = StatsFormatters.calculateYDomain(for: data, valueKeyPath: \.value)
            }
        }
    }

    func testStatsFormatters_GetStats_Performance() {
        let data = (0..<1000).map { TestDataPoint(value: Double($0)) }

        measure {
            for _ in 0..<100 {
                _ = StatsFormatters.getStats(data, valueKeyPath: \.value)
            }
        }
    }

    // MARK: - DateFormatters Performance Tests

    func testDateFormatters_FormatFullDate_Performance() {
        let dates = (0..<100).map { Date().addingTimeInterval(TimeInterval($0 * 86400)) }

        measure {
            for date in dates {
                for _ in 0..<10 {
                    _ = DateFormatters.formatFullDate(date)
                }
            }
        }
    }

    func testDateFormatters_FormatDateRange_Performance() {
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(86400 * 30)

        measure {
            for _ in 0..<1000 {
                _ = DateFormatters.formatDateRange(from: startDate, to: endDate)
            }
        }
    }

    func testDateFormatters_ParseEXIFDateString_Performance() {
        let exifStrings = (0..<100).map { "2024:01:\(String(format: "%02d", $0 % 28 + 1)) 14:30:00" }

        measure {
            for exifString in exifStrings {
                for _ in 0..<10 {
                    _ = DateFormatters.parseEXIFDateString(exifString)
                }
            }
        }
    }

    // MARK: - PhotoStore Performance Tests

    func testPhotoStore_CropTo4x5_Performance() {
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))

        measure {
            for _ in 0..<10 {
                _ = PhotoStore.cropTo4x5(testImage)
            }
        }
    }

    func testPhotoStore_CropTo4x5_LargeImage_Performance() {
        let largeImage = createTestImage(size: CGSize(width: 4000, height: 5000))

        measure {
            for _ in 0..<5 {
                _ = PhotoStore.cropTo4x5(largeImage)
            }
        }
    }

    func testPhotoStore_MultipleCrops_Performance() {
        let images = (0..<10).map { _ in createTestImage(size: CGSize(width: 1000, height: 1000)) }

        measure {
            for image in images {
                _ = PhotoStore.cropTo4x5(image)
            }
        }
    }

    // MARK: - MeasurementType Performance Tests

    func testMeasurementType_PairedMeasurement_Performance() {
        let types: [MeasurementType] = [
            .bicepsLeft, .bicepsRight,
            .forearmLeft, .forearmRight,
            .thighLeft, .thighRight,
            .calfLeft, .calfRight
        ]

        measure {
            for _ in 0..<1000 {
                for type in types {
                    _ = type.pairedMeasurement
                }
            }
        }
    }

    func testMeasurementType_BaseName_Performance() {
        let allTypes = MeasurementType.allCases

        measure {
            for _ in 0..<1000 {
                for type in allTypes {
                    _ = type.baseName
                }
            }
        }
    }

    // MARK: - UserProfile Performance Tests

    func testUserProfile_AgeCalculation_Performance() {
        let calendar = Calendar.current
        let birthDate = calendar.date(byAdding: .year, value: -30, to: Date())!

        var profile = UserProfile()
        profile.birthDate = birthDate

        measure {
            for _ in 0..<10000 {
                _ = profile.age
            }
        }
    }

    func testUserProfile_SaveLoad_Performance() {
        var profile = UserProfile()
        profile.heightCm = 175.0
        profile.gender = .male

        measure {
            for _ in 0..<100 {
                profile.save()
                _ = UserProfile.load()
            }
        }
    }

    // MARK: - CameraViewModel Performance Tests

    func testCameraViewModel_ToggleGhostPhoto_Performance() {
        let viewModel = CameraViewModel()

        measure {
            for _ in 0..<1000 {
                viewModel.toggleGhostPhoto()
            }
        }
    }

    func testCameraViewModel_TimerTick_Performance() {
        let viewModel = CameraViewModel()
        viewModel.startCountdown(seconds: 10)

        measure {
            for _ in 0..<10000 {
                viewModel.tickCountdown()
            }
        }
    }

    // MARK: - Data Structure Performance Tests

    func testAlignTransform_HashingPerformance() {
        let transforms = (0..<1000).map { i in
            AlignTransform(
                scale: Double(i) / 1000.0,
                offsetX: Double(i),
                offsetY: Double(i),
                rotation: Double(i) / 100.0
            )
        }

        measure {
            var set = Set<AlignTransform>()
            for transform in transforms {
                set.insert(transform)
            }
        }
    }

    func testMeasureUnit_SetOperations_Performance() {
        let units = (0..<1000).flatMap { _ in MeasureUnit.allCases }

        measure {
            var set = Set<MeasureUnit>()
            for unit in units {
                set.insert(unit)
            }
        }
    }

    // MARK: - Array Processing Performance Tests

    func testLargeDataSet_Filtering_Performance() {
        let data = (0..<10000).map { TestDataPoint(value: Double($0)) }

        measure {
            _ = data.filter { $0.value > 5000 }
        }
    }

    func testLargeDataSet_Mapping_Performance() {
        let data = (0..<10000).map { TestDataPoint(value: Double($0)) }

        measure {
            _ = data.map { $0.value * 2.0 }
        }
    }

    func testLargeDataSet_Sorting_Performance() {
        let data = (0..<1000).map { TestDataPoint(value: Double.random(in: 0...1000)) }

        measure {
            _ = data.sorted { $0.value < $1.value }
        }
    }

    // MARK: - Memory Performance Tests

    func testMemoryFootprint_ManyAlignTransforms() {
        measure {
            let transforms = (0..<10000).map { i in
                AlignTransform(
                    scale: Double(i) / 1000.0,
                    offsetX: Double(i),
                    offsetY: Double(i),
                    rotation: Double(i) / 100.0
                )
            }
            // Use the transforms to prevent optimization
            XCTAssertEqual(transforms.count, 10000)
        }
    }

    func testMemoryFootprint_ManyMeasurementEntries() {
        measure {
            let entries = (0..<1000).map { i in
                MeasurementEntry(
                    journeyId: UUID(),
                    date: Date(),
                    type: .weight,
                    value: Double(i),
                    unit: .kg
                )
            }
            XCTAssertEqual(entries.count, 1000)
        }
    }

    // MARK: - String Performance Tests

    func testStringFormatting_Performance() {
        measure {
            for i in 0..<10000 {
                _ = String(format: "%.1f kg", Double(i))
            }
        }
    }

    func testStringInterpolation_Performance() {
        measure {
            for i in 0..<10000 {
                _ = "\(Double(i)) kg"
            }
        }
    }

    // MARK: - Codable Performance Tests

    func testCodable_EncodeUserProfile_Performance() {
        var profile = UserProfile()
        profile.heightCm = 175.0
        profile.gender = .male
        profile.preferredUnit = .kg

        let encoder = JSONEncoder()

        measure {
            for _ in 0..<1000 {
                _ = try? encoder.encode(profile)
            }
        }
    }

    func testCodable_DecodeUserProfile_Performance() {
        var profile = UserProfile()
        profile.heightCm = 175.0
        profile.gender = .male

        let encoder = JSONEncoder()
        let data = try! encoder.encode(profile)

        let decoder = JSONDecoder()

        measure {
            for _ in 0..<1000 {
                _ = try? decoder.decode(UserProfile.self, from: data)
            }
        }
    }

    func testCodable_AlignTransform_Performance() {
        let transform = AlignTransform(scale: 1.5, offsetX: 10.0, offsetY: 20.0, rotation: 1.57)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        measure {
            for _ in 0..<1000 {
                if let data = try? encoder.encode(transform) {
                    _ = try? decoder.decode(AlignTransform.self, from: data)
                }
            }
        }
    }

    // MARK: - Concurrent Performance Tests

    func testConcurrentStatsCalculation_Performance() {
        let data = (0..<1000).map { TestDataPoint(value: Double($0)) }

        measure {
            DispatchQueue.concurrentPerform(iterations: 100) { _ in
                _ = StatsFormatters.formatMin(data, valueKeyPath: \.value, unit: "kg")
                _ = StatsFormatters.formatMax(data, valueKeyPath: \.value, unit: "kg")
                _ = StatsFormatters.formatAverage(data, valueKeyPath: \.value, unit: "kg")
            }
        }
    }

    // MARK: - Realistic Workflow Performance Tests

    func testRealisticWorkflow_ProcessMeasurements_Performance() {
        let measurements = (0..<365).map { i in
            MeasurementEntry(
                journeyId: UUID(),
                date: Date().addingTimeInterval(TimeInterval(i * 86400)),
                type: .weight,
                value: 75.0 + Double.random(in: -5...5),
                unit: .kg
            )
        }

        measure {
            // Simulate processing a year of measurements
            _ = measurements.sorted { $0.date < $1.date }
            _ = StatsFormatters.formatMin(measurements, valueKeyPath: \.value, unit: "kg")
            _ = StatsFormatters.formatMax(measurements, valueKeyPath: \.value, unit: "kg")
            _ = StatsFormatters.formatAverage(measurements, valueKeyPath: \.value, unit: "kg")
            _ = StatsFormatters.calculateYDomain(for: measurements, valueKeyPath: \.value)
        }
    }

    func testRealisticWorkflow_ProcessPhotos_Performance() {
        let photos = (0..<100).map { i in
            ProgressPhoto(
                journeyId: UUID(),
                date: Date().addingTimeInterval(TimeInterval(i * 86400)),
                assetLocalId: "photo-\(i)",
                isFrontCamera: true
            )
        }

        measure {
            // Simulate processing photos
            _ = photos.sorted { $0.date < $1.date }
            _ = photos.filter { !$0.isHidden }
            _ = photos.map { $0.assetLocalId }
        }
    }

    // MARK: - Helper Methods

    private func createTestImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private struct TestDataPoint {
        let value: Double
    }

    // MARK: - Baseline Performance Goals

    /// These tests document expected performance baselines
    /// Failures indicate performance regressions

    func testPerformance_StatsCalculation_CompletesFast() {
        let data = (0..<1000).map { TestDataPoint(value: Double($0)) }
        let startTime = Date()

        for _ in 0..<100 {
            _ = StatsFormatters.getStats(data, valueKeyPath: \.value)
        }

        let elapsed = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(elapsed, 1.0, "100 iterations of stats calculation should complete in < 1 second")
    }

    func testPerformance_ImageCrop_CompletesFast() {
        let image = createTestImage(size: CGSize(width: 1000, height: 1000))
        let startTime = Date()

        for _ in 0..<10 {
            _ = PhotoStore.cropTo4x5(image)
        }

        let elapsed = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(elapsed, 2.0, "10 image crops should complete in < 2 seconds")
    }
}
