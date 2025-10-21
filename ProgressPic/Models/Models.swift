import SwiftUI
import SwiftData
import Photos

// MARK: - Domain models (SwiftData + CloudKit)
@Model
final class JourneyReminder {
    var id: UUID = UUID()
    var hour: Int = 10
    var minute: Int = 0
    var daysBitmask: Int = 127 // All days by default (1-7 bits set)
    var notificationText: String = "Time for a new photo!"
    
    var journey: Journey? = nil
    
    init(hour: Int, minute: Int, daysBitmask: Int, notificationText: String) {
        self.id = UUID()
        self.hour = hour
        self.minute = minute
        self.daysBitmask = daysBitmask
        self.notificationText = notificationText
    }
    
    var selectedDays: Set<Int> {
        var days: Set<Int> = []
        for day in 1...7 {
            if daysBitmask & (1 << (day - 1)) != 0 {
                days.insert(day)
            }
        }
        return days
    }
}

@Model
final class Journey {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date.now
    var coverAssetLocalId: String? = nil   // PHAsset localIdentifier
    var saveToCameraRoll: Bool = false
    var template: String? = nil
    var sortOrder: Int = 0  // For manual reordering

    @Relationship(deleteRule: .cascade, inverse: \ProgressPhoto.journey) var photos: [ProgressPhoto]? = []
    @Relationship(deleteRule: .cascade, inverse: \MeasurementEntry.journey) var measurements: [MeasurementEntry]? = []
    @Relationship(deleteRule: .cascade, inverse: \JourneyReminder.journey) var reminders: [JourneyReminder]? = []

    init(name: String,
         createdAt: Date = .now,
         saveToCameraRoll: Bool = false,
         template: String? = nil,
         sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.createdAt = createdAt
        self.saveToCameraRoll = saveToCameraRoll
        self.template = template
        self.sortOrder = sortOrder
    }
}

@Model
final class ProgressPhoto {
    var id: UUID = UUID()
    var journeyId: UUID = UUID()        // denormalized for convenience
    var date: Date = Date.now
    var assetLocalId: String = ""   // PHAsset localIdentifier - stores the cropped image
    var originalAssetLocalId: String? = nil  // Stores the original uncropped image for re-cropping
    var isFrontCamera: Bool = true
    var alignTransform: AlignTransform = AlignTransform.identity  // saved transform
    var notes: String? = nil  // User notes attached to photo
    var isHidden: Bool = false  // Hide from Watch/Compare

    var journey: Journey? = nil

    init(journeyId: UUID, date: Date, assetLocalId: String, isFrontCamera: Bool, alignTransform: AlignTransform = .identity, notes: String? = nil, isHidden: Bool = false, originalAssetLocalId: String? = nil) {
        self.id = UUID()
        self.journeyId = journeyId
        self.date = date
        self.assetLocalId = assetLocalId
        self.originalAssetLocalId = originalAssetLocalId
        self.isFrontCamera = isFrontCamera
        self.alignTransform = alignTransform
        self.notes = notes
        self.isHidden = isHidden
    }
}

@Model
final class MeasurementEntry {
    var id: UUID = UUID()
    var journeyId: UUID = UUID()
    var date: Date = Date.now
    var typeRaw: String = "weight"
    var value: Double = 0.0
    var unitRaw: String = "kg"
    var label: String? = nil
    
    var journey: Journey? = nil

    var type: MeasurementType { get { MeasurementType(rawValue: typeRaw) ?? .weight }
        set { typeRaw = newValue.rawValue } }
    var unit: MeasureUnit { get { MeasureUnit(rawValue: unitRaw) ?? .kg }
        set { unitRaw = newValue.rawValue } }

    init(journeyId: UUID, date: Date, type: MeasurementType, value: Double, unit: MeasureUnit, label: String? = nil) {
        self.id = UUID()
        self.journeyId = journeyId
        self.date = date
        self.typeRaw = type.rawValue
        self.value = value
        self.unitRaw = unit.rawValue
        self.label = label
    }
}


