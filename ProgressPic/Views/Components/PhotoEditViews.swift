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
                    // Clear cache and reload to show updated transform
                    imageCache.removeAll() // Clear ALL cached images to force reload
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
    @State private var showScaleControls = false

    // Ghost overlay
    @State private var ghostImage: UIImage?
    @State private var showGhost = false
    @State private var ghostOpacity: Double = 0.5
    @State private var allPhotosInJourney: [ProgressPhoto] = []
    @State private var useLastAsGhost = false  // false = first, true = last

    // Grid overlay
    @State private var showGrid = false
    
    // Track the actual crop size used during adjustment
    @State private var adjustViewCropSize: CGSize = .zero

    // Check if current photo is first or last in journey
    private var isFirstPhoto: Bool {
        guard let firstPhoto = allPhotosInJourney.first else { return false }
        return firstPhoto.id == photo.id
    }

    private var isLastPhoto: Bool {
        guard let lastPhoto = allPhotosInJourney.last else { return false }
        return lastPhoto.id == photo.id
    }

    private var shouldShowGhostSourceSelector: Bool {
        // Only show if there are at least 2 photos and not viewing first or last
        return allPhotosInJourney.count > 1 && (!isFirstPhoto && !isLastPhoto)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppStyle.Colors.bgDark.ignoresSafeArea()

                if let img = image {
                    GeometryReader { geo in
                        let cropW = geo.size.width
                        let cropH = cropW * 5/4
                        
                        // Calculate vertical center position accounting for available space
                        // Account for navigation bar (~80pt) and bottom controls (~160pt)
                        let topSpace: CGFloat = 80
                        let bottomSpace: CGFloat = 160
                        let availableHeight = geo.size.height - topSpace - bottomSpace
                        let centerY = topSpace + (availableHeight / 2)

                        ZStack {
                            // Full image dimmed as background (visible outside crop frame)
                            // This should match the crop frame's fitted sizing
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: cropW, height: cropH)
                                .scaleEffect(scale)
                                .offset(offset)
                                .rotationEffect(rotation)
                                .opacity(0.3)
                                .position(x: geo.size.width/2, y: centerY)
                                .allowsHitTesting(false)

                            // Crop window with clipped content
                            ZStack {
                                // Background for crop area
                                Rectangle()
                                    .fill(AppStyle.Colors.bgDark)

                                // Transformed image fitted to crop area (full brightness)
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: cropW, height: cropH)
                                    .scaleEffect(scale)
                                    .offset(offset)
                                    .rotationEffect(rotation)
                                    .opacity(showGhost ? (1 - ghostOpacity) : 1)

                                // Ghost overlay (if enabled) - also fitted to crop area
                                if showGhost, let ghost = ghostImage {
                                    Image(uiImage: ghost)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: cropW, height: cropH)
                                        .opacity(ghostOpacity)
                                        .allowsHitTesting(false)
                                }
                            }
                            .frame(width: cropW, height: cropH)
                            .clipped() // Clip to crop boundaries
                            .position(x: geo.size.width/2, y: centerY)
                            .onAppear {
                                // Store the crop size for rendering
                                adjustViewCropSize = CGSize(width: cropW, height: cropH)
                            }
                            .onChange(of: geo.size) { _, _ in
                                // Update if orientation changes
                                adjustViewCropSize = CGSize(width: cropW, height: cropH)
                            }

                            // Border on crop area
                            Rectangle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                .frame(width: cropW, height: cropH)
                                .position(x: geo.size.width/2, y: centerY)
                                .allowsHitTesting(false)

                            // Grid overlay (if enabled)
                            if showGrid {
                                GridOverlay()
                                    .frame(width: cropW, height: cropH)
                                    .position(x: geo.size.width/2, y: centerY)
                                    .allowsHitTesting(false)
                            }
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
                                        // Allow zooming out to 50% of the fill scale for more flexibility
                                        let absoluteMinScale = minScale * 0.5
                                        scale = max(absoluteMinScale, min(newScale, 10.0))
                                        print("🔍 Zoom: \(scale) (min: \(absoluteMinScale))")
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
            .overlay(alignment: .bottom) {
                VStack(spacing: 12) {
                    // Compact icon-only controls
                    HStack(spacing: 16) {
                        // Rotate button
                        IconButton(
                            icon: "rotate.left",
                            isActive: showRotationControls,
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showRotationControls.toggle()
                                }
                            }
                        )

                        // Scale button
                        IconButton(
                            icon: "arrow.up.left.and.arrow.down.right",
                            isActive: showScaleControls,
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showScaleControls.toggle()
                                }
                            }
                        )

                        // Grid button
                        IconButton(
                            icon: "grid",
                            isActive: showGrid,
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showGrid.toggle()
                                }
                            }
                        )

                        Spacer()

                        // Ghost overlay button
                        if ghostImage != nil || allPhotosInJourney.count > 1 {
                            IconButton(
                                icon: showGhost ? "eye.fill" : "eye.slash.fill",
                                isActive: showGhost,
                                action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showGhost.toggle()
                                    }
                                }
                            )
                        }

                        // Reset button
                        IconButton(
                            icon: "arrow.counterclockwise",
                            isActive: false,
                            action: resetTransform
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    // Expandable controls
                    if showRotationControls {
                        SliderControl(
                            icon: "rotate.left",
                            value: Binding(
                                get: { rotation.degrees },
                                set: { newValue in
                                    rotation = .degrees(newValue)
                                    lastRotation = rotation
                                }
                            ),
                            range: -45...45,
                            step: 1,
                            unit: "°"
                        )
                        .padding(.horizontal, 20)
                    }

                    // Expandable scale control
                    if showScaleControls {
                        let minScalePercent = minScale * 0.5 * 100
                        let maxScalePercent = 10.0 * 100
                        SliderControl(
                            icon: "arrow.up.left.and.arrow.down.right",
                            value: Binding(
                                get: { scale * 100 },
                                set: { newValue in
                                    scale = newValue / 100
                                    lastScale = newValue / 100
                                }
                            ),
                            range: minScalePercent...maxScalePercent,
                            step: 1,
                            unit: "%"
                        )
                        .padding(.horizontal, 20)
                    }

                    // Expandable ghost opacity control
                    if showGhost && (ghostImage != nil || allPhotosInJourney.count > 1) {
                        SliderControl(
                            icon: "circle.lefthalf.filled",
                            value: Binding(
                                get: { ghostOpacity * 100 },
                                set: { newValue in
                                    ghostOpacity = newValue / 100
                                }
                            ),
                            range: 0...100,
                            step: 1,
                            unit: "%"
                        )
                        .padding(.horizontal, 20)
                    }

                    // Ghost source selector (compact)
                    if showGhost && shouldShowGhostSourceSelector {
                        HStack(spacing: 8) {
                            Text("Ghost:")
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
                        .padding(.horizontal, 20)
                    }
                }
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
        // Always load the original uncropped image if available
        let imageId = photo.originalAssetLocalId ?? photo.assetLocalId
        print("📸 Attempting to load \(photo.originalAssetLocalId != nil ? "ORIGINAL" : "cropped") image for adjustment")
        print("📸 Image ID: \(imageId)")
        
        let loadedImage = await PhotoStore.fetchUIImage(localId: imageId, targetSize: nil)
        
        await MainActor.run {
            if let loadedImage = loadedImage {
                image = loadedImage
                print("✅ Image loaded successfully: \(loadedImage.size)")
                
                if photo.originalAssetLocalId != nil {
                    // Re-editing: Load the saved transform from the original
                    let transform = photo.alignTransform
                    scale = transform.scale > 0 ? transform.scale : 1
                    lastScale = scale
                    offset = CGSize(width: transform.offsetX, height: transform.offsetY)
                    lastOffset = offset
                    rotation = Angle(radians: transform.rotation)
                    lastRotation = rotation
                    hasCalculatedInitialScale = true
                    print("📸 Re-edit mode: Loaded saved transform from original")
                    print("📸 Transform: scale=\(transform.scale), offset=(\(transform.offsetX), \(transform.offsetY)), rotation=\(transform.rotation)")
                } else {
                    // First edit: Start with identity transform (will be set by calculateInitialScale)
                    print("📸 First edit mode: Starting fresh (scale will be calculated)")
                }
            } else {
                print("❌ Failed to load image from: \(imageId)")
                errorMessage = "Failed to load image for editing. The original image may have been deleted."
                showErrorAlert = true
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
        // Use centralized renderer for consistency
        return TransformRenderer.renderTransformedImage(
            sourceImage: sourceImage,
            transform: transform,
            targetSize: CGSize(width: sourceImage.size.width, height: sourceImage.size.width * 5.0 / 4.0)
        )
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
        guard let img = image else { return }
        isSaving = true

        print("🔧 Starting saveEdits")
        print("🔧 Current scale: \(scale), offset: (\(offset.width), \(offset.height)), rotation: \(rotation.degrees)°")
        print("🔧 Source image size: \(img.size)")
        print("🔧 Has originalAssetLocalId: \(photo.originalAssetLocalId != nil)")
        
        // Generate the new transformed image
        let transform = AlignTransform(
            scale: scale,
            offsetX: offset.width,
            offsetY: offset.height,
            rotation: rotation.radians
        )
        
        // Render the cropped image with the new transform
        let croppedImage = renderCroppedImage(from: img)
        print("🔧 Rendered cropped image size: \(croppedImage.size)")
        
        // Store old IDs for cleanup
        let oldAssetId = photo.assetLocalId
        let oldOriginalId = photo.originalAssetLocalId
        
        // Save the new cropped image, replacing the old assetLocalId
        guard let newLocalId = try? await PhotoStore.saveToAppDirectory(croppedImage) else {
            await MainActor.run {
                errorMessage = "Failed to save adjusted image"
                showErrorAlert = true
                isSaving = false
            }
            return
        }
        
        print("✂️ Saved new cropped image with ID: \(newLocalId)")
        print("🔧 Old assetLocalId: \(oldAssetId)")

        await MainActor.run {
            // Update the photo with the new assetLocalId and transform
            photo.assetLocalId = newLocalId
            photo.alignTransform = transform
            
            // CRITICAL: Preserve the original image ID
            // If we don't have an original ID yet, save the current (old) one
            if photo.originalAssetLocalId == nil {
                photo.originalAssetLocalId = oldAssetId
                print("💾 Saved original image ID for future re-edits: \(oldAssetId)")
            } else {
                print("💾 Keeping existing original image ID: \(photo.originalAssetLocalId!)")
            }
            
            print("💾 Updated photo: assetLocalId=\(newLocalId)")
            print("💾 Transform: scale=\(scale), offset=(\(offset.width), \(offset.height)), rotation=\(rotation.degrees)°")
            
            do {
                try ctx.save()
                print("✅ Photo updated successfully in database")
                
                // Clean up old assetLocalId file ONLY if it's different from originalAssetLocalId
                // We never delete the original!
                Task {
                    if oldAssetId != oldOriginalId {
                        try? await PhotoStore.deleteFromAppDirectory(localId: oldAssetId)
                        print("🗑️ Deleted old cropped image file: \(oldAssetId)")
                    } else {
                        print("⚠️ Skipping deletion of \(oldAssetId) as it's the original")
                    }
                }
                
                isSaving = false
                dismiss()
            } catch {
                print("❌ Error saving photo: \(error)")
                errorMessage = "Failed to save edits: \(error.localizedDescription)"
                showErrorAlert = true
                isSaving = false
            }
        }
    }

    private func renderCroppedImage(from sourceImage: UIImage) -> UIImage {
        // Use centralized renderer for consistency
        let transform = AlignTransform(
            scale: scale,
            offsetX: offset.width,
            offsetY: offset.height,
            rotation: rotation.radians
        )
        return TransformRenderer.renderTransformedImage(
            sourceImage: sourceImage,
            transform: transform,
            targetSize: CGSize(width: 1200, height: 1500),
            adjustViewSize: adjustViewCropSize
        )
    }
}

// MARK: - Helper Components for Photo Edit Controls

/// Compact icon-only button for photo edit controls
private struct IconButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isActive ? AppStyle.Colors.accentPrimary : .white.opacity(0.7))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isActive ? AppStyle.Colors.accentPrimary.opacity(0.2) : Color.white.opacity(0.1))
                )
        }
    }
}

/// Expandable slider control for photo edit adjustments
private struct SliderControl: View {
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 20)
            
            // Minus button
            Button(action: {
                let newValue = value - step
                if newValue >= range.lowerBound {
                    value = newValue
                }
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white.opacity(0.15)))
            }
            .disabled(value <= range.lowerBound)

            Slider(value: $value, in: range, step: step)
                .tint(AppStyle.Colors.accentPrimary)
            
            // Plus button
            Button(action: {
                let newValue = value + step
                if newValue <= range.upperBound {
                    value = newValue
                }
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white.opacity(0.15)))
            }
            .disabled(value >= range.upperBound)

            Text("\(Int(value))\(unit)")
                .font(.caption.monospacedDigit())
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 50, alignment: .trailing)
        }
    }
}
