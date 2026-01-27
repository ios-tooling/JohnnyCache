//
//  InfoView.swift
//  JohnnyCacheTest
//
//  Created by Claude on 1/26/26.
//

import SwiftUI

struct InfoView: View {
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationView {
			ScrollView {
				VStack(alignment: .leading, spacing: 20) {
					headerSection

					howItWorksSection

					cacheIndicatorsSection

					cloudKitInfoSection

					tipsSection
				}
				.padding()
			}
			.navigationTitle("About This Demo")
			.toolbar {
				ToolbarItem(placement: .primaryAction) {
					Button("Done") {
						dismiss()
					}
				}
			}
		}
	}

	private var headerSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			Image(systemName: "icloud.and.arrow.down")
				.font(.system(size: 50))
				.foregroundStyle(.blue)

			Text("JohnnyCache + CloudKit Demo")
				.font(.title2)
				.fontWeight(.bold)

			Text("This app demonstrates JohnnyCache's CloudKit integration for caching images across devices.")
				.font(.body)
				.foregroundStyle(.secondary)
		}
	}

	private var howItWorksSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			sectionHeader("How It Works")

			featureRow(
				icon: "1.circle.fill",
				color: .green,
				title: "Memory Cache",
				description: "Images are first stored in memory for instant access"
			)

			featureRow(
				icon: "2.circle.fill",
				color: .blue,
				title: "Disk Cache",
				description: "Images persist to disk for faster loading across app launches"
			)

			featureRow(
				icon: "3.circle.fill",
				color: .purple,
				title: "CloudKit Sync",
				description: "Images are backed up to CloudKit and sync across your devices"
			)

			featureRow(
				icon: "4.circle.fill",
				color: .orange,
				title: "Network Fallback",
				description: "If not cached, images are downloaded from the network"
			)
		}
	}

	private var cacheIndicatorsSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			sectionHeader("Cache Indicators")

			Text("Each image shows where it was loaded from:")
				.font(.subheadline)
				.foregroundStyle(.secondary)

			HStack(spacing: 20) {
				indicatorExample(icon: "checkmark.circle.fill", color: .green, label: "Memory/Disk")
				indicatorExample(icon: "icloud.fill", color: .blue, label: "CloudKit")
				indicatorExample(icon: "arrow.down.circle.fill", color: .orange, label: "Network")
			}
		}
	}

	private var cloudKitInfoSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			sectionHeader("CloudKit Features")

			infoRow(
				icon: "doc.on.doc",
				title: "Smart Storage",
				description: "Small images (<50KB) stored directly, larger images use CKAsset"
			)

			infoRow(
				icon: "arrow.triangle.2.circlepath",
				title: "Automatic Sync",
				description: "Images sync across all your devices signed into iCloud"
			)

			infoRow(
				icon: "shield",
				title: "Cache Stampede Prevention",
				description: "Multiple requests for the same image trigger only one download"
			)

			infoRow(
				icon: "chart.bar",
				title: "Size Limits",
				description: "Memory: 50MB, Disk: 200MB with automatic LRU eviction"
			)
		}
	}

	private var tipsSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			sectionHeader("Tips")

			tipRow("Force quit and relaunch the app to see disk cache persistence")
			tipRow("Clear caches from Settings to test different loading scenarios")
			tipRow("Watch the colored indicators to see cache behavior in real-time")
			tipRow("Check Settings tab for CloudKit account status")
		}
	}

	private func sectionHeader(_ title: String) -> some View {
		Text(title)
			.font(.headline)
			.fontWeight(.semibold)
	}

	private func featureRow(icon: String, color: Color, title: String, description: String) -> some View {
		HStack(alignment: .top, spacing: 12) {
			Image(systemName: icon)
				.font(.title2)
				.foregroundStyle(color)
				.frame(width: 30)

			VStack(alignment: .leading, spacing: 4) {
				Text(title)
					.font(.subheadline)
					.fontWeight(.medium)
				Text(description)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
	}

	private func indicatorExample(icon: String, color: Color, label: String) -> some View {
		VStack(spacing: 4) {
			Image(systemName: icon)
				.foregroundStyle(color)
				.font(.title2)
			Text(label)
				.font(.caption2)
				.foregroundStyle(.secondary)
		}
	}

	private func infoRow(icon: String, title: String, description: String) -> some View {
		HStack(alignment: .top, spacing: 12) {
			Image(systemName: icon)
				.foregroundStyle(.blue)
				.frame(width: 24)

			VStack(alignment: .leading, spacing: 2) {
				Text(title)
					.font(.subheadline)
					.fontWeight(.medium)
				Text(description)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
	}

	private func tipRow(_ text: String) -> some View {
		HStack(alignment: .top, spacing: 8) {
			Text("•")
				.fontWeight(.bold)
			Text(text)
				.font(.subheadline)
				.foregroundStyle(.secondary)
		}
	}
}

#Preview {
	InfoView()
}
