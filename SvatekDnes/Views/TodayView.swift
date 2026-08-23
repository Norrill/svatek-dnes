import SwiftUI
import Combine

/// "Dnes" tab: hero card for today, calendar export, contacts teaser
/// and a preview of the upcoming days.
struct TodayView: View {
	@EnvironmentObject var contacts: ContactsService
	@Environment(\.scenePhase) private var scenePhase

	@State private var today = Date()
	@State private var addedToCalendar = false
	@State private var exportErrorMessage = ""
	@State private var showsExportError = false

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 20) {
					heroCard(for: todayInfo)
					addToCalendarButton
					contactNamedaysSection
					if contacts.canRequestAccess {
						contactsTeaser
					}
					upcomingSection
				}
				.padding(.horizontal)
				.padding(.top, 4)
				.padding(.bottom, 24)
			}
			.background(Color(.systemGroupedBackground))
			.navigationTitle("today_title")
			.navigationBarTitleDisplayMode(.large)
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
			// Midnight, DST or timezone change while the app stays foregrounded.
			today = Date()
		}
		.alert("calendar_export_error_title", isPresented: $showsExportError) {
			Button("common_ok", role: .cancel) {}
		} message: {
			Text(exportErrorMessage)
		}
	}

	private var todayInfo: DayInfo {
		CalendarComposer.info(for: today)
	}

	// MARK: - Hero card

	private func heroCard(for info: DayInfo) -> some View {
		VStack(alignment: .leading, spacing: 10) {
			Text(capitalizedFirst(AppFormat.weekdayDayMonth(info.date)))
				.font(.headline)
				.foregroundStyle(.white.opacity(0.85))

			Text(heroTitle(for: info))
				.font(.system(size: 40, weight: .bold, design: .rounded))
				.foregroundStyle(.white)
				.lineLimit(3)
				.minimumScaleFactor(0.5)

			if let variants = info.entry.variantsText {
				Text(variants)
					.font(.subheadline)
					.foregroundStyle(.white.opacity(0.85))
			}

			if !info.holidays.isEmpty {
				holidayBadges(info.holidays)
					.padding(.top, 2)
			}

			if !todayContactNames.isEmpty {
				Text(contactLine)
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(.white)
					.padding(.top, 2)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(20)
		.background(
			LinearGradient(
				colors: [Color.brandGreen, Color.brandGreen.opacity(0.75)],
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			)
		)
		.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
	}

	private func heroTitle(for info: DayInfo) -> String {
		if !info.entry.displayText.isEmpty {
			return info.entry.displayText
		}
		if let holiday = info.primaryHoliday {
			return holiday.shortName
		}
		return String(localized: "nameday_none")
	}

	private func holidayBadges(_ holidays: [Holiday]) -> some View {
		VStack(alignment: .leading, spacing: 6) {
			ForEach(holidays) { holiday in
				Text(verbatim: "\(holiday.kindLabel) – \(holiday.shortName)")
					.font(.caption.weight(.semibold))
					.padding(.horizontal, 10)
					.padding(.vertical, 5)
					.background(
						holiday.isDayOff ? Color.red.opacity(0.85) : Color.white.opacity(0.2),
						in: Capsule()
					)
					.foregroundStyle(.white)
			}
		}
	}

	private var todayContactNames: [String] {
		var seen = Set<String>()
		return contacts.matches(month: todayInfo.entry.m, day: todayInfo.entry.d)
			.map(\.givenName)
			.filter { !$0.isEmpty && seen.insert($0).inserted }
	}

	private var contactLine: String {
		let names = todayContactNames
		if names.count == 1 {
			return String(format: String(localized: "today_contact_nameday_single"), names[0])
		}
		return String(format: String(localized: "today_contact_nameday_multiple"), names.joinedNames)
	}

	// MARK: - Calendar export

	@ViewBuilder
	private var addToCalendarButton: some View {
		if let title = eventTitle(for: todayInfo) {
			Button {
				addTodayToCalendar(title: title)
			} label: {
				Label(
					addedToCalendar ? "calendar_export_added" : "calendar_export_add",
					systemImage: addedToCalendar ? "checkmark" : "calendar.badge.plus"
				)
				.frame(maxWidth: .infinity)
			}
			.buttonStyle(.borderedProminent)
			.controlSize(.large)
			.tint(Color.brandGreen)
			.disabled(addedToCalendar)
		}
	}

	private func eventTitle(for info: DayInfo) -> String? {
		if !info.entry.names.isEmpty {
			let joined = info.entry.names.joinedNames
			return info.entry.names.count > 1
				? String(format: String(localized: "nameday_has_multiple"), joined)
				: String(format: String(localized: "nameday_has_single"), joined)
		}
		if let holiday = info.primaryHoliday {
			return holiday.name
		}
		return nil
	}

	private func addTodayToCalendar(title: String) {
		Task { @MainActor in
			do {
				try await CalendarExporter.shared.addAllDayEvent(title: title, date: today)
				withAnimation {
					addedToCalendar = true
				}
				try? await Task.sleep(for: .seconds(3))
				withAnimation {
					addedToCalendar = false
				}
			} catch {
				exportErrorMessage = error.localizedDescription
				showsExportError = true
			}
		}
	}

	// MARK: - Contacts teaser

	private var contactsTeaser: some View {
		VStack(alignment: .leading, spacing: 8) {
			Label("today_teaser_title", systemImage: "person.2.circle")
				.font(.headline)
			Text("today_teaser_message")
				.font(.subheadline)
				.foregroundStyle(.secondary)
			Button("today_teaser_allow") {
				Task {
					await contacts.requestAccessAndLoad()
				}
			}
			.buttonStyle(.bordered)
			.tint(Color.brandGreen)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(16)
		.background(
			Color(.secondarySystemGroupedBackground),
			in: RoundedRectangle(cornerRadius: 16, style: .continuous)
		)
	}

	// MARK: - Contact namedays

	/// The next three contact namedays.
	@ViewBuilder
	private var contactNamedaysSection: some View {
		let groups = Array(contacts.upcoming(from: today).prefix(3))
		if !groups.isEmpty {
			VStack(alignment: .leading, spacing: 10) {
				Text("today_contacts_section")
					.font(.title3.weight(.semibold))

				VStack(spacing: 0) {
					ForEach(groups, id: \.date) { group in
						NavigationLink {
							DayDetailView(info: CalendarComposer.info(for: group.date))
						} label: {
							contactGroupRow(group)
						}
						.buttonStyle(.plain)

						if group.date != groups.last?.date {
							Divider()
								.padding(.leading, 16)
						}
					}
				}
				.background(
					Color(.secondarySystemGroupedBackground),
					in: RoundedRectangle(cornerRadius: 16, style: .continuous)
				)
			}
		}
	}

	private func contactGroupRow(_ group: (date: Date, contacts: [MatchedContact])) -> some View {
		let isToday = Calendar.czech.isDate(group.date, inSameDayAs: today)
		return HStack(spacing: 12) {
			VStack(alignment: .leading, spacing: 2) {
				Text(countdownLabel(group.date))
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(isToday ? Color.brandGreen : Color.primary)
					.lineLimit(1)
					.minimumScaleFactor(0.75)
				Text(AppFormat.dayMonth(group.date))
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
					.minimumScaleFactor(0.75)
			}
			.frame(width: 92, alignment: .leading)

			Text(groupNames(group.contacts))
				.font(.body.weight(.medium))
				.lineLimit(2)

			Spacer(minLength: 8)

			if isToday {
				Text(verbatim: "🎉")
			}
			Image(systemName: "chevron.right")
				.font(.caption.weight(.semibold))
				.foregroundStyle(.tertiary)
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 12)
		.contentShape(Rectangle())
	}

	private func groupNames(_ list: [MatchedContact]) -> String {
		if list.count == 1 {
			return list[0].fullName
		}
		var seen = Set<String>()
		return list.map(\.givenName)
			.filter { !$0.isEmpty && seen.insert($0).inserted }
			.joinedNames
	}

	/// "dnes", "zítra", "za 5 dní" – for the contact nameday rows.
	private func countdownLabel(_ date: Date) -> String {
		switch AppFormat.relativeKind(date, reference: today) {
		case .today, .tomorrow:
			return AppFormat.relativeDay(date, reference: today)
		case .other:
			return AppFormat.inDays(AppFormat.daysUntil(date, reference: today))
		}
	}

	// MARK: - Upcoming days

	private var upcomingSection: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("today_upcoming_section")
				.font(.title3.weight(.semibold))

			let days = Array(CalendarComposer.upcoming(days: 8, from: today).dropFirst())
			VStack(spacing: 0) {
				ForEach(days) { info in
					NavigationLink {
						DayDetailView(info: info)
					} label: {
						upcomingRow(info)
					}
					.buttonStyle(.plain)

					if info.id != days.last?.id {
						Divider()
							.padding(.leading, 16)
					}
				}
			}
			.background(
				Color(.secondarySystemGroupedBackground),
				in: RoundedRectangle(cornerRadius: 16, style: .continuous)
			)
		}
	}

	private func upcomingRow(_ info: DayInfo) -> some View {
		HStack(spacing: 12) {
			VStack(alignment: .leading, spacing: 2) {
				Text(dayLabel(info.date))
					.font(.subheadline.weight(.semibold))
				Text(AppFormat.shortDate(month: info.entry.m, day: info.entry.d))
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			.frame(width: 72, alignment: .leading)

			VStack(alignment: .leading, spacing: 3) {
				if info.entry.displayText.isEmpty {
					Text("nameday_none_inline")
						.font(.body)
						.foregroundStyle(.secondary)
				} else {
					Text(info.entry.displayText)
						.font(.body.weight(.medium))
				}
				if let holiday = info.primaryHoliday {
					HStack(spacing: 5) {
						Circle()
							.fill(holiday.isDayOff ? Color.red : Color.brandGreen)
							.frame(width: 7, height: 7)
						Text(holiday.shortName)
							.font(.caption)
							.foregroundStyle(holiday.isDayOff ? Color.red : Color.brandGreen)
					}
				}
			}

			Spacer(minLength: 8)

			let names = upcomingContactNames(info)
			if !names.isEmpty {
				Text(verbatim: "🎉 " + names.joinedNames)
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
					.layoutPriority(-1)
			}

			Image(systemName: "chevron.right")
				.font(.caption.weight(.semibold))
				.foregroundStyle(.tertiary)
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 12)
		.contentShape(Rectangle())
	}

	private func upcomingContactNames(_ info: DayInfo) -> [String] {
		var seen = Set<String>()
		return contacts.matches(month: info.entry.m, day: info.entry.d)
			.map(\.givenName)
			.filter { !$0.isEmpty && seen.insert($0).inserted }
	}

	/// "zítra", or the weekday alone ("neděle") for later days.
	private func dayLabel(_ date: Date) -> String {
		switch AppFormat.relativeKind(date, reference: today) {
		case .today, .tomorrow:
			return AppFormat.relativeDay(date, reference: today)
		case .other:
			return AppFormat.weekday(date)
		}
	}

	private func capitalizedFirst(_ text: String) -> String {
		guard let first = text.first else {
			return text
		}
		return String(first).uppercased(with: AppFormat.locale) + text.dropFirst()
	}
}

#Preview {
	TodayView()
		.environmentObject(ContactsService.shared)
}
