import SwiftUI

/// Provides demographic-based comparison ranges for measurements
/// Calculates average ranges based on user's gender, age, and height
struct MeasurementRangeComparison {
    let measurementType: MeasurementType
    let userValue: Double
    let userGender: UserProfile.Gender
    let userAge: Int
    let userHeight: Double // in cm

    /// Returns the average range for this measurement type based on user demographics
    var averageRange: ClosedRange<Double> {
        switch measurementType {
        case .weight:
            return averageWeight()
        case .bodyFat:
            return averageBodyFat()
        case .chest:
            return averageChest()
        case .waist:
            return averageWaist()
        case .hips:
            return averageHips()
        case .neck:
            return averageNeck()
        case .bicepsLeft, .bicepsRight:
            return averageBiceps()
        case .forearmLeft, .forearmRight:
            return averageForearm()
        case .thighLeft, .thighRight:
            return averageThigh()
        case .calfLeft, .calfRight:
            return averageCalf()
        case .custom:
            return 0...100 // No comparison for custom measurements
        }
    }

    /// Human-readable comparison text
    var comparisonText: String {
        // For custom measurements, don't show comparison
        if measurementType == .custom {
            return "Custom measurement"
        }

        let range = averageRange

        if userValue < range.lowerBound {
            return "Below average for your demographics"
        } else if userValue > range.upperBound {
            return "Above average for your demographics"
        } else {
            return "Within average range"
        }
    }

    /// Color for the comparison UI element
    var comparisonColor: Color {
        // Blue for informational (not a health judgment)
        return .blue
    }

    // MARK: - Average Calculation Methods

    /// Weight averages based on height (BMI-derived)
    private func averageWeight() -> ClosedRange<Double> {
        let heightM = userHeight / 100.0
        let heightSquared = heightM * heightM

        // BMI 20-25 is typical average range
        let minWeight = 20.0 * heightSquared
        let maxWeight = 25.0 * heightSquared

        return minWeight...maxWeight
    }

    /// Body fat percentage averages
    private func averageBodyFat() -> ClosedRange<Double> {
        var baseRange: (lower: Double, upper: Double)

        switch userGender {
        case .male:
            baseRange = (15, 20) // Average male
        case .female:
            baseRange = (23, 28) // Average female
        }

        // Adjust for age - body fat tends to increase with age (more gradual increase)
        let ageAdjustment: Double
        switch userAge {
        case 18...29:
            ageAdjustment = -1.5  // Younger adults typically leaner
        case 30...39:
            ageAdjustment = 0.0   // Baseline age group
        case 40...49:
            ageAdjustment = 1.5   // Gradual increase
        case 50...59:
            ageAdjustment = 2.5   // Continued increase
        case 60...:
            ageAdjustment = 3.5   // More moderate than before
        default:
            ageAdjustment = -1.5
        }

        return (baseRange.lower + ageAdjustment)...(baseRange.upper + ageAdjustment)
    }

    /// Chest measurement averages
    private func averageChest() -> ClosedRange<Double> {
        // Base measurements for average height (175.5cm male, 161.8cm female)
        var baseRange: (lower: Double, upper: Double)

        switch userGender {
        case .male:
            baseRange = (98, 110) // cm - Based on US average of 106.6cm
        case .female:
            baseRange = (88, 105) // cm - Based on US average of 100.1cm
        }

        // Scale based on height
        let heightRatio = userHeight / (userGender == .male ? 175.5 : 161.8)

        return (baseRange.lower * heightRatio)...(baseRange.upper * heightRatio)
    }

    /// Waist measurement averages
    private func averageWaist() -> ClosedRange<Double> {
        var baseRange: (lower: Double, upper: Double)

        switch userGender {
        case .male:
            baseRange = (80, 95) // cm - Updated based on US average of 95cm
        case .female:
            baseRange = (70, 89) // cm - Updated based on US average of 89cm
        }

        // Adjust for age - waist tends to increase with age (more moderate adjustments)
        let ageAdjustment: Double
        switch userAge {
        case 18...29:
            ageAdjustment = -3.0  // Younger adults typically have smaller waists
        case 30...39:
            ageAdjustment = 0.0   // Baseline age group
        case 40...49:
            ageAdjustment = 2.0   // Moderate increase
        case 50...59:
            ageAdjustment = 4.0   // Continued increase
        case 60...:
            ageAdjustment = 5.0   // More moderate than before
        default:
            ageAdjustment = -3.0
        }

        // Scale based on height
        let heightRatio = userHeight / (userGender == .male ? 175.5 : 161.8)

        return ((baseRange.lower + ageAdjustment) * heightRatio)...((baseRange.upper + ageAdjustment) * heightRatio)
    }

