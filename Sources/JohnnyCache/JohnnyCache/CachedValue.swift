//
//  CachedValue.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 7/7/26.
//

import Foundation

/// A single-value cache: one named value persisted to disk, with the same
/// freshness, registry, and error-reporting behavior as a keyed `JohnnyCache`.
///
///     let cache = CachedValue<Payload>(name: "feature_flags", location: .library, signOutPersistent: true)
///     cache.value = payload                    // persists
///     cache.value(newerThan: someDate)         // freshness read
///     cache.clear()
@MainActor public struct CachedValue<Element: CacheableElement> {
	let cache: JohnnyCache<String, Element>
	let key = "value"

	public init(name: String, location: CacheLocation = .caches, signOutPersistent: Bool = false) {
		cache = JohnnyCache<String, Element>(configuration: .init(
			location: location.directory(named: name),
			signOutPersistent: signOutPersistent
		))
	}

	/// The cached value. Setting persists to disk; setting `nil` removes it.
	public var value: Element? {
		get { cache[key] }
		nonmutating set { cache.set(newValue, forKey: key) }
	}

	/// Returns the value only if it was cached within the last `maxAge` seconds.
	public func value(maxAge: TimeInterval) -> Element? {
		cache[key, maxAge: maxAge]
	}

	/// Returns the value only if it was cached after `date`.
	public func value(newerThan date: Date) -> Element? {
		cache[key, newerThan: date]
	}

	public func clear() {
		cache.clearValue(forKey: key)
	}
}
