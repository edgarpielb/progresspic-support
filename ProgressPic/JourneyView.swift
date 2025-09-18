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
    @State private var showImportPhotos = false
    @State private var selectedPhoto: ProgressPhoto?
    @State private var showPhotoDetail = false
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
                                }
                                
                                Spacer()
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
                                }
                                
                                Spacer()
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
                    Button(action: {
                        showImportPhotos = true
                    }) {
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
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding()
                        .glassCard()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    
                    // Photo grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(photos) { photo in
                            Button(action: {
                                selectedPhoto = photo
                                showPhotoDetail = true
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
        .sheet(isPresented: $showImportPhotos) {
            ImportPhotosView(journey: journey)
        }
        .sheet(isPresented: $showPhotoDetail) {
            if let selectedPhoto = selectedPhoto {
                PhotoEditSheet(photo: selectedPhoto)     // NEW view below
            }
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
}

struct PhotoGridItem: View {
    let photo: ProgressPhoto
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadFailed = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
            
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else if loadFailed {
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.title2)
                    Text("Failed")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            } else if isLoading {
                ProgressView()
                    .tint(.white)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .task {
            await loadImage()
        }
        .onTapGesture {
            if loadFailed {
                Task { await loadImage() }
            }
        }
    }
    
    private func loadImage() async {
        isLoading = true
        loadFailed = false
        
        do {
            // Try different target sizes for landscape images
            let targetSize = CGSize(width: 300, height: 300)
            let loadedImage = await PhotoStore.fetchUIImage(localId: photo.assetLocalId, targetSize: targetSize)
            
            await MainActor.run {
                if let loadedImage = loadedImage {
                    self.image = loadedImage
                    self.isLoading = false
                } else {
                    // Try loading without target size constraint
                    Task {
                        let fallbackImage = await PhotoStore.fetchUIImage(localId: photo.assetLocalId, targetSize: nil)
                        await MainActor.run {
                            if let fallbackImage = fallbackImage {
                                self.image = fallbackImage
                            } else {
                                self.loadFailed = true
                            }
                            self.isLoading = false
                        }
                    }
                }
            }
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
                            .foregroundColor(.blue)
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

    var photo: ProgressPhoto

    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var rotation: Angle = .zero
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 30/255, green: 32/255, blue: 35/255).ignoresSafeArea()

                if let img = image {
                    GeometryReader { geo in
                        ZStack {
                            // Crop "frame" (4:5)
                            let cropW = geo.size.width
                            let cropH = geo.size.width * 5/4

                            Rectangle()
                                .fill(Color.black.opacity(0.45))
                                .mask(
                                    Rectangle()
                                        .frame(width: cropW, height: cropH)
                                        .position(x: cropW/2, y: geo.size.height/2)
                                        .allowsHitTesting(false)
                                )
                                .ignoresSafeArea()

                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: cropW, height: cropH)
                                .scaleEffect(scale)
                                .offset(offset)
                                .rotationEffect(rotation)
                                .clipped()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                                .position(x: cropW/2, y: geo.size.height/2)
                                .gesture(
                                    SimultaneousGesture(
                                        DragGesture().onChanged { offset = $0.translation },
                                        MagnificationGesture().onChanged { scale = $0 }
                                    )
                                )
                                .gesture(
                                    RotationGesture().onChanged { rotation = $0 }
                                )
                        }
                    }
                } else {
                    ProgressView().tint(.white)
                }
            }
            .navigationTitle("Edit Photo")
            .navigationBarTitleDisplayMode(.inline)
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
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark")
                                .foregroundColor((image == nil) ? .gray : .blue)
                        }
                    }
                    .disabled(isSaving || image == nil)
                }
            }
            .task { await loadImage() }
        }
    }

    private func loadImage() async {
        image = await PhotoStore.fetchUIImage(localId: photo.assetLocalId, targetSize: nil)
    }

    private func saveEdits() async {
        guard let base = image else { return }
        isSaving = true

        // Render the transformed crop (4:5)
        let outSize = CGSize(width: 2000, height: 2500) // good resolution for 4:5
        let renderer = UIGraphicsImageRenderer(size: outSize)
        let rendered = renderer.image { ctx in
            ctx.cgContext.translateBy(x: outSize.width/2, y: outSize.height/2)
            ctx.cgContext.rotate(by: CGFloat(rotation.radians))
            ctx.cgContext.scaleBy(x: scale, y: scale)
            ctx.cgContext.translateBy(x: offset.width, y: offset.height)

            let drawRect = CGRect(
                x: -base.size.width/2,
                y: -base.size.height/2,
                width: base.size.width,
                height: base.size.height
            )
            base.draw(in: drawRect)
        }

        // Save new asset and relink this ProgressPhoto to it
        if let newLocalId = try? await PhotoStore.saveToLibrary(rendered) {
            photo.assetLocalId = newLocalId
            photo.alignTransform = AlignTransform(scale: 1, offsetX: 0, offsetY: 0, rotation: 0)
            try? ctx.save()
        }
        isSaving = false
        dismiss()
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
