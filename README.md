# JohnnyCache

A modern, type-safe caching framework for Apple platforms with automatic memory management, LRU eviction, CloudKit sync, and cache stampede prevention.

## Features

- **Three-Tier Caching**: Automatic in-memory, on-disk, and CloudKit storage
- **CloudKit Sync**: Optional cloud-based caching synced across all your devices
- **Smart Asset Storage**: Automatically uses CKAsset for large data (configurable threshold)
- **True LRU Eviction**: Tracks access times for accurate least-recently-used eviction
- **Cache Expiration**: Optional `maxAge` and `newerThan` parameters for freshness control
- **Cache Stampede Prevention**: Deduplicates concurrent requests for the same key
- **Type-Safe**: Generic design works with any `Hashable` key and cacheable element
- **Automatic Size Management**: Configurable memory and disk limits with automatic purging
- **Async/Await Support**: Modern Swift concurrency with `@MainActor` safety
- **Protocol-Oriented**: Extend with custom key and element types
- **Built-in Types**: Works out-of-the-box with `Data`, `UIImage`/`NSImage`, any `Codable` type, plus `String` and `URL` keys
- **Production-Ready**: Comprehensive test coverage with Swift Testing

## Requirements

- macOS 14.0+ / iOS 16.0+ / watchOS 10.0+
- Swift 6.0+
- Xcode 16.0+

## Installation

### Swift Package Manager

Add JohnnyCache to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ios-tooling/JohnnyCache.git", from: "1.0.0")
]
```

Or in Xcode:
1. File > Add Package Dependencies
2. Enter the repository URL
3. Select your version requirements

## Quick Start

### Basic Usage

```swift
import JohnnyCache

// Create a cache for Data keyed by String
let cache = JohnnyCache<String, Data>()

// Store data
cache["user_profile"] = profileData

// Retrieve data (checks memory, then disk)
if let data = cache["user_profile"] {
    print("Found cached data!")
}

// Remove data
cache["user_profile"] = nil
```

### Image Caching

```swift
import JohnnyCache
import UIKit

// Create an image cache with URL keys
let imageCache = JohnnyCache<URL, UIImage>()

let imageURL = URL(string: "https://example.com/avatar.jpg")!

// Store image
imageCache[imageURL] = downloadedImage

// Retrieve image
if let cachedImage = imageCache[imageURL] {
    imageView.image = cachedImage
}
```

### Caching Codable Types

Any `Codable` type automatically conforms to `CacheableElement` - no extra code needed:

```swift
struct UserProfile: Codable, Sendable {
    let id: Int
    let name: String
    let email: String
    let createdAt: Date  // Dates use ISO8601 encoding
}

// Just use it directly - Codable conformance is automatic!
let cache = JohnnyCache<String, UserProfile>()

cache["user_123"] = UserProfile(id: 123, name: "Alice", email: "alice@example.com", createdAt: Date())

if let user = cache["user_123"] {
    print("Hello, \(user.name)!")
}
```

### Shared Image Cache

JohnnyCache provides a pre-configured global image cache:

```swift
// iOS/watchOS
let image = try await sharedImagesCache[async: imageURL]  // JohnnyCache<URL, UIImage>

// macOS
let image = try await sharedImagesCache[async: imageURL]  // JohnnyCache<URL, NSImage>
```

### Async Fetching with Automatic Caching

```swift
// Create cache with fetch closure
let cache = JohnnyCache<URL, Data> { url in
    // This closure is only called on cache miss
    let (data, _) = try await URLSession.shared.data(from: url)
    return data
}

// First call fetches from network and caches
let data1 = try await cache[async: imageURL]

// Second call returns cached data instantly
let data2 = try await cache[async: imageURL]

// Concurrent calls are deduplicated (stampede prevention)
await withTaskGroup(of: Data?.self) { group in
    for _ in 0..<10 {
        group.addTask { try? await cache[async: imageURL] }
    }
    // Only ONE network request is made!
}
```

### Cache Expiration

Control cache freshness with `maxAge` and `newerThan` parameters:

```swift
let cache = JohnnyCache<String, Data>()

