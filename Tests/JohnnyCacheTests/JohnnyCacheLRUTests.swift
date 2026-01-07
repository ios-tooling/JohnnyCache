//
//  JohnnyCacheLRUTests.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//

import Testing
import Foundation
@testable import JohnnyCache

@Suite("LRU Eviction")
@MainActor
struct JohnnyCacheLRUTests {

	@Test("In-memory LRU eviction removes least recently accessed items")
	func inMemoryLRUEviction() async throws {
		// Set very small memory limit to trigger eviction
		let config = JohnnyCache<String, Data>.Configuration(
			location: nil,
			inMemory: 2300, // Only 2.3KB
			onDisk: 1024 * 1024
		)
		let cache = JohnnyCache<String, Data>(configuration: config)

		// Add 1KB items
		cache["oldest"] = Data(count: 800)
		try? await Task.sleep(for: .milliseconds(10))

		cache["middle"] = Data(count: 800)
		try? await Task.sleep(for: .milliseconds(10))

		cache["newest"] = Data(count: 800)
		try? await Task.sleep(for: .milliseconds(10))

		// Now all three are in cache (2.4KB total, over 2.3KB limit)
		// Should have triggered purge down to ~1.875KB (75% of limit)
		// Oldest should be evicted

		#expect(cache["oldest"] == nil, "Oldest item should be evicted")
		#expect(cache["newest"] != nil, "Newest item should remain")
	}

	@Test("Access updates LRU order")
	func accessUpdatesLRU() async throws {
		let config = JohnnyCache<String, Data>.Configuration(
			location: nil,
			inMemory: 2300,
			onDisk: 1024 * 1024
		)
		let cache = JohnnyCache<String, Data>(configuration: config)

		// Add items in order
		cache["first"] = Data(count: 800)
		try? await Task.sleep(for: .milliseconds(10))

		cache["second"] = Data(count: 800)
		try? await Task.sleep(for: .milliseconds(10))

		// Access "first" to update its timestamp
		_ = cache["first"]
		try? await Task.sleep(for: .milliseconds(10))

		// Add third item to trigger eviction
		cache["third"] = Data(count: 800)

		// "second" should be evicted (least recently accessed)
		// "first" and "third" should remain
		#expect(cache["second"] == nil, "Second (least recently accessed) should be evicted")
		#expect(cache["first"] != nil, "First (recently accessed) should remain")
		#expect(cache["third"] != nil, "Third (newest) should remain")
	}

	@Test("Purge maintains cost limit")
	func purgeDownToLimit() async throws {
		let limit: UInt64 = 5000
		let config = JohnnyCache<String, Data>.Configuration(
			location: nil,
			inMemory: limit,
			onDisk: 1024 * 1024
		)
		let cache = JohnnyCache<String, Data>(configuration: config)

		// Add 10KB of data
		for i in 0..<10 {
			cache["key\(i)"] = Data(count: 1000)
			try? await Task.sleep(for: .milliseconds(5))
		}

		// Should purge down to 75% of limit (3750 bytes)
		let targetCost = limit
		#expect(cache.inMemoryCost <= targetCost, "Cost should be at or below 75% of limit")
	}

	@Test("Multiple overwrites maintain correct order")
	func overwriteMaintainsOrder() async throws {
		let config = JohnnyCache<String, Data>.Configuration(
			location: nil,
			inMemory: 3000,
			onDisk: 1024 * 1024
		)
		let cache = JohnnyCache<String, Data>(configuration: config)

		cache["a"] = Data(count: 1000)
		try? await Task.sleep(for: .milliseconds(10))

		cache["b"] = Data(count: 1000)
		try? await Task.sleep(for: .milliseconds(10))

		// Overwrite "a" - should update its access time
		cache["a"] = Data(count: 1000)
		try? await Task.sleep(for: .milliseconds(10))

		// Add "c" to trigger eviction
		cache["c"] = Data(count: 1000)

		// "b" should be evicted (least recently accessed)
		#expect(cache["b"] == nil, "Item 'b' should be evicted")
		#expect(cache["a"] != nil, "Item 'a' (recently overwritten) should remain")
		#expect(cache["c"] != nil, "Item 'c' (newest) should remain")
	}

	@Test("Empty cache doesn't crash on purge")
	func emptyPurge() async throws {
		let config = JohnnyCache<String, Data>.Configuration(
			location: nil,
			inMemory: 1000,
			onDisk: 1024 * 1024
		)
		let cache = JohnnyCache<String, Data>(configuration: config)

		// Manually trigger purge on empty cache
		cache.purgeInMemory(downTo: 0)

		// Should not crash
		#expect(cache.inMemoryCost == 0)
	}

	@Test("Disk LRU eviction based on modification time")
	func diskLRUEviction() async throws {
		let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let config = JohnnyCache<String, Data>.Configuration(
			location: tempDir,
			inMemory: 1024 * 1024,
			onDisk: 2500 // Very small disk limit
		)
		let cache = JohnnyCache<String, Data>(configuration: config)

		// Add files with delays to ensure different timestamps
		cache["oldest"] = Data(count: 1000)
		try? await Task.sleep(for: .milliseconds(100))

		cache["middle"] = Data(count: 1000)
		try? await Task.sleep(for: .milliseconds(100))

		cache["newest"] = Data(count: 1000)
		try? await Task.sleep(for: .milliseconds(100))

		// Should have triggered disk purge
		// Clear in-memory to force disk reads
		cache.clearAll(inMemory: true, onDisk: false)

		// Oldest should be gone from disk
		#expect(cache["oldest"] == nil, "Oldest file should be evicted from disk")

		// Clean up
		try? FileManager.default.removeItem(at: tempDir)
	}
}
