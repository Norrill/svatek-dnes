import SwiftUI

@main
struct SvatekDnesApp: App {
	@Environment(\.scenePhase) private var scenePhase

	init() {
		AppBackgroundTasks.register()
	}

	var body: some Scene {
		WindowGroup {
			RootView()
		}
		.onChange(of: scenePhase) { _, phase in
			if phase == .active {
				Task {
					await AppRefresher.refresh()
				}
			}
		}
	}
}
