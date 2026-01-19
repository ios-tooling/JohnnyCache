//
//  Codable.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/19/26.
//

import Foundation
import UniformTypeIdentifiers

public extension Encodable {
	func toData() throws -> Data {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601

		return try encoder.encode(self)
	}

	var cacheCost: UInt64 {
		UInt64((try? toData())?.count ?? 0)
	}

	static var uttype: UTType { .json }
}

public extension Decodable {
	static func from(data: Data) throws -> Self {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601

		return try decoder.decode(Self.self, from: data)
	}
}
