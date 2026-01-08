//
//  SharedCaches.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/8/26.
//

#if canImport(UIKit)
import UIKit
@MainActor public var sharedImagesCache = JohnnyCache<URL, UIImage>(configuration: .init(name: "images")) { url in
	let (data, response) = try await URLSession.shared.data(from: url)
	return UIImage(data: data)
}
#endif


#if canImport(Cocoa)
import Cocoa
@MainActor public var sharedImagesCache = JohnnyCache<URL, NSImage>(configuration: .init(name: "images")) { url in
	let (data, response) = try await URLSession.shared.data(from: url)
	return NSImage(data: data)
}
#endif


