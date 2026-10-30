import SwiftUI

struct WatchDayRow: View {
	@EnvironmentObject private var store: WatchDataStore

	let day: DayInfo

	var body: some View {
		NavigationLink {
			WatchDayDetailView(day: day)
		} label: {
			VStack(alignment: .leading, spacing: 1) {
				HStack(spacing: 4) {
					Text(AppFormat.dayMonth(day.date))
						.font(.caption2)
						.foregroundStyle(day.isDayOff ? AnyShapeStyle(Color.brandRed) : AnyShapeStyle(.secondary))
					if let holiday = day.primaryHoliday {
						HolidayDot(isDayOff: holiday.isDayOff, size: 5)
					}
					Spacer(minLength: 0)
					if !store.contacts(for: day.date).isEmpty {
						Text(verbatim: "🎉")
							.font(.caption2)
							.accessibilityLabel("calendar_contact_marker_a11y")
					}
				}
				Text(day.entry.displayText.isEmpty ? String(localized: "nameday_none_inline") : day.entry.displayText)
					.font(.footnote)
					.lineLimit(2)
			}
			.padding(.vertical, 1)
		}
	}
}
