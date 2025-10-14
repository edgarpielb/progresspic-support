import SwiftUI
import SwiftData
import PhotosUI
import Photos
import AVFoundation

private let accent = Color(red: 0.24, green: 0.85, blue: 0.80)

struct JourneysView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Journey.createdAt, order: .reverse) private var journeys: [Journey]
    @State private var showNew = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {

                    // Existing journeys
                    ForEach(journeys) { j in
                        NavigationLink {
                            JourneyDetailView(journey: j)
                        } label: {
                            HStack(spacing: 16) {
                                JourneyCoverThumb(journey: j)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(j.name).font(.title3.bold()).foregroundColor(.white)
                                    let count = j.photos?.count ?? 0
                                    Text("\(count) photos · Started \(j.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                Spacer()
                            }
                            .padding(16)
                            .glassCard(corner: 20)
                            .contentShape(RoundedRectangle(cornerRadius: 20))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
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
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 16)
                .padding(.bottom, 120) // space for tab bar
            }
            .background(AppStyle.Colors.bgDark)
            .navigationTitle("Journeys")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Journeys")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showNew = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(isPresented: $showNew) { NewJourneySheet() }
    }
}

// MARK: - Subviews

struct JourneyCoverThumb: View {
    let journey: Journey
    @State private var img: UIImage?
    @Query private var photos: [ProgressPhoto]
    
    init(journey: Journey) {
        self.journey = journey
        let journeyId = journey.id
        _photos = Query(
            filter: #Predicate<ProgressPhoto> { $0.journeyId == journeyId },
            sort: \ProgressPhoto.date,
            order: .reverse
        )
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06))
            if let ui = img {
                Image(uiImage: ui).resizable().scaledToFill().clipped()
            } else {
                Image(systemName: "camera").font(.title2).foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12)))
        .task {
            // Load the most recent photo
            if let latestPhoto = photos.first {
                img = await PhotoStore.fetchUIImage(localId: latestPhoto.assetLocalId, targetSize: CGSize(width: 160, height: 160))
            }
        }
        .onChange(of: photos.count) { _, _ in
            // Reload when photos change
            Task {
                if let latestPhoto = photos.first {
                    img = await PhotoStore.fetchUIImage(localId: latestPhoto.assetLocalId, targetSize: CGSize(width: 160, height: 160))
                } else {
                    img = nil
                }
            }
        }
    }
}

struct CoverThumb: View {
    @State private var img: UIImage?
    var localId: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06))
            if let ui = img {
                Image(uiImage: ui).resizable().scaledToFill().clipped()
            } else {
                Image(systemName: "camera").font(.title2).foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12)))
        .task {
            if let id = localId {
                img = await PhotoStore.fetchUIImage(localId: id, targetSize: CGSize(width: 160, height: 160))
            }
        }
    }
}


// MARK: - Journey Detail View
struct JourneyDetailView: View {
    let journey: Journey
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query private var photos: [ProgressPhoto]
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isImportingPhotos = false
    @State private var selectedPhotoForEdit: ProgressPhoto?
    @State private var showJourneySettings = false
    @State private var showCompareView = false
    @State private var showWatchView = false
    
    init(journey: Journey) {
        self.journey = journey
        let journeyId = journey.id
        _photos = Query(filter: #Predicate<ProgressPhoto> { $0.journeyId == journeyId },
                       sort: \ProgressPhoto.date, order: .reverse)
    }
    
    var body: some View {
        ZStack {
            Color(red: 30/255, green: 32/255, blue: 35/255).ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Journey stats
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(photos.count)")
                                .font(.title.bold())
                                .foregroundColor(.white)
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
                        matching: .images
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
                    
                    // Photo grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(photos) { photo in
                            Button(action: {
                                selectedPhotoForEdit = photo
                            }) {
                                PhotoGridItem(photo: photo)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
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
            PhotoEditSheet(photo: photo, allPhotos: photos)
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
                guard let imageData = try await item.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: imageData) else {
                    errorCount += 1
                    print("❌ Failed to load image data for item \(index + 1)")
                    continue
                }
                
                // Get creation date from metadata if available
                var creationDate = Date()
                if let assetIdentifier = item.itemIdentifier {
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
                    if let asset = fetchResult.firstObject {
                        creationDate = asset.creationDate ?? Date()
                    }
                }
                
                // Save to app directory
                let localId = try await PhotoStore.saveToAppDirectory(uiImage)
                print("💾 Copied imported photo \(index + 1)/\(items.count) to app directory")
                
                // Create progress photo entry
                await MainActor.run {
                    let progressPhoto = ProgressPhoto(
                        journeyId: journey.id,
                        date: creationDate,
                        assetLocalId: localId,
                        isFrontCamera: false,
                        alignTransform: .identity
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
            } catch {
                print("❌ Error saving final context: \(error)")
            }
            
            isImportingPhotos = false
            selectedPhotoItems = [] // Clear selection
        }
    }
}

struct PhotoGridItem: View {
    let photo: ProgressPhoto
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var loadTask: Task<Void, Never>?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                
                if let img = image {
                    // Apply transform to show cropped version
                    let transform = photo.alignTransform
                    let itemHeight = geometry.size.width * 5.0/4.0 // 4:5 ratio height
                    if transform.scale != 1 || transform.offsetX != 0 || transform.offsetY != 0 || transform.rotation != 0 {
                        // Show transformed (cropped) version - render it properly for thumbnail
                        let transformedImage = renderTransformedThumbnail(image: img, transform: transform, size: geometry.size.width)
                        Image(uiImage: transformedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: itemHeight)
                            .clipped()
                            .transition(.opacity.animation(.easeIn(duration: 0.2)))
                    } else {
                        // Show original (no transform applied)
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: itemHeight)
                            .clipped()
                            .transition(.opacity.animation(.easeIn(duration: 0.2)))
                    }
                } else if loadFailed {
                    Button(action: {
                        Task { await loadImage() }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.cyan)
                                .font(.title2)
                            Text("Tap to retry")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .buttonStyle(.plain)
                } else if isLoading {
                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
        }
        .aspectRatio(4.0/5.0, contentMode: .fit) // 4:5 ratio to match edit view crop
        .task(id: photo.id) {
            await loadImage()
        }
        .onDisappear {
            // Cancel load task if view disappears before loading completes
            loadTask?.cancel()
        }
    }
    
    private func loadImage() async {
        // Cancel any previous load task
        loadTask?.cancel()
        
        loadTask = Task {
            isLoading = true
            loadFailed = false
            
            // Use a reasonable thumbnail size for grid display
            let targetSize = CGSize(width: 300, height: 300)
            
            guard !Task.isCancelled else { return }
            
            if let loadedImage = await PhotoStore.fetchUIImage(localId: photo.assetLocalId, targetSize: targetSize) {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.image = loadedImage
                    self.isLoading = false
                }
            } else {
                // If load failed, mark as failed for retry
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.loadFailed = true
                    self.isLoading = false
                }
            }
        }
    }
    
    private func renderTransformedThumbnail(image: UIImage, transform: AlignTransform, size: CGFloat) -> UIImage {
        // Render the final 4:5 cropped thumbnail with transform applied
        // Use consistent logic with PhotoEditSheet
        let targetWidth = size * UIScreen.main.scale * 2 // 2x for retina quality
        let targetHeight = targetWidth * 5.0 / 4.0 // 4:5 ratio
        let targetSize = CGSize(width: targetWidth, height: targetHeight)
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { ctx in
            // Fill background
            ctx.cgContext.setFillColor(UIColor(red: 30/255, green: 32/255, blue: 35/255, alpha: 1.0).cgColor)
            ctx.cgContext.fill(CGRect(origin: .zero, size: targetSize))
            
            // Move to center of crop area
            ctx.cgContext.translateBy(x: targetSize.width / 2, y: targetSize.height / 2)
            
            // Apply user's transform
            ctx.cgContext.rotate(by: CGFloat(transform.rotation))
            ctx.cgContext.scaleBy(x: transform.scale, y: transform.scale)
            ctx.cgContext.translateBy(x: transform.offsetX, y: transform.offsetY)
            
            // Calculate how the image fits (scaledToFit logic)
            let imageAspect = image.size.width / image.size.height
            let cropAspect = targetSize.width / targetSize.height
            
            var drawSize: CGSize
            if imageAspect > cropAspect {
                // Image is wider - fit by width
                drawSize = CGSize(width: targetSize.width, height: targetSize.width / imageAspect)
            } else {
                // Image is taller - fit by height
                drawSize = CGSize(width: targetSize.height * imageAspect, height: targetSize.height)
            }
            
            // Draw centered
            let drawRect = CGRect(
                x: -drawSize.width / 2,
                y: -drawSize.height / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            
            image.draw(in: drawRect)
        }
    }
}

