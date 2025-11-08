import SwiftUI
import SwiftData
import Photos
import AVFoundation

// MARK: - Photo Edit Sheet
// MARK: - Photo Edit Sheet (Read-only view with action bar)
struct PhotoEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    
    let photo: ProgressPhoto
    let allPhotos: [ProgressPhoto]  // For navigation
    let onPhotoDeleted: ((ProgressPhoto) -> Void)?  // Callback when photo is deleted

    @State private var currentPhoto: ProgressPhoto
    @State private var image: UIImage?
    @State private var imageCache: [String: UIImage] = [:]  // Cache all loaded images
    @State private var isLoadingImages = false
    @State private var showNotesEditor = false
    @State private var showDatePicker = false
    @State private var showAdjustView = false
    @State private var showDeleteConfirmation = false
    @State private var notesText: String = ""
    @State private var selectedDate: Date = Date()
    
    init(photo: ProgressPhoto, allPhotos: [ProgressPhoto] = [], onPhotoDeleted: ((ProgressPhoto) -> Void)? = nil) {
        self.photo = photo
        self.allPhotos = allPhotos.isEmpty ? [photo] : allPhotos
        self.onPhotoDeleted = onPhotoDeleted
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
                    .padding(.bottom, AppStyle.Spacing.xl)

                    // Main image with 4:5 aspect ratio (already cropped to 4:5)
                    ZStack {
                        if let img = image {
                            // Image already has transform baked in, display at fixed aspect ratio
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(4.0/5.0, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, AppStyle.Spacing.md)
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        } else if isLoadingImages {
                            ProgressView()
                                .tint(AppStyle.Colors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(4/5, contentMode: .fit)
                        } else {
                            // Placeholder for when no image is available
                            Rectangle()
                                .fill(AppStyle.Colors.panel)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(4/5, contentMode: .fit)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(AppStyle.Colors.textTertiary)
                                )
                                .padding(.horizontal, AppStyle.Spacing.md)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: currentPhoto.id)
                    
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
            .task {
                // Pre-load all images when the sheet opens
                await preloadAllImages()
            }
            .onChange(of: currentPhoto) { _, newPhoto in
                // Switch to the cached image immediately
                switchToPhoto(newPhoto)
                notesText = newPhoto.notes ?? ""
                selectedDate = newPhoto.date
            }
            .onChange(of: showAdjustView) { _, isShowing in
                // Reload image when adjust sheet is dismissed to show updated transform
                if !isShowing {
                    // Invalidate cache only for the edited photo
                    PhotoStore.invalidateCache(for: currentPhoto.assetLocalId)
                    if currentPhoto.originalAssetLocalId != currentPhoto.assetLocalId {
                        PhotoStore.invalidateCache(for: currentPhoto.originalAssetLocalId)
                    }
                    image = nil
                    Task {
                        // Wait a moment for SwiftData to propagate changes
                        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                        await loadSingleImage(currentPhoto)
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
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "note.text")
                            .font(.system(size: AppStyle.IconSize.xl))
                        
                        // Notification badge when there's a note
                        if currentPhoto.notes != nil {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                                .offset(x: 8, y: -8)
                        }
                    }
                    Text("Notes")
                        .font(AppStyle.FontStyle.caption)
                }
                .foregroundColor(AppStyle.Colors.textPrimary)
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
                AppStyle.Colors.bgDark.opacity(0.95)
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
                        .tint(AppStyle.Colors.accentPrimary)
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
    private func preloadAllImages() async {
        guard !isLoadingImages else { return }
        
        await MainActor.run {
            isLoadingImages = true
        }
        
        // Load images in parallel for better performance
        await withTaskGroup(of: (String, UIImage?).self) { group in
            // Limit concurrent loads to prevent memory issues
            let photosToLoad = allPhotos.prefix(20)  // Load up to 20 photos
            
            for photo in photosToLoad {
                group.addTask {
                    // Always load from assetLocalId for display (it's already transformed)
                    if let displayImage = await PhotoStore.fetchUIImage(localId: photo.assetLocalId, targetSize: CGSize(width: 800, height: 1000)) {
                        // assetLocalId always contains the display-ready image
                        return (photo.id.uuidString, displayImage)
                    }
                    return (photo.id.uuidString, nil)
                }
            }
            
            // Collect results
            for await (photoId, img) in group {
                if let img = img {
                    await MainActor.run {
                        imageCache[photoId] = img
                    }
                }
            }
        }
        
        await MainActor.run {
            // Set the current image from cache
            if let cachedImage = imageCache[currentPhoto.id.uuidString] {
                image = cachedImage
            } else {
                // If not in cache, load it individually
                Task {
                    await loadSingleImage(currentPhoto)
                }
            }
            isLoadingImages = false
        }
    }
    
    private func loadSingleImage(_ photo: ProgressPhoto) async {
        // Always load from assetLocalId for display (it's already transformed)
        guard let displayImage = await PhotoStore.fetchUIImage(localId: photo.assetLocalId, targetSize: CGSize(width: 800, height: 1000)) else {
            return
        }
        
        // assetLocalId always contains the display-ready image
        // No transform needed - it was already applied when saved
        await MainActor.run {
            imageCache[photo.id.uuidString] = displayImage
            if photo.id == currentPhoto.id {
                image = displayImage
            }
        }
    }
    
    private func switchToPhoto(_ photo: ProgressPhoto) {
        // Check cache first
        if let cachedImage = imageCache[photo.id.uuidString] {
            withAnimation(.easeInOut(duration: 0.2)) {
                image = cachedImage
            }
        } else {
            // Load if not cached - keep previous image visible during load to avoid flicker
            Task {
                await loadSingleImage(photo)
            }
        }
    }
    
    /// Renders the final 4:5 cropped image with the transform applied
    @MainActor
    private func renderCroppedImage(from sourceImage: UIImage, transform: AlignTransform) -> UIImage {
        // Use centralized renderer for consistency
        return TransformRenderer.renderTransformedImage(
            sourceImage: sourceImage,
            transform: transform,
            targetSize: CGSize(width: sourceImage.size.width, height: sourceImage.size.width * 5.0 / 4.0)
        )
    }
    
    private func previousPhoto() {
        guard canGoPrevious else { return }
        currentPhoto = allPhotos[currentPhotoIndex - 1]
    }
    
    private func nextPhoto() {
        guard canGoNext else { return }
        currentPhoto = allPhotos[currentPhotoIndex + 1]
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
        let photoToDelete = currentPhoto
        if let journey = currentPhoto.journey {
            journey.photoCount = max(0, journey.photoCount - 1)  // Decrement cached count
        }
        ctx.delete(currentPhoto)
        try? ctx.save()

        // Delete both cropped and original photo files
        Task {
            try? await PhotoStore.deleteFromAppDirectory(localId: photoToDelete.assetLocalId)

            // Delete the original file if it's different from cropped
            if photoToDelete.originalAssetLocalId != photoToDelete.assetLocalId {
                try? await PhotoStore.deleteFromAppDirectory(localId: photoToDelete.originalAssetLocalId)
            }
        }

        // Notify parent view that photo was deleted
        onPhotoDeleted?(photoToDelete)

        dismiss()
    }
}
