import Foundation
import WidgetKit

/// One place that brings everything up to date when the app becomes active.
@MainActor
enum AppRefresher {
	private static var lastRun: Date?

	static func refresh() async {
		// Debounce: scenePhase can fire several times in a row.
		if let last = lastRun, Date().timeIntervalSince(last) < 30 {
			return
		}
		lastRun = Date()

		_ = await HolidayUpdateService.shared.updateIfStale()
		await ContactsService.shared.reloadIfAuthorized()
		SnapshotStore.update(with: ContactsService.shared.matched)
		await NotificationScheduler.shared.requestAuthorizationIfNeeded()
		await NotificationScheduler.shared.rescheduleAll()
		WidgetCenter.shared.reloadAllTimelines()
		AppBackgroundTasks.schedule()
	}

	/// Lightweight refresh after the user changed a manual assignment –
	/// no remote fetch, no debounce.
	static func contactsChanged() async {
		await ContactsService.shared.reloadIfAuthorized()
		SnapshotStore.update(with: ContactsService.shared.matched)
		await NotificationScheduler.shared.rescheduleAll()
		WidgetCenter.shared.reloadAllTimelines()
	}
}