// MARK: - Import Photos View
struct ImportPhotosView: View {
    let journey: Journey
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @State private var selectedImages: [UIImage] = []
    @State private var selectedPhotoData: [SelectedPhotoData] = []
    @State private var showImagePicker = false
    @State private var isImporting = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 30/255, green: 32/255, blue: 35/255).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    if selectedImages.isEmpty {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("Import Old Photos")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            
                            Text("Add existing photos from your photo library to this journey. These photos will be added with their original creation dates and won't create duplicates in your library.")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            
                            Button("Select Photos") {
                                showImagePicker = true
                            }
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.cyan)
                            .cornerRadius(12)
                        }
                    } else {
                        // Selected photos preview
                        ScrollView {
                            VStack(spacing: 16) {
                                Text("Selected Photos (\(selectedImages.count))")
                                    .font(.title3.bold())
                                    .foregroundColor(.white)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(height: 100)
                                                .clipped()
                                                .cornerRadius(8)
                                            
                                            Button(action: {
                                                selectedImages.remove(at: index)
                                                if index < selectedPhotoData.count {
                                                    selectedPhotoData.remove(at: index)
                                                }
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.title3)
                                                    .foregroundColor(.red)
                                                    .background(Color.white, in: Circle())
                                            }
                                            .padding(4)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                
                                HStack(spacing: 16) {
                                    Button("Add More") {
                                        showImagePicker = true
                                    }
                                    .foregroundColor(.cyan)
                                    .font(.headline)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(10)
                                    
                                    Button("Import All") {
                                        importPhotos()
                                    }
                                    .foregroundColor(.white)
                                    .font(.headline)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.cyan)
                                    .cornerRadius(10)
                                    .disabled(isImporting)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                
                if isImporting {
                    ZStack {
                        Color(red: 30/255, green: 32/255, blue: 35/255).opacity(0.8).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(.white)
                            Text("Importing Photos...")
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(
                            ZStack {
                                Color(red: 30/255, green: 32/255, blue: 35/255).opacity(0.9)
                                Rectangle()
                                    .fill(.ultraThinMaterial)
                            }
                        )
                        .cornerRadius(12)
                    }
                }
            }
            .navigationTitle("Import Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.cyan)
                            .font(.body.weight(.semibold))
                    }
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImages: $selectedImages, selectedPhotoData: $selectedPhotoData)
        }
    }
    
    private func importPhotos() {
        isImporting = true
        
        Task {
            var successCount = 0
            var errorCount = 0
            
            for (index, photoData) in selectedPhotoData.enumerated() {
                do {
                    let localId: String
                    let date: Date
                    
                    // For imported photos, copy them to app directory to avoid photo library dependency
                    localId = try await PhotoStore.saveToAppDirectory(photoData.image)
                    date = photoData.creationDate ?? Date()
                    print("💾 Copied imported photo \(index + 1)/\(selectedPhotoData.count) to app directory")
                    
                    // Create progress photo entry
                    let progressPhoto = ProgressPhoto(
                        journeyId: journey.id,
                        date: date,
                        assetLocalId: localId,
                        isFrontCamera: false, // Assume imported photos are not selfies
                        alignTransform: .identity
                    )
                    progressPhoto.journey = journey  // Set the relationship
                    
                    await MainActor.run {
                        ctx.insert(progressPhoto)
                        
                        // Save context periodically to prevent memory issues
                        if index % 5 == 0 {
                            do {
                                try ctx.save()
                            } catch {
                                print("Error saving context: \(error)")
                            }
                        }
                    }
                    
                    successCount += 1
                    print("✅ Successfully imported photo \(index + 1)/\(selectedPhotoData.count)")
                    
                } catch {
                    errorCount += 1
                    print("❌ Error importing photo \(index + 1): \(error)")
                }
            }
            
            await MainActor.run {
                // Final save
                do {
                    try ctx.save()
                    print("📸 Import complete: \(successCount) success, \(errorCount) errors")
                } catch {
                    print("❌ Error saving final context: \(error)")
                }
                
                isImporting = false
                dismiss()
            }
        }
    }
}

// MARK: - Selected Photo Data
struct SelectedPhotoData {
    let image: UIImage
    let assetIdentifier: String?
    let creationDate: Date?
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    @Binding var selectedPhotoData: [SelectedPhotoData]
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 0 // Allow multiple selection
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard !results.isEmpty else { return }
            
            var newImages: [UIImage] = []
            var newPhotoData: [SelectedPhotoData] = []
            let group = DispatchGroup()
            
            for result in results {
                group.enter()
                
                // Get asset identifier if available
                let assetIdentifier = result.assetIdentifier
                
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("Error loading image: \(error)")
                        return
                    }
                    
                    if let image = object as? UIImage {
                        newImages.append(image)
                        
                        // Get creation date from original asset if available
                        var creationDate: Date?
                        if let identifier = assetIdentifier {
                            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
                            creationDate = fetchResult.firstObject?.creationDate
                        }
                        
                        let photoData = SelectedPhotoData(
                            image: image,
                            assetIdentifier: assetIdentifier,
                            creationDate: creationDate
                        )
                        newPhotoData.append(photoData)
                    }
                }
            }
            
            group.notify(queue: .main) {
                self.parent.selectedImages.append(contentsOf: newImages)
                self.parent.selectedPhotoData.append(contentsOf: newPhotoData)
            }
        }
        
        // Add the missing delegate methods to prevent warnings
        func pickerDidPerformCancelAction(_ picker: PHPickerViewController) {
            parent.dismiss()
        }
        
        func pickerDidPerformConfirmationAction(_ picker: PHPickerViewController) {
            // This method is called when user confirms selection
            // No additional action needed as didFinishPicking handles the results
        }
    }
}

