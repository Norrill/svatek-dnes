import SwiftUI

/// Detail of one calendar day: names, holidays, matched contacts
/// and calendar export (single or yearly event).
struct DayDetailView: View {
	let info: DayInfo

	@EnvironmentObject var contacts: ContactsService

	@State private var addedToCalendar = false
	@State private var exportErrorMessage = ""
	@State private var showsExportError = false

	var body: some View {
		List {
			namesSection
			if !info.holidays.isEmpty {
				holidaysSection
			}
			if !matchedContacts.isEmpty {
				contactsSection
			}
			if eventTitle != nil {
				calendarSection
			}
		}
		.navigationTitle(AppFormat.dayMonth(info.date))
		.navigationBarTitleDisplayMode(.inline)
		.alert("Nepodařilo se přidat do kalendáře", isPresented: $showsExportError) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(exportErrorMessage)
		}
	}

	// MARK: - Names

	private var namesSection: some View {
		Section {
			VStack(alignment: .leading, spacing: 6) {
				if info.entry.displayText.isEmpty {
					Text("V kalendáři jmenin není na tento den žádné jméno.")
						.font(.body)
						.foregroundStyle(.secondary)
				} else {
					Text(info.entry.displayText)
						.font(.system(size: 32, weight: .bold, design: .rounded))
					if let variants = info.entry.variantsText {
						Text(variants)
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}
				}
			}
			.padding(.vertical, 4)
		} header: {
			Text(namesHeader)
		}
	}

	private var namesHeader: String {
		switch info.entry.names.count {
		case 0:
			return String(localized: "Jmeniny")
		case 1:
			return String(localized: "Svátek má")
		default:
			return String(localized: "Svátek mají")
		}
	}

	// MARK: - Holidays

	private var holidaysSection: some View {
		Section("Svátky a významné dny") {
			ForEach(info.holidays) { holiday in
				VStack(alignment: .leading, spacing: 4) {
					HStack(spacing: 8) {
						Text(holiday.shortName)
							.font(.headline)
							.foregroundStyle(holiday.isDayOff ? Color.red : Color.primary)
						Spacer(minLength: 8)
						Text(holiday.kindLabel)
							.font(.caption2.weight(.semibold))
							.padding(.horizontal, 8)
							.padding(.vertical, 4)
							.background(
								(holiday.isDayOff ? Color.red : Color.brandGreen).opacity(0.15),
								in: Capsule()
							)
							.foregroundStyle(holiday.isDayOff ? Color.red : Color.brandGreen)
					}
					if holiday.name != holiday.shortName {
						Text(holiday.name)
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}
				}
				.padding(.vertical, 2)
			}
		}
	}

	// MARK: - Contacts

	private var matchedContacts: [MatchedContact] {
		contacts.matches(month: info.entry.m, day: info.entry.d)
	}

	private var contactsSection: some View {
		Section {
			ForEach(matchedContacts) { contact in
				HStack(spacing: 12) {
					initialsAvatar(for: contact)
					VStack(alignment: .leading, spacing: 2) {
						Text(contact.fullName)
							.font(.body.weight(.medium))
						if contact.isManual {
							Text("přiřazeno ručně")
								.font(.caption)
								.foregroundStyle(.secondary)
						} else if contact.kind == .fuzzy {
							Text("pravděpodobně \(contact.matchedName)")
								.font(.caption)
								.foregroundStyle(.secondary)
						} else if contact.matchedName != contact.givenName {
							Text("v kalendáři jako \(contact.matchedName)")
								.font(.caption)
								.foregroundStyle(.secondary)
						}
					}
				}
				.padding(.vertical, 2)
			}
		} header: {
			Text(matchedContacts.count > 1
				? String(localized: "Svátek mají vaše kontakty")
				: String(localized: "Svátek má váš kontakt"))
		}
	}

	private func initialsAvatar(for contact: MatchedContact) -> some View {
		let initials = [contact.givenName, contact.familyName]
			.compactMap { $0.first.map(String.init) }
			.joined()
		return ZStack {
			Circle()
				.fill(Color.brandGreen)
			Text(initials.uppercased(with: AppFormat.locale))
				.font(.subheadline.weight(.semibold))
				.foregroundStyle(.white)
		}
		.frame(width: 40, height: 40)
	}

	// MARK: - Calendar export

	private var calendarSection: some View {
		Section {
			if addedToCalendar {
				Label("Přidáno do kalendáře", systemImage: "checkmark.circle.fill")
					.foregroundStyle(Color.brandGreen)
			} else {
				Menu {
					Button("Jen tento rok") {
						addToCalendar(yearly: false)
					}
					Button("Opakovat každý rok") {
						addToCalendar(yearly: true)
					}
				} label: {
					Label("Přidat do kalendáře", systemImage: "calendar.badge.plus")
				}
			}
		}
	}

	private var eventTitle: String? {
		if !info.entry.names.isEmpty {
			let joined = info.entry.names.joinedNames
			return info.entry.names.count > 1
				? String(localized: "Svátek mají \(joined)")
				: String(localized: "Svátek má \(joined)")
		}
		if let holiday = info.primaryHoliday {
			return holiday.name
		}
		return nil
	}

	private func addToCalendar(yearly: Bool) {
		guard let title = eventTitle else {
			return
		}
		Task { @MainActor in
			do {
				try await CalendarExporter.shared.addAllDayEvent(title: title, date: info.date, yearly: yearly)
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
}

#Preview {
	NavigationStack {
		DayDetailView(info: CalendarComposer.info(for: Date()))
	}
	.environmentObject(ContactsService.shared)
}
