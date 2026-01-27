//
//  ImageCacheManager.swift
//  JohnnyCacheTest
//
//  Created by Claude on 1/26/26.
//

import Foundation
import SwiftUI
import CloudKit
import JohnnyCache

@MainActor
@Observable
class ImageCacheManager {
	static let shared = ImageCacheManager()

	var cacheStats = CacheStats()

	// JohnnyCache configured with CloudKit
	let imageCache: JohnnyCache<URL, Data>

	struct CacheStats {
		var inMemoryCost: UInt64 = 0
		var onDiskCost: UInt64 = 0
		var formattedInMemory: String { ByteCountFormatter.string(fromByteCount: Int64(inMemoryCost), countStyle: .memory) }
		var formattedOnDisk: String { ByteCountFormatter.string(fromByteCount: Int64(onDiskCost), countStyle: .file) }
	}

	private init() {
		// Configure CloudKit
		let container = CKContainer(identifier: "iCloud.con.standalone.cloudkittesting")

		// Configure cache with CloudKit
		let config = JohnnyCache<URL, Data>.Configuration(
			name: "ImageCache",
			inMemory: 50 * 1024 * 1024,  // 50MB in memory
			onDisk: 200 * 1024 * 1024,    // 200MB on disk
			cloudKitInfo: .init(container: container, recordName: "CachedImage", assetLimit: 50_000)
		)

		// Create cache with async fetch function
		imageCache = JohnnyCache<URL, Data>(configuration: config) { url in
			print("📥 Fetching image from network: \(url.lastPathComponent)")

			// Fetch from network
			let (data, response) = try await URLSession.shared.data(from: url)

			guard let httpResponse = response as? HTTPURLResponse,
				  httpResponse.statusCode == 200 else {
				throw URLError(.badServerResponse)
			}

			print("✅ Downloaded image: \(url.lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)))")
			return data
		}

		updateStats()
	}

	func updateStats() {
		cacheStats.inMemoryCost = imageCache.inMemoryCost
		cacheStats.onDiskCost = imageCache.onDiskCost
	}

	func clearCache(inMemory: Bool = true, onDisk: Bool = true) {
		imageCache.clearAll(inMemory: inMemory, onDisk: onDisk)
		updateStats()
	}

	func clearCache(inMemory: Bool = true, onDisk: Bool = true, cloudKit: Bool = false) async throws {
		try await imageCache.clearAllCaches(inMemory: inMemory, onDisk: onDisk, cloudKit: cloudKit)
		updateStats()
	}

	// Fetch image with CloudKit caching
	func fetchImage(from url: URL) async throws -> Data? {
		let data = try await imageCache[async: url]
		updateStats()
		return data
	}

	// Check if image is already cached (sync check)
	func cachedImage(for url: URL) -> Data? {
		let data = imageCache[url]
		return data
	}
}