// MARK: - Photo Edit Sheet
// MARK: - Photo Edit Sheet (Read-only view with action bar)
struct PhotoEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    
    let photo: ProgressPhoto
    let allPhotos: [ProgressPhoto]  // For navigation
    
    @State private var currentPhoto: ProgressPhoto
    @State private var image: UIImage?
    @State private var showNotesEditor = false
    @State private var showDatePicker = false
    @State private var showAdjustView = false
    @State private var showDeleteConfirmation = false
    @State private var notesText: String = ""
    @State private var selectedDate: Date = Date()
    
    init(photo: ProgressPhoto, allPhotos: [ProgressPhoto] = []) {
        self.photo = photo
        self.allPhotos = allPhotos.isEmpty ? [photo] : allPhotos
        _currentPhoto = State(initialValue: photo)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppStyle.Colors.bgDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 4) {
                        Text(currentPhoto.journey?.name ?? "Photo")
                            .font(AppStyle.FontStyle.headline)
                            .foregroundColor(AppStyle.Colors.textPrimary)
                        
                        Text(currentPhoto.date.formatted(date: .abbreviated, time: .shortened))
                            .font(AppStyle.FontStyle.caption)
                            .foregroundColor(AppStyle.Colors.textSecondary)
                    }
                    .padding(.top, AppStyle.Spacing.md)
                    
                    // Main image with 4:5 aspect ratio (already cropped to 4:5)
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, AppStyle.Spacing.md)
                    } else {
                        ProgressView()
                            .tint(AppStyle.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(4/5, contentMode: .fit)
                    }
                    
                    Spacer(minLength: AppStyle.Spacing.lg)
                    
                    // Navigation controls (if multiple photos)
                    if allPhotos.count > 1 {
                        HStack(spacing: AppStyle.Spacing.xxxl) {
                            Button(action: previousPhoto) {
                                Image(systemName: "arrow.left")
                                    .font(.title2)
                                    .foregroundColor(canGoPrevious ? AppStyle.Colors.textPrimary : AppStyle.Colors.textTertiary)
                                    .frame(width: 60, height: 60)
                                    .background(AppStyle.Colors.panel)
                                    .clipShape(Circle())
                            }
                            .disabled(!canGoPrevious)
                            
                            Button(action: nextPhoto) {
                                Image(systemName: "arrow.right")
                                    .font(.title2)
                                    .foregroundColor(canGoNext ? AppStyle.Colors.textPrimary : AppStyle.Colors.textTertiary)
                                    .frame(width: 60, height: 60)
                                    .background(AppStyle.Colors.panel)
                                    .clipShape(Circle())
                            }
                            .disabled(!canGoNext)
                        }
                        .padding(.bottom, AppStyle.Spacing.md)
                        
                        // Dots indicator
                        HStack(spacing: 8) {
                            ForEach(0..<min(allPhotos.count, 10), id: \.self) { index in
                                Circle()
                                    .fill(currentPhotoIndex == index ? AppStyle.Colors.textPrimary : AppStyle.Colors.textTertiary)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.bottom, AppStyle.Spacing.lg)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppStyle.Colors.bgDark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(AppStyle.Colors.textPrimary)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if let img = image {
                        ShareLink(item: Image(uiImage: img), preview: SharePreview("Photo", image: Image(uiImage: img))) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                                .foregroundColor(AppStyle.Colors.textPrimary)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
            .task(id: currentPhoto.id) {
                await loadImage()
                notesText = currentPhoto.notes ?? ""
                selectedDate = currentPhoto.date
            }
            .onChange(of: showAdjustView) { _, isShowing in
                // Reload image when adjust sheet is dismissed to show updated transform
                if !isShowing {
                    Task {
                        await loadImage()
                    }
                }
            }
            .sheet(isPresented: $showNotesEditor) {
                notesEditorSheet
            }
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
            .sheet(isPresented: $showAdjustView) {
                PhotoAdjustSheet(photo: currentPhoto)
            }
            .alert("Delete Photo", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deletePhoto()
                }
            } message: {
                Text("Are you sure you want to delete this photo? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Action Bar
    private var actionBar: some View {
        HStack(spacing: 0) {
            // Notes
            Button(action: { showNotesEditor = true }) {
                VStack(spacing: 6) {
                    Image(systemName: currentPhoto.notes != nil ? "note.text.badge.plus" : "note.text")
                        .font(.system(size: AppStyle.IconSize.xl))
                    Text("Notes")
                        .font(AppStyle.FontStyle.caption)
                }
                .foregroundColor(currentPhoto.notes != nil ? AppStyle.Colors.accentCyan : AppStyle.Colors.textPrimary)
                .frame(maxWidth: .infinity)
            }
            .accessibilityLabel(currentPhoto.notes != nil ? "Edit notes" : "Add notes")
            .accessibilityHint("Add or edit notes for this photo")
            
            // Date
            Button(action: { showDatePicker = true }) {
                VStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: AppStyle.IconSize.xl))
                    Text("Date")
                        .font(AppStyle.FontStyle.caption)
                }
                .foregroundColor(AppStyle.Colors.textPrimary)
                .frame(maxWidth: .infinity)
            }
            .accessibilityLabel("Change date")
            .accessibilityHint("Taken on \(currentPhoto.date.formatted(date: .abbreviated, time: .shortened))")
            
            // Adjust
            Button(action: { showAdjustView = true }) {
                VStack(spacing: 6) {
                    Image(systemName: "crop.rotate")
                        .font(.system(size: AppStyle.IconSize.xl))
                    Text("Adjust")
                        .font(AppStyle.FontStyle.caption)
                }
                .foregroundColor(AppStyle.Colors.textPrimary)
                .frame(maxWidth: .infinity)
            }
            .accessibilityLabel("Adjust photo")
            .accessibilityHint("Crop, rotate, and align this photo")
            
            // Delete
            Button(action: { showDeleteConfirmation = true }) {
                VStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.system(size: AppStyle.IconSize.xl))
                    Text("Delete")
                        .font(AppStyle.FontStyle.caption)
                }
                .foregroundColor(AppStyle.Colors.accentRed)
                .frame(maxWidth: .infinity)
            }
            .accessibilityLabel("Delete photo")
            .accessibilityHint("Permanently delete this photo")
        }
        .padding(.vertical, AppStyle.Spacing.lg)
        .padding(.horizontal, AppStyle.Spacing.sm)
        .background(
            ZStack {
                Color(red: 30/255, green: 32/255, blue: 35/255).opacity(0.95)
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
            .ignoresSafeArea(edges: .bottom)
        )
    }
    
    // MARK: - Notes Editor Sheet
    private var notesEditorSheet: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                AppStyle.Colors.bgDark.ignoresSafeArea()
                
                TextEditor(text: $notesText)
                    .font(AppStyle.FontStyle.body)
                    .foregroundColor(AppStyle.Colors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding()
                
                // Placeholder
                if notesText.isEmpty {
                    Text("Add notes about this photo...")
                        .font(AppStyle.FontStyle.body)
                        .foregroundColor(AppStyle.Colors.textTertiary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppStyle.Colors.bgDark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showNotesEditor = false
                        notesText = currentPhoto.notes ?? ""
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNotes()
                    }
                }
            }
        }
    }
    
    // MARK: - Date Picker Sheet
    private var datePickerSheet: some View {
        NavigationStack {
            ZStack {
                AppStyle.Colors.bgDark.ignoresSafeArea()
                
                VStack(spacing: AppStyle.Spacing.xl) {
                    DatePicker("Date & Time", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                        .tint(AppStyle.Colors.accentCyan)
                        .padding()
                }
            }
            .navigationTitle("Change Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppStyle.Colors.bgDark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showDatePicker = false
                        selectedDate = currentPhoto.date
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveDate()
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Properties
    private var currentPhotoIndex: Int {
        allPhotos.firstIndex(where: { $0.id == currentPhoto.id }) ?? 0
    }
    
    private var canGoPrevious: Bool {
        currentPhotoIndex > 0
    }
    
    private var canGoNext: Bool {
        currentPhotoIndex < allPhotos.count - 1
    }
    
    // MARK: - Actions
    private func loadImage() async {
        // Load image and render the 4:5 cropped version with transform applied
        guard let baseImage = await PhotoStore.fetchUIImage(localId: currentPhoto.assetLocalId, targetSize: nil) else {
            return
        }
        
        // Render the final cropped 4:5 image as the user sees it in adjust view
        let croppedImage = renderCroppedImage(from: baseImage, transform: currentPhoto.alignTransform)
        
        await MainActor.run {
            image = croppedImage
        }
    }
    
    /// Renders the final 4:5 cropped image with the transform applied
    private func renderCroppedImage(from sourceImage: UIImage, transform: AlignTransform) -> UIImage {
        // Calculate target size maintaining 4:5 aspect ratio
        // Use source image width and calculate height
        let targetWidth = sourceImage.size.width
        let targetHeight = targetWidth * 5.0 / 4.0 // 4:5 ratio
        let targetSize = CGSize(width: targetWidth, height: targetHeight)
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { ctx in
            // Fill background
            ctx.cgContext.setFillColor(UIColor(red: 30/255, green: 32/255, blue: 35/255, alpha: 1.0).cgColor)
            ctx.cgContext.fill(CGRect(origin: .zero, size: targetSize))
            
            // Move to center of crop area
            ctx.cgContext.translateBy(x: targetSize.width / 2, y: targetSize.height / 2)
            
            // Apply user's transform
            ctx.cgContext.rotate(by: CGFloat(transform.rotation))
            ctx.cgContext.scaleBy(x: transform.scale, y: transform.scale)
            ctx.cgContext.translateBy(x: transform.offsetX, y: transform.offsetY)
            
            // Calculate how the image fits (scaledToFit logic)
            let imageAspect = sourceImage.size.width / sourceImage.size.height
            let cropAspect = targetSize.width / targetSize.height
            
            var drawSize: CGSize
            if imageAspect > cropAspect {
                // Image is wider - fit by width
                drawSize = CGSize(width: targetSize.width, height: targetSize.width / imageAspect)
            } else {
                // Image is taller - fit by height
                drawSize = CGSize(width: targetSize.height * imageAspect, height: targetSize.height)
            }
            
            // Draw centered
            let drawRect = CGRect(
                x: -drawSize.width / 2,
                y: -drawSize.height / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            
            sourceImage.draw(in: drawRect)
        }
    }
    
    private func previousPhoto() {
        guard canGoPrevious else { return }
        currentPhoto = allPhotos[currentPhotoIndex - 1]
        image = nil
    }
    
    private func nextPhoto() {
        guard canGoNext else { return }
        currentPhoto = allPhotos[currentPhotoIndex + 1]
        image = nil
    }
    
    private func saveNotes() {
        currentPhoto.notes = notesText.isEmpty ? nil : notesText
        try? ctx.save()
        showNotesEditor = false
    }
    
    private func saveDate() {
        currentPhoto.date = selectedDate
        try? ctx.save()
        showDatePicker = false
        // Note: Photo ordering in parent view will update automatically via SwiftData @Query
    }
    
    private func toggleHidden() {
        currentPhoto.isHidden.toggle()
        try? ctx.save()
        // Note: Hidden photos will be filtered out automatically in Watch/Compare via @Query
    }
    
    private func deletePhoto() {
        ctx.delete(currentPhoto)
        try? ctx.save()
        
        // Delete file
        Task {
            try? await PhotoStore.deleteFromAppDirectory(localId: currentPhoto.assetLocalId)
        }
        
        dismiss()
    }
}

// MARK: - Photo Adjust Sheet (Crop/Align with Ghost)
struct PhotoAdjustSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    let photo: ProgressPhoto

    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var rotation: Angle = .zero
    @State private var isSaving = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var minScale: CGFloat = 1
    @State private var hasCalculatedInitialScale = false
    
    // Ghost overlay
    @State private var ghostImage: UIImage?
    @State private var showGhost = false
    @State private var ghostOpacity: Double = 0.5
    @State private var allPhotosInJourney: [ProgressPhoto] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 30/255, green: 32/255, blue: 35/255).ignoresSafeArea()

                if let img = image {
                    GeometryReader { geo in
                        let cropW = geo.size.width
                        let cropH = cropW * 5/4
                        
                        ZStack {
                            // Full image layer (dimmed, for context)
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .scaleEffect(scale)
                                .offset(offset)
                                .rotationEffect(rotation)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .opacity(0.3)
                                .blur(radius: 3)
                                .allowsHitTesting(false)

                            // Light overlay everywhere EXCEPT the crop area (matches bottom bar translucency)
                            Rectangle()
                                .fill(Color.black.opacity(0.35))
                                .frame(width: geo.size.width, height: geo.size.height)
                                .mask(
                                    ZStack {
                                        Rectangle()
                                            .fill(Color.white)
                                        RoundedRectangle(cornerRadius: 18)
                                            .fill(Color.black)
                                            .frame(width: cropW, height: cropH)
                                            .position(x: geo.size.width/2, y: geo.size.height/2)
                                            .blendMode(.destinationOut)
                                    }
                                    .compositingGroup()
                                )
                                .allowsHitTesting(false)

                            // Bright crop area with main image + ghost overlay on top
                            ZStack {
                                // Main image being edited (below) - fade out as ghost opacity increases
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: cropW, height: cropH)
                                    .overlay(
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFit()
                                            .scaleEffect(scale)
                                            .offset(offset)
                                            .rotationEffect(rotation)
                                            .opacity(showGhost ? (1 - ghostOpacity) : 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    .position(x: cropW/2, y: geo.size.height/2)
                                
                                // Ghost overlay (on top, if enabled)
                                if showGhost, let ghost = ghostImage {
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(width: cropW, height: cropH)
                                        .overlay(
                                            Image(uiImage: ghost)
                                                .resizable()
                                                .scaledToFit()
                                                .opacity(ghostOpacity)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 18))
                                        .position(x: cropW/2, y: geo.size.height/2)
                                        .allowsHitTesting(false)
                                }
                                
                                // Border and shadow on top of everything
                                Rectangle()
                                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                    .frame(width: cropW, height: cropH)
                                    .position(x: cropW/2, y: geo.size.height/2)
                                    .allowsHitTesting(false)
                            }
                            .frame(width: geo.size.width, height: geo.size.height)
                            .position(x: geo.size.width/2, y: geo.size.height/2)
                            .gesture(
                                SimultaneousGesture(
                                    DragGesture()
                                        .onChanged { value in
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            lastOffset = offset
                                        },
                                    MagnificationGesture()
                                        .onChanged { value in
                                            let newScale = lastScale * value
                                            scale = max(minScale, newScale)
                                            print("🔍 Zoom: \(scale) (min: \(minScale))")
                                        }
                                        .onEnded { _ in
                                            lastScale = scale
                                            print("✅ Zoom ended at: \(scale)")
                                        }
                                )
                            )
                            .gesture(
                                RotationGesture().onChanged { rotation = $0 }
                            )
                        }
                        .onChange(of: geo.size) { _, newSize in
                            // Recalculate scale when geometry changes (e.g., rotation)
                            if hasCalculatedInitialScale {
                                calculateInitialScale(imageSize: img.size, cropSize: CGSize(width: newSize.width, height: newSize.width * 5/4))
                            }
                        }
                        .task(id: img) {
                            // Calculate initial scale when image loads or changes
                            if !hasCalculatedInitialScale {
                                calculateInitialScale(imageSize: img.size, cropSize: CGSize(width: cropW, height: cropH))
                                hasCalculatedInitialScale = true
                            }
                        }
                    }
                } else {
                    ProgressView().tint(.white)
                }
            }
            .navigationTitle("Edit Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar, .bottomBar)
            .toolbarBackground(.visible, for: .navigationBar, .bottomBar)
            .toolbarColorScheme(.dark, for: .navigationBar, .bottomBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Task { await saveEdits() }
                    }) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark")
                                .foregroundColor((image == nil) ? .gray : .cyan)
                                .font(.body.weight(.semibold))
                        }
                    }
                    .disabled(isSaving || image == nil)
                }
            }
            .task { 
                await loadImage()
                await loadGhostImage()
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    // Ghost Overlay controls
                    if ghostImage != nil {
                        HStack(spacing: 16) {
                            Button(action: { showGhost.toggle() }) {
                                HStack(spacing: 8) {
                                    Image(systemName: showGhost ? "eye.fill" : "eye.slash.fill")
                                    Text("Ghost Overlay")
                                        .font(.subheadline.weight(.medium))
                                }
                                .foregroundColor(showGhost ? .cyan : .white.opacity(0.7))
                            }
                            
                            Spacer()
                        }
                        
                        // Slider
                        if showGhost {
                            HStack {
                                Image(systemName: "circle.lefthalf.filled")
                                    .foregroundColor(.white.opacity(0.7))
                                Slider(value: $ghostOpacity, in: 0...1)
                                    .tint(.cyan)
                                Text("\(Int(ghostOpacity * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 40)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
                .background(
                    ZStack {
                        Color(red: 30/255, green: 32/255, blue: 35/255).opacity(0.9)
                        Rectangle()
                            .fill(.ultraThinMaterial)
                    }
                    .ignoresSafeArea(edges: .bottom)
                )
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func loadImage() async {
        image = await PhotoStore.fetchUIImage(localId: photo.assetLocalId, targetSize: nil)
        
        // Apply saved transform if it exists
        await MainActor.run {
            let transform = photo.alignTransform
            if transform.scale != 1 || transform.offsetX != 0 || transform.offsetY != 0 || transform.rotation != 0 {
                // User has previously edited this photo - restore their edits
                scale = transform.scale
                lastScale = transform.scale
                // Allow zoom out further than saved level (will be constrained by minScale later)
                offset = CGSize(width: transform.offsetX, height: transform.offsetY)
                lastOffset = offset
                rotation = Angle(radians: transform.rotation)
                hasCalculatedInitialScale = true // Prevent calculateInitialScale from overwriting
                print("📸 Loaded saved transform: scale=\(transform.scale), offset=(\(transform.offsetX), \(transform.offsetY)), rotation=\(transform.rotation)")
            }
        }
    }
    
    private func loadGhostImage() async {
        // Fetch photos in the same journey
        let journeyId = photo.journeyId
        let descriptor = FetchDescriptor<ProgressPhoto>(
            predicate: #Predicate { $0.journeyId == journeyId },
            sortBy: [SortDescriptor(\ProgressPhoto.date, order: .forward)]
        )
        
        do {
            let photosInJourney = try ctx.fetch(descriptor)
            await MainActor.run {
                allPhotosInJourney = photosInJourney
            }
            
            // Load the first photo in the journey as ghost overlay
            guard let firstPhoto = photosInJourney.first, firstPhoto.id != photo.id else {
                print("👻 No ghost photo available (this is the first photo)")
                return
            }
            
            print("👻 Loading ghost image from first photo...")
            
            if let loadedGhost = await PhotoStore.fetchUIImage(localId: firstPhoto.assetLocalId, targetSize: nil) {
                await MainActor.run {
                    // Render the ghost with its transform as a 4:5 cropped image (same as main display)
                    let croppedGhost = renderCroppedGhostImage(from: loadedGhost, transform: firstPhoto.alignTransform)
                    self.ghostImage = croppedGhost
                    print("👻 Ghost image loaded and cropped successfully")
                }
            } else {
                print("❌ Failed to load ghost image")
            }
        } catch {
            print("❌ Error fetching photos for ghost: \(error)")
        }
    }
    
    private func renderCroppedGhostImage(from sourceImage: UIImage, transform: AlignTransform) -> UIImage {
        // Render ghost image with same 4:5 crop logic as main image
        let targetWidth = sourceImage.size.width
        let targetHeight = targetWidth * 5.0 / 4.0
        let targetSize = CGSize(width: targetWidth, height: targetHeight)
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { ctx in
            // Fill background
            ctx.cgContext.setFillColor(UIColor(red: 30/255, green: 32/255, blue: 35/255, alpha: 1.0).cgColor)
            ctx.cgContext.fill(CGRect(origin: .zero, size: targetSize))
            
            // Move to center
            ctx.cgContext.translateBy(x: targetSize.width / 2, y: targetSize.height / 2)
            
            // Apply transform
            ctx.cgContext.rotate(by: CGFloat(transform.rotation))
            ctx.cgContext.scaleBy(x: transform.scale, y: transform.scale)
            ctx.cgContext.translateBy(x: transform.offsetX, y: transform.offsetY)
            
            // Calculate fit size
            let imageAspect = sourceImage.size.width / sourceImage.size.height
            let cropAspect = targetSize.width / targetSize.height
            
            var drawSize: CGSize
            if imageAspect > cropAspect {
                drawSize = CGSize(width: targetSize.width, height: targetSize.width / imageAspect)
            } else {
                drawSize = CGSize(width: targetSize.height * imageAspect, height: targetSize.height)
            }
            
            // Draw centered
            let drawRect = CGRect(
                x: -drawSize.width / 2,
                y: -drawSize.height / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            
            sourceImage.draw(in: drawRect)
        }
    }
    
    private func calculateInitialScale(imageSize: CGSize, cropSize: CGSize) {
        // Image will be .scaledToFit() within the crop area
        // Then we apply scaleEffect to zoom it to fill
        
        let imageAspect = imageSize.width / imageSize.height
        let cropAspect = cropSize.width / cropSize.height  // 4:5 = 0.8
        
        // ScaledToFit will constrain by the limiting dimension
        // To fill, we need to scale by the ratio of the crop aspect to image aspect
        let fillScale: CGFloat
        if imageAspect > cropAspect {
            // Image is wider than crop - fits by width, needs to scale by height ratio
            fillScale = imageAspect / cropAspect
        } else {
            // Image is taller than crop - fits by height, needs to scale by width ratio
            fillScale = cropAspect / imageAspect
        }
        
        // Always update minScale to the fill scale
        minScale = fillScale
        
        // Only set initial scale if we haven't loaded a saved transform
        if !hasCalculatedInitialScale {
            scale = fillScale
            lastScale = fillScale
            print("📐 Scale calc: image=\(imageSize), crop=\(cropSize)")
            print("📐 Image aspect=\(String(format: "%.2f", imageAspect)), crop aspect=\(String(format: "%.2f", cropAspect))")
            print("📐 Initial scale: \(String(format: "%.2f", fillScale)) (min: \(String(format: "%.2f", minScale)))")
        } else {
            print("📐 Skipping initial scale - using saved transform (scale: \(scale), min: \(minScale))")
        }
    }

    private func saveEdits() async {
        guard image != nil else { return }
        isSaving = true

        // Save the transform without creating a new image
        // This keeps the original image and allows re-editing with full zoom out
        await MainActor.run {
            do {
                photo.alignTransform = AlignTransform(
                    scale: scale,
                    offsetX: offset.width,
                    offsetY: offset.height,
                    rotation: rotation.radians
                )
                
                try ctx.save()
                print("✅ Photo transform saved: scale=\(scale), offset=(\(offset.width), \(offset.height)), rotation=\(rotation.radians)")
                isSaving = false
                dismiss()
            } catch {
                print("❌ Error saving photo transform: \(error)")
                errorMessage = "Failed to save edits: \(error.localizedDescription)"
                showErrorAlert = true
                isSaving = false
            }
        }
    }
    
}

// MARK: - Journey Compare Sheet
struct JourneyCompareSheet: View {
    let journey: Journey
    let photos: [ProgressPhoto]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 30/255, green: 32/255, blue: 35/255)
                    .ignoresSafeArea()
                
                JourneyCompareView(journey: journey, photos: photos)
                    .padding()
            }
            .navigationTitle("Compare Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Journey Compare View
struct JourneyCompareView: View {
    let journey: Journey
    let photos: [ProgressPhoto]
    @State private var left: ProgressPhoto?
    @State private var right: ProgressPhoto?
    @State private var mode: CompareMode = .parallel
    @State private var showDates = true
    @State private var fitImage = false
    @State private var selectedSide: SelectionSide = .left
    @State private var showTooltip = false
    
    enum CompareMode: String, CaseIterable {
        case parallel = "Parallel"
        case slider = "Slider"
    }
    
    enum SelectionSide {
        case left, right
    }
    
    // Filter out hidden photos
    private var visiblePhotos: [ProgressPhoto] {
        photos.filter { !$0.isHidden }
    }
    
    private func flipPhotos() {
        let temp = left
        left = right
        right = temp
    }
    
    private func selectPhoto(_ photo: ProgressPhoto) {
        if selectedSide == .left {
            left = photo
        } else {
            right = photo
        }
        // Hide tooltip when photo is selected
        withAnimation(.easeOut(duration: 0.2)) {
            showTooltip = false
        }
    }
    
    private func selectSide(_ side: SelectionSide) {
        selectedSide = side
        withAnimation(.easeIn(duration: 0.2)) {
            showTooltip = true
        }
        
        // Auto-hide tooltip after 3 seconds
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    showTooltip = false
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if visiblePhotos.count >= 2 {
                // Increased spacing for title/done button
                Spacer().frame(height: AppStyle.Spacing.lg)
                
                // Segmented control
                Picker("Mode", selection: $mode) {
                    ForEach(CompareMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                Spacer().frame(height: AppStyle.Spacing.sm)
                
                // Action buttons ABOVE comparison
                if left != nil && right != nil {
                    HStack(spacing: AppStyle.Spacing.xl) {
                        // Dates toggle
                        Button(action: {
                            showDates.toggle()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: showDates ? "calendar.badge.checkmark" : "calendar")
                                    .font(.system(size: AppStyle.IconSize.xl))
                                    .foregroundColor(showDates ? AppStyle.Colors.accentCyan : AppStyle.Colors.textPrimary)
                                Text("Dates")
                                    .font(AppStyle.FontStyle.caption)
                                    .foregroundColor(AppStyle.Colors.textSecondary)
                            }
                            .frame(width: 70)
                        }
                        
                        // Fit Image toggle
                        Button(action: {
                            fitImage.toggle()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: fitImage ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                                    .font(.system(size: AppStyle.IconSize.xl))
                                    .foregroundColor(fitImage ? AppStyle.Colors.accentCyan : AppStyle.Colors.textPrimary)
                                Text("Fit Image")
                                    .font(AppStyle.FontStyle.caption)
                                    .foregroundColor(AppStyle.Colors.textSecondary)
                            }
                            .frame(width: 70)
                        }
                        
                        // Flip action
                        Button(action: flipPhotos) {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: AppStyle.IconSize.xl))
                                    .foregroundColor(AppStyle.Colors.textPrimary)
                                Text("Flip")
                                    .font(AppStyle.FontStyle.caption)
                                    .foregroundColor(AppStyle.Colors.textSecondary)
                            }
                            .frame(width: 70)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, AppStyle.Spacing.sm)
                }
                
                // Main comparison view - full width with 4:5 ratio
                if let left = left, let right = right {
                    GeometryReader { geometry in
                        let availableWidth = geometry.size.width
                        let canvasHeight = availableWidth * 5.0 / 4.0 // 4:5 aspect ratio
                        
                        ZStack {
                            ImprovedCompareCanvas(
                                left: left,
                                right: right,
                                mode: mode,
                                showDates: showDates,
                                fitImage: fitImage
                            )
                            .frame(width: availableWidth, height: canvasHeight)
                            .background(
                                RoundedRectangle(cornerRadius: AppStyle.Corner.xl)
                                    .fill(AppStyle.Colors.panel)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppStyle.Corner.xl)
                                    .stroke(AppStyle.Colors.border, lineWidth: 1)
                            )
                        
                        // Tap areas to select which side to replace
                        HStack(spacing: 0) {
                            // Left tap area
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectSide(.left)
                                }
                                .overlay(
                                    VStack {
                                        if selectedSide == .left && showTooltip {
                                            ZStack {
                                                Circle()
                                                    .fill(.white)
                                                    .frame(width: 40, height: 40)
                                                    .shadow(radius: 4)
                                                
                                                Text("L")
                                                    .font(.system(size: 20, weight: .bold))
                                                    .foregroundColor(.black)
                                            }
                                            .padding(.top, 20)
                                            
                                            Text("Tap an image\nbelow to replace")
                                                .font(AppStyle.FontStyle.caption)
                                                .multilineTextAlignment(.center)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(AppStyle.Colors.bgDark.opacity(0.9))
                                                )
                                                .padding(.top, 8)
                                                .transition(.opacity)
                                        }
                                        Spacer()
                                    }
                                )
                            
                            // Right tap area
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectSide(.right)
                                }
                                .overlay(
                                    VStack {
                                        if selectedSide == .right && showTooltip {
                                            ZStack {
                                                Circle()
                                                    .fill(.white)
                                                    .frame(width: 40, height: 40)
                                                    .shadow(radius: 4)
                                                
                                                Text("R")
                                                    .font(.system(size: 20, weight: .bold))
                                                    .foregroundColor(.black)
                                            }
                                            .padding(.top, 20)
                                            
                                            Text("Tap an image\nbelow to replace")
                                                .font(AppStyle.FontStyle.caption)
                                                .multilineTextAlignment(.center)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(AppStyle.Colors.bgDark.opacity(0.9))
                                                )
                                                .padding(.top, 8)
                                                .transition(.opacity)
                                        }
                                        Spacer()
                                    }
                                )
                        }
                        }
                    }
                    .frame(height: UIScreen.main.bounds.width * 5.0 / 4.0) // Reserve space for GeometryReader with 4:5 ratio
                    
                    Spacer().frame(height: AppStyle.Spacing.lg)
                    
                    // Single photo slider
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(visiblePhotos) { photo in
                                Button(action: {
                                    selectPhoto(photo)
                                }) {
                                    ZStack(alignment: .topLeading) {
                                        PhotoGridItem(photo: photo)
                                            .frame(width: 120, height: 150)
                                        
                                        // Selection indicators
                                        VStack(spacing: 4) {
                                            if self.left?.id == photo.id {
                                                Circle()
                                                    .fill(AppStyle.Colors.accentRed)
                                                    .frame(width: 28, height: 28)
                                                    .overlay(
                                                        Text("L")
                                                            .font(.system(size: 14, weight: .bold))
                                                            .foregroundColor(.white)
                                                    )
                                            }
                                            if self.right?.id == photo.id {
                                                Circle()
                                                    .fill(AppStyle.Colors.accentRed)
                                                    .frame(width: 28, height: 28)
                                                    .overlay(
                                                        Text("R")
                                                            .font(.system(size: 14, weight: .bold))
                                                            .foregroundColor(.white)
                                                    )
                                            }
                                        }
                                        .padding(8)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, AppStyle.Spacing.lg)
                    
                } else {
                    // Empty state
                    GeometryReader { geometry in
                        let availableWidth = geometry.size.width
                        let canvasHeight = availableWidth * 5.0 / 4.0 // 4:5 aspect ratio
                        
                        RoundedRectangle(cornerRadius: AppStyle.Corner.xl)
                            .fill(AppStyle.Colors.panel)
                            .frame(width: availableWidth, height: canvasHeight)
                            .overlay(
                                Text("Select two photos to compare")
                                    .font(AppStyle.FontStyle.body)
                                    .foregroundColor(AppStyle.Colors.textSecondary)
                            )
                    }
                    .frame(height: UIScreen.main.bounds.width * 5.0 / 4.0)
                }
            } else {
                // No photos state
                RoundedRectangle(cornerRadius: AppStyle.Corner.xl)
                    .fill(AppStyle.Colors.panel)
                    .frame(height: 200)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title2)
                                .foregroundColor(AppStyle.Colors.textTertiary)
                            Text("Add at least 2 photos to compare")
                                .font(AppStyle.FontStyle.body)
                                .foregroundColor(AppStyle.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    )
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .onAppear {
            // Auto-select oldest (before) and newest (after) visible photos
            if left == nil && right == nil && visiblePhotos.count >= 2 {
                left = visiblePhotos.last  // Oldest photo (Picture 1)
                right = visiblePhotos.first  // Newest photo (Picture 2)
            }
        }
    }
}

// MARK: - Improved Compare Canvas
struct ImprovedCompareCanvas: View {
    let left: ProgressPhoto
    let right: ProgressPhoto
    let mode: JourneyCompareView.CompareMode
    let showDates: Bool
    let fitImage: Bool
    
    @State private var leftImg: UIImage?
    @State private var rightImg: UIImage?
    @State private var sliderPosition: CGFloat = 0.5
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let l = leftImg, let r = rightImg {
                    switch mode {
                    case .parallel:
                        parallelView(leftImg: l, rightImg: r, width: geometry.size.width, height: geometry.size.height)
                    case .slider:
                        sliderView(leftImg: l, rightImg: r, width: geometry.size.width, height: geometry.size.height)
                    }
                } else {
                    ProgressView()
                        .tint(AppStyle.Colors.textPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .task {
            await loadImages()
        }
        .onChange(of: left) { _, _ in
            Task { await loadImages() }
        }
        .onChange(of: right) { _, _ in
            Task { await loadImages() }
        }
    }
    
    private func parallelView(leftImg: UIImage, rightImg: UIImage, width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 8) {
            // Left image with date
            VStack(spacing: 4) {
                Image(uiImage: leftImg)
                    .resizable()
                    .aspectRatio(contentMode: fitImage ? .fit : .fill)
                    .frame(width: (width - 16) / 2, height: height - (showDates ? 30 : 0))
                    .clipped()
                    .cornerRadius(AppStyle.Corner.md)
                
                if showDates {
                    Text(left.date.formatted(date: .abbreviated, time: .omitted))
                        .font(AppStyle.FontStyle.caption)
                        .foregroundColor(AppStyle.Colors.textSecondary)
                }
            }
            
            // Right image with date
            VStack(spacing: 4) {
                Image(uiImage: rightImg)
                    .resizable()
                    .aspectRatio(contentMode: fitImage ? .fit : .fill)
                    .frame(width: (width - 16) / 2, height: height - (showDates ? 30 : 0))
                    .clipped()
                    .cornerRadius(AppStyle.Corner.md)
                
                if showDates {
                    Text(right.date.formatted(date: .abbreviated, time: .omitted))
                        .font(AppStyle.FontStyle.caption)
                        .foregroundColor(AppStyle.Colors.textSecondary)
                }
            }
        }
        .padding(8)
    }
    
    private func sliderView(leftImg: UIImage, rightImg: UIImage, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Left image (base layer)
            Image(uiImage: leftImg)
                .resizable()
                .aspectRatio(contentMode: fitImage ? .fit : .fill)
                .frame(width: width, height: height)
                .clipped()
            
            // Right image (masked overlay)
            Image(uiImage: rightImg)
                .resizable()
                .aspectRatio(contentMode: fitImage ? .fit : .fill)
                .frame(width: width, height: height)
                .clipped()
                .mask(alignment: .leading) {
                    Rectangle()
                        .frame(width: width - (width * sliderPosition))
                        .offset(x: width * sliderPosition)
                }
            
            // Divider line with handle
            VStack {
                Circle()
                    .fill(AppStyle.Colors.textPrimary)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "arrow.left.and.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppStyle.Colors.bgDark)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            }
            .frame(maxHeight: .infinity)
            .frame(width: 3)
            .background(AppStyle.Colors.textPrimary)
            .position(x: width * sliderPosition, y: height / 2)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newPosition = value.location.x / width
                        sliderPosition = min(max(newPosition, 0), 1)
                    }
            )
            
            // Date labels for slider mode
            if showDates {
                VStack {
                    HStack {
                        Text(left.date.formatted(date: .abbreviated, time: .omitted))
                            .font(AppStyle.FontStyle.caption2)
                            .foregroundColor(AppStyle.Colors.textPrimary)
                            .padding(6)
                            .background(AppStyle.Colors.bgDark.opacity(0.8))
                            .cornerRadius(6)
                            .padding(8)
                        
                        Spacer()
                        
                        Text(right.date.formatted(date: .abbreviated, time: .omitted))
                            .font(AppStyle.FontStyle.caption2)
                            .foregroundColor(AppStyle.Colors.textPrimary)
                            .padding(6)
                            .background(AppStyle.Colors.bgDark.opacity(0.8))
                            .cornerRadius(6)
                            .padding(8)
                    }
                    Spacer()
                }
            }
        }
        .cornerRadius(AppStyle.Corner.lg)
    }
    
    private func loadImages() async {
        // Capture asset IDs on main actor to avoid Sendable warnings
        let leftLocalId = left.assetLocalId
        let rightLocalId = right.assetLocalId
        
        // Calculate target size for downsampling
        let screenSize = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        let targetSize = CGSize(
            width: screenSize.width * scale / 2,  // Half width for side-by-side
            height: screenSize.height * scale / 2
        )
        
        // Load both images concurrently
        async let leftTask = PhotoStore.fetchUIImage(localId: leftLocalId, targetSize: targetSize)
        async let rightTask = PhotoStore.fetchUIImage(localId: rightLocalId, targetSize: targetSize)
        
        leftImg = await leftTask
        rightImg = await rightTask
    }
}

