# ProgressPic Testing Roadmap

## Current Status
- **Test Files**: 0 (no tests found)
- **Test Directories**: None
- **Opportunity**: Full testing coverage to implement
- **Priority**: HIGH - Production app with critical features

---

## 1. UNIT TEST OPPORTUNITIES

### 1.1 Utilities Layer (High Value, Easy to Test)

#### DateFormatters.swift
**Test Cases**:
- `formatFullDate()` - Format date as "1 Jan 2024"
- `formatShortDate()` - Format date as "Jan 1"
- `formatMonthYear()` - Format date as "Jan 2024"
- `formatDateRange()` - Smart range formatting with edge cases:
  - Same day
  - Same month, different days
  - Same year, different months
  - Different years
- `formatRelative()` - Returns "Today", "Yesterday", "Tomorrow", or full date
- `parseEXIFDateString()` - Parse "yyyy:MM:dd HH:mm:ss" format
- `parseGPSDateTime()` - Parse GPS datetime components

**Why Test**: Date formatting is error-prone; many bugs come from localization and edge cases

---

#### StatsFormatters.swift
**Test Cases**:
- `formatMin()` - Extract and format minimum value
  - Empty array → returns placeholder
  - Single value → returns that value
  - Multiple values → returns correct minimum
- `formatMax()` - Similar tests as min
- `formatAverage()` - Average calculation
  - Verify decimal places
  - Edge cases: single value, two values
- `formatRange()` - Max - min
- `calculateYDomain()` - Chart Y-axis scaling
  - Test padding calculation
  - Test negative value handling
  - Test minPadding enforcement
- `formatPercentage()` - Format as percentage with decimals
- `formatChange()` - Format +/- sign handling
- `getStats()` - Raw stats tuple extraction

**Why Test**: Used in 100+ places for chart rendering; bugs affect data visualization

---

#### HapticFeedback.swift
**Test Cases**:
- Each feedback method can be called without crashing
- Verify style parameters (light, medium, heavy)
- Verify notification types (success, warning, error)

**Why Test**: Called in many views; ensure consistency

---

### 1.2 Models & Enums

#### MeasurementType
**Test Cases**:
- `pairedMeasurement` - L/R variants
  - bicepsLeft → bicepsRight
  - forearmLeft → forearmRight
  - thighLeft → thighRight
  - calfLeft → calfRight
  - non-paired → nil
- `baseName` - Extract base name (e.g., "Biceps" from "Biceps (L)")
- `isLeft` - Correctly identify left variants
- `hasPairedVariant` - Detect if measurement has L/R pair

**Why Test**: Business logic for paired measurements; affects UI

---

#### UserProfile
**Test Cases**:
- `init()` - Default initialization
- `load()` - Load from UserDefaults
- `save()` - Save to UserDefaults and verify retrieval
- `age` calculation - Test with various birthdates
  - Before birthday this year
  - After birthday this year
  - Edge case: today is birthday
  - Leap year dates
- Gender enum serialization/deserialization
- ColorScheme enum serialization/deserialization

**Why Test**: User data persistence; loss of data is critical

---

#### AlignTransform
**Test Cases**:
- `identity` - Default transform
- Codable protocol - Serialize/deserialize
- Equality comparison

---

### 1.3 Data Models

#### Models Relationships
**Test Cases** (would need SwiftData context):
- Journey with cascade delete
  - Delete journey → all photos deleted
  - Delete journey → all measurements deleted
  - Delete journey → all reminders deleted
- ProgressPhoto → Journey relationship
- MeasurementEntry → Journey relationship
- JourneyReminder → Journey relationship

---

## 2. INTEGRATION TEST OPPORTUNITIES

### 2.1 PhotoStore Service (Critical)
**Test Cases**:
- Cache behavior
  - `fetchUIImage()` - First call loads, second call returns cached
  - Cache eviction under pressure
  - `invalidateCache()` - Targeted invalidation
  - `clearCache()` - Full cache clear
- File operations
  - `saveToAppDirectory()` - File created in correct location
  - File naming (UUID.jpg format)
  - File can be retrieved after saving
  - `deleteFromAppDirectory()` - File deleted
- Image cropping
  - `cropTo4x5()` - Correct aspect ratio
  - `downsampleImage()` - Memory-efficient loading
- EXIF extraction
  - `extractEXIFDate()` - Correctly parses EXIF
  - Fallback to TIFF dict
  - Fallback to GPS timestamp
- Photo library integration
  - `saveToPhotoLibrary()` - Optional save
  - `loadFromPhotoLibrary()` - Legacy photo loading
  - Permission handling

**Why Test**: Handles storage; bugs cause data loss

---

### 2.2 CameraService
**Test Cases** (Requires device/simulator):
- Permission handling
  - Authorized → can capture
  - Denied → cannot capture
  - NotDetermined → requests permission
