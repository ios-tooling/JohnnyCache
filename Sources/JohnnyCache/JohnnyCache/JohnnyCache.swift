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

	// Per-key observer callbacks, keyed by a UUID for removal
	var observers: [Key: [UUID: (Element?) -> Void]] = [:]

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
		
		set { set(newValue, forKey: key) }
	}
	
	public func set(_ newValue: Element?, forKey key: Key) {
		storeInMemory(newValue, forKey: key, cachedAt: Date())
		storeOnDisk(newValue, forKey: key)
		
		// Store to CloudKit if configured (in background)
		if #available(macOS 15.0, iOS 16.0, watchOS 10.0, tvOS 16.0, visionOS 1.0, *), configuration.cloudKitInfo != nil {
			Task {
				try? await storeInCloudKit(newValue, forKey: key)
			}
		}
	}

	public func clearValue(forKey key: Key) {
		set(nil, forKey: key)
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
							storeInMemory(cloudKitValue, forKey: key, cachedAt: Date())
							storeOnDisk(cloudKitValue, forKey: key)
							return cloudKitValue
						}
					}

					if let fetchElement {
						let newValue = try await fetchElement(key)
						storeInMemory(newValue, forKey: key, cachedAt: Date())
						storeOnDisk(newValue, forKey: key)

						// Store to CloudKit if configured (in background to avoid blocking)
						if #available(iOS 16.0, macOS 15, watchOS 10, tvOS 16.0, visionOS 1.0, *), configuration.cloudKitInfo != nil {
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

	/// Clears all caches including CloudKit
	/// - Parameters:
	///   - inMemory: Clear in-memory cache (default: true)
	///   - onDisk: Clear on-disk cache (default: true)
	///   - cloudKit: Clear CloudKit cache (default: false)
	public func clearAllCaches(inMemory: Bool = true, onDisk: Bool = true, cloudKit: Bool = false) async throws {
		if inMemory { clearInMemory() }
		if onDisk { clearOnDisk() }
		if #available(iOS 16.0, macOS 15, watchOS 10, tvOS 16.0, visionOS 1.0, *), cloudKit {
			try await clearCloudKit()
		}
	}
	
	public func addObserver(for key: Key, id: UUID, handler: @escaping (Element?) -> Void) {
		observers[key, default: [:]][id] = handler
	}

	public func removeObserver(for key: Key, id: UUID) {
		observers[key]?[id] = nil
		if observers[key]?.isEmpty == true {
			observers.removeValue(forKey: key)
		}
	}

	func notifyObservers(for key: Key, element: Element?) {
		guard let keyObservers = observers[key] else { return }
		for handler in keyObservers.values {
			handler(element)
		}
	}

	func onDiskURL(for key: Key) -> URL? {
		guard let location = configuration.location else { return nil }
		let path = key.stringRepresentation.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: ";")
		
		return location.appendingPathComponent(path, conformingTo: Element.uttype)
	}
}
