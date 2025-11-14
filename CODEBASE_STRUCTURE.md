# ProgressPic Codebase Structure Analysis

## Overview
ProgressPic is a comprehensive iOS fitness tracking application built with SwiftUI and SwiftData. It allows users to track physical progress through photos, measurements, and body composition data with an elegant dark-themed UI.

**Total Swift Files**: 52
**View Files**: 37
**Architecture**: MVVM with centralized services and utilities

---

## 1. PROJECT STRUCTURE

```
ProgressPic/
├── Models/                          # Data models & services (11 files)
├── ViewModels/                      # State management (1 file)
├── Views/                           # UI layer (37 files)
│   ├── Components/                  # Reusable components
│   ├── Sheets/                      # Modal views
│   └── Utilities/                   # View-specific helpers
├── Utilities/                       # App-wide helpers (3 files)
├── Resources/                       # Assets & images
└── ProgressPic.icon/                # Icon assets
```

---

## 2. DATA MODELS (Models/)

### Core Models
All models use @Model decorator for SwiftData persistence with CloudKit sync.

#### **Journey** (Main progress tracking entity)
- Represents a fitness journey/goal
- Properties:
  - `id`, `name`, `createdAt`
  - `saveToCameraRoll`, `autoSyncStartDate`, `template`, `sortOrder`
  - `photoCount` (cached to avoid materializing full relationship)
- Relationships (cascade delete):
  - `photos`: [ProgressPhoto]
  - `measurements`: [MeasurementEntry]
  - `reminders`: [JourneyReminder]

#### **ProgressPhoto** (Photo tracking)
- Properties:
  - `id`, `journeyId`, `date`
  - `assetLocalId` (cropped image), `originalAssetLocalId` (original for re-cropping)
  - `isFrontCamera`, `alignTransform`, `notes`, `isHidden`
- Indexes:
  - `[journeyId, date]` - primary queries
  - `[journeyId]` - journey photos
  - `[date]` - date-based filters

#### **MeasurementEntry** (Body measurements)
- Properties:
  - `id`, `journeyId`, `date`
  - `typeRaw`, `value`, `unitRaw`, `label`
- Supports types: weight, bodyFat, chest, waist, hips, neck, biceps(L/R), forearm(L/R), thigh(L/R), calf(L/R), custom
- Indexes:
  - `[journeyId, date]`
  - `[journeyId, typeRaw]`

#### **JourneyReminder** (Notification scheduling)
- Properties:
  - `id`, `hour`, `minute`, `daysBitmask` (7-bit for days of week)
  - `notificationText`
- Relationship: belongs to Journey

#### **Supporting Enums & Structures**
- `MeasurementType`: All supported measurement types with paired variants (L/R)
- `MeasureUnit`: kg, lb, cm, inch, percent
- `AlignTransform`: Photo transform data (scale, offset, rotation)
- `UserProfile`: User preferences (birthDate, height, gender, colorScheme)
- `BodyCompositionData`: HealthKit data aggregation
- `HealthDataPoint`: Individual health data points

---

## 3. SERVICES LAYER (Models/)

### **PhotoStore** (293 lines)
**Purpose**: Image loading, caching, and file storage
**Key Features**:
- NSCache for memory-efficient image caching with automatic eviction
- Prefetch capability for scrolling performance
- App directory storage (replaces photo library for new photos)
- Photo library fallback for legacy photos
- Efficient downsampling using CGImageSource (prevents memory spikes)
- EXIF metadata extraction (creation dates)
- 4:5 aspect ratio cropping (1200x1500)
- Cache invalidation strategies

**Key Methods**:
- `fetchUIImage()` - Load with caching
- `saveToAppDirectory()` - Save locally
- `saveToAppDirectoryAndLibrary()` - Optional camera roll sync
- `prefetchPhotos()` - Background loading
- `clearCache()` / `invalidateCache()` - Memory management
- `cropTo4x5()` - Aspect ratio normalization
- `extractEXIFDate()` - Metadata extraction

