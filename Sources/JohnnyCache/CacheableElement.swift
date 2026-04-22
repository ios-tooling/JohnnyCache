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
	var cacheCost: UInt64 { get }
	var cacheCostDescription: String { get }
	
	static var uttype: UTType { get }
}

public extension CacheableElement {
	var cacheCostDescription: String {
		ByteCountFormatter().string(for: cacheCost) ?? "??"
	}
}

public enum CacheableElementError: Error {
	case noDataAvailable
	case unableToInstantiateFromData
}
