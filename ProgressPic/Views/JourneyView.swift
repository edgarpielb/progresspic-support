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

                                    let count = j.photos?.count ?? 0
                                    HStack(spacing: 12) {
                                        Text("\(count) photos")
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

                                // Navigation arrow aligned with text
                                if editMode == .inactive {
                                    Image(systemName: "chevron.right")
                                        .font(.body.weight(.semibold))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .opacity(editMode == .active ? 0.7 : 1.0)
                    .onLongPressGesture(minimumDuration: 0.5) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            editMode = .active
                        }
                        // Haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                }
                .onMove { fromOffsets, toOffset in
                    moveJourneys(from: fromOffsets, to: toOffset)
                }

                // Add journey card - only show when no journeys exist
                if journeys.isEmpty {
                    Button {
                        showNew = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 26, weight: .bold))
                            Text("Add Journey").font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 90)
                        .glassCard(corner: 24)
                        .contentShape(RoundedRectangle(cornerRadius: 24))
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppStyle.Colors.bgDark)
            .navigationTitle("Journeys")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Journeys")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .topBarLeading) {
                    if editMode == .active {
                        Button("Done") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                editMode = .inactive
                            }
                        }
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if editMode == .inactive {
                        Button(action: {
                            showNew = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .environment(\.editMode, $editMode)
            .navigationDestination(for: Journey.self) { journey in
                JourneyDetailView(journey: journey)
            }
        }
        .sheet(isPresented: $showNew) { NewJourneySheet() }
        .task {
            // Initialize sortOrder for existing journeys that don't have it set
            await initializeSortOrder()
        }
    }

    private func moveJourneys(from source: IndexSet, to destination: Int) {
        var reorderedJourneys = journeys
        reorderedJourneys.move(fromOffsets: source, toOffset: destination)

        // Update sortOrder for all journeys
        for (index, journey) in reorderedJourneys.enumerated() {
            journey.sortOrder = index
        }

        do {
            try ctx.save()
        } catch {
            print("❌ Error saving reorder: \(error)")
        }
    }

    private func initializeSortOrder() async {
        var needsSave = false

        for (index, journey) in journeys.enumerated() {
            if journey.sortOrder == 0 && index != 0 {
                journey.sortOrder = index
                needsSave = true
            }
        }

        if needsSave {
            do {
                try ctx.save()
                print("✅ Initialized sortOrder for existing journeys")
            } catch {
                print("❌ Error initializing sortOrder: \(error)")
            }
        }
    }
}

// MARK: - Journey Detail View
// Note: JourneyCoverThumb and CoverThumb moved to JourneyPhotoComponents.swift
struct JourneyDetailView: View {
    let journey: Journey
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var photos: [ProgressPhoto] = []
    @State private var isLoadingPhotos = false
    @State private var currentPage = 0
    @State private var hasMorePhotos = true
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isImportingPhotos = false
    @State private var selectedPhotoForEdit: ProgressPhoto?
    @State private var showJourneySettings = false
    @State private var showCompareView = false
    @State private var showWatchView = false

    init(journey: Journey) {
        self.journey = journey
    }
    
