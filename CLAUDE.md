# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

JohnnyCache is a Swift Package Manager (SPM) library that provides a simple, type-safe caching framework for Apple platforms (macOS 14+, iOS 16+, watchOS 10+). It implements a three-tier caching system with in-memory, on-disk, and CloudKit storage, automatic cache size management, cache stampede prevention, and protocol-based extensibility.

## Common Commands

### Building
```bash
swift build
```

### Testing
```bash
swift test
```

### Running a Single Test
```bash
swift test --filter JohnnyCacheBasicTests/testBasicSetGet
```

### Opening in Xcode
```bash
open Package.swift
```

## Architecture

### Core Design Pattern

JohnnyCache uses a **generic, protocol-based architecture** with two key protocols:

1. **`CacheableKey`** - Defines what can be used as a cache key (must be Hashable & Sendable)
   - Requires `stringRepresentation` for file system storage
   - Default implementations: `String`, `URL`

2. **`CacheableElement`** - Defines what can be cached
   - Requires serialization methods: `toData()` and `from(data:)`
   - Must specify `cacheCost` (UInt64) for memory management
   - Must specify `uttype` (UTType) for file system storage
   - Default implementations: `Data`, `UIImage` (iOS), `NSImage` (macOS), and any `Codable` type

### Three-Tier Caching System

The `JohnnyCache<Key, Element>` class (`@MainActor`) provides:

1. **In-Memory Cache**: Dictionary-based storage with LRU eviction
   - Tracked via `inMemoryCost`
   - Automatic purging when exceeding `configuration.inMemoryLimit`
   - Purges down to 75% of limit when triggered

2. **On-Disk Cache**: File-based storage in configured directory
   - Files named using `key.stringRepresentation` (slashes → dashes, colons → semicolons)
   - Tracked via `onDiskCost`
   - Automatic purging based on file creation dates
   - Purges down to 75% of limit when triggered

3. **CloudKit Cache** (optional): Cloud-based storage synced across devices
   - Configured via `Configuration.cloudKitInfo`
   - Small data (<50KB default) stored directly in CKRecord `data` field
   - Large data (≥50KB default) stored as `CKAsset` in `data_asset` field
   - Uses public database by default for easy cross-device access
   - Background sync operations to avoid blocking UI

### Cache Stampede Prevention

When multiple concurrent requests are made for the same uncached key, only one fetch executes. Other requests wait for the same result via `inFlightFetches` task tracking.

### Access Patterns

- **Synchronous**: `cache[key]` - returns immediately, checks memory then disk (not CloudKit)
- **Async with fetch**: `try await cache[async: key]` - checks memory → disk → CloudKit → fetch closure, with stampede prevention

### Cache Expiration

Both subscripts support optional age parameters:
- **`maxAge: TimeInterval?`** - Only return if cached within this many seconds
- **`newerThan: Date?`** - Only return if cached after this date

Examples:
- `cache["key", maxAge: 60]` - returns nil if cached more than 60 seconds ago
- `cache["key", newerThan: lastUpdate]` - returns nil if cached before `lastUpdate`
- `try await cache[async: "key", maxAge: 300]` - re-fetches if older than 5 minutes

Age is tracked via `cachedAt` timestamp (separate from `accessedAt` used for LRU). On-disk items use file creation date.

### Shared Caches

`sharedImagesCache` is a pre-configured global cache for URL-keyed images:
- iOS/watchOS: `JohnnyCache<URL, UIImage>`
- macOS: `JohnnyCache<URL, NSImage>`

### Key Files

- `JohnnyCache/JohnnyCache.swift` - Core cache class with subscript access and `clearAllCaches()`
- `JohnnyCache/JohnnyCache.Configuration.swift` - Configuration including `CloudKitInfo`
- `JohnnyCache/JohnnyCache+CacheLimits.swift` - Cache purging logic
- `JohnnyCache/JohnnyCache+RetrieveValue.swift` - Memory, disk, and CloudKit retrieval
- `JohnnyCache/JohnnyCache+StoreValues.swift` - Memory, disk, and CloudKit storage; `clearCloudKitCache()`
- `JohnnyCache/JohnnyCache+CloudKit.swift` - CloudKit sign-in detection
- `JohnnyCache/CachedItem.swift` - Internal wrapper with `cachedAt` and `accessedAt` timestamps
- `CacheableKey.swift` & `CacheableElement.swift` - Protocol definitions
- `Extensions/Codable.swift` - Default CacheableElement conformance for Codable types
- `Extensions/FileManager.swift` - File enumeration and size utilities
- `Cacheable Elements/` - Protocol conformances for Data, UIImage, NSImage

