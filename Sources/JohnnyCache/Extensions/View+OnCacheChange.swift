//
//  View+OnCacheChange.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 3/13/26.
//

import SwiftUI

private struct OnCacheChangeModifier<Key: CacheableKey, Element: CacheableElement>: ViewModifier {
	let cache: JohnnyCache<Key, Element>
	let key: Key
	let action: (Element?) -> Void

	@State private var observerID = UUID()

	func body(content: Content) -> some View {
		content
			.task {
				let current = cache[key]
				action(current)
				cache.addObserver(for: key, id: observerID, handler: action)
			}
			.onDisappear {
				cache.removeObserver(for: key, id: observerID)
			}
	}
}

public extension View {
	func onCacheChange<Key: CacheableKey, Element: CacheableElement>(
		in cache: JohnnyCache<Key, Element>,
		for key: Key,
		perform action: @escaping (Element?) -> Void
	) -> some View {
		modifier(OnCacheChangeModifier(cache: cache, key: key, action: action))
	}
}
