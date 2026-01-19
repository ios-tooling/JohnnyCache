//
//  JohnnyCacheCodableTests.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/19/26.
//

import Testing
import Foundation
import UniformTypeIdentifiers
@testable import JohnnyCache

// MARK: - Test Types

struct TestUser: Codable, CacheableElement, Sendable, Equatable {
	let id: Int
	let name: String
	let email: String
}

struct TestPost: Codable, CacheableElement, Sendable, Equatable {
	let id: Int
	let title: String
	let createdAt: Date
	let tags: [String]
}

struct NestedModel: Codable, CacheableElement, Sendable, Equatable {
	struct Address: Codable, Sendable, Equatable {
		let street: String
		let city: String
	}

	let name: String
	let addresses: [Address]
}

@Suite("Codable Caching")
@MainActor
struct JohnnyCacheCodableTests {

	@Test("Store and retrieve Codable type")
	func storeAndRetrieveCodable() async throws {
		let config = JohnnyCache<String, TestUser>.Configuration(location: nil)
		let cache = JohnnyCache<String, TestUser>(configuration: config)

		let user = TestUser(id: 1, name: "Alice", email: "alice@example.com")

		cache["user1"] = user

		let retrieved = cache["user1"]
		#expect(retrieved == user)
	}

	@Test("Codable type persists to disk")
	func codableDiskPersistence() async throws {
		let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let config = JohnnyCache<String, TestUser>.Configuration(location: tempDir)

		let user = TestUser(id: 42, name: "Bob", email: "bob@example.com")

		// Create cache and store
		do {
			let cache = JohnnyCache<String, TestUser>(configuration: config)
			cache["bob"] = user
		}

		// Create new cache instance (simulating app restart)
		let newCache = JohnnyCache<String, TestUser>(configuration: config)

		let retrieved = newCache["bob"]
		#expect(retrieved == user)

		// Clean up
		try? FileManager.default.removeItem(at: tempDir)
	}

	@Test("Codable with Date uses ISO8601 encoding")
	func dateEncodingISO8601() async throws {
		let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let config = JohnnyCache<String, TestPost>.Configuration(location: tempDir)
		let cache = JohnnyCache<String, TestPost>(configuration: config)

		let date = Date(timeIntervalSince1970: 1705680000) // 2024-01-19 16:00:00 UTC
		let post = TestPost(id: 1, title: "Test Post", createdAt: date, tags: ["swift", "cache"])

		cache["post1"] = post

		// Clear in-memory to force disk read
		cache.clearAll(inMemory: true, onDisk: false)

		let retrieved = cache["post1"]
		#expect(retrieved != nil)
		#expect(retrieved?.createdAt == date)
		#expect(retrieved?.tags == ["swift", "cache"])

		// Clean up
		try? FileManager.default.removeItem(at: tempDir)
	}

	@Test("Codable UTType is JSON")
	func codableUTTypeIsJSON() async throws {
		#expect(TestUser.uttype == .json)
		#expect(TestPost.uttype == .json)
	}

	@Test("Codable cacheCost reflects encoded size")
	func codableCacheCost() async throws {
		let smallUser = TestUser(id: 1, name: "A", email: "a@b.c")
		let largeUser = TestUser(id: 1, name: String(repeating: "A", count: 1000), email: String(repeating: "B", count: 1000))

		#expect(smallUser.cacheCost > 0)
		#expect(largeUser.cacheCost > smallUser.cacheCost)
	}

	@Test("Codable in-memory cost tracking")
	func codableInMemoryCost() async throws {
		let config = JohnnyCache<String, TestUser>.Configuration(location: nil)
		let cache = JohnnyCache<String, TestUser>(configuration: config)

		#expect(cache.inMemoryCost == 0)

		let user = TestUser(id: 1, name: "Test", email: "test@example.com")
		cache["user"] = user

		#expect(cache.inMemoryCost == user.cacheCost)
	}

