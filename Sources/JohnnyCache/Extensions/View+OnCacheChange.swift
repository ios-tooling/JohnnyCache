//
//  View+OnCacheChange.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 3/13/26.
//

import SwiftUI

@available(iOS 15.0, *)
private struct OnCacheChangeModifier<Key: CacheableKey, Element: CacheableElement>: ViewModifier {
	let cache: JohnnyCache<Key, Element>
	let key: Key
	let action: (Element?) -> Void
	var initialValue: (() async -> Element?)?

	@State private var observerID = UUID()

	func body(content: Content) -> some View {
		let changeToken = cache.changeToken(for: key)
		content
			.onAppear {
				if let current = cache[key] {
					action(current)
				}
				cache.addObserver(for: key, id: observerID, handler: action)
			}
			.task(id: changeToken) {
				if let initial = await initialValue?() {
					cache[key] = initial
					action(initial)
				}
				guard !Task.isCancelled else { return }
			}
			.onDisappear {
				cache.removeObserver(for: key, id: observerID)
			}
	}
}

@available(iOS 15.0, *)
public extension View {
	func onCacheChange<Key: CacheableKey, Element: CacheableElement>(
		in cache: JohnnyCache<Key, Element>,
		for key: Key,
		perform action: @escaping (Element?) -> Void
	) -> some View {
		modifier(OnCacheChangeModifier(cache: cache, key: key, action: action, initialValue: nil))
	}
	
	func onCacheChange<Key: CacheableKey, Element: CacheableElement>(
		in cache: JohnnyCache<Key, Element>,
		for key: Key,
		initial: @autoclosure @escaping () -> Element?,
		perform action: @escaping (Element?) -> Void
	) -> some View {
		modifier(OnCacheChangeModifier(cache: cache, key: key, action: action, initialValue: initial))
	}
	
	func onCacheChange<Key: CacheableKey, Element: CacheableElement>(
		in cache: JohnnyCache<Key, Element>,
		for key: Key,
		initial: @escaping () async -> Element?,
		perform action: @escaping (Element?) -> Void
	) -> some View {
		modifier(OnCacheChangeModifier(cache: cache, key: key, action: action, initialValue: initial))
	}
}
