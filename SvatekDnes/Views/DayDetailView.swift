import SwiftUI

/// Detail of one calendar day: names, holidays, matched contacts
/// and calendar export (single or yearly event).
struct DayDetailView: View {
	let info: DayInfo

	@EnvironmentObject var contacts: ContactsService

	@State private var addedToCalendar = false
	@State private var exportErrorMessage = ""
	@State private var showsExportError = false
	@State private var assigningContact: AssignmentTarget?
	@StateObject private var contactActions = ContactActions()

	// Scale with Dynamic Type instead of staying fixed at large text sizes.
	@ScaledMetric(relativeTo: .largeTitle) private var namesSize: CGFloat = 32
	@ScaledMetric(relativeTo: .subheadline) private var avatarSize: CGFloat = 40

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
		.alert("calendar_export_error_title", isPresented: $showsExportError) {
			Button("common_ok", role: .cancel) {}
		} message: {
			Text(exportErrorMessage)
		}
		.modifier(ContactActionsHost(actions: contactActions))
		.sheet(item: $assigningContact) { target in
			AssignNamedayView(target: target)
		}
	}

	// MARK: - Names

	private var namesSection: some View {
		Section {
			VStack(alignment: .leading, spacing: 6) {
				if info.entry.displayText.isEmpty {
					Text("day_no_name_message")
						.font(.body)
						.foregroundStyle(.secondary)
				} else {
					Text(info.entry.displayText)
						.font(.system(size: namesSize, weight: .bold, design: .rounded))
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
			return String(localized: "day_names_header_empty")
		case 1:
			return String(localized: "day_names_header_single")
		default:
			return String(localized: "day_names_header_multiple")
		}
	}

	// MARK: - Holidays

	private var holidaysSection: some View {
		Section("day_holidays_header") {
			ForEach(info.holidays) { holiday in
				VStack(alignment: .leading, spacing: 4) {
					HStack(spacing: 8) {
						Text(holiday.shortName)
							.font(.headline)
							.foregroundStyle(holiday.isDayOff ? Color.brandRed : Color.primary)
						Spacer(minLength: 8)
						Text(holiday.kindLabel)
							.font(.caption2.weight(.semibold))
							.padding(.horizontal, 8)
							.padding(.vertical, 4)
							.background(
								(holiday.isDayOff ? Color.brandRed : Color.brandGreen).opacity(0.15),
								in: Capsule()
							)
							.foregroundStyle(holiday.isDayOff ? Color.brandRed : Color.brandGreen)
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
							Text("contact_assigned_manually")
								.font(.caption)
								.foregroundStyle(.secondary)
						} else if contact.kind == .fuzzy {
							Text(String(format: String(localized: "contact_match_probable"), contact.matchedName))
								.font(.caption)
								.foregroundStyle(.secondary)
						} else if contact.matchedName != contact.givenName {
							Text(String(format: String(localized: "contact_match_calendar_name"), contact.matchedName))
								.font(.caption)
								.foregroundStyle(.secondary)
						}
					}
					Spacer(minLength: 8)
					Button {
						contactActions.composeMessage(for: contact)
					} label: {
						Image(systemName: "message")
							.foregroundStyle(Color.brandGreen)
					}
					.buttonStyle(.borderless)
					.accessibilityLabel("contact_send_message")
				}
				.padding(.vertical, 2)
				.contextMenu {
					ContactActionButtons(contact: contact, actions: contactActions)
					Divider()
					Button {
						assigningContact = AssignmentTarget(id: contact.id, givenName: contact.givenName)
					} label: {
						Label("people_change_nameday", systemImage: "pencil")
					}
					if contact.isManual {
						Button(role: .destructive) {
							removeAssignment(contact)
						} label: {
							Label("people_remove_assignment", systemImage: "xmark.circle")
						}
					}
				}
			}
		} header: {
			Text(matchedContacts.count > 1
				? String(localized: "day_contacts_header_multiple")
				: String(localized: "day_contacts_header_single"))
		}
	}

	private func removeAssignment(_ contact: MatchedContact) {
		ManualAssignmentStore.remove(contactId: contact.id)
		Task { @MainActor in
			await AppRefresher.contactsChanged()
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
		.frame(width: avatarSize, height: avatarSize)
		// Decorative – the full name follows right next to it.
		.accessibilityHidden(true)
	}

	// MARK: - Calendar export

	private var calendarSection: some View {
		Section {
			if addedToCalendar {
				Label("calendar_export_added", systemImage: "checkmark.circle.fill")
					.foregroundStyle(Color.brandGreen)
			} else {
				Menu {
					Button("calendar_export_once") {
						addToCalendar(yearly: false)
					}
					Button("calendar_export_yearly") {
						addToCalendar(yearly: true)
					}
				} label: {
					Label("calendar_export_add", systemImage: "calendar.badge.plus")
				}
			}
		}
	}

	private var eventTitle: String? {
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
