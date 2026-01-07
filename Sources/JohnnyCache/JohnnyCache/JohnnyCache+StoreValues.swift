//
//  File.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//

import Foundation

extension JohnnyCache {
	func storeInMemory(_ element: Element?, forKey key: Key) {
		if let element {
			inMemoryCost -= cache[key]?.cacheCost ?? 0
			cache[key] = .init(key: key, element: element, cacheCost: element.cacheCost)
			inMemoryCost += element.cacheCost
			checkInMemorySize()
		} else {
			guard let existing = cache[key] else { return }
			inMemoryCost -= existing.element.cacheCost
			cache.removeValue(forKey: key)
		}
	}
	
	func storeOnDisk(_ element: Element?, forKey key: Key) {
		guard let url = onDiskURL(for: key) else { return }
		
		if let element {
			do {
				if FileManager.default.fileExists(atPath: url.path) {
					onDiskCost -= url.fileSize
					try? FileManager.default.removeItem(at: url)
				}
				let data = try element.toData()
				try data.write(to: url)
				onDiskCost += UInt64(data.count)
				checkOnDiskSize()
			} catch {
				report(error: error, context: "Failed to extract data for \(key)")
			}
		} else {
			onDiskCost -= url.fileSize
			try? FileManager.default.removeItem(at: url)
		}
	}
	

}
