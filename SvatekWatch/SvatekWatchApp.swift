import SwiftUI

@main
struct SvatekWatchApp: App {
	@StateObject private var store = WatchDataStore.shared

	init() {
		WatchDataStore.shared.activate()
	}

	var body: some Scene {
		WindowGroup {
			WatchTodayView()
				.environmentObject(store)
		}
	}
}
