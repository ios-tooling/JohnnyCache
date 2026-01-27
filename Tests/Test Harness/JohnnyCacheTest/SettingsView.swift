//
//  SettingsView.swift
//  JohnnyCacheTest
//
//  Created by Claude on 1/26/26.
//

import SwiftUI
import CloudKit

struct SettingsView: View {
	@State private var cacheManager = ImageCacheManager.shared
	@State private var cloudKitStatus: CKAccountStatus?
	@State private var isCheckingCloudKit = false
	@State private var isClearingCloudKit = false
	@State private var showingClearCloudKitAlert = false
	@State private var showingClearAllAlert = false

	var body: some View {
		NavigationView {
			Form {
				Section("Cache Information") {
					LabeledContent("Memory Usage", value: cacheManager.cacheStats.formattedInMemory)
					LabeledContent("Disk Usage", value: cacheManager.cacheStats.formattedOnDisk)

					Button("Refresh Stats") {
						cacheManager.updateStats()
					}
				}

				Section("CloudKit Status") {
					if isCheckingCloudKit {
						HStack {
							ProgressView()
							Text("Checking CloudKit...")
						}
					} else if let status = cloudKitStatus {
						LabeledContent("Account Status", value: statusString(for: status))
							.foregroundStyle(statusColor(for: status))
					}

					Button("Check CloudKit Status") {
						Task {
							await checkCloudKitStatus()
						}
					}
				}

				Section("Local Cache Management") {
					Button("Clear Memory Cache") {
						cacheManager.clearCache(inMemory: true, onDisk: false)
					}

					Button("Clear Disk Cache") {
						cacheManager.clearCache(inMemory: false, onDisk: true)
					}

					Button("Clear Memory & Disk", role: .destructive) {
						cacheManager.clearCache()
					}
				}

				Section(header: Text("CloudKit Cache Management"), footer: Text("CloudKit cache is shared across all your devices. Clearing it will affect all devices signed into your iCloud account.")) {

					if isClearingCloudKit {
						HStack {
							ProgressView()
							Text("Clearing CloudKit cache...")
						}
					}

					Button("Clear CloudKit Cache Only", role: .destructive) {
						showingClearCloudKitAlert = true
					}
					.disabled(isClearingCloudKit)

					Button("Clear All Caches (Including CloudKit)", role: .destructive) {
						showingClearAllAlert = true
					}
					.disabled(isClearingCloudKit)
				}

				Section("About") {
					LabeledContent("CloudKit Container", value: "iCloud.con.standalone.cloudkittesting")
						.font(.caption)

					LabeledContent("Asset Threshold", value: "50 KB")
						.font(.caption)

					LabeledContent("Memory Limit", value: "50 MB")
						.font(.caption)

					LabeledContent("Disk Limit", value: "200 MB")
						.font(.caption)
				}
			}
			.navigationTitle("Settings")
			.task {
				await checkCloudKitStatus()
			}
			.alert("Clear CloudKit Cache", isPresented: $showingClearCloudKitAlert) {
				Button("Clear CloudKit", role: .destructive) {
					Task {
						await clearCloudKit()
					}
				}
				Button("Cancel", role: .cancel) {}
			} message: {
				Text("This will delete all cached images from CloudKit across all your devices. Local caches will remain.")
			}
			.alert("Clear All Caches", isPresented: $showingClearAllAlert) {
				Button("Clear Everything", role: .destructive) {
					Task {
						await clearAllCaches()
					}
				}
				Button("Cancel", role: .cancel) {}
			} message: {
				Text("This will clear all cached images from memory, disk, AND CloudKit across all devices.")
			}
		}
	}

	private func checkCloudKitStatus() async {
		isCheckingCloudKit = true
		do {
			let container = CKContainer(identifier: "iCloud.con.standalone.cloudkittesting")
			let status = try await container.accountStatus()
			cloudKitStatus = status
		} catch {
			print("Error checking CloudKit status: \(error)")
		}
		isCheckingCloudKit = false
	}

	private func statusString(for status: CKAccountStatus) -> String {
		switch status {
		case .available:
			return "Available ✓"
		case .noAccount:
			return "No Account"
		case .restricted:
			return "Restricted"
		case .couldNotDetermine:
			return "Unknown"
		case .temporarilyUnavailable:
			return "Temporarily Unavailable"
		@unknown default:
			return "Unknown"
		}
	}

	private func statusColor(for status: CKAccountStatus) -> Color {
		switch status {
		case .available:
			return .green
		case .noAccount, .restricted:
			return .red
		default:
			return .orange
		}
	}

	private func clearCloudKit() async {
		isClearingCloudKit = true
		do {
			try await cacheManager.clearCache(inMemory: false, onDisk: false, cloudKit: true)
			print("✅ CloudKit cache cleared successfully")
		} catch {
			print("❌ Error clearing CloudKit cache: \(error)")
		}
		isClearingCloudKit = false
	}

	private func clearAllCaches() async {
		isClearingCloudKit = true
		do {
			try await cacheManager.clearCache(inMemory: true, onDisk: true, cloudKit: true)
			print("✅ All caches cleared successfully")
		} catch {
			print("❌ Error clearing caches: \(error)")
		}
		isClearingCloudKit = false
	}
}

#Preview {
	SettingsView()
}
