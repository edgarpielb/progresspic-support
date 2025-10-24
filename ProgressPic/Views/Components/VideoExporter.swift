import SwiftUI
import SwiftData
import Photos
import AVFoundation
// MARK: - Video Exporter
actor VideoExporter {
    static func exportProgressVideo(
        photos: [ProgressPhoto],
        journeyName: String,
        playbackSpeed: Double = 1.0,
        progressCallback: @escaping (Double) -> Void
    ) async -> URL? {
        guard !photos.isEmpty else { return nil }

        // Configuration
        let fps = 30
        let frameDuration: Double = 1.0 / playbackSpeed  // Duration per photo based on speed
        let framesPerPhoto = Int(frameDuration * Double(fps))
        let resolution = CGSize(width: 1080, height: 1350)  // 4:5 aspect ratio
        
        // Create temp file
        let tempDir = FileManager.default.temporaryDirectory
        let timestamp = Date().timeIntervalSince1970
        let outputURL = tempDir.appendingPathComponent("progress_\(journeyName)_\(Int(timestamp)).mp4")
        
        // Remove if exists
        try? FileManager.default.removeItem(at: outputURL)
        
        guard let videoWriter = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            return nil
        }
        
        // Video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: resolution.width,
            AVVideoHeightKey: resolution.height
        ]
        
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: resolution.width,
                kCVPixelBufferHeightKey as String: resolution.height
            ]
        )
        
        guard videoWriter.canAdd(videoInput) else { return nil }
        videoWriter.add(videoInput)
        
        guard videoWriter.startWriting() else { return nil }
        videoWriter.startSession(atSourceTime: .zero)
        
        var frameCount = 0
        let totalFrames = photos.count * framesPerPhoto
        
        // Write frames
        for photo in photos {
            // Always load from assetLocalId for display (already transformed)
            guard let image = await PhotoStore.fetchUIImage(localId: photo.assetLocalId, targetSize: CGSize(width: 2400, height: 2400)) else {
                continue
            }

            // assetLocalId already contains the transformed image
            // Just resize to target resolution if needed
            let transformedImage = image

            // Render this image for the required number of frames
            for _ in 0..<framesPerPhoto {
                while !videoInput.isReadyForMoreMediaData {
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }

                let presentationTime = CMTime(value: Int64(frameCount), timescale: Int32(fps))

                if let pixelBuffer = createPixelBuffer(from: transformedImage, size: resolution) {
                    adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                }

                frameCount += 1

                // Update progress
                let progress = Double(frameCount) / Double(totalFrames)
                progressCallback(progress)
            }
        }
        
        videoInput.markAsFinished()
        await videoWriter.finishWriting()
        
        return videoWriter.status == .completed ? outputURL : nil
    }

    // Removed - now using TransformRenderer.renderTransformedImage

    private static func createPixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        
        guard let ctx = context, let cgImage = image.cgImage else {
            return nil
        }
        
        // Fill background
        ctx.setFillColor(UIColor(red: 30/255, green: 32/255, blue: 35/255, alpha: 1.0).cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        
        // Calculate letterbox rect
        let imageAspect = image.size.width / image.size.height
        let targetAspect = size.width / size.height
        
        let drawRect: CGRect
        if imageAspect > targetAspect {
            // Image is wider - fit width
            let height = size.width / imageAspect
            drawRect = CGRect(x: 0, y: (size.height - height) / 2, width: size.width, height: height)
        } else {
            // Image is taller - fit height
            let width = size.height * imageAspect
            drawRect = CGRect(x: (size.width - width) / 2, y: 0, width: width, height: size.height)
        }
        
        ctx.draw(cgImage, in: drawRect)
        
        return buffer
    }
}
