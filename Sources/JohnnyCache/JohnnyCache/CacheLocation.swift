//
//  CacheLocation.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 7/7/26.
//

import Foundation

/// Where a cache's on-disk directory lives. `.caches` is purgeable by the OS;
/// use `.library` for cached data that should survive storage pressure.
public enum CacheLocation: Sendable {
	case caches
	case library
	case documents
	case custom(URL)

	public func directory(named name: String) -> URL {
		switch self {
		case .caches: baseDirectory(for: .cachesDirectory).appendingPathComponent(name)
		case .library: baseDirectory(for: .libraryDirectory).appendingPathComponent(name)
		case .documents: baseDirectory(for: .documentDirectory).appendingPathComponent(name)
		case .custom(let url): url
		}
	}

	func baseDirectory(for kind: FileManager.SearchPathDirectory) -> URL {
		FileManager.default.urls(for: kind, in: .userDomainMask).first!
	}
}
