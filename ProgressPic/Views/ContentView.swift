import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var cameraService = CameraService()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var cameraStopTask: Task<Void, Never>?
    
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
        .background(AppStyle.Colors.bgDark)
        .accentColor(.white)
        .toolbarBackground(AppStyle.Colors.bgDark, for: .tabBar)
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
                AppConstants.Log.app.debug("⚠️ App-wide memory warning - clearing image cache")
                PhotoStore.clearCache()
            }
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            // Manage camera lifecycle based on tab selection
            if newTab == 1 {
                // Switching TO camera tab
                // Cancel any pending stop task
                cameraStopTask?.cancel()
                cameraStopTask = nil

                // Start camera if not running
                if cameraService.isAuthorized && !cameraService.session.isRunning {
                    AppConstants.Log.app.debug("▶️ Switching to camera tab - starting camera")
                    cameraService.start()
                }
            } else if oldTab == 1 {
                // Switching AWAY FROM camera tab
                // Schedule camera stop after 5 seconds (balance between UX and battery)
                // Short delay makes returns feel instant, but stops soon enough to save battery
                AppConstants.Log.app.debug("⏸️ Switching away from camera tab - scheduling stop in 5 seconds")
                cameraStopTask?.cancel()
                cameraStopTask = Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

                    // Check if task was cancelled (user returned to camera tab)
                    guard !Task.isCancelled else {
                        AppConstants.Log.app.debug("✅ Camera stop cancelled - user returned to camera tab")
                        return
                    }

                    await MainActor.run {
                        AppConstants.Log.app.debug("⏸️ Stopping camera after 5-second delay")
                        cameraService.stop()
                    }
                }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Always stop camera when app goes to background
            if newPhase == .background {
                AppConstants.Log.app.debug("📱 App entering background - stopping camera immediately")
                cameraStopTask?.cancel()
                cameraService.stop()
            } else if newPhase == .active && selectedTab == 1 {
                // Restart camera if we're on camera tab and app becomes active
                if cameraService.isAuthorized && !cameraService.session.isRunning {
                    AppConstants.Log.app.debug("📱 App becoming active on camera tab - starting camera")
                    cameraService.start()
                }
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
                AppConstants.Log.app.debug("🔧 Fixed \(fixedCount) orphaned photos")
            } else {
                AppConstants.Log.app.debug("✅ No orphaned photos found")
            }
        } catch {
            print("⚠️ Failed to fix orphaned photos: \(error)")
        }
    }
}

#Preview { ContentView() }