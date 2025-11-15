import SwiftUI
import SwiftData

/// Main view for comparing two journey photos side-by-side
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

    // MARK: - Helper Methods

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

    // MARK: - Image Capture

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

            // Render the comparison image using the renderer
            let image = await JourneyCompareRenderer.renderComparisonImage(
                leftImg: leftImg,
                rightImg: rightImg,
                size: targetSize,
                mode: mode,
                fitImage: fitImage,
                showDates: showDates,
                leftDate: leftPhoto.date,
                rightDate: rightPhoto.date,
                dateFormat: dateFormat,
                dateFontSize: dateFontSize,
                dateColor: dateColor,
                datePosition: datePosition,
                showDateBackground: showDateBackground,
                sliderPosition: sliderPosition
            )

            await MainActor.run {
                shareImage = image
            }
        }
    }
}
