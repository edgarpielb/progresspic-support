import SwiftUI
import SwiftData

struct CompareView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Journey.createdAt, order: .reverse) private var journeys: [Journey]
    @State private var selectedJourney: Journey?
    @State private var mode: Mode = .parallel
    @State private var left: ProgressPhoto?
    @State private var right: ProgressPhoto?
    @State private var showLeftSelector = false
    @State private var showRightSelector = false

    enum Mode: String, CaseIterable { case parallel = "Parallel", slider = "Slider" }

    var body: some View {
        ZStack(alignment: .top) {
            // Force dark background
            Color(red: 30/255, green: 32/255, blue: 35/255)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Mode picker at the top - add top safe area padding manually
                Picker("", selection: $mode) {
                    Text("Parallel").tag(Mode.parallel)
                    Text("Slider").tag(Mode.slider)
                }
                .pickerStyle(.segmented)
                .tint(.white)
                .padding(.horizontal)
                .padding(.top, 50) // Manual safe area compensation
                
                // Journey selector
                Menu {
                    ForEach(journeys) { j in Button(j.name) { selectedJourney = j } }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.stack")
                        Text(selectedJourney?.name ?? "Select Journey")
                    }
                    .foregroundColor(.white)
                    .glassCapsule()
                    .contentShape(Rectangle())
                }
                .padding(.top, 12)
                .padding(.horizontal)

                if let j = selectedJourney {
                    // Photo comparison section
                    VStack(spacing: 16) {
                        // Photo selectors at the top
                        HStack(spacing: 16) {
                            VStack(spacing: 8) {
                                Text("Before")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Button(action: {
                                    showLeftSelector = true
                                }) {
                                    if let left = left {
                                        PhotoSelectorThumb(photo: left)
                                    } else {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.06))
                                            .frame(width: 120, height: 120)
                                            .overlay(
                                                VStack(spacing: 4) {
                                                    Image(systemName: "photo")
                                                        .font(.title2)
                                                        .foregroundColor(.white.opacity(0.5))
                                                    Text("Tap to select")
                                                        .font(.caption2)
                                                        .foregroundColor(.white.opacity(0.7))
                                                }
                                            )
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            
                            VStack(spacing: 8) {
                                Text("After")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Button(action: {
                                    showRightSelector = true
                                }) {
                                    if let right = right {
                                        PhotoSelectorThumb(photo: right)
                                    } else {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.06))
                                            .frame(width: 120, height: 120)
                                            .overlay(
                                                VStack(spacing: 4) {
                                                    Image(systemName: "photo")
                                                        .font(.title2)
                                                        .foregroundColor(.white.opacity(0.5))
                                                    Text("Tap to select")
                                                        .font(.caption2)
                                                        .foregroundColor(.white.opacity(0.7))
                                                }
                                            )
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 16)
                        
                        // Photo selectors (show when tapped)
                        if showLeftSelector || showRightSelector {
                            PhotoSelectorSlider(
                                journey: j,
                                selectedPhoto: showLeftSelector ? $left : $right,
                                isVisible: showLeftSelector ? $showLeftSelector : $showRightSelector,
                                title: showLeftSelector ? "Select Before Photo" : "Select After Photo"
                            )
                            .padding(.horizontal)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.3), value: showLeftSelector || showRightSelector)
                        }
                        
                        // Compare view
                        if let l = left, let r = right, !showLeftSelector && !showRightSelector {
                            CompareCanvas(left: l, right: r, mode: mode)
                                .padding(.horizontal)
                        }
                    }
                } else {
                    VStack {
                        Spacer()
                        Text("Select a journey to compare photos")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.body)
                        Spacer()
                    }
                }
            }
        }
        .ignoresSafeArea(.all) // Ignore all safe areas
        .navigationTitle("Compare Photos")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            if selectedJourney == nil, let firstJourney = journeys.first {
                selectedJourney = firstJourney
            }
        }
    }
}

// New photo selector thumb component
struct PhotoSelectorThumb: View {
    let photo: ProgressPhoto
    @State private var img: UIImage?
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06))
                if let ui = img {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.14)))
            
            Text(photo.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .task {
            img = await PhotoStore.fetchUIImage(localId: photo.assetLocalId, targetSize: CGSize(width: 240, height: 240))
        }
    }
}

