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
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
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
                    // Clear cache and reload to show updated transform
                    imageCache.removeValue(forKey: currentPhoto.id.uuidString)
                    image = nil
                    Task {
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
                    // Load original if available, otherwise use the stored image
                    let imageId = photo.originalAssetLocalId ?? photo.assetLocalId
                    if let baseImage = await PhotoStore.fetchUIImage(localId: imageId, targetSize: CGSize(width: 800, height: 1000)) {
                        let displayImage = await self.renderCroppedImage(from: baseImage, transform: photo.alignTransform)
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
        // Load original if available, otherwise use the stored image
        let imageId = photo.originalAssetLocalId ?? photo.assetLocalId
        guard let baseImage = await PhotoStore.fetchUIImage(localId: imageId, targetSize: CGSize(width: 800, height: 1000)) else {
            return
        }
        
        // Apply the saved transform to show the image as the user edited it
        let displayImage = renderCroppedImage(from: baseImage, transform: photo.alignTransform)
        
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
        ctx.delete(currentPhoto)
        try? ctx.save()

        // Delete file
        Task {
            try? await PhotoStore.deleteFromAppDirectory(localId: photoToDelete.assetLocalId)
        }

        // Notify parent view that photo was deleted
        onPhotoDeleted?(photoToDelete)

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
    @State private var lastRotation: Angle = .zero
    @State private var isSaving = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var minScale: CGFloat = 1
    @State private var hasCalculatedInitialScale = false
    @State private var showRotationControls = false
    
    // Ghost overlay
    @State private var ghostImage: UIImage?
    @State private var showGhost = false
    @State private var ghostOpacity: Double = 0.5
    @State private var allPhotosInJourney: [ProgressPhoto] = []
    @State private var useLastAsGhost = false  // false = first, true = last

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 30/255, green: 32/255, blue: 35/255).ignoresSafeArea()

                if let img = image {
                    GeometryReader { geo in
                        let cropW = geo.size.width
                        let cropH = cropW * 5/4
                        
                        ZStack {
                            // Single transformed image for entire view
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .scaleEffect(scale)
                                .offset(offset)
                                .rotationEffect(rotation)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .opacity(showGhost ? (1 - ghostOpacity) : 1)
                                .overlay(
                                    // Dimming overlay everywhere EXCEPT the crop area
                                    Rectangle()
                                        .fill(Color.black.opacity(0.7))
                                        .frame(width: geo.size.width, height: geo.size.height)
                                        .mask(
                                            ZStack {
                                                Rectangle()
                                                    .fill(Color.white)
                                                Rectangle()
                                                    .fill(Color.black)
                                                    .frame(width: cropW, height: cropH)
                                                    .position(x: geo.size.width/2, y: geo.size.height/2)
                                                    .blendMode(.destinationOut)
                                            }
                                            .compositingGroup()
                                        )
                                        .allowsHitTesting(false)
                                )
                                
                            // Ghost overlay (if enabled)
                            if showGhost, let ghost = ghostImage {
                                Image(uiImage: ghost)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .opacity(ghostOpacity)
                                    .allowsHitTesting(false)
                            }
                            
                            // Border on crop area
                            Rectangle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                .frame(width: cropW, height: cropH)
                                .position(x: geo.size.width/2, y: geo.size.height/2)
                                .allowsHitTesting(false)
                        }
                        .contentShape(Rectangle())
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
                        .simultaneousGesture(
                            RotationGesture()
                                .onChanged { value in
                                    rotation = lastRotation + value
                                }
                                .onEnded { _ in
                                    lastRotation = rotation
                                }
                        )
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
                                .progressViewStyle(CircularProgressViewStyle(tint: AppStyle.Colors.accentPrimary))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark")
                                .foregroundColor((image == nil) ? .gray : AppStyle.Colors.accentPrimary)
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
                VStack(spacing: 0) {
                    Spacer().frame(height: 12)
                    
                    // Rotation controls
                    HStack(spacing: 20) {
                        // Rotation toggle button
                        Button(action: { 
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showRotationControls.toggle()
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "rotate.left")
                                Text("Rotate")
                                    .font(.subheadline.weight(.medium))
                            }
                            .foregroundColor(showRotationControls ? AppStyle.Colors.accentPrimary : .white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        // Reset button
                        Button(action: resetTransform) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset")
                                    .font(.subheadline.weight(.medium))
                            }
                            .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    // Rotation controls
                    if showRotationControls {
                        Spacer().frame(height: 8)
                        VStack(spacing: 12) {
                            // Rotation slider
                            HStack {
                                Image(systemName: "rotate.left")
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 20)
                                
                                Slider(value: Binding(
                                    get: { rotation.degrees },
                                    set: { newValue in 
                                        rotation = .degrees(newValue)
                                        lastRotation = rotation
                                    }
                                ), in: -45...45, step: 1)
                                .tint(AppStyle.Colors.accentPrimary)
                                
                                Text("\(Int(rotation.degrees))°")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 45, alignment: .trailing)
                            }
                        }
                    }
                    
                    // Ghost Overlay controls
                    if ghostImage != nil || allPhotosInJourney.count > 1 {
                        Spacer().frame(height: 12)
                        
                        HStack(spacing: 16) {
                            Button(action: { 
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showGhost.toggle()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: showGhost ? "eye.fill" : "eye.slash.fill")
                                    Text("Ghost Overlay")
                                        .font(.subheadline.weight(.medium))
                                }
                                .foregroundColor(showGhost ? AppStyle.Colors.accentPrimary : .white.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            // Ghost source selector
                            if allPhotosInJourney.count > 1 {
                                HStack(spacing: 8) {
                                    Text("Use:")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                    
                                    Button(action: {
                                        if useLastAsGhost {
                                            useLastAsGhost = false
                                            Task { await loadGhostImage() }
                                        }
                                    }) {
                                        Text("First")
                                            .font(.caption.weight(.medium))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(!useLastAsGhost ? AppStyle.Colors.accentPrimary.opacity(0.3) : Color.white.opacity(0.1))
                                            )
                                            .foregroundColor(!useLastAsGhost ? AppStyle.Colors.accentPrimary : .white.opacity(0.7))
                                    }
                                    
                                    Button(action: {
                                        if !useLastAsGhost {
                                            useLastAsGhost = true
                                            Task { await loadGhostImage() }
                                        }
                                    }) {
                                        Text("Last")
                                            .font(.caption.weight(.medium))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(useLastAsGhost ? AppStyle.Colors.accentPrimary.opacity(0.3) : Color.white.opacity(0.1))
                                            )
                                            .foregroundColor(useLastAsGhost ? AppStyle.Colors.accentPrimary : .white.opacity(0.7))
                                    }
                                }
                            }
                        }
                        
                        // Slider
                        if showGhost {
                            HStack {
                                Image(systemName: "circle.lefthalf.filled")
                                    .foregroundColor(.white.opacity(0.7))
                                Slider(value: $ghostOpacity, in: 0...1)
                                    .tint(AppStyle.Colors.accentPrimary)
                                Text("\(Int(ghostOpacity * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 40)
                            }
                        }
                    }
                }
                .padding(.horizontal)
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
        // Load the original uncropped image if available, otherwise use the cropped version
        let imageId = photo.originalAssetLocalId ?? photo.assetLocalId
        image = await PhotoStore.fetchUIImage(localId: imageId, targetSize: nil)
        print("📸 Loaded \(photo.originalAssetLocalId != nil ? "original" : "cropped") image for adjustment")

        // Apply saved transform if it exists
        await MainActor.run {
            let transform = photo.alignTransform
            // Always load saved transform, even if it's identity
            scale = transform.scale > 0 ? transform.scale : 1
            lastScale = scale
            offset = CGSize(width: transform.offsetX, height: transform.offsetY)
            lastOffset = offset
            rotation = Angle(radians: transform.rotation)
            lastRotation = rotation
            
            // If we have a saved transform, mark that we've calculated initial scale
            if transform.scale > 0 {
                hasCalculatedInitialScale = true
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
            
            // Select ghost photo based on user preference
            let ghostPhoto: ProgressPhoto?
            if useLastAsGhost {
                // Find the last (most recent) photo in the journey that isn't the current one
                let otherPhotos = photosInJourney.filter { $0.id != photo.id }
                ghostPhoto = otherPhotos.last  // Last in sorted array = most recent
                
                if ghostPhoto == nil {
                    print("👻 No other photos available for ghost overlay")
                    await MainActor.run { ghostImage = nil }
                    return
                }
                print("👻 Loading ghost image from last photo in journey...")
            } else {
                // Load the first photo in the journey (if not current)
                let otherPhotos = photosInJourney.filter { $0.id != photo.id }
                ghostPhoto = otherPhotos.first
                
                if ghostPhoto == nil {
                    print("👻 No other photos available for ghost overlay") 
                    await MainActor.run { ghostImage = nil }
                    return
                }
                print("👻 Loading ghost image from first photo...")
            }
            
            guard let selectedGhostPhoto = ghostPhoto else { return }
            
            if let loadedGhost = await PhotoStore.fetchUIImage(localId: selectedGhostPhoto.assetLocalId, targetSize: nil) {
                await MainActor.run {
                    // Render the ghost with its transform as a 4:5 cropped image (same as main display)
                    let croppedGhost = renderCroppedGhostImage(from: loadedGhost, transform: selectedGhostPhoto.alignTransform)
                    self.ghostImage = croppedGhost
                    print("👻 Ghost image loaded and cropped successfully")
                }
            } else {
                print("❌ Failed to load ghost image")
                await MainActor.run { ghostImage = nil }
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
    
    private func resetTransform() {
        withAnimation(.easeInOut(duration: 0.3)) {
            // Reset to initial fill scale
            if let img = image {
                let geo = UIScreen.main.bounds
                let cropW = geo.width
                let cropH = cropW * 5/4
                calculateInitialScale(imageSize: img.size, cropSize: CGSize(width: cropW, height: cropH))
                scale = minScale
                lastScale = minScale
            }
            offset = .zero
            lastOffset = .zero
            rotation = .zero
            lastRotation = .zero
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

        await MainActor.run {
            // Simply save the transform without creating a new image
            // This keeps the original image and applies the transform on display
            photo.alignTransform = AlignTransform(
                scale: scale,
                offsetX: offset.width,
                offsetY: offset.height,
                rotation: rotation.radians
            )
            
            do {
                try ctx.save()
                print("✅ Transform saved successfully")
                print("📐 Saved transform: scale=\(scale), offset=(\(offset.width), \(offset.height)), rotation=\(rotation.radians)")
                isSaving = false
                dismiss()
            } catch {
                print("❌ Error saving transform: \(error)")
                errorMessage = "Failed to save edits: \(error.localizedDescription)"
                showErrorAlert = true
                isSaving = false
            }
        }
    }

    private func renderCroppedImage(from sourceImage: UIImage) -> UIImage {
        let outW: CGFloat = 1200   // 4:5 canvas (optimized for memory)
        let outH: CGFloat = 1500
        let canvas = CGSize(width: outW, height: outH)

        let baseScale = min(outW / sourceImage.size.width, outH / sourceImage.size.height)
        let finalScale = baseScale * max(scale, 0.001)

        let renderer = UIGraphicsImageRenderer(size: canvas)
        return renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvas))

            ctx.cgContext.translateBy(x: outW/2 + offset.width * baseScale, y: outH/2 + offset.height * baseScale)
            ctx.cgContext.rotate(by: rotation.radians)
            ctx.cgContext.scaleBy(x: finalScale, y: finalScale)

            let drawRect = CGRect(
                x: -sourceImage.size.width/2,
                y: -sourceImage.size.height/2,
                width: sourceImage.size.width,
                height: sourceImage.size.height
            )
            sourceImage.draw(in: drawRect)
        }
    }
}
