# ProgressPic Codebase - Quick Reference Guide

## File Locations (All Absolute Paths)

### Core Models & Services
```
/home/user/ProgressPic/ProgressPic/Models/
├── Models.swift                    # Journey, ProgressPhoto, MeasurementEntry, JourneyReminder
├── PhotoStore.swift                # Image loading, caching, file storage (293 lines)
├── CameraService.swift             # AVFoundation camera management (460 lines)
├── HealthKitService.swift          # HealthKit body composition data (300 lines)
├── ReviewAndReminderServices.swift # App review & notifications (112 lines)
├── ProgressPicApp.swift            # App entry point, SwiftData setup
├── AppConstants.swift              # Centralized constants & logging
├── AppStyle.swift                  # Colors, typography, spacing
└── Glass.swift                     # Additional model support
```

### View Models
```
/home/user/ProgressPic/ProgressPic/ViewModels/
└── CameraViewModel.swift           # Camera UI state & logic
```

### Views (37 files)
```
/home/user/ProgressPic/ProgressPic/Views/
├── ContentView.swift               # Root tab navigation
├── JourneyView.swift               # Journey list & management
├── CameraHostView.swift            # Camera interface
├── ActivityView.swift              # Stats dashboard
├── MeasurementDetailView.swift     # Measurement charts
├── BodyCompositionDetailView.swift # Health metrics
├── JourneySettingsView.swift       # Journey config
├── UserProfileDetailView.swift     # User profile
├── SettingsView.swift              # App settings
├── Sheets/                         # Modal views (7 files)
│   ├── OnboardingView.swift
│   ├── UserProfileSetupView.swift
│   ├── NewJourneySheet.swift
│   ├── AddMeasurementSheet.swift
│   ├── BulkMeasurementSheet.swift
│   ├── EditReminderView.swift
│   └── YearCalendarSheet.swift
├── Components/                     # Reusable components (15 files)
│   ├── Generic/
│   │   ├── EmptyStateView.swift
│   │   ├── PhotoEditControls.swift
│   │   └── ...
│   ├── CompareCanvas.swift
│   ├── PhotoEditViews.swift
│   ├── VideoExporter.swift
│   ├── JourneyWatchViews.swift
│   └── ...
└── Utilities/                      # View helpers (5 files)
    ├── ChartXAxisHelpers.swift
    ├── TransformRenderingUtilities.swift
    ├── PhotoImportUtilities.swift
    ├── ShareUtilities.swift
    └── ChartAggregationHelpers.swift
```

### App-Wide Utilities
```
/home/user/ProgressPic/ProgressPic/Utilities/
├── DateFormatters.swift            # Cached date formatting (138 lines)
├── StatsFormatters.swift           # Statistics & charts (157 lines)
└── HapticFeedback.swift            # Haptic API (50 lines)
```

---

## Data Model Relationships

```
Journey (parent)
├── photos: [ProgressPhoto]         (cascade delete)
├── measurements: [MeasurementEntry] (cascade delete)
└── reminders: [JourneyReminder]    (cascade delete)

ProgressPhoto
├── journeyId: UUID
├── date: Date
├── assetLocalId: String            (stored in Documents/Photos/)
└── originalAssetLocalId: String?   (for re-cropping)

MeasurementEntry
├── journeyId: UUID
├── date: Date
├── type: MeasurementType
├── value: Double
└── unit: MeasureUnit

JourneyReminder
├── hour: Int
├── minute: Int
├── daysBitmask: Int                (7-bit Mon-Sun)
└── notificationText: String
```

---

## Key Service APIs

### PhotoStore (Static)
```swift
// Loading
PhotoStore.fetchUIImage(localId: String, targetSize: CGSize?) -> UIImage?
PhotoStore.loadFromPhotoLibrary(localId: String) -> UIImage?

// Saving
PhotoStore.saveToAppDirectory(_ image: UIImage) -> String
PhotoStore.saveToAppDirectoryAndLibrary(_ image: UIImage, saveToCameraRoll: Bool) -> String

// Cache Management
PhotoStore.clearCache()
PhotoStore.invalidateCache(for: localId)
PhotoStore.prefetchPhotos(_ photos: [ProgressPhoto], targetSize: CGSize)

// Utilities
PhotoStore.cropTo4x5(_ image: UIImage) -> UIImage
PhotoStore.extractEXIFDate(from: imageData) -> Date?
```

