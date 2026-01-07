//
//  UIImage+CacheableElement.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//


#if canImport(UIKit)

import UIKit
import UniformTypeIdentifiers

extension UIImage: CacheableElement {
	public func toData() throws -> Data {
		guard let data = pngData() else { throw CacheableElementError.noDataAvailable }
		return data
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
		return UInt64(size.width * size.height * 4) * UInt64(scale * scale)
	}
}



#endif