// MARK: - Journey Watch Sheet
struct JourneyWatchSheet: View {
    let journey: Journey
    let photos: [ProgressPhoto]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 30/255, green: 32/255, blue: 35/255)
                    .ignoresSafeArea()
                
                JourneyWatchView(journey: journey, photos: photos)
                    .padding()
            }
            .navigationTitle("Watch Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Journey Watch View
struct JourneyWatchView: View {
    let journey: Journey
    let photos: [ProgressPhoto]
    @State private var isPlaying = false
    @State private var currentIndex = 0
    @State private var playbackSpeed: Double = 1.0
    @State private var showExportSheet = false
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var exportedVideoURL: URL?
    
    // Reverse photos to show oldest → newest (chronological order), excluding hidden
    private var chronologicalPhotos: [ProgressPhoto] {
        photos.filter { !$0.isHidden }.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        VStack(spacing: AppStyle.Spacing.lg) {
            if chronologicalPhotos.isEmpty {
                emptyState
            } else if chronologicalPhotos.count == 1 {
                singlePhotoState
            } else {
                normalState
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                startPlayback()
            }
        }
        .onDisappear {
            isPlaying = false
        }
        .sheet(item: $exportedVideoURL) { url in
            if #available(iOS 16.0, *) {
                ShareSheet(url: url)
            }
        }
    }
    
    private var emptyState: some View {
        RoundedRectangle(cornerRadius: AppStyle.Corner.xl)
            .fill(AppStyle.Colors.panel)
            .frame(height: 200)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "play.rectangle")
                        .font(.title2)
                        .foregroundColor(AppStyle.Colors.textTertiary)
                    Text("Add photos to watch your progress")
                        .font(AppStyle.FontStyle.body)
                        .foregroundColor(AppStyle.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            )
    }
    
    private var singlePhotoState: some View {
        VStack(spacing: AppStyle.Spacing.lg) {
            PhotoGridItem(photo: chronologicalPhotos[0])
                .frame(height: 400)
                .glassCard()
            
            Text("1 / 1 • \(chronologicalPhotos[0].date.formatted(date: .abbreviated, time: .omitted))")
                .font(AppStyle.FontStyle.caption)
                .foregroundColor(AppStyle.Colors.textSecondary)
            
            Text("Add more photos to create a slideshow")
                .font(AppStyle.FontStyle.caption)
                .foregroundColor(AppStyle.Colors.textTertiary)
        }
    }
    
    private var normalState: some View {
        VStack(spacing: AppStyle.Spacing.lg) {
            // Main photo display
            if currentIndex < chronologicalPhotos.count {
                PhotoGridItem(photo: chronologicalPhotos[currentIndex])
                    .frame(height: 400)
                    .glassCard()
            }
            
            // Position indicator: "1 / N • Date"
            Text("\(currentIndex + 1) / \(chronologicalPhotos.count) • \(chronologicalPhotos[currentIndex].date.formatted(date: .abbreviated, time: .omitted))")
                .font(AppStyle.FontStyle.caption)
                .foregroundColor(AppStyle.Colors.textSecondary)
            
            // Scrubber slider
            HStack(spacing: 12) {
                Text("1")
                    .font(AppStyle.FontStyle.caption)
                    .foregroundColor(AppStyle.Colors.textSecondary)
                    .frame(width: 20)
                
                Slider(value: Binding(
                    get: { Double(currentIndex) },
                    set: { currentIndex = Int($0) }
                ), in: 0...Double(max(0, chronologicalPhotos.count - 1)), step: 1)
                .tint(AppStyle.Colors.accent)
                
                Text("\(chronologicalPhotos.count)")
                    .font(AppStyle.FontStyle.caption)
                    .foregroundColor(AppStyle.Colors.textSecondary)
                    .frame(width: 30, alignment: .trailing)
            }
            .padding(.horizontal)
            
            // Controls: Previous | Play/Pause | Next
            HStack(spacing: AppStyle.Spacing.xxxl) {
                Button(action: {
                    if currentIndex > 0 {
                        currentIndex -= 1
                    }
                }) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundColor(currentIndex == 0 ? AppStyle.Colors.textTertiary : AppStyle.Colors.textPrimary)
                }
                .disabled(currentIndex == 0)
                .accessibilityLabel("Previous photo")
                .accessibilityHint("Go to the previous photo in the slideshow")
                
                Button(action: {
                    isPlaying.toggle()
                }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(AppStyle.Colors.textPrimary)
                }
                .accessibilityLabel(isPlaying ? "Pause slideshow" : "Play slideshow")
                .accessibilityHint("Play through all \(chronologicalPhotos.count) photos from oldest to newest")
                
                Button(action: {
                    if currentIndex < chronologicalPhotos.count - 1 {
                        currentIndex += 1
                    }
                }) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor(currentIndex >= chronologicalPhotos.count - 1 ? AppStyle.Colors.textTertiary : AppStyle.Colors.textPrimary)
                }
                .disabled(currentIndex >= chronologicalPhotos.count - 1)
                .accessibilityLabel("Next photo")
                .accessibilityHint("Go to the next photo in the slideshow")
            }
            .padding(.vertical, AppStyle.Spacing.sm)
            
            // Export button
            if isExporting {
                VStack(spacing: 8) {
                    ProgressView(value: exportProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(AppStyle.Colors.accentCyan)
                    
                    Text("Exporting: \(Int(exportProgress * 100))%")
                        .font(AppStyle.FontStyle.caption)
                        .foregroundColor(AppStyle.Colors.textSecondary)
                }
                .padding()
                .glassCard()
            } else {
                Button(action: {
                    Task {
                        await exportVideo()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: AppStyle.IconSize.lg))
                        Text("Export Video")
                            .font(AppStyle.FontStyle.headline)
                    }
                    .foregroundColor(AppStyle.Colors.textPrimary)
                    .padding(.horizontal, AppStyle.Spacing.xl)
                    .padding(.vertical, AppStyle.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppStyle.Corner.lg)
                            .fill(AppStyle.Colors.panel)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppStyle.Corner.lg)
                                    .stroke(AppStyle.Colors.border, lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func startPlayback() {
        guard isPlaying && !chronologicalPhotos.isEmpty else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + (1.0 / playbackSpeed)) {
            if self.isPlaying {
                if self.currentIndex < self.chronologicalPhotos.count - 1 {
                    self.currentIndex += 1
                    self.startPlayback()
                } else {
                    // Loop back to start
                    self.currentIndex = 0
                    self.startPlayback()
                }
            }
        }
    }
    
    private func exportVideo() async {
        await MainActor.run {
            isExporting = true
            exportProgress = 0
        }
        
        // Capture needed data before detached task to avoid Sendable warnings
        let photosToExport = chronologicalPhotos
        let journeyName = journey.name
        
        // Run export on background queue
        let result = await Task.detached {
            return await VideoExporter.exportProgressVideo(
                photos: photosToExport,
                journeyName: journeyName,
                progressCallback: { progress in
                    Task { @MainActor in
                        exportProgress = progress
                    }
                }
            )
        }.value
        
        await MainActor.run {
            isExporting = false
            if let url = result {
                exportedVideoURL = url
            }
        }
    }
}