// Only return if cached within the last 60 seconds
if let fresh = cache["key", maxAge: 60] {
    print("Fresh data!")
}

// Only return if cached after a specific date
let cutoff = Date().addingTimeInterval(-3600)  // 1 hour ago
if let recent = cache["key", newerThan: cutoff] {
    print("Recent data!")
}

// Combine both constraints
if let valid = cache["key", maxAge: 300, newerThan: lastKnownUpdate] {
    print("Valid data!")
}
```

With async fetching, expired items trigger a re-fetch:

```swift
let cache = JohnnyCache<URL, Data> { url in
    let (data, _) = try await URLSession.shared.data(from: url)
    return data
}

// Re-fetches if cached data is older than 5 minutes
let data = try await cache[async: apiURL, maxAge: 300]
```

## CloudKit Integration

Enable CloudKit caching to sync data across all your devices:

### Setup

1. **Enable iCloud Capability** in your Xcode project
   - Select your target → Signing & Capabilities
   - Add "iCloud" capability
   - Check "CloudKit"
   - Add or select a CloudKit container

2. **Configure Cache with CloudKit**

```swift
import CloudKit
import JohnnyCache

// Configure CloudKit
let container = CKContainer(identifier: "iCloud.com.yourcompany.yourapp")
let cloudKitInfo = JohnnyCache<URL, Data>.Configuration.CloudKitInfo(
    container: container,
    recordName: "CachedImage",    // CKRecord type name
    assetLimit: 50_000             // 50KB - larger data uses CKAsset
)

// Create cache with CloudKit enabled
var config = JohnnyCache<URL, Data>.Configuration(
    name: "ImageCache",
    inMemory: 50 * 1024 * 1024,    // 50 MB
    onDisk: 200 * 1024 * 1024      // 200 MB
)
config.cloudKitInfo = cloudKitInfo

let cache = JohnnyCache<URL, Data>(configuration: config) { url in
    // Fetch from network on cache miss
    let (data, _) = try await URLSession.shared.data(from: url)
    return data
}
```

### How It Works

With CloudKit enabled, the async subscript checks all three tiers:

```swift
// Checks: Memory → Disk → CloudKit → Network
let data = try await cache[async: imageURL]
```

**Cache Flow:**
1. Check in-memory cache (instant)
2. Check on-disk cache (very fast)
3. **Check CloudKit** (fast, synced across devices)
4. Call fetch closure (slow, network-dependent)
5. Store result in all three tiers

**Storage Strategy:**
- **Small data** (<50KB by default): Stored in CKRecord's `data` field
- **Large data** (≥50KB by default): Stored as `CKAsset` for efficiency
- CloudKit operations happen in background to avoid blocking UI

### Clearing CloudKit Cache

```swift
// Clear local caches only (old method, still works)
cache.clearAll(inMemory: true, onDisk: true)

// Clear CloudKit cache only
try await cache.clearAllCaches(inMemory: false, onDisk: false, cloudKit: true)

// Clear everything including CloudKit
try await cache.clearAllCaches(inMemory: true, onDisk: true, cloudKit: true)
```

⚠️ **Important**: Clearing CloudKit cache affects **all devices** signed into your iCloud account!

### CloudKit Dashboard

You can view cached records in the [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard):

1. Select your container
2. Go to Public Data → Records
3. Filter by your `recordName` (e.g., "CachedImage")
4. Inspect records to see:
   - `data` field for small items
   - `data_asset` field with CKAsset for large items

### Requirements

- iCloud account (user must be signed in)
- CloudKit entitlements in your app
- Network connection for CloudKit operations
- Uses public CloudKit database by default

## Configuration

### Custom Cache Configuration

```swift
let config = JohnnyCache<String, Data>.Configuration(
    location: URL.cachesDirectory.appendingPathComponent("MyCache"),
    inMemory: 50 * 1024 * 1024,    // 50 MB in-memory limit
    onDisk: 500 * 1024 * 1024       // 500 MB on-disk limit
)

