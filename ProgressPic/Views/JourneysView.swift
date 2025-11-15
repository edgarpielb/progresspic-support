import SwiftUI
import SwiftData
import PhotosUI
import Photos
import AVFoundation

// Note: The following components have been extracted to separate files for better compilation:
// - JourneyCoverThumb, CoverThumb, PhotoGridItem -> JourneyPhotoComponents.swift
// - ImportPhotosView, ImagePicker, SelectedPhotoData -> PhotoImportUtilities.swift
// - ShareSheet, URL extension -> ShareUtilities.swift

private let accent = Color(red: 0.24, green: 0.85, blue: 0.80)

struct JourneysView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Journey.sortOrder, order: .forward) private var journeys: [Journey]
    @State private var showNew = false
    @State private var editMode: EditMode = .inactive
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                // Existing journeys
                ForEach(journeys) { j in
                    Button(action: {
                        if editMode == .inactive {
                            navigationPath.append(j)
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 12) {
                            // Photo collage
                            JourneyPhotoCollage(journey: j)

                            // Journey info with navigation arrow
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(j.name)
                                        .font(.title3.bold())
                                        .foregroundColor(.white)

                                    HStack(spacing: 12) {
                                        Text("\(j.photoCount) photos")
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.7))
                                        Text("•")
                                            .foregroundStyle(.white.opacity(0.4))
                                        Text("Started \(j.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                }
                                Spacer()
                                if editMode == .inactive {
                                    Image(systemName: "chevron.right")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
                .onMove { from, to in
                    // Manual reorder: adjust sortOrder for all journeys
                    var mutableJourneys = journeys
                    mutableJourneys.move(fromOffsets: from, toOffset: to)
                    for (index, journey) in mutableJourneys.enumerated() {
                        journey.sortOrder = index
                    }
                    do {
                        try ctx.save()
                    } catch {
                        print("❌ Failed to save reordered journeys: \(error)")
                    }
                }
                .onDelete { offsets in
                    for i in offsets {
                        ctx.delete(journeys[i])
                    }
                    do {
                        try ctx.save()
                    } catch {
                        print("❌ Error deleting journey: \(error)")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppStyle.Colors.bgDark)
            .listStyle(.plain)
            .navigationTitle("My Journeys")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showNew = true }) {
                        Label("New Journey", systemImage: "plus")
                            .foregroundColor(.white)
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .navigationDestination(for: Journey.self) { journey in
                JourneyDetailView(journey: journey)
            }
        }
        .sheet(isPresented: $showNew) {
            NewJourneySheet()
        }
        .onAppear {
            initializeSortOrder()
        }
    }

    /// Initialize sortOrder for existing journeys that don't have one
    private func initializeSortOrder() {
        var needsUpdate = false
        for (index, journey) in journeys.enumerated() {
            if journey.sortOrder == 0 && index != 0 {
                journey.sortOrder = index
                needsUpdate = true
            }
        }

        if needsUpdate {
            do {
                try ctx.save()
                print("✅ Initialized sortOrder for existing journeys")
            } catch {
                print("❌ Error initializing sortOrder: \(error)")
            }
        }
    }
}
