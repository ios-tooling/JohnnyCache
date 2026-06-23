//
//  JohnnyCacheMemoryPressureTests.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 6/23/26.
//

import Testing
import Foundation
@testable import JohnnyCache

@Suite("Memory Pressure")
@MainActor
struct JohnnyCacheMemoryPressureTests {

	@Test("Warning purges in-memory cache down to half the limit")
	func warningPurgesToHalfLimit() async throws {
		let config = JohnnyCache<String, Data>.Configuration(location: nil, inMemory: 1000)
		let cache = JohnnyCache<String, Data>(configuration: config)

		for index in 0..<8 { cache["key\(index)"] = Data(count: 100) }
		#expect(cache.inMemoryCost == 800)

		cache.handleMemoryPressure(.warning)

		#expect(cache.inMemoryCost <= 500)
	}

	@Test("Critical clears the entire in-memory cache")
	func criticalClearsAll() async throws {
		let config = JohnnyCache<String, Data>.Configuration(location: nil, inMemory: 1000)
		let cache = JohnnyCache<String, Data>(configuration: config)

		for index in 0..<5 { cache["key\(index)"] = Data(count: 100) }
		#expect(cache.inMemoryCost == 500)

		cache.handleMemoryPressure(.critical)

		#expect(cache.inMemoryCost == 0)
	}

	@Test("Monitoring can be disabled via configuration")
	func monitoringDisabled() async throws {
		let config = JohnnyCache<String, Data>.Configuration(location: nil, respondsToMemoryPressure: false)
		let cache = JohnnyCache<String, Data>(configuration: config)

		#expect(cache.memoryPressureSource == nil)
	}

	@Test("Monitoring is active by default")
	func monitoringActiveByDefault() async throws {
		let config = JohnnyCache<String, Data>.Configuration(location: nil)
		let cache = JohnnyCache<String, Data>(configuration: config)

		#expect(cache.memoryPressureSource != nil)
	}
}
