//
//  CachedImageView.swift
//  JohnnyCacheTest
//
//  Created by Claude on 1/26/26.
//

import SwiftUI

struct CachedImageView: View {
	let url: URL
	let size: CGFloat

	@State private var imageData: Data?
	@State private var isLoading = false
	@State private var error: Error?
	@State private var loadSource: LoadSource = .notLoaded

	enum LoadSource {
		case notLoaded
		case cache
		case cloudKit
		case network

		var color: Color {
			switch self {
			case .notLoaded: return .gray
			case .cache: return .green
			case .cloudKit: return .blue
			case .network: return .orange
			}
		}

		var icon: String {
			switch self {
			case .notLoaded: return "circle"
			case .cache: return "checkmark.circle.fill"
			case .cloudKit: return "icloud.fill"
			case .network: return "arrow.down.circle.fill"
			}
		}
	}

	var body: some View {
		ZStack {
			if let imageData {
				imageView(for: imageData)
			} else if isLoading {
				ProgressView()
					.frame(width: size, height: size)
			} else {
				Color.gray.opacity(0.3)
					.frame(width: size, height: size)
			}

			// Status indicator
			VStack {
				HStack {
					Spacer()
					Image(systemName: loadSource.icon)
						.foregroundStyle(loadSource.color)
						.padding(4)
						.background(Color.white.opacity(0.8))
						.clipShape(Circle())
						.padding(4)
				}
				Spacer()
			}
		}
		.frame(width: size, height: size)
		.cornerRadius(8)
		.task {
			await loadImage()
		}
	}

	@ViewBuilder
	private func imageView(for data: Data) -> some View {
		#if canImport(UIKit)
		if let uiImage = UIImage(data: data) {
			Image(uiImage: uiImage)
				.resizable()
				.aspectRatio(contentMode: .fill)
				.frame(width: size, height: size)
				.clipped()
		}
		#else
		if let nsImage = NSImage(data: data) {
			Image(nsImage: nsImage)
				.resizable()
				.aspectRatio(contentMode: .fill)
				.frame(width: size, height: size)
				.clipped()
		}
		#endif
	}

	private func loadImage() async {
		isLoading = true

		do {
			// First check if it's already in cache (sync)
			if let cachedData = ImageCacheManager.shared.cachedImage(for: url) {
				imageData = cachedData
				loadSource = .cache
				print("💚 Loaded from cache: \(url.lastPathComponent)")
				isLoading = false
				return
			}

			// Not in local cache, try async fetch (will check CloudKit then network)
			print("🔍 Cache miss for: \(url.lastPathComponent)")
			if let data = try await ImageCacheManager.shared.fetchImage(from: url) {
				imageData = data
				// We can't easily tell if it came from CloudKit or network,
				// but for demo purposes, assume network after cache miss
				loadSource = .network
				isLoading = false
			}
		} catch {
			self.error = error
			print("❌ Error loading image: \(error)")
			isLoading = false
		}
	}
}
