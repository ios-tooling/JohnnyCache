//
//  JohnnyCache+RetrieveValue.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//

import Foundation
import CloudKit

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
	
	func cloudKitElement(for key: Key, maxAge: TimeInterval?, newerThan: Date?) async throws -> Element? {
		guard let info = configuration.cloudKitInfo, let recordID = recordID(forKey: key) else { return nil }

		let database = info.container.publicCloudDatabase

		do {
			let record = try await database.record(for: recordID)

			// Check age constraints against record modification date
			if let modificationDate = record.modificationDate {
				if let newerThan, modificationDate < newerThan { return nil }
				if let maxAge, maxAge < abs(modificationDate.timeIntervalSinceNow) { return nil }
			}

			// Extract data from the record - check both "data" field and "data_asset"
			let data: Data
			if let asset = record["data_asset"] as? CKAsset, let fileURL = asset.fileURL {
				data = try Data(contentsOf: fileURL)
			} else if let directData = record["data"] as? Data {
				data = directData
			} else {
				report(error: CacheableElementError.noDataAvailable, context: "CloudKit record for \(key) missing data field and asset")
				return nil
			}

			// Deserialize element
			let element = try Element.from(data: data)

			// Store locally for faster future access
			storeInMemory(element, forKey: key, cachedAt: record.creationDate)
			storeOnDisk(element, forKey: key)

			return element
		} catch let error as CKError where error.code == .unknownItem {
			// Record doesn't exist in CloudKit - not an error, just a cache miss
			return nil
		} catch {
			report(error: error, context: "Failed to fetch CloudKit record for \(key)")
			throw error
		}
	}
}
