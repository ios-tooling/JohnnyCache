//
//  CachedItem.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//

import Foundation

struct CachedItem<Payload: CacheableElement>: Sendable {
	let element: Payload
	let storedAt: Date = .now
}