### CameraService (ObservableObject)
```swift
@Published var previewLayer: AVCaptureVideoPreviewLayer?
@Published var latestPhoto: UIImage?
@Published var isFront: Bool
@Published var isAuthorized: Bool
@Published var currentZoom: CGFloat
@Published var flashMode: AVCaptureDevice.FlashMode

func requestPermissionIfNeeded() async
func start()
func stop()
func capturePhoto() async -> UIImage?
func switchCamera()
```

### HealthKitService (Singleton + ObservableObject)
```swift
static let shared = HealthKitService()

@Published var isAuthorized: Bool
@Published var bodyComposition: BodyCompositionData

func requestAuthorization() async -> Bool
func fetchBodyComposition() async
```

---

## Core Data Flow

```
1. USER CAPTURES PHOTO
   ├─ CameraService captures UIImage
   ├─ PhotoStore.cropTo4x5() normalizes aspect ratio
   ├─ PhotoStore.saveToAppDirectory() saves to disk
   ├─ Creates ProgressPhoto(assetLocalId: filename)
   ├─ Saves to SwiftData
   └─ CloudKit syncs if available

2. USER ADDS MEASUREMENT
   ├─ AddMeasurementSheet collects input
   ├─ Creates MeasurementEntry
   ├─ Saves to SwiftData
   └─ CloudKit syncs if available

3. USER VIEWS PROGRESS
   ├─ MeasurementDetailView loads measurements
   ├─ StatsFormatters calculates min/max/avg
   ├─ ChartXAxisHelpers generates date points
   ├─ Chart renders with time range filter
   └─ PhotoStore caches images for smooth scrolling

4. USER DELETES JOURNEY
   ├─ Cascade delete removes all photos/measurements
   ├─ JourneySettingsView loops through photos
   ├─ PhotoStore.deleteFromAppDirectory() removes files
   └─ CloudKit syncs deletions
```

---

## Database Schema & Indexes

### Models
```swift
@Model final class Journey {
    #Index([\.name])
    // No explicit index; managed by relationships
}

@Model final class ProgressPhoto {
    #Index<ProgressPhoto>([\.journeyId, \.date])
    #Index<ProgressPhoto>([\.journeyId])
    #Index<ProgressPhoto>([\.date])
}

@Model final class MeasurementEntry {
    #Index<MeasurementEntry>([\.journeyId, \.date])
    #Index<MeasurementEntry>([\.journeyId, \.typeRaw])
}
```

### Query Performance
- Indexed queries: O(log n)
- Without indexes: O(n) table scans
- Pagination available: `ModelContext.fetchPaginated()`

---

## Configuration Constants

### AppConstants
```swift
// Logging
AppConstants.Log.app        // General
AppConstants.Log.photo      // Photo operations
AppConstants.Log.camera     // Camera
AppConstants.Log.data       // Database
AppConstants.Log.health     // HealthKit

// Cache
AppConstants.Cache.imageCountLimit = 50
AppConstants.Cache.imageSizeLimit = 100 * 1024 * 1024

// Photo
AppConstants.Photo.exportWidth = 1200
AppConstants.Photo.exportHeight = 1500

// Camera
AppConstants.Camera.defaultGhostOpacity = 0.32
AppConstants.Camera.maxZoom = 10.0

// Video
AppConstants.Video.defaultFPS = 30
AppConstants.Video.defaultPhotoDuration = 0.5
```

---

## Common Patterns

### Using Utilities
```swift
// Date formatting
let dateStr = DateFormatters.formatFullDate(date)  // "1 Jan 2024"
let rangeStr = DateFormatters.formatDateRange(from: start, to: end)

// Statistics
let minStr = StatsFormatters.formatMin(measurements, valueKeyPath: \.value, unit: "kg")
let domain = StatsFormatters.calculateYDomain(for: data, valueKeyPath: \.value)

// Haptic feedback
HapticFeedback.medium()
HapticFeedback.success()
HapticFeedback.warning()
```