// New photo selector slider component
struct PhotoSelectorSlider: View {
    let journey: Journey
    @Binding var selectedPhoto: ProgressPhoto?
    @Binding var isVisible: Bool
    let title: String
    @Query private var photos: [ProgressPhoto]
    
    init(journey: Journey, selectedPhoto: Binding<ProgressPhoto?>, isVisible: Binding<Bool>, title: String) {
        self.journey = journey
        _selectedPhoto = selectedPhoto
        _isVisible = isVisible
        self.title = title
        let journeyId = journey.id
        _photos = Query(filter: #Predicate<ProgressPhoto> { $0.journeyId == journeyId },
                       sort: \ProgressPhoto.date, order: .forward)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with title and close button
            HStack {
                Text(title)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    isVisible = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Horizontal photo scroll view
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(photos) { photo in
                            VStack(spacing: 8) {
                                Button(action: {
                                    selectedPhoto = photo
                                    // Auto-dismiss after selection
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isVisible = false
                                    }
                                }) {
                                    ZStack {
                                        // Photo thumbnail
                                        PhotoGridThumb(photo: photo)
                                            .frame(width: 100, height: 100)
                                        
                                        // Selection indicator
                                        if photo.id == selectedPhoto?.id {
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.cyan, lineWidth: 3)
                                                .frame(width: 100, height: 100)
                                        }
                                        
                                        // Selection checkmark
                                        if photo.id == selectedPhoto?.id {
                                            VStack {
                                                HStack {
                                                    Spacer()
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.title3)
                                                        .foregroundColor(.cyan)
                                                        .background(Color.black.opacity(0.6), in: Circle())
                                                        .padding(4)
                                                }
                                                Spacer()
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                // Date label
                                Text(photo.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                    .frame(width: 100)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 140)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.5))
                    Text("No photos available")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.body)
                }
                .frame(height: 100)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.bottom, 16)
    }
}

// Optimized thumb component for the slider
struct PhotoGridThumb: View {
    let photo: ProgressPhoto
    @State private var img: UIImage?
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06))
            if let ui = img {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.8)
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.14)))
        .task {
            img = await PhotoStore.fetchUIImage(localId: photo.assetLocalId, targetSize: CGSize(width: 160, height: 160))
        }
    }
}

struct Thumb: View {
    let localId: String
    @State private var img: UIImage?
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06))
            if let ui = img { 
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.8)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.14)))
        .frame(width: 90, height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task { img = await PhotoStore.fetchUIImage(localId: localId, targetSize: CGSize(width: 200, height: 200)) }
    }
}

struct CompareCanvas: View {
    let left: ProgressPhoto
    let right: ProgressPhoto
    let mode: CompareView.Mode

    @State private var leftImg: UIImage?
    @State private var rightImg: UIImage?
    @State private var sliderX: CGFloat = 0.5

    var body: some View {
        ZStack {
            if let l = leftImg, let r = rightImg {
                switch mode {
                case .parallel:
                    HStack(spacing: 8) {
                        Image(uiImage: l).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 16))
                        Image(uiImage: r).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                case .slider:
                    GeometryReader { geo in
                        let w = max(1, geo.size.width)
                        let cut = w * sliderX

                        // Left image (base layer - always visible)
                        Image(uiImage: l)
                            .resizable()
                            .scaledToFit()
                            .clipped()
                        
                        // Right image (overlay - masked to show only the right portion)
                        Image(uiImage: r)
                            .resizable()
                            .scaledToFit()
                            .clipped()
                            .mask(alignment: .leading) {
                                Rectangle()
                                    .frame(width: w - cut)
                                    .offset(x: cut)
                            }

                        // Slider line
                        Rectangle()
                            .fill(.white)
                            .frame(width: 3)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 1, y: 0)
                            .position(x: cut, y: geo.size.height/2)
                        
                        // Invisible overlay for gesture handling
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { v in
                                        let x = min(max(v.location.x, 0), geo.size.width)
                                        sliderX = x / max(1, geo.size.width)
                                    }
                            )
                    }
                    .frame(height: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else { ProgressView().frame(height: 420) }
        }
        .task {
            leftImg = await PhotoStore.fetchUIImage(localId: left.assetLocalId)
            rightImg = await PhotoStore.fetchUIImage(localId: right.assetLocalId)
        }
    }
}
