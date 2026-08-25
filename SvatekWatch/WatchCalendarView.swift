import SwiftUI

/// A year of namedays starting today, scrolled with the Digital Crown.
/// A `List` on watchOS is crown-scrollable without any extra work.
struct WatchCalendarView: View {
	@EnvironmentObject private var store: WatchDataStore

	/// A full year ahead – enough to reach any nameday from today.
	private static let dayCount = 365

	private let days: [DayInfo] = CalendarComposer.upcoming(days: dayCount)

	var body: some View {
		List(days) { day in
			NavigationLink {
				WatchDayDetailView(day: day)
			} label: {
				row(for: day)
			}
		}
		.navigationTitle("calendar_title")
	}

	private func row(for day: DayInfo) -> some View {
		VStack(alignment: .leading, spacing: 1) {
			HStack(spacing: 4) {
				Text(AppFormat.dayMonth(day.date))
					.font(.caption2)
					.foregroundStyle(day.isDayOff ? AnyShapeStyle(Color.brandRed) : AnyShapeStyle(.secondary))
				if let holiday = day.primaryHoliday {
					HolidayDot(isDayOff: holiday.isDayOff, size: 5)
				}
				Spacer(minLength: 0)
			}
			Text(day.entry.displayText.isEmpty ? String(localized: "nameday_none_inline") : day.entry.displayText)
				.font(.footnote)
				.lineLimit(2)
			contactLine(for: day)
		}
		.padding(.vertical, 1)
	}

	@ViewBuilder
	private func contactLine(for day: DayInfo) -> some View {
		let names = store.contacts(for: day.date)
		if !names.isEmpty {
			Text(names.joinedNames)
				.font(.caption2)
				.foregroundStyle(Color.brandGreen)
				.lineLimit(1)
		}
	}
}
