# JohnnyCache

A type-safe, three-tier caching framework for Apple platforms (macOS 14+, iOS 16+, watchOS 10+) with in-memory, on-disk, and optional CloudKit storage.

## Requirements

- macOS 14.0+ / iOS 14.0+ / tvOS 16.0+ / watchOS 10.0+ / visionOS 1.0+
- Swift 6.0+ / Xcode 16.0+

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/ios-tooling/JohnnyCache.git", from: "1.0.0")
]
```

---

## Core API

`JohnnyCache<Key: CacheableKey, Element: CacheableElement>` is `@MainActor`.

### Reading and Writing

```swift
// Synchronous — checks memory then disk, never network
cache["key"]                              // Element?
cache["key", maxAge: 60]                  // nil if cached > 60s ago
cache["key", newerThan: date]             // nil if cached before date

// Asynchronous — checks memory → disk → CloudKit → fetch closure
try await cache[async: "key"]
try await cache[async: "key", maxAge: 300]

// Writing
cache["key"] = value                      // sets all tiers
cache["key"] = nil                        // removes from all tiers
cache.set(value, forKey: "key")           // equivalent to subscript set
cache.clearValue(forKey: "key")           // equivalent to cache["key"] = nil
```

### Cache Clearing

```swift
cache.clearAll()                          // clears memory + disk (sync)
cache.clearAll(inMemory: true, onDisk: false)

try await cache.clearAllCaches()                              // memory + disk
try await cache.clearAllCaches(cloudKit: true)                // + CloudKit (all devices!)
try await cache.clearAllCaches(inMemory: false, onDisk: false, cloudKit: true)
```

### Observing Changes

```swift
// Register a handler called whenever a key's value changes
let id = UUID()
cache.addObserver(for: "key", id: id) { element in
    // called on @MainActor whenever cache["key"] is written
}
cache.removeObserver(for: "key", id: id)
```

### SwiftUI Integration

```swift
// Observe a cache key and react to changes in a View
.onCacheChange(in: cache, for: "key") { value in
    self.value = value
}

// With a synchronous fallback initial value
.onCacheChange(in: cache, for: "key", initial: defaultValue) { value in
    self.value = value
}

// With an async fallback initial value
.onCacheChange(in: cache, for: "key", initial: { await fetchDefault() }) { value in
    self.value = value
}
```

The modifier fires `action` immediately with the current cached value (if any), then calls `action` on every subsequent write to that key. If no cached value exists and an `initial` closure is provided, it is awaited and the result is stored before calling `action`.

---

## Initialization

```swift
// Minimal — uses default config (disk cache in Caches directory)
let cache = JohnnyCache<String, Data>()

// With fetch closure — called on cache miss
let cache = JohnnyCache<URL, UIImage> { url in
    let (data, _) = try await URLSession.shared.data(from: url)
    return UIImage(data: data)
}

// With custom configuration
let config = JohnnyCache<URL, UIImage>.Configuration(
    name: "Images",
    inMemory: 100 * 1024 * 1024,   // 100 MB
    onDisk:   500 * 1024 * 1024    // 500 MB
)
let cache = JohnnyCache<URL, UIImage>(configuration: config) { url in ... }
```

### Shared Global Cache

```swift
// Pre-configured URL → UIImage/NSImage cache
let image = try await sharedImagesCache[async: imageURL]
```

---

## CloudKit

CloudKit support is opt-in via `Configuration.CloudKitInfo`.

### Setup

1. Enable the iCloud capability with CloudKit in your Xcode target.
2. Configure the cache:

```swift
import CloudKit

let cloudKitInfo = JohnnyCache<URL, Data>.Configuration.CloudKitInfo(
    container: CKContainer(identifier: "iCloud.com.example.myapp"),
    recordName: "CachedData",   // CKRecord type name
    assetLimit: 50_000          // bytes; larger data uses CKAsset (default: 50KB)
)

var config = JohnnyCache<URL, Data>.Configuration(name: "DataCache")
config.cloudKitInfo = cloudKitInfo

