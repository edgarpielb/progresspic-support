import SwiftUI

// MARK: - Improved Compare Canvas
struct ImprovedCompareCanvas: View {
    let left: ProgressPhoto
    let right: ProgressPhoto
    let mode: JourneyCompareView.CompareMode
    let showDates: Bool
    let fitImage: Bool
    @Binding var sliderPosition: CGFloat
    let dateFormat: DateFormat
    let datePosition: DatePosition
    let dateFont: DateFont
    let dateFontSize: DateFontSize
    let dateColor: Color
    let showDateBackground: Bool

    @State private var leftImg: UIImage?
    @State private var rightImg: UIImage?
    @State private var dragStartPosition: CGFloat = 0.5
    @State private var isDragging: Bool = false

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
        .onChange(of: sliderPosition) { _, newValue in
            // Sync dragStartPosition when sliderPosition changes externally (but not during drag)
            if !isDragging {
                dragStartPosition = newValue
            }
        }
    }

    private func parallelView(leftImg: UIImage, rightImg: UIImage, width: CGFloat, height: CGFloat) -> some View {
        GeometryReader { geo in
            let halfWidth = geo.size.width / 2

            HStack(spacing: 0) {
                // Left half - image centered in its own space
                Image(uiImage: leftImg)
                    .resizable()
                    .aspectRatio(contentMode: fitImage ? .fit : .fill)
                    .frame(width: halfWidth, height: geo.size.height)
                    .clipped()

                // Right half - image centered in its own space
                Image(uiImage: rightImg)
                    .resizable()
                    .aspectRatio(contentMode: fitImage ? .fit : .fill)
                    .frame(width: halfWidth, height: geo.size.height)
                    .clipped()
            }
            .overlay(alignment: .center) {
                // White divider line in the center
                Rectangle()
                    .fill(.white)
                    .frame(width: 1, height: geo.size.height)
            }
            .overlay {
                // Date labels overlay respecting position
                if showDates {
                    parallelDateLabels(halfWidth: halfWidth, totalHeight: geo.size.height)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.Corner.lg))
    }

    private func parallelDateLabels(halfWidth: CGFloat, totalHeight: CGFloat) -> some View {
        ZStack {
            // Left date
            VStack {
                if datePosition == .topLeft || datePosition == .topCenter || datePosition == .topRight {
                    HStack {
                        if datePosition == .topLeft {
                            dateLabel(text: dateFormat.format(left.date), isLeft: true)
                                .padding(12)
                            Spacer()
                        } else if datePosition == .topCenter {
                            Spacer()
                            dateLabel(text: dateFormat.format(left.date), isLeft: true)
                                .padding(12)
                            Spacer()
                        } else {
                            Spacer()
                            dateLabel(text: dateFormat.format(left.date), isLeft: true)
                                .padding(12)
                        }
                    }
                    .frame(width: halfWidth)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                } else {
                    Spacer()
                    HStack {
                        if datePosition == .bottomLeft {
                            dateLabel(text: dateFormat.format(left.date), isLeft: true)
                                .padding(12)
                            Spacer()
                        } else if datePosition == .bottomCenter {
                            Spacer()
                            dateLabel(text: dateFormat.format(left.date), isLeft: true)
                                .padding(12)
                            Spacer()
                        } else {
                            Spacer()
                            dateLabel(text: dateFormat.format(left.date), isLeft: true)
                                .padding(12)
                        }
                    }
                    .frame(width: halfWidth)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Right date
            VStack {
                if datePosition == .topLeft || datePosition == .topCenter || datePosition == .topRight {
                    HStack {
                        if datePosition == .topLeft {
                            dateLabel(text: dateFormat.format(right.date), isLeft: false)
                                .padding(12)
                            Spacer()
                        } else if datePosition == .topCenter {
                            Spacer()
                            dateLabel(text: dateFormat.format(right.date), isLeft: false)
                                .padding(12)
                            Spacer()
                        } else {
                            Spacer()
                            dateLabel(text: dateFormat.format(right.date), isLeft: false)
                                .padding(12)
                        }
                    }
                    .frame(width: halfWidth)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    Spacer()
                } else {
                    Spacer()
                    HStack {
                        if datePosition == .bottomLeft {
                            dateLabel(text: dateFormat.format(right.date), isLeft: false)
                                .padding(12)
                            Spacer()
                        } else if datePosition == .bottomCenter {
                            Spacer()
                            dateLabel(text: dateFormat.format(right.date), isLeft: false)
                                .padding(12)
                            Spacer()
                        } else {
                            Spacer()
                            dateLabel(text: dateFormat.format(right.date), isLeft: false)
                                .padding(12)
                        }
                    }
                    .frame(width: halfWidth)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func dateLabel(text: String, isLeft: Bool) -> some View {
        Text(text)
            .font(dateFont.font(size: dateFontSize))
            .foregroundColor(dateColor)
            .padding(.horizontal, showDateBackground ? 10 : 0)
            .padding(.vertical, showDateBackground ? 6 : 0)
            .background(
                Group {
                    if showDateBackground {
                        Capsule()
                            .fill(Color.black.opacity(0.6))
                    }
                }
            )
    }

    private func sliderDateLabels() -> some View {
        VStack {
            if datePosition == .topLeft || datePosition == .topCenter || datePosition == .topRight {
                HStack {
                    if datePosition == .topLeft {
                        dateLabel(text: dateFormat.format(left.date), isLeft: true)
                            .padding(12)
                        Spacer()
                        dateLabel(text: dateFormat.format(right.date), isLeft: false)
                            .padding(12)
                    } else if datePosition == .topCenter {
                        Spacer()
                        dateLabel(text: dateFormat.format(left.date), isLeft: true)
                            .padding(12)
                        Spacer()
                        dateLabel(text: dateFormat.format(right.date), isLeft: false)
                            .padding(12)
                        Spacer()
                    } else {
                        dateLabel(text: dateFormat.format(left.date), isLeft: true)
                            .padding(12)
                        Spacer()
                        dateLabel(text: dateFormat.format(right.date), isLeft: false)
                            .padding(12)
                    }
                }
                Spacer()
            } else {
                Spacer()
                HStack {
                    if datePosition == .bottomLeft {
                        dateLabel(text: dateFormat.format(left.date), isLeft: true)
                            .padding(12)
                        Spacer()
                        dateLabel(text: dateFormat.format(right.date), isLeft: false)
                            .padding(12)
                    } else if datePosition == .bottomCenter {
                        Spacer()
                        dateLabel(text: dateFormat.format(left.date), isLeft: true)
                            .padding(12)
                        Spacer()
                        dateLabel(text: dateFormat.format(right.date), isLeft: false)
                            .padding(12)
                        Spacer()
                    } else {
                        dateLabel(text: dateFormat.format(left.date), isLeft: true)
                            .padding(12)
                        Spacer()
                        dateLabel(text: dateFormat.format(right.date), isLeft: false)
                            .padding(12)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func sliderView(leftImg: UIImage, rightImg: UIImage, width: CGFloat, height: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Left image (base layer - always full width, masked to show left of slider)
                Image(uiImage: leftImg)
                    .resizable()
                    .aspectRatio(contentMode: fitImage ? .fit : .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .mask {
                        Rectangle()
                            .frame(width: geo.size.width * sliderPosition)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                // Right image (overlay - always full width, masked to show right of slider)
                Image(uiImage: rightImg)
                    .resizable()
                    .aspectRatio(contentMode: fitImage ? .fit : .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .mask {
                        Rectangle()
                            .frame(width: geo.size.width * (1 - sliderPosition))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                // Divider line (visual only, no interaction)
                ZStack {
                    // Vertical line
                    Rectangle()
                        .fill(.white)
                        .frame(width: 3)
                        .shadow(color: .black.opacity(0.5), radius: 2)

                    // Handle circle
                    Circle()
                        .fill(.white)
                        .frame(width: 44, height: 44)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                        .overlay(
                            Image(systemName: "arrow.left.and.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppStyle.Colors.bgDark)
                        )
                        .position(x: 0, y: geo.size.height / 2)
                }
                .frame(width: 3)
                .offset(x: geo.size.width * sliderPosition - 1.5)
                .allowsHitTesting(false)

                // Slider drag area - only center zone (60pt wide)
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 60)
                    .contentShape(Rectangle())
                    .position(x: geo.size.width * sliderPosition, y: geo.size.height / 2)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { value in
                                isDragging = true
                                // Calculate new position based on drag translation
                                // translation.width is in screen points, so we add it directly to the current position
                                let currentX = geo.size.width * dragStartPosition
                                let newX = currentX + value.translation.width
                                let newPosition = newX / geo.size.width
                                sliderPosition = min(max(newPosition, 0), 1)
                            }
                            .onEnded { _ in
                                isDragging = false
                                // Update drag start position when drag ends
                                dragStartPosition = sliderPosition
                            }
                    )

                // Date labels for slider mode
                if showDates {
                    sliderDateLabels()
                }
            }
        }
        .cornerRadius(AppStyle.Corner.lg)
    }

    private func loadImages() async {
        // Always load from assetLocalId for display (already transformed)

        // Capture values before async operations to avoid Sendable warnings
        let leftLocalId = left.assetLocalId
        let rightLocalId = right.assetLocalId

        // Load both images concurrently
        async let leftTask = PhotoStore.fetchUIImage(localId: leftLocalId, targetSize: CGSize(width: 2400, height: 2400))
        async let rightTask = PhotoStore.fetchUIImage(localId: rightLocalId, targetSize: CGSize(width: 2400, height: 2400))

        // assetLocalId always contains the display-ready images
        leftImg = await leftTask
        rightImg = await rightTask
    }
}
