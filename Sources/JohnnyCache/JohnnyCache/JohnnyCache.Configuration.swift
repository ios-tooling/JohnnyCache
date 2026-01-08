//
//  JohnnyCache.Configuration.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//

import Foundation

extension JohnnyCache {
	public struct Configuration {
		var location: URL?
		var inMemoryLimit: UInt64
		var onDiskLimit: UInt64

		public init(
			location: URL? = URL.cacheDirectory(named: String(describing: Element.self)),
				inMemory: UInt64 = 1024 * 1024 * 100, 	// 100 MB in memory limit
				onDisk: UInt64 = 1024 * 1024 * 1024, 	// 1 GB on disk limit
		) {
			self.location = location
			self.inMemoryLimit = inMemory
			self.onDiskLimit = onDisk
		}
	}
}

extension URL {
	public static func cacheDirectory(named name: String) -> URL {
		if #available(iOS 16.0, *) {
			URL.cachesDirectory.appendingPathComponent(name)
		} else {
			FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		}
	}
}