### Loading Images with Cache
```swift
if let image = await PhotoStore.fetchUIImage(localId: photo.assetLocalId, 
                                              targetSize: CGSize(width: 600, height: 750)) {
    // Image is cached and ready
}
```

### Querying Data
```swift
// With index optimization
let descriptor = FetchDescriptor<ProgressPhoto>(
    predicate: #Predicate { $0.journeyId == journey.id },
    sortBy: [SortDescriptor(\.date, order: .reverse)]
)
let photos = try modelContext.fetch(descriptor)
```

---

## Testing Priorities

### Must Test (Critical)
1. PhotoStore - File ops, caching, EXIF extraction
2. DateFormatters - All format methods
3. StatsFormatters - Min/max/avg calculations
4. MeasurementType - Paired variants, base names
5. Journey CRUD with cascade delete

### Should Test (Important)
1. CameraService - Permission handling
2. HealthKitService - Data fetching
3. Core workflows - Capture photo, add measurement
4. Chart rendering - Multiple data sizes

### Nice to Have
1. Accessibility - VoiceOver, Dynamic Type
2. Performance - 1000+ photos, memory pressure
3. Localization - Formatting in different locales

---

## Performance Tips

### Memory Optimization
```swift
// Use downsampling
let image = PhotoStore.loadFromAppDirectory(filename: id, targetSize: CGSize(width: 600, height: 750))
// Not full resolution

// Prefetch for scrolling
PhotoStore.prefetchPhotos(photos, targetSize: targetSize)

// Watch out for sliding window (already implemented in JourneyWatchViews)
// Max 20 photos at 1200x1200 to avoid 500MB spikes
```

### Database Optimization
```swift
// Use indexed predicates
#Predicate { $0.journeyId == journey.id && $0.date > startDate }
// Fast with index on [journeyId, date]

// Avoid materializing relationships unnecessarily
// Use photoCount property instead of photos.count
```

### Cache Management
```swift
// On app memory warning
PhotoStore.clearCache()

// When editing a photo
PhotoStore.invalidateCache(for: photo.assetLocalId)
// Don't clear entire cache
```

---

## File Organization

### For a New Feature
1. Add model to Models.swift
2. Add service if needed in Models/
3. Create views in Views/ (main) or Views/Sheets/
4. Create components in Views/Components/
5. Add utilities if code duplication (Utilities/ or Views/Utilities/)
6. Update AppConstants if needed

### Absolute Paths for All Operations
```swift
// CORRECT
let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let photosDir = documentsPath.appendingPathComponent("Photos")

// INCORRECT
// Don't use relative paths or FileManager.currentDirectoryPath
```

---

## Known Limitations & Workarounds

1. **SwiftData Cascade Delete**: Works but requires manual file cleanup
   - When deleting Journey, manually delete all photo files in JourneySettingsView

2. **PhotoStore Cache**: NSCache automatic but not immediate
   - Use `invalidateCache(for:)` for edited photos
   - Use `clearCache()` on memory warnings

3. **HealthKit on Simulator**: Limited functionality
   - Real Health data only available on device
   - Mock data recommended for testing

4. **CloudKit Sync**: Requires iCloud enabled in Capabilities
   - Falls back to local storage if unavailable
   - No explicit conflict resolution needed (CloudKit handles it)

---

## Documentation References

- **CODEBASE_STRUCTURE.md** - Complete architecture
- **TESTING_ROADMAP.md** - Testing strategy & priorities
- **ANALYSIS_SUMMARY.md** - Recent optimizations & fixes

---

## Useful Commands

```bash
# Find all Swift files
find /home/user/ProgressPic -name "*.swift" | wc -l

# List services
ls /home/user/ProgressPic/ProgressPic/Models/

# Check file sizes
du -sh /home/user/ProgressPic/ProgressPic/Models/*.swift

# Search for usage
grep -r "PhotoStore" /home/user/ProgressPic/ProgressPic/Views/
```

---

Generated: 2025-01-14
