import XCTest
import SwiftData
@testable import ProgressPic

/// Test suite for SwiftData model relationships and cascade deletes
/// Validates Journey, ProgressPhoto, MeasurementEntry, and JourneyReminder relationships
final class ModelRelationshipTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()

        // Create an in-memory model container for testing
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
    }

    override func tearDown() async throws {
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }

    // MARK: - Journey Tests

    func testJourney_Initialization_SetsDefaultValues() {
        let journey = Journey(name: "Test Journey")

        XCTAssertEqual(journey.name, "Test Journey")
        XCTAssertFalse(journey.saveToCameraRoll)
        XCTAssertTrue(journey.autoSyncStartDate)
        XCTAssertEqual(journey.sortOrder, 0)
        XCTAssertEqual(journey.photoCount, 0)
        XCTAssertNotNil(journey.id)
    }

    func testJourney_WithCustomValues_StoresCorrectly() {
        let journey = Journey(
            name: "Custom Journey",
            saveToCameraRoll: true,
            autoSyncStartDate: false,
            template: "fitness",
            sortOrder: 5
        )

        XCTAssertEqual(journey.name, "Custom Journey")
        XCTAssertTrue(journey.saveToCameraRoll)
        XCTAssertFalse(journey.autoSyncStartDate)
        XCTAssertEqual(journey.template, "fitness")
        XCTAssertEqual(journey.sortOrder, 5)
    }

    func testJourney_EmptyRelationships_InitializeAsEmptyArrays() {
        let journey = Journey(name: "Test")

        XCTAssertNotNil(journey.photos)
        XCTAssertNotNil(journey.measurements)
        XCTAssertNotNil(journey.reminders)
        XCTAssertEqual(journey.photos?.count, 0)
        XCTAssertEqual(journey.measurements?.count, 0)
        XCTAssertEqual(journey.reminders?.count, 0)
    }

    func testJourney_InsertAndFetch_Succeeds() throws {
        let journey = Journey(name: "Fetchable Journey")
        modelContext.insert(journey)
        try modelContext.save()

        // Fetch the journey
        let descriptor = FetchDescriptor<Journey>()
        let fetchedJourneys = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetchedJourneys.count, 1)
        XCTAssertEqual(fetchedJourneys.first?.name, "Fetchable Journey")
    }

    // MARK: - ProgressPhoto Tests

    func testProgressPhoto_Initialization_SetsValues() {
        let journeyId = UUID()
        let photo = ProgressPhoto(
            journeyId: journeyId,
            date: Date(),
            assetLocalId: "test-asset-123",
            isFrontCamera: true
        )

        XCTAssertEqual(photo.journeyId, journeyId)
        XCTAssertEqual(photo.assetLocalId, "test-asset-123")
        XCTAssertTrue(photo.isFrontCamera)
        XCTAssertFalse(photo.isHidden)
        XCTAssertNotNil(photo.id)
    }

    func testProgressPhoto_WithNotes_StoresCorrectly() {
        let photo = ProgressPhoto(
            journeyId: UUID(),
            date: Date(),
            assetLocalId: "test-asset",
            isFrontCamera: true,
            notes: "Test note"
        )

        XCTAssertEqual(photo.notes, "Test note")
    }

    func testProgressPhoto_Hidden_CanBeSet() {
        let photo = ProgressPhoto(
            journeyId: UUID(),
            date: Date(),
            assetLocalId: "test-asset",
            isFrontCamera: true,
            isHidden: true
        )

        XCTAssertTrue(photo.isHidden)
    }

    // MARK: - MeasurementEntry Tests

    func testMeasurementEntry_Initialization_SetsValues() {
        let journeyId = UUID()
        let measurement = MeasurementEntry(
            journeyId: journeyId,
            date: Date(),
            type: .weight,
            value: 75.5,
            unit: .kg
        )

        XCTAssertEqual(measurement.journeyId, journeyId)
        XCTAssertEqual(measurement.value, 75.5)
        XCTAssertEqual(measurement.type, .weight)
        XCTAssertEqual(measurement.unit, .kg)
        XCTAssertNotNil(measurement.id)
    }

    func testMeasurementEntry_TypeRawValue_StoresCorrectly() {
        let measurement = MeasurementEntry(
            journeyId: UUID(),
            date: Date(),
            type: .bicepsLeft,
            value: 35.0,
            unit: .cm
        )

        XCTAssertEqual(measurement.typeRaw, "bicepsLeft")
        XCTAssertEqual(measurement.type, .bicepsLeft)
    }

    func testMeasurementEntry_UnitRawValue_StoresCorrectly() {
        let measurement = MeasurementEntry(
            journeyId: UUID(),
            date: Date(),
            type: .weight,
            value: 165.0,
            unit: .lb
        )

        XCTAssertEqual(measurement.unitRaw, "lb")
        XCTAssertEqual(measurement.unit, .lb)
    }

    func testMeasurementEntry_WithLabel_StoresCorrectly() {
        let measurement = MeasurementEntry(
            journeyId: UUID(),
            date: Date(),
            type: .weight,
            value: 75.0,
            unit: .kg,
            label: "Morning weight"
        )

        XCTAssertEqual(measurement.label, "Morning weight")
    }

    // MARK: - JourneyReminder Tests

    func testJourneyReminder_Initialization_SetsValues() {
        let reminder = JourneyReminder(
            hour: 10,
            minute: 30,
            daysBitmask: 127,
            notificationText: "Time for a photo!"
        )

        XCTAssertEqual(reminder.hour, 10)
        XCTAssertEqual(reminder.minute, 30)
        XCTAssertEqual(reminder.daysBitmask, 127)
        XCTAssertEqual(reminder.notificationText, "Time for a photo!")
        XCTAssertNotNil(reminder.id)
    }

    func testJourneyReminder_SelectedDays_AllDaysSet() {
        let reminder = JourneyReminder(
            hour: 10,
            minute: 0,
            daysBitmask: 127, // All 7 days (bits 0-6 set)
            notificationText: "Test"
        )

        let selectedDays = reminder.selectedDays
        XCTAssertEqual(selectedDays.count, 7)
        XCTAssertTrue(selectedDays.contains(1))
        XCTAssertTrue(selectedDays.contains(7))
    }

    func testJourneyReminder_SelectedDays_WeekdaysOnly() {
        // Weekdays only: Monday-Friday (days 1-5)
        // Bitmask: 0b00011111 = 31
        let reminder = JourneyReminder(
            hour: 9,
            minute: 0,
            daysBitmask: 31,
            notificationText: "Weekday reminder"
        )

        let selectedDays = reminder.selectedDays
        XCTAssertEqual(selectedDays.count, 5)
        XCTAssertTrue(selectedDays.contains(1)) // Monday
        XCTAssertTrue(selectedDays.contains(5)) // Friday
        XCTAssertFalse(selectedDays.contains(6)) // Saturday
        XCTAssertFalse(selectedDays.contains(7)) // Sunday
    }

    func testJourneyReminder_SelectedDays_WeekendsOnly() {
        // Weekends only: Saturday-Sunday (days 6-7)
        // Bitmask: 0b01100000 = 96
        let reminder = JourneyReminder(
            hour: 10,
            minute: 0,
            daysBitmask: 96,
            notificationText: "Weekend reminder"
        )

        let selectedDays = reminder.selectedDays
        XCTAssertEqual(selectedDays.count, 2)
        XCTAssertTrue(selectedDays.contains(6)) // Saturday
        XCTAssertTrue(selectedDays.contains(7)) // Sunday
        XCTAssertFalse(selectedDays.contains(1)) // Monday
    }

    // MARK: - Relationship Tests

    func testJourney_AddPhoto_EstablishesRelationship() throws {
        let journey = Journey(name: "Test Journey")
        modelContext.insert(journey)

        let photo = ProgressPhoto(
            journeyId: journey.id,
            date: Date(),
            assetLocalId: "test-asset",
            isFrontCamera: true
        )
        photo.journey = journey
        modelContext.insert(photo)

        try modelContext.save()

        // Verify relationship
        XCTAssertEqual(journey.photos?.count, 1)
        XCTAssertEqual(journey.photos?.first?.assetLocalId, "test-asset")
        XCTAssertEqual(photo.journey?.name, "Test Journey")
    }

    func testJourney_AddMeasurement_EstablishesRelationship() throws {
        let journey = Journey(name: "Test Journey")
        modelContext.insert(journey)

        let measurement = MeasurementEntry(
            journeyId: journey.id,
            date: Date(),
            type: .weight,
            value: 75.0,
            unit: .kg
        )
        measurement.journey = journey
        modelContext.insert(measurement)

        try modelContext.save()

        // Verify relationship
        XCTAssertEqual(journey.measurements?.count, 1)
        XCTAssertEqual(journey.measurements?.first?.value, 75.0)
        XCTAssertEqual(measurement.journey?.name, "Test Journey")
    }

    func testJourney_AddReminder_EstablishesRelationship() throws {
        let journey = Journey(name: "Test Journey")
        modelContext.insert(journey)

        let reminder = JourneyReminder(
            hour: 10,
            minute: 30,
            daysBitmask: 127,
            notificationText: "Test reminder"
        )
        reminder.journey = journey
        modelContext.insert(reminder)

        try modelContext.save()

        // Verify relationship
        XCTAssertEqual(journey.reminders?.count, 1)
        XCTAssertEqual(journey.reminders?.first?.hour, 10)
        XCTAssertEqual(reminder.journey?.name, "Test Journey")
    }

    func testJourney_MultiplePhotos_AllRelated() throws {
        let journey = Journey(name: "Multi Photo Journey")
        modelContext.insert(journey)

        // Add 3 photos
        for i in 0..<3 {
            let photo = ProgressPhoto(
                journeyId: journey.id,
                date: Date(),
                assetLocalId: "asset-\(i)",
                isFrontCamera: true
            )
            photo.journey = journey
            modelContext.insert(photo)
        }

        try modelContext.save()

        XCTAssertEqual(journey.photos?.count, 3)
    }

    // MARK: - Cascade Delete Tests

    func testJourney_Delete_CascadesPhotos() throws {
        let journey = Journey(name: "Delete Test Journey")
        modelContext.insert(journey)

        let photo = ProgressPhoto(
            journeyId: journey.id,
            date: Date(),
            assetLocalId: "test-asset",
            isFrontCamera: true
        )
        photo.journey = journey
        modelContext.insert(photo)

        try modelContext.save()

        // Verify photo exists
        var photoDescriptor = FetchDescriptor<ProgressPhoto>()
        var fetchedPhotos = try modelContext.fetch(photoDescriptor)
        XCTAssertEqual(fetchedPhotos.count, 1)

        // Delete journey
        modelContext.delete(journey)
        try modelContext.save()

        // Verify photo was cascade deleted
        photoDescriptor = FetchDescriptor<ProgressPhoto>()
        fetchedPhotos = try modelContext.fetch(photoDescriptor)
        XCTAssertEqual(fetchedPhotos.count, 0, "Photo should be cascade deleted with journey")
    }

    func testJourney_Delete_CascadesMeasurements() throws {
        let journey = Journey(name: "Delete Test Journey")
        modelContext.insert(journey)

        let measurement = MeasurementEntry(
            journeyId: journey.id,
            date: Date(),
            type: .weight,
            value: 75.0,
            unit: .kg
        )
        measurement.journey = journey
        modelContext.insert(measurement)

        try modelContext.save()

        // Verify measurement exists
        var measurementDescriptor = FetchDescriptor<MeasurementEntry>()
        var fetchedMeasurements = try modelContext.fetch(measurementDescriptor)
        XCTAssertEqual(fetchedMeasurements.count, 1)

        // Delete journey
        modelContext.delete(journey)
        try modelContext.save()

        // Verify measurement was cascade deleted
        measurementDescriptor = FetchDescriptor<MeasurementEntry>()
        fetchedMeasurements = try modelContext.fetch(measurementDescriptor)
        XCTAssertEqual(fetchedMeasurements.count, 0, "Measurement should be cascade deleted with journey")
    }

    func testJourney_Delete_CascadesReminders() throws {
        let journey = Journey(name: "Delete Test Journey")
        modelContext.insert(journey)

        let reminder = JourneyReminder(
            hour: 10,
            minute: 0,
            daysBitmask: 127,
            notificationText: "Test"
        )
        reminder.journey = journey
        modelContext.insert(reminder)

        try modelContext.save()

        // Verify reminder exists
        var reminderDescriptor = FetchDescriptor<JourneyReminder>()
        var fetchedReminders = try modelContext.fetch(reminderDescriptor)
        XCTAssertEqual(fetchedReminders.count, 1)

        // Delete journey
        modelContext.delete(journey)
        try modelContext.save()

        // Verify reminder was cascade deleted
        reminderDescriptor = FetchDescriptor<JourneyReminder>()
        fetchedReminders = try modelContext.fetch(reminderDescriptor)
        XCTAssertEqual(fetchedReminders.count, 0, "Reminder should be cascade deleted with journey")
    }

    func testJourney_Delete_CascadesAllRelatedData() throws {
        let journey = Journey(name: "Full Delete Test")
        modelContext.insert(journey)

        // Add photo
        let photo = ProgressPhoto(
            journeyId: journey.id,
            date: Date(),
            assetLocalId: "test-asset",
            isFrontCamera: true
        )
        photo.journey = journey
        modelContext.insert(photo)

        // Add measurement
        let measurement = MeasurementEntry(
            journeyId: journey.id,
            date: Date(),
            type: .weight,
            value: 75.0,
            unit: .kg
        )
        measurement.journey = journey
        modelContext.insert(measurement)

        // Add reminder
        let reminder = JourneyReminder(
            hour: 10,
            minute: 0,
            daysBitmask: 127,
            notificationText: "Test"
        )
        reminder.journey = journey
        modelContext.insert(reminder)

        try modelContext.save()

        // Delete journey
        modelContext.delete(journey)
        try modelContext.save()

        // Verify all related data was deleted
        let photoDescriptor = FetchDescriptor<ProgressPhoto>()
        let fetchedPhotos = try modelContext.fetch(photoDescriptor)
        XCTAssertEqual(fetchedPhotos.count, 0)

        let measurementDescriptor = FetchDescriptor<MeasurementEntry>()
        let fetchedMeasurements = try modelContext.fetch(measurementDescriptor)
        XCTAssertEqual(fetchedMeasurements.count, 0)

        let reminderDescriptor = FetchDescriptor<JourneyReminder>()
        let fetchedReminders = try modelContext.fetch(reminderDescriptor)
        XCTAssertEqual(fetchedReminders.count, 0)
    }

    // MARK: - Query Performance Tests

    func testQuery_ByJourneyId_UsesIndex() throws {
        // Create multiple journeys
        let journey1 = Journey(name: "Journey 1")
        let journey2 = Journey(name: "Journey 2")
        modelContext.insert(journey1)
        modelContext.insert(journey2)

        // Add photos to both
        for i in 0..<10 {
            let photo1 = ProgressPhoto(
                journeyId: journey1.id,
                date: Date(),
                assetLocalId: "j1-asset-\(i)",
                isFrontCamera: true
            )
            photo1.journey = journey1
            modelContext.insert(photo1)

            let photo2 = ProgressPhoto(
                journeyId: journey2.id,
                date: Date(),
                assetLocalId: "j2-asset-\(i)",
                isFrontCamera: true
            )
            photo2.journey = journey2
            modelContext.insert(photo2)
        }

        try modelContext.save()

        // Query photos by journey ID (should use index)
        let predicate = #Predicate<ProgressPhoto> { photo in
            photo.journeyId == journey1.id
        }
        let descriptor = FetchDescriptor<ProgressPhoto>(predicate: predicate)
        let fetchedPhotos = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetchedPhotos.count, 10)
        XCTAssertTrue(fetchedPhotos.allSatisfy { $0.journeyId == journey1.id })
    }

    func testQuery_ByJourneyIdAndDate_UsesCompositeIndex() throws {
        let journey = Journey(name: "Test Journey")
        modelContext.insert(journey)

        // Add photos with different dates
        let calendar = Calendar.current
        for i in 0..<5 {
            let date = calendar.date(byAdding: .day, value: i, to: Date())!
            let photo = ProgressPhoto(
                journeyId: journey.id,
                date: date,
                assetLocalId: "asset-\(i)",
                isFrontCamera: true
            )
            photo.journey = journey
            modelContext.insert(photo)
        }

        try modelContext.save()

        // Query photos by journey ID and date range (should use composite index)
        let targetDate = calendar.date(byAdding: .day, value: 2, to: Date())!
        let predicate = #Predicate<ProgressPhoto> { photo in
            photo.journeyId == journey.id && photo.date >= targetDate
        }
        let descriptor = FetchDescriptor<ProgressPhoto>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date)]
        )
        let fetchedPhotos = try modelContext.fetch(descriptor)

        XCTAssertGreaterThanOrEqual(fetchedPhotos.count, 3)
    }
}
