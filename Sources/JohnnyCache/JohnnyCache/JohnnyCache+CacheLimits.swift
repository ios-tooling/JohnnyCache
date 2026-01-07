//
//  JohnnyCache+CacheLimits.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//

import Foundation

extension JohnnyCache {
	func checkInMemorySize() {
		let limit = configuration.inMemoryLimit
		
		if inMemoryCost < limit { return }
		
		purgeInMemory(downTo: limit * 3 / 4)
	}
	
	func purgeInMemory(downTo limit: UInt64) {
		let all = cache.values.sorted { $0.accessedAt < $1.accessedAt }
		var index = 0
		while inMemoryCost > limit, index < all.count {
			storeInMemory(nil, forKey: all[index].key)
			index += 1
		}
	}

	func purgeOnDisk(downTo limit: UInt64) {
		let fm = FileManager.default
		guard let location = configuration.location, let files = try? fm.listAllFiles(in: location) else { return }
		let sorted = files.sorted { $0.creationDate < $1.creationDate }
		var total = files.reduce(0, { $0 + $1.size })
		var index = 0
		
		while total > limit, index < sorted.count {
			total -= sorted[index].size
			try? fm.removeItem(at: sorted[index].url)
			index += 1
		}
	}

	
	func checkOnDiskSize() {
		let limit = configuration.onDiskLimit
		
		if onDiskCost < limit { return }
		
		purgeOnDisk(downTo: limit * 3 / 4)
	}
}
