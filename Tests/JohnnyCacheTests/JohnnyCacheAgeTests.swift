//
//  JohnnyCacheAgeTests.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/19/26.
//

import Testing
import Foundation
@testable import JohnnyCache

@Suite("Cache Age & Expiration")
@MainActor
struct JohnnyCacheAgeTests {

	// MARK: - maxAge Tests

	@Test("maxAge returns item within age limit")
	func maxAgeReturnsValidItem() async throws {
		let config = JohnnyCache<String, Data>.Configuration(location: nil)
		let cache = JohnnyCache<String, Data>(configuration: config)

		let testData = "Fresh data".data(using: .utf8)!
		cache["key"] = testData

		// Item was just cached, should be returned with 60 second maxAge
		let result = cache["key", maxAge: 60]
		#expect(result == testData)
	}

	@Test("maxAge returns nil for expired item")
	func maxAgeReturnsNilForExpired() async throws {
		let config = JohnnyCache<String, Data>.Configuration(location: nil)
		let cache = JohnnyCache<String, Data>(configuration: config)

		let testData = "Old data".data(using: .utf8)!
		cache["key"] = testData

		// Wait for item to expire
		try await Task.sleep(for: .milliseconds(150))

		// Item should be expired with 0.1 second maxAge
		let result = cache["key", maxAge: 0.1]
		#expect(result == nil)

		// But still accessible without maxAge constraint
		let resultNoAge = cache["key"]
		#expect(resultNoAge == testData)
	}

	@Test("maxAge works with disk cache")
	func maxAgeWithDiskCache() async throws {
		let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let config = JohnnyCache<String, Data>.Configuration(location: tempDir)
		let cache = JohnnyCache<String, Data>(configuration: config)

		let testData = "Disk data".data(using: .utf8)!
		cache["diskKey"] = testData

		// Clear in-memory to force disk read
		cache.clearAll(inMemory: true, onDisk: false)

		// Item should be returned with generous maxAge
		let result = cache["diskKey", maxAge: 60]
		#expect(result == testData)

		// Clean up
		try? FileManager.default.removeItem(at: tempDir)
	}

	@Test("maxAge on disk returns nil for expired item")
	func maxAgeDiskExpired() async throws {
		let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let config = JohnnyCache<String, Data>.Configuration(location: tempDir)
		let cache = JohnnyCache<String, Data>(configuration: config)

		let testData = "Old disk data".data(using: .utf8)!
		cache["diskKey"] = testData

		// Wait for item to expire
		try await Task.sleep(for: .milliseconds(150))

		// Clear in-memory to force disk read
		cache.clearAll(inMemory: true, onDisk: false)

		// Item should be expired with 0.1 second maxAge
		let result = cache["diskKey", maxAge: 0.1]
		#expect(result == nil)

		// Clean up
		try? FileManager.default.removeItem(at: tempDir)
	}

	// MARK: - newerThan Tests

	@Test("newerThan returns item cached after date")
	func newerThanReturnsValidItem() async throws {
		let config = JohnnyCache<String, Data>.Configuration(location: nil)
		let cache = JohnnyCache<String, Data>(configuration: config)

		let beforeCache = Date()
		try await Task.sleep(for: .milliseconds(10))

		let testData = "Recent data".data(using: .utf8)!
		cache["key"] = testData

		// Item was cached after beforeCache date
		let result = cache["key", newerThan: beforeCache]
		#expect(result == testData)
	}

	@Test("newerThan returns nil for item cached before date")
	func newerThanReturnsNilForOldItem() async throws {
		let config = JohnnyCache<String, Data>.Configuration(location: nil)
		let cache = JohnnyCache<String, Data>(configuration: config)

		let testData = "Old data".data(using: .utf8)!
		cache["key"] = testData

		try await Task.sleep(for: .milliseconds(10))
		let afterCache = Date()

		// Item was cached before afterCache date
		let result = cache["key", newerThan: afterCache]
		#expect(result == nil)

		// But still accessible without newerThan constraint
		let resultNoConstraint = cache["key"]
		#expect(resultNoConstraint == testData)
	}

