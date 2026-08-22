import Foundation
import Combine

/// User preferences persisted in the shared app-group defaults.
final class AppSettings: ObservableObject {
	static let shared = AppSettings()

	private enum Key {
		static let notifyContacts = "notifyContacts"
		static let notifyHolidays = "notifyHolidays"
		static let notifyAllNamedays = "notifyAllNamedays"
		static let notifyDayBefore = "notifyDayBefore"
		static let notificationMinutes = "notificationMinutesFromMidnight"
		static let lastRemoteUpdate = "lastRemoteUpdate"
		static let lastRemoteAttempt = "lastRemoteAttempt"
	}

	private let defaults: UserDefaults

	@Published var notifyContacts: Bool {
		didSet { defaults.set(notifyContacts, forKey: Key.notifyContacts) }
	}
	@Published var notifyHolidays: Bool {
		didSet { defaults.set(notifyHolidays, forKey: Key.notifyHolidays) }
	}
	@Published var notifyAllNamedays: Bool {
		didSet { defaults.set(notifyAllNamedays, forKey: Key.notifyAllNamedays) }
	}
	@Published var notifyDayBefore: Bool {
		didSet { defaults.set(notifyDayBefore, forKey: Key.notifyDayBefore) }
	}
	/// Notification time as minutes from midnight, default 8:00.
	@Published var notificationMinutesFromMidnight: Int {
		didSet { defaults.set(notificationMinutesFromMidnight, forKey: Key.notificationMinutes) }
	}

	var notificationHour: Int { notificationMinutesFromMidnight / 60 }
	var notificationMinute: Int { notificationMinutesFromMidnight % 60 }

	var lastRemoteUpdate: Date? {
		get { defaults.object(forKey: Key.lastRemoteUpdate) as? Date }
		set { defaults.set(newValue, forKey: Key.lastRemoteUpdate) }
	}

	var lastRemoteAttempt: Date? {
		get { defaults.object(forKey: Key.lastRemoteAttempt) as? Date }
		set { defaults.set(newValue, forKey: Key.lastRemoteAttempt) }
	}

	private init(defaults: UserDefaults = AppGroup.defaults) {
		self.defaults = defaults
		defaults.register(defaults: [
			Key.notifyContacts: true,
			Key.notifyHolidays: true,
			Key.notifyAllNamedays: false,
			Key.notifyDayBefore: false,
			Key.notificationMinutes: 8 * 60,
		])
		notifyContacts = defaults.bool(forKey: Key.notifyContacts)
		notifyHolidays = defaults.bool(forKey: Key.notifyHolidays)
		notifyAllNamedays = defaults.bool(forKey: Key.notifyAllNamedays)
		notifyDayBefore = defaults.bool(forKey: Key.notifyDayBefore)
		notificationMinutesFromMidnight = defaults.integer(forKey: Key.notificationMinutes)
	}
}
