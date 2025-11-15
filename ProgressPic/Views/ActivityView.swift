import SwiftUI
import SwiftData

// Note: The following components have been extracted to separate files for better compilation:
// - CombinedWeekAndStreakView, EnhancedDayBubble -> ActivityWeekStreakView.swift
// - AllMeasurementStatsSection, SectionHeader, MeasurementRow -> ActivityMeasurementsSection.swift
// - BodyCompositionSection, MetricRow -> ActivityBodyCompositionSection.swift

struct ActivityView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Journey.createdAt, order: .reverse) private var journeys: [Journey]
    @State private var showProfileSetup = false
    @State private var showProfileDetail = false
    @State private var showYearCalendar = false
    @State private var userProfile = UserProfile.load()
    @StateObject private var healthKit = HealthKitService.shared
    @State private var isLoadingHealthData = false
    @State private var showExportSheet = false
    @State private var exportFileURL: URL?
    
    private var isProfileComplete: Bool {
        userProfile.birthDate != nil && userProfile.heightCm != nil
    }

    var body: some View {
        NavigationStack {
        ZStack {
            AppStyle.Colors.bgDark.ignoresSafeArea()

                // Content state with ScrollView
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                    // Universal Week Ring with Streaks (combines all journeys)
                    Button(action: {
                        showYearCalendar = true
                    }) {
                        CombinedWeekAndStreakView(journeys: journeys)
                            .padding(12)
                            .glassCard()
                    }
                    .buttonStyle(.plain)

                    BodyCompositionSection(healthKit: healthKit, isLoading: isLoadingHealthData)
                                .padding(12)
                                .glassCard()

                    // Show measurement stats from first journey (or could combine all)
                    if let firstJourney = journeys.first {
                        AllMeasurementStatsSection(journey: firstJourney)
                            .padding(12)
                            .glassCard()
                        }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
                .padding(.top, 4)
            }
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Activity")
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Export button
                    Button(action: {
                        exportAllMeasurements()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    
                    // Profile button
                    Button(action: {
                        if isProfileComplete {
                            showProfileDetail = true
                        } else {
                            showProfileSetup = true
                        }
                    }) {
                        Image(systemName: "person.circle.fill")
                            .font(.title3)
                            .foregroundColor(AppStyle.Colors.accentPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $showProfileSetup) {
            UserProfileSetupView { profile in
                userProfile = profile
            }
        }
        .sheet(isPresented: $showProfileDetail) {
            UserProfileDetailView()
                .onDisappear {
                    // Reload profile when detail view is dismissed
                    userProfile = UserProfile.load()
                }
        }
        .sheet(isPresented: $showYearCalendar) {
            YearCalendarSheet(journeys: journeys)
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = exportFileURL {
                ShareSheet(url: url)
            }
        }
        .onAppear {
            // Show profile setup if not completed (only on first launch)
            if !isProfileComplete {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showProfileSetup = true
                }
            }

            // Check if we should request a review based on current streak - run on background thread
            Task {
                let allPhotos = (try? ctx.fetch(FetchDescriptor<ProgressPhoto>(sortBy: [SortDescriptor(\.date, order: .forward)]))) ?? []
                let allMeasurements = (try? ctx.fetch(FetchDescriptor<MeasurementEntry>(sortBy: [SortDescriptor(\.date, order: .forward)]))) ?? []
                let currentStreak = calculateCurrentStreak(photos: allPhotos, measurements: allMeasurements)
                await MainActor.run {
                    ReviewRequestManager.checkAndRequestReview(currentStreak: currentStreak)
                }
            }
        }
            .task {
                // Only fetch data if already authorized
                if healthKit.isAuthorized {
                    isLoadingHealthData = true
                    await healthKit.fetchBodyComposition()
                    isLoadingHealthData = false
                }
            }
        }
    }
    
    private func calculateCurrentStreak(photos: [ProgressPhoto], measurements: [MeasurementEntry]) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        
        // Combine photo and measurement days (excluding future dates)
        var allActivityDays = Set<Date>()
        for photo in photos {
            let dayStart = cal.startOfDay(for: photo.date)
            if dayStart <= today {
                allActivityDays.insert(dayStart)
            }
        }
        for measurement in measurements {
            let dayStart = cal.startOfDay(for: measurement.date)
            if dayStart <= today {
                allActivityDays.insert(dayStart)
            }
        }
        
        guard !allActivityDays.isEmpty else { return 0 }

        let days = Array(allActivityDays).sorted()
        guard let lastActivityDay = days.last else { return 0 }

        // Check if last activity was today or yesterday
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: today) else { return 0 }
        
        guard cal.isDate(lastActivityDay, inSameDayAs: today) || cal.isDate(lastActivityDay, inSameDayAs: yesterday) else {
            return 0
        }
        
        // Count backwards from last activity day
        var currentStreak = 1
        var checkDate = lastActivityDay
        
        for day in days.reversed().dropFirst() {
            if let prevDay = cal.date(byAdding: .day, value: -1, to: checkDate),
               cal.isDate(day, inSameDayAs: prevDay) {
                currentStreak += 1
                checkDate = day
            } else {
                break
            }
        }
        
        return currentStreak
    }
    
    private func exportAllMeasurements() {
        // Haptic feedback
        HapticFeedback.medium()

        // Fetch all measurement entries
        do {
            let allMeasurements = try ctx.fetch(FetchDescriptor<MeasurementEntry>(sortBy: [SortDescriptor(\.date, order: .forward)]))
            
            guard !allMeasurements.isEmpty else {
                AppConstants.Log.data.warning("No measurements to export")
                return
            }
            
            // Get the first journey for context (or could combine all)
            let journey = journeys.first
            
            // Export using the by-type format for better organization
            guard let csvData = ExportService.exportMeasurementsByTypeToCSV(entries: allMeasurements, journey: journey ?? Journey(name: "All Journeys")) else {
                AppConstants.Log.data.error("Failed to export measurements to CSV")
                return
            }
            
            // Create temporary file
            let filename = ExportService.generateCSVFilename(journey: journey, type: "all_measurements")
            
            let fileURL = try ExportService.createTemporaryFile(data: csvData, filename: filename)
            exportFileURL = fileURL
            showExportSheet = true
            AppConstants.Log.data.info("CSV export successful: \(filename)")
        } catch {
            AppConstants.Log.data.error("Failed to export measurements: \(error.localizedDescription)")
        }
    }
}
