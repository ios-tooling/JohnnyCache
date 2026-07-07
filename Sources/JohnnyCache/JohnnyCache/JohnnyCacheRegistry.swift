//
//  JohnnyCacheRegistry.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 7/7/26.
//

import Foundation

/// A cache that can be cleared wholesale, e.g. when a user signs out.
@MainActor public protocol SweepableCache: AnyObject {
	var isSignOutPersistent: Bool { get }
	func clearForSignOut()
}

/// Tracks every live cache so a host app can clear them all at once
/// (typically on sign-out). Caches register themselves at init; caches whose
/// configuration is `signOutPersistent` are skipped by the sweep.
@MainActor public enum JohnnyCacheRegistry {
	static var registered: [WeakCacheBox] = []

	/// Called for any cache error when the cache has no `errorHandler` of its
	/// own. Set once at app startup to route errors to your reporting system.
	public static var defaultErrorHandler: ((Error, String) -> Void)?

	public static func register(_ cache: some SweepableCache) {
		prune()
		registered.append(.init(cache: cache))
	}

	public static func clearAllRegistered() {
		for box in registered {
			guard let cache = box.cache, !cache.isSignOutPersistent else { continue }
			cache.clearForSignOut()
		}
		prune()
	}

	static func prune() {
		registered.removeAll { $0.cache == nil }
	}

	struct WeakCacheBox {
		weak var cache: (any SweepableCache)?
	}
}

extension JohnnyCache: SweepableCache {
	public var isSignOutPersistent: Bool { configuration.signOutPersistent }

	public func clearForSignOut() {
		let keys = Array(cache.keys)
		clearAll()
		for key in keys { notifyObservers(for: key, element: nil) }
	}
}