    /// Hip measurement averages
    private func averageHips() -> ClosedRange<Double> {
        var baseRange: (lower: Double, upper: Double)

        switch userGender {
        case .male:
            baseRange = (92, 104) // cm - Based on US average of 99.9cm
        case .female:
            baseRange = (94, 108) // cm - Based on US average of 101.4cm (women typically have wider hips)
        }

        // Scale based on height
        let heightRatio = userHeight / (userGender == .male ? 175.5 : 161.8)

        return (baseRange.lower * heightRatio)...(baseRange.upper * heightRatio)
    }

    /// Neck measurement averages
    private func averageNeck() -> ClosedRange<Double> {
        var baseRange: (lower: Double, upper: Double)

        switch userGender {
        case .male:
            baseRange = (38, 43) // cm - Updated based on anthropometric data
        case .female:
            baseRange = (32, 36) // cm - Updated based on anthropometric data
        }

        // Slight adjustment for age (neck can expand slightly with age due to weight gain)
        let ageAdjustment: Double
        switch userAge {
        case 18...29:
            ageAdjustment = -0.3  // Younger, typically leaner
        case 30...39:
            ageAdjustment = 0.0   // Baseline
        case 40...49:
            ageAdjustment = 0.3   // Slight increase
        case 50...:
            ageAdjustment = 0.5   // Modest increase
        default:
            ageAdjustment = -0.3
        }

        // Scale based on height
        let heightRatio = userHeight / (userGender == .male ? 175.5 : 161.8)

        return ((baseRange.lower + ageAdjustment) * heightRatio)...((baseRange.upper + ageAdjustment) * heightRatio)
    }

    /// Biceps measurement averages (flexed)
    private func averageBiceps() -> ClosedRange<Double> {
        var baseRange: (lower: Double, upper: Double)

        switch userGender {
        case .male:
            baseRange = (31, 39) // cm - Average for adult males
        case .female:
            baseRange = (26, 34) // cm - Average for adult females
        }

        // Adjust for age - muscle mass tends to decrease with age (more moderate decline)
        let ageAdjustment: Double
        switch userAge {
        case 18...29:
            ageAdjustment = 0.5   // Peak muscle years
        case 30...39:
            ageAdjustment = 0.0   // Baseline
        case 40...49:
            ageAdjustment = -0.5  // Slight decline
        case 50...59:
            ageAdjustment = -1.0  // Moderate decline (sarcopenia begins)
        case 60...:
            ageAdjustment = -1.5  // More pronounced decline
        default:
            ageAdjustment = 0.0
        }

        return (baseRange.lower + ageAdjustment)...(baseRange.upper + ageAdjustment)
    }

    /// Forearm measurement averages
    private func averageForearm() -> ClosedRange<Double> {
        var baseRange: (lower: Double, upper: Double)

        switch userGender {
        case .male:
            baseRange = (27, 31) // cm - Updated based on anthropometric data
        case .female:
            baseRange = (23, 27) // cm - Updated based on anthropometric data
        }

        // Adjust for age - muscle mass tends to decrease with age (moderate decline)
        let ageAdjustment: Double
        switch userAge {
        case 18...29:
            ageAdjustment = 0.3   // Peak muscle years
        case 30...39:
            ageAdjustment = 0.0   // Baseline
        case 40...49:
            ageAdjustment = -0.3  // Slight decline
        case 50...59:
            ageAdjustment = -0.6  // Moderate decline
        case 60...:
            ageAdjustment = -1.0  // More pronounced decline
        default:
            ageAdjustment = 0.0
        }

        return (baseRange.lower + ageAdjustment)...(baseRange.upper + ageAdjustment)
    }

    /// Thigh measurement averages
    private func averageThigh() -> ClosedRange<Double> {
        var baseRange: (lower: Double, upper: Double)

        switch userGender {
        case .male:
            baseRange = (52, 62) // cm - Updated based on anthropometric data
        case .female:
            baseRange = (54, 64) // cm - Slightly larger due to body fat distribution
        }

        // Scale based on height
        let heightRatio = userHeight / (userGender == .male ? 175.5 : 161.8)

        return (baseRange.lower * heightRatio)...(baseRange.upper * heightRatio)
    }

    /// Calf measurement averages
    private func averageCalf() -> ClosedRange<Double> {
        var baseRange: (lower: Double, upper: Double)

        switch userGender {
        case .male:
            baseRange = (36, 42) // cm - Updated based on anthropometric data
        case .female:
            baseRange = (34, 40) // cm - Updated based on anthropometric data
        }

        // Scale based on height
        let heightRatio = userHeight / (userGender == .male ? 175.5 : 161.8)

        return (baseRange.lower * heightRatio)...(baseRange.upper * heightRatio)
    }
}
