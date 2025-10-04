import SwiftUI
import SwiftData
import Photos

// MARK: - Domain models (SwiftData + CloudKit)
@Model
final class Journey {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date.now
    var coverAssetLocalId: String? = nil   // PHAsset localIdentifier
    var saveToCameraRoll: Bool = true
    var reminderTimes: [DateComponents] = [] // user-custom times
    var template: String? = nil

    @Relationship(deleteRule: .cascade, inverse: \ProgressPhoto.journey) var photos: [ProgressPhoto]? = []
    @Relationship(deleteRule: .cascade, inverse: \MeasurementEntry.journey) var measurements: [MeasurementEntry]? = []

    init(name: String,
         createdAt: Date = .now,
         saveToCameraRoll: Bool = true,
         reminderTimes: [DateComponents] = [],
         template: String? = nil) {
        self.id = UUID()
        self.name = name
        self.createdAt = createdAt
        self.saveToCameraRoll = saveToCameraRoll
        self.reminderTimes = reminderTimes
        self.template = template
    }
}

@Model
final class ProgressPhoto {
    var id: UUID = UUID()
    var journeyId: UUID = UUID()        // denormalized for convenience
    var date: Date = Date.now
    var assetLocalId: String = ""   // PHAsset localIdentifier
    var isFrontCamera: Bool = true
    var alignTransform: AlignTransform = AlignTransform.identity  // saved transform
    
    var journey: Journey? = nil

    init(journeyId: UUID, date: Date, assetLocalId: String, isFrontCamera: Bool, alignTransform: AlignTransform = .identity) {
        self.id = UUID()
        self.journeyId = journeyId
        self.date = date
        self.assetLocalId = assetLocalId
        self.isFrontCamera = isFrontCamera
        self.alignTransform = alignTransform
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
    case weight, bodyFat, chest, waist, hips, bicepsLeft, bicepsRight, thigh, calf, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .weight: return "Weight"
        case .bodyFat: return "Body Fat %"
        case .chest: return "Chest"
        case .waist: return "Waist"
        case .hips: return "Hips"
        case .bicepsLeft: return "Biceps (L)"
        case .bicepsRight: return "Biceps (R)"
        case .thigh: return "Thigh"
        case .calf: return "Calf"
        case .custom: return "Custom"
        }
    }
}

enum MeasureUnit: String, CaseIterable, Identifiable {
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
