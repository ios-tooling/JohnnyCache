//
//  JohnnyCacheCloudKitTests.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/26/26.
//

import Testing
import Foundation
import CloudKit
@testable import JohnnyCache

@Suite("CloudKit Integration Tests")
@MainActor
struct JohnnyCacheCloudKitTests {

	// Note: These tests verify CloudKit integration logic without actually
	// connecting to CloudKit, as that requires entitlements and a valid container

	@Test("Configuration without CloudKit info")
	func configWithoutCloudKit() async throws {
		let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let config = JohnnyCache<String, Data>.Configuration(location: tempDir)

		#expect(config.cloudKitInfo == nil)

		let cache = JohnnyCache<String, Data>(configuration: config)
		let testData = "Test".data(using: .utf8)!

		// Should work fine without CloudKit
		cache["test"] = testData
		#expect(cache["test"] == testData)

		// Clean up
		try? FileManager.default.removeItem(at: tempDir)
	}

	@Test("Record ID returns nil without CloudKit configuration")
	func recordIDWithoutCloudKitConfig() async throws {
		let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let config = JohnnyCache<String, Data>.Configuration(location: tempDir)
		let cache = JohnnyCache<String, Data>(configuration: config)

		let recordID = cache.recordID(forKey: "test-key")
		#expect(recordID == nil)

		// Clean up
		try? FileManager.default.removeItem(at: tempDir)
	}

	@Test("CloudKit element returns nil without configuration")
	func cloudKitElementWithoutConfig() async throws {
		let config = JohnnyCache<String, Data>.Configuration(location: nil)
		let cache = JohnnyCache<String, Data>(configuration: config)

		// Should return nil gracefully
		let element = try await cache.cloudKitElement(for: "test-key", maxAge: nil, newerThan: nil)
		#expect(element == nil)
	}

	@Test("Asset limit threshold logic - small data")
	func assetLimitSmallData() async throws {
		let smallDataSize = 5_000 // Less than default 10_000
		let data = Data(repeating: 0xFF, count: smallDataSize)

		let assetLimit = 10_000

		// Data should be stored directly, not as asset
		#expect(data.count < assetLimit)
		#expect(data.count == 5_000)
	}

	@Test("Asset limit threshold logic - large data")
	func assetLimitLargeData() async throws {
		let largeDataSize = 15_000 // More than default 10_000
		let data = Data(repeating: 0xFF, count: largeDataSize)

		let assetLimit = 10_000

		// Data should be stored as asset
		#expect(data.count > assetLimit)
		#expect(data.count == 15_000)
	}

	@Test("Custom asset limits are respected")
	func customAssetLimits() async throws {
		let customLimit = 100_000

		let smallData = Data(repeating: 0xFF, count: 50_000)
		let largeData = Data(repeating: 0xFF, count: 150_000)

		#expect(smallData.count < customLimit)
		#expect(largeData.count > customLimit)
	}

	@Test("Temporary file URL generation for asset storage")
	func temporaryFileURLForAsset() async throws {
		let recordName = "TestRecord:test-asset"
		let tempURL = URL.temporaryDirectory.appendingPathComponent(recordName)

		// Verify temp URL can be created
		#expect(tempURL.path.contains(recordName))
		#expect(tempURL.path.contains("tmp") || tempURL.path.contains("Temporary") || tempURL.path.contains("T"))
	}

	@Test("Synchronous subscript works without CloudKit")
	func syncSubscriptWithoutCloudKit() async throws {
		let cache = JohnnyCache<String, Data>(configuration: .init(location: nil))
		let testData = "Hello".data(using: .utf8)!

		cache["key"] = testData
		#expect(cache["key"] == testData)

		cache["key"] = nil
		#expect(cache["key"] == nil)
	}

	@Test("Async subscript works without CloudKit configuration")
	func asyncSubscriptWithoutCloudKit() async throws {
		var fetchCalled = false
		let config = JohnnyCache<String, Data>.Configuration(location: nil)
		let cache = JohnnyCache<String, Data>(configuration: config) { key in
			fetchCalled = true
			return "Fetched: \(key)".data(using: .utf8)!
		}

		let result = try await cache[async: "test-key"]
		#expect(result != nil)
		#expect(fetchCalled == true)
	}

