import SwiftUI

/// Watch entry screen: who has their nameday today, whether it is a holiday,
/// and which of your people are celebrating. The Digital Crown scrolls the
/// screen; the toolbar opens the year and the name search.
struct WatchTodayView: View {
	@EnvironmentObject private var store: WatchDataStore
	@Environment(\.scenePhase) private var scenePhase

	@State private var today = Date()

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 12) {
					hero
					if let holiday = info.primaryHoliday {
						holidayRow(holiday)
					}
					contactsSection
					upcomingContactsSection
				}
				.padding(.horizontal, 4)
				.padding(.bottom, 8)
			}
			.navigationTitle("today_title")
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					NavigationLink {
						WatchCalendarView()
					} label: {
						Label("calendar_title", systemImage: "calendar")
					}
				}
				ToolbarItem(placement: .topBarTrailing) {
					NavigationLink {
						WatchSearchView()
					} label: {
						Label("search_name_prompt", systemImage: "magnifyingglass")
					}
				}
			}
		}
		.onAppear {
			today = Date()
		}
		.onChange(of: scenePhase) { _, phase in
			if phase == .active {
				today = Date()
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
			today = Date()
		}
	}

	private var info: DayInfo {
		CalendarComposer.info(for: today)
	}

	private var hero: some View {
		VStack(alignment: .leading, spacing: 2) {
			Text(AppFormat.weekdayDayMonth(today))
				.font(.caption2)
				.foregroundStyle(.secondary)
			Text(info.entry.displayText.isEmpty ? String(localized: "nameday_none") : info.entry.displayText)
				.font(.title3)
				.fontWeight(.semibold)
				.foregroundStyle(info.entry.displayText.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.brandGreen))
				.minimumScaleFactor(0.7)
			if let variants = info.entry.variantsText {
				Text(variants)
					.font(.caption2)
					.foregroundStyle(.secondary)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private func holidayRow(_ holiday: Holiday) -> some View {
		HStack(alignment: .firstTextBaseline, spacing: 6) {
			HolidayDot(isDayOff: holiday.isDayOff)
			VStack(alignment: .leading, spacing: 1) {
				Text(holiday.shortName)
					.font(.footnote)
					.fontWeight(.medium)
				Text(holiday.kindLabel)
					.font(.caption2)
					.foregroundStyle(.secondary)
			}
		}
	}

	@ViewBuilder
	private var contactsSection: some View {
		let names = store.contacts(for: today)
		if !names.isEmpty {
			VStack(alignment: .leading, spacing: 2) {
				Text("today_contacts_section")
					.font(.caption2)
					.foregroundStyle(.secondary)
				Text(names.joinedNames)
					.font(.footnote)
					.fontWeight(.medium)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
	}

	/// Who is coming up, so the screen is useful before the day itself.
	@ViewBuilder
	private var upcomingContactsSection: some View {
		let upcoming = store.upcomingContacts(from: today)
		if !upcoming.isEmpty {
			VStack(alignment: .leading, spacing: 3) {
				Text("watch_upcoming_contacts")
					.font(.caption2)
					.foregroundStyle(.secondary)
				ForEach(upcoming) { day in
					HStack(alignment: .firstTextBaseline, spacing: 5) {
						Text(day.names.joinedNames)
							.font(.footnote)
							.lineLimit(1)
						Spacer(minLength: 0)
						Text(AppFormat.countdown(day.date, reference: today))
							.font(.caption2)
							.foregroundStyle(.secondary)
					}
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
	}
}
