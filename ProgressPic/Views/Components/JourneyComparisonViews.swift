import SwiftUI
import SwiftData
import AVFoundation

// MARK: - Journey Compare Sheet
struct JourneyCompareSheet: View {
    let journey: Journey
    let photos: [ProgressPhoto]
    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: UIImage?
    @State private var shareURL: URL?
    @State private var showShareSheet = false

    var body: some View {
        NavigationView {
            ZStack {
                AppStyle.Colors.bgDark
                    .ignoresSafeArea()

                JourneyCompareView(journey: journey, photos: photos, shareImage: $shareImage)
            }
            .navigationTitle("Compare Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        prepareShareImage()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .foregroundColor(AppStyle.Colors.accentPrimary)
                    }
                }
            }
            .sheet(item: $shareURL) { url in
                ShareSheet(url: url)
            }
        }
    }
    
    private func prepareShareImage() {
        guard let image = shareImage else { return }
        
        // Save image to temporary directory
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "comparison_\(Date().timeIntervalSince1970).jpg"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        if let imageData = image.jpegData(compressionQuality: 0.9) {
            try? imageData.write(to: fileURL)
            shareURL = fileURL
            showShareSheet = true
        }
    }
}

// MARK: - Journey Compare View
struct JourneyCompareView: View {
    let journey: Journey
    let photos: [ProgressPhoto]
    @Binding var shareImage: UIImage?
    @State private var left: ProgressPhoto?
    @State private var right: ProgressPhoto?
    @State private var mode: CompareMode = .parallel
    @State private var showDates = true
    @State private var fitImage = false
    @State private var selectedSide: SelectionSide = .left
    @State private var showTooltip = false
    @State private var sliderPosition: CGFloat = 0.5
    
    // Date overlay settings
    @State private var dateFormat: DateFormat = .classic
    @State private var datePosition: DatePosition = .topLeft
    @State private var dateFont: DateFont = .system
    @State private var dateFontSize: DateFontSize = .medium
    @State private var dateColor: Color = .white
    @State private var showDateBackground = true
    @State private var showDateSheet = false
    
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

        // Reset slider to center when selecting a side in slider mode
        if mode == .slider {
            withAnimation(.easeInOut(duration: 0.3)) {
                sliderPosition = 0.5
            }
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
        contentWithModifiers
    }

    @ViewBuilder
    private var contentWithModifiers: some View {
        mainContent
            .ignoresSafeArea(edges: .bottom)
            .sheet(isPresented: $showDateSheet, content: {
                dateSheet
            })
            .modifier(PhotoChangeModifier(
                left: left,
                right: right,
                mode: mode,
                fitImage: fitImage,
                showDates: showDates,
                dateFormat: dateFormat,
                datePosition: datePosition,
                dateFont: dateFont,
                dateFontSize: dateFontSize,
                dateColor: dateColor,
                showDateBackground: showDateBackground,
                onCapture: captureComparisonImage
            ))
            .onAppear {
                if left == nil && right == nil && visiblePhotos.count >= 2 {
                    left = visiblePhotos.last
                    right = visiblePhotos.first
                }
            }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 8)

