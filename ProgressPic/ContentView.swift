import SwiftUI

struct ContentView: View {
    @StateObject private var themeManager = ThemeManager()
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            // Full screen dark background
            Color(red: 30/255, green: 32/255, blue: 35/255)
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                JourneysView()
                    .tag(0)
                ActivityView()
                    .tag(1)
                CameraHostView()
                    .tag(2)
                CompareView()
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                Spacer()
                CustomTabBar(selectedTab: $selectedTab)
                    .padding(.bottom, 8)
            }
        }
        .environmentObject(themeManager)
    }
}

#Preview { ContentView() }