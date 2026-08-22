import Foundation

/// Everything the UI needs to render one day.
struct DayInfo: Identifiable {
	let date: Date
	let entry: NamedayEntry
	let holidays: [Holiday]

	var id: Date { date }

	var isDayOff: Bool {
		holidays.contains { $0.isDayOff }
	}

	/// The most important holiday of the day (days off win over significant days).
	var primaryHoliday: Holiday? {
		holidays.first { $0.isDayOff } ?? holidays.first
	}
}

enum CalendarComposer {
	static func info(for date: Date) -> DayInfo {
		DayInfo(
			date: date,
			entry: NamedayStore.shared.entry(for: date),
			holidays: HolidayCalendar.holidays(for: date)
		)
	}

	/// Day infos for `days` consecutive days starting at `from`'s day.
	static func upcoming(days: Int, from: Date = Date()) -> [DayInfo] {
		let calendar = Calendar.czech
		let start = calendar.startOfDay(for: from)
		return (0..<days).compactMap { offset in
			guard let date = calendar.date(byAdding: .day, value: offset, to: start) else {
				return nil
			}
			return info(for: date)
		}
	}
}
