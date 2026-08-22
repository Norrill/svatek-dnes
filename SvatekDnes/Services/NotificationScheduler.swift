import Foundation
import UserNotifications

/// Schedules local notifications for namedays and holidays.
/// iOS caps pending local notifications at 64, so we schedule a rolling
/// window and rebuild it on every app activation and background refresh.
@MainActor
final class NotificationScheduler {
	static let shared = NotificationScheduler()

	/// Rolling window length in days.
	private let horizonDays = 45
	/// Safety cap below the iOS limit of 64 pending notifications.
	private let maxScheduled = 60

	private init() {}

	@discardableResult
	func requestAuthorizationIfNeeded() async -> Bool {
		let center = UNUserNotificationCenter.current()
		let settings = await center.notificationSettings()
		switch settings.authorizationStatus {
		case .notDetermined:
			return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
		case .authorized, .provisional, .ephemeral:
			return true
		default:
			return false
		}
	}

	/// Rebuilds the whole rolling window of notifications.
	func rescheduleAll() async {
		let center = UNUserNotificationCenter.current()
		center.removeAllPendingNotificationRequests()

		let settings = AppSettings.shared
		guard settings.notifyContacts || settings.notifyHolidays || settings.notifyAllNamedays else {
			return
		}
		let status = await center.notificationSettings().authorizationStatus
		guard status == .authorized || status == .provisional || status == .ephemeral else {
			return
		}

		let calendar = Calendar.czech
		let now = Date()
		let contactsByDay = contactNamesByDay()
		var scheduled = 0

		for info in CalendarComposer.upcoming(days: horizonDays, from: now) {
			guard scheduled < maxScheduled else {
				break
			}
			let comps = calendar.dateComponents([.year, .month, .day], from: info.date)
			guard let month = comps.month, let day = comps.day else {
				continue
			}

			var lines: [String] = []
			var title: String?

			if settings.notifyContacts {
				let names = contactsByDay[WidgetSnapshot.key(month: month, day: day)] ?? []
				if !names.isEmpty {
					let verb = names.count == 1 ? "má" : "mají"
					title = "Dnes \(verb) svátek \(names.joinedCzech) 🎉"
				}
			}
			if settings.notifyHolidays, let holiday = info.primaryHoliday, holiday.isDayOff {
				let line = "\(holiday.shortName) – \(holiday.kindLabel)"
				if title == nil {
					title = "Dnes je \(holiday.shortName)"
					if holiday.name != holiday.shortName {
						lines.append(holiday.name)
					}
					lines.append(holiday.kindLabel.prefix(1).uppercased() + holiday.kindLabel.dropFirst())
				} else {
					lines.append(line)
				}
			}
			if settings.notifyAllNamedays, !info.entry.names.isEmpty {
				let text = "Svátek má \(info.entry.names.joinedCzech)"
				if title == nil {
					title = text
				} else if !(settings.notifyContacts && title?.contains(info.entry.names[0]) == true) {
					lines.append(text)
				}
			}

			guard let finalTitle = title else {
				continue
			}

			// The day's notification at the configured time.
			if let fireDate = fireDate(for: info.date, settings: settings), fireDate > now {
				schedule(
					center: center,
					identifier: "day-\(comps.year!)-\(month)-\(day)",
					title: finalTitle,
					body: lines.joined(separator: "\n"),
					fireDate: fireDate
				)
				scheduled += 1
			}

			// Optional evening-before reminder for contacts' namedays.
			if settings.notifyDayBefore, settings.notifyContacts, scheduled < maxScheduled {
				let names = contactsByDay[WidgetSnapshot.key(month: month, day: day)] ?? []
				if !names.isEmpty,
					let dayBefore = calendar.date(byAdding: .day, value: -1, to: info.date),
					let evening = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: dayBefore),
					evening > now {
					let verb = names.count == 1 ? "má" : "mají"
					schedule(
						center: center,
						identifier: "before-\(comps.year!)-\(month)-\(day)",
						title: "Zítra \(verb) svátek \(names.joinedCzech)",
						body: "Nezapomeňte popřát.",
						fireDate: evening
					)
					scheduled += 1
				}
			}
		}
	}

	/// Contact given names per "m-d" key, deduplicated. Falls back to the
	/// persisted widget snapshot when contacts have not been loaded in this
	/// process (background refresh in a cold-launched app).
	private func contactNamesByDay() -> [String: [String]] {
		var byDay: [String: [String]] = [:]
		let matched = ContactsService.shared.matched
		if matched.isEmpty {
			byDay = SnapshotStore.load()?.contactsByDay ?? [:]
		} else {
			for contact in matched {
				byDay[WidgetSnapshot.key(month: contact.month, day: contact.day), default: []].append(contact.givenName)
			}
		}
		return byDay.mapValues { names in
			var seen = Set<String>()
			return names.filter { !$0.isEmpty && seen.insert($0).inserted }
		}
	}

	private func fireDate(for day: Date, settings: AppSettings) -> Date? {
		Calendar.czech.date(
			bySettingHour: settings.notificationHour,
			minute: settings.notificationMinute,
			second: 0,
			of: day
		)
	}

	private func schedule(center: UNUserNotificationCenter, identifier: String, title: String, body: String, fireDate: Date) {
		let content = UNMutableNotificationContent()
		content.title = title
		if !body.isEmpty {
			content.body = body
		}
		content.sound = .default

		let comps = Calendar.czech.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
		let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
		center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
	}
}