                if visiblePhotos.count >= 2 {
                    modePicker
                    Spacer().frame(height: AppStyle.Spacing.sm)

                    if left != nil && right != nil {
                        actionButtons
                    }

                    comparisonView

                    if !visiblePhotos.isEmpty {
                        photoSelector
                    }
                } else {
                    emptyPhotosState
                }
            }
        }
    }

    private var dateSheet: some View {
        DateSettingsSheet(
            showDateOverlay: $showDates,
            dateFormat: $dateFormat,
            datePosition: $datePosition,
            dateFont: $dateFont,
            dateFontSize: $dateFontSize,
            dateColor: $dateColor,
            showDateBackground: $showDateBackground
        )
    }

    // MARK: - View Components

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            Text("Parallel").tag(CompareMode.parallel)
            Text("Slider").tag(CompareMode.slider)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    private var actionButtons: some View {
        HStack(spacing: AppStyle.Spacing.xl) {
            Button(action: {
                showDates = true
                showDateSheet = true
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: AppStyle.IconSize.xl))
                        .foregroundColor(showDates ? AppStyle.Colors.accentPrimary : AppStyle.Colors.textPrimary)
                    Text("Dates")
                        .font(AppStyle.FontStyle.caption)
                        .foregroundColor(AppStyle.Colors.textSecondary)
                }
                .frame(width: 70)
            }

            Button(action: {
                fitImage.toggle()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: fitImage ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: AppStyle.IconSize.xl))
                        .foregroundColor(fitImage ? AppStyle.Colors.accentPrimary : AppStyle.Colors.textPrimary)
                    Text("Fit Image")
                        .font(AppStyle.FontStyle.caption)
                        .foregroundColor(AppStyle.Colors.textSecondary)
                }
                .frame(width: 70)
            }

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

    private var comparisonView: some View {
        Group {
            if let left = left, let right = right {
                comparisonCanvas(left: left, right: right)
            } else {
                emptyComparisonState
            }
        }
    }

    private func comparisonCanvas(left: ProgressPhoto, right: ProgressPhoto) -> some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let canvasHeight = availableWidth * 5.0 / 4.0

            ZStack {
                ImprovedCompareCanvas(
                    left: left,
                    right: right,
                    mode: mode,
                    showDates: showDates,
                    fitImage: fitImage,
                    sliderPosition: $sliderPosition,
                    dateFormat: dateFormat,
                    datePosition: datePosition,
                    dateFont: dateFont,
                    dateFontSize: dateFontSize,
                    dateColor: dateColor,
                    showDateBackground: showDateBackground
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

                tapAreas
            }
        }
        .frame(height: UIScreen.main.bounds.width * 5.0 / 4.0)
    }

    private var emptyComparisonState: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let canvasHeight = availableWidth * 5.0 / 4.0

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

    private var tapAreas: some View {
        Group {
            if mode == .parallel {
                parallelTapAreas
            } else {
                sliderTapAreas
            }
        }
    }

    private var parallelTapAreas: some View {
        HStack(spacing: 0) {
            tapArea(side: .left)
            tapArea(side: .right)
        }
    }

    private func tapArea(side: SelectionSide) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                selectSide(side)
            }
            .overlay(
                VStack {
                    Spacer()
                    if selectedSide == side && showTooltip {
                        tooltipView(side: side)
                    }
                }
            )
    }

    private func tooltipView(side: SelectionSide) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(AppStyle.Colors.accentPrimary)
                    .frame(width: 40, height: 40)
                    .shadow(radius: 4)

                Text(side == .left ? "L" : "R")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

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
                .transition(.opacity)
        }
        .padding(.bottom, showDates ? 32 : 12)
    }

    private var sliderTapAreas: some View {
        GeometryReader { tapGeo in
            let sliderX = tapGeo.size.width * sliderPosition
            let sliderZone: CGFloat = 60

            HStack(spacing: 0) {
                if sliderX > sliderZone / 2 {
                    Color.clear
                        .frame(width: sliderX - sliderZone / 2)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectSide(.left)
                        }
                        .overlay(
                            VStack {
                                Spacer()
                                if selectedSide == .left && showTooltip {
                                    tooltipView(side: .left)
                                }
                            }
                        )
                }

                Color.clear.frame(width: sliderZone)

                if (tapGeo.size.width - sliderX) > sliderZone / 2 {
                    Color.clear
                        .frame(width: tapGeo.size.width - sliderX - sliderZone / 2)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectSide(.right)
                        }
                        .overlay(
                            VStack {
                                Spacer()
                                if selectedSide == .right && showTooltip {
                                    tooltipView(side: .right)
                                }
                            }
                        )
                }
            }
        }
    }

    private var photoSelector: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: AppStyle.Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(visiblePhotos) { photo in
                        Button(action: {
                            selectPhoto(photo)
                        }) {
                            ZStack(alignment: .topLeading) {
                                PhotoGridItem(photo: photo)
                                    .frame(width: 120, height: 150)

                                VStack(spacing: 4) {
                                    if self.left?.id == photo.id {
                                        selectionIndicator(label: "L")
                                    }
                                    if self.right?.id == photo.id {
                                        selectionIndicator(label: "R")
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
        }
    }

    private func selectionIndicator(label: String) -> some View {
        Circle()
            .fill(AppStyle.Colors.accentPrimary)
            .frame(width: 28, height: 28)
            .overlay(
                Text(label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    private var emptyPhotosState: some View {
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
    
    private func captureComparisonImage() {
        guard let leftPhoto = left, let rightPhoto = right else { return }
        
        Task {
            // Load images at high resolution for sharing
            let screenWidth = UIScreen.main.bounds.width
            let targetSize = CGSize(width: screenWidth * UIScreen.main.scale, height: screenWidth * UIScreen.main.scale * 5.0 / 4.0)

            // Always load from assetLocalId for display (already transformed)
            guard let leftImg = await PhotoStore.fetchUIImage(localId: leftPhoto.assetLocalId, targetSize: CGSize(width: 2400, height: 2400)),
                  let rightImg = await PhotoStore.fetchUIImage(localId: rightPhoto.assetLocalId, targetSize: CGSize(width: 2400, height: 2400)) else {
                return
            }

            // assetLocalId always contains the display-ready images
            // No transform needed - they were already applied when saved

            // Render the comparison image
            let image = await renderComparisonImage(leftImg: leftImg, rightImg: rightImg, size: targetSize)

            await MainActor.run {
                shareImage = image
            }
        }
    }

    // Removed - now using TransformRenderer.renderTransformedImage
    private func renderTransformedImageForShare_REMOVED(image: UIImage, transform: AlignTransform, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { ctx in
            // Fill background
            ctx.cgContext.setFillColor(UIColor(red: 30/255, green: 32/255, blue: 35/255, alpha: 1.0).cgColor)
            ctx.cgContext.fill(CGRect(origin: .zero, size: targetSize))

            // Calculate how the image fits FIRST (this is what .scaledToFit does)
            let imageAspect = image.size.width / image.size.height
            let targetAspect = targetSize.width / targetSize.height

            var drawSize: CGSize
            if imageAspect > targetAspect {
                // Image is wider - fit by width
                drawSize = CGSize(width: targetSize.width, height: targetSize.width / imageAspect)
            } else {
                // Image is taller - fit by height
                drawSize = CGSize(width: targetSize.height * imageAspect, height: targetSize.height)
            }

            // Move to center of crop area
            ctx.cgContext.translateBy(x: targetSize.width / 2, y: targetSize.height / 2)

            // Apply user transforms (these are relative to the fitted image)
            // Important: scale is relative to fit scale, offset is in screen points
            let safeScale = max(transform.scale, 0.001)
            ctx.cgContext.scaleBy(x: safeScale, y: safeScale)
            ctx.cgContext.translateBy(x: transform.offsetX / safeScale, y: transform.offsetY / safeScale)
            ctx.cgContext.rotate(by: CGFloat(transform.rotation))

            // Draw the image at its fitted size (already calculated above)
            let drawRect = CGRect(
                x: -drawSize.width / 2,
                y: -drawSize.height / 2,
                width: drawSize.width,
                height: drawSize.height
            )

            image.draw(in: drawRect)
        }
    }
    
    private func renderComparisonImage(leftImg: UIImage, rightImg: UIImage, size: CGSize) async -> UIImage? {
        // Capture state values on main actor before entering detached task
        let currentMode = mode
        let shouldFitImage = fitImage
        let shouldShowDates = showDates
        let leftDate = left?.date ?? Date()
        let rightDate = right?.date ?? Date()
        let currentDateFormat = dateFormat
        let currentDateFontSize = dateFontSize
        let currentDateColor = dateColor
        let currentDatePosition = datePosition
        let shouldShowDateBackground = showDateBackground
        let currentSliderPos = sliderPosition

        return await Task.detached {
            UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
            defer { UIGraphicsEndImageContext() }

            guard let context = UIGraphicsGetCurrentContext() else { return nil }

            // Fill background
            context.setFillColor(UIColor(red: 30/255, green: 32/255, blue: 35/255, alpha: 1.0).cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            
            // Flip coordinate system to fix upside-down images
            context.translateBy(x: 0, y: size.height)
            context.scaleBy(x: 1.0, y: -1.0)

            if currentMode == .parallel {
                // Draw parallel view
                let halfWidth = size.width / 2

                // Draw left image
                if let leftCGImage = leftImg.cgImage {
                    context.saveGState()
                    let leftClip = CGRect(x: 0, y: 0, width: halfWidth, height: size.height)
                    context.clip(to: leftClip)
                    
                    let drawRect: CGRect
                    if shouldFitImage {
                        // Fit mode - show entire image
                        let imageAspect = CGFloat(leftCGImage.width) / CGFloat(leftCGImage.height)
                        let targetAspect = halfWidth / size.height
                        if imageAspect > targetAspect {
                            let drawHeight = halfWidth / imageAspect
                            drawRect = CGRect(x: 0, y: (size.height - drawHeight) / 2, width: halfWidth, height: drawHeight)
                        } else {
                            let drawWidth = size.height * imageAspect
                            drawRect = CGRect(x: (halfWidth - drawWidth) / 2, y: 0, width: drawWidth, height: size.height)
                        }
                    } else {
                        // Fill mode - crop to fill entire area
                        let imageAspect = CGFloat(leftCGImage.width) / CGFloat(leftCGImage.height)
                        let targetAspect = halfWidth / size.height
                        if imageAspect > targetAspect {
                            let drawWidth = size.height * imageAspect
                            drawRect = CGRect(x: -(drawWidth - halfWidth) / 2, y: 0, width: drawWidth, height: size.height)
                        } else {
                            let drawHeight = halfWidth / imageAspect
                            drawRect = CGRect(x: 0, y: -(drawHeight - size.height) / 2, width: halfWidth, height: drawHeight)
                        }
                    }
                    context.draw(leftCGImage, in: drawRect)
                    context.restoreGState()
                }

                // Draw right image
                if let rightCGImage = rightImg.cgImage {
                    context.saveGState()
                    let rightClip = CGRect(x: halfWidth, y: 0, width: halfWidth, height: size.height)
                    context.clip(to: rightClip)
                    
                    let drawRect: CGRect
                    if shouldFitImage {
                        // Fit mode - show entire image
                        let imageAspect = CGFloat(rightCGImage.width) / CGFloat(rightCGImage.height)
                        let targetAspect = halfWidth / size.height
                        if imageAspect > targetAspect {
                            let drawHeight = halfWidth / imageAspect
                            drawRect = CGRect(x: halfWidth, y: (size.height - drawHeight) / 2, width: halfWidth, height: drawHeight)
                        } else {
                            let drawWidth = size.height * imageAspect
                            drawRect = CGRect(x: halfWidth + (halfWidth - drawWidth) / 2, y: 0, width: drawWidth, height: size.height)
                        }
                    } else {
                        // Fill mode - crop to fill entire area
                        let imageAspect = CGFloat(rightCGImage.width) / CGFloat(rightCGImage.height)
                        let targetAspect = halfWidth / size.height
                        if imageAspect > targetAspect {
                            let drawWidth = size.height * imageAspect
                            drawRect = CGRect(x: halfWidth - (drawWidth - halfWidth) / 2, y: 0, width: drawWidth, height: size.height)
                        } else {
                            let drawHeight = halfWidth / imageAspect
                            drawRect = CGRect(x: halfWidth, y: -(drawHeight - size.height) / 2, width: halfWidth, height: drawHeight)
                        }
                    }
                    context.draw(rightCGImage, in: drawRect)
                    context.restoreGState()
                }

                // Draw white divider line
                context.setFillColor(UIColor.white.cgColor)
                context.fill(CGRect(x: halfWidth - 0.5, y: 0, width: 1, height: size.height))
            } else {
                // Slider mode
                let dividerX = size.width * currentSliderPos
                
                // Draw RIGHT image (visible on LEFT side of slider - before divider)
                if let rightCGImage = rightImg.cgImage {
                    context.saveGState()
                    let leftClip = CGRect(x: 0, y: 0, width: dividerX, height: size.height)
                    context.clip(to: leftClip)
                    
                    let drawRect: CGRect
                    if shouldFitImage {
                        let imageAspect = CGFloat(rightCGImage.width) / CGFloat(rightCGImage.height)
                        let targetAspect = size.width / size.height
                        if imageAspect > targetAspect {
                            let drawHeight = size.width / imageAspect
                            drawRect = CGRect(x: 0, y: (size.height - drawHeight) / 2, width: size.width, height: drawHeight)
                        } else {
                            let drawWidth = size.height * imageAspect
                            drawRect = CGRect(x: (size.width - drawWidth) / 2, y: 0, width: drawWidth, height: size.height)
                        }
                    } else {
                        let imageAspect = CGFloat(rightCGImage.width) / CGFloat(rightCGImage.height)
                        let targetAspect = size.width / size.height
                        if imageAspect > targetAspect {
                            let drawWidth = size.height * imageAspect
                            drawRect = CGRect(x: -(drawWidth - size.width) / 2, y: 0, width: drawWidth, height: size.height)
                        } else {
                            let drawHeight = size.width / imageAspect
                            drawRect = CGRect(x: 0, y: -(drawHeight - size.height) / 2, width: size.width, height: drawHeight)
                        }
                    }
                    context.draw(rightCGImage, in: drawRect)
                    context.restoreGState()
                }
                
                // Draw LEFT image (visible on RIGHT side of slider - after divider)
                if let leftCGImage = leftImg.cgImage {
                    context.saveGState()
                    let rightClip = CGRect(x: dividerX, y: 0, width: size.width - dividerX, height: size.height)
                    context.clip(to: rightClip)
                    
                    let drawRect: CGRect
                    if shouldFitImage {
                        let imageAspect = CGFloat(leftCGImage.width) / CGFloat(leftCGImage.height)
                        let targetAspect = size.width / size.height
                        if imageAspect > targetAspect {
                            let drawHeight = size.width / imageAspect
                            drawRect = CGRect(x: 0, y: (size.height - drawHeight) / 2, width: size.width, height: drawHeight)
                        } else {
                            let drawWidth = size.height * imageAspect
                            drawRect = CGRect(x: (size.width - drawWidth) / 2, y: 0, width: drawWidth, height: size.height)
                        }
                    } else {
                        let imageAspect = CGFloat(leftCGImage.width) / CGFloat(leftCGImage.height)
                        let targetAspect = size.width / size.height
                        if imageAspect > targetAspect {
                            let drawWidth = size.height * imageAspect
                            drawRect = CGRect(x: -(drawWidth - size.width) / 2, y: 0, width: drawWidth, height: size.height)
                        } else {
                            let drawHeight = size.width / imageAspect
                            drawRect = CGRect(x: 0, y: -(drawHeight - size.height) / 2, width: size.width, height: drawHeight)
                        }
                    }
                    context.draw(leftCGImage, in: drawRect)
                    context.restoreGState()
                }
                
                // Draw white divider line
                context.setFillColor(UIColor.white.cgColor)
                context.fill(CGRect(x: dividerX - 0.5, y: 0, width: 1, height: size.height))
            }
            
            // Reset coordinate system for drawing dates
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: 0, y: -size.height)

            // Draw dates if enabled
            if shouldShowDates {
                Self.drawDatesSync(
                    context: context,
                    size: size,
                    leftDate: leftDate,
                    rightDate: rightDate,
                    dateFormat: currentDateFormat,
                    datePosition: currentDatePosition,
                    dateFontSize: currentDateFontSize,
                    dateColor: currentDateColor,
                    showDateBackground: shouldShowDateBackground,
                    isSlider: currentMode == .slider
                )
            }

            return UIGraphicsGetImageFromCurrentImageContext()
        }.value
    }
    
    nonisolated private static func drawDatesSync(
        context: CGContext,
        size: CGSize,
        leftDate: Date,
        rightDate: Date,
        dateFormat: DateFormat,
        datePosition: DatePosition,
        dateFontSize: DateFontSize,
        dateColor: Color,
        showDateBackground: Bool,
        isSlider: Bool
    ) {
        let leftText = dateFormat.format(leftDate)
        let rightText = dateFormat.format(rightDate)

        // Get font size based on dateFontSize - scaled up for better visibility
        let fontSize: CGFloat
        switch dateFontSize {
        case .small: fontSize = 18
        case .medium: fontSize = 22
        case .large: fontSize = 28
        case .extraLarge: fontSize = 36
        }

        let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(dateColor),
            .paragraphStyle: paragraphStyle
        ]

        // Calculate positions based on datePosition
        let isTop = datePosition == .topLeft || datePosition == .topCenter || datePosition == .topRight
        let padding: CGFloat = showDateBackground ? 16 : 12
        let yPosition: CGFloat = isTop ? padding : size.height - fontSize - padding * 2
        
        // Determine X positions based on position setting
        let leftX: CGFloat
        let rightX: CGFloat
        
        // For parallel mode, dates are always in opposite corners
        // For slider mode, they can be positioned based on setting
        if !isSlider {
            // Parallel mode: left date on left, right date on right
            leftX = padding
            let rightSize = rightText.size(withAttributes: attributes)
            rightX = size.width - rightSize.width - padding - (showDateBackground ? 20 : 0)
        } else {
            // Slider mode: both dates respect the position setting
            if datePosition == .topLeft || datePosition == .bottomLeft {
                leftX = padding
                let rightSize = rightText.size(withAttributes: attributes)
                rightX = size.width - rightSize.width - padding - (showDateBackground ? 20 : 0)
            } else if datePosition == .topRight || datePosition == .bottomRight {
                let leftSize = leftText.size(withAttributes: attributes)
                leftX = size.width - leftSize.width - padding - (showDateBackground ? 20 : 0)
                rightX = padding
            } else {
                // Center position
                let leftSize = leftText.size(withAttributes: attributes)
                leftX = (size.width - leftSize.width) / 2
                let rightSize = rightText.size(withAttributes: attributes)
                rightX = (size.width - rightSize.width) / 2
            }
        }
        
        // Draw left date
        let leftSize = leftText.size(withAttributes: attributes)

        if showDateBackground {
            let bgPadding: CGFloat = 12
            let backgroundRect = CGRect(x: leftX, y: yPosition, width: leftSize.width + bgPadding * 2, height: leftSize.height + bgPadding)
            let backgroundPath = UIBezierPath(roundedRect: backgroundRect, cornerRadius: backgroundRect.height / 2)
            context.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
            context.addPath(backgroundPath.cgPath)
            context.fillPath()
            leftText.draw(in: CGRect(x: leftX + bgPadding, y: yPosition + bgPadding / 2, width: leftSize.width, height: leftSize.height), withAttributes: attributes)
        } else {
            leftText.draw(in: CGRect(x: leftX, y: yPosition, width: leftSize.width, height: leftSize.height), withAttributes: attributes)
        }

        // Draw right date
        let rightSize = rightText.size(withAttributes: attributes)

        if showDateBackground {
            let bgPadding: CGFloat = 12
            let backgroundRect = CGRect(x: rightX - bgPadding, y: yPosition, width: rightSize.width + bgPadding * 2, height: rightSize.height + bgPadding)
            let backgroundPath = UIBezierPath(roundedRect: backgroundRect, cornerRadius: backgroundRect.height / 2)
            context.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
            context.addPath(backgroundPath.cgPath)
            context.fillPath()
            rightText.draw(in: CGRect(x: rightX, y: yPosition + bgPadding / 2, width: rightSize.width, height: rightSize.height), withAttributes: attributes)
        } else {
            rightText.draw(in: CGRect(x: rightX, y: yPosition, width: rightSize.width, height: rightSize.height), withAttributes: attributes)
        }
    }
}