### **CameraService** (460 lines)
**Purpose**: AVFoundation camera management
**Key Features**:
- AVCaptureSession for photo/video capture
- Front/back camera switching
- Zoom level control (1x to 10x)
- Flash mode management
- Ultra-wide camera detection
- Permission handling
- Photo output capture
- Lazy initialization (doesn't start until needed)

**Published Properties**:
- `previewLayer`, `latestPhoto`, `isFront`, `isAuthorized`
- `canCapture`, `flashMode`, `currentZoom`, `hasUltraWideCamera`

### **HealthKitService** (300 lines)
**Purpose**: HealthKit integration for body composition data
**Key Features**:
- Weight, body fat %, lean body mass, BMI
- Authorization request handling
- Async data fetching
- Date tracking for each metric
- Persistent authorization status

**Published Properties**:
- `isAuthorized`, `bodyComposition`

### **ReviewAndReminderServices** (112 lines)
**Purpose**: App review prompts & notification scheduling
**Key Services**:
- App Store review request
- Local notification scheduling
- Reminder time management

---

## 4. VIEW MODELS (ViewModels/)

### **CameraViewModel** (100+ lines)
**Purpose**: Encapsulates camera UI state and business logic
**Published Properties**:
- Journey & photo management
- Ghost overlay settings
- Timer controls
- Camera settings
- UI state (adjust view, photo library, errors)
- Orientation/background observers

**Key Methods**:
- `loadGhostOverlay()` - Load comparison ghost image
- `toggleGhostPhoto()` - Switch first/last photo

---

## 5. VIEWS (Views/) - 37 Files

### Main Views
- **ContentView.swift** - Root tab navigation (Journeys/Camera/Activity)
- **JourneyView.swift** - Main journey list with editing
- **CameraHostView.swift** - Camera capture interface
- **ActivityView.swift** - Activity/stats dashboard

### Detail Views
- **MeasurementDetailView.swift** - Detailed measurement charts & statistics
- **BodyCompositionDetailView.swift** - Health metrics visualization
- **JourneySettingsView.swift** - Journey configuration
- **UserProfileDetailView.swift** - User profile management
- **SettingsView.swift** - App settings

### Sheet/Modal Views (Views/Sheets/)
- **OnboardingView.swift** - First-time setup
- **UserProfileSetupView.swift** - Profile configuration
- **NewJourneySheet.swift** - Create journey
- **AddMeasurementSheet.swift** - Single measurement entry
- **BulkMeasurementSheet.swift** - Multiple measurements at once
- **EditReminderView.swift** - Notification scheduling
- **YearCalendarSheet.swift** - Calendar-based navigation
- **AdjustView.swift** - Photo alignment/transformation

### Reusable Components (Views/Components/)
#### Generic Components (Views/Components/Generic/)
- **EmptyStateView.swift** - Consistent empty/loading states
- **PhotoEditControls.swift** - Photo editing buttons
- **ReminderListItem.swift** - Reminder display item
- **TimeRangeSelector.swift** - Date range selection
- **WatchViewComponents.swift** - Watch app components

#### Specialized Components (Views/Components/)
- **CompareCanvas.swift** - Side-by-side photo comparison
- **CompareViewModifiers.swift** - Comparison view styling
- **DateOverlaySettings.swift** - Date watermark configuration
- **PhotoAdjustSheet.swift** - Photo cropping/adjusting
- **PhotoEditViews.swift** - Photo editing interface
- **VideoExporter.swift** - Video creation/export
- **JourneyWatchViews.swift** - Watch-specific views
- **JourneyPhotoComponents.swift** - Photo gallery components
- **JourneyComparisonViews.swift** - Comparison views
- **Add WeekRingView.swift** - Activity ring display

### View Utilities (Views/Utilities/)
- **ChartXAxisHelpers.swift** - X-axis date generation for charts
- **ChartAggregationHelpers.swift** - Chart data aggregation
- **TransformRenderingUtilities.swift** - Blur effects with caching
- **PhotoImportUtilities.swift** - Photo import logic
- **ShareUtilities.swift** - Sharing functionality

---

## 6. UTILITIES (Utilities/) - 3 Files

### **DateFormatters.swift** (138 lines)
**Purpose**: Centralized, cached date formatting
**Cached Formatters**:
- `fullDate` - "1 Jan 2024"
- `shortDate` - "Jan 1"
- `monthYear` - "Jan 2024"
- `monthOnly` - "January"
- `dayMonth` - "1 Jan"
- `isoDate` - "yyyy-MM-dd"
- `timeOnly` - "3:45 PM"

**Methods**:
- `formatFullDate()`, `formatShortDate()`, `formatMonthYear()`
- `formatDateRange()` - Smart range formatting
- `formatRelative()` - "Today", "Yesterday", etc.
- `parseEXIFDateString()`, `parseGPSDateTime()` - EXIF parsing

### **StatsFormatters.swift** (157 lines)
**Purpose**: Statistics calculation and formatting using KeyPath
**Methods**:
- `formatMin()`, `formatMax()`, `formatAverage()`, `formatRange()`
- `calculateYDomain()` - Chart scaling with padding
- `formatPercentage()`, `formatChange()`, `formatDuration()`
- `getStats()` - Raw statistics tuple

### **HapticFeedback.swift** (50 lines)
**Purpose**: Standardized haptic feedback API
**Methods**:
- `impact()` - Impact feedback
- `notification()` - Notification feedback
- `selection()` - Selection feedback
- Convenience: `success()`, `warning()`, `light()`, `medium()`, `heavy()`

---

## 7. KEY CONSTANTS & CONFIGURATION (AppConstants.swift)

### Logging
```swift
AppConstants.Log.app        // General app
AppConstants.Log.photo      // Photo operations
AppConstants.Log.camera     // Camera operations
AppConstants.Log.data       // Data persistence
AppConstants.Log.health     // HealthKit
```

### Configuration Namespaces
- **Cache**: Image count (50), size limits (100MB)
- **Photo**: Export dimensions (1200x1500), aspect ratio
- **Camera**: Ghost opacity defaults, zoom limits (1x-10x)
- **Video**: FPS (30), photo duration (0.5s), limits
- **Layout**: Padding, corner radius, spacing
- **Animation**: Standard (0.3s), quick (0.2s), slow (0.5s)

### App Style (AppStyle.swift)
- Colors: Dark theme with cyan/pink accents
- Typography: Font configurations
- Spacing: Consistent padding and margins

---

## 8. DATA PERSISTENCE

### SwiftData
- Schema: Journey, ProgressPhoto, MeasurementEntry, JourneyReminder
- CloudKit integration with automatic detection
- Fallback to local storage if iCloud unavailable
- In-memory container as final fallback
- Pagination support via `fetchPaginated()` extension

### File Storage
- App Documents/Photos/ for image files (JPEG, quality 0.9)
- Filename: UUID.uuidString + ".jpg"
- Optional camera roll backup

### UserDefaults
- UserProfile (serialized JSON)
- Onboarding status
- HealthKit authorization status

---

## 9. ARCHITECTURE PATTERNS

### Patterns Used
1. **MVVM**: Views + ViewModels + Models
2. **Singleton**: HealthKitService.shared, PhotoStore (static)
3. **Repository**: Services encapsulate data access
4. **Dependency Injection**: Via @Environment and @StateObject
5. **Reactive**: @Published + @State with Combine
6. **Caching**: NSCache with memory pressure handling
7. **Generic Programming**: KeyPath-based utilities
8. **Protocol-Oriented**: Dated protocol for charts

### Thread Safety
- @MainActor annotations on UI-bound code
- Async/await for background tasks
- Task.detached for heavy I/O
- DispatchQueue for camera configuration

---

## 10. FUNCTIONAL AREAS

### Photo Management
- Capture & storage
- Image caching with prefetch
- EXIF metadata extraction
- 4:5 aspect ratio enforcement
- Alignment transform (drag/zoom/rotate)
- Ghost overlay for comparison

### Measurement Tracking
- Multiple measurement types
- Left/right variant pairing
- Unit conversion (metric/imperial)
- Time-series charting
- Statistics calculation
- CSV export

### User Profile & Health
- HealthKit integration
- Body composition data
- Birth date & age calculation
- Height/gender tracking
- Color scheme preferences

### Notifications & Reminders
- Daily reminder scheduling
- Day selection (bitmask: Mon-Sun)
- Custom notification text
- Time specification (hour/minute)

### Data Visualization
- Charts with time range selection
- Ghost overlay comparison
- Before/after side-by-side
- Video export (30 FPS, configurable duration)
- Activity rings (Watch app)

---

## 11. TEST COVERAGE

### Current Status
**No test files found** in the repository

### Recommended Test Areas
1. **Unit Tests**:
   - DateFormatters (all format functions)
   - StatsFormatters (min/max/avg, domain calculation)
   - MeasurementType (paired measurements, base names)
   - UserProfile (serialization, age calculation)

2. **Integration Tests**:
   - PhotoStore (save/load/delete with caching)
   - Journey CRUD (with cascade relationships)
   - Measurement queries (filtered by type/date)
   - HealthKit synchronization

3. **UI Tests**:
   - Camera capture & orientation
   - Photo editing workflow
   - Measurement entry & chart display
   - Reminder scheduling
   - Journey comparison

4. **Performance Tests**:
   - Large photo set loading (100+)
   - Watch view memory (500+ photos)
   - Chart rendering (1000+ entries)
   - Cache eviction under memory pressure

---

## 12. ARCHITECTURE SUMMARY

```
┌─────────────────────────────────────────────────────┐
│                    CONTENT VIEW                      │
│              (Tab: Journeys/Camera/Activity)         │
└────────────────┬────────────────┬────────────────────┘
                 │                │
        ┌────────▼────────┐  ┌────▼───────────────┐
        │  JOURNEYS VIEW  │  │  CAMERA HOST VIEW  │
        │                 │  │  + CameraViewModel│
        └────────┬────────┘  └────┬───────────────┘
                 │                │
        ┌────────▼─────────────────▼──────────────────┐
        │          MODELS & DATA LAYER                 │
        │  ┌──────────────────────────────────────┐   │
        │  │  SWIFTDATA MODELS                    │   │
        │  │  - Journey                           │   │
        │  │  - ProgressPhoto                     │   │
        │  │  - MeasurementEntry                  │   │
        │  │  - JourneyReminder                   │   │
        │  └──────────────────────────────────────┘   │
        └────────┬────────────────────────────────────┘
                 │
        ┌────────▼──────────────────────────────────┐
        │       SERVICES LAYER                       │
        │  ┌──────────────┬──────────────┐          │
        │  │  PhotoStore  │ CameraService│          │
        │  ├──────────────┼──────────────┤          │
        │  │HealthKitSvc  │ ReviewService│          │
        │  └──────────────┴──────────────┘          │
        └────────┬──────────────────────────────────┘
                 │
        ┌────────▼──────────────────────────────────┐
        │       UTILITIES LAYER                      │
        │  ┌────────────┬──────────────┐            │
        │  │DateFormats │StatsFormatters│           │
        │  │HapticFdbck │ChartXAxisHelp│           │
        │  └────────────┴──────────────┘            │
        └────────────────────────────────────────────┘
```

---

## 13. KEY FILES BY FUNCTIONALITY

### Photo Management
- `PhotoStore.swift` - File I/O, caching, EXIF
- `PhotoEditViews.swift` - Photo alignment UI
- `PhotoAdjustSheet.swift` - Cropping interface
- `CameraService.swift` - Capture

### Measurements & Charts
- `MeasurementDetailView.swift` - Charts, stats
- `BodyCompositionDetailView.swift` - Health data
- `ChartXAxisHelpers.swift` - Axis generation
- `StatsFormatters.swift` - Statistics

### Journeys & Organization
- `JourneyView.swift` - Main list
- `JourneySettingsView.swift` - Configuration
- `NewJourneySheet.swift` - Creation

### Comparison & Video
- `CompareCanvas.swift` - Side-by-side
- `VideoExporter.swift` - Export
- `TransformRenderingUtilities.swift` - Rendering

---

## SUMMARY

ProgressPic is a well-structured, feature-rich fitness tracking app with:
- **52 Swift files** organized into clear functional domains
- **Robust data model** with SwiftData persistence & CloudKit sync
- **Modular services** for camera, photos, HealthKit, and more
- **Reusable utilities** for formatting and UI components
- **No test coverage** - primary testing opportunity
- **Enterprise-level optimizations**: caching, memory management, indexes
- **Accessibility support** through EmptyStateView components
- **Dark theme** with configurable accent colors

**Architecture Quality**: Production-ready with excellent separation of concerns
