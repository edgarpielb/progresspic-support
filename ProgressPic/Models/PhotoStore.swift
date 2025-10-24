import SwiftUI
import Photos
import PhotosUI
import ImageIO

// MARK: - PhotoStore (Local file storage)
enum PhotoStore {
    /// Memory cache for loaded images to avoid repeated decoding
    /// Automatically evicts under memory pressure
    private static let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        // Limit cache to prevent unbounded memory growth
        cache.countLimit = AppConstants.Cache.imageCountLimit
        cache.totalCostLimit = AppConstants.Cache.imageSizeLimit
        return cache
    }()
    
    /// Generate a cache key from localId and optional target size
    private static func cacheKey(for localId: String, targetSize: CGSize?) -> String {
        if let size = targetSize {
            return "\(localId)_\(Int(size.width))x\(Int(size.height))"
        }
        return "\(localId)_full"
    }
    
    /// Clear the image cache (useful for memory warnings or testing)
    static func clearCache() {
        imageCache.removeAllObjects()
        print("🗑️ Cleared image cache")
    }
    
    static func requestAuthorization() async -> Bool {
        // Still needed for importing existing photos from photo library
        await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization { status in
                cont.resume(returning: status == .authorized || status == .limited)
            }
        }
    }
    
    /// Crop image to 4:5 aspect ratio (1200x1500 optimized)
    /// This ensures consistent cropping across all photos in the app
    /// Using smaller dimensions to reduce memory usage while maintaining quality
    static func cropTo4x5(_ image: UIImage) -> UIImage {
        let outW = AppConstants.Photo.exportWidth
        let outH = AppConstants.Photo.exportHeight
        let canvas = CGSize(width: outW, height: outH)

        // Calculate scale to fill the canvas (use max to ensure crop fills the frame)
        let baseScale = max(outW / image.size.width, outH / image.size.height)

        let renderer = UIGraphicsImageRenderer(size: canvas)
        return renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvas))

            // Center the image
            ctx.cgContext.translateBy(x: outW/2, y: outH/2)
            ctx.cgContext.scaleBy(x: baseScale, y: baseScale)

            let drawRect = CGRect(
                x: -image.size.width/2,
                y: -image.size.height/2,
                width: image.size.width,
                height: image.size.height
            )
            image.draw(in: drawRect)
        }
    }

    static func saveToAppDirectory(_ image: UIImage) async throws -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let photosDirectory = documentsPath.appendingPathComponent("Photos")

        // Create Photos directory if it doesn't exist
        try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true, attributes: nil)

        // Generate unique filename
        let filename = UUID().uuidString + ".jpg"
        let fileURL = photosDirectory.appendingPathComponent(filename)

        // Save image as JPEG
        guard let jpegData = image.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "PhotoStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not convert image to JPEG"])
        }

        try jpegData.write(to: fileURL)
        return filename // Return just the filename, not the full path
    }

    static func saveToLibrary(_ image: UIImage) async throws -> String {
        // Redirect to app directory storage instead of photo library
        return try await saveToAppDirectory(image)
    }
    
    static func saveToAppDirectoryAndLibrary(_ image: UIImage, saveToCameraRoll: Bool) async throws -> String {
        // Always save to app directory
        let filename = try await saveToAppDirectory(image)
        
        // Optionally save to photo library if setting is enabled
        if saveToCameraRoll {
            try await saveToPhotoLibrary(image)
        }
        
        return filename
    }
    
    private static func saveToPhotoLibrary(_ image: UIImage) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
    
    static func deleteFromAppDirectory(localId: String) async throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let photosDirectory = documentsPath.appendingPathComponent("Photos")
        let fileURL = photosDirectory.appendingPathComponent(localId)
        
        // Remove from cache
        imageCache.removeObject(forKey: localId as NSString)
        
        // Delete the file
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
            print("🗑️ Deleted photo file: \(localId)")
        } else {
            print("⚠️ Photo file not found: \(localId)")
        }
    }

    static func fetchUIImage(localId: String, targetSize: CGSize? = nil) async -> UIImage? {
        // Check cache first
        let key = cacheKey(for: localId, targetSize: targetSize)
        if let cachedImage = imageCache.object(forKey: key as NSString) {
            print("✅ Cache hit for: \(localId) (\(targetSize != nil ? "\(Int(targetSize!.width))x\(Int(targetSize!.height))" : "full"))")
            return cachedImage
        }
        
        // First try to load from app directory (new method)
        if let image = loadFromAppDirectory(filename: localId, targetSize: targetSize) {
            // Cache the loaded image
            imageCache.setObject(image, forKey: key as NSString)
            print("💾 Cached image: \(localId) (\(targetSize != nil ? "\(Int(targetSize!.width))x\(Int(targetSize!.height))" : "full"))")
            return image
        }
        
        // Fallback: try to load from photo library (for existing photos)
        if let image = await loadFromPhotoLibrary(localId: localId, targetSize: targetSize) {
            // Cache the loaded image
            imageCache.setObject(image, forKey: key as NSString)
            print("💾 Cached image from library: \(localId)")
            return image
        }
        
        return nil
    }
    
    static func loadFromAppDirectory(filename: String, targetSize: CGSize? = nil) -> UIImage? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let photosDirectory = documentsPath.appendingPathComponent("Photos")
        let fileURL = photosDirectory.appendingPathComponent(filename)
        
        // If no target size, load normally (for editing, etc.)
        guard let targetSize = targetSize else {
            return UIImage(contentsOfFile: fileURL.path)
        }
        
        // Use CGImageSource for efficient downsampling
        // This decodes only the pixels we need, avoiding memory spikes
        return downsampleImage(at: fileURL, to: targetSize)
    }
    
    /// Efficiently downsample an image using CGImageSource
    /// This avoids loading the full image into memory, preventing memory spikes
    private static func downsampleImage(at imageURL: URL, to targetSize: CGSize) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, imageSourceOptions) else {
            print("⚠️ Failed to create image source for: \(imageURL.lastPathComponent)")
            return nil
        }
        
        // Calculate the maximum dimension
        let maxDimensionInPixels = max(targetSize.width, targetSize.height)
        
        // Create thumbnail options
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary
        
        // Generate the thumbnail
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            print("⚠️ Failed to create thumbnail for: \(imageURL.lastPathComponent)")
            // Fallback to standard loading
            return UIImage(contentsOfFile: imageURL.path)
        }
        
        return UIImage(cgImage: downsampledImage)
    }
    
    static func loadFromPhotoLibrary(localId: String, targetSize: CGSize? = nil) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil).firstObject else { return nil }
        
        return await withTaskGroup(of: UIImage?.self) { group in
            group.addTask {
                await withCheckedContinuation { cont in
                    let manager = PHCachingImageManager.default()
                    let size = targetSize ?? CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
                    
                    // Configure options to ensure single callback
                    let options = PHImageRequestOptions()
                    options.deliveryMode = .highQualityFormat
                    options.isNetworkAccessAllowed = true
                    options.isSynchronous = false
                    
                    var hasResumed = false
                    
                    let requestID = manager.requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: options) { img, info in
                        // Ensure we only resume once
                        guard !hasResumed else { return }
                        
                        // Check if this is the final result
                        let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                        let isInCloud = info?[PHImageResultIsInCloudKey] as? Bool ?? false
                        let isCancelled = info?[PHImageCancelledKey] as? Bool ?? false
                        let hasError = info?[PHImageErrorKey] != nil
                        
                        if isCancelled || hasError {
                            hasResumed = true
                            cont.resume(returning: nil)
                            return
                        }
                        
                        // Only resume for high quality, non-degraded results
                        if !isDegraded && !isInCloud {
                            hasResumed = true
                            cont.resume(returning: img)
                        } else if img != nil && !isInCloud && !isDegraded {
                            // Accept non-cloud, non-degraded images
                            hasResumed = true
                            cont.resume(returning: img)
                        } else if img != nil && !hasResumed {
                            // Last resort: accept any image we get after some delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                if !hasResumed {
                                    hasResumed = true
                                    cont.resume(returning: img)
                                }
                            }
                        }
                    }
                    
                    // Set a timeout to prevent hanging
                    Task {
                        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                        if !hasResumed {
                            manager.cancelImageRequest(requestID)
                            hasResumed = true
                            cont.resume(returning: nil)
                        }
                    }
                }
            }
            
            // Return the first (and only) result
            for await result in group {
                return result
            }
            return nil
        }
    }

    static func creationDate(for localId: String) -> Date? {
        // First try to get creation date from local file
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let photosDirectory = documentsPath.appendingPathComponent("Photos")
        let fileURL = photosDirectory.appendingPathComponent(localId)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                return attributes[.creationDate] as? Date
            } catch {
                print("Error getting file creation date: \(error)")
            }
        }
        
        // Fallback to photo library for existing photos
        return PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil).firstObject?.creationDate
    }

    /// Extract the original EXIF creation date from a PHAsset
    /// This returns the actual date the photo was taken, not the import date
    static func getEXIFCreationDate(from asset: PHAsset) async -> Date? {
        return await withCheckedContinuation { continuation in
            // Try two methods: first PHImageManager for image data, then fallback to PHContentEditingInput
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat

            manager.requestImageDataAndOrientation(for: asset, options: options) { imageData, _, _, _ in
                // Try to extract EXIF from image data
                if let data = imageData,
                   let date = extractEXIFDate(from: data) {
                    print("✅ Successfully extracted EXIF date: \(date)")
                    continuation.resume(returning: date)
                    return
                }

                // Fallback: Try using PHContentEditingInput
                let editingOptions = PHContentEditingInputRequestOptions()
                editingOptions.isNetworkAccessAllowed = true

                asset.requestContentEditingInput(with: editingOptions) { input, _ in
                    if let url = input?.fullSizeImageURL,
                       let data = try? Data(contentsOf: url),
                       let date = extractEXIFDate(from: data) {
                        print("✅ Successfully extracted EXIF date from editing input: \(date)")
                        continuation.resume(returning: date)
                        return
                    }

                    // Final fallback: use PHAsset creationDate
                    print("⚠️ Could not extract EXIF date, using PHAsset.creationDate")
                    continuation.resume(returning: asset.creationDate)
                }
            }
        }
    }

    /// Helper function to extract EXIF date from image data
    static func extractEXIFDate(from imageData: Data) -> Date? {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return nil
        }

        // Try EXIF dictionary first (most reliable for camera photos)
        if let exifDict = imageProperties[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let dateString = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String,
           let date = parseEXIFDateString(dateString) {
            return date
        }

        // Fallback: Try TIFF dictionary (some photos store date here)
        if let tiffDict = imageProperties[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
           let dateString = tiffDict[kCGImagePropertyTIFFDateTime as String] as? String,
           let date = parseEXIFDateString(dateString) {
            return date
        }

        // Fallback: Try GPS dictionary for timestamp
        if let gpsDict = imageProperties[kCGImagePropertyGPSDictionary as String] as? [String: Any],
           let dateString = gpsDict[kCGImagePropertyGPSDateStamp as String] as? String,
           let timeString = gpsDict[kCGImagePropertyGPSTimeStamp as String] as? String,
           let date = parseGPSDateTime(dateString: dateString, timeString: timeString) {
            return date
        }

        return nil
    }

    /// Parse EXIF date string format: "yyyy:MM:dd HH:mm:ss"
    private static func parseEXIFDateString(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter.date(from: dateString)
    }

    /// Parse GPS date and time
    private static func parseGPSDateTime(dateString: String, timeString: String) -> Date? {
        let combinedString = "\(dateString) \(timeString)"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // GPS time is UTC
        return formatter.date(from: combinedString)
    }

    /// Extract EXIF date directly from UIImage
    /// This is a fallback when PHAsset is not available
    static func extractDateFromUIImage(_ image: UIImage) -> Date? {
        // Try to get image data from the UIImage
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            print("⚠️ Could not convert UIImage to JPEG data")
            return nil
        }

        return extractEXIFDate(from: imageData)
    }
}

