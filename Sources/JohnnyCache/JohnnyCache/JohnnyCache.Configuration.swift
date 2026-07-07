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
		var inMemoryLimit: UInt64 = 1024 * 1024 * 200
		var onDiskLimit: UInt64 = 1024 * 1024 * 1024
		var respondsToMemoryPressure = true
		var cloudKitInfo: CloudKitInfo?
		var signOutPersistent = false

		public init(
			location: URL? = URL.cacheDirectory(named: String(describing: Element.self)),
			name: String? = nil,
				inMemory: UInt64 = 1024 * 1024 * 200, 	// 200 MB in memory limit
				onDisk: UInt64 = 1024 * 1024 * 1024, 	// 1 GB on disk limit
				respondsToMemoryPressure: Bool = true,
				cloudKitInfo: CloudKitInfo? = nil,
				signOutPersistent: Bool = false
		) {
			if let name {
				self.location = URL.cacheDirectory(named: name)
			} else if let location {
				self.location = location
			}
			self.inMemoryLimit = inMemory
			self.onDiskLimit = onDisk
			self.respondsToMemoryPressure = respondsToMemoryPressure
			self.cloudKitInfo = cloudKitInfo
			self.signOutPersistent = signOutPersistent
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
		if #available(iOS 16.0, tvOS 16.0, visionOS 1.0, *) {
			URL.cachesDirectory.appendingPathComponent(name)
		} else {
			FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		}
	}
}
