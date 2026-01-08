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
	}
}
