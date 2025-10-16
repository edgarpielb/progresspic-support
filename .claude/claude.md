# ProgressPic - Project Settings

## Project Overview
ProgressPic is a fitness progress tracking iOS app built with SwiftUI and SwiftData. Users create "journeys" to track their physical transformation through photos and body measurements over time.

## Core Features
- **Journeys**: Create and manage multiple fitness tracking journeys
- **Progress Photos**: Take and store photos with alignment overlays for comparison
- **Measurements**: Track weight, body fat %, and various body measurements
- **Reminders**: Set custom reminders for photo capture and measurements
- **Compare View**: Side-by-side photo comparisons
- **Camera Roll Integration**: Optional saving to photo library

## Architecture
- **Framework**: SwiftUI + SwiftData (local storage only)
- **Data Models**: Journey, ProgressPhoto, MeasurementEntry, JourneyReminder
- **Storage**: Photo Library (PHAsset) + SwiftData for metadata
- **Platform**: iOS native
- **Note**: CloudKit capabilities are configured in entitlements but not currently used (`cloudKitDatabase: .none` in ProgressPicApp.swift)

## Key Components
- `Models.swift` - Core data models and SwiftData schema
- `Services.swift` - Business logic and service layer
- `JourneyView.swift` - Main journey detail view
- `JourneySettingsView.swift` - Journey configuration
- `CameraHostView.swift` - Camera capture interface
- `CompareView.swift` - Photo comparison interface

## Coding Conventions
- Use `AppStyle.Colors` for consistent theming
- Dark mode color scheme: `Color(red: 30/255, green: 32/255, blue: 35/255)`
- SwiftUI view structure with computed properties for sections
- Environment-based navigation (`@Environment(\.dismiss)`)
- SwiftData `@Model` classes for persistence
- Async/await for data operations

## Common Patterns
```swift
// Color scheme
background: Color(red: 30/255, green: 32/255, blue: 35/255)
panel: Color.white.opacity(0.1)
primary text: .white
secondary text: .gray or .white.opacity(0.7)

// Navigation toolbar
.toolbar {
    ToolbarItem(placement: .principal) {
        VStack(spacing: 4) {
            Text("Title").font(.title2).fontWeight(.bold)
            Text("SUBTITLE").font(.caption).tracking(1.2)
        }
    }
}

// Data operations
@Environment(\.modelContext) private var ctx
try? ctx.save()
ctx.processPendingChanges()
```

## User Settings
The app stores:
- `UserProfile` (UserDefaults) - birthDate, heightCm, gender, preferredUnit
- Per-journey settings - saveToCameraRoll, reminders
- Photo alignment transforms per image

## Testing Notes
- Test with Photos library permissions
- Test reminder scheduling with notification permissions
- Test SwiftData persistence locally (no cloud sync currently)
- Test camera capture on device (not simulator)

## Build & Run
- **Xcode Version**: Latest stable
- **Target**: iOS 17.0+
- **Dependencies**: None (native frameworks only)

## Known Areas
- Photo library access via PHAsset
- Reminder scheduling via UNUserNotificationCenter
- SwiftData relationships with cascade delete
- Camera session management
- Transform-based photo alignment

## Style Guide
- Use SF Symbols for icons
- 20pt horizontal padding for main content
- 12pt corner radius for panels
- NavigationView/NavigationStack for navigation
- Sheet presentations for modal forms
- Alert for destructive actions
