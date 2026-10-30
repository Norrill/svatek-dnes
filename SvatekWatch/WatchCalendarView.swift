import SwiftUI

/// A year of namedays starting today, scrolled with the Digital Crown.
/// A `List` on watchOS is crown-scrollable without any extra work.
struct WatchCalendarView: View {
	/// A full year ahead – enough to reach any nameday from today.
	private static let dayCount = 365

	private let days: [DayInfo] = CalendarComposer.upcoming(days: dayCount)

	var body: some View {
		List(days) { day in
			WatchDayRow(day: day)
		}
		.navigationTitle("calendar_title")
	}
}
