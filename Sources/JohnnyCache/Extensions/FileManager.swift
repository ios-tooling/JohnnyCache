//
//  File.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//

import Foundation

extension FileManager {
	struct FileInfo: Sendable {
		let url: URL
		let size: UInt64
		let creationDate: Date
	}
	
	enum FileIndexError: Error {
		case notAFile(URL)
	}
	
	func setModificationDate(at url: URL, to date: Date = Date()) {
		try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
	}
	
	func fileSize(at url: URL) -> UInt64 {
		guard let attr = try? attributesOfItem(atPath: url.path) else { return 0 }
		
		return UInt64(attr[.size] as? Int64 ?? 0)
	}
	
	func listAllFiles(in directoryURL: URL, includingSubdirectories: Bool = false) throws -> [FileInfo] {
		let fm = self
		
		// Ask the enumerator to prefetch the resource keys we care about.
		let keys: Set<URLResourceKey> = [
			.isRegularFileKey,
			.fileSizeKey,
			.totalFileSizeKey,      // sometimes useful for packaged files
			.creationDateKey,
			.contentModificationDateKey
		]
		
		guard let enumerator = fm.enumerator(
			at: directoryURL,
			includingPropertiesForKeys: Array(keys),
			options: includingSubdirectories ? [] : [.skipsSubdirectoryDescendants],
			errorHandler: { url, error in
				// Decide whether to stop or continue.
				// Return true to continue enumeration.
				// You can log/collect errors here if you want.
				return true
			}
		) else {
			return []
		}
		
		var results: [FileInfo] = []
		results.reserveCapacity(512)
		
		for case let fileURL as URL in enumerator {
			// Pull resource values (prefetched above).
			let values = try fileURL.resourceValues(forKeys: keys)
			
			// Skip non-regular files (directories, symlinks, etc.)
			guard values.isRegularFile == true else { continue }
			
			// Size: prefer fileSize; fall back to totalFileSize if needed.
			let sizeInt = values.fileSize ?? values.totalFileSize ?? 0
			
			// Creation date: if missing, decide what you want (skip, default, throw).
			guard let creationDate = values.contentModificationDate ?? values.creationDate else { continue }
			
			results.append(
				FileInfo(
					url: fileURL,
					size: UInt64(sizeInt),
					creationDate: creationDate
				)
			)
		}
		
		return results
	}
	
}