	@Test("Nested Codable types work correctly")
	func nestedCodableTypes() async throws {
		let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let config = JohnnyCache<String, NestedModel>.Configuration(location: tempDir)
		let cache = JohnnyCache<String, NestedModel>(configuration: config)

		let model = NestedModel(
			name: "John",
			addresses: [
				NestedModel.Address(street: "123 Main St", city: "NYC"),
				NestedModel.Address(street: "456 Oak Ave", city: "LA")
			]
		)

		cache["john"] = model

		// Clear in-memory to force disk read
		cache.clearAll(inMemory: true, onDisk: false)

		let retrieved = cache["john"]
		#expect(retrieved == model)
		#expect(retrieved?.addresses.count == 2)

		// Clean up
		try? FileManager.default.removeItem(at: tempDir)
	}

	@Test("Multiple Codable items with URL keys")
	func codableWithURLKeys() async throws {
		let config = JohnnyCache<URL, TestUser>.Configuration(location: nil)
		let cache = JohnnyCache<URL, TestUser>(configuration: config)

		let url1 = URL(string: "https://api.example.com/users/1")!
		let url2 = URL(string: "https://api.example.com/users/2")!

		let user1 = TestUser(id: 1, name: "Alice", email: "alice@example.com")
		let user2 = TestUser(id: 2, name: "Bob", email: "bob@example.com")

		cache[url1] = user1
		cache[url2] = user2

		#expect(cache[url1] == user1)
		#expect(cache[url2] == user2)
	}

	@Test("Codable async fetch and cache")
	func codableAsyncFetch() async throws {
		var fetchCount = 0
		let config = JohnnyCache<String, TestUser>.Configuration(location: nil)

		let cache = JohnnyCache<String, TestUser>(configuration: config) { key in
			fetchCount += 1
			return TestUser(id: Int(key) ?? 0, name: "User \(key)", email: "\(key)@example.com")
		}

		// First fetch
		let user1 = try await cache[async: "123"]
		#expect(user1?.id == 123)
		#expect(user1?.name == "User 123")
		#expect(fetchCount == 1)

		// Second fetch should use cache
		let user2 = try await cache[async: "123"]
		#expect(user2 == user1)
		#expect(fetchCount == 1)
	}

	@Test("Codable LRU eviction")
	func codableLRUEviction() async throws {
		// Create users of roughly equal size
		let user = TestUser(id: 1, name: "Test User", email: "test@example.com")
		let userCost = user.cacheCost

		// Set limit to hold ~2 users
		let config = JohnnyCache<String, TestUser>.Configuration(
			location: nil,
			inMemory: userCost * 2 + 10,
			onDisk: 1024 * 1024
		)
		let cache = JohnnyCache<String, TestUser>(configuration: config)

		cache["oldest"] = TestUser(id: 1, name: "Oldest", email: "oldest@example.com")
		try? await Task.sleep(for: .milliseconds(10))

		cache["middle"] = TestUser(id: 2, name: "Middle", email: "middle@example.com")
		try? await Task.sleep(for: .milliseconds(10))

		cache["newest"] = TestUser(id: 3, name: "Newest", email: "newest@example.com")

		// Oldest should be evicted
		#expect(cache["oldest"] == nil)
		#expect(cache["newest"] != nil)
	}

	@Test("toData and from(data:) roundtrip")
	func toDataFromDataRoundtrip() async throws {
		let original = TestUser(id: 99, name: "Roundtrip", email: "round@trip.com")

		let data = try original.toData()
		let decoded = try TestUser.from(data: data)

		#expect(decoded == original)
	}

	@Test("Invalid data returns nil from cache")
	func invalidDataHandling() async throws {
		let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

		// Write invalid JSON to the cache location
		let invalidData = "not valid json".data(using: .utf8)!
		let fileURL = tempDir.appendingPathComponent("badkey.json")
		try invalidData.write(to: fileURL)

		let config = JohnnyCache<String, TestUser>.Configuration(location: tempDir)
		let cache = JohnnyCache<String, TestUser>(configuration: config)

		// Should return nil for corrupted data
		let result = cache["badkey"]
		#expect(result == nil)

		// Clean up
		try? FileManager.default.removeItem(at: tempDir)
	}
}
