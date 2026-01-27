//
//  JohnnyCache.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//

import Foundation
import OSLog

@MainActor public class JohnnyCache<Key: CacheableKey, Element: CacheableElement> {
	var cache: [Key: CachedItem] = [:]
	var configuration: Configuration
	var isSignedInToCloudKit = false
	public var fetchElement: FetchElement?
	public internal(set) var inMemoryCost: UInt64 = 0
	public internal(set) var onDiskCost: UInt64 = 0

	// Tracks in-flight fetch operations to prevent duplicate requests for the same key
	internal var inFlightFetches: [Key: Task<Element?, Error>] = [:]

	private let logger = Logger(subsystem: "com.standalone.JohnnyCache", category: "cache")

	public typealias FetchElement = (Key) async throws -> Element?
	public typealias ErrorHandler = @MainActor (Error, String) -> Void

	/// Optional custom error handler. If not set, errors are logged using OSLog.
	public var errorHandler: ErrorHandler?
	
	func report(error: Error, context: String) {
		if let errorHandler {
			errorHandler(error, context)
		} else {
			logger.error("\(context): \(error.localizedDescription)")
		}
	}
	
	public init(configuration config: Configuration = .init(), fetch: FetchElement? = nil) {
		configuration = config
		fetchElement = fetch
		setupCloudKit()
		
		if let url = config.location {
			let fm = FileManager.default
			try? fm.createDirectory(at: url, withIntermediateDirectories: true)
			if let files = try? fm.listAllFiles(in: url) {
				onDiskCost = files.reduce(0, { $0 + $1.size })
			}
		}
	}
	
	public subscript(key: Key, maxAge maxAge: TimeInterval? = nil, newerThan newerThan: Date? = nil) -> Element? {
		get {
			if let inMemory = inMemoryElement(for: key, maxAge: maxAge, newerThan: newerThan) { return inMemory }
			if let onDisk = onDiskElement(for: key, maxAge: maxAge, newerThan: newerThan) { return onDisk }
			
			return nil
		}
		
		set {
			storeInMemory(newValue, forKey: key, cachedAt: .now)
			storeOnDisk(newValue, forKey: key)

			// Store to CloudKit if configured (in background)
			if configuration.cloudKitInfo != nil {
				Task {
					try? await storeInCloudKit(newValue, forKey: key)
				}
			}
		}
	}
	
	public subscript(async key: Key, maxAge maxAge: TimeInterval? = nil, newerThan newerThan: Date? = nil) -> Element? {
		get async throws {
			if let cached = self[key, maxAge: maxAge, newerThan: newerThan] { return cached }

			// Check if there's already a fetch in progress for this key
			if let existingTask = inFlightFetches[key] {
				return try await existingTask.value
			}

			// No fetch element configured
			guard fetchElement != nil || configuration.cloudKitInfo != nil else { return nil }

			// Create and track new fetch task
			let task: Task<Element?, Error> = Task { @MainActor in
				do {
					if configuration.cloudKitInfo != nil {
						if let cloudKitValue = try await cloudKitElement(for: key, maxAge: maxAge, newerThan: newerThan) {
							storeInMemory(cloudKitValue, forKey: key, cachedAt: .now)
							storeOnDisk(cloudKitValue, forKey: key)
							return cloudKitValue
						}
					}

					if let fetchElement {
						let newValue = try await fetchElement(key)
						storeInMemory(newValue, forKey: key, cachedAt: .now)
						storeOnDisk(newValue, forKey: key)

						// Store to CloudKit if configured (in background to avoid blocking)
						if configuration.cloudKitInfo != nil {
							Task {
								try? await storeInCloudKit(newValue, forKey: key)
							}
						}

						return newValue
					}
				} catch {
					report(error: error, context: "Failed to fetch item for key \(key)")
					throw error
				}
				
				return nil
			}

			inFlightFetches[key] = task
			defer { inFlightFetches.removeValue(forKey: key) }
			return try await task.value
		}
	}
	
	public func clearAll(inMemory: Bool = true, onDisk: Bool = true) {
		if inMemory { clearInMemory() }
		if onDisk { clearOnDisk() }
	}
	
	func onDiskURL(for key: Key) -> URL? {
		guard let location = configuration.location else { return nil }
		let path = key.stringRepresentation.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: ";")
		
		return location.appendingPathComponent(path, conformingTo: Element.uttype)
	}
}
