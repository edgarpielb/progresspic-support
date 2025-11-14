# ProgressPic - Comprehensive Project Documentation for AI Assistants

**Last Updated**: 2025-11-14
**iOS Version**: 17.0+
**Swift Version**: 5.0+
**Architecture**: SwiftUI + SwiftData + iCloud CloudKit

---

## Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Directory Structure](#directory-structure)
4. [Data Models](#data-models)
5. [Services & Utilities](#services--utilities)
6. [Views & Components](#views--components)
7. [Development Workflows](#development-workflows)
8. [Coding Conventions](#coding-conventions)
9. [Key Features](#key-features)
10. [Performance Considerations](#performance-considerations)
11. [Testing Guidelines](#testing-guidelines)
12. [Common Patterns](#common-patterns)
13. [Troubleshooting](#troubleshooting)

---

## Project Overview

ProgressPic is a sophisticated fitness progress tracking iOS app that enables users to document their physical transformation through photos and body measurements. Built with modern Apple frameworks, it emphasizes performance, user experience, and data persistence with iCloud synchronization.

### Core Value Proposition
- **Visual Progress Tracking**: Photo-based journey documentation with alignment tools
- **Measurement Tracking**: Comprehensive body metrics with HealthKit integration
- **Smart Comparisons**: Advanced photo overlay and side-by-side comparison tools
- **Cross-Device Sync**: iCloud CloudKit automatic synchronization
- **Privacy First**: All data stored locally with optional iCloud sync

---

## Architecture

### Pattern: MVVM (Model-View-ViewModel) with Modern SwiftUI

```
┌─────────────────────────────────────────────────────────────┐
│                         SwiftUI Views                        │
│  (ContentView, JourneyView, CameraHostView, ActivityView)   │
└────────────────────┬────────────────────────────────────────┘
                     │ @Query, @State, @Environment
┌────────────────────┴────────────────────────────────────────┐
│                      ViewModels & Services                   │
│    (CameraViewModel, PhotoStore, HealthKitService, etc.)    │
└────────────────────┬────────────────────────────────────────┘
                     │ SwiftData operations
┌────────────────────┴────────────────────────────────────────┐
│                      SwiftData Models                        │
│     (Journey, ProgressPhoto, MeasurementEntry, etc.)        │
└────────────────────┬────────────────────────────────────────┘
                     │ CloudKit sync
┌────────────────────┴────────────────────────────────────────┐
│                    iCloud CloudKit Database                  │
│              (Automatic cross-device sync)                   │
└──────────────────────────────────────────────────────────────┘
```

### Key Architectural Principles

1. **Reactive State Management**: SwiftUI property wrappers (`@Published`, `@State`, `@Query`)
2. **Service-Oriented**: Dedicated services for cross-cutting concerns
3. **iCloud Sync Enabled**: CloudKit automatic synchronization (`cloudKitDatabase: .automatic`)
4. **Separation of Concerns**: Models, Views, ViewModels, Services clearly separated
5. **Centralized Configuration**: `AppConstants` and `AppStyle` for consistency
6. **Performance First**: Caching, indexing, and memory optimization throughout

### Technology Stack

- **SwiftUI**: Declarative UI framework
- **SwiftData**: Modern persistence layer (replacing CoreData)
- **CloudKit**: iCloud synchronization
- **AVFoundation**: Camera management
- **HealthKit**: Body composition integration
- **Photos Framework**: Photo library integration
- **UserNotifications**: Reminder scheduling
- **CoreImage**: Image processing and filters

**Note**: No third-party dependencies - pure Apple frameworks

---

## Directory Structure

```
ProgressPic/
├── Models/                          # Data models and core services
│   ├── Models.swift                 # SwiftData models (356 lines)
│   ├── ProgressPicApp.swift         # App entry point with container setup
│   ├── PhotoStore.swift             # Photo loading and caching (446 lines)
│   ├── CameraService.swift          # AVFoundation camera (560 lines)
│   ├── HealthKitService.swift       # HealthKit integration (301 lines)
│   ├── ReviewAndReminderServices.swift # App review & notifications (116 lines)
│   ├── ExportService.swift          # CSV export (167 lines)
│   ├── AppConstants.swift           # Centralized constants (137 lines)
│   ├── AppStyle.swift               # Design tokens (121 lines)
│   └── Glass.swift                  # Reusable glass UI components (72 lines)
│
├── ViewModels/                      # View state management
│   └── CameraViewModel.swift        # Camera business logic (178 lines)
│
├── Views/                           # SwiftUI views
│   ├── ContentView.swift            # Root TabView (147 lines)
│   ├── JourneyView.swift            # Journey detail and photo grid
│   ├── ActivityView.swift           # Activity/streak tracking
│   ├── CameraHostView.swift         # Camera interface
│   ├── AdjustView.swift             # Photo alignment/adjustment
│   ├── MeasurementDetailView.swift  # Measurement charts
│   ├── BodyCompositionDetailView.swift # Body composition charts
│   ├── UserProfileDetailView.swift  # User profile
│   ├── JourneySettingsView.swift    # Journey settings
│   ├── SettingsView.swift           # App settings (101 lines)
│   │
│   ├── Components/                  # Reusable view components
│   │   ├── CompareCanvas.swift      # Photo comparison canvas
│   │   ├── CompareViewModifiers.swift # Comparison modifiers
│   │   ├── DateOverlaySettings.swift # Date overlay config
│   │   ├── JourneyComparisonViews.swift # Comparison UI
│   │   ├── JourneyPhotoComponents.swift # Photo grid items
│   │   ├── JourneyWatchViews.swift  # Photo slideshow
│   │   ├── PhotoAdjustSheet.swift   # Photo adjustment
│   │   ├── PhotoEditViews.swift     # Photo editing UI
│   │   ├── VideoExporter.swift      # Video export
│   │   └── Generic/                 # Generic reusable components
│   │       ├── EmptyStateView.swift # Empty/loading states (99 lines)
│   │       └── (other generic components)
│   │
│   ├── Sheets/                      # Modal sheets
│   │   ├── OnboardingView.swift     # First-time onboarding
│   │   ├── NewJourneySheet.swift    # Create journey
│   │   ├── AddMeasurementSheet.swift # Add measurement
│   │   ├── BulkMeasurementSheet.swift # Bulk entry
│   │   ├── EditReminderView.swift   # Reminder editor
│   │   ├── UserProfileSetupView.swift # Profile setup
│   │   └── YearCalendarSheet.swift  # Calendar view
│   │
│   └── Utilities/                   # View-specific utilities
│       ├── ShareUtilities.swift     # Share sheet helpers (517 lines)
│       ├── PhotoImportUtilities.swift # Photo import logic
│       ├── ChartAggregationHelpers.swift # Chart data processing
│       ├── ChartXAxisHelpers.swift  # Chart X-axis generation (4,557 lines)
│       └── TransformRenderingUtilities.swift # Image transforms
│
├── Utilities/                       # App-wide utilities
│   ├── HapticFeedback.swift         # Centralized haptics (53 lines)
│   ├── DateFormatters.swift         # Cached date formatters (136 lines)
│   └── StatsFormatters.swift        # Statistics formatting (160 lines)
│
└── Resources/                       # Assets and configuration
    ├── Assets.xcassets/             # Images and colors
    ├── ProgressPicInfo.plist        # App configuration
    └── ProgressPic.entitlements     # Capabilities
```

**Total**: ~8,982 lines of Swift code across 51 files

---

## Data Models

### SwiftData Schema (`Models.swift`)

The app uses **SwiftData** with **iCloud CloudKit sync enabled**:

```swift
let schema = Schema([
    Journey.self,
    ProgressPhoto.self,
    MeasurementEntry.self,
    JourneyReminder.self
])

ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    allowsSave: true,
    cloudKitDatabase: .automatic  // ⚠️ iCloud sync enabled
)
```

### Core Models

#### 1. Journey
Represents a progress tracking journey.

**Properties**:
- `id: UUID` - Unique identifier
- `name: String` - Journey name
- `createdAt: Date` - Creation timestamp
- `saveToCameraRoll: Bool` - Auto-save to camera roll
- `autoSyncStartDate: Date?` - HealthKit sync start date
- `template: String?` - Journey template (weight loss, muscle gain, etc.)
- `sortOrder: Int` - Manual ordering
- `photoCount: Int` - Cached photo count (performance optimization)

**Relationships**:
- `photos: [ProgressPhoto]` (cascade delete)
- `measurements: [MeasurementEntry]` (cascade delete)
- `reminders: [JourneyReminder]` (cascade delete)

**File**: `Models.swift:23-88`

#### 2. ProgressPhoto
Stores photo metadata and alignment data.

**Properties**:
- `id: UUID` - Unique identifier
- `journeyId: UUID` - Parent journey
- `date: Date` - Photo timestamp
- `assetLocalId: String` - Photo file UUID (in app directory)
- `originalAssetLocalId: String?` - Original uncropped photo UUID
- `isFrontCamera: Bool` - Camera orientation
- `alignTransform: AlignTransform?` - Alignment data
- `notes: String` - User notes
- `isHidden: Bool` - Hidden from Watch/Compare

**Indexes** (performance optimized):
- `#Index([\.journeyId, \.date])`
- `#Index([\.journeyId])`
- `#Index([\.date])`

**File**: `Models.swift:90-187`

#### 3. MeasurementEntry
Body measurement data.

**Properties**:
- `id: UUID`
- `journeyId: UUID`
- `date: Date`
- `typeRaw: String` - Measurement type (weight, bodyFat, chest, etc.)
- `value: Double` - Measurement value
- `unitRaw: String` - Unit (kg, lb, cm, inch, %)
- `label: String?` - Optional label (e.g., "Left" or "Right" for limbs)

**Indexes**:
- `#Index([\.journeyId, \.date])`
- `#Index([\.journeyId, \.typeRaw])`

**File**: `Models.swift:189-317`

#### 4. JourneyReminder
Scheduled notifications for photo reminders.

**Properties**:
- `id: UUID`
- `hour: Int` - Hour (0-23)
- `minute: Int` - Minute (0-59)
- `daysBitmask: Int` - Days of week (bit flags)
- `notificationText: String` - Notification message

**File**: `Models.swift:319-351`

### Supporting Types

#### AlignTransform (Codable struct)
Photo alignment data for overlay comparisons.

**Properties**:
- `scale: CGFloat` - Zoom level
- `offsetX: CGFloat` - Horizontal offset
- `offsetY: CGFloat` - Vertical offset
- `rotation: Angle` - Rotation angle

#### UserProfile (Codable struct)
User preferences stored in UserDefaults.

**Properties**:
- `birthDate: Date?`
- `heightCm: Double?`
- `gender: String?`
- `preferredUnit: String` - "metric" or "imperial"
- `colorScheme: String` - "cyan" or "pink"

### Storage Strategy

1. **Metadata**: SwiftData (synced via CloudKit)
   - Journey information
   - Photo metadata (dates, transforms, notes)
   - Measurements
   - Reminders

2. **Photo Files**: Local app directory (`Documents/Photos/`)
   - Stored as JPEG files (`{UUID}.jpg`)
   - NOT synced via iCloud (deliberate design choice)
   - Both original and cropped versions stored

3. **User Preferences**: UserDefaults
   - User profile
   - Onboarding status
   - Review request tracking

---

## Services & Utilities

### Core Services (`Models/`)

#### PhotoStore (Static Service)
Handles all photo loading, caching, and storage operations.

**Key Features**:
- NSCache for in-memory image caching (50 image limit, 100MB size)
- Downsampling for memory efficiency
- App directory storage management
- EXIF date extraction
- Targeted cache invalidation

**Important Methods**:
- `fetchUIImage(assetId:targetSize:) async -> UIImage?` - Load photo with downsampling
- `savePhoto(_:assetId:) async -> Bool` - Save photo to app directory
- `invalidateCache(for:)` - Invalidate single photo cache
- `prefetchImages(assetIds:targetSize:)` - Prefetch for scrolling

**File**: `Models/PhotoStore.swift:1-446`

#### CameraService (ObservableObject)
Manages AVFoundation camera session.

**Key Features**:
- Front/back camera switching
- Multi-camera support (wide, ultra-wide)
- Zoom levels (0.5x, 1x, 2x)
- Flash modes (on, off, auto)
- Photo capture with proper orientation
- Lifecycle management (start/stop optimization)

**Important Properties**:
- `@Published var session: AVCaptureSession`
- `@Published var capturedPhoto: UIImage?`
- `@Published var isCapturing: Bool`

**Important Methods**:
- `start()` - Initialize camera session
- `stop()` - Clean up camera session
- `flipCamera()` - Switch front/back
- `capturePhoto()` - Take photo
- `setZoomLevel(_:)` - Set zoom (0.5, 1.0, 2.0)

**File**: `Models/CameraService.swift:1-560`

#### HealthKitService (Singleton)
HealthKit integration for body composition data.

**Key Features**:
- Read/write body composition (weight, body fat %, BMI, lean mass)
- Historical data queries
- Authorization management

**Important Methods**:
- `requestAuthorization() async -> Bool`
- `fetchRecentData(for:limit:) async -> [(date: Date, value: Double)]`
- `saveToHealthKit(type:value:date:unit:) async -> Bool`

**File**: `Models/HealthKitService.swift:1-301`

#### ExportService (Static)
CSV export functionality.

**Supported Formats**:
- List format (chronological)
- Grouped by type

**File**: `Models/ExportService.swift:1-167`

#### ReviewAndReminderServices (Static)
App review prompts and notification scheduling.

**Review Triggers**:
- 3, 7, 14 day streaks

**Notification Features**:
- Day-of-week selection
- Custom notification text
- Permission management

**File**: `Models/ReviewAndReminderServices.swift:1-116`

### Utilities (`Utilities/`)

#### HapticFeedback (Static)
Centralized haptic feedback API.

**Usage**:
```swift
// Instead of:
// let generator = UIImpactFeedbackGenerator(style: .medium)
// generator.impactOccurred()

// Use:
HapticFeedback.medium()
HapticFeedback.success()
HapticFeedback.warning()
```

**Methods**:
- `impact(_:intensity:)` - Impact feedback
- `notification(_:)` - Notification feedback
- `selection()` - Selection feedback
- Convenience: `light()`, `medium()`, `heavy()`, `success()`, `warning()`, `error()`

**File**: `Utilities/HapticFeedback.swift:1-53`

#### DateFormatters (Static)
Cached DateFormatter instances to avoid expensive recreation.

**Cached Formatters**:
- `fullDate` - "January 15, 2025"
- `shortDate` - "1/15/25"
- `monthYear` - "January 2025"
- `dayMonthYear` - "15 Jan 2025"
- `time` - "2:30 PM"
- `relative` - Relative date formatting

**Important Methods**:
- `formatFullDate(_:)` - Format with full date formatter
- `formatShortDate(_:)` - Format with short date formatter
- `formatDateRange(from:to:)` - Format date range
- `parseEXIFDateString(_:)` - Parse EXIF dates

**File**: `Utilities/DateFormatters.swift:1-136`

#### StatsFormatters (Static)
Generic statistics calculation and formatting.

**Important Methods**:
```swift
// Generic via KeyPath
let min = StatsFormatters.formatMin(data, valueKeyPath: \.value, unit: "kg")
let max = StatsFormatters.formatMax(data, valueKeyPath: \.value, unit: "kg")
let avg = StatsFormatters.formatAverage(data, valueKeyPath: \.value, unit: "kg")
let range = StatsFormatters.formatRange(data, valueKeyPath: \.value, unit: "kg")

// Chart domain calculation
let domain = StatsFormatters.calculateYDomain(data, valueKeyPath: \.value)
```

**File**: `Utilities/StatsFormatters.swift:1-160`

### View Utilities (`Views/Utilities/`)

#### ChartXAxisHelpers (Protocol-Oriented)
Generates X-axis dates and labels for time-based charts.

**Protocol**: `Dated` - Types with a `date` property

**Methods**:
```swift
// Generate all X-axis dates
let dates = ChartXAxisHelpers.getAllXAxisDates(
    for: .month,
    filteredData: entries,
    calendar: .current
)

// Get formatted labels
let labels = ChartXAxisHelpers.getXAxisValues(for: .week, ...)

// Format individual label
let label = ChartXAxisHelpers.formatXAxisLabel(date, timeRange: .month)
```

**File**: `Views/Utilities/ChartXAxisHelpers.swift:1-4557`

#### TransformRenderingUtilities (Image Processing)
Photo transformation rendering with blur caching.

**Key Features**:
- Shared `CIContext` for performance
- NSCache for blurred backgrounds
- Efficient blur computation (radius=50 Gaussian)

**Important Methods**:
- `drawBlurredBackground(...)` - Render blurred background (cached)
- `clearBlurCache()` - Clear all blur cache
- `invalidateBlurCache(for:)` - Invalidate specific photo

**File**: `Views/Utilities/TransformRenderingUtilities.swift`

---

## Views & Components

### Main Views

#### ContentView
Root TabView with 3 tabs.

**Tabs**:
1. Journeys (NavigationStack)
2. Camera (CameraHostView)
3. Activity (ActivityView)

**File**: `Views/ContentView.swift:1-147`

#### JourneyView
Main journey detail view with photo grid and timeline.

**Features**:
- Photo grid with lazy loading
- Edit mode (multi-select, delete)
- Navigation to photo editor, settings, measurements
- Pull-to-refresh

**File**: `Views/JourneyView.swift`

#### CameraHostView
Camera interface with ghost overlay.

**Features**:
- Front/back camera switch
- Zoom controls (0.5x, 1x, 2x)
- Flash modes
- Ghost overlay (last or first photo)
- Timer (3s, 5s, 10s)
- Grid overlay
- 4:5 aspect ratio (1200x1500px)

**File**: `Views/CameraHostView.swift`

#### ActivityView
Streak tracking and activity calendar.

**Features**:
- Current streak display
- Best streak tracking
- Activity heatmap
- Calendar navigation

**File**: `Views/ActivityView.swift`

### Component Views

#### EmptyStateView & LoadingStateView
Reusable empty and loading state components.

**Usage**:
```swift
EmptyStateView(
    icon: "photo.on.rectangle.angled",
    title: "No Photos Yet",
    message: "Add your first photo to start tracking progress"
)

LoadingStateView(message: "Loading photos...", scale: 1.2)
```

**Features**:
- Consistent styling
- Built-in accessibility
- Customizable icons and messages

**File**: `Views/Components/Generic/EmptyStateView.swift:1-99`

#### JourneyComparisonViews
Side-by-side and overlay photo comparisons.

**Modes**:
- Side-by-side
- Overlay with opacity slider
- Before/after views

**File**: `Views/Components/JourneyComparisonViews.swift`

#### JourneyWatchViews
Photo slideshow with timelapse functionality.

**Key Optimization**: Sliding window approach (max 20 photos in memory)

**Features**:
- Playback speed control
- Video export
- Memory efficient

**File**: `Views/Components/JourneyWatchViews.swift`

#### PhotoEditViews
Photo editing interface.

**Features**:
- Navigation (previous/next)
- Date editing
- Notes
- Adjustment tools
- Delete functionality
- Accessibility labels

**File**: `Views/Components/PhotoEditViews.swift`

---

## Development Workflows

### Git Workflow

**Branch Naming Convention**:
- Feature branches: `claude/{description}-{sessionId}`
- Example: `claude/analyze-progresspic-codebase-011CUvFtPjCSGjPL8MjSxFaH`

**Commit Messages**:
- Clear, concise, action-oriented
- Focus on "why" not just "what"
- Examples from recent history:
  - "Fix critical bugs, optimize performance, and improve code quality"
  - "Add code quality enhancements and utility files"
  - "Complete HapticFeedback utility integration across all views"

**Push Requirements**:
- Always use: `git push -u origin <branch-name>`
- Branch must start with `claude/` and match session ID
- Network failures: retry up to 4 times with exponential backoff (2s, 4s, 8s, 16s)

### Pull Request Workflow

**PR Creation**:
Use `/push` slash command which handles:
1. Check git status
2. Stage changes
3. Create commit
4. Push to remote
5. Create PR via `gh pr create`

**PR Format**:
```markdown
## Summary
- Bullet point summary of changes
- Focus on user-facing impact
- Mention any breaking changes

## Test Plan
- [ ] Manual testing completed
- [ ] Edge cases verified
- [ ] Performance tested
```

### Build & Test

**Xcode Configuration**:
- Minimum iOS: 17.0
- Development Team: H56LZ558HT
- Default Simulator: iPhone 17 Pro (see `.claude/settings.json`)

**Build Command**:
```bash
xcodebuild -project ProgressPic.xcodeproj \
  -scheme ProgressPic \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

**Testing**:
- Currently no automated tests (opportunity for improvement)
- Manual testing required for:
  - Camera functionality (requires physical device)
  - Photo library permissions
  - HealthKit integration
  - Notification scheduling
  - iCloud sync

### Pre-commit Checks

Before committing, verify:
1. ✅ Code compiles without errors
2. ✅ No force unwraps introduced
3. ✅ Proper error handling added
4. ✅ Memory management considered
5. ✅ Accessibility labels added (if UI changes)
6. ✅ No sensitive data in commits

---

## Coding Conventions

### File Organization

**By Concern**:
- Models → `Models/`
- Views → `Views/` (with subdirectories: `Sheets/`, `Components/`, `Utilities/`)
- ViewModels → `ViewModels/`
- Utilities → `Utilities/`

**Component Extraction**:
- Extract reusable components to `Views/Components/Generic/`
- Keep view files under 1000 lines when possible
- Split large views into logical components

### Naming Conventions

**Files**: PascalCase matching primary type
- `JourneyView.swift` → `struct JourneyView`
- `CameraService.swift` → `class CameraService`

**Types**:
- Classes/Structs/Enums: PascalCase
- Protocols: PascalCase

**Properties & Variables**:
- camelCase for all properties
- Descriptive names (`createdAt`, not `date`)

**Functions**:
- camelCase with verb prefix
- Examples: `fetchUIImage`, `loadGhostOverlay`, `formatFullDate`

**Constants**:
- Enum namespacing: `AppConstants.Cache.imageCountLimit`
- Static properties: `AppStyle.Colors.bgDark`

**Logging**:
```swift
// Emoji prefixes for log visibility
Logger.app.info("✅ Successfully loaded photo")
Logger.app.warning("⚠️ Cache miss, loading from disk")
Logger.app.error("❌ Failed to save photo: \(error)")
Logger.app.debug("🔧 Camera session started")
```

**OSLog Categories**:
- `AppConstants.Log.app` - General app logs
- `AppConstants.Log.photo` - Photo operations
- `AppConstants.Log.camera` - Camera operations
- `AppConstants.Log.data` - Data persistence
- `AppConstants.Log.health` - HealthKit operations

### SwiftUI View Structure

**Consistent Pattern**:
```swift
struct ViewName: View {
    // MARK: - Environment & Dependencies
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    // MARK: - State
    @State private var showSheet = false
    @Query private var journeys: [Journey]

    // MARK: - Properties
    let journey: Journey

    // MARK: - Body
    var body: some View {
        content
            .navigationTitle("Title")
            .toolbar { toolbar }
    }

    // MARK: - Subviews
    private var content: some View {
        // View hierarchy
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        // Toolbar items
    }

    // MARK: - Helper Methods
    private func helperMethod() {
        // Logic
    }
}
```

### Code Style Patterns

**Error Handling**:
```swift
// Use guard for early returns
guard let photo = photos.first else {
    Logger.photo.warning("⚠️ No photos available")
    return
}

// Optional chaining and nil coalescing
let name = journey.name.isEmpty ? "Unnamed Journey" : journey.name
```

**Async/Await**:
```swift
// Prefer async/await over completion handlers
Task {
    guard let image = await PhotoStore.fetchUIImage(assetId: photoId) else { return }
    await MainActor.run {
        self.loadedImage = image
    }
}
```

**SwiftData Operations**:
```swift
// Always use modelContext from environment
@Environment(\.modelContext) private var ctx

// Save pattern
journey.name = "New Name"
try? ctx.save()

// Delete pattern
ctx.delete(photo)
try? ctx.save()

// Batch operations
photos.forEach { ctx.delete($0) }
try? ctx.save()
```

**Performance Patterns**:
```swift
// Use lazy loading
LazyVGrid(columns: columns) {
    ForEach(photos) { photo in
        PhotoGridItem(photo: photo)
    }
}

// Background queue for I/O
Task {
    await Task.detached {
        // Heavy work on background queue
    }.value
}

// Cache checks
if let cached = cache.object(forKey: key) {
    return cached
}
```

### Accessibility

**Always Add Labels**:
```swift
Button("Delete") { delete() }
    .accessibilityLabel("Delete photo")
    .accessibilityHint("Permanently removes this photo from your journey")

Image(systemName: "camera")
    .accessibilityLabel("Camera")
```

### Design System

**Colors** (`AppStyle.Colors`):
```swift
.bgDark          // Color(red: 30/255, green: 32/255, blue: 35/255)
.panelDark       // Color.white.opacity(0.1)
.accentCyan      // Cyan accent
.accentPink      // Pink accent
```

**Spacing**:
- Horizontal padding: 20pt
- Panel corner radius: 12pt
- Section spacing: 16pt

**Typography**:
```swift
.title2
    .fontWeight(.bold)
    .foregroundStyle(.white)

.caption
    .tracking(1.2)
    .foregroundStyle(.gray)
```

**Glass Effects** (`Glass.swift`):
```swift
.glassCard()     // Standard glass card
.glassCapsule()  // Glass capsule button
```

---

## Key Features

### 1. Journey Management
- Create multiple journeys
- Journey templates (weight loss, muscle gain, etc.)
- Manual reordering
- Journey deletion with file cleanup

### 2. Photo Capture & Management
- Built-in camera (AVFoundation)
- Multi-camera support (wide, ultra-wide)
- Zoom levels (0.5x, 1x, 2x)
- Ghost overlay for alignment
- Timer capture (3s, 5s, 10s)
- Grid overlay
- 4:5 aspect ratio (1200x1500px)
- Import from library with EXIF preservation

### 3. Photo Editing
- Date editing
- Notes
- Hide from Watch/Compare
- Alignment/transformation tools
- Recropping from original
- Navigation (previous/next)

### 4. Photo Comparison
- Side-by-side
- Overlay with opacity control
- Before/after views
- Multi-photo timelines
- Custom date overlays

### 5. Watch/Slideshow Mode
- Timelapse viewing
- Custom playback speed
- Video export
- Sliding window optimization (max 20 photos in memory)

### 6. Measurement Tracking
- Weight, body fat %, BMI
- Circumferences (chest, waist, hips, neck, biceps, forearms, thighs, calves)
- Left/right variants for limbs
- Custom measurements
- Bulk entry
- Charts with time ranges (week, month, 6 months, year, all)
- Statistics (min, max, average, range)
- CSV export

### 7. HealthKit Integration
- Body composition import/export
- Historical data charts
- Bidirectional sync

### 8. Activity & Streaks
- Photo streak tracking
- Activity calendar
- Heatmap visualization
- Best streak tracking
- App review prompts at milestones (3, 7, 14 days)

### 9. Reminders
- Custom notification scheduling
- Day-of-week selection
- Multiple reminders per journey
- Custom notification text

### 10. iCloud Sync
- CloudKit automatic sync
- Cross-device synchronization
- Offline support
- Sync status indicator

---

## Performance Considerations

### Memory Management

**Image Caching** (`PhotoStore`):
- NSCache with 50 image limit
- 100MB size limit
- Automatic eviction under memory pressure
- Downsampling to target size (1200x1500px)

**Sliding Window** (Watch View):
- Maximum 20 photos in memory simultaneously
- Loads ±10 photos around current position
- Prevents memory crashes with large photo sets

**Blur Caching** (`TransformRenderingUtilities`):
- Shared CIContext (expensive to create)
- NSCache for blurred backgrounds
- Cache key: photo assetId + transform hash
- Eliminates ~90% of blur computation

### Database Optimization

**Indexes** (Critical for performance at scale):
```swift
// ProgressPhoto indexes
#Index([\.journeyId, \.date])  // Sorted queries
#Index([\.journeyId])          // Filtering by journey
#Index([\.date])               // Date-based queries

// MeasurementEntry indexes
#Index([\.journeyId, \.date])  // Timeline queries
#Index([\.journeyId, \.typeRaw])  // Type filtering
```

**Photo Count Caching**:
```swift
// Instead of materializing relationship:
journey.photoCount  // Cached Int property

// Not: journey.photos.count (slow with large datasets)
```

### Lazy Loading

**Always Use**:
```swift
LazyVGrid      // Not VGrid
LazyVStack     // Not VStack (for long lists)
LazyHStack     // Not HStack (for wide content)
```

### Background Operations

**I/O on Background Queue**:
```swift
Task.detached {
    // File operations
    let data = try? Data(contentsOf: url)
    await MainActor.run {
        // Update UI
    }
}
```

**Non-Blocking Async**:
```swift
// Instead of Thread.sleep
try? await Task.sleep(nanoseconds: 100_000_000)
```

### Cache Invalidation

**Targeted Invalidation**:
```swift
// Instead of clearing all:
// PhotoStore.imageCache.removeAll()

// Invalidate only what changed:
PhotoStore.invalidateCache(for: photoId)
TransformRenderingUtilities.invalidateBlurCache(for: photoId)
```

---

## Testing Guidelines

### Critical Test Scenarios

**Journey Operations**:
- [ ] Create journey
- [ ] Delete journey (verify files cleaned up)
- [ ] Reorder journeys

**Photo Operations**:
- [ ] Capture photo
- [ ] Import photo (verify EXIF date preserved)
- [ ] Edit photo (date, notes, alignment)
- [ ] Delete photo (verify both cropped and original removed)
- [ ] Hide/unhide photo

**Memory & Performance**:
- [ ] Watch view with 100+ photos (verify no crash)
- [ ] Scroll photo grid with 500+ photos (verify smooth)
- [ ] Chart rendering with 1000+ measurements (verify fast)
- [ ] Camera flip (verify no UI freeze)

**Data Persistence**:
- [ ] iCloud sync (verify changes sync across devices)
- [ ] Offline mode (verify app works without internet)
- [ ] App restart (verify data persists)

**Permissions**:
- [ ] Camera access
- [ ] Photo library (read)
- [ ] Photo library (add)
- [ ] HealthKit (read/write)
- [ ] Notifications

### Testing on Physical Device

**Required for**:
- Camera functionality
- Performance testing
- Memory testing
- HealthKit integration
- Actual photo library access

---

## Common Patterns

### Color Scheme
```swift
// Background
.background(Color(red: 30/255, green: 32/255, blue: 35/255))

// Panel
.background(Color.white.opacity(0.1))
.cornerRadius(12)

// Text
.foregroundStyle(.white)              // Primary
.foregroundStyle(.gray)               // Secondary
.foregroundStyle(.white.opacity(0.7)) // Tertiary
```

### Navigation Toolbar
```swift
.toolbar {
    ToolbarItem(placement: .principal) {
        VStack(spacing: 4) {
            Text("Journey Name")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text("42 PHOTOS")
                .font(.caption)
                .tracking(1.2)
                .foregroundStyle(.gray)
        }
    }
}
```

### Data Operations
```swift
// Environment access
@Environment(\.modelContext) private var ctx

// Query
@Query(sort: \Journey.sortOrder) private var journeys: [Journey]

// Filter query
@Query(filter: #Predicate<Journey> {
    $0.createdAt > startDate
}) private var recentJourneys: [Journey]

// Save
journey.name = "New Name"
try? ctx.save()

// Delete
ctx.delete(photo)
try? ctx.save()
```

### Haptic Feedback
```swift
// On success
HapticFeedback.success()

// On error
HapticFeedback.error()

// On selection
HapticFeedback.selection()

// Impact
HapticFeedback.medium()
```

### Loading & Empty States
```swift
if isLoading {
    LoadingStateView(message: "Loading photos...", scale: 1.2)
} else if photos.isEmpty {
    EmptyStateView(
        icon: "photo.on.rectangle.angled",
        title: "No Photos Yet",
        message: "Add your first photo to start tracking progress"
    )
} else {
    // Content
}
```

---

## Troubleshooting

### Common Issues

**Problem**: Photos not loading
- **Check**: PhotoStore cache invalidation
- **Check**: File exists in `Documents/Photos/`
- **Check**: assetLocalId is valid UUID

**Problem**: Camera not working
- **Check**: Camera permissions granted
- **Check**: Running on physical device (not simulator)
- **Check**: CameraService.start() called

**Problem**: iCloud sync not working
- **Check**: iCloud account signed in
- **Check**: CloudKit container ID correct (`iCloud.Edgar.ProgressPic`)
- **Check**: Entitlements file includes CloudKit capability

**Problem**: Memory crash in Watch view
- **Check**: Sliding window implementation active
- **Check**: Image target size is 1200x1500 (not 2400x2400)
- **Check**: Max 20 photos loaded at once

**Problem**: Database query slow
- **Check**: Indexes defined on queried properties
- **Check**: Using cached photoCount instead of relationship count
- **Check**: FetchDescriptor has appropriate limits

**Problem**: UI freeze during photo edit
- **Check**: Using targeted cache invalidation (not removeAll)
- **Check**: Blur cache working correctly
- **Check**: Heavy operations on background queue

### Debug Logging

**Enable OSLog**:
```swift
import OSLog

let logger = Logger(subsystem: "Edgar.ProgressPic", category: "debug")
logger.info("✅ Operation successful")
logger.warning("⚠️ Potential issue")
logger.error("❌ Error occurred: \(error)")
```

**View Logging Categories**:
```swift
AppConstants.Log.app     // General
AppConstants.Log.photo   // Photo operations
AppConstants.Log.camera  // Camera
AppConstants.Log.data    // Data persistence
AppConstants.Log.health  // HealthKit
```

### Performance Profiling

**Instruments Profiles to Run**:
- Time Profiler (CPU usage)
- Allocations (memory leaks)
- Leaks (retain cycles)
- Core Data (database performance - SwiftData uses Core Data under the hood)

---

## Recent Improvements

### Critical Fixes (PR #1)
✅ Added JourneyReminder to SwiftData schema (data corruption fix)
✅ File cleanup on journey/photo deletion (GB-scale storage leak fix)
✅ Memory optimization in Watch view (500MB+ → 125MB)
✅ Force unwraps → safe unwrapping (4+ crash scenarios eliminated)
✅ Database indexes added (6 indexes for performance)
✅ Division by zero fixes

### Performance Optimizations (PR #1)
✅ Blur background caching (~90% faster rendering)
✅ Thread.sleep → async/await (non-blocking camera flip)
✅ Targeted cache invalidation (90% reduction in unnecessary reloads)
✅ Image resolution optimization (2400x2400 → 1200x1200)

### Code Quality Enhancements (PRs #2 & #3)
✅ HapticFeedback utility (11 instances standardized)
✅ DateFormatters utility (eliminates ~50 lines duplication)
✅ StatsFormatters utility (eliminates ~80 lines duplication)
✅ ChartXAxisHelpers utility (ready for ~300 lines savings)
✅ EmptyStateView component (60 lines eliminated)
✅ Accessibility enhancements (photo navigation labels)

---

## Important Notes for AI Assistants

### Always Remember

1. **iCloud Sync is ENABLED** (`cloudKitDatabase: .automatic`)
   - Consider sync implications when modifying data models
   - Schema changes require careful migration

2. **Photo Files Are Local Only**
   - Not synced via iCloud (deliberate design)
   - Always clean up files when deleting photos/journeys

3. **Performance is Critical**
   - App handles 100+ photos and 1000+ measurements
   - Always use indexes for database queries
   - Use caching strategically
   - Lazy loading is mandatory for lists

4. **Memory Management**
   - Mobile devices have limited memory
   - Always downsample images
   - Use sliding window for large datasets
   - Clear caches appropriately

5. **Accessibility is Important**
   - Add labels and hints to all interactive elements
   - Use semantic colors (not hardcoded)
   - Test with VoiceOver

6. **Error Handling**
   - Never force unwrap (use guard let or optional chaining)
   - Log errors with appropriate severity
   - Provide user-friendly error messages

7. **SwiftData Best Practices**
   - Always save after modifications
   - Use @Query for reactive updates
   - Leverage relationships with cascade delete
   - Consider CloudKit sync delay

### When Making Changes

**Before Adding Code**:
- [ ] Check if utility already exists
- [ ] Consider performance impact
- [ ] Plan memory usage
- [ ] Add appropriate logging
- [ ] Consider accessibility

**Before Committing**:
- [ ] No force unwraps
- [ ] Proper error handling
- [ ] Memory leaks prevented
- [ ] Files cleaned up on delete
- [ ] Accessibility labels added
- [ ] No sensitive data

---

## Useful Commands

### Xcode Build
```bash
xcodebuild -project ProgressPic.xcodeproj \
  -scheme ProgressPic \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

### Git Operations
```bash
# Check status
git status

# Stage all changes
git add .

# Commit
git commit -m "Your message"

# Push (with retry on network errors)
git push -u origin <branch-name>

# Create branch
git checkout -b claude/feature-description-sessionId
```

### Find Code Patterns
```bash
# Find all force unwraps
rg "!" --type swift | grep -v "// " | grep "!"

# Find all TODO comments
rg "TODO|FIXME" --type swift

# Find large files
find ProgressPic -name "*.swift" -exec wc -l {} + | sort -rn | head -20
```

---

**End of Documentation**

For questions or clarifications, consult:
- This CLAUDE.md file
- ANALYSIS_SUMMARY.md (detailed recent changes)
- Code comments (MARK sections)
- Git history (`git log`)
