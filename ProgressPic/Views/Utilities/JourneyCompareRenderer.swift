import SwiftUI
import UIKit

/// Utilities for rendering journey comparison images for sharing
struct JourneyCompareRenderer {

    /// Renders a comparison image from two photos with the specified settings
    static func renderComparisonImage(
        leftImg: UIImage,
        rightImg: UIImage,
        size: CGSize,
        mode: JourneyCompareView.CompareMode,
        fitImage: Bool,
        showDates: Bool,
        leftDate: Date,
        rightDate: Date,
        dateFormat: DateFormat,
        dateFontSize: DateFontSize,
        dateColor: Color,
        datePosition: DatePosition,
        showDateBackground: Bool,
        sliderPosition: CGFloat
    ) async -> UIImage? {
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

            if mode == .parallel {
                drawParallelMode(
                    context: context,
                    leftImg: leftImg,
                    rightImg: rightImg,
                    size: size,
                    fitImage: fitImage
                )
            } else {
                drawSliderMode(
                    context: context,
                    leftImg: leftImg,
                    rightImg: rightImg,
                    size: size,
                    fitImage: fitImage,
                    sliderPosition: sliderPosition
                )
            }

            // Reset coordinate system for drawing dates
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: 0, y: -size.height)

            // Draw dates if enabled
            if showDates {
                drawDates(
                    context: context,
                    size: size,
                    leftDate: leftDate,
                    rightDate: rightDate,
                    dateFormat: dateFormat,
                    datePosition: datePosition,
                    dateFontSize: dateFontSize,
                    dateColor: dateColor,
                    showDateBackground: showDateBackground,
                    isSlider: mode == .slider
                )
            }

            return UIGraphicsGetImageFromCurrentImageContext()
        }.value
    }

    // MARK: - Drawing Modes

    private static func drawParallelMode(
        context: CGContext,
        leftImg: UIImage,
        rightImg: UIImage,
        size: CGSize,
        fitImage: Bool
    ) {
        let halfWidth = size.width / 2

        // Draw left image
        if let leftCGImage = leftImg.cgImage {
            context.saveGState()
            let leftClip = CGRect(x: 0, y: 0, width: halfWidth, height: size.height)
            context.clip(to: leftClip)

            let drawRect = calculateDrawRect(
                imageSize: CGSize(width: leftCGImage.width, height: leftCGImage.height),
                targetSize: CGSize(width: halfWidth, height: size.height),
                fitImage: fitImage,
                offsetX: 0
            )
            context.draw(leftCGImage, in: drawRect)
            context.restoreGState()
        }

        // Draw right image
        if let rightCGImage = rightImg.cgImage {
            context.saveGState()
            let rightClip = CGRect(x: halfWidth, y: 0, width: halfWidth, height: size.height)
            context.clip(to: rightClip)

            let drawRect = calculateDrawRect(
                imageSize: CGSize(width: rightCGImage.width, height: rightCGImage.height),
                targetSize: CGSize(width: halfWidth, height: size.height),
                fitImage: fitImage,
                offsetX: halfWidth
            )
            context.draw(rightCGImage, in: drawRect)
            context.restoreGState()
        }

        // Draw white divider line
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: halfWidth - 0.5, y: 0, width: 1, height: size.height))
    }

    private static func drawSliderMode(
        context: CGContext,
        leftImg: UIImage,
        rightImg: UIImage,
        size: CGSize,
        fitImage: Bool,
        sliderPosition: CGFloat
    ) {
        let dividerX = size.width * sliderPosition

        // Draw RIGHT image (visible on LEFT side of slider - before divider)
        if let rightCGImage = rightImg.cgImage {
            context.saveGState()
            let leftClip = CGRect(x: 0, y: 0, width: dividerX, height: size.height)
            context.clip(to: leftClip)

            let drawRect = calculateDrawRect(
                imageSize: CGSize(width: rightCGImage.width, height: rightCGImage.height),
                targetSize: size,
                fitImage: fitImage,
                offsetX: 0
            )
            context.draw(rightCGImage, in: drawRect)
            context.restoreGState()
        }

        // Draw LEFT image (visible on RIGHT side of slider - after divider)
        if let leftCGImage = leftImg.cgImage {
            context.saveGState()
            let rightClip = CGRect(x: dividerX, y: 0, width: size.width - dividerX, height: size.height)
            context.clip(to: rightClip)

            let drawRect = calculateDrawRect(
                imageSize: CGSize(width: leftCGImage.width, height: leftCGImage.height),
                targetSize: size,
                fitImage: fitImage,
                offsetX: 0
            )
            context.draw(leftCGImage, in: drawRect)
            context.restoreGState()
        }

        // Draw white divider line
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: dividerX - 0.5, y: 0, width: 1, height: size.height))
    }

    // MARK: - Helper Methods

    private static func calculateDrawRect(
        imageSize: CGSize,
        targetSize: CGSize,
        fitImage: Bool,
        offsetX: CGFloat
    ) -> CGRect {
        let imageAspect = imageSize.width / imageSize.height
        let targetAspect = targetSize.width / targetSize.height

        if fitImage {
            // Fit mode - show entire image
            if imageAspect > targetAspect {
                let drawHeight = targetSize.width / imageAspect
                return CGRect(
                    x: offsetX,
                    y: (targetSize.height - drawHeight) / 2,
                    width: targetSize.width,
                    height: drawHeight
                )
            } else {
                let drawWidth = targetSize.height * imageAspect
                return CGRect(
                    x: offsetX + (targetSize.width - drawWidth) / 2,
                    y: 0,
                    width: drawWidth,
                    height: targetSize.height
                )
            }
        } else {
            // Fill mode - crop to fill entire area
            if imageAspect > targetAspect {
                let drawWidth = targetSize.height * imageAspect
                return CGRect(
                    x: offsetX - (drawWidth - targetSize.width) / 2,
                    y: 0,
                    width: drawWidth,
                    height: targetSize.height
                )
            } else {
                let drawHeight = targetSize.width / imageAspect
                return CGRect(
                    x: offsetX,
                    y: -(drawHeight - targetSize.height) / 2,
                    width: targetSize.width,
                    height: drawHeight
                )
            }
        }
    }

    // MARK: - Date Drawing

    private static func drawDates(
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
