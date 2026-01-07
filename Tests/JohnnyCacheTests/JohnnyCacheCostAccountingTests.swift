//
//  JohnnyCacheCostAccountingTests.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//

import Testing
import Foundation
@testable import JohnnyCache

@Suite("Cost Accounting")
@MainActor
struct JohnnyCacheCostAccountingTests {

	@Test("In-memory cost increases when adding items")
	func inMemoryCostIncreases() async throws {
		let config = JohnnyCache<String, Data>.Configuration(location: nil)
		let cache = JohnnyCache<String, Data>(configuration: config)

		#expect(cache.inMemoryCost == 0)

		let data1 = Data(count: 1000)
		cache["key1"] = data1

		#expect(cache.inMemoryCost == 1000)

		let data2 = Data(count: 500)
		cache["key2"] = data2

		#expect(cache.inMemoryCost == 1500)
	}

	@Test("In-memory cost decreases when removing items")
	func inMemoryCostDecreases() async throws {
		let config = JohnnyCache<String, Data>.Configuration(location: nil)
		let cache = JohnnyCache<String, Data>(configuration: config)

		let data1 = Data(count: 1000)
		let data2 = Data(count: 500)

		cache["key1"] = data1
		cache["key2"] = data2

		#expect(cache.inMemoryCost == 1500)

		cache["key1"] = nil
		#expect(cache.inMemoryCost == 500)

		cache["key2"] = nil
		#expect(cache.inMemoryCost == 0)
	}

	@Test("In-memory cost updates correctly on overwrite")
	func inMemoryCostOnOverwrite() async throws {
		let config = JohnnyCache<String, Data>.Configuration(location: nil)
		let cache = JohnnyCache<String, Data>(configuration: config)

		// Store 1MB
		cache["key"] = Data(count: 1_000_000)
		#expect(cache.inMemoryCost == 1_000_000)

		// Overwrite with 2MB - should subtract old, add new
		cache["key"] = Data(count: 2_000_000)
		#expect(cache.inMemoryCost == 2_000_000)

		// Overwrite with 500KB - should subtract old, add new
		cache["key"] = Data(count: 500_000)
		#expect(cache.inMemoryCost == 500_000)
	}

	@Test("On-disk cost tracks correctly")
	func onDiskCostTracking() async throws {
		let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let config = JohnnyCache<String, Data>.Configuration(location: tempDir)
		let cache = JohnnyCache<String, Data>(configuration: config)

		let data1 = Data(count: 1000)
		cache["disk1"] = data1

		// Give file system time to write
		try? await Task.sleep(for: .milliseconds(100))

		#expect(cache.onDiskCost > 0)
		let firstCost = cache.onDiskCost

		let data2 = Data(count: 2000)
		cache["disk2"] = data2

		try? await Task.sleep(for: .milliseconds(100))

		#expect(cache.onDiskCost > firstCost)

		// Clean up
		try? FileManager.default.removeItem(at: tempDir)
	}

	@Test("On-disk cost updates on overwrite")
	func onDiskCostOnOverwrite() async throws {
		let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let config = JohnnyCache<String, Data>.Configuration(location: tempDir)
		let cache = JohnnyCache<String, Data>(configuration: config)

		// Store 1KB
		cache["key"] = Data(count: 1000)
		try? await Task.sleep(for: .milliseconds(100))
		let firstCost = cache.onDiskCost

		// Overwrite with 2KB
		cache["key"] = Data(count: 2000)
		try? await Task.sleep(for: .milliseconds(100))

		// Cost should increase (approximately doubled)
		#expect(cache.onDiskCost > firstCost)
		#expect(cache.onDiskCost < firstCost * 3) // Sanity check

		// Clean up
		try? FileManager.default.removeItem(at: tempDir)
	}

	@Test("Clear resets all costs to zero")
	func clearResetsCosts() async throws {
		let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let config = JohnnyCache<String, Data>.Configuration(location: tempDir)
		let cache = JohnnyCache<String, Data>(configuration: config)

		cache["key1"] = Data(count: 1000)
		cache["key2"] = Data(count: 2000)

		#expect(cache.inMemoryCost > 0)
		#expect(cache.onDiskCost > 0)

		cache.clearAll()

		#expect(cache.inMemoryCost == 0)
		#expect(cache.onDiskCost == 0)

		// Clean up
		try? FileManager.default.removeItem(at: tempDir)
	}

	@Test("On-disk cost initialized correctly from existing files")
	func onDiskCostInitialization() async throws {
		let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let config = JohnnyCache<String, Data>.Configuration(location: tempDir)

		// Create cache and add data
		do {
			let cache = JohnnyCache<String, Data>(configuration: config)
			cache["file1"] = Data(count: 1000)
			cache["file2"] = Data(count: 2000)
			try? await Task.sleep(for: .milliseconds(100))
		}

		// Create new cache instance - should calculate cost from existing files
		let newCache = JohnnyCache<String, Data>(configuration: config)
		#expect(newCache.onDiskCost > 0)

		// Clean up
		try? FileManager.default.removeItem(at: tempDir)
	}
}
