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
            // Fill background with app's dark color
            ctx.cgContext.setFillColor(UIColor(red: 30/255, green: 32/255, blue: 35/255, alpha: 1.0).cgColor)
            ctx.cgContext.fill(CGRect(origin: .zero, size: outputSize))
            
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
}
