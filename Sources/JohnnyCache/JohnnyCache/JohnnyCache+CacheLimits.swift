//
//  JohnnyCache+CacheLimits.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//

import Foundation
import CloudKit

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
			storeInMemory(nil, forKey: all[index].key, cachedAt: nil)
			index += 1
		}
	}
	
	func purgeOnDisk(downTo limit: UInt64) {
		let fm = FileManager.default
		guard let location = configuration.location, let files = try? fm.listAllFiles(in: location) else { return }
		let sorted = files.sorted { $0.creationDate < $1.creationDate }
		var index = 0
		
		while onDiskCost > limit, index < sorted.count {
			onDiskCost -= sorted[index].size
			try? fm.removeItem(at: sorted[index].url)
			index += 1
		}
	}
	
	
	func checkOnDiskSize() {
		let limit = configuration.onDiskLimit
		
		if onDiskCost < limit { return }
		
		purgeOnDisk(downTo: limit * 3 / 4)
	}
	
	func clearInMemory() {
		cache = [:]
		inMemoryCost = 0

		// Cancel in-flight fetches as the cache is being cleared
		for (_, task) in inFlightFetches { task.cancel() }
		inFlightFetches.removeAll()
	}
		
	func clearOnDisk() {
		guard let location = configuration.location else { return }
		try? FileManager.default.removeItem(at: location)
		try? FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
		onDiskCost = 0
	}
	
	/// Clears all cached items from CloudKit
	/// This queries and deletes all records with the configured recordName
	@available(iOS 16.0, macOS 15, watchOS 10, *)
	func clearCloudKit() async throws {
		guard let info = configuration.cloudKitInfo else { return }

		let database = info.container.publicCloudDatabase
		let query = CKQuery(recordType: info.recordName, predicate: NSPredicate(value: true))

		do {
			// Query all records of this type
			let (matchResults, _) = try await database.records(matching: query)

			// Collect record IDs to delete
			var recordIDsToDelete: [CKRecord.ID] = []
			for (recordID, result) in matchResults {
				switch result {
				case .success:
					recordIDsToDelete.append(recordID)
				case .failure(let error):
					print("Error fetching record \(recordID): \(error)")
				}
			}

			// Delete records in batches if needed
			guard !recordIDsToDelete.isEmpty else {
				print("No CloudKit records found to delete")
				return
			}

			print("Deleting \(recordIDsToDelete.count) CloudKit records...")

			// Delete all records
			let modifyResult = try await database.modifyRecords(saving: [], deleting: recordIDsToDelete)

			var deletedCount = 0
			var failedCount = 0

			for (recordID, result) in modifyResult.deleteResults {
				switch result {
				case .success:
					deletedCount += 1
				case .failure(let error):
					failedCount += 1
					print("Failed to delete record \(recordID): \(error)")
				}
			}

			print("✅ Deleted \(deletedCount) CloudKit records" + (failedCount > 0 ? " (failed: \(failedCount))" : ""))

		} catch {
			report(error: error, context: "Failed to clear CloudKit cache")
			throw error
		}
	}


}