- Session configuration
  - Front camera switch
  - Back camera switch
  - Output connection management
- Zoom levels
  - Min/max bounds respected
  - Smooth transitions
- Flash modes
  - On/off toggling
  - State persistence
- Ultra-wide camera detection
  - Correct flag set based on device
- Device orientation
  - Video mirroring for front camera
  - No mirroring for back camera

**Why Test**: Complex AVFoundation logic; device-specific

---

### 2.3 HealthKitService
**Test Cases**:
- Authorization workflow
  - Request authorization
  - Check authorization status
  - Persist status to UserDefaults
- Data fetching
  - `fetchBodyComposition()` - All metrics async
  - Each metric has date attached
  - Nil handling for unavailable data
- Data types
  - Weight parsing
  - Body fat percentage (0-1 → multiply by 100)
  - Lean body mass
  - BMI

**Why Test**: HealthKit is device-specific; mock needed

---

## 3. UI/VIEW LAYER TESTS

### 3.1 Core User Workflows
**Test Cases**:
1. **Create Journey Workflow**
   - Open NewJourneySheet
   - Enter name
   - Save
   - Journey appears in JourneyView
   - Journey has empty photo/measurement lists

2. **Capture Photo Workflow**
   - Navigate to Camera tab
   - Request permission
   - Capture photo
   - Accept/retake
   - Photo appears in JourneyView
   - Ghost overlay toggles

3. **Add Measurement Workflow**
   - Open AddMeasurementSheet
   - Select type (weight, chest, etc.)
   - Enter value
   - Select unit (kg, lb, cm, inch, %)
   - Save
   - Appears in MeasurementDetailView

4. **View Progress Workflow**
   - Select journey
   - View photo grid
   - View measurements chart
   - Export comparison video

5. **Delete Journey Workflow**
   - Delete journey
   - Verify files cleaned up
   - Verify no orphaned data

---

### 3.2 Component Tests

#### PhotoEditViews
**Test Cases**:
- Previous/Next photo navigation
  - Disable when at start/end
  - Correct image displayed
  - Alignment state preserved
- Accessibility labels on navigation buttons
- Date edit opens date picker
- Adjust view opens alignment interface
- Delete with confirmation

#### MeasurementDetailView
**Test Cases**:
- Chart renders with data
- Time range selector works (1 week, 1 month, 3 months, 6 months, 1 year, all)
- Statistics display (min, max, avg, range)
- Empty state when no data
- CSV export functionality

#### JourneyView
**Test Cases**:
- Journey list displays
- Reordering journeys
- Selecting journey shows detail
- Long-press edit mode
- Bulk operations (select multiple, delete)
- Photo count displays correctly

#### CameraHostView + CameraViewModel
**Test Cases**:
- Camera preview displays
- Ghost overlay toggles and opacities work
- Timer countdown works
- Grid overlay toggles
- Zoom control works
- Tab switching stops camera (battery)

---

## 4. PERFORMANCE TESTS

### 4.1 Memory Management
**Test Cases**:
1. **Large Photo Set**
   - Load 100+ photos
   - Memory stays under 200MB
   - No crashes on iPhone 12/13

2. **Watch View with Many Photos**
   - Load watch view with 100+ photos
   - Memory stays under 150MB
   - Sliding window prevents full load
   - Scrolling is smooth (60 FPS)

3. **Cache Eviction**
   - Add 100 photos to cache
   - Force memory warning
   - Cache clears to free memory
   - App continues functioning

4. **Chart Rendering**
   - 1000+ measurement entries
   - Chart renders without lag
   - Scrolling smooth
   - Time range selection responsive

---

### 4.2 Database Performance
**Test Cases**:
1. **Query Performance**
   - Journey with 1000+ photos - queries fast
   - Index on [journeyId, date] improves speed
   - Measurement queries by type work quickly

2. **Pagination**
   - `fetchPaginated()` works correctly
   - Page 1, 2, 3 load correct data
   - `hasMore` flag accurate

3. **CloudKit Sync** (if configured)
   - Data syncs between devices
   - Conflict resolution works
   - Offline mode works

---

## 5. ERROR HANDLING TESTS

### 5.1 Crash Prevention
**Test Cases**:
1. **Force Unwrap Removal** (Already fixed)
   - Empty arrays handled
   - Nil values handled
   - Array bounds checked

2. **Division by Zero** (Already fixed)
   - Image dimension validation (PhotoStore:75-79)
   - Dimension validation (AdjustView:276-280)

3. **File Operations**
   - Missing photo file → graceful error
   - Permission denied → error message
   - Disk full → error message
   - Network error (HealthKit) → fallback data

4. **Permission Handling**
   - Camera denied → show error view
   - Photos denied → show error view
   - HealthKit denied → skip health data
   - Notifications denied → reminder view disabled