let cache = JohnnyCache<URL, Data>(configuration: config) { url in
    let (data, _) = try await URLSession.shared.data(from: url)
    return data
}
```

### Behavior

- `try await cache[async: key]` checks memory → disk → CloudKit → fetch closure.
- CloudKit writes happen in a background `Task` so they don't block the return.
- Small data (<`assetLimit`): stored in CKRecord `data` field.
- Large data (≥`assetLimit`): stored as `CKAsset` in `data_asset` field.
- CloudKit is silently skipped when the user is not signed into iCloud.
- Record ID format: `"{recordName}:{key.stringRepresentation}"`.

> **Warning:** `clearAllCaches(cloudKit: true)` deletes all records of the configured `recordName` from CloudKit's public database — this affects all devices.

---

## Supported Types

### Built-in Key Types

| Type | Notes |
|------|-------|
| `String` | Direct use |
| `URL` | Used for `sharedImagesCache` |

### Built-in Element Types

| Type | Platform |
|------|----------|
| `Data` | All |
| `UIImage` | iOS / watchOS |
| `NSImage` | macOS |
| Any `Codable` | All — automatic conformance |

### Custom Key Type

```swift
struct CacheKey: Hashable, Sendable, CacheableKey {
    let userId: String
    let category: String
    var stringRepresentation: String { "\(userId)_\(category)" }
}
```

### Custom Element Type

```swift
struct MyModel: CacheableElement, Sendable {
    // Serialization
    func toData() throws -> Data { try JSONEncoder().encode(self) }
    static func from(data: Data) throws -> Self { try JSONDecoder().decode(Self.self, from: data) }

    // Memory cost in bytes (used for LRU eviction)
    var cacheCost: UInt64 { UInt64(MemoryLayout<Self>.size) }

    // File extension for on-disk storage
    static var uttype: UTType { .json }
}
```

> `Codable` types get automatic `CacheableElement` conformance. Only implement the protocol manually for custom serialization or accurate cost accounting.

---

## How Caching Works

### Lookup Order

**Synchronous** (`cache[key]`):
```
Memory → Disk → nil
```

**Asynchronous** (`try await cache[async: key]`):
```
Memory → Disk → CloudKit (if configured) → fetch closure (if provided) → nil
```

On a fetch closure hit, the result is stored in all applicable tiers before returning. CloudKit writes are fire-and-forget (background `Task`).

### Cache Stampede Prevention

When multiple concurrent async lookups request the same uncached key simultaneously, only one fetch runs. All callers await the same `Task<Element?, Error>` stored in `inFlightFetches`.

### Size Management

- Limits are enforced **after** adding items.
- When a limit is exceeded, the cache purges to 75% of the limit.
- In-memory eviction uses `accessedAt` (LRU).
- On-disk eviction uses file modification dates.
- `cachedAt` tracks when an item was first cached (used for `maxAge`/`newerThan`), separate from `accessedAt`.

### Thread Safety

All operations are `@MainActor`. CloudKit and fetch closures are awaited within a `Task { @MainActor in ... }`.

---

## Error Handling

```swift
// Default: errors are logged via OSLog
// Custom: override the error handler
cache.errorHandler = { error, context in
    MyAnalytics.report(error, context: context)
}
```

Disk read/write errors do not throw — they log and return nil. The async subscript throws on fetch closure errors.

---

## Testing

```bash
swift test
swift test --filter JohnnyCacheBasicTests
swift test --filter JohnnyCacheBasicTests/testBasicSetGet
```

72 tests across: basic CRUD, expiration, CloudKit logic, Codable serialization, cost accounting, LRU eviction, stampede prevention, concurrency.

---

## Architecture

```
Sources/JohnnyCache/
├── JohnnyCache/
│   ├── JohnnyCache.swift                  # Core class: subscripts, set/clear, observers
│   ├── JohnnyCache+RetrieveValue.swift    # Memory, disk, CloudKit reads
│   ├── JohnnyCache+StoreValues.swift      # Memory, disk, CloudKit writes; observer notification
│   ├── JohnnyCache+CacheLimits.swift      # Size enforcement and LRU eviction
│   ├── JohnnyCache+CloudKit.swift         # iCloud sign-in detection
│   ├── JohnnyCache.Configuration.swift    # Configuration + CloudKitInfo
│   └── CachedItem.swift                   # Internal wrapper (element, cachedAt, accessedAt)
├── CacheableKey.swift                     # Key protocol (Hashable + stringRepresentation)
├── CacheableElement.swift                 # Element protocol (toData, from, cacheCost, uttype)
├── SharedCaches.swift                     # sharedImagesCache global
├── Extensions/
│   ├── Codable.swift                      # Automatic CacheableElement for Codable
│   ├── FileManager.swift                  # File enumeration and size utilities
│   ├── URL.swift                          # URL utilities
│   └── View+OnCacheChange.swift           # SwiftUI .onCacheChange modifier
└── Cacheable Elements/
    ├── Data+CacheableElement.swift
    ├── UIImage+CacheableElement.swift     # iOS / watchOS
    └── NSImage+CacheableElement.swift     # macOS
```

---

## Demo App

A SwiftUI demo app is in `Tests/Test Harness/JohnnyCacheTest.xcodeproj`. It demonstrates CloudKit integration, cache statistics, and the `@Observable` pattern (iOS 17+).

---

## License

MIT. See [LICENSE](LICENSE).