	@Test("newerThan works with disk cache")
	func newerThanWithDiskCache() async throws {
		let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let config = JohnnyCache<String, Data>.Configuration(location: tempDir)
		let cache = JohnnyCache<String, Data>(configuration: config)

		let beforeCache = Date()
		try await Task.sleep(for: .milliseconds(10))

		let testData = "Recent disk data".data(using: .utf8)!
		cache["diskKey"] = testData

		// Clear in-memory to force disk read
		cache.clearAll(inMemory: true, onDisk: false)

		// Item was cached after beforeCache date
		let result = cache["diskKey", newerThan: beforeCache]
		#expect(result == testData)

		// Clean up
		try? FileManager.default.removeItem(at: tempDir)
	}

	@Test("newerThan on disk returns nil for old item")
	func newerThanDiskOldItem() async throws {
		let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let config = JohnnyCache<String, Data>.Configuration(location: tempDir)
		let cache = JohnnyCache<String, Data>(configuration: config)

		let testData = "Old disk data".data(using: .utf8)!
		cache["diskKey"] = testData

		try await Task.sleep(for: .milliseconds(10))
		let afterCache = Date()

		// Clear in-memory to force disk read
		cache.clearAll(inMemory: true, onDisk: false)

		// Item was cached before afterCache date
		let result = cache["diskKey", newerThan: afterCache]
		#expect(result == nil)

		// Clean up
		try? FileManager.default.removeItem(at: tempDir)
	}

	// MARK: - Combined maxAge and newerThan Tests

	@Test("Combined maxAge and newerThan both must pass")
	func combinedAgeConstraints() async throws {
		let config = JohnnyCache<String, Data>.Configuration(location: nil)
		let cache = JohnnyCache<String, Data>(configuration: config)

		let beforeCache = Date()
		try await Task.sleep(for: .milliseconds(10))

		let testData = "Test data".data(using: .utf8)!
		cache["key"] = testData

		// Both constraints satisfied
		let result1 = cache["key", maxAge: 60, newerThan: beforeCache]
		#expect(result1 == testData)

		// maxAge fails (wait for expiration)
		try await Task.sleep(for: .milliseconds(150))
		let result2 = cache["key", maxAge: 0.1, newerThan: beforeCache]
		#expect(result2 == nil)
	}

	@Test("newerThan fails even if maxAge passes")
	func newerThanFailsWithValidMaxAge() async throws {
		let config = JohnnyCache<String, Data>.Configuration(location: nil)
		let cache = JohnnyCache<String, Data>(configuration: config)

		let testData = "Test data".data(using: .utf8)!
		cache["key"] = testData

		try await Task.sleep(for: .milliseconds(10))
		let afterCache = Date()

		// maxAge would pass (60 seconds), but newerThan fails
		let result = cache["key", maxAge: 60, newerThan: afterCache]
		#expect(result == nil)
	}

	// MARK: - Async Subscript with Age Tests

	@Test("Async subscript respects maxAge")
	func asyncSubscriptMaxAge() async throws {
		var fetchCount = 0
		let config = JohnnyCache<String, Data>.Configuration(location: nil)

		let cache = JohnnyCache<String, Data>(configuration: config) { key in
			fetchCount += 1
			return "Fetched: \(key)".data(using: .utf8)
		}

		// First fetch
		let result1 = try await cache[async: "key", maxAge: 60]
		#expect(result1 != nil)
		#expect(fetchCount == 1)

		// Second fetch within maxAge - should use cache
		let result2 = try await cache[async: "key", maxAge: 60]
		#expect(result2 == result1)
		#expect(fetchCount == 1)
	}

	@Test("Async subscript re-fetches when maxAge expired")
	func asyncSubscriptRefetchOnExpiry() async throws {
		var fetchCount = 0
		let config = JohnnyCache<String, Data>.Configuration(location: nil)

		let cache = JohnnyCache<String, Data>(configuration: config) { key in
			fetchCount += 1
			return "Fetch \(fetchCount)".data(using: .utf8)
		}

		// First fetch
		let result1 = try await cache[async: "key", maxAge: 0.1]
		#expect(result1 != nil)
		#expect(fetchCount == 1)

		// Wait for expiration
		try await Task.sleep(for: .milliseconds(150))

		// Should re-fetch because maxAge expired
		let result2 = try await cache[async: "key", maxAge: 0.1]
		#expect(result2 != nil)
		#expect(fetchCount == 2)
	}

