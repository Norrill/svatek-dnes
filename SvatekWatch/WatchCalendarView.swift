import SwiftUI

/// A year of namedays starting today, scrolled with the Digital Crown, with
/// a name search on top. A `List` on watchOS is crown-scrollable without any
/// extra work.
struct WatchCalendarView: View {
	@EnvironmentObject private var store: WatchDataStore

	@State private var query = ""

	/// A full year ahead – enough to reach any nameday from today.
	private static let dayCount = 365

	private let days: [DayInfo] = CalendarComposer.upcoming(days: dayCount)

	/// Fold first: a query of only diacritics or spaces is not a search.
	private var isSearching: Bool {
		!NameMatching.fold(query).isEmpty
	}

	var body: some View {
		List {
			if isSearching {
				searchResults
			} else {
				ForEach(days) { day in
					NavigationLink {
						WatchDayDetailView(day: day)
					} label: {
						row(for: day)
					}
				}
			}
		}
		.searchable(text: $query, prompt: "search_name_prompt")
		.navigationTitle("calendar_title")
	}

	// MARK: - Browsing

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
			contactLine(for: day.date)
		}
		.padding(.vertical, 1)
	}

	@ViewBuilder
	private func contactLine(for date: Date) -> some View {
		let names = store.contacts(for: date)
		if !names.isEmpty {
			Text(names.joinedNames)
				.font(.caption2)
				.foregroundStyle(Color.brandGreen)
				.lineLimit(1)
		}
	}

	// MARK: - Search

	@ViewBuilder
	private var searchResults: some View {
		let results = NamedayStore.shared.search(query)
		if results.isEmpty {
			Label("search_empty_title", systemImage: "magnifyingglass")
				.font(.footnote)
				.foregroundStyle(.secondary)
		} else {
			ForEach(results, id: \.self) { entry in
				searchRow(entry)
			}
		}
	}

	/// Search hits are shown at their *next* occurrence, so tapping one lands
	/// on a real day – including 29 February, which rolls to the next leap year.
	@ViewBuilder
	private func searchRow(_ entry: NamedayEntry) -> some View {
		if let date = NamedayStore.shared.nextDate(month: entry.m, day: entry.d, onOrAfter: Date()) {
			NavigationLink {
				WatchDayDetailView(day: CalendarComposer.info(for: date))
			} label: {
				VStack(alignment: .leading, spacing: 1) {
					Text(entry.displayText)
						.font(.footnote)
						.lineLimit(2)
					Text(AppFormat.dayMonth(date))
						.font(.caption2)
						.foregroundStyle(.secondary)
					contactLine(for: date)
				}
				.padding(.vertical, 1)
			}
		}
	}
}
