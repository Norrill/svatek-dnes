import Foundation
import BackgroundTasks
import WidgetKit

/// Monthly refresh of the remote holiday/nameday data via BGAppRefreshTask.
enum AppBackgroundTasks {
	static func register() {
		BGTaskScheduler.shared.register(forTaskWithIdentifier: AppGroup.refreshTaskIdentifier, using: nil) { task in
			guard let refreshTask = task as? BGAppRefreshTask else {
				task.setTaskCompleted(success: false)
				return
			}
			handle(refreshTask)
		}
	}

	static func schedule() {
		let request = BGAppRefreshTaskRequest(identifier: AppGroup.refreshTaskIdentifier)
		// The data changes at most monthly; a week is a comfortable cadence.
		request.earliestBeginDate = Date(timeIntervalSinceNow: 7 * 24 * 3600)
		try? BGTaskScheduler.shared.submit(request)
	}

	private static func handle(_ task: BGAppRefreshTask) {
		schedule()
		let work = Task {
			let updated = await HolidayUpdateService.shared.updateIfStale()

			// The task may run in a cold-launched process where contacts were
			// never loaded – load them first, otherwise rescheduleAll would
			// rebuild the notification window without any contact namedays.
			await ContactsService.shared.reloadIfAuthorized()
			await MainActor.run {
				let contacts = ContactsService.shared
				if contacts.isAuthorized && !contacts.matched.isEmpty {
					SnapshotStore.update(with: contacts.matched)
				}
			}

			guard !Task.isCancelled else {
				return
			}
			await NotificationScheduler.shared.rescheduleAll()
			if updated {
				WidgetCenter.shared.reloadAllTimelines()
			}
			guard !Task.isCancelled else {
				return
			}
			task.setTaskCompleted(success: true)
		}
		task.expirationHandler = {
			work.cancel()
			task.setTaskCompleted(success: false)
		}
	}
}
