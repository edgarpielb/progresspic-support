//
//  AppConstants.swift
//  ProgressPic
//
//  Created by Claude Code
//

import Foundation
import CoreGraphics

/// Centralized constants used throughout the ProgressPic app
enum AppConstants {

    // MARK: - Cache Configuration
    enum Cache {
        /// Maximum number of images to keep in memory cache
        static let imageCountLimit = 50
        /// Maximum total size of cached images in bytes (100 MB)
        static let imageSizeLimit = 100 * 1024 * 1024
    }

    // MARK: - Photo Export Dimensions
    enum Photo {
        /// Standard export width for saved photos
        static let exportWidth: CGFloat = 1200
        /// Standard export height for saved photos
        static let exportHeight: CGFloat = 1500
        /// Aspect ratio for photo export
        static let aspectRatio: CGFloat = exportWidth / exportHeight
    }

    // MARK: - Camera Settings
    enum Camera {
        /// Default opacity for ghost overlay
        static let defaultGhostOpacity: Double = 0.32
        /// Minimum ghost opacity
        static let minGhostOpacity: Double = 0.0
        /// Maximum ghost opacity
        static let maxGhostOpacity: Double = 1.0
        /// Maximum zoom level
        static let maxZoom: CGFloat = 10.0
        /// Minimum zoom level
        static let minZoom: CGFloat = 1.0
    }

    // MARK: - Video Export Settings
    enum Video {
        /// Default frames per second for video export
        static let defaultFPS: Int = 30
        /// Minimum frames per second
        static let minFPS: Int = 15
        /// Maximum frames per second
        static let maxFPS: Int = 60
        /// Default duration per photo in seconds
        static let defaultPhotoDuration: Double = 0.5
        /// Minimum photo duration
        static let minPhotoDuration: Double = 0.1
        /// Maximum photo duration
        static let maxPhotoDuration: Double = 5.0
    }

    // MARK: - UI Layout
    enum Layout {
        /// Standard horizontal padding for main content
        static let horizontalPadding: CGFloat = 20
        /// Standard corner radius for panels and cards
        static let cornerRadius: CGFloat = 12
        /// Small corner radius for compact elements
        static let smallCornerRadius: CGFloat = 8
        /// Large corner radius for prominent elements
        static let largeCornerRadius: CGFloat = 16
        /// Standard vertical spacing
        static let verticalSpacing: CGFloat = 16
        /// Compact vertical spacing
        static let compactSpacing: CGFloat = 8
        /// Large vertical spacing
        static let largeSpacing: CGFloat = 24
    }

    // MARK: - Animation Durations
    enum Animation {
        /// Standard animation duration in seconds
        static let standard: Double = 0.3
        /// Quick animation duration
        static let quick: Double = 0.2
        /// Slow animation duration
        static let slow: Double = 0.5
    }

    // MARK: - Measurement Settings
    enum Measurement {
        /// Number of decimal places for weight display
        static let weightDecimalPlaces = 1
        /// Number of decimal places for body fat percentage
        static let bodyFatDecimalPlaces = 1
        /// Number of decimal places for measurements in cm
        static let measurementDecimalPlaces = 1
    }

    // MARK: - Streak & Activity
    enum Activity {
        /// Minimum number of photos for streak calculation
        static let minPhotosForStreak = 2
        /// Days threshold for app review prompt
        static let reviewPromptStreakThreshold = 7
        /// Minimum photos required before showing review prompt
        static let reviewPromptMinPhotos = 5
    }

    // MARK: - Date Overlay Settings
    enum DateOverlay {
        /// Default font size for date overlay
        static let defaultFontSize: CGFloat = 48
        /// Minimum font size
        static let minFontSize: CGFloat = 20
        /// Maximum font size
        static let maxFontSize: CGFloat = 120
        /// Default opacity for date overlay
        static let defaultOpacity: Double = 1.0
    }
}
