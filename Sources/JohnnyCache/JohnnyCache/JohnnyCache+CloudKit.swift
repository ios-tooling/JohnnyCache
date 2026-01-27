//
//  File.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 1/26/26.
//

import Foundation

extension JohnnyCache {
	func setupCloudKit() {
		Task { await checkAccountStatus() }
	}
	
	public func checkAccountStatus() async {
		guard let container = configuration.cloudKitInfo?.container else { return }
		do {
			let accountStatus = try await container.accountStatus()
			
			switch accountStatus {
			case .available, .restricted:
				isSignedInToCloudKit = true
			@unknown default: break
			}
		} catch {
			print("Failed to check CloudKit account status: \(error)")
		}
	}

}
