//
//  File.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/7/26.
//

import Foundation

extension URL {
	var fileSize: UInt64 { FileManager.default.fileSize(at: self) }
	
	func setModificationDate(to date: Date = Date()) {
		FileManager.default.setModificationDate(at: self, to: date)
	}
}
