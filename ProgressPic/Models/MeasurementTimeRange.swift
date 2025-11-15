import Foundation

/// Time range options for filtering measurement data
enum MeasurementTimeRange: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case sixMonths = "6 Months"
    case year = "Year"
    case all = "All"

    var id: String { rawValue }
}

// MARK: - Measurement Type Description Extension
extension MeasurementType {
    /// Detailed description for each measurement type explaining what it measures
    var description: String {
        switch self {
        case .weight:
            return "Track your body weight over time. Weight is one of the most basic and important health metrics."
        case .bodyFat:
            return "Body fat percentage indicates the proportion of fat in your body composition."
        case .chest:
            return "Chest measurement is taken around the fullest part of your chest, typically at nipple level."
        case .waist:
            return "Waist measurement is taken at the narrowest point of your torso, typically above your belly button."
        case .hips:
            return "Hip measurement is taken at the widest part of your hips and buttocks."
        case .neck:
            return "Neck measurement is taken around the middle of your neck, below the Adam's apple. A key metric for body composition tracking."
        case .bicepsLeft, .bicepsRight:
            return "Bicep measurement is taken around the largest part of your upper arm when flexed. Track both arms to monitor muscle development."
        case .forearmLeft, .forearmRight:
            return "Forearm measurement is taken around the widest part of your lower arm, typically near the elbow. Important for grip and arm strength."
        case .thighLeft, .thighRight:
            return "Thigh measurement is taken around the largest part of your upper leg. Essential for tracking lower body muscle development."
        case .calfLeft, .calfRight:
            return "Calf measurement is taken around the largest part of your lower leg. Important for overall leg development and athleticism."
        case .custom:
            return "Custom measurement for tracking any body part or metric you choose."
        }
    }
}
