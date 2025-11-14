import XCTest
import SwiftData
@testable import ProgressPic

/// Integration workflow tests for ProgressPic
/// Validates end-to-end user workflows and component interactions
@MainActor
final class IntegrationWorkflowTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory model container for testing
        let schema = Schema([
            Journey.self,
            ProgressPhoto.self,
            MeasurementEntry.self,
            JourneyReminder.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        modelContainer = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )

        modelContext = ModelContext(modelContainer)

        // Clear PhotoStore cache
        PhotoStore.clearCache()
    }

    override func tearDown() async throws {
        modelContext = nil
        modelContainer = nil
        PhotoStore.clearCache()
        try await super.tearDown()
    }

    // MARK: - Journey Creation Workflow

    func testWorkflow_CreateJourney_Success() throws {
        // 1. Create journey
        let journey = Journey(name: "Weight Loss Journey")
        modelContext.insert(journey)
        try modelContext.save()

        // 2. Verify journey exists
        let descriptor = FetchDescriptor<Journey>()
        let journeys = try modelContext.fetch(descriptor)

        XCTAssertEqual(journeys.count, 1)
        XCTAssertEqual(journeys.first?.name, "Weight Loss Journey")
        XCTAssertEqual(journeys.first?.photoCount, 0)
        XCTAssertTrue(journeys.first?.autoSyncStartDate ?? false)
    }

    // MARK: - Add Photo Workflow

    func testWorkflow_AddPhotoToJourney_Success() throws {
        // 1. Create journey
        let journey = Journey(name: "Progress Journey")
        modelContext.insert(journey)

        // 2. Add photo
        let photo = ProgressPhoto(
            journeyId: journey.id,
            date: Date(),
            assetLocalId: "test-photo-123",
            isFrontCamera: true
        )
        photo.journey = journey
        modelContext.insert(photo)

        try modelContext.save()

        // 3. Verify photo is associated with journey
        XCTAssertEqual(journey.photos?.count, 1)
        XCTAssertEqual(photo.journey?.name, "Progress Journey")
    }

    // MARK: - Add Measurement Workflow

    func testWorkflow_AddMeasurementToJourney_Success() throws {
        // 1. Create journey
        let journey = Journey(name: "Fitness Journey")
        modelContext.insert(journey)

        // 2. Add measurement
        let measurement = MeasurementEntry(
            journeyId: journey.id,
            date: Date(),
            type: .weight,
            value: 75.5,
            unit: .kg
        )
        measurement.journey = journey
        modelContext.insert(measurement)

        try modelContext.save()

        // 3. Verify measurement is associated
        XCTAssertEqual(journey.measurements?.count, 1)
        XCTAssertEqual(measurement.value, 75.5)
        XCTAssertEqual(measurement.type, .weight)
    }

    // MARK: - Complete Journey Workflow

    func testWorkflow_CompleteJourney_MultiplePhotosAndMeasurements() throws {
        // 1. Create journey
        let journey = Journey(name: "30 Day Challenge")
        modelContext.insert(journey)

        // 2. Add 5 photos
        for i in 0..<5 {
            let photo = ProgressPhoto(
                journeyId: journey.id,
                date: Date().addingTimeInterval(TimeInterval(i * 86400)),
                assetLocalId: "photo-\(i)",
                isFrontCamera: true
            )
            photo.journey = journey
            modelContext.insert(photo)
        }

        // 3. Add 5 measurements
        for i in 0..<5 {
            let measurement = MeasurementEntry(
                journeyId: journey.id,
                date: Date().addingTimeInterval(TimeInterval(i * 86400)),
                type: .weight,
                value: 80.0 - Double(i) * 0.5,
                unit: .kg
            )
            measurement.journey = journey
            modelContext.insert(measurement)
        }

        // 4. Add reminder
        let reminder = JourneyReminder(
            hour: 9,
            minute: 0,
            daysBitmask: 127,
            notificationText: "Take your progress photo!"
        )
        reminder.journey = journey
        modelContext.insert(reminder)

        try modelContext.save()

        // 5. Verify complete journey
        XCTAssertEqual(journey.photos?.count, 5)
        XCTAssertEqual(journey.measurements?.count, 5)
        XCTAssertEqual(journey.reminders?.count, 1)

        // 6. Verify data can be queried
        let sortedPhotos = journey.photos?.sorted { $0.date < $1.date }
        XCTAssertEqual(sortedPhotos?.first?.assetLocalId, "photo-0")
        XCTAssertEqual(sortedPhotos?.last?.assetLocalId, "photo-4")

        let sortedMeasurements = journey.measurements?.sorted { $0.date < $1.date }
        XCTAssertEqual(sortedMeasurements?.first?.value, 80.0)
        XCTAssertEqual(sortedMeasurements?.last?.value, 78.0)
    }

    // MARK: - Delete Journey Workflow

    func testWorkflow_DeleteJourney_CascadesAllData() throws {
        // 1. Create complete journey
        let journey = Journey(name: "Test Journey")
        modelContext.insert(journey)

        let photo = ProgressPhoto(
            journeyId: journey.id,
            date: Date(),
            assetLocalId: "photo",
            isFrontCamera: true
        )
        photo.journey = journey
        modelContext.insert(photo)

        let measurement = MeasurementEntry(
            journeyId: journey.id,
            date: Date(),
            type: .weight,
            value: 75.0,
            unit: .kg
        )
        measurement.journey = journey
        modelContext.insert(measurement)

        let reminder = JourneyReminder(
            hour: 10,
            minute: 0,
            daysBitmask: 127,
            notificationText: "Test"
        )
        reminder.journey = journey
        modelContext.insert(reminder)

        try modelContext.save()

        // 2. Verify data exists
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Journey>()), 1)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<ProgressPhoto>()), 1)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<MeasurementEntry>()), 1)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<JourneyReminder>()), 1)

        // 3. Delete journey
        modelContext.delete(journey)
        try modelContext.save()

        // 4. Verify cascade delete
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Journey>()), 0)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<ProgressPhoto>()), 0)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<MeasurementEntry>()), 0)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<JourneyReminder>()), 0)
    }

    // MARK: - Multiple Journeys Workflow

    func testWorkflow_MultipleJourneys_Independent() throws {
        // 1. Create two journeys
        let journey1 = Journey(name: "Journey 1")
        let journey2 = Journey(name: "Journey 2")
        modelContext.insert(journey1)
        modelContext.insert(journey2)

        // 2. Add data to journey 1
        for i in 0..<3 {
            let photo = ProgressPhoto(
                journeyId: journey1.id,
                date: Date(),
                assetLocalId: "j1-photo-\(i)",
                isFrontCamera: true
            )
            photo.journey = journey1
            modelContext.insert(photo)
        }

        // 3. Add data to journey 2
        for i in 0..<5 {
            let photo = ProgressPhoto(
                journeyId: journey2.id,
                date: Date(),
                assetLocalId: "j2-photo-\(i)",
                isFrontCamera: true
            )
            photo.journey = journey2
            modelContext.insert(photo)
        }

        try modelContext.save()

        // 4. Verify journeys are independent
        XCTAssertEqual(journey1.photos?.count, 3)
        XCTAssertEqual(journey2.photos?.count, 5)

        // 5. Delete journey 1
        modelContext.delete(journey1)
        try modelContext.save()

        // 6. Verify journey 2 is unaffected
        XCTAssertEqual(journey2.photos?.count, 5)
        let predicate = #Predicate<ProgressPhoto> { photo in
            photo.journeyId == journey2.id
        }
        let remainingPhotos = try modelContext.fetch(FetchDescriptor(predicate: predicate))
        XCTAssertEqual(remainingPhotos.count, 5)
    }

    // MARK: - Camera View Model Workflow

    func testWorkflow_CameraViewModel_PhotoCapture() {
        // 1. Create view model with journey
        let journey = Journey(name: "Camera Test")
        let viewModel = CameraViewModel(journey: journey)

        // 2. Verify initial state
        XCTAssertNotNil(viewModel.selectedJourney)
        XCTAssertFalse(viewModel.timerActive)
        XCTAssertFalse(viewModel.ghostEnabled)

        // 3. Enable ghost overlay
        viewModel.ghostEnabled = true
        viewModel.ghostOpacity = 0.5

        XCTAssertTrue(viewModel.ghostEnabled)
        XCTAssertEqual(viewModel.ghostOpacity, 0.5)

        // 4. Start timer
        viewModel.startCountdown(seconds: 5)

        XCTAssertTrue(viewModel.timerActive)
        XCTAssertEqual(viewModel.countdownSeconds, 5)

        // 5. Simulate countdown
        viewModel.tickCountdown()
        XCTAssertEqual(viewModel.countdownSeconds, 4)
    }

    // MARK: - Stats Calculation Workflow

    func testWorkflow_StatsCalculation_WithMeasurements() throws {
        // 1. Create journey with measurements
        let journey = Journey(name: "Stats Test")
        modelContext.insert(journey)

        let measurements = [
            MeasurementEntry(journeyId: journey.id, date: Date(), type: .weight, value: 80.0, unit: .kg),
            MeasurementEntry(journeyId: journey.id, date: Date(), type: .weight, value: 78.5, unit: .kg),
            MeasurementEntry(journeyId: journey.id, date: Date(), type: .weight, value: 77.0, unit: .kg),
            MeasurementEntry(journeyId: journey.id, date: Date(), type: .weight, value: 79.0, unit: .kg)
        ]

        for measurement in measurements {
            measurement.journey = journey
            modelContext.insert(measurement)
        }

        try modelContext.save()

        // 2. Calculate stats
        let minFormatted = StatsFormatters.formatMin(measurements, valueKeyPath: \.value, unit: "kg")
        let maxFormatted = StatsFormatters.formatMax(measurements, valueKeyPath: \.value, unit: "kg")
        let avgFormatted = StatsFormatters.formatAverage(measurements, valueKeyPath: \.value, unit: "kg")

        // 3. Verify calculations
        XCTAssertEqual(minFormatted, "77.0 kg")
        XCTAssertEqual(maxFormatted, "80.0 kg")
        XCTAssertEqual(avgFormatted, "78.6 kg")

        // 4. Calculate domain for charting
        let domain = StatsFormatters.calculateYDomain(for: measurements, valueKeyPath: \.value)

        XCTAssertLessThan(domain.lowerBound, 77.0, "Domain should include padding below min")
        XCTAssertGreaterThan(domain.upperBound, 80.0, "Domain should include padding above max")
    }

    // MARK: - Date Formatting Workflow

    func testWorkflow_DateFormatting_WithPhotos() throws {
        // 1. Create photos with different dates
        let journey = Journey(name: "Date Test")
        modelContext.insert(journey)

        let calendar = Calendar.current
        let dates = (0..<7).map { i in
            calendar.date(byAdding: .day, value: i, to: Date())!
        }

        for (i, date) in dates.enumerated() {
            let photo = ProgressPhoto(
                journeyId: journey.id,
                date: date,
                assetLocalId: "photo-\(i)",
                isFrontCamera: true
            )
            photo.journey = journey
            modelContext.insert(photo)
        }

        try modelContext.save()

        // 2. Format dates
        let sortedPhotos = journey.photos?.sorted { $0.date < $1.date } ?? []
        let formatted = sortedPhotos.map { DateFormatters.formatFullDate($0.date) }

        // 3. Verify formatting
        XCTAssertEqual(formatted.count, 7)
        XCTAssertFalse(formatted.isEmpty)

        // 4. Format date range
        if let firstDate = sortedPhotos.first?.date,
           let lastDate = sortedPhotos.last?.date {
            let rangeFormatted = DateFormatters.formatDateRange(from: firstDate, to: lastDate)
            XCTAssertFalse(rangeFormatted.isEmpty)
        }
    }

    // MARK: - Review Request Workflow

    func testWorkflow_ReviewRequest_StreakProgression() {
        // 1. Start with clean state
        UserDefaults.standard.removeObject(forKey: "LastReviewRequestStreak")
        UserDefaults.standard.removeObject(forKey: "HasRequestedFinalReview")

        // 2. Progress through streaks
        ReviewRequestManager.checkAndRequestReview(currentStreak: 1)
        var lastStreak = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(lastStreak, 0, "No review at 1 day")

        ReviewRequestManager.checkAndRequestReview(currentStreak: 3)
        lastStreak = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(lastStreak, 3, "First review at 3 days")

        ReviewRequestManager.checkAndRequestReview(currentStreak: 7)
        lastStreak = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(lastStreak, 7, "Second review at 7 days")

        ReviewRequestManager.checkAndRequestReview(currentStreak: 14)
        lastStreak = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(lastStreak, 14, "Final review at 14 days")

        let hasFinal = UserDefaults.standard.bool(forKey: "HasRequestedFinalReview")
        XCTAssertTrue(hasFinal, "Final flag should be set")

        // 3. Verify no more reviews after final
        ReviewRequestManager.checkAndRequestReview(currentStreak: 30)
        lastStreak = UserDefaults.standard.integer(forKey: "LastReviewRequestStreak")
        XCTAssertEqual(lastStreak, 14, "No updates after final review")

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "LastReviewRequestStreak")
        UserDefaults.standard.removeObject(forKey: "HasRequestedFinalReview")
    }

    // MARK: - User Profile Workflow

    func testWorkflow_UserProfile_SaveLoadUpdate() {
        // 1. Create and save profile
        var profile = UserProfile()
        profile.heightCm = 175.0
        profile.gender = .male
        profile.preferredUnit = .kg
        profile.colorScheme = .cyan

        profile.save()

        // 2. Load profile
        let loadedProfile = UserProfile.load()

        XCTAssertEqual(loadedProfile.heightCm, 175.0)
        XCTAssertEqual(loadedProfile.gender, .male)
        XCTAssertEqual(loadedProfile.preferredUnit, .kg)
        XCTAssertEqual(loadedProfile.colorScheme, .cyan)

        // 3. Update profile
        var updatedProfile = loadedProfile
        updatedProfile.heightCm = 180.0
        updatedProfile.save()

        // 4. Verify update
        let finalProfile = UserProfile.load()
        XCTAssertEqual(finalProfile.heightCm, 180.0)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "UserProfile")
    }

    // MARK: - Complex Query Workflow

    func testWorkflow_ComplexQuery_FilterAndSort() throws {
        // 1. Create journey with mixed data
        let journey = Journey(name: "Query Test")
        modelContext.insert(journey)

        let calendar = Calendar.current

        // 2. Add photos over time, some hidden
        for i in 0..<10 {
            let photo = ProgressPhoto(
                journeyId: journey.id,
                date: calendar.date(byAdding: .day, value: i, to: Date())!,
                assetLocalId: "photo-\(i)",
                isFrontCamera: i % 2 == 0,
                isHidden: i % 3 == 0
            )
            photo.journey = journey
            modelContext.insert(photo)
        }

        try modelContext.save()

        // 3. Query visible photos only
        let predicate = #Predicate<ProgressPhoto> { photo in
            photo.journeyId == journey.id && photo.isHidden == false
        }
        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date)]
        )
        let visiblePhotos = try modelContext.fetch(descriptor)

        // 4. Verify filtered results
        XCTAssertEqual(visiblePhotos.count, 7, "Should have 7 visible photos (10 total - 3 hidden)")
        XCTAssertTrue(visiblePhotos.allSatisfy { !$0.isHidden })

        // 5. Verify sorted by date
        for i in 0..<(visiblePhotos.count - 1) {
            XCTAssertLessThan(visiblePhotos[i].date, visiblePhotos[i + 1].date)
        }
    }

    // MARK: - Photo Store Integration Workflow

    func testWorkflow_PhotoStore_SaveAndLoad() async throws {
        // 1. Create test image
        let testImage = createTestImage(color: .blue, size: CGSize(width: 200, height: 200))

        // 2. Crop image
        let croppedImage = PhotoStore.cropTo4x5(testImage)

        // 3. Verify aspect ratio
        let aspectRatio = croppedImage.size.width / croppedImage.size.height
        XCTAssertEqual(aspectRatio, 4.0/5.0, accuracy: 0.01)

        // 4. Save image
        let filename = try await PhotoStore.saveToAppDirectory(croppedImage)

        XCTAssertTrue(filename.hasSuffix(".jpg"))

        // 5. Load image back
        let loadedImage = PhotoStore.loadFromAppDirectory(filename: filename, targetSize: nil)

        XCTAssertNotNil(loadedImage)

        // 6. Cleanup
        try await PhotoStore.deleteFromAppDirectory(localId: filename)
    }

    // MARK: - Helper Methods

    private func createTestImage(color: UIColor, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
