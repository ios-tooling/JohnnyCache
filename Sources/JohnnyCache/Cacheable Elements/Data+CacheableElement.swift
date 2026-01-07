//
//  Data+CacheableItem.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//

import Foundation
import UniformTypeIdentifiers

extension Data: CacheableElement {
	public func toData() throws -> Data { self }
	
	public static func from(data: Data) throws -> Self {
		data
	}
	
	static public var uttype: UTType { .data }
	public var cacheCost: UInt64 { UInt64(count) }
}
