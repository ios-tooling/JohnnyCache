# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

JohnnyCache is a Swift Package Manager (SPM) library that provides a simple, type-safe caching framework for Apple platforms (macOS 14+, iOS 14+, watchOS 10+). It implements a two-tier caching system with both in-memory and on-disk storage, automatic cache size management, cache stampede prevention, and protocol-based extensibility.

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

### Two-Tier Caching System

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

### Cache Stampede Prevention

When multiple concurrent requests are made for the same uncached key, only one fetch executes. Other requests wait for the same result via `inFlightFetches` task tracking.

### Access Patterns

- **Synchronous**: `cache[key]` - returns immediately, checks memory then disk
- **Async with fetch**: `try await cache[async: key]` - falls back to provided `FetchElement` closure if cache misses, with stampede prevention

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

- `JohnnyCache/JohnnyCache.swift` - Core cache class with subscript access
- `JohnnyCache/JohnnyCache.Configuration.swift` - Configuration (default: 100MB memory, 1GB disk)
- `JohnnyCache/JohnnyCache+CacheLimits.swift` - Cache purging logic
- `JohnnyCache/JohnnyCache+RetrieveValue.swift` - Memory and disk retrieval
- `JohnnyCache/JohnnyCache+StoreValues.swift` - Memory and disk storage
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

## Platform Support

- macOS 14+, iOS 14+, watchOS 10+
- Swift 6.0+ with strict concurrency
- Uses `@MainActor` for thread safety
- Protocols require `Sendable` conformance
- Conditional compilation: `#if canImport(UIKit)` for iOS, `#if canImport(Cocoa)` for macOS
