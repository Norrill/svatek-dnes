import Combine
import Foundation
import WatchConnectivity

/// A future day on which at least one contact has their nameday.
struct UpcomingContactDay: Identifiable {
	let date: Date
	let month: Int
	let day: Int
	let names: [String]

	var id: Date { date }
}

/// Holds what the iPhone has pushed over.
///
/// The nameday calendar, the holidays and the Easter computus all ship with
/// the watch app, so everything except contact names works with the phone
/// switched off or out of range. Contacts have to arrive from the phone:
/// the Contacts framework does not exist on watchOS.
final class WatchDataStore: NSObject, ObservableObject {
	static let shared = WatchDataStore()

	/// Contact matches last received from the phone, if any.
	@Published private(set) var snapshot: WidgetSnapshot?

	private override init() {
		snapshot = SnapshotStore.load()
		super.init()
	}

	func activate() {
		guard WCSession.isSupported() else {
			return
		}
		let session = WCSession.default
		session.delegate = self
		session.activate()
	}

	/// Given names of contacts having their nameday on `date`.
	func contacts(for date: Date) -> [String] {
		let components = Calendar.czech.dateComponents([.month, .day], from: date)
		guard let month = components.month, let day = components.day else {
			return []
		}
		return snapshot?.contacts(month: month, day: day) ?? []
	}

	/// The next days on which one of your contacts celebrates.
	/// Starts tomorrow – today has its own section on the watch face.
	func upcomingContacts(limit: Int = 4, from: Date = Date()) -> [UpcomingContactDay] {
		guard let snapshot, !snapshot.contactsByDay.isEmpty else {
			return []
		}
		let calendar = Calendar.czech
		let start = calendar.startOfDay(for: from)
		var result: [UpcomingContactDay] = []
		for offset in 1...365 {
			guard let date = calendar.date(byAdding: .day, value: offset, to: start) else {
				continue
			}
			let components = calendar.dateComponents([.month, .day], from: date)
			guard let month = components.month, let day = components.day else {
				continue
			}
			let names = snapshot.contacts(month: month, day: day)
			guard !names.isEmpty else {
				continue
			}
			result.append(UpcomingContactDay(date: date, month: month, day: day, names: names))
			if result.count >= limit {
				break
			}
		}
		return result
	}

	private func apply(_ context: [String: Any]) {
		guard !context.isEmpty else {
			return
		}
		DispatchQueue.main.async {
			// Holiday overrides first – they change what the calendar
			// renders, and the snapshot below only adds names on top.
			if let remote = context["remoteData"] as? Data {
				HolidayUpdateService.shared.adopt(remote)
			}
			if let data = context["snapshot"] as? Data,
				let decoded = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) {
				SnapshotStore.save(decoded)
				self.snapshot = decoded
			}
			// Redraw even when only the overrides changed.
			self.objectWillChange.send()
		}
	}
}

extension WatchDataStore: WCSessionDelegate {
	func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
		guard activationState == .activated else {
			return
		}
		// Whatever the phone sent while the watch app was not running is
		// waiting here – there is no separate delivery callback for it.
		apply(session.receivedApplicationContext)
	}

	func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
		apply(applicationContext)
	}
}