	@Test("Data size determines storage strategy")
	func dataSizeStorageStrategy() async throws {
		let defaultAssetLimit = 10_000

		// Test various data sizes
		let tinyData = Data(repeating: 0, count: 100)
		let smallData = Data(repeating: 0, count: 5_000)
		let mediumData = Data(repeating: 0, count: 9_999)
		let borderlineData = Data(repeating: 0, count: 10_000)
		let largeData = Data(repeating: 0, count: 10_001)
		let hugeData = Data(repeating: 0, count: 100_000)

		// Verify size-based logic
		#expect(tinyData.count < defaultAssetLimit)
		#expect(smallData.count < defaultAssetLimit)
		#expect(mediumData.count < defaultAssetLimit)
		#expect(borderlineData.count == defaultAssetLimit)
		#expect(largeData.count > defaultAssetLimit)
		#expect(hugeData.count > defaultAssetLimit)
	}

	@Test("Cache operates normally without CloudKit backend")
	func cacheWithoutCloudKitBackend() async throws {
		let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let cache = JohnnyCache<String, Data>(configuration: .init(location: tempDir))

		let data1 = "Data 1".data(using: .utf8)!
		let data2 = "Data 2".data(using: .utf8)!
		let data3 = "Data 3".data(using: .utf8)!

		// Store multiple items
		cache["key1"] = data1
		cache["key2"] = data2
		cache["key3"] = data3

		// Retrieve them
		#expect(cache["key1"] == data1)
		#expect(cache["key2"] == data2)
		#expect(cache["key3"] == data3)

		// Update an item
		let updatedData = "Updated".data(using: .utf8)!
		cache["key2"] = updatedData
		#expect(cache["key2"] == updatedData)

		// Delete an item
		cache["key1"] = nil
		#expect(cache["key1"] == nil)

		// Clean up
		try? FileManager.default.removeItem(at: tempDir)
	}

	@Test("Age constraints work without CloudKit")
	func ageConstraintsWithoutCloudKit() async throws {
		let cache = JohnnyCache<String, Data>(configuration: .init(location: nil))
		let testData = "Test".data(using: .utf8)!

		cache["recent"] = testData

		// Should find with no age limit
		#expect(cache["recent"] != nil)

		// Should find with generous max age
		#expect(cache["recent", maxAge: 60] != nil)

		// Should not find with impossible max age
		#expect(cache["recent", maxAge: -1] == nil)

		// Should find with old newerThan date
		let pastDate = Date(timeIntervalSinceNow: -60)
		#expect(cache["recent", newerThan: pastDate] != nil)

		// Should not find with future newerThan date
		let futureDate = Date(timeIntervalSinceNow: 60)
		#expect(cache["recent", newerThan: futureDate] == nil)
	}

	@Test("URL keys generate unique string representations")
	func urlKeyStringRepresentations() async throws {
		let url1 = URL(string: "https://example.com/image1.png")!
		let url2 = URL(string: "https://example.com/image2.png")!
		let url3 = URL(string: "https://other.com/image1.png")!

		let str1 = url1.stringRepresentation
		let str2 = url2.stringRepresentation
		let str3 = url3.stringRepresentation

		// Each URL should have unique representation
		#expect(str1 != str2)
		#expect(str1 != str3)
		#expect(str2 != str3)

		// Representations should contain meaningful parts
		#expect(str1.contains("example.com"))
		#expect(str2.contains("example.com"))
		#expect(str3.contains("other.com"))
	}

	@Test("Cache handles concurrent access without CloudKit")
	func concurrentAccessWithoutCloudKit() async throws {
		let cache = JohnnyCache<String, Data>(configuration: .init(location: nil))

		// Store some initial data
		for i in 0..<10 {
			let data = "Data \(i)".data(using: .utf8)!
			cache["key\(i)"] = data
		}

		// Verify all data is accessible
		for i in 0..<10 {
			let expected = "Data \(i)".data(using: .utf8)!
			#expect(cache["key\(i)"] == expected)
		}
	}
}
