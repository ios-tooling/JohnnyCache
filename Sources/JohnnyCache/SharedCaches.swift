//
//  SharedCaches.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/8/26.
//

#if canImport(UIKit)
import UIKit
@MainActor public var sharedImagesCache = JohnnyCache<URL, UIImage>(configuration: .init(name: "images"))
#endif


#if canImport(Cocoa)
import Cocoa
@MainActor public var sharedImagesCache = JohnnyCache<URL, NSImage>(configuration: .init(name: "images"))
#endif


