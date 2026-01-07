//
//  JohnnyCache+RetrieveValue.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//

import Foundation

extension JohnnyCache {
	func inMemoryElement(for key: Key) -> Element? {
		guard var item = cache[key] else { return nil }
		
		item.accessedAt = .now
		cache[key] = item
		return item.element
	}
	
	func onDiskElement(for key: Key) -> Element? {
		guard let url = onDiskURL(for: key) else { return nil }
		guard let data = try? Data(contentsOf: url) else { return nil }
		
		do {
			let element = try Element.from(data: data)
			url.setModificationDate()
			storeInMemory(element, forKey: key)
			return element
		} catch {
			report(error: error, context: "Failed to extract element for \(key) from \(url)")
			return nil
		}
	}
}
