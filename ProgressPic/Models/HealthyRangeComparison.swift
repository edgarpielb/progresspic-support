import SwiftUI

/// Provides healthy range comparisons for body composition metrics
/// Calculates healthy ranges based on user's gender, age, and height
struct HealthyRangeComparison {
    let metricType: BodyMetricType
    let userValue: Double
    let userGender: UserProfile.Gender
    let userHeight: Double? // in cm
    let userAge: Int?

    var healthyRange: ClosedRange<Double> {
        switch metricType {
        case .bodyFat:
            return healthyBodyFat(gender: userGender)
        case .bmi:
            return healthyBMI()
        case .leanMass:
            return averageLeanMass(gender: userGender, height: userHeight, age: userAge)
        case .weight:
            return healthyWeight(gender: userGender, height: userHeight)
        }
    }

    var rangeLabel: String {
        return metricType == .leanMass ? "Average range" : "Healthy range"
    }

    var comparisonText: String {
        let range = healthyRange

        // For lean mass, show comparison to average
        if metricType == .leanMass {
            if userValue < range.lowerBound {
                return "Below average for your demographics"
            } else if userValue > range.upperBound {
                return "Above average for your demographics"
            } else {
                return "Within average range"
            }
        }

        // For other metrics, use standard comparison
        if userValue < range.lowerBound {
            return "Below healthy range"
        } else if userValue > range.upperBound {
            return "Above healthy range"
        } else {
            return "Within healthy range"
        }
    }

    var comparisonColor: Color {
        let range = healthyRange

        // For lean mass, any value is "okay" - it's just informational
        if metricType == .leanMass {
            // Show blue for informational (not a health judgment)
            return .blue
        }

        // For other metrics, must be within range
        if userValue >= range.lowerBound && userValue <= range.upperBound {
            return .green
        } else {
            return .orange
        }
    }

    // MARK: - Healthy Range Calculations

    private func healthyBodyFat(gender: UserProfile.Gender) -> ClosedRange<Double> {
        // General healthy ranges based on fitness standards
        switch gender {
        case .male:
            return 10...20 // Athletic to fitness range
        case .female:
            return 18...28 // Athletic to fitness range
        }
    }

    private func healthyBMI() -> ClosedRange<Double> {
        return 18.5...24.9 // WHO healthy BMI range
    }

    private func averageLeanMass(gender: UserProfile.Gender, height: Double?, age: Int?) -> ClosedRange<Double> {
        guard let heightCm = height else {
            // Fallback to general averages
            switch gender {
            case .male: return 55...75
            case .female: return 40...60
            }
        }

        let heightM = heightCm / 100.0
        let heightSquared = heightM * heightM

        // Base lean mass index (LMI) ranges by gender
        // These are average population ranges, not "healthy" thresholds
        var baseLMI: (lower: Double, upper: Double)

        switch gender {
        case .male:
            baseLMI = (16.5, 20.5) // Average male range
        case .female:
            baseLMI = (13.5, 17.5) // Average female range
        }

        // Adjust for age - lean mass typically decreases with age
        if let userAge = age {
            let ageAdjustment: Double
            switch userAge {
            case 18...29:
                ageAdjustment = 0.5  // Young adults have more muscle
            case 30...39:
                ageAdjustment = 0.0  // Prime adult years
            case 40...49:
                ageAdjustment = -0.5 // Slight decline
            case 50...59:
                ageAdjustment = -1.0 // More decline
            case 60...69:
                ageAdjustment = -1.5 // Significant decline
            case 70...:
                ageAdjustment = -2.0 // Natural age-related loss
            default:
                ageAdjustment = 0.5  // Under 18, still developing
            }

            baseLMI.lower = Swift.max(10.0, baseLMI.lower + ageAdjustment)
            baseLMI.upper = Swift.max(baseLMI.lower + 2.0, baseLMI.upper + ageAdjustment)
        }

        // Calculate actual lean mass range based on height
        let minLean = heightSquared * baseLMI.lower
        let maxLean = heightSquared * baseLMI.upper

        return minLean...maxLean
    }

    private func healthyWeight(gender: UserProfile.Gender, height: Double?) -> ClosedRange<Double> {
        guard let heightCm = height else {
            // Fallback to average height estimates
            switch gender {
            case .male: return 60...80
            case .female: return 50...70
            }
        }

        let heightM = heightCm / 100.0
        let heightSquared = heightM * heightM

        // Use healthy BMI range (18.5-24.9) with user's actual height
        // Weight = BMI × Height²
        let minWeight = 18.5 * heightSquared
        let maxWeight = 24.9 * heightSquared

        return minWeight...maxWeight
    }
}
