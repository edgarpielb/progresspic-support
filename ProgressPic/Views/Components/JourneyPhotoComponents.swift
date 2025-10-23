import SwiftUI
import SwiftData

// MARK: - Journey Cover Thumbnail Components

// MARK: - Journey Photo Collage
struct JourneyPhotoCollage: View {
    let journey: Journey
    @Query private var photos: [ProgressPhoto]
    @State private var loadedImages: [UUID: UIImage] = [:]

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
        let photoCount = photos.count

        if photoCount == 0 {
            // Empty state - show camera icon
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    Image(systemName: "camera")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.3))
                )
                .frame(height: 200)
        } else if photoCount == 1 {
            // Single photo - full width
            singlePhotoView(photos[0])
        } else if photoCount == 2 {
            // Two photos - side by side
            HStack(spacing: 2) {
                photoTile(photos[0])
                photoTile(photos[1])
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        } else if photoCount <= 3 {
            // Three photos - one large left, two stacked right
            HStack(spacing: 2) {
                photoTile(photos[0])
                    .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    photoTile(photos[1])
                    photoTile(photos[2])
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        } else {
            // Four or more photos - 2x3 grid (like image 2)
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    photoTile(photos[0])
                    photoTile(photos[1])
                    photoTile(photos[2])
                }
                HStack(spacing: 2) {
                    photoTile(photos[min(3, photoCount - 1)])
                    photoTile(photos[min(4, photoCount - 1)])
                    if photoCount > 5 {
                        // Show count overlay on last tile
                        ZStack {
                            photoTile(photos[5])
                            if photoCount > 6 {
                                Rectangle()
                                    .fill(Color.black.opacity(0.6))
                                VStack {
                                    Spacer()
                                    Text("+\(photoCount - 6)")
                                        .font(.title.bold())
                                        .foregroundColor(.white)
                                    Spacer()
                                    Spacer()
                                    Spacer()
                                }
                            }
                        }
                    } else {
                        photoTile(photos[min(5, photoCount - 1)])
                    }
                }
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    @ViewBuilder
    private func singlePhotoView(_ photo: ProgressPhoto) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.06))

            if let image = loadedImages[photo.id] {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
                    .tint(.white.opacity(0.5))
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .task {
            if loadedImages[photo.id] == nil {
                // Always load from assetLocalId for display (it's already transformed)
                if let img = await PhotoStore.fetchUIImage(
                    localId: photo.assetLocalId,
                    targetSize: CGSize(width: 400, height: 500)
                ) {
                    // assetLocalId always contains the display-ready image
                    loadedImages[photo.id] = img
                }
            }
        }
    }

    @ViewBuilder
    private func photoTile(_ photo: ProgressPhoto) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.06))

            if let image = loadedImages[photo.id] {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
                    .tint(.white.opacity(0.5))
                    .scaleEffect(0.6)
            }
        }
        .clipped()
        .task {
            if loadedImages[photo.id] == nil {
                // Always load from assetLocalId for display (it's already transformed)
                if let img = await PhotoStore.fetchUIImage(
                    localId: photo.assetLocalId,
                    targetSize: CGSize(width: 200, height: 250)
                ) {
                    // assetLocalId always contains the display-ready image
                    loadedImages[photo.id] = img
                }
            }
        }
    }
    
    // Removed - now using TransformRenderer.renderTransformedImage
}

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
            // Load the most recent photo with smaller size for cover thumbnails
            if let latestPhoto = photos.first {
                await loadCoverImage(latestPhoto)
            }
        }
        .onChange(of: photos.count) { _, _ in
            // Reload when photos change
            Task {
                if let latestPhoto = photos.first {
                    await loadCoverImage(latestPhoto)
                } else {
                    img = nil
                }
            }
        }
        .onDisappear {
            // Clear image when view disappears to free memory
            img = nil
        }
    }
    
    private func loadCoverImage(_ photo: ProgressPhoto) async {
        // Always load from assetLocalId for display (it's already transformed)
        if let loadedImg = await PhotoStore.fetchUIImage(localId: photo.assetLocalId, targetSize: CGSize(width: 120, height: 120)) {
            // assetLocalId always contains the display-ready image
            img = loadedImg
        }
    }
    
    // Removed - now using TransformRenderer.renderThumbnail
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
                img = await PhotoStore.fetchUIImage(localId: id, targetSize: CGSize(width: 120, height: 120))
            }
        }
        .onDisappear {
            // Clear image when view disappears to free memory
            img = nil
        }
    }
}

// MARK: - Photo Grid Item

struct PhotoGridItem: View {
    let photo: ProgressPhoto
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var loadFailed = false
    @State private var loadTask: Task<Void, Never>?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                if let img = image {
                    let itemHeight = geometry.size.width * 5.0/4.0 // 4:5 ratio height
                    
                    // Image is already transformed in loadImage()
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(4.0/5.0, contentMode: .fill)
                        .frame(width: geometry.size.width, height: itemHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    // Only show background when no image is loaded
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                }
                
                if loadFailed && image == nil {
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
                } else if isLoading && image == nil {
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
        .task(id: photo.assetLocalId) {
            // Reload when assetLocalId changes (e.g., after recropping)
            await loadImage()
        }
        .onChange(of: photo.alignTransform) { _, _ in
            // Clear cached image and reload when transform changes
            image = nil
            Task {
                await loadImage()
            }
        }
        .onDisappear {
            // Cancel load task if view disappears before loading completes
            loadTask?.cancel()
            // Don't clear image - let PhotoStore cache handle memory management
            // Clearing here causes unnecessary reloading when navigating between photos
        }
    }
    
    private func loadImage() async {
        // Note: We allow reloading when image is nil to handle transform changes

        // Cancel any previous load task
        loadTask?.cancel()

        loadTask = Task {
            loadFailed = false

            // Use higher quality thumbnails for better grid display
            // Since we're already storing 1200x1500 cropped images, use them directly
            let targetSize = CGSize(width: 600, height: 750)

            guard !Task.isCancelled else { return }

            // Only show loading if this takes longer than 50ms (cache misses)
            let loadingTask = Task {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                if !Task.isCancelled {
                    await MainActor.run {
                        isLoading = true
                    }
                }
            }

            // Always load from assetLocalId for display (it's already transformed)
            if let loadedImage = await PhotoStore.fetchUIImage(localId: photo.assetLocalId, targetSize: targetSize) {
                loadingTask.cancel()
                guard !Task.isCancelled else { return }
                
                // assetLocalId always contains the display-ready image
                // No transform needed - it was already applied when saved
                await MainActor.run {
                    self.image = loadedImage
                    self.isLoading = false
                }
            } else {
                // If load failed, mark as failed for retry
                loadingTask.cancel()
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.loadFailed = true
                    self.isLoading = false
                }
            }
        }
    }
    
    // Removed - now using TransformRenderer.renderThumbnail
}

