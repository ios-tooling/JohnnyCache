//
//  CacheableKey.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//

import Foundation

public protocol CacheableKey: Hashable, Sendable {
	var stringRepresentation: String { get }
}

extension String: CacheableKey {
	public var stringRepresentation: String { self }
}

extension URL: CacheableKey {
	public var stringRepresentation: String {
		if #available(iOS 16.0, *) {
			(host(percentEncoded: false) ?? "") + "/" + path
		} else {
			(host ?? "") + "/" + path
		}
	}
}
