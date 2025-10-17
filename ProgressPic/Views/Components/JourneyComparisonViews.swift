import SwiftUI
import SwiftData
import AVFoundation

// MARK: - Journey Compare Sheet
struct JourneyCompareSheet: View {
    let journey: Journey
    let photos: [ProgressPhoto]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(red: 30/255, green: 32/255, blue: 35/255)
                .ignoresSafeArea()

            JourneyCompareView(journey: journey, photos: photos, dismiss: dismiss)
        }
    }
}

// MARK: - Journey Compare View
struct JourneyCompareView: View {
    let journey: Journey
    let photos: [ProgressPhoto]
    let dismiss: DismissAction
    @State private var left: ProgressPhoto?
    @State private var right: ProgressPhoto?
    @State private var mode: CompareMode = .parallel
    @State private var showDates = true
    @State private var fitImage = false
    @State private var selectedSide: SelectionSide = .left
    @State private var showTooltip = false
    
    enum CompareMode: String, CaseIterable {
        case parallel = "Parallel"
        case slider = "Slider"
    }
    
    enum SelectionSide {
        case left, right
    }
    
    // Filter out hidden photos
    private var visiblePhotos: [ProgressPhoto] {
        photos.filter { !$0.isHidden }
    }
    
    private func flipPhotos() {
        let temp = left
        left = right
        right = temp
    }
    
    private func selectPhoto(_ photo: ProgressPhoto) {
        if selectedSide == .left {
            left = photo
        } else {
            right = photo
        }
        // Hide tooltip when photo is selected
        withAnimation(.easeOut(duration: 0.2)) {
            showTooltip = false
        }
    }
    
