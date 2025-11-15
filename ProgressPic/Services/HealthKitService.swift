import SwiftUI
import HealthKit

// MARK: - HealthKit Service
struct BodyCompositionData {
    var weight: Double?
    var bodyFatPercentage: Double?
    var leanBodyMass: Double?
    var bmi: Double?
    var weightDate: Date?
    var bodyFatDate: Date?
    var leanMassDate: Date?
    var bmiDate: Date?
}

struct HealthDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

@MainActor
class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    private let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var bodyComposition = BodyCompositionData()

    private init() {
        // Check authorization status on init
        checkAuthorizationStatus()
    }

    private func checkAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            isAuthorized = false
            return
        }

        // Check if we have authorization by trying to get the status
        // Note: HealthKit doesn't provide a direct way to check read authorization
        // but we can infer it from UserDefaults or by attempting to read data
        let hasAuthorized = UserDefaults.standard.bool(forKey: "HealthKitAuthorized")
        isAuthorized = hasAuthorized
        print("📊 HealthKit authorization status: \(isAuthorized)")
    }
    
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit is not available on this device")
            return false
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKObjectType.quantityType(forIdentifier: .leanBodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyMassIndex)!
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            isAuthorized = true
            // Save authorization status to persist across app launches
            UserDefaults.standard.set(true, forKey: "HealthKitAuthorized")
            print("✅ HealthKit authorization granted")
            return true
        } catch {
            print("❌ HealthKit authorization failed: \(error)")
            isAuthorized = false
            UserDefaults.standard.set(false, forKey: "HealthKitAuthorized")
            return false
        }
    }
    
    func fetchBodyComposition() async {
        guard isAuthorized else {
            print("⚠️ HealthKit not authorized")
            return
        }
        
        async let weight = fetchMostRecent(.bodyMass)
        async let bodyFat = fetchMostRecent(.bodyFatPercentage)
        async let leanMass = fetchMostRecent(.leanBodyMass)
        async let bmi = fetchMostRecent(.bodyMassIndex)
        
        let results = await (weight, bodyFat, leanMass, bmi)
        
        bodyComposition = BodyCompositionData(
            weight: results.0?.value,
            bodyFatPercentage: results.0?.value != nil ? (results.1?.value ?? 0) * 100 : nil, // Convert to percentage
            leanBodyMass: results.2?.value,
            bmi: results.3?.value,
            weightDate: results.0?.date,
            bodyFatDate: results.1?.date,
            leanMassDate: results.2?.date,
            bmiDate: results.3?.date
        )
        
        print("📊 Body composition fetched:")
        print("  Weight: \(bodyComposition.weight ?? 0) kg")
        print("  Body Fat: \(bodyComposition.bodyFatPercentage ?? 0)%")
        print("  Lean Mass: \(bodyComposition.leanBodyMass ?? 0) kg")
        print("  BMI: \(bodyComposition.bmi ?? 0)")
    }
    
    private func fetchMostRecent(_ identifier: HKQuantityTypeIdentifier) async -> (value: Double, date: Date)? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return nil
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let wrappedQuery = HKSampleQuery(
                sampleType: quantityType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard error == nil,
                      let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let unit: HKUnit
                switch identifier {
                case .bodyMass, .leanBodyMass:
                    unit = .gramUnit(with: .kilo)
                case .bodyFatPercentage:
                    unit = .percent()
                case .bodyMassIndex:
                    unit = .count()
                default:
                    unit = .count()
                }
                
                let value = sample.quantity.doubleValue(for: unit)
                continuation.resume(returning: (value: value, date: sample.endDate))
            }
            
            healthStore.execute(wrappedQuery)
        }
    }
    
    func fetchHistoricalData(for identifier: HKQuantityTypeIdentifier, timeRange: TimeRange) async -> [HealthDataPoint] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return []
        }

        let endDate = Date()
        let startDate: Date

        switch timeRange {
        case .week:
            startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            startDate = Calendar.current.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        case .sixMonths:
            startDate = Calendar.current.date(byAdding: .month, value: -6, to: endDate) ?? endDate
        case .year:
            startDate = Calendar.current.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        case .all:
            startDate = Calendar.current.date(byAdding: .year, value: -10, to: endDate) ?? endDate
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

        // Add reasonable limit for large datasets to prevent memory issues
        let limit = timeRange == .all ? 1000 : HKObjectQueryNoLimit

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard error == nil,
                      let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let unit: HKUnit
                switch identifier {
                case .bodyMass, .leanBodyMass:
                    unit = .gramUnit(with: .kilo)
                case .bodyFatPercentage:
                    unit = .percent()
                case .bodyMassIndex:
                    unit = .count()
                default:
                    unit = .count()
                }

                let dataPoints = samples.map { sample in
                    var value = sample.quantity.doubleValue(for: unit)
                    // Convert body fat percentage to percentage (0-100)
                    if identifier == .bodyFatPercentage {
                        value *= 100
                    }
                    return HealthDataPoint(date: sample.endDate, value: value)
                }

                continuation.resume(returning: dataPoints)
            }

            healthStore.execute(query)
        }
    }
    
    func saveHealthData(type: HKQuantityTypeIdentifier, value: Double, date: Date) async -> Bool {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: type) else {
            print("⚠️ Unable to get quantity type for \(type)")
            return false
        }
        
        // Create the appropriate unit based on the type
        let unit: HKUnit
        switch type {
        case .bodyFatPercentage:
            unit = .percent()
        case .bodyMassIndex:
            unit = .count()
        case .leanBodyMass, .bodyMass:
            unit = .gramUnit(with: .kilo)
        default:
            unit = .count()
        }
        
        let quantity = HKQuantity(unit: unit, doubleValue: value)
        let sample = HKQuantitySample(type: quantityType, quantity: quantity, start: date, end: date)
        
        do {
            try await healthStore.save(sample)
            print("✅ Successfully saved \(type.rawValue) data to HealthKit")
            return true
        } catch {
            print("❌ Error saving to HealthKit: \(error.localizedDescription)")
            return false
        }
    }
    
    func deleteHealthData(identifier: HKQuantityTypeIdentifier, date: Date) async -> Bool {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            print("⚠️ Unable to get quantity type for \(identifier)")
            return false
        }
        
        // Create a predicate to find samples at the specific date
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: quantityType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    print("❌ Error querying samples to delete: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                    return
                }
                
                guard let samples = samples, !samples.isEmpty else {
                    print("⚠️ No samples found to delete")
                    continuation.resume(returning: false)
                    return
                }
                
                self.healthStore.delete(samples) { success, error in
                    if let error = error {
                        print("❌ Error deleting samples: \(error.localizedDescription)")
                        continuation.resume(returning: false)
                    } else if success {
                        print("✅ Successfully deleted \(samples.count) sample(s)")
                        continuation.resume(returning: true)
                    } else {
                        continuation.resume(returning: false)
                    }
                }
            }
            
            self.healthStore.execute(query)
        }
    }
}

enum TimeRange: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case sixMonths = "6 Months"
    case year = "Year"
    case all = "All"
    
    var id: String { rawValue }
}
