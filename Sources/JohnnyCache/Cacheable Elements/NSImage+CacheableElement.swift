//
//  NSImage+CacheableElement.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//


#if canImport(Cocoa)

import Cocoa
import UniformTypeIdentifiers

extension NSImage: CacheableElement {
	public func toData() throws -> Data {
		guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { throw CacheableElementError.noDataAvailable }
		let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
		guard let pngData = bitmapRep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else { throw CacheableElementError.noDataAvailable }
		return pngData
	}
	
	public static func from(data: Data) throws -> Self {
		if let image = Self.init(data: data) {
			return image
		} else {
			throw CacheableElementError.unableToInstantiateFromData
		}
	}
	
	static public var uttype: UTType { .png }
	public var cacheCost: UInt64 {
		let size = size
		return UInt64(size.width * size.height * 4)
	}
}



#endif