---

## 6. ACCESSIBILITY TESTS

### 6.1 VoiceOver
**Test Cases**:
- All buttons have accessibility labels ✅ (Verified)
- Navigation hints on PhotoEditViews ✅ (Added)
- Empty states have labels ✅ (Built into EmptyStateView)
- Loading states announced ✅ (Built into LoadingStateView)
- Form inputs labeled
- Image alt text

### 6.2 Dynamic Type
**Test Cases**:
- Text scales at accessibility sizes
- Layout doesn't break
- Numbers still readable

### 6.3 Motion
**Test Cases**:
- Reduce motion toggle respected
- Animations optional
- No animation spam

---

## 7. LOCALIZATION TESTS

**Test Cases**:
- All user-facing strings are in Localizable.strings
- Date formatting respects locale
- Number formatting respects locale
- Unit conversion (kg ↔ lbs, cm ↔ inches)
- Right-to-left language support

---

## 8. TEST INFRASTRUCTURE

### Recommended Setup
```swift
// Tests folder structure
ProgressPicTests/
├── Unit/
│   ├── Utilities/
│   │   ├── DateFormattersTests.swift
│   │   ├── StatsFormattersTests.swift
│   │   └── HapticFeedbackTests.swift
│   ├── Models/
│   │   ├── MeasurementTypeTests.swift
│   │   ├── UserProfileTests.swift
│   │   └── ModelsTests.swift
│   └── Services/
│       ├── PhotoStoreTests.swift
│       └── HealthKitServiceTests.swift
├── Integration/
│   ├── PhotoStoreIntegrationTests.swift
│   ├── CameraServiceTests.swift
│   └── DatabaseTests.swift
└── UI/
    ├── JourneyViewTests.swift
    ├── CameraHostViewTests.swift
    └── MeasurementDetailViewTests.swift
```

### Testing Frameworks
- **XCTest** - Built-in unit/integration tests
- **XCUITest** - UI automation tests
- **Combine+Testing** - Observable state testing
- **Mocking**: Create mocks for:
  - HealthKitService (use real data, not live HK)
  - CameraService (simulate photo capture)
  - PhotoStore (use temp directory)

---

## 9. PRIORITY RANKING

### Phase 1 (Critical) - 20-30 hours
1. DateFormatters unit tests (60 min)
2. StatsFormatters unit tests (60 min)
3. MeasurementType unit tests (45 min)
4. UserProfile unit tests (60 min)
5. PhotoStore integration tests (3 hours) ⭐ CRITICAL
6. Create Journey workflow test (1.5 hours)
7. Add Measurement workflow test (1.5 hours)

### Phase 2 (Important) - 20-30 hours
1. CameraService integration tests (2 hours)
2. HealthKitService mock + tests (2 hours)
3. JourneyView component tests (2 hours)
4. MeasurementDetailView tests (2 hours)
5. PhotoEditViews tests (2 hours)
6. Large dataset performance tests (3 hours)
7. Memory pressure tests (2 hours)

### Phase 3 (Nice to Have) - 15-20 hours
1. Accessibility audits (2 hours)
2. CloudKit sync tests (3 hours)
3. Video export tests (2 hours)
4. Localization tests (2 hours)
5. Error handling tests (2 hours)

---

## 10. EXPECTED COVERAGE AFTER TESTING

| Layer | Current | Target | Effort |
|-------|---------|--------|--------|
| Utilities | 0% | 95% | 4 hours |
| Models | 0% | 90% | 3 hours |
| Services | 0% | 80% | 6 hours |
| Views | 0% | 60% | 8 hours |
| Integration | 0% | 70% | 8 hours |
| **Overall** | **0%** | **75%** | **~30 hours** |

---

## TESTING CHECKLIST

### Before Implementing Tests
- [ ] Create XCTest target in Xcode
- [ ] Add test dependencies (if needed)
- [ ] Set up CI/CD (GitHub Actions or Xcode Cloud)
- [ ] Create test data/fixtures

### After Each Test Suite
- [ ] Run on device (not just simulator)
- [ ] Run on iOS 16 and iOS 17
- [ ] Check code coverage
- [ ] Run performance profiler

### Before Shipping
- [ ] All critical tests pass (Phase 1)
- [ ] Code coverage > 75%
- [ ] No memory leaks (Instruments)
- [ ] Performance benchmarks met
- [ ] Manual testing checklist complete

---

## REFERENCES

- **ANALYSIS_SUMMARY.md** - Recent code optimizations and fixes
- **CODEBASE_STRUCTURE.md** - Complete architecture overview
- **Xcode Testing Guide** - https://developer.apple.com/documentation/xctest
- **Swift Testing** (new framework) - Worth evaluating for future tests
