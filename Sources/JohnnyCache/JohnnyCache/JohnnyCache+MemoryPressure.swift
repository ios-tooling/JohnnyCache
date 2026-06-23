//
//  JohnnyCache+MemoryPressure.swift
//  JohnnyCache
//
//  Created by Ben Gottlieb on 6/23/26.
//

import Foundation

extension JohnnyCache {
	/// Begins watching for system memory-pressure events, purging the
	/// in-memory cache before the OS resorts to terminating the process.
	func startMonitoringMemoryPressure() {
		let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
		source.setEventHandler { [weak self] in
			guard let self else { return }
			let event = source.data
			MainActor.assumeIsolated { self.handleMemoryPressure(event) }
		}
		source.activate()
		memoryPressureSource = source
	}

	func stopMonitoringMemoryPressure() {
		memoryPressureSource?.cancel()
		memoryPressureSource = nil
	}

	/// Critical pressure drops the entire in-memory cache; a warning trims it
	/// to half the configured limit. On-disk and CloudKit tiers are untouched.
	func handleMemoryPressure(_ event: DispatchSource.MemoryPressureEvent) {
		if event.contains(.critical) {
			clearInMemory()
		} else if event.contains(.warning) {
			purgeInMemory(downTo: configuration.inMemoryLimit / 2)
		}
	}
}
