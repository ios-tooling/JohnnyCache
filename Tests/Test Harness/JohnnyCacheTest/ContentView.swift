//
//  ContentView.swift
//  JohnnyCacheTest
//
//  Created by Claude on 1/26/26.
//

import SwiftUI

struct ContentView: View {
	@State private var showingInfo = false

	var body: some View {
		TabView {
			ImageGalleryView()
				.tabItem {
					Label("Gallery", systemImage: "photo.on.rectangle.angled")
				}

			SettingsView()
				.tabItem {
					Label("Settings", systemImage: "gear")
				}
		}
		.sheet(isPresented: $showingInfo) {
			InfoView()
		}
		.onAppear {
			// Show info on first launch
			if UserDefaults.standard.bool(forKey: "hasSeenInfo") == false {
				showingInfo = true
				UserDefaults.standard.set(true, forKey: "hasSeenInfo")
			}
		}
	}
}

#Preview {
	ContentView()
}