    var body: some View {
        ZStack {
            Color(red: 30/255, green: 32/255, blue: 35/255).ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 16) {
                    // Journey stats with loading state
                    HStack {
                        VStack(alignment: .leading) {
                            if isLoadingPhotos && photos.isEmpty {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else {
                                Text("\(photos.count)")
                                    .font(.title.bold())
                                    .foregroundColor(.white)
                            }
                            Text("Photos")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text(journey.createdAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            Text("Started")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding()
                    .glassCard()
                    .padding(.horizontal)
                    
                    // Compare and Watch Buttons
                    HStack(spacing: 16) {
                        // Compare Button
                        Button(action: {
                            showCompareView = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "square.split.2x1")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Compare")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Side by side photos")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding()
                            .frame(height: 80)
                            .glassCard()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        // Watch Button
                        Button(action: {
                            showWatchView = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "play.rectangle")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Watch")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Timeline playback")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding()
                            .frame(height: 80)
                            .glassCard()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    
                    // Import Photos Button
                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: 20,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.badge.plus")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Import Old Photos")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Add existing photos from your library")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            if isImportingPhotos {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding()
                        .glassCard()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .disabled(isImportingPhotos)
                    
                    // Photo grid with loading states
                    Group {
                        if photos.isEmpty && isLoadingPhotos {
                            // Initial loading state
                            VStack(spacing: 16) {
                                Spacer()
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.2)
                                Text("Loading photos...")
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                            }
                        } else if photos.isEmpty {
                            // Empty state
                            VStack(spacing: 16) {
                                Spacer()
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 64))
                                    .foregroundColor(.white.opacity(0.3))
                                Text("No photos yet")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("Take your first photo to start your journey!")
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.5))
                                    .multilineTextAlignment(.center)
                                Spacer()
                            }
                            .padding(.horizontal, 40)
                        } else {
                            // Photo grid with infinite scroll
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                                    Button(action: {
                                        selectedPhotoForEdit = photo
                                    }) {
                                        PhotoGridItem(photo: photo)
                                            .onAppear {
                                                // Load more when reaching near the end
                                                if index == photos.count - 3 && hasMorePhotos && !isLoadingPhotos {
                                                    Task {
                                                        await loadPhotos()
                                                    }
                                                }
                                            }
                                    }
                                    .buttonStyle(.plain)
                                }

                                // Loading indicator for infinite scroll
                                if isLoadingPhotos && hasMorePhotos {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.8)
                                        Spacer()
                                    }
                                    .padding(.vertical, 16)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 120)
                }
                .padding(.top)
            }
        }
        .navigationTitle(journey.name)
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await loadPhotos()
        }
        .onChange(of: journey.id) { _, _ in
            // Reload photos when journey changes
            currentPage = 0
            photos = []
            hasMorePhotos = true
            Task {
                await loadPhotos()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showJourneySettings = true
                }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.white)
                }
            }
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await importSelectedPhotos(newItems)
            }
        }
        .sheet(item: $selectedPhotoForEdit) { photo in
            PhotoEditSheet(photo: photo, allPhotos: photos) { deletedPhoto in
                // Remove the deleted photo from the local array to update UI immediately
                photos.removeAll { $0.id == deletedPhoto.id }
            }
            .onDisappear {
                // Refresh the photo when edit sheet is dismissed
                if let editedPhoto = selectedPhotoForEdit {
                    Task {
                        // Fetch the updated photo from the context
                        let journeyId = journey.id
                        let photoId = editedPhoto.id
                        let predicate = #Predicate<ProgressPhoto> { photo in
                            photo.journeyId == journeyId && photo.id == photoId
                        }
                        let descriptor = FetchDescriptor(predicate: predicate)
                        
                        if let updatedPhoto = try? ctx.fetch(descriptor).first,
                           let index = photos.firstIndex(where: { $0.id == editedPhoto.id }) {
                            // Update the photo in the array to trigger view refresh
                            photos[index] = updatedPhoto
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showJourneySettings) {
            JourneySettingsView(journey: journey, onJourneyDeleted: { journeyWasDeleted in
                if journeyWasDeleted {
                    // Journey was deleted, dismiss this detail view
                    dismiss()
                }
            })
        }
        .sheet(isPresented: $showCompareView) {
            JourneyCompareSheet(journey: journey, photos: photos)
        }
        .sheet(isPresented: $showWatchView) {
            JourneyWatchSheet(journey: journey, photos: photos)
        }
    }
    
    private func importSelectedPhotos(_ items: [PhotosPickerItem]) async {
        await MainActor.run {
            isImportingPhotos = true
        }
        
        var successCount = 0
        var errorCount = 0
        
        for (index, item) in items.enumerated() {
            do {
                // Load image data from PhotosPickerItem
                guard let imageData = try await item.loadTransferable(type: Data.self) else {
                    errorCount += 1
                    print("❌ Failed to load image data for item \(index + 1)")
                    continue
                }

                // Get creation date from EXIF metadata if available
                var creationDate = Date()

                // First try: Extract EXIF date directly from image data
                if let exifDate = PhotoStore.extractEXIFDate(from: imageData) {
                    creationDate = exifDate
                    print("✅ Extracted EXIF date from image data: \(exifDate.formatted())")
                }
                // Second try: Use PHAsset for EXIF extraction if identifier available
                else if let assetIdentifier = item.itemIdentifier {
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
                    if let asset = fetchResult.firstObject {
                        // Use our EXIF extraction method instead of asset.creationDate
                        if let exifDate = await PhotoStore.getEXIFCreationDate(from: asset) {
                            creationDate = exifDate
                            print("✅ Extracted EXIF date from PHAsset: \(exifDate.formatted())")
                        } else {
                            print("⚠️ Could not extract EXIF date for photo \(index + 1), using current date")
                        }
                    } else {
                        print("⚠️ Could not fetch PHAsset for photo \(index + 1), using current date")
                    }
                } else {
                    print("⚠️ No asset identifier for photo \(index + 1) and no EXIF data, using current date")
                }

                // Downscale large images to reduce memory usage (max 3000px on longest side)
                guard let uiImage = downsampleImage(from: imageData, maxDimension: 3000) else {
                    errorCount += 1
                    print("❌ Failed to create image from data for item \(index + 1)")
                    continue
                }

                // Save original image to app directory
                let originalId = try await PhotoStore.saveToAppDirectory(uiImage)
                print("💾 Saved original image \(index + 1)/\(items.count)")

                // Calculate initial transform to fill 4:5 aspect ratio
                let imageAspect = uiImage.size.width / uiImage.size.height
                let targetAspect: CGFloat = 4.0 / 5.0  // 4:5 crop ratio
                
                let fillScale: CGFloat
                if imageAspect > targetAspect {
                    fillScale = imageAspect / targetAspect
                } else {
                    fillScale = targetAspect / imageAspect
                }
                
                let initialTransform = AlignTransform(
                    scale: fillScale,
                    offsetX: 0,
                    offsetY: 0,
                    rotation: 0
                )

                // Create progress photo entry with original ID and initial transform
                await MainActor.run {
                    let progressPhoto = ProgressPhoto(
                        journeyId: journey.id,
                        date: creationDate,
                        assetLocalId: originalId,  // Use original ID directly
                        isFrontCamera: false,
                        alignTransform: initialTransform,
                        originalAssetLocalId: nil  // No separate original needed
                    )
                    progressPhoto.journey = journey
                    ctx.insert(progressPhoto)

                    // Save context periodically
                    if index % 5 == 0 {
                        do {
                            try ctx.save()
                        } catch {
                            print("❌ Error saving context: \(error)")
                        }
                    }
                }

                successCount += 1
                print("✅ Successfully imported photo \(index + 1)/\(items.count)")

            } catch {
                errorCount += 1
                print("❌ Error importing photo \(index + 1): \(error)")
            }
        }
        
        // Final save
        await MainActor.run {
            do {
                try ctx.save()
                print("📸 Import complete: \(successCount) success, \(errorCount) errors")

                // Process pending changes to ensure photos are properly registered
                ctx.processPendingChanges()

                // Reset pagination and reload photos to show new imports immediately
                currentPage = 0
                photos = []
                hasMorePhotos = true
            } catch {
                print("❌ Error saving final context: \(error)")
            }

            isImportingPhotos = false
            selectedPhotoItems = [] // Clear selection
        }

        // Reload photos after import to immediately show them in the UI
        await loadPhotos()
    }

    private func downsampleImage(from imageData: Data, maxDimension: CGFloat) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, imageSourceOptions) else {
            print("⚠️ Failed to create image source")
            return nil
        }

        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ] as CFDictionary

        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            print("⚠️ Failed to downsample image, falling back to standard loading")
            return UIImage(data: imageData)
        }

        return UIImage(cgImage: downsampledImage)
    }

    private func loadPhotos() async {
        guard !isLoadingPhotos && hasMorePhotos else { return }

        await MainActor.run {
            isLoadingPhotos = true
        }

        do {
            let journeyId = journey.id
            let predicate = #Predicate<ProgressPhoto> { $0.journeyId == journeyId }
            let sortDescriptors = [SortDescriptor(\ProgressPhoto.date, order: .reverse)]

            let result = try await ctx.fetchPaginated(
                ProgressPhoto.self,
                predicate: predicate,
                sortBy: sortDescriptors,
                pageSize: 20, // Load 20 photos per page
                page: currentPage
            )

            // Append new photos to existing array on main thread
            await MainActor.run {
                photos.append(contentsOf: result.items)
                hasMorePhotos = result.hasMore
                currentPage += 1
                isLoadingPhotos = false
            }

        } catch {
            print("❌ Error loading photos: \(error)")
            await MainActor.run {
                isLoadingPhotos = false
            }
        }
    }
}

// Note: PhotoGridItem moved to JourneyPhotoComponents.swift
// Note: ImportPhotosView, SelectedPhotoData, ImagePicker moved to PhotoImportUtilities.swift

// MARK: - Extracted Components
// Note: The following large components have been moved to separate files:
// - PhotoEditSheet, PhotoAdjustSheet -> PhotoEditViews.swift (892 lines)
// - JourneyCompareSheet, JourneyCompareView, ImprovedCompareCanvas -> JourneyComparisonViews.swift (565 lines)
// - JourneyWatchSheet, JourneyWatchView -> JourneyWatchViews.swift (533 lines)
// - ShareSheet, URL extension -> ShareUtilities.swift (21 lines)
// Total: ~2,000 lines extracted for better compilation performance