let cache = JohnnyCache<String, Data>(configuration: config)
```

### Memory-Only Cache

```swift
let config = JohnnyCache<String, Data>.Configuration(
    location: nil  // No disk storage
)

let memoryCache = JohnnyCache<String, Data>(configuration: config)
```

### Error Handling

```swift
let cache = JohnnyCache<String, Data>()

// Custom error handler
cache.errorHandler = { error, context in
    print("Cache error: \(context) - \(error)")
    // Send to analytics, crash reporting, etc.
}
```

## Advanced Usage

### Custom Cacheable Types

For non-Codable types or when you need custom serialization, conform to `CacheableElement`:

```swift
struct UserProfile: CacheableElement, Sendable {
    let name: String
    let avatar: URL

    // Serialize to Data
    func toData() throws -> Data {
        try JSONEncoder().encode(self)
    }

    // Deserialize from Data
    static func from(data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }

    // Memory cost in bytes (be accurate for proper LRU eviction)
    var cacheCost: UInt64 {
        UInt64(name.utf8.count + avatar.absoluteString.utf8.count)
    }

    // File type for disk storage
    static var uttype: UTType { .json }
}

// Use it
let cache = JohnnyCache<String, UserProfile>()
cache["user_123"] = UserProfile(name: "Alice", avatar: avatarURL)
```

> **Note**: `Codable` types get automatic `CacheableElement` conformance. Only implement this protocol manually when you need custom serialization or more accurate cost calculation.

### Custom Key Types

Conform to `CacheableKey` for custom key types:

```swift
struct CacheKey: Hashable, Sendable, CacheableKey {
    let userId: String
    let category: String

    var stringRepresentation: String {
        "\(userId)_\(category)"
    }
}

let cache = JohnnyCache<CacheKey, Data>()
cache[CacheKey(userId: "123", category: "photos")] = photoData
```

### Manual Cache Management

```swift
let cache = JohnnyCache<String, Data>()

// Clear only in-memory cache
cache.clearAll(inMemory: true, onDisk: false)

// Clear only disk cache
cache.clearAll(inMemory: false, onDisk: true)

// Clear everything
cache.clearAll()

// Manual purging
cache.purgeInMemory(downTo: 10 * 1024 * 1024)  // Purge down to 10MB
```

## How It Works

### Two-Tier Architecture

1. **In-Memory Cache**: Fast dictionary-based storage with LRU eviction
   - Items are stored with access timestamps
   - When memory limit is exceeded, purges to 75% of limit
   - Evicts least-recently-accessed items first

2. **On-Disk Cache**: Persistent file-based storage
   - Files named using sanitized key representations
   - Modification dates updated on access for LRU tracking
   - Automatic purging when disk limit is exceeded

### Cache Stampede Prevention

When multiple concurrent requests are made for the same uncached key:

```swift
// Without stampede prevention (bad):
Task { await fetch("image.jpg") }  // Makes network request
Task { await fetch("image.jpg") }  // Makes DUPLICATE request
Task { await fetch("image.jpg") }  // Makes DUPLICATE request

// With JohnnyCache (good):
Task { try? await cache[async: "image.jpg"] }  // Makes network request
Task { try? await cache[async: "image.jpg"] }  // Waits for first request
Task { try? await cache[async: "image.jpg"] }  // Waits for first request
// Result: Only ONE network request, all tasks get the same result
```

### Access Pattern

```
cache[key]
    ↓
Check in-memory cache
    ↓ (miss)
Check disk cache
    ↓ (hit)
Load from disk → Store in memory → Return
    ↓ (miss)
Return nil

try await cache[async: key]
    ↓
Check in-memory cache
    ↓ (miss)
Check disk cache
    ↓ (miss)
Check if fetch already in-flight
    ↓ (yes: wait for it)
    ↓ (no: start new fetch)
Call fetch closure → Store result → Return
    ↓ (error)
Clean up in-flight state → Throw (allows retry)
```

## Best Practices

### 1. Choose Appropriate Limits

```swift
// For image caches
let imageConfig = JohnnyCache<URL, UIImage>.Configuration(
    inMemory: 100 * 1024 * 1024,    // 100 MB - images are expensive
    onDisk: 1024 * 1024 * 1024       // 1 GB - plenty of room
)

