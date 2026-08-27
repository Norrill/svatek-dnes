import Foundation
import WidgetKit

/// One place that brings everything up to date when the app becomes active.
@MainActor
enum AppRefresher {
	private static var lastRun: Date?
	private static var storeChangeTask: Task<Void, Never>?

	static func refresh() async {
		// Re-reading the address book is the cheap part and must not lag
		// behind what the user just did in the Contacts app – adding a
		// contact and coming straight back fits inside the debounce below.
		let contactsDidChange = await ContactsService.shared.reloadIfAuthorized()

		// Debounce: scenePhase can fire several times in a row.
		if let last = lastRun, Date().timeIntervalSince(last) < 30 {
			if contactsDidChange {
				await propagateContacts()
			}
			return
		}
		lastRun = Date()

		_ = await HolidayUpdateService.shared.updateIfStale()
		await NotificationScheduler.shared.requestAuthorizationIfNeeded()
		await propagateContacts()
		AppBackgroundTasks.schedule()
	}

	/// Lightweight refresh after the user changed a manual assignment –
	/// no remote fetch, no debounce.
	static func contactsChanged() async {
		guard await ContactsService.shared.reloadIfAuthorized() else {
			return
		}
		await propagateContacts()
	}

	/// `CNContactStoreDidChange` arrives several times for a single edit,
	/// so let the burst settle before walking the address book again.
	static func contactStoreChanged() {
		storeChangeTask?.cancel()
		storeChangeTask = Task {
			try? await Task.sleep(for: .milliseconds(500))
			guard !Task.isCancelled else {
				return
			}
			await contactsChanged()
		}
	}

	/// Everything downstream of the matched contacts.
	private static func propagateContacts() async {
		SnapshotStore.update(with: ContactsService.shared.matched)
		await NotificationScheduler.shared.rescheduleAll()
		WidgetCenter.shared.reloadAllTimelines()
	}
}
