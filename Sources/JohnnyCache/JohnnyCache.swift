//
//  JohnnyCache.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//

import Foundation

@MainActor public class JohnnyCache<CacheKey: CacheableKey, CachedElement: CacheableElement> {
	var cache: [CacheKey: CachedItem<CachedElement>] = [:]
	let location: URL?
	
	func report(error: any Error, context: String) {
		print("\(context) \(error.localizedDescription)")
	}
	
	public init(onDisk url: URL? = URL.cachesDirectory.appendingPathComponent(String(describing: CachedElement.self))) {
		location = url
		
		if let url {
			try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
		}
	}
	
	public subscript(key: CacheKey) -> CachedElement? {
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
	
	public func clearAll(inMemory: Bool = true, onDisk: Bool = true) {
		if inMemory { cache = [:] }
		if onDisk { clearOnDisk() }
	}
		
	func clearOnDisk() {
		guard let location else { return }
		try? FileManager.default.removeItem(at: location)
		try? FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
	}
	
	func inMemoryElement(for key: CacheKey) -> CachedElement? { cache[key]?.element }
	func onDiskElement(for key: CacheKey) -> CachedElement? {
		guard let url = onDiskURL(for: key) else { return nil }
		guard let data = try? Data(contentsOf: url) else { return nil }
		
		do {
			let element = try CachedElement.from(data: data)
			storeInMemory(element, forKey: key)
			return element
		} catch {
			report(error: error, context: "Failed to extract element for \(key) from \(url)")
			return nil
		}
	}
	
	func storeInMemory(_ element: CachedElement?, forKey key: CacheKey) {
		if let element {
			cache[key] = .init(element: element)
		} else {
			cache.removeValue(forKey: key)
		}
	}
	
	func storeOnDisk(_ element: CachedElement?, forKey key: CacheKey) {
		guard let url = onDiskURL(for: key) else { return }
		
		if let element {
			do {
				let data = try element.toData()
				try data.write(to: url)
			} catch {
				report(error: error, context: "Failed to extract data for \(key)")
			}
		} else {
			try? FileManager.default.removeItem(at: url)
		}
	}
	
	func onDiskURL(for key: CacheKey) -> URL? {
		guard let location else { return nil }
		
		return location.appendingPathComponent(key.stringRepresentation, conformingTo: CachedElement.uttype)
	}
}
