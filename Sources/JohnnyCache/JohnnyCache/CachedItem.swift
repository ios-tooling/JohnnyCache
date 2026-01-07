//
//  CachedItem.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//

import Foundation

extension JohnnyCache {
	struct CachedItem: Sendable {
		let key: Key
		let element: Element
		let storedAt: Date = .now
	}
}
