import SwiftUI
import SwiftData
import PhotosUI
import Photos

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
            .background(ThemeColors.backgroundColor())
            .navigationTitle("Journeys")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
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
            PhotoEditSheet(photo: photo)
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
        .task {
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
        // Render the transformed image for the thumbnail to match exactly what's shown in edit view
        let cropSize = CGSize(width: size * 2, height: size * 2.5) // 4:5 ratio at 2x for quality
        
        // Calculate scaled-to-fit size (matching SwiftUI's .scaledToFit())
        let imageAspect = image.size.width / image.size.height
        let cropAspect = cropSize.width / cropSize.height
        
        var fitSize: CGSize
        if imageAspect > cropAspect {
            // Image is wider - constrain by width
            fitSize = CGSize(width: cropSize.width, height: cropSize.width / imageAspect)
        } else {
            // Image is taller - constrain by height
            fitSize = CGSize(width: cropSize.height * imageAspect, height: cropSize.height)
        }
        
        // The offset was captured at screen resolution (screen width)
        // We need to scale it to match our render resolution
        let screenWidth = UIScreen.main.bounds.width
        let scaleFactor = cropSize.width / screenWidth
        let scaledOffsetX = transform.offsetX * scaleFactor
        let scaledOffsetY = transform.offsetY * scaleFactor
        
        let renderer = UIGraphicsImageRenderer(size: cropSize)
        return renderer.image { ctx in
            // Fill with black (background outside crop)
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: cropSize))
            
            // Apply transforms using the same method as the edit view
            // 1. Translate to center + scaled user offset
            ctx.cgContext.translateBy(
                x: cropSize.width/2 + scaledOffsetX,
                y: cropSize.height/2 + scaledOffsetY
            )
            
            // 2. Apply rotation around the offset center point
            ctx.cgContext.rotate(by: CGFloat(transform.rotation))
            
            // 3. Apply scale (zoom)
            ctx.cgContext.scaleBy(x: transform.scale, y: transform.scale)
            
            // 4. Draw the image centered at scaled-to-fit size
            let drawRect = CGRect(
                x: -fitSize.width/2,
                y: -fitSize.height/2,
                width: fitSize.width,
                height: fitSize.height
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
                        .background(.ultraThinMaterial)
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
struct PhotoEditSheet: View {
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
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
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
                    .disabled(isSaving || image == nil || isDeleting)
                }
            }
            .task { 
                await loadImage()
                await loadGhostImage()
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    // Top row: Ghost Overlay and Delete Photo buttons side by side
                    HStack(spacing: 16) {
                        if ghostImage != nil {
                            Button(action: { showGhost.toggle() }) {
                                HStack(spacing: 8) {
                                    Image(systemName: showGhost ? "eye.fill" : "eye.slash.fill")
                                    Text("Ghost Overlay")
                                        .font(.subheadline.weight(.medium))
                                }
                                .foregroundColor(showGhost ? .cyan : .white.opacity(0.7))
                            }
                        }
                        
                        Spacer()
                        
                        Button(role: .destructive, action: {
                            showDeleteConfirmation = true
                        }) {
                            HStack(spacing: 6) {
                                Text("Delete Photo")
                                Image(systemName: "trash")
                            }
                            .foregroundColor(.red)
                            .font(.subheadline.weight(.medium))
                        }
                        .disabled(isDeleting)
                    }
                    
                    // Bottom row: Slider (always reserve space, but hide when ghost is disabled)
                    HStack {
                        if showGhost && ghostImage != nil {
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
                    .frame(height: 28) // Fixed height to maintain consistent bottom bar size
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, ignoresSafeAreaEdges: .bottom)
            }
            .alert("Delete Photo", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task { await deletePhoto() }
                }
            } message: {
                Text("Are you sure you want to delete this photo? This action cannot be undone.")
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
            let screenSize = UIScreen.main.bounds.size
            let scale = UIScreen.main.scale
            let targetSize = CGSize(width: screenSize.width * scale, height: screenSize.width * 5/4 * scale)
            
            if let loadedGhost = await PhotoStore.fetchUIImage(localId: firstPhoto.assetLocalId, targetSize: targetSize) {
                await MainActor.run {
                    // Apply the ghost's transform if it has one
                    let ghostTransform = firstPhoto.alignTransform
                    if ghostTransform.scale != 1 || ghostTransform.offsetX != 0 || ghostTransform.offsetY != 0 || ghostTransform.rotation != 0 {
                        // Ghost has been edited - need to render it with transform
                        let renderer = UIGraphicsImageRenderer(size: loadedGhost.size)
                        let transformedGhost = renderer.image { ctx in
                            ctx.cgContext.translateBy(x: loadedGhost.size.width/2, y: loadedGhost.size.height/2)
                            ctx.cgContext.rotate(by: CGFloat(ghostTransform.rotation))
                            ctx.cgContext.scaleBy(x: ghostTransform.scale, y: ghostTransform.scale)
                            ctx.cgContext.translateBy(x: ghostTransform.offsetX, y: ghostTransform.offsetY)
                            
                            let drawRect = CGRect(
                                x: -loadedGhost.size.width/2,
                                y: -loadedGhost.size.height/2,
                                width: loadedGhost.size.width,
                                height: loadedGhost.size.height
                            )
                            loadedGhost.draw(in: drawRect)
                        }
                        self.ghostImage = transformedGhost
                    } else {
                        self.ghostImage = loadedGhost
                    }
                    print("👻 Ghost image loaded successfully")
                }
            } else {
                print("❌ Failed to load ghost image")
            }
        } catch {
            print("❌ Error fetching photos for ghost: \(error)")
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
    
    private func deletePhoto() async {
        isDeleting = true
        
        await MainActor.run {
            do {
                // Delete from SwiftData
                ctx.delete(photo)
                try ctx.save()
                print("✅ Photo deleted from database")
                
                // Delete the image file from app directory
                Task {
                    do {
                        try await PhotoStore.deleteFromAppDirectory(localId: photo.assetLocalId)
                        print("✅ Photo file deleted from app directory")
                    } catch {
                        print("⚠️ Warning: Could not delete photo file: \(error)")
                    }
                }
                
                isDeleting = false
                dismiss()
            } catch {
                print("❌ Error deleting photo: \(error)")
                errorMessage = "Failed to delete photo: \(error.localizedDescription)"
                showErrorAlert = true
                isDeleting = false
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
    
    enum CompareMode: String, CaseIterable {
        case parallel = "Parallel"
        case slider = "Slider"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if photos.count >= 2 {
                // Mode picker
                Picker("Mode", selection: $mode) {
                    ForEach(CompareMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                
                // Photo selectors
                HStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("Before")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Menu {
                            ForEach(photos) { photo in
                                Button(action: {
                                    left = photo
                                }) {
                                    Text(photo.date.formatted(date: .abbreviated, time: .omitted))
                                }
                            }
                        } label: {
                            if let left = left {
                                PhotoGridItem(photo: left)
                                    .frame(height: 80)
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 80)
                                    .overlay(
                                        Text("Select")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                    )
                            }
                        }
                    }
                    
                    VStack(spacing: 8) {
                        Text("After")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Menu {
                            ForEach(photos) { photo in
                                Button(action: {
                                    right = photo
                                }) {
                                    Text(photo.date.formatted(date: .abbreviated, time: .omitted))
                                }
                            }
                        } label: {
                            if let right = right {
                                PhotoGridItem(photo: right)
                                    .frame(height: 80)
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 80)
                                    .overlay(
                                        Text("Select")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                    )
                            }
                        }
                    }
                }
                
                // Compare view
                if let left = left, let right = right {
                    CompareCanvas(left: left, right: right, mode: mode == .parallel ? .parallel : .slider)
                        .frame(height: 300)
                        .glassCard()
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 300)
                        .overlay(
                            Text("Select two photos to compare")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.7))
                        )
                }
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 200)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.5))
                            Text("Add at least 2 photos to compare")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                    )
            }
        }
        .onAppear {
            // Auto-select first two photos if available
            if left == nil && right == nil && photos.count >= 2 {
                left = photos.first
                right = photos.count > 1 ? photos[1] : nil
            }
        }
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
    
    var body: some View {
        VStack(spacing: 16) {
            if !photos.isEmpty {
                // Main photo display
                if currentIndex < photos.count {
                    PhotoGridItem(photo: photos[currentIndex])
                        .frame(height: 300)
                        .glassCard()
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 300)
                }
                
                // Progress bar
                HStack(spacing: 12) {
                    Text("1")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Slider(value: Binding(
                        get: { Double(currentIndex) },
                        set: { currentIndex = Int($0) }
                    ), in: 0...Double(max(0, photos.count - 1)), step: 1)
                    .tint(.white)
                    
                    Text("\(photos.count)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Controls
                HStack(spacing: 20) {
                    Button(action: {
                        if currentIndex > 0 {
                            currentIndex -= 1
                        }
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .disabled(currentIndex == 0)
                    
                    Button(action: {
                        isPlaying.toggle()
                    }) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    Button(action: {
                        if currentIndex < photos.count - 1 {
                            currentIndex += 1
                        }
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .disabled(currentIndex >= photos.count - 1)
                }
                .padding()
                .glassCard()
                
                // Speed control
                VStack(spacing: 8) {
                    Text("Playback Speed: \(playbackSpeed, specifier: "%.1f")x")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Slider(value: $playbackSpeed, in: 0.5...3.0, step: 0.1)
                        .tint(.white)
                }
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 200)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "play.rectangle")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.5))
                            Text("Add photos to watch your progress")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                    )
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                startPlayback()
            }
        }
    }
    
    private func startPlayback() {
        guard isPlaying && !photos.isEmpty else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + (1.0 / playbackSpeed)) {
            if isPlaying {
                if currentIndex < photos.count - 1 {
                    currentIndex += 1
                    startPlayback()
                } else {
                    // Loop back to start
                    currentIndex = 0
                    startPlayback()
                }
            }
        }
    }
}