// MARK: - Video Exporter
actor VideoExporter {
    static func exportProgressVideo(
        photos: [ProgressPhoto],
        journeyName: String,
        progressCallback: @escaping (Double) -> Void
    ) async -> URL? {
        guard !photos.isEmpty else { return nil }
        
        // Configuration
        let fps = 30
        let frameDuration: Double = 1.0  // 1 second per photo
        let framesPerPhoto = Int(frameDuration * Double(fps))
        let resolution = CGSize(width: 1080, height: 1350)  // 4:5 aspect ratio
        
        // Create temp file
        let tempDir = FileManager.default.temporaryDirectory
        let timestamp = Date().timeIntervalSince1970
        let outputURL = tempDir.appendingPathComponent("progress_\(journeyName)_\(Int(timestamp)).mp4")
        
        // Remove if exists
        try? FileManager.default.removeItem(at: outputURL)
        
        guard let videoWriter = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            return nil
        }
        
        // Video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: resolution.width,
            AVVideoHeightKey: resolution.height
        ]
        
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: resolution.width,
                kCVPixelBufferHeightKey as String: resolution.height
            ]
        )
        
        guard videoWriter.canAdd(videoInput) else { return nil }
        videoWriter.add(videoInput)
        
        guard videoWriter.startWriting() else { return nil }
        videoWriter.startSession(atSourceTime: .zero)
        
        var frameCount = 0
        let totalFrames = photos.count * framesPerPhoto
        
        // Write frames
        for photo in photos {
            // Load image downsampled to target resolution
            guard let image = await PhotoStore.fetchUIImage(localId: photo.assetLocalId, targetSize: resolution) else {
                continue
            }
            
            // Render this image for the required number of frames
            for _ in 0..<framesPerPhoto {
                while !videoInput.isReadyForMoreMediaData {
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
                
                let presentationTime = CMTime(value: Int64(frameCount), timescale: Int32(fps))
                
                if let pixelBuffer = createPixelBuffer(from: image, size: resolution) {
                    adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                }
                
                frameCount += 1
                
                // Update progress
                let progress = Double(frameCount) / Double(totalFrames)
                progressCallback(progress)
            }
        }
        
        videoInput.markAsFinished()
        await videoWriter.finishWriting()
        
        return videoWriter.status == .completed ? outputURL : nil
    }
    
    private static func createPixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        
        guard let ctx = context, let cgImage = image.cgImage else {
            return nil
        }
        
        // Fill background
        ctx.setFillColor(UIColor(red: 30/255, green: 32/255, blue: 35/255, alpha: 1.0).cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        
        // Calculate letterbox rect
        let imageAspect = image.size.width / image.size.height
        let targetAspect = size.width / size.height
        
        let drawRect: CGRect
        if imageAspect > targetAspect {
            // Image is wider - fit width
            let height = size.width / imageAspect
            drawRect = CGRect(x: 0, y: (size.height - height) / 2, width: size.width, height: height)
        } else {
            // Image is taller - fit height
            let width = size.height * imageAspect
            drawRect = CGRect(x: (size.width - width) / 2, y: 0, width: width, height: size.height)
        }
        
        ctx.draw(cgImage, in: drawRect)
        
        return buffer
    }
}

// MARK: - Share Sheet
@available(iOS 16.0, *)
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Make URL identifiable for sheet presentation
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
