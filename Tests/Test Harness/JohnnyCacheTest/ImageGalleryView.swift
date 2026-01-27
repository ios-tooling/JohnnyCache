//
//  ImageGalleryView.swift
//  JohnnyCacheTest
//
//  Created by Claude on 1/26/26.
//

import SwiftUI

struct ImageGalleryView: View {
	@State private var cacheManager = ImageCacheManager.shared
	@State private var showingClearAlert = false
	@State private var showingClearCloudKitAlert = false
	@State private var showingClearAllAlert = false

	// Sample image URLs from Lorem Picsum
	let imageURLs: [URL] = [
		URL(string: "https://picsum.photos/id/237/400/400")!, // Dog
		URL(string: "https://picsum.photos/id/238/400/400")!, // Forest
		URL(string: "https://picsum.photos/id/239/400/400")!, // Road
		URL(string: "https://picsum.photos/id/240/400/400")!, // Water
		URL(string: "https://picsum.photos/id/241/400/400")!, // City
		URL(string: "https://picsum.photos/id/242/400/400")!, // Mountain
		URL(string: "https://picsum.photos/id/243/400/400")!, // Desert
		URL(string: "https://picsum.photos/id/244/400/400")!, // Beach
		URL(string: "https://picsum.photos/id/247/400/400")!, // Architecture
		URL(string: "https://picsum.photos/id/250/400/400")!, // Nature
		URL(string: "https://picsum.photos/id/251/400/400")!, // Buildings
		URL(string: "https://picsum.photos/id/252/400/400")!, // Landscape
	]

	let columns = [
		GridItem(.adaptive(minimum: 150), spacing: 16)
	]

	var body: some View {
		NavigationView {
			VStack(spacing: 0) {
				// Cache stats header
				cacheStatsView
					.padding()
					.background(Color(white: 0.95))

				Divider()

				// Image grid
				ScrollView {
					LazyVGrid(columns: columns, spacing: 16) {
						ForEach(imageURLs, id: \.self) { url in
							CachedImageView(url: url, size: 150)
						}
					}
					.padding()
				}
			}
			.navigationTitle("CloudKit Image Cache")
			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
					Menu {
						Button(role: .destructive) {
							showingClearAlert = true
						} label: {
							Label("Clear Memory & Disk", systemImage: "trash")
						}

						Divider()

						Button {
							cacheManager.clearCache(inMemory: true, onDisk: false)
						} label: {
							Label("Clear Memory Only", systemImage: "memorychip")
						}

						Button {
							cacheManager.clearCache(inMemory: false, onDisk: true)
						} label: {
							Label("Clear Disk Only", systemImage: "externaldrive")
						}

						Divider()

						Button(role: .destructive) {
							showingClearCloudKitAlert = true
						} label: {
							Label("Clear CloudKit Cache", systemImage: "icloud.slash")
						}

						Button(role: .destructive) {
							showingClearAllAlert = true
						} label: {
							Label("Clear All (Including CloudKit)", systemImage: "exclamationmark.triangle")
						}
					} label: {
						Image(systemName: "ellipsis.circle")
					}
				}
			}
			.alert("Clear Local Cache", isPresented: $showingClearAlert) {
				Button("Clear Memory & Disk", role: .destructive) {
					cacheManager.clearCache()
				}
				Button("Cancel", role: .cancel) {}
			} message: {
				Text("This will remove all cached images from memory and disk. CloudKit data will remain.")
			}
			.alert("Clear CloudKit Cache", isPresented: $showingClearCloudKitAlert) {
				Button("Clear CloudKit", role: .destructive) {
					Task {
						try? await cacheManager.clearCache(inMemory: false, onDisk: false, cloudKit: true)
					}
				}
				Button("Cancel", role: .cancel) {}
			} message: {
				Text("This will delete all cached images from CloudKit across all your devices. Local caches will remain.")
			}
			.alert("Clear All Caches", isPresented: $showingClearAllAlert) {
				Button("Clear Everything", role: .destructive) {
					Task {
						try? await cacheManager.clearCache(inMemory: true, onDisk: true, cloudKit: true)
					}
				}
				Button("Cancel", role: .cancel) {}
			} message: {
				Text("This will clear all cached images from memory, disk, AND CloudKit across all devices. This cannot be undone.")
			}
		}
	}

	private var cacheStatsView: some View {
		VStack(spacing: 8) {
			HStack(spacing: 20) {
				statItem(
					title: "Memory",
					value: cacheManager.cacheStats.formattedInMemory,
					color: .green,
					icon: "memorychip"
				)

				statItem(
					title: "Disk",
					value: cacheManager.cacheStats.formattedOnDisk,
					color: .blue,
					icon: "externaldrive"
				)
			}

			// Legend
			HStack(spacing: 16) {
				legendItem(icon: "checkmark.circle.fill", color: .green, text: "Cache")
				legendItem(icon: "icloud.fill", color: .blue, text: "CloudKit")
				legendItem(icon: "arrow.down.circle.fill", color: .orange, text: "Network")
			}
			.font(.caption)
			.foregroundStyle(.secondary)
		}
	}

	private func statItem(title: String, value: String, color: Color, icon: String) -> some View {
		VStack(spacing: 4) {
			HStack(spacing: 4) {
				Image(systemName: icon)
					.foregroundStyle(color)
				Text(title)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			Text(value)
				.font(.headline)
				.monospacedDigit()
		}
		.frame(maxWidth: .infinity)
	}

	private func legendItem(icon: String, color: Color, text: String) -> some View {
		HStack(spacing: 4) {
			Image(systemName: icon)
				.foregroundStyle(color)
				.font(.caption)
			Text(text)
		}
	}
}

#Preview {
	ImageGalleryView()
}
