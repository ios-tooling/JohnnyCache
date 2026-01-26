//
//  JohnnyCache+RetrieveValue.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//

import Foundation

extension JohnnyCache {
	func inMemoryElement(for key: Key, maxAge: TimeInterval?, newerThan: Date?) -> Element? {
		guard var item = cache[key] else { return nil }
		
		if let newerThan, item.cachedAt < newerThan { return nil }
		if let maxAge, maxAge < abs(item.cachedAt.timeIntervalSinceNow) { return nil }
		
		item.accessedAt = Date()
		cache[key] = item
		return item.element
	}
	
	func onDiskElement(for key: Key, maxAge: TimeInterval?, newerThan: Date?) -> Element? {
		guard let url = onDiskURL(for: key) else { return nil }
		
		if let cachedAt = url.createdAt {
			if let newerThan, cachedAt < newerThan { return nil }
			if let maxAge, maxAge < abs(cachedAt.timeIntervalSinceNow) { return nil }
		}

		guard let data = try? Data(contentsOf: url) else { return nil }
		
		do {
			let element = try Element.from(data: data)
			url.setModificationDate()
			storeInMemory(element, forKey: key, cachedAt: url.createdAt)
			return element
		} catch {
			report(error: error, context: "Failed to extract element for \(key) from \(url)")
			return nil
		}
	}
}
