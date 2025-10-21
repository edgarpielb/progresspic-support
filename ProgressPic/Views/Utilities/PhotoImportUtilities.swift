import SwiftUI
import SwiftData
import Photos
import PhotosUI

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
                        
                        // Store asset identifier for later EXIF date extraction
                        // We'll extract the actual EXIF date when saving, not the import date
                        var creationDate: Date?
                        if assetIdentifier != nil {
                            // Just store nil for now - we'll get EXIF date during save
                            creationDate = nil
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
                            .foregroundColor(.pink)
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

                    // Get EXIF creation date if asset identifier is available
                    if let assetId = photoData.assetIdentifier,
                       let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil).firstObject {
                        date = await PhotoStore.getEXIFCreationDate(from: asset) ?? Date()
                        print("📅 Extracted EXIF date: \(date) for photo \(index + 1)")
                    } else {
                        date = photoData.creationDate ?? Date()
                    }

                    print("💾 Copied imported photo \(index + 1)/\(selectedPhotoData.count) to app directory")
                    
                    // Calculate initial transform to fill 4:5 aspect ratio
                    let initialTransform = calculateInitialTransform(for: photoData.image.size)
                    
                    // Create progress photo entry
                    let progressPhoto = ProgressPhoto(
                        journeyId: journey.id,
                        date: date,
                        assetLocalId: localId,
                        isFrontCamera: false, // Assume imported photos are not selfies
                        alignTransform: initialTransform
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

