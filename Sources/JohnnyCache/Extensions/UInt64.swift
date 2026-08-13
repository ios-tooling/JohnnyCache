//
//  UInt64.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 8/12/26.
//

import Foundation

extension UInt64 {
	/// Cost ledgers can trail what's actually on disk — two caches sharing a
	/// directory, or a clear racing a write — so subtraction floors at zero
	/// instead of trapping on overflow.
	mutating func subtract(clamping amount: UInt64) {
		self = self >= amount ? self - amount : 0
	}
}
