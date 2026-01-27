//
//  JohnnyCache.Configuration.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//

import Foundation
import CloudKit

extension JohnnyCache {
	public struct Configuration {
		var location: URL?
		var inMemoryLimit: UInt64
		var onDiskLimit: UInt64
		var cloudKitInfo: CloudKitInfo?
		
		public init(
			location: URL? = URL.cacheDirectory(named: String(describing: Element.self)),
			name: String? = nil,
				inMemory: UInt64 = 1024 * 1024 * 100, 	// 100 MB in memory limit
				onDisk: UInt64 = 1024 * 1024 * 1024, 	// 1 GB on disk limit
				cloudKitInfo: CloudKitInfo? = nil
		) {
			if let name {
				self.location = URL.cacheDirectory(named: name)
			} else if let location {
				self.location = location
			}
			self.inMemoryLimit = inMemory
			self.onDiskLimit = onDisk
			self.cloudKitInfo = cloudKitInfo
		}
		
		public struct CloudKitInfo {
			public var container: CKContainer
			public var recordName: String
			public var assetLimit = 10_000
			
			public init(container: CKContainer, recordName: String, assetLimit: Int = 10_000) {
				self.container = container
				self.recordName = recordName
				self.assetLimit = assetLimit
			}
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
