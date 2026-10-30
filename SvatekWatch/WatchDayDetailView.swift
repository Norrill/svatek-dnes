import SwiftUI

/// One day in full: every calendar name, the variants used for matching,
/// holidays and the contacts celebrating that day.
struct WatchDayDetailView: View {
	@EnvironmentObject private var store: WatchDataStore

	let day: DayInfo

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 10) {
				Text(day.entry.displayText.isEmpty ? String(localized: "nameday_none") : day.entry.displayText)
					.font(.headline)
					.foregroundStyle(day.entry.displayText.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.brandGreen))
					.minimumScaleFactor(0.7)

				if let variants = day.entry.variantsText {
					Text(variants)
						.font(.caption2)
						.foregroundStyle(.secondary)
				}

				ForEach(day.holidays) { holiday in
					HStack(alignment: .firstTextBaseline, spacing: 6) {
						HolidayDot(isDayOff: holiday.isDayOff)
						VStack(alignment: .leading, spacing: 1) {
							Text(holiday.name)
								.font(.footnote)
							Text(holiday.kindLabel)
								.font(.caption2)
								.foregroundStyle(.secondary)
						}
					}
				}

				contactsSection
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(.horizontal, 4)
			.padding(.bottom, 8)
		}
		.navigationTitle(AppFormat.dayMonth(day.date))
	}

	@ViewBuilder
	private var contactsSection: some View {
		let names = store.contacts(for: day.date)
		if !names.isEmpty {
			VStack(alignment: .leading, spacing: 2) {
				Text("today_contacts_section")
					.font(.caption2)
					.foregroundStyle(.secondary)
				Text(names.joinedNames)
					.font(.footnote)
					.fontWeight(.medium)
			}
		}
	}
}
