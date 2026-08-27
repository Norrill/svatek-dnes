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
					// Deliberately outside AppRefresher: that one debounces,
					// and granting access in Settings has to show up the
					// moment the user comes back.
					await ContactsService.shared.refreshAuthorization()
					await AppRefresher.refresh()
				}
			}
		}
	}
}
