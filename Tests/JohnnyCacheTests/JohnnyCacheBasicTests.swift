//
//  JohnnyCacheBasicTests.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//

import Testing
import Foundation
@testable import JohnnyCache

@Suite("Basic Cache Operations")
@MainActor
struct JohnnyCacheBasicTests {

	@Test("Store and retrieve string-keyed data")
	func storeAndRetrieve() async throws {
		let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let config = JohnnyCache<String, Data>.Configuration(location: tempDir)
		let cache = JohnnyCache<String, Data>(configuration: config)

		let testData = "Hello, World!".data(using: .utf8)!

		// Store data
		cache["test"] = testData

		// Retrieve from in-memory cache
		let retrieved = cache["test"]
		#expect(retrieved == testData)

		// Clean up
		try? FileManager.default.removeItem(at: tempDir)
	}

	@Test("Store and retrieve from disk")
	func diskPersistence() async throws {
		let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let config = JohnnyCache<String, Data>.Configuration(location: tempDir)

		let testData = "Disk Test".data(using: .utf8)!

		// Create cache and store data
		do {
			let cache = JohnnyCache<String, Data>(configuration: config)
			cache["diskTest"] = testData
		}

		// Create new cache instance (simulating app restart)
		let newCache = JohnnyCache<String, Data>(configuration: config)

		// Should retrieve from disk
		let retrieved = newCache["diskTest"]
		#expect(retrieved == testData)

		// Clean up
		try? FileManager.default.removeItem(at: tempDir)
	}

	@Test("Clear in-memory cache")
	func clearInMemory() async throws {
		let config = JohnnyCache<String, Data>.Configuration(location: nil)
		let cache = JohnnyCache<String, Data>(configuration: config)

		let testData = "Test".data(using: .utf8)!
		cache["key1"] = testData
		cache["key2"] = testData

		#expect(cache["key1"] != nil)
		#expect(cache["key2"] != nil)

		cache.clearAll(inMemory: true, onDisk: true)

		#expect(cache["key1"] == nil)
		#expect(cache["key2"] == nil)
	}

	@Test("Clear disk cache")
	func clearDisk() async throws {
		let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let config = JohnnyCache<String, Data>.Configuration(location: tempDir)
		let cache = JohnnyCache<String, Data>(configuration: config)

		let testData = "Test".data(using: .utf8)!
		cache["diskKey"] = testData

		cache.clearAll(inMemory: false, onDisk: true)

		// Clear in-memory to force disk read
		cache.clearAll(inMemory: true, onDisk: false)

		// Should not find on disk
		#expect(cache["diskKey"] == nil)

		// Clean up
		try? FileManager.default.removeItem(at: tempDir)
	}

	@Test("Nil value removes item")
	func nilRemoval() async throws {
		let config = JohnnyCache<String, Data>.Configuration(location: nil)
		let cache = JohnnyCache<String, Data>(configuration: config)

		let testData = "Test".data(using: .utf8)!
		cache["key"] = testData
		#expect(cache["key"] != nil)

		cache["key"] = nil
		#expect(cache["key"] == nil)
	}

	@Test("URL-based keys work correctly")
	func urlKeys() async throws {
		let config = JohnnyCache<URL, Data>.Configuration(location: nil)
		let cache = JohnnyCache<URL, Data>(configuration: config)

		let testURL = URL(string: "https://example.com/image.png")!
		let testData = "Image Data".data(using: .utf8)!

		cache[testURL] = testData
		#expect(cache[testURL] == testData)
	}
}
