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
			if let fetchElement {
				do {
					let newValue = try await fetchElement(key)
					storeInMemory(newValue, forKey: key)
					storeOnDisk(newValue, forKey: key)
					return newValue
				} catch {
					report(error: error, context: "Failed to fetch item for key \(key)")
				}
			}
			return nil
		}
	}
	
	public func clearAll(inMemory: Bool = true, onDisk: Bool = true) {
		if inMemory { clearInMemory() }
		if onDisk { clearOnDisk() }
	}
	
	func clearInMemory() {
		cache = [:]
		inMemoryCost = 0
	}
		
	func clearOnDisk() {
		guard let location = configuration.location else { return }
		try? FileManager.default.removeItem(at: location)
		try? FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
		onDiskCost = 0
	}
	
	func inMemoryElement(for key: Key) -> Element? {
		guard var item = cache[key] else { return nil }
		
		item.accessedAt = .now
		cache[key] = item
		return item.element
	}
	
	func onDiskElement(for key: Key) -> Element? {
		guard let url = onDiskURL(for: key) else { return nil }
		guard let data = try? Data(contentsOf: url) else { return nil }
		
		do {
			let element = try Element.from(data: data)
			url.setModificationDate()
			storeInMemory(element, forKey: key)
			return element
		} catch {
			report(error: error, context: "Failed to extract element for \(key) from \(url)")
			return nil
		}
	}
	
	func storeInMemory(_ element: Element?, forKey key: Key) {
		if let element {
			inMemoryCost -= cache[key]?.cacheCost ?? 0
			cache[key] = .init(key: key, element: element, cacheCost: element.cacheCost)
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
	
	func onDiskURL(for key: Key) -> URL? {
		guard let location = configuration.location else { return nil }
		let path = key.stringRepresentation.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: ";")
		
		return location.appendingPathComponent(path, conformingTo: Element.uttype)
	}
}
