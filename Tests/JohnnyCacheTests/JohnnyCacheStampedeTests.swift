//
//  JohnnyCacheStampedeTests.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//

import Testing
import Foundation
@testable import JohnnyCache

@Suite("Cache Stampede Prevention")
@MainActor
struct JohnnyCacheStampedeTests {

	@Test("Concurrent requests for same key trigger only one fetch")
	func deduplicatesConcurrentFetches() async throws {
		var fetchCount = 0
		let config = JohnnyCache<String, Data>.Configuration(location: nil)

		let cache = JohnnyCache<String, Data>(configuration: config) { key in
			fetchCount += 1
			// Simulate network delay
			try? await Task.sleep(for: .milliseconds(100))
			return "Fetched: \(key)".data(using: .utf8)
		}

		// Launch 10 concurrent requests for the same key
		await withTaskGroup(of: Data?.self) { group in
			for _ in 0..<10 {
				group.addTask {
					await cache[async: "sharedKey"]
				}
			}

			// Wait for all to complete
			var results: [Data?] = []
			for await result in group {
				results.append(result)
			}

			// All should succeed
			#expect(results.count == 10)
			#expect(results.allSatisfy { $0 != nil })
		}

		// But fetch should only be called once
		#expect(fetchCount == 1, "Fetch should only be called once, not \(fetchCount) times")
	}

	@Test("Different keys trigger separate fetches")
	func differentKeysSeparateFetches() async throws {
		var fetchedKeys: [String] = []
		let config = JohnnyCache<String, Data>.Configuration(location: nil)

		let cache = JohnnyCache<String, Data>(configuration: config) { key in
			fetchedKeys.append(key)
			try? await Task.sleep(for: .milliseconds(50))
			return "Data for \(key)".data(using: .utf8)
		}

		// Fetch different keys concurrently
		await withTaskGroup(of: Data?.self) { group in
			group.addTask { await cache[async: "key1"] }
			group.addTask { await cache[async: "key2"] }
			group.addTask { await cache[async: "key3"] }

			for await _ in group {}
		}

		#expect(fetchedKeys.sorted() == ["key1", "key2", "key3"])
	}

	@Test("In-flight fetch state is cleaned up")
	func inFlightCleanup() async throws {
		let config = JohnnyCache<String, Data>.Configuration(location: nil)

		let cache = JohnnyCache<String, Data>(configuration: config) { key in
			try? await Task.sleep(for: .milliseconds(50))
			return "Data".data(using: .utf8)
		}

		// Initially no in-flight fetches
		#expect(cache.inFlightFetches.isEmpty)

		// Start a fetch
		let task = Task {
			await cache[async: "test"]
		}

		// Give it time to register
		try? await Task.sleep(for: .milliseconds(10))
		#expect(cache.inFlightFetches.count == 1, "Should have one in-flight fetch")

		// Wait for completion
		_ = await task.value

		// Should be cleaned up
		#expect(cache.inFlightFetches.isEmpty, "In-flight fetches should be cleaned up")
	}

	@Test("Failed fetch doesn't block subsequent attempts")
	func failedFetchRetriable() async throws {
		var attemptCount = 0
		let config = JohnnyCache<String, Data>.Configuration(location: nil)

		let cache = JohnnyCache<String, Data>(configuration: config) { key in
			attemptCount += 1
			if attemptCount == 1 {
				throw NSError(domain: "TestError", code: 1)
			}
			return "Success".data(using: .utf8)
		}

		// First attempt should fail
		let first = await cache[async: "test"]
		#expect(first == nil)
		#expect(attemptCount == 1)

		// Second attempt should succeed
		let second = await cache[async: "test"]
		#expect(second != nil)
		#expect(attemptCount == 2)
	}

	@Test("Cache hit doesn't trigger fetch")
	func cacheHitSkipsFetch() async throws {
		var fetchCount = 0
		let config = JohnnyCache<String, Data>.Configuration(location: nil)

		let cache = JohnnyCache<String, Data>(configuration: config) { key in
			fetchCount += 1
			return "Fetched".data(using: .utf8)
		}

		// Pre-populate cache
		cache["cached"] = "Cached Data".data(using: .utf8)

		// Async access should return cached value without fetching
		let result = await cache[async: "cached"]

		#expect(result != nil)
		#expect(fetchCount == 0, "Should not fetch when value is cached")
	}

	@Test("Clear cancels in-flight fetches")
	func clearCancelsInFlight() async throws {
		let config = JohnnyCache<String, Data>.Configuration(location: nil)

		let cache = JohnnyCache<String, Data>(configuration: config) { key in
			// Long delay to ensure it's still running when we clear
			try? await Task.sleep(for: .milliseconds(500))
			return "Data".data(using: .utf8)
		}

		// Start multiple fetches
		let task1 = Task { await cache[async: "key1"] }
		let task2 = Task { await cache[async: "key2"] }

		// Give them time to register
		try? await Task.sleep(for: .milliseconds(50))
		#expect(cache.inFlightFetches.count == 2)

		// Clear the cache
		cache.clearAll()

		// In-flight fetches should be cancelled and cleaned up
		#expect(cache.inFlightFetches.isEmpty)

		// Tasks should complete (even if cancelled)
		_ = await task1.value
		_ = await task2.value
	}

	@Test("Sequential requests after fetch completes work correctly")
	func sequentialRequestsAfterCompletion() async throws {
		var fetchCount = 0
		let config = JohnnyCache<String, Data>.Configuration(location: nil)

		let cache = JohnnyCache<String, Data>(configuration: config) { key in
			fetchCount += 1
			try? await Task.sleep(for: .milliseconds(50))
			return "Fetched \(fetchCount)".data(using: .utf8)
		}

		// First request
		let first = await cache[async: "test"]
		#expect(first != nil)
		#expect(fetchCount == 1)

		// Second request should use cached value
		let second = await cache[async: "test"]
		#expect(second != nil)
		#expect(fetchCount == 1, "Should still be 1 - used cached value")

		// Values should be identical
		#expect(first == second)
	}
}
