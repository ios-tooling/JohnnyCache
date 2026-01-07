# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

JohnnyCache is a Swift Package Manager (SPM) library that provides a simple, type-safe caching framework for Apple platforms (macOS 12+, iOS 16+, watchOS 10+). It implements a two-tier caching system with both in-memory and on-disk storage, automatic cache size management, and protocol-based extensibility.

## Common Commands

### Building
```bash
swift build
```

### Testing
```bash
swift test
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
   - Default implementations: `Data`, `UIImage` (iOS only)

### Two-Tier Caching System

The `JohnnyCache<Key, Element>` class (`@MainActor`) provides:

1. **In-Memory Cache**: Dictionary-based storage with LRU eviction
   - Tracked via `inMemoryCost`
   - Automatic purging when exceeding `configuration.inMemoryLimit`
   - Purges down to 75% of limit when triggered

2. **On-Disk Cache**: File-based storage in configured directory
   - Files named using `key.stringRepresentation` (slashes replaced with dashes)
   - Tracked via `onDiskCost`
   - Automatic purging based on file creation dates
   - Purges down to 75% of limit when triggered

### Access Patterns

- **Synchronous**: `cache[key]` - returns immediately, checks memory then disk
- **Async with fetch**: `await cache[async: key]` - falls back to provided `FetchElement` closure if cache misses

### Key Files

- `JohnnyCache.swift` - Core cache implementation with subscript access
- `JohnnyCache.Configuration.swift` - Configuration with default limits (100MB memory, 1GB disk)
- `JohnnyCache+CacheLimits.swift` - Cache purging logic
- `CachedItem.swift` - Internal wrapper storing element + metadata (storedAt timestamp)
- `CacheableKey.swift` & `CacheableElement.swift` - Protocol definitions
- `Extensions/FileManager.swift` - File enumeration and size utilities
- `Cacheable Elements/` - Protocol conformances for Data and UIImage

## Key Implementation Details

### File System Handling
- Cache directory is created automatically on init
- Keys with slashes are converted (e.g., "foo/bar" becomes "foo-bar")
- Files are stored with UTType-based extensions
- Size tracking uses `FileManager.FileInfo` struct with creation dates for LRU

### Cache Size Management
- Size limits are enforced **after** adding items (not before)
- Purging is triggered when cost exceeds limit
- Purge targets 75% of limit to reduce thrashing
- In-memory uses `storedAt` timestamp for LRU
- On-disk uses file creation dates for LRU

### Error Handling
- Errors are logged via `report(error:context:)` method (currently prints to console)
- Failed disk reads/writes don't crash - they return nil/skip storage
- No throwing from subscripts - errors are caught internally

## Platform Support

- macOS 12+, iOS 16+, watchOS 10+
- Uses `@MainActor` for thread safety
- Protocols require `Sendable` conformance
- Conditional compilation for UIKit (`#if canImport(UIKit)`)