    private func selectSide(_ side: SelectionSide) {
        selectedSide = side
        withAnimation(.easeIn(duration: 0.2)) {
            showTooltip = true
        }
        
        // Auto-hide tooltip after 3 seconds
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    showTooltip = false
                }
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Custom header with title and done button - inside ScrollView
                HStack {
                    Spacer()
                    Text("Compare Photos")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Spacer()
                }
                .overlay(
                    HStack {
                        Spacer()
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.white)
                                .font(.body)
                        }
                    }
                    .padding(.horizontal)
                )
                .padding(.top, 20)
                .padding(.bottom, 16)

                if visiblePhotos.count >= 2 {
                        // Use standard Picker for better responsiveness
                        Picker("Mode", selection: $mode) {
                            Text("Parallel").tag(CompareMode.parallel)
                            Text("Slider").tag(CompareMode.slider)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        Spacer().frame(height: AppStyle.Spacing.sm)
                
                // Action buttons ABOVE comparison
                if left != nil && right != nil {
                    HStack(spacing: AppStyle.Spacing.xl) {
                        // Dates toggle
                        Button(action: {
                            showDates.toggle()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: showDates ? "calendar.badge.checkmark" : "calendar")
                                    .font(.system(size: AppStyle.IconSize.xl))
                                    .foregroundColor(showDates ? AppStyle.Colors.accentCyan : AppStyle.Colors.textPrimary)
                                Text("Dates")
                                    .font(AppStyle.FontStyle.caption)
                                    .foregroundColor(AppStyle.Colors.textSecondary)
                            }
                            .frame(width: 70)
                        }
                        
                        // Fit Image toggle
                        Button(action: {
                            fitImage.toggle()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: fitImage ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                                    .font(.system(size: AppStyle.IconSize.xl))
                                    .foregroundColor(fitImage ? AppStyle.Colors.accentCyan : AppStyle.Colors.textPrimary)
                                Text("Fit Image")
                                    .font(AppStyle.FontStyle.caption)
                                    .foregroundColor(AppStyle.Colors.textSecondary)
                            }
                            .frame(width: 70)
                        }
                        
                        // Flip action
                        Button(action: flipPhotos) {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: AppStyle.IconSize.xl))
                                    .foregroundColor(AppStyle.Colors.textPrimary)
                                Text("Flip")
                                    .font(AppStyle.FontStyle.caption)
                                    .foregroundColor(AppStyle.Colors.textSecondary)
                            }
                            .frame(width: 70)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, AppStyle.Spacing.sm)
                }
                
                // Main comparison view - full width with 4:5 ratio
                if let left = left, let right = right {
                    GeometryReader { geometry in
                        let availableWidth = geometry.size.width
                        let canvasHeight = availableWidth * 5.0 / 4.0 // 4:5 aspect ratio
                        
                        ZStack {
                            ImprovedCompareCanvas(
                                left: left,
                                right: right,
                                mode: mode,
                                showDates: showDates,
                                fitImage: fitImage
                            )
                            .frame(width: availableWidth, height: canvasHeight)
                            .background(
                                RoundedRectangle(cornerRadius: AppStyle.Corner.xl)
                                    .fill(AppStyle.Colors.panel)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppStyle.Corner.xl)
                                    .stroke(AppStyle.Colors.border, lineWidth: 1)
                            )
                        
                        // Tap areas to select which side to replace (only in parallel mode)
                        if mode == .parallel {
                            HStack(spacing: 0) {
                                // Left tap area
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectSide(.left)
                                    }
                                .overlay(
                                    VStack {
                                        if selectedSide == .left && showTooltip {
                                            ZStack {
                                                Circle()
                                                    .fill(.white)
                                                    .frame(width: 40, height: 40)
                                                    .shadow(radius: 4)
                                                
                                                Text("L")
                                                    .font(.system(size: 20, weight: .bold))
                                                    .foregroundColor(.black)
                                            }
                                            .padding(.top, 20)
                                            
                                            Text("Tap an image\nbelow to replace")
                                                .font(AppStyle.FontStyle.caption)
                                                .multilineTextAlignment(.center)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(AppStyle.Colors.bgDark.opacity(0.9))
                                                )
                                                .padding(.top, 8)
                                                .transition(.opacity)
                                        }
                                        Spacer()
                                    }
                                )
                            
                            // Right tap area
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectSide(.right)
                                }
                                .overlay(
                                    VStack {
                                        if selectedSide == .right && showTooltip {
                                            ZStack {
                                                Circle()
                                                    .fill(.white)
                                                    .frame(width: 40, height: 40)
                                                    .shadow(radius: 4)
                                                
                                                Text("R")
                                                    .font(.system(size: 20, weight: .bold))
                                                    .foregroundColor(.black)
                                            }
                                            .padding(.top, 20)
                                            
                                            Text("Tap an image\nbelow to replace")
                                                .font(AppStyle.FontStyle.caption)
                                                .multilineTextAlignment(.center)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(AppStyle.Colors.bgDark.opacity(0.9))
                                                )
                                                .padding(.top, 8)
                                                .transition(.opacity)
                                        }
                                        Spacer()
                                    }
                                )
                            }
                        }
                        }
                    }
                    .frame(height: UIScreen.main.bounds.width * 5.0 / 4.0) // Reserve space for GeometryReader with 4:5 ratio
                    
                    Spacer().frame(height: AppStyle.Spacing.lg)
                    
                    // Single photo slider
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(visiblePhotos) { photo in
                                Button(action: {
                                    selectPhoto(photo)
                                }) {
                                    ZStack(alignment: .topLeading) {
                                        PhotoGridItem(photo: photo)
                                            .frame(width: 120, height: 150)
                                        
                                        // Selection indicators
                                        VStack(spacing: 4) {
                                            if self.left?.id == photo.id {
                                                Circle()
                                                    .fill(AppStyle.Colors.accentRed)
                                                    .frame(width: 28, height: 28)
                                                    .overlay(
                                                        Text("L")
                                                            .font(.system(size: 14, weight: .bold))
                                                            .foregroundColor(.white)
                                                    )
                                            }
                                            if self.right?.id == photo.id {
                                                Circle()
                                                    .fill(AppStyle.Colors.accentRed)
                                                    .frame(width: 28, height: 28)
                                                    .overlay(
                                                        Text("R")
                                                            .font(.system(size: 14, weight: .bold))
                                                            .foregroundColor(.white)
                                                    )
                                            }
                                        }
                                        .padding(8)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, AppStyle.Spacing.lg)
                    
                } else {
                    // Empty state
                    GeometryReader { geometry in
                        let availableWidth = geometry.size.width
                        let canvasHeight = availableWidth * 5.0 / 4.0 // 4:5 aspect ratio
                        
                        RoundedRectangle(cornerRadius: AppStyle.Corner.xl)
                            .fill(AppStyle.Colors.panel)
                            .frame(width: availableWidth, height: canvasHeight)
                            .overlay(
                                Text("Select two photos to compare")
                                    .font(AppStyle.FontStyle.body)
                                    .foregroundColor(AppStyle.Colors.textSecondary)
                            )
                    }
                    .frame(height: UIScreen.main.bounds.width * 5.0 / 4.0)
                }
                } else {
                    // No photos state
                    RoundedRectangle(cornerRadius: AppStyle.Corner.xl)
                        .fill(AppStyle.Colors.panel)
                        .frame(height: 200)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.title2)
                                    .foregroundColor(AppStyle.Colors.textTertiary)
                                Text("Add at least 2 photos to compare")
                                    .font(AppStyle.FontStyle.body)
                                    .foregroundColor(AppStyle.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                        )
                        .padding(.horizontal)
                        .padding(.top, 60)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            // Auto-select oldest (before) and newest (after) visible photos
            if left == nil && right == nil && visiblePhotos.count >= 2 {
                left = visiblePhotos.last  // Oldest photo (Picture 1)
                right = visiblePhotos.first  // Newest photo (Picture 2)
            }
        }
    }
}

// MARK: - Improved Compare Canvas
struct ImprovedCompareCanvas: View {
    let left: ProgressPhoto
    let right: ProgressPhoto
    let mode: JourneyCompareView.CompareMode
    let showDates: Bool
    let fitImage: Bool
    
