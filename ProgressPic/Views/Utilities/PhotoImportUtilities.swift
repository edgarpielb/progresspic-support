import SwiftUI
import SwiftData
import Photos
import PhotosUI
import UniformTypeIdentifiers

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
        // IMPORTANT: Use PHPhotoLibrary.shared() to get assetIdentifier from results
        var config = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        config.filter = .images
        config.selectionLimit = 0 // Allow multiple selection
        config.selection = .ordered

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator

        // Force dark mode to ensure proper contrast (white checkmark on dark background)
        picker.overrideUserInterfaceStyle = .dark

        // Set the tint color for the selection checkmarks
        picker.view.tintColor = UIColor.systemBlue // Use system blue for better visibility

        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // No need to update anything here since we set everything in makeUIViewController
    }
    
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

                let assetIdentifier = result.assetIdentifier

                // Load image data to preserve EXIF metadata
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    result.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                        guard let imageData = data, error == nil else {
                            group.leave()
                            return
                        }

                        // Extract EXIF date from the data
                        let exifDate = PhotoStore.extractEXIFDate(from: imageData)

                        // Convert data to UIImage
                        guard let image = UIImage(data: imageData) else {
                            group.leave()
                            return
                        }

                        DispatchQueue.main.async {
                            newImages.append(image)

                            let photoData = SelectedPhotoData(
                                image: image,
                                assetIdentifier: assetIdentifier,
                                creationDate: exifDate
                            )
                            newPhotoData.append(photoData)
                            group.leave()
                        }
                    }
                } else {
                    group.leave()
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
                AppStyle.Colors.bgDark.ignoresSafeArea()
                
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
                        AppStyle.Colors.bgDark.opacity(0.8).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(.white)
                            Text("Importing Photos...")
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(
                            ZStack {
                                AppStyle.Colors.bgDark.opacity(0.9)
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
                            .foregroundColor(AppStyle.Colors.accentPrimary)
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

                    // For imported photos, first save the original
                    let originalId = try await PhotoStore.saveToAppDirectory(photoData.image)

                    // Use the EXIF date that was extracted during photo selection
                    // If no EXIF date was found, fall back to current date
                    if let exifDate = photoData.creationDate {
                        date = exifDate
                        print("📅 Import Photo \(index + 1): Using extracted EXIF date: \(date)")
                    } else {
                        print("⚠️ Import Photo \(index + 1): No creationDate in photoData")
                        // Last resort: try to extract from PHAsset if available
                        if let assetId = photoData.assetIdentifier {
                            print("🔍 Import Photo \(index + 1): Trying PHAsset fallback with ID: \(assetId)")
                            if let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil).firstObject {
                                date = await PhotoStore.getEXIFCreationDate(from: asset) ?? Date()
                                print("📅 Import Photo \(index + 1): Extracted from PHAsset: \(date)")
                            } else {
                                print("❌ Import Photo \(index + 1): Could not fetch PHAsset")
                                date = Date()
                            }
                        } else {
                            print("⚠️ Import Photo \(index + 1): No asset identifier, using current date")
                            date = Date()
                        }
                    }

                    print("💾 Import Photo \(index + 1)/\(selectedPhotoData.count): Saving with date \(date)")
                    
                    // Calculate initial transform to fill 4:5 aspect ratio
                    let initialTransform = calculateInitialTransform(for: photoData.image.size)
                    
                    // Render the cropped display version with the transform applied
                    let croppedImage = TransformRenderer.renderTransformedImage(
                        sourceImage: photoData.image,
                        transform: initialTransform,
                        targetSize: CGSize(width: AppConstants.Photo.exportWidth, height: AppConstants.Photo.exportHeight)
                    )
                    
                    // Save the cropped version as the display image
                    localId = try await PhotoStore.saveToAppDirectory(croppedImage)
                    
                    // Create progress photo entry with both original and cropped versions
                    let progressPhoto = ProgressPhoto(
                        journeyId: journey.id,
                        date: date,
                        assetLocalId: localId,  // Cropped display version
                        isFrontCamera: false, // Assume imported photos are not selfies
                        alignTransform: initialTransform,
                        originalAssetLocalId: originalId  // Keep original for re-editing
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
    
    /// Calculate initial transform to automatically fill 4:5 aspect ratio
    private func calculateInitialTransform(for imageSize: CGSize) -> AlignTransform {
        let imageAspect = imageSize.width / imageSize.height
        let targetAspect: CGFloat = 4.0 / 5.0  // 4:5 crop ratio
        
        // Calculate scale needed to fill the 4:5 frame
        let fillScale: CGFloat
        if imageAspect > targetAspect {
            // Image is wider than 4:5 - scale by height to fill
            fillScale = imageAspect / targetAspect
        } else {
            // Image is taller than 4:5 - scale by width to fill
            fillScale = targetAspect / imageAspect
        }
        
        // Return transform with calculated scale to auto-crop to 4:5
        return AlignTransform(
            scale: fillScale,
            offsetX: 0,
            offsetY: 0,
            rotation: 0
        )
    }
}

