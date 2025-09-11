import SwiftUI
import SwiftData

@main
struct ProgressPicApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(
                    for: [Journey.self, ProgressPhoto.self, MeasurementEntry.self]
                )
        }
    }
}
