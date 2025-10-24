import SwiftUI
import UIKit

/// Centralized transform rendering utilities to ensure consistent image display across the app
struct TransformRenderer {
    
    /// Renders an image with the exact same transform logic as the SwiftUI adjust view
    /// This ensures that what the user sees in adjust view appears everywhere else
    static func renderTransformedImage(
        sourceImage: UIImage,
        transform: AlignTransform,
        targetSize: CGSize? = nil,
        adjustViewSize: CGSize? = nil  // The size of the crop frame in adjust view
    ) -> UIImage {
        // Use provided size or default to a standard 4:5 output
        let outputSize: CGSize
        if let targetSize = targetSize {
            // Ensure 4:5 aspect ratio
            outputSize = CGSize(width: targetSize.width, height: targetSize.width * 5.0 / 4.0)
        } else {
            // Default high-quality output
            outputSize = CGSize(width: 1200, height: 1500)
        }
        
        // Default adjust view size (iPhone screen width typically ~390)
        // This is the reference size where transforms were recorded
        let referenceSize = adjustViewSize ?? CGSize(width: 390, height: 487.5) // 4:5 ratio
        
        // Calculate scale factor between reference size and output size
        let scaleFactor = outputSize.width / referenceSize.width
        
        print("🎨 TransformRenderer: outputSize=\(outputSize)")
        print("🎨 TransformRenderer: sourceImage=\(sourceImage.size)")
        print("🎨 TransformRenderer: referenceSize=\(referenceSize)")
        print("🎨 TransformRenderer: scaleFactor=\(scaleFactor)")
        print("🎨 TransformRenderer: original transform scale=\(transform.scale), offset=(\(transform.offsetX), \(transform.offsetY)), rotation=\(transform.rotation)")
        
        // Scale the offsets to match output size
        let scaledOffsetX = transform.offsetX * scaleFactor
        let scaledOffsetY = transform.offsetY * scaleFactor
        
        print("🎨 TransformRenderer: scaled offset=(\(scaledOffsetX), \(scaledOffsetY))")
        
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        return renderer.image { ctx in
            // Draw blurred background first (fills entire output area)
            drawBlurredBackground(
                sourceImage: sourceImage,
                in: ctx.cgContext,
                size: outputSize
            )

            // Calculate how the image fits within the crop (matching SwiftUI's scaledToFit logic)
            let imageAspect = sourceImage.size.width / sourceImage.size.height
            let canvasAspect = outputSize.width / outputSize.height  // Always 4:5 = 0.8
            
            var fitSize: CGSize
            if imageAspect > canvasAspect {
                // Image is wider than crop - fit by width
                fitSize = CGSize(width: outputSize.width, height: outputSize.width / imageAspect)
            } else {
                // Image is taller than crop - fit by height  
                fitSize = CGSize(width: outputSize.height * imageAspect, height: outputSize.height)
            }
            
            print("🎨 TransformRenderer: fitSize=\(fitSize)")
            
            // Move to center of the output
            ctx.cgContext.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
            
            // Apply user transforms matching SwiftUI order
            // SwiftUI: scale THEN offset THEN rotate
            // Core Graphics: We need to apply in REVERSE order for the same visual result
            
            ctx.cgContext.rotate(by: CGFloat(transform.rotation))
            
            // Use SCALED offsets for the output size
            ctx.cgContext.translateBy(x: scaledOffsetX, y: scaledOffsetY)
            
            // Scale is applied last in CG (first in SwiftUI)
            let safeScale = max(transform.scale, 0.001)
            ctx.cgContext.scaleBy(x: safeScale, y: safeScale)
            
            // Draw the fitted image centered
            let drawRect = CGRect(
                x: -fitSize.width / 2,
                y: -fitSize.height / 2,
                width: fitSize.width,
                height: fitSize.height
            )
            
            print("🎨 TransformRenderer: drawRect=\(drawRect)")
            
            sourceImage.draw(in: drawRect)
        }
    }
    
    /// Renders a thumbnail with proper transform application
    /// Optimized for grid views and smaller displays
    static func renderThumbnail(
        sourceImage: UIImage,
        transform: AlignTransform,
        thumbnailWidth: CGFloat
    ) -> UIImage {
        // Calculate 4:5 height
        let thumbnailSize = CGSize(
            width: thumbnailWidth * UIScreen.main.scale,  // Account for retina
            height: thumbnailWidth * UIScreen.main.scale * 5.0 / 4.0
        )
        
        return renderTransformedImage(
            sourceImage: sourceImage,
            transform: transform,
            targetSize: thumbnailSize
        )
    }
    
    /// Check if a transform has any modifications
    static func isIdentityTransform(_ transform: AlignTransform) -> Bool {
        return transform.scale == 1.0 &&
               transform.offsetX == 0 &&
               transform.offsetY == 0 &&
               transform.rotation == 0
    }

    /// Draws a blurred, scaled version of the source image as background
    /// This creates a more natural look when the image doesn't fill the crop area
    private static func drawBlurredBackground(
        sourceImage: UIImage,
        in context: CGContext,
        size: CGSize
    ) {
        // Create a blurred version of the image
        guard let ciImage = CIImage(image: sourceImage) else {
            // Fallback to dark background if blur fails
            context.setFillColor(UIColor(red: 30/255, green: 32/255, blue: 35/255, alpha: 1.0).cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            return
        }

        // Apply Gaussian blur
        let blurFilter = CIFilter(name: "CIGaussianBlur")
        blurFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        blurFilter?.setValue(40.0, forKey: kCIInputRadiusKey) // Strong blur

        guard let blurredCIImage = blurFilter?.outputImage else {
            // Fallback to dark background if blur fails
            context.setFillColor(UIColor(red: 30/255, green: 32/255, blue: 35/255, alpha: 1.0).cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            return
        }

        // Render the blurred image
        let ciContext = CIContext(options: [.useSoftwareRenderer: false])

        // Scale the blurred image to fill the entire output size while maintaining aspect
        let imageAspect = ciImage.extent.width / ciImage.extent.height
        let outputAspect = size.width / size.height

        var scaledSize: CGSize
        var drawRect: CGRect

        if imageAspect > outputAspect {
            // Image is wider - scale to fill height
            scaledSize = CGSize(width: size.height * imageAspect, height: size.height)
            drawRect = CGRect(
                x: -(scaledSize.width - size.width) / 2,
                y: 0,
                width: scaledSize.width,
                height: scaledSize.height
            )
        } else {
            // Image is taller - scale to fill width
            scaledSize = CGSize(width: size.width, height: size.width / imageAspect)
            drawRect = CGRect(
                x: 0,
                y: -(scaledSize.height - size.height) / 2,
                width: scaledSize.width,
                height: scaledSize.height
            )
        }

        // Create CGImage from blurred CIImage
        if let cgImage = ciContext.createCGImage(blurredCIImage, from: blurredCIImage.extent) {
            // Darken the background with a semi-transparent overlay
            context.saveGState()

            // Draw the blurred image
            context.draw(cgImage, in: drawRect)

            // Add dark overlay to make it more subtle
            context.setFillColor(UIColor.black.withAlphaComponent(0.4).cgColor)
            context.fill(CGRect(origin: .zero, size: size))

            context.restoreGState()
        } else {
            // Fallback to dark background
            context.setFillColor(UIColor(red: 30/255, green: 32/255, blue: 35/255, alpha: 1.0).cgColor)
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