// For small data caches
let dataConfig = JohnnyCache<String, Data>.Configuration(
    inMemory: 10 * 1024 * 1024,     // 10 MB - data is compact
    onDisk: 50 * 1024 * 1024         // 50 MB - moderate storage
)
```

### 2. Implement Accurate Cost Calculation

```swift
extension MyCustomType: CacheableElement {
    var cacheCost: UInt64 {
        // Be accurate! This affects eviction
        var cost: UInt64 = 0
        cost += UInt64(MemoryLayout<Self>.size)
        cost += UInt64(stringProperty.utf8.count)
        cost += UInt64(arrayProperty.count * MemoryLayout<Element>.size)
        return cost
    }
}
```

### 3. Use Appropriate Keys

```swift
// Good: Specific, meaningful keys
cache["user_\(userId)_profile"]
cache[URL(string: "https://api.example.com/data")!]

// Bad: Generic keys that might collide
cache["data"]
cache["temp"]
```

### 4. Handle Errors Gracefully

```swift
let cache = JohnnyCache<URL, Data> { url in
    do {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    } catch {
        // Log error, return nil, or re-throw
        logger.error("Failed to fetch \(url): \(error)")
        throw error
    }
}
```

## Testing

JohnnyCache includes comprehensive test coverage using Swift Testing:

```bash
# Run tests in Xcode
Cmd + U

# Or via command line (requires Xcode)
xcodebuild test -scheme JohnnyCache -destination 'platform=macOS'
```

Test suites cover:
- Basic cache operations (CRUD, persistence)
- Cache age and expiration (maxAge, newerThan)
- Codable type caching (serialization, dates, nested types)
- Cost accounting accuracy
- LRU eviction behavior
- Cache stampede prevention
- Concurrent access patterns
- Error handling

## Performance Characteristics

| Operation | In-Memory | On-Disk |
|-----------|-----------|---------|
| Read (hit) | O(1) | O(1) + file I/O |
| Write | O(1) | O(1) + file I/O |
| Eviction | O(n log n)* | O(n log n)* |

*Where n is the number of cached items. Eviction sorts by access time.

**Note**: Disk I/O is synchronous and runs on the main thread. Keep cached items reasonably sized to avoid UI jank.

## Architecture

```
JohnnyCache/
├── JohnnyCache/
│   ├── JohnnyCache.swift              # Core cache class
│   ├── JohnnyCache+RetrieveValue.swift # Get operations
│   ├── JohnnyCache+StoreValues.swift  # Set/remove operations
│   ├── JohnnyCache+CacheLimits.swift  # Eviction & purging
│   ├── JohnnyCache.Configuration.swift # Configuration
│   └── CachedItem.swift               # Internal item wrapper
├── CacheableKey.swift             # Key protocol
├── CacheableElement.swift         # Element protocol
├── SharedCaches.swift             # Pre-configured sharedImagesCache
├── Extensions/
│   ├── Codable.swift              # Automatic CacheableElement for Codable types
│   └── FileManager.swift          # File utilities
└── Cacheable Elements/
    ├── Data+CacheableElement.swift
    ├── UIImage+CacheableElement.swift  # iOS/watchOS
    └── NSImage+CacheableElement.swift  # macOS
```

## Thread Safety

JohnnyCache is annotated with `@MainActor`, ensuring all operations execute on the main thread. This provides:

- **Data race safety** through Swift's actor isolation
- **Predictable behavior** for UI-related caching (images, etc.)
- **Simple concurrency model** without manual synchronization

If you need background caching, wrap calls in `Task { @MainActor in ... }`:

```swift
Task.detached {
    await MainActor.run {
        cache[key] = value
    }
}
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes with descriptive messages
4. Add tests for new functionality
5. Ensure all tests pass (`Cmd + U` in Xcode)
6. Push to your branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## License

JohnnyCache is available under the MIT license. See the [LICENSE](LICENSE) file for more info.
