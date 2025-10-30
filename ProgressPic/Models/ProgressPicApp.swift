import SwiftUI
import SwiftData

@main
struct ProgressPicApp: App {
    let container: ModelContainer

    init() {
        // ICLOUD SYNC ENABLED
        // To enable iCloud: Ensure Capabilities > iCloud > CloudKit is ON in Xcode.
        // Container ID: Use automatic or specify your own (e.g., "iCloud.com.yourdomain.ProgressPic")
        do {
            let schema = Schema([Journey.self, ProgressPhoto.self, MeasurementEntry.self])
            
            // Check if iCloud is available
            let isICloudAvailable = FileManager.default.ubiquityIdentityToken != nil
            
            if isICloudAvailable {
                // Create configuration with iCloud CloudKit enabled
                let config = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    allowsSave: true,
                    groupContainer: .none,
                    cloudKitDatabase: .automatic // Enable CloudKit with automatic container
                )
                
                container = try ModelContainer(for: schema, configurations: config)
                print("✅ SwiftData ModelContainer initialized with iCloud CloudKit sync")
            } else {
                // iCloud not available - use local storage
                let config = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    allowsSave: true,
                    groupContainer: .none,
                    cloudKitDatabase: .none
                )
                
                container = try ModelContainer(for: schema, configurations: config)
                print("⚠️ iCloud not available - using local storage only")
            }
        } catch {
            print("❌ Failed to create ModelContainer: \(error)")
            // Create a fallback in-memory container
            do {
                let schema = Schema([Journey.self, ProgressPhoto.self, MeasurementEntry.self])
                let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = try ModelContainer(for: schema, configurations: fallbackConfig)
                print("⚠️ Using fallback in-memory container")
            } catch {
                fatalError("Failed to create fallback ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)     // Force dark everywhere
                .tint(.white)                    // Make all toggles/segmented/buttons white instead of blue
                .modelContainer(container)
        }
    }
}
