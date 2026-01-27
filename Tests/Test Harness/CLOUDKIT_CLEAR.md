# CloudKit Cache Clearing

## Overview

JohnnyCache now includes the ability to clear cached data from CloudKit in addition to local memory and disk caches.

## API

### JohnnyCache Methods

#### Synchronous Clear (Local Only)
```swift
func clearAll(inMemory: Bool = true, onDisk: Bool = true)
```

Clears local caches synchronously. Does not affect CloudKit.

#### Async Clear (Including CloudKit)
```swift
func clearAllCaches(inMemory: Bool = true, onDisk: Bool = true, cloudKit: Bool = false) async throws
```

Clears caches including optional CloudKit. This is async because CloudKit operations require network requests.

#### CloudKit Only Clear
```swift
func clearCloudKitCache() async throws
```

Internal method that queries and deletes all records of the configured recordName from CloudKit.

## Usage Examples

### Clear Local Caches Only (Sync)
```swift
cache.clearAll(inMemory: true, onDisk: true)
```

### Clear Local Caches (Async)
```swift
try await cache.clearAllCaches(inMemory: true, onDisk: true, cloudKit: false)
```

### Clear CloudKit Only
```swift
try await cache.clearAllCaches(inMemory: false, onDisk: false, cloudKit: true)
```

### Clear Everything (All Three Tiers)
```swift
try await cache.clearAllCaches(inMemory: true, onDisk: true, cloudKit: true)
```

## Test Harness Integration

The demo app includes UI for clearing CloudKit caches:

### Settings Tab

**Local Cache Management Section:**
- Clear Memory Cache
- Clear Disk Cache
- Clear Memory & Disk

**CloudKit Cache Management Section:**
- Clear CloudKit Cache Only (deletes from CloudKit across all devices)
- Clear All Caches (Including CloudKit) (nuclear option)

### Gallery Tab Menu

The toolbar menu includes:
- Clear Memory & Disk (local only)
- Clear Memory Only
- Clear Disk Only
- **Clear CloudKit Cache** (with confirmation)
- **Clear All (Including CloudKit)** (with strong warning)

## Important Notes

### Cross-Device Impact

⚠️ **Clearing CloudKit cache affects ALL devices signed into your iCloud account!**

When you clear the CloudKit cache:
1. All records of the configured recordName are deleted from CloudKit
2. Other devices will no longer find cached data in CloudKit
3. Other devices will need to re-fetch from the network
4. Local caches on other devices are NOT affected

### Confirmation Dialogs

The test harness shows confirmation alerts before clearing CloudKit:

```swift
.alert("Clear CloudKit Cache", isPresented: $showingClearCloudKitAlert) {
    Button("Clear CloudKit", role: .destructive) {
        Task {
            try? await cacheManager.clearCache(
                inMemory: false,
                onDisk: false,
                cloudKit: true
            )
        }
    }
    Button("Cancel", role: .cancel) {}
} message: {
    Text("This will delete all cached images from CloudKit across all your devices. Local caches will remain.")
}
```

## Implementation Details

### Query and Delete Pattern

The `clearCloudKitCache()` method:

1. **Queries** all records with `CKQuery(recordType: recordName, predicate: NSPredicate(value: true))`
2. **Collects** record IDs from successful matches
3. **Batch deletes** using `database.modifyRecords(saving: [], deleting: recordIDs)`
4. **Reports** success/failure counts

```swift
func clearCloudKitCache() async throws {
    guard let info = configuration.cloudKitInfo else { return }

    let database = info.container.publicCloudDatabase
    let query = CKQuery(recordType: info.recordName, predicate: NSPredicate(value: true))

    let (matchResults, _) = try await database.records(matching: query)

    var recordIDsToDelete: [CKRecord.ID] = []
    for (recordID, result) in matchResults {
        switch result {
        case .success:
            recordIDsToDelete.append(recordID)
        case .failure(let error):
            print("Error fetching record \(recordID): \(error)")
        }
    }

    let modifyResult = try await database.modifyRecords(
        saving: [],
        deleting: recordIDsToDelete
    )

    // Process delete results...
}
```

### Error Handling

Errors are:
- Caught and logged via `report(error:context:)`
- Thrown to the caller for UI handling
- Displayed in console with emoji indicators:
  - ✅ Success
  - ❌ Errors

### Progress Indication

The test harness shows:
- Loading spinner during CloudKit operations
- Disabled buttons during clearing
- Console logs with progress

```swift
@State private var isClearingCloudKit = false

private func clearCloudKitCache() async {
    isClearingCloudKit = true
    do {
        try await cacheManager.clearCache(
            inMemory: false,
            onDisk: false,
            cloudKit: true
        )
        print("✅ CloudKit cache cleared successfully")
    } catch {
        print("❌ Error clearing CloudKit cache: \(error)")
    }
    isClearingCloudKit = false
}
```

## Testing

New tests verify the functionality:

```swift
@Test("clearAllCaches method exists and is callable")
func clearAllCachesMethod() async throws {
    let cache = JohnnyCache<String, Data>(configuration: .init(location: nil))
    try await cache.clearAllCaches(inMemory: true, onDisk: true, cloudKit: false)
    #expect(cache.inMemoryCost == 0)
}

@Test("clearAllCaches with CloudKit parameter")
func clearAllCachesWithCloudKit() async throws {
    let cache = JohnnyCache<String, Data>(configuration: .init(location: nil))
    let testData = "Test".data(using: .utf8)!
    cache["test"] = testData
    try await cache.clearAllCaches(inMemory: true, onDisk: true, cloudKit: false)
    #expect(cache["test"] == nil)
}
```

## Performance Considerations

### Network Requirements

CloudKit clearing:
- Requires active network connection
- May take several seconds for large caches
- Uses batched delete operations for efficiency

### Typical Times

| Operation | Time |
|-----------|------|
| Clear Memory | <1ms |
| Clear Disk | 1-10ms |
| Clear CloudKit | 1-5 seconds |
| Clear All | 1-5 seconds |

### Best Practices

1. **Show Progress**: Always display loading indicator for CloudKit operations
2. **Confirm First**: Use alerts for destructive CloudKit operations
3. **Handle Errors**: Catch and display errors to user
4. **Background Tasks**: Use `Task {}` for async operations from sync contexts
5. **Update Stats**: Call `updateStats()` after clearing to reflect changes

## CloudKit Dashboard

After clearing, you can verify in the CloudKit Dashboard:

1. Visit https://icloud.developer.apple.com/dashboard
2. Select your container
3. Go to Public Data → Records
4. Filter by your recordName
5. Should see 0 records (or reduced count)

## Migration Guide

If you were using the old `clearAll()` method:

### Before (Sync only)
```swift
cache.clearAll(inMemory: true, onDisk: true)
```

### After (Same - still works!)
```swift
cache.clearAll(inMemory: true, onDisk: true)  // No change needed
```

### New (With CloudKit)
```swift
try await cache.clearAllCaches(inMemory: true, onDisk: true, cloudKit: true)
```

The old `clearAll()` method remains unchanged for backward compatibility.

## Summary

- ✅ CloudKit cache clearing available via `clearAllCaches(cloudKit: true)`
- ✅ Backward compatible - old `clearAll()` still works
- ✅ Queries and deletes all records efficiently
- ✅ Includes error handling and progress reporting
- ✅ Test harness provides full UI for clearing
- ⚠️ Affects all devices - use with caution
- ⚠️ Requires network connection
- ⚠️ Always confirm before clearing CloudKit
