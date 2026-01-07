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
	var fetchElement: FetchElement?
	var inMemoryCost: UInt64 = 0
	var onDiskCost: UInt64 = 0

	// Tracks in-flight fetch operations to prevent duplicate requests for the same key
	internal var inFlightFetches: [Key: Task<Element?, Never>] = [:]

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
		
		if let url = config.location {
			let fm = FileManager.default
			try? fm.createDirectory(at: url, withIntermediateDirectories: true)
			if let files = try? fm.listAllFiles(in: url) {
				onDiskCost = files.reduce(0, { $0 + $1.size })
			}
		}
	}
	
	public subscript(key: Key) -> Element? {
		get {
			if let inMemory = inMemoryElement(for: key) { return inMemory }
			if let onDisk = onDiskElement(for: key) { return onDisk }
			
			return nil
		}
		
		set {
			storeInMemory(newValue, forKey: key)
			storeOnDisk(newValue, forKey: key)
		}
	}
	
	public subscript(async key: Key) -> Element? {
		get async {
			if let cached = self[key] { return cached }

			// Check if there's already a fetch in progress for this key
			if let existingTask = inFlightFetches[key] {
				return await existingTask.value
			}

			// No fetch element configured
			guard let fetchElement else { return nil }

			// Create and track new fetch task
			let task = Task { @MainActor in
				do {
					let newValue = try await fetchElement(key)
					storeInMemory(newValue, forKey: key)
					storeOnDisk(newValue, forKey: key)
					return newValue
				} catch {
					report(error: error, context: "Failed to fetch item for key \(key)")
					return nil
				}
			}

			inFlightFetches[key] = task
			let result = await task.value
			inFlightFetches.removeValue(forKey: key)

			return result
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
