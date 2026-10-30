import SwiftUI

struct WatchSearchView: View {
	@State private var query = ""

	private var isSearching: Bool {
		!NameMatching.fold(query).isEmpty
	}

	private var matchingDays: [DayInfo] {
		let today = Date()
		return NamedayStore.shared.search(query)
			.compactMap { NamedayStore.shared.nextDate(month: $0.m, day: $0.d, onOrAfter: today) }
			.sorted()
			.map(CalendarComposer.info(for:))
	}

	var body: some View {
		List {
			TextField("search_name_prompt", text: $query)
			if isSearching {
				results
			}
		}
	}

	@ViewBuilder
	private var results: some View {
		let days = matchingDays
		if days.isEmpty {
			Label("search_empty_title", systemImage: "magnifyingglass")
				.font(.footnote)
				.foregroundStyle(.secondary)
		} else {
			ForEach(days) { day in
				WatchDayRow(day: day)
			}
		}
	}
}
