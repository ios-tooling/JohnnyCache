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

				Section("Cache Management") {
					Button("Clear Memory Cache") {
						cacheManager.clearCache(inMemory: true, onDisk: false)
					}

					Button("Clear Disk Cache") {
						cacheManager.clearCache(inMemory: false, onDisk: true)
					}

					Button("Clear All Caches", role: .destructive) {
						cacheManager.clearCache()
					}
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
}

#Preview {
	SettingsView()
}