## Key Implementation Details

### File System Handling
- Cache directory is created automatically on init
- Keys with slashes/colons are converted (e.g., "foo/bar" → "foo-bar", "http:" → "http;")
- Files are stored with UTType-based extensions
- Size tracking uses `FileManager.FileInfo` struct with creation dates for LRU

### Cache Size Management
- Size limits are enforced **after** adding items (not before)
- Purging is triggered when cost exceeds limit
- Purge targets 75% of limit to reduce thrashing
- In-memory uses `accessedAt` timestamp for LRU eviction
- On-disk uses file modification dates for LRU eviction
- `cachedAt` tracks original cache time (for expiration), separate from `accessedAt` (for LRU)

### Error Handling
- Errors are logged via `report(error:context:)` method using OSLog
- Custom error handler can be set via `cache.errorHandler`
- Failed disk reads/writes don't crash - they return nil/skip storage
- Synchronous subscript catches errors internally; async subscript throws

## CloudKit Integration

### Configuration

CloudKit caching is opt-in via `CloudKitInfo`:

```swift
let container = CKContainer(identifier: "iCloud.com.example.myapp")
let cloudKitInfo = JohnnyCache<URL, Data>.Configuration.CloudKitInfo(
    container: container,
    recordName: "CachedImage",
    assetLimit: 50_000  // 50KB threshold for CKAsset usage
)

var config = JohnnyCache<URL, Data>.Configuration(
    name: "ImageCache",
    inMemory: 50 * 1024 * 1024,
    onDisk: 200 * 1024 * 1024
)
config.cloudKitInfo = cloudKitInfo

let cache = JohnnyCache<URL, Data>(configuration: config) { url in
    // Fetch from network
}
```

### Storage Strategy

- Data **< assetLimit**: Stored in CKRecord's `data` field directly
- Data **≥ assetLimit**: Stored as CKAsset in `data_asset` field (with temp file cleanup)
- Record ID format: `"{recordName}:{key.stringRepresentation}"`

### Async Flow with CloudKit

When using `cache[async: key]`:
1. Check in-memory cache
2. Check on-disk cache
3. **Check CloudKit** (if configured and signed in)
4. Call fetch closure (if provided)
5. Store result in all three tiers (CloudKit storage happens in background Task)

### Clearing CloudKit Cache

```swift
// Clear CloudKit only (affects all devices!)
try await cache.clearAllCaches(inMemory: false, onDisk: false, cloudKit: true)

// Clear everything including CloudKit
try await cache.clearAllCaches(inMemory: true, onDisk: true, cloudKit: true)

// Note: Old clearAll() still works for local-only clearing (backward compatible)
cache.clearAll(inMemory: true, onDisk: true)
```

**Important**: `clearAllCaches(cloudKit: true)` queries and deletes ALL records of the configured recordName from CloudKit's public database. This affects all devices signed into the same iCloud account.

### CloudKit Sign-In Detection

The cache automatically detects CloudKit availability via `isSignedInToCloudKit` property:
- Checks on init using `container.accountStatus()`
- Only attempts CloudKit operations when signed in
- Silently skips CloudKit if not available

## Platform Support

- macOS 14+, iOS 16+, watchOS 10+
- Swift 6.0+ with strict concurrency
- Uses `@MainActor` for thread safety
- Protocols require `Sendable` conformance
- Conditional compilation: `#if canImport(UIKit)` for iOS, `#if canImport(Cocoa)` for macOS
- CloudKit requires entitlements: iCloud capability with CloudKit service enabled

## Test Harness

The `Tests/Test Harness/` directory contains a complete SwiftUI demo app:

### Features
- @Observable pattern (iOS 17+) for reactive UI
- Image gallery with 12 sample images (Lorem Picsum)
- Real-time cache statistics (memory/disk usage)
- CloudKit account status checking
- Color-coded indicators: 🟢 cache hit, 🟠 network fetch
- Cache clearing UI with CloudKit options

### Running the Test Harness
1. Open `Tests/Test Harness/JohnnyCacheTest.xcodeproj`
2. Add Swift files to target if needed (see `SETUP_GUIDE.md`)
3. Link JohnnyCache package (local package in parent directory)
4. Verify entitlements include CloudKit container
5. Build and run on iOS 17+ device/simulator with iCloud signed in

### Key Test Harness Files
- `ImageCacheManager.swift` - @Observable cache manager with CloudKit config
- `ImageGalleryView.swift` - Main gallery with cache controls
- `SettingsView.swift` - Cache stats, CloudKit status, and clearing UI
- `CachedImageView.swift` - Image view with load source indicators
