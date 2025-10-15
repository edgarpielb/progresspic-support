import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var cameraService = CameraService()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        TabView(selection: $selectedTab) {
            JourneysView()
                .tabItem {
                    Image(systemName: "rectangle.stack")
                    Text("Journeys")
                }
                .tag(0)
            
            CameraHostView()
                .environmentObject(cameraService)
                .tabItem {
                    Image(systemName: "camera.fill")
                    Text("Camera")
                }
                .tag(1)
            
            ActivityView()
                .tabItem {
                    Image(systemName: "flame")
                    Text("Activity")
                }
                .tag(2)
        }
        .background(Color(red: 30/255, green: 32/255, blue: 35/255))
        .accentColor(.white)
        .toolbarBackground(Color(red: 30/255, green: 32/255, blue: 35/255), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .onAppear {
            // Fix any existing photos that don't have journey relationships set
            Task {
                await fixOrphanedPhotos()
            }

            // Add app-wide memory warning handler
            NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: .main
            ) { _ in
                print("⚠️ App-wide memory warning - clearing image cache")
                PhotoStore.clearCache()
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            // Stop camera when switching away from camera tab to save battery
            if newTab != 1 {
                cameraService.stopIfNotNeeded()
            }
        }
    }
    
    // MARK: - Migration Helper
    @MainActor
    private func fixOrphanedPhotos() async {
        do {
            // Fetch all journeys and photos
            let journeyDescriptor = FetchDescriptor<Journey>()
            let photoDescriptor = FetchDescriptor<ProgressPhoto>()
            
            let journeys = try modelContext.fetch(journeyDescriptor)
            let photos = try modelContext.fetch(photoDescriptor)
            
            // Create a lookup dictionary for journeys by ID
            let journeyLookup = Dictionary(uniqueKeysWithValues: journeys.map { ($0.id, $0) })
            
            var fixedCount = 0
            
            // Fix photos that don't have journey relationship set
            for photo in photos {
                if photo.journey == nil, let journey = journeyLookup[photo.journeyId] {
                    photo.journey = journey
                    fixedCount += 1
                }
            }
            
            if fixedCount > 0 {
                try modelContext.save()
                print("🔧 Fixed \(fixedCount) orphaned photos")
            } else {
                print("✅ No orphaned photos found")
            }
        } catch {
            print("⚠️ Failed to fix orphaned photos: \(error)")
        }
    }
}

#Preview { ContentView() }