// MARK: - Enums & helpers
enum MeasurementType: String, CaseIterable, Identifiable {
    case weight, bodyFat, chest, waist, hips, neck
    case bicepsLeft, bicepsRight
    case forearmLeft, forearmRight
    case thighLeft, thighRight
    case calfLeft, calfRight
    case custom
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .weight: return "Weight"
        case .bodyFat: return "Body Fat %"
        case .chest: return "Chest"
        case .waist: return "Waist"
        case .hips: return "Hips"
        case .neck: return "Neck"
        case .bicepsLeft: return "Biceps (L)"
        case .bicepsRight: return "Biceps (R)"
        case .forearmLeft: return "Forearm (L)"
        case .forearmRight: return "Forearm (R)"
        case .thighLeft: return "Thigh (L)"
        case .thighRight: return "Thigh (R)"
        case .calfLeft: return "Calf (L)"
        case .calfRight: return "Calf (R)"
        case .custom: return "Custom"
        }
    }
    
    // Get the paired measurement (left <-> right)
    var pairedMeasurement: MeasurementType? {
        switch self {
        case .bicepsLeft: return .bicepsRight
        case .bicepsRight: return .bicepsLeft
        case .forearmLeft: return .forearmRight
        case .forearmRight: return .forearmLeft
        case .thighLeft: return .thighRight
        case .thighRight: return .thighLeft
        case .calfLeft: return .calfRight
        case .calfRight: return .calfLeft
        default: return nil
        }
    }
    
    // Check if this measurement has a left/right variant
    var hasPairedVariant: Bool {
        return pairedMeasurement != nil
    }
    
    // Get the base name without L/R
    var baseName: String {
        switch self {
        case .bicepsLeft, .bicepsRight: return "Biceps"
        case .forearmLeft, .forearmRight: return "Forearm"
        case .thighLeft, .thighRight: return "Thigh"
        case .calfLeft, .calfRight: return "Calf"
        default: return title
        }
    }
    
    // Check if this is the left variant
    var isLeft: Bool {
        switch self {
        case .bicepsLeft, .forearmLeft, .thighLeft, .calfLeft: return true
        default: return false
        }
    }
}

enum MeasureUnit: String, CaseIterable, Identifiable, Codable {
    case kg, lb, cm, inch, percent
    var id: String { rawValue }
}

// Saved transform for alignment (drag/zoom/rotate)
struct AlignTransform: Codable, Hashable {
    var scale: CGFloat
    var offsetX: CGFloat
    var offsetY: CGFloat
    var rotation: Double  // radians

    static let identity = AlignTransform(scale: 1, offsetX: 0, offsetY: 0, rotation: 0)
}

// MARK: - Pagination Helper
struct PaginatedQuery<T> {
    let items: [T]
    let hasMore: Bool
    let totalCount: Int?

    init(items: [T], hasMore: Bool, totalCount: Int? = nil) {
        self.items = items
        self.hasMore = hasMore
        self.totalCount = totalCount
    }
}

// Helper for paginated SwiftData queries
extension ModelContext {
    func fetchPaginated<T: PersistentModel>(
        _ type: T.Type,
        predicate: Predicate<T>? = nil,
        sortBy sortDescriptors: [SortDescriptor<T>] = [],
        pageSize: Int = 50,
        page: Int = 0
    ) async throws -> PaginatedQuery<T> {
        let fetchDescriptor = FetchDescriptor<T>(
            predicate: predicate,
            sortBy: sortDescriptors
        )

        // Set range for pagination
        let startIndex = page * pageSize
        let endIndex = startIndex + pageSize

        // First get total count (expensive, so we cache it)
        let totalCount: Int?
        if let predicate = predicate {
            let countDescriptor = FetchDescriptor<T>(predicate: predicate)
            totalCount = try fetchCount(countDescriptor)
        } else {
            totalCount = try fetchCount(FetchDescriptor<T>())
        }

        // Fetch the page
        var mutableDescriptor = fetchDescriptor
        mutableDescriptor.fetchOffset = startIndex
        mutableDescriptor.fetchLimit = pageSize

        let items = try fetch(mutableDescriptor)

        return PaginatedQuery(
            items: items,
            hasMore: (totalCount ?? 0) > endIndex,
            totalCount: totalCount
        )
    }
}

// User Profile for health comparisons
struct UserProfile: Codable {
    var birthDate: Date?
    var heightCm: Double?
    var gender: Gender?
    var preferredUnit: MeasureUnit?
    
    enum Gender: String, Codable, CaseIterable {
        case male = "Male"
        case female = "Female"
    }
    
    var age: Int? {
        guard let birthDate = birthDate else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        return ageComponents.year
    }
    
    static func load() -> UserProfile {
        if let data = UserDefaults.standard.data(forKey: "UserProfile"),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            return profile
        }
        return UserProfile()
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "UserProfile")
        }
    }
}
