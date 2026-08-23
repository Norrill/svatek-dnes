import Foundation
import EventKit

/// Adds nameday/holiday events to the user's calendar (write-only access).
@MainActor
final class CalendarExporter {
	static let shared = CalendarExporter()

	enum ExportError: LocalizedError {
		case denied
		case saveFailed

		var errorDescription: String? {
			switch self {
			case .denied:
				return String(localized: "Aplikace nemá přístup ke kalendáři. Povolte jej v Nastavení.")
			case .saveFailed:
				return String(localized: "Událost se nepodařilo uložit.")
			}
		}
	}

	private let store = EKEventStore()

	private init() {}

	/// Creates an all-day event on the given date. Repeats yearly when requested.
	func addAllDayEvent(title: String, date: Date, yearly: Bool = false, notes: String? = nil) async throws {
		let granted = (try? await store.requestWriteOnlyAccessToEvents()) ?? false
		guard granted else {
			throw ExportError.denied
		}

		let event = EKEvent(eventStore: store)
		event.title = title
		event.isAllDay = true
		event.startDate = Calendar.current.startOfDay(for: date)
		event.endDate = event.startDate
		event.notes = notes
		event.availability = .free
		event.calendar = store.defaultCalendarForNewEvents
		if yearly {
			event.recurrenceRules = [
				EKRecurrenceRule(recurrenceWith: .yearly, interval: 1, end: nil)
			]
		}

		do {
			try store.save(event, span: .thisEvent, commit: true)
		} catch {
			throw ExportError.saveFailed
		}
	}
}
