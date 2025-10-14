import SwiftUI
import SwiftData

@main
struct ProgressPicApp: App {
    let container: ModelContainer

    init() {
        // LOCAL by default
        // To enable iCloud: replace "iCloud.com.your.bundleid" with your container id,
        // then ensure Capabilities > iCloud > CloudKit is ON in Xcode.
        do {
            let schema = Schema([Journey.self, ProgressPhoto.self, MeasurementEntry.self])
            
            // Create configuration with better settings
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .none,
                cloudKitDatabase: .none
            )
            
            container = try ModelContainer(for: schema, configurations: config)
            print("✅ SwiftData ModelContainer initialized successfully")
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