    @State private var leftImg: UIImage?
    @State private var rightImg: UIImage?
    @State private var sliderPosition: CGFloat = 0.5
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let l = leftImg, let r = rightImg {
                    switch mode {
                    case .parallel:
                        parallelView(leftImg: l, rightImg: r, width: geometry.size.width, height: geometry.size.height)
                    case .slider:
                        sliderView(leftImg: l, rightImg: r, width: geometry.size.width, height: geometry.size.height)
                    }
                } else {
                    ProgressView()
                        .tint(AppStyle.Colors.textPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .task {
            await loadImages()
        }
        .onChange(of: left) { _, _ in
            Task { await loadImages() }
        }
        .onChange(of: right) { _, _ in
            Task { await loadImages() }
        }
    }
    
    private func parallelView(leftImg: UIImage, rightImg: UIImage, width: CGFloat, height: CGFloat) -> some View {
        // Calculate dimensions accounting for all padding and spacing
        let totalHorizontalPadding: CGFloat = 16 // 8 on each side
        let centerSpacing: CGFloat = 8
        let imageWidth = (width - totalHorizontalPadding - centerSpacing) / 2

        // Calculate height accounting for padding and date label
        let totalVerticalPadding: CGFloat = 16 // 8 on top and bottom
        let dateHeight: CGFloat = showDates ? 24 : 0 // Height for date text + spacing
        let imageHeight = height - totalVerticalPadding - dateHeight

        return HStack(spacing: centerSpacing) {
            // Left image with date
            VStack(spacing: 4) {
                Image(uiImage: leftImg)
                    .resizable()
                    .aspectRatio(contentMode: fitImage ? .fit : .fill)
                    .frame(width: imageWidth, height: imageHeight)
                    .clipped()
                    .cornerRadius(AppStyle.Corner.md)

                if showDates {
                    Text(left.date.formatted(date: .abbreviated, time: .omitted))
                        .font(AppStyle.FontStyle.caption)
                        .foregroundColor(AppStyle.Colors.textSecondary)
                        .frame(height: 20)
                }
            }

            // Right image with date
            VStack(spacing: 4) {
                Image(uiImage: rightImg)
                    .resizable()
                    .aspectRatio(contentMode: fitImage ? .fit : .fill)
                    .frame(width: imageWidth, height: imageHeight)
                    .clipped()
                    .cornerRadius(AppStyle.Corner.md)

                if showDates {
                    Text(right.date.formatted(date: .abbreviated, time: .omitted))
                        .font(AppStyle.FontStyle.caption)
                        .foregroundColor(AppStyle.Colors.textSecondary)
                        .frame(height: 20)
                }
            }
        }
        .padding(8)
    }
    
    private func sliderView(leftImg: UIImage, rightImg: UIImage, width: CGFloat, height: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack {
                // Left image (base layer)
                Image(uiImage: leftImg)
                    .resizable()
                    .aspectRatio(contentMode: fitImage ? .fit : .fill)
                    .frame(width: width, height: height)
                    .clipped()

                // Right image (masked overlay)
                Image(uiImage: rightImg)
                    .resizable()
                    .aspectRatio(contentMode: fitImage ? .fit : .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(width: width - (width * sliderPosition))
                            .offset(x: width * sliderPosition)
                    }

                // Divider line with handle
                VStack {
                    Circle()
                        .fill(AppStyle.Colors.textPrimary)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left.and.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppStyle.Colors.bgDark)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                }
                .frame(maxHeight: .infinity)
                .frame(width: 3)
                .background(AppStyle.Colors.textPrimary)
                .position(x: geo.size.width * sliderPosition, y: geo.size.height / 2)
                .allowsHitTesting(false)

                // Full-frame drag overlay for slider interaction
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let newPosition = value.location.x / geo.size.width
                                sliderPosition = min(max(newPosition, 0), 1)
                            }
                    )

                // Date labels for slider mode
                if showDates {
                    VStack {
                        HStack {
                            Text(left.date.formatted(date: .abbreviated, time: .omitted))
                                .font(AppStyle.FontStyle.caption2)
                                .foregroundColor(AppStyle.Colors.textPrimary)
                                .padding(6)
                                .background(AppStyle.Colors.bgDark.opacity(0.8))
                                .cornerRadius(6)
                                .padding(8)

                            Spacer()

                            Text(right.date.formatted(date: .abbreviated, time: .omitted))
                                .font(AppStyle.FontStyle.caption2)
                                .foregroundColor(AppStyle.Colors.textPrimary)
                                .padding(6)
                                .background(AppStyle.Colors.bgDark.opacity(0.8))
                                .cornerRadius(6)
                                .padding(8)
                        }
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .cornerRadius(AppStyle.Corner.lg)
    }
    
    private func loadImages() async {
        // Capture asset IDs on main actor to avoid Sendable warnings
        let leftLocalId = left.assetLocalId
        let rightLocalId = right.assetLocalId
        
        // Calculate target size for downsampling
        let screenSize = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        let targetSize = CGSize(
            width: screenSize.width * scale / 2,  // Half width for side-by-side
            height: screenSize.height * scale / 2
        )
        
        // Load both images concurrently
        async let leftTask = PhotoStore.fetchUIImage(localId: leftLocalId, targetSize: targetSize)
        async let rightTask = PhotoStore.fetchUIImage(localId: rightLocalId, targetSize: targetSize)
        
        leftImg = await leftTask
        rightImg = await rightTask
    }
}
