//
//  CacheableElement.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//

import Foundation
import UniformTypeIdentifiers

public protocol CacheableElement: Sendable {
	func toData() throws -> Data
	static func from(data: Data) throws -> Self
	
	static var uttype: UTType { get }
}

public enum CacheableElementError: Error {
	case noDataAvailable
	case unableToInstantiateFromData
}
