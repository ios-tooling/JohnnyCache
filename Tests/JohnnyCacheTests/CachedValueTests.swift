//
//  CachedValueTests.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 7/7/26.
//

import Testing
import Foundation
@testable import JohnnyCache

private struct Payload: Codable, Sendable, Equatable, CacheableElement {
	var name: String
	var count: Int
}

private func tempLocation() -> CacheLocation {
	.custom(URL.temporaryDirectory.appendingPathComponent(UUID().uuidString))
}

@Suite("CachedValue")
@MainActor
struct CachedValueTests {
	@Test("Round-trips a value through memory")
	func roundTrip() {
		let cached = CachedValue<Payload>(name: "test", location: tempLocation())
		#expect(cached.value == nil)

		cached.value = Payload(name: "hello", count: 3)
		#expect(cached.value == Payload(name: "hello", count: 3))
	}

	@Test("Persists to disk across instances")
	func persistsAcrossInstances() {
		let location = tempLocation()
		let first = CachedValue<Payload>(name: "test", location: location)
		first.value = Payload(name: "persisted", count: 7)

		let second = CachedValue<Payload>(name: "test", location: location)
		#expect(second.value == Payload(name: "persisted", count: 7))
	}

	@Test("Caches arrays without explicit conformance")
	func cachesArrays() {
		let cached = CachedValue<[Payload]>(name: "test", location: tempLocation())
		cached.value = [Payload(name: "a", count: 1), Payload(name: "b", count: 2)]
		#expect(cached.value?.count == 2)
	}

	@Test("maxAge read misses once the value is too old")
	func maxAgeMiss() async throws {
		let cached = CachedValue<Payload>(name: "test", location: tempLocation())
		cached.value = Payload(name: "fresh", count: 1)

		#expect(cached.value(maxAge: 60) != nil)
		try await Task.sleep(for: .milliseconds(50))
		#expect(cached.value(maxAge: 0.01) == nil)
	}

	@Test("newerThan read misses for values cached before the date")
	func newerThanMiss() {
		let cached = CachedValue<Payload>(name: "test", location: tempLocation())
		cached.value = Payload(name: "old", count: 1)

		#expect(cached.value(newerThan: Date(timeIntervalSinceNow: -60)) != nil)
		#expect(cached.value(newerThan: Date(timeIntervalSinceNow: 60)) == nil)
	}

	@Test("clear removes memory and disk copies")
	func clearRemovesBoth() {
		let location = tempLocation()
		let cached = CachedValue<Payload>(name: "test", location: location)
		cached.value = Payload(name: "gone", count: 1)
		cached.clear()

		#expect(cached.value == nil)
		#expect(CachedValue<Payload>(name: "test", location: location).value == nil)
	}
}

@Suite("Registry sweep")
@MainActor
struct RegistrySweepTests {
	@Test("clearAllRegistered clears normal caches and skips sign-out-persistent ones")
	func sweepSkipsPersistent() {
		let normal = CachedValue<Payload>(name: "normal", location: tempLocation())
		let persistent = CachedValue<Payload>(name: "persistent", location: tempLocation(), signOutPersistent: true)
		normal.value = Payload(name: "user", count: 1)
		persistent.value = Payload(name: "flags", count: 2)

		JohnnyCacheRegistry.clearAllRegistered()

		#expect(normal.value == nil)
		#expect(persistent.value == Payload(name: "flags", count: 2))
	}

	@Test("Sweep clears keyed caches too")
	func sweepClearsKeyedCache() {
		let cache = JohnnyCache<String, Payload>(configuration: .init(location: URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
		cache["a"] = Payload(name: "a", count: 1)

		JohnnyCacheRegistry.clearAllRegistered()

		#expect(cache["a"] == nil)
	}

	@Test("Default error handler receives decode failures")
	func defaultErrorHandlerFires() throws {
		let location = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let cached = CachedValue<Payload>(name: "corrupt", location: .custom(location))

		var reported: String?
		JohnnyCacheRegistry.defaultErrorHandler = { _, context in reported = context }
		defer { JohnnyCacheRegistry.defaultErrorHandler = nil }

		try Data("not json".utf8).write(to: location.appendingPathComponent("value", conformingTo: Payload.uttype))
		#expect(cached.value == nil)
		#expect(reported != nil)
	}
}
