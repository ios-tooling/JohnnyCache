//
//  JohnnyCache+StoreValues.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//

import Foundation
import CloudKit

extension JohnnyCache {
	func storeInMemory(_ element: Element?, forKey key: Key, cachedAt: Date?) {
		if let element {
			inMemoryCost -= cache[key]?.cacheCost ?? 0
			cache[key] = .init(key: key, element: element, cacheCost: element.cacheCost, cachedAt: cachedAt)
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
	
	func recordID(forKey key: Key) -> CKRecord.ID? {
		guard let info = configuration.cloudKitInfo else { return nil }

		return CKRecord.ID(recordName: info.recordName + ":" + key.stringRepresentation)
	}
	
	func storeInCloudKit(_ element: Element?, forKey key: Key) async throws {
		guard isSignedInToCloudKit, let info = configuration.cloudKitInfo, let recordID = recordID(forKey: key) else { return }
		var tempFileURL: URL?
		
		let database = info.container.publicCloudDatabase

		if let element {
			// Store element in CloudKit
			let data = try element.toData()

			// Fetch existing record or create new one
			let record: CKRecord
			do {
				record = try await database.record(for: recordID)
			} catch let error as CKError where error.code == .unknownItem {
				// Record doesn't exist, create new one
				record = CKRecord(recordType: info.recordName, recordID: recordID)
			} catch {
				throw error
			}

			// Store data in the record
			if data.count > info.assetLimit {
				let tempURL = URL.temporaryDirectory.appendingPathComponent(recordID.recordName)
				try data.write(to: tempURL, options: .atomic)
				tempFileURL = tempURL
				record["data_asset"] = CKAsset(fileURL: tempURL)
				record["data"] = nil
			} else {
				record["data_asset"] = nil
				record["data"] = data
			}
			do {
				// Save to CloudKit
				try await database.save(record)
			} catch let error as CKError {
				if error.code == .permissionFailure {
					#if targetEnvironment(simulator)
					print("☁️ Make sure you've properly set Create Permissions on \"\(info.recordName)\" records in your CloudKit dashboard. https://icloud.developer.apple.com/dashboard/database/")
					#endif
					return
				}
				throw error
			}
		} else {
			// Delete element from CloudKit
			do {
				try await database.deleteRecord(withID: recordID)
			} catch let error as CKError where error.code == .unknownItem {
				// Record doesn't exist - not an error
				return
			} catch {
				throw error
			}
		}
		if let tempFileURL { try? FileManager.default.removeItem(at: tempFileURL) }
	}
}
