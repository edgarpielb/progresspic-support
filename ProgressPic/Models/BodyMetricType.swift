import Foundation
import HealthKit

/// Represents different body composition metrics tracked via HealthKit
enum BodyMetricType {
    case bodyFat
    case bmi
    case leanMass
    case weight

    var title: String {
        switch self {
        case .bodyFat: return "Body Fat Percentage"
        case .bmi: return "Body Mass Index"
        case .leanMass: return "Lean Mass"
        case .weight: return "Weight"
        }
    }

    var icon: String {
        switch self {
        case .bodyFat: return "🔥"
        case .bmi: return "📊"
        case .leanMass: return "💪"
        case .weight: return "⚖️"
        }
    }

    var identifier: HKQuantityTypeIdentifier {
        switch self {
        case .bodyFat: return .bodyFatPercentage
        case .bmi: return .bodyMassIndex
        case .leanMass: return .leanBodyMass
        case .weight: return .bodyMass
        }
    }

    var description: String {
        switch self {
        case .bodyFat:
            return "Body fat percentage indicates the proportion of fat in your body composition. It's an important health metric that affects both athletic performance and long-term wellness. A balanced body fat percentage supports hormonal function, energy levels, and physical performance."
        case .bmi:
            return "Body Mass Index (BMI) is a measure of body fat based on height and weight. It's commonly used as a general indicator of whether a person has a healthy body weight. However, BMI doesn't directly measure body fat and may not be accurate for athletes or people with high muscle mass."
        case .leanMass:
            return "Lean Body Mass represents the weight of everything in your body except fat, including muscles, bones, organs, and water. Maintaining or increasing lean mass is important for metabolic health, physical strength, and overall fitness. Regular exercise, especially resistance training, can help preserve and build lean mass."
        case .weight:
            return "Body weight is the total mass of your body, including bones, muscles, fat, organs, and water. Monitoring your weight over time can help track changes in your overall health and fitness. However, weight alone doesn't tell the whole story—body composition metrics like body fat percentage and lean mass provide more insight."
        }
    }
}