	@Test("Async subscript respects newerThan")
	func asyncSubscriptNewerThan() async throws {
		var fetchCount = 0
		let config = JohnnyCache<String, Data>.Configuration(location: nil)

		let cache = JohnnyCache<String, Data>(configuration: config) { key in
			fetchCount += 1
			return "Fetch \(fetchCount)".data(using: .utf8)
		}

		let beforeFirstFetch = Date()
		try await Task.sleep(for: .milliseconds(10))

		// First fetch
		_ = try await cache[async: "key"]
		#expect(fetchCount == 1)

		try await Task.sleep(for: .milliseconds(10))
		let afterFirstFetch = Date()

		// Should use cached value (cached after beforeFirstFetch)
		let result2 = try await cache[async: "key", newerThan: beforeFirstFetch]
		#expect(result2 != nil)
		#expect(fetchCount == 1)

		// Should re-fetch (cached before afterFirstFetch)
		let result3 = try await cache[async: "key", newerThan: afterFirstFetch]
		#expect(result3 != nil)
		#expect(fetchCount == 2)
	}

	// MARK: - cachedAt Tracking Tests

	@Test("cachedAt is preserved when loading from disk")
	func cachedAtPreservedFromDisk() async throws {
		let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let config = JohnnyCache<String, Data>.Configuration(location: tempDir)

		let beforeCache = Date()
		try await Task.sleep(for: .milliseconds(10))

		// Create cache and store data
		do {
			let cache = JohnnyCache<String, Data>(configuration: config)
			cache["key"] = "Test data".data(using: .utf8)!
		}

		try await Task.sleep(for: .milliseconds(10))
		let afterCache = Date()

		// Create new cache instance
		let newCache = JohnnyCache<String, Data>(configuration: config)

		// Should find item with newerThan beforeCache (disk creation time preserved)
		let result1 = newCache["key", newerThan: beforeCache]
		#expect(result1 != nil)

		// Should NOT find item with newerThan afterCache
		// Clear in-memory first to force disk read with fresh date check
		newCache.clearAll(inMemory: true, onDisk: false)
		let result2 = newCache["key", newerThan: afterCache]
		#expect(result2 == nil)

		// Clean up
		try? FileManager.default.removeItem(at: tempDir)
	}

	@Test("Overwriting updates cachedAt timestamp")
	func overwriteUpdatesCachedAt() async throws {
		let config = JohnnyCache<String, Data>.Configuration(location: nil)
		let cache = JohnnyCache<String, Data>(configuration: config)

		cache["key"] = "First value".data(using: .utf8)!

		try await Task.sleep(for: .milliseconds(50))
		let betweenWrites = Date()
		try await Task.sleep(for: .milliseconds(50))

		// Overwrite with new value
		cache["key"] = "Second value".data(using: .utf8)!

		// Should find with newerThan betweenWrites (new cachedAt)
		let result = cache["key", newerThan: betweenWrites]
		#expect(result != nil)
		#expect(result == "Second value".data(using: .utf8))
	}

	// MARK: - Edge Cases

	@Test("Zero maxAge returns nil for any cached item")
	func zeroMaxAgeReturnsNil() async throws {
		let config = JohnnyCache<String, Data>.Configuration(location: nil)
		let cache = JohnnyCache<String, Data>(configuration: config)

		cache["key"] = "Data".data(using: .utf8)!

		// Even freshly cached item should fail with 0 maxAge
		let result = cache["key", maxAge: 0]
		#expect(result == nil)
	}

	@Test("Future newerThan date returns nil")
	func futureNewerThanReturnsNil() async throws {
		let config = JohnnyCache<String, Data>.Configuration(location: nil)
		let cache = JohnnyCache<String, Data>(configuration: config)

		cache["key"] = "Data".data(using: .utf8)!

		let futureDate = Date().addingTimeInterval(3600) // 1 hour from now
		let result = cache["key", newerThan: futureDate]
		#expect(result == nil)
	}

	@Test("Nil maxAge and newerThan returns item regardless of age")
	func nilConstraintsIgnoreAge() async throws {
		let config = JohnnyCache<String, Data>.Configuration(location: nil)
		let cache = JohnnyCache<String, Data>(configuration: config)

		let testData = "Old data".data(using: .utf8)!
		cache["key"] = testData

		try await Task.sleep(for: .milliseconds(100))

		// With nil constraints, should always return cached value
		let result = cache["key", maxAge: nil, newerThan: nil]
		#expect(result == testData)
	}
}
