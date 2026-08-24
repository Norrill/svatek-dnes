import SwiftUI

/// "Kalendář" – browsable full-year nameday calendar with name search.
struct CalendarListView: View {
	@EnvironmentObject private var contacts: ContactsService

	@State private var selectedMonth = Calendar.czech.component(.month, from: Date())
	@State private var searchText = ""

	private let year = Calendar.czech.component(.year, from: Date())

	private var isSearching: Bool {
		!NameMatching.fold(searchText).isEmpty
	}

	var body: some View {
		NavigationStack {
			Group {
				if isSearching {
					searchResults
				} else {
					monthBrowser
				}
			}
			.navigationTitle("calendar_title")
			.navigationDestination(for: Date.self) { date in
				DayDetailView(info: CalendarComposer.info(for: date))
			}
			.searchable(text: $searchText, prompt: "search_name_prompt")
		}
	}

	// MARK: - Month browsing

	private var monthBrowser: some View {
		VStack(spacing: 0) {
			monthChips
			List {
				ForEach(NamedayStore.shared.month(selectedMonth), id: \.self) { entry in
					dayRow(entry)
				}
			}
			.listStyle(.insetGrouped)
			.id(selectedMonth)
		}
		.background(Color(.systemGroupedBackground))
	}

	private var monthChips: some View {
		ScrollViewReader { proxy in
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 8) {
					ForEach(1...12, id: \.self) { month in
						monthChip(month)
					}
				}
				.padding(.horizontal)
				.padding(.vertical, 10)
			}
			.onAppear {
				// Defer past the first layout pass, otherwise scrollTo is a no-op.
				let month = selectedMonth
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
					withAnimation {
						proxy.scrollTo(month, anchor: .center)
					}
				}
			}
		}
	}

	private func monthChip(_ month: Int) -> some View {
		let selected = month == selectedMonth
		return Button {
			selectedMonth = month
		} label: {
			Text(AppFormat.monthName(month).capitalized(with: AppFormat.locale))
				.font(.subheadline.weight(selected ? .semibold : .regular))
				.padding(.horizontal, 14)
				.padding(.vertical, 7)
				.background(Capsule().fill(selected ? Color.brandGreen : Color(.secondarySystemFill)))
				.foregroundStyle(selected ? Color.white : Color.primary)
		}
		.buttonStyle(.plain)
		.id(month)
	}

	@ViewBuilder
	private func dayRow(_ entry: NamedayEntry) -> some View {
		if let date = validDate(month: entry.m, day: entry.d) {
			NavigationLink(value: date) {
				dayRowLabel(entry)
			}
		} else {
			// Day not existing this year (29. 2. in a non-leap year) –
			// shown, but without navigation.
			dayRowLabel(entry)
				.opacity(0.6)
		}
	}

	private func dayRowLabel(_ entry: NamedayEntry) -> some View {
		let holidays = HolidayCalendar.holidays(month: entry.m, day: entry.d, year: year)
		let dayOff = holidays.contains { $0.isDayOff }
		return HStack(spacing: 12) {
			dayBadge(day: entry.d, isToday: isToday(entry), isDayOff: dayOff)
			VStack(alignment: .leading, spacing: 2) {
				if entry.names.isEmpty {
					Text(verbatim: "–")
						.foregroundStyle(.secondary)
				} else {
					Text(verbatim: entry.displayText)
				}
				ForEach(holidays) { holiday in
					Text(verbatim: holiday.shortName)
						.font(.footnote)
						.foregroundStyle(holiday.isDayOff ? Color.red : Color.brandGreen)
						// Day-off is encoded by colour only – say it out loud.
						.accessibilityLabel(Text(verbatim: "\(holiday.shortName) – \(holiday.kindLabel)"))
				}
			}
			Spacer(minLength: 0)
			if !contacts.matches(month: entry.m, day: entry.d).isEmpty {
				Text(verbatim: "🎉")
					.accessibilityLabel("calendar_contact_marker_a11y")
			}
		}
	}

	private func dayBadge(day: Int, isToday: Bool, isDayOff: Bool) -> some View {
		Text(verbatim: "\(day)")
			.font(.callout.weight(.semibold))
			.monospacedDigit()
			.frame(width: 34, height: 34)
			.background(
				RoundedRectangle(cornerRadius: 8, style: .continuous)
					.fill(
						isToday
							? Color.brandGreen
							: (isDayOff ? Color.red.opacity(0.15) : Color(.tertiarySystemFill))
					)
			)
			.foregroundStyle(
				isToday
					? Color.white
					: (isDayOff ? Color.red : Color.primary)
			)
	}

	// MARK: - Search

	@ViewBuilder
	private var searchResults: some View {
		let results = NamedayStore.shared.search(searchText)
		if results.isEmpty {
			ContentUnavailableView {
				Label("search_empty_title", systemImage: "magnifyingglass")
			} description: {
				Text(String(format: String(localized: "search_empty_message"), searchText.trimmingCharacters(in: .whitespacesAndNewlines)))
			}
			.background(Color(.systemGroupedBackground))
		} else {
			List {
				ForEach(results, id: \.self) { entry in
					searchRow(entry)
				}
			}
			.listStyle(.insetGrouped)
		}
	}

	@ViewBuilder
	private func searchRow(_ entry: NamedayEntry) -> some View {
		if let date = validDate(month: entry.m, day: entry.d) {
			NavigationLink(value: date) {
				searchRowLabel(entry)
			}
		} else {
			searchRowLabel(entry)
				.opacity(0.6)
		}
	}

	private func searchRowLabel(_ entry: NamedayEntry) -> some View {
		VStack(alignment: .leading, spacing: 2) {
			Text(verbatim: AppFormat.shortDate(month: entry.m, day: entry.d))
				.foregroundStyle(.secondary)
				+ Text(verbatim: " – ")
				.foregroundStyle(.secondary)
				+ highlightedNames(entry)
			if let variants = matchedVariantsLine(entry) {
				variants
					.font(.footnote)
					.foregroundStyle(.secondary)
			}
		}
	}

	/// Canonical names joined the Czech way, matched names in bold.
	private func highlightedNames(_ entry: NamedayEntry) -> Text {
		guard !entry.names.isEmpty else {
			return Text(verbatim: "–").foregroundStyle(.secondary)
		}
		let folded = NameMatching.fold(searchText)
		var result = Text(verbatim: "")
		for (index, name) in entry.names.enumerated() {
			if index > 0 {
				result = result + Text(verbatim: index == entry.names.count - 1 ? String(localized: "names_final_separator") : ", ")
			}
			var piece = Text(verbatim: name)
			if NameMatching.fold(name).hasPrefix(folded) {
				piece = piece.bold()
			}
			result = result + piece
		}
		return result
	}

	/// "též …" line shown when the query matched a variant name.
	private func matchedVariantsLine(_ entry: NamedayEntry) -> Text? {
		let folded = NameMatching.fold(searchText)
		guard entry.alt.contains(where: { NameMatching.fold($0).hasPrefix(folded) }) else {
			return nil
		}
		var result = Text(verbatim: String(localized: "nameday_variants_prefix") + " ")
		for (index, name) in entry.alt.enumerated() {
			if index > 0 {
				result = result + Text(verbatim: index == entry.alt.count - 1 ? String(localized: "names_final_separator") : ", ")
			}
			var piece = Text(verbatim: name)
			if NameMatching.fold(name).hasPrefix(folded) {
				piece = piece.bold()
			}
			result = result + piece
		}
		return result
	}

	// MARK: - Helpers

	/// The m/d date in the current year, nil when it does not exist
	/// (29. 2. in a non-leap year – Calendar would silently roll it over).
	private func validDate(month: Int, day: Int) -> Date? {
		var comps = DateComponents()
		comps.year = year
		comps.month = month
		comps.day = day
		guard let date = Calendar.czech.date(from: comps) else {
			return nil
		}
		let check = Calendar.czech.dateComponents([.month, .day], from: date)
		guard check.month == month, check.day == day else {
			return nil
		}
		return date
	}

	private func isToday(_ entry: NamedayEntry) -> Bool {
		let comps = Calendar.czech.dateComponents([.year, .month, .day], from: Date())
		return comps.year == year && comps.month == entry.m && comps.day == entry.d
	}
}

#Preview {
	CalendarListView()
		.environmentObject(ContactsService.shared)
}
