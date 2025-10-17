import SwiftUI
import SwiftData

// MARK: - Journey Cover Thumbnail Components

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
                img = await PhotoStore.fetchUIImage(localId: latestPhoto.assetLocalId, targetSize: CGSize(width: 120, height: 120))
            }
        }
        .onChange(of: photos.count) { _, _ in
            // Reload when photos change
            Task {
                if let latestPhoto = photos.first {
                    img = await PhotoStore.fetchUIImage(localId: latestPhoto.assetLocalId, targetSize: CGSize(width: 120, height: 120))
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
        .task(id: photo.assetLocalId) {
            // Reload when assetLocalId changes (e.g., after recropping)
            await loadImage()
        }
        .onDisappear {
            // Cancel load task if view disappears before loading completes
            loadTask?.cancel()
            // Clear image when view disappears to free memory
            image = nil
        }
    }
    
    private func loadImage() async {
        // Cancel any previous load task
        loadTask?.cancel()

        loadTask = Task {
            isLoading = true
            loadFailed = false

            // Use higher quality thumbnails for better grid display
            // Since we're already storing 1200x1500 cropped images, use them directly
            let targetSize = CGSize(width: 600, height: 750)

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

