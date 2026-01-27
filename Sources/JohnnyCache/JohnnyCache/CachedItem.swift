//
//  CachedItem.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//

import Foundation

extension JohnnyCache {
	struct CachedItem: Sendable {
		var key: Key
		var element: Element
		var cacheCost: UInt64
		var accessedAt = Date()
		var cachedAt: Date
		
		init(key: Key, element: Element, cacheCost: UInt64, cachedAt: Date? = nil) {
			self.key = key
			self.element = element
			self.cacheCost = cacheCost
			self.cachedAt = cachedAt ?? Date()
		}
	}
}
