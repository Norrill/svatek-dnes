import SwiftUI
import UIKit

/// "Lidé" – contacts matched against the nameday calendar,
/// grouped by their next upcoming nameday.
struct PeopleView: View {
	@EnvironmentObject var contacts: ContactsService

	@State private var exportedIDs: Set<String> = []
	@State private var exportErrorMessage: String?
	@State private var showExportError = false
	@State private var toastVisible = false
	@State private var toastTask: Task<Void, Never>?
	@State private var assigningContact: AssignmentTarget?
	@StateObject private var contactActions = ContactActions()

	@ScaledMetric(relativeTo: .subheadline) private var avatarSize: CGFloat = 40

	var body: some View {
		NavigationStack {
			content
				.navigationTitle("people_title")
				.overlay(alignment: .bottom) {
					if toastVisible {
						toast
					}
				}
				.alert("calendar_export_error_title", isPresented: $showExportError) {
					Button("common_ok", role: .cancel) {}
				} message: {
					Text(exportErrorMessage ?? String(localized: "calendar_export_error_retry"))
				}
				.sheet(item: $assigningContact) { target in
					AssignNamedayView(target: target)
				}
				.modifier(ContactActionsHost(actions: contactActions))
		}
	}

	@ViewBuilder
	private var content: some View {
		if contacts.canRequestAccess {
			requestAccessState
		} else if !contacts.isAuthorized {
			deniedState
		} else if contacts.matched.isEmpty && contacts.unmatched.isEmpty {
			noMatchesState
		} else {
			peopleList
		}
	}

	// MARK: - Permission states

	private var requestAccessState: some View {
		EmptyStateView(
			systemImage: "person.2.badge.plus",
			title: "people_intro_title",
			message: "people_intro_message"
		) {
			Button {
				Task {
					await contacts.requestAccessAndLoad()
				}
			} label: {
				Text("people_intro_allow")
					.fontWeight(.semibold)
			}
			.buttonStyle(.borderedProminent)
			.controlSize(.large)
		}
	}

	private var deniedState: some View {
		EmptyStateView(
			systemImage: "person.2.slash",
			title: "people_denied_title",
			message: "people_denied_message"
		) {
			if let url = URL(string: UIApplication.openSettingsURLString) {
				Link("people_open_settings", destination: url)
					.fontWeight(.semibold)
					.buttonStyle(.borderedProminent)
					.controlSize(.large)
			}
		}
	}

	private var noMatchesState: some View {
		ScrollView {
			EmptyStateView(
				systemImage: "person.crop.circle.badge.questionmark",
				title: "people_empty_title",
				message: "people_empty_message"
			) {
				EmptyView()
			}
			.padding(.top, 60)
		}
		.refreshable {
			await contacts.reloadIfAuthorized()
		}
	}

	// MARK: - Main list

	private var peopleList: some View {
		let groups = contacts.upcoming()
		return List {
			ForEach(groups, id: \.date) { group in
				let isToday = Calendar.current.isDateInToday(group.date)
				Section {
					ForEach(group.contacts) { contact in
						PersonRow(
							contact: contact,
							isToday: isToday,
							isExported: exportedIDs.contains(contact.id)
						)
						.swipeActions(edge: .leading, allowsFullSwipe: true) {
							Button {
								contactActions.composeMessage(for: contact)
							} label: {
								Label("contact_send_message", systemImage: "message")
							}
							.tint(Color.brandGreen)
						}
						.swipeActions(edge: .trailing, allowsFullSwipe: false) {
							Button {
								addToCalendar(contact, date: group.date)
							} label: {
								Label("calendar_export_add", systemImage: "calendar.badge.plus")
							}
							.tint(Color.brandGreen)
						}
						.contextMenu {
							ContactActionButtons(contact: contact, actions: contactActions)
							Divider()
							Button {
								addToCalendar(contact, date: group.date)
							} label: {
								Label("calendar_export_add", systemImage: "calendar.badge.plus")
							}
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
					Text(sectionTitle(for: group.date))
						.foregroundStyle(isToday ? Color.brandGreen : Color.secondary)
						.fontWeight(isToday ? .semibold : .regular)
				}
			}
			if !contacts.unmatched.isEmpty {
				unmatchedSection
			}
		}
		.refreshable {
			await contacts.reloadIfAuthorized()
		}
	}

	private var unmatchedSection: some View {
		Section {
			ForEach(contacts.unmatched) { contact in
				Button {
					assigningContact = AssignmentTarget(id: contact.id, givenName: contact.givenName)
				} label: {
					HStack(spacing: 12) {
						ZStack {
							Circle()
								.fill(Color(.systemFill))
							Text(initials(given: contact.givenName, family: contact.familyName))
								.font(.subheadline.weight(.semibold))
								.foregroundStyle(.secondary)
						}
						.frame(width: avatarSize, height: avatarSize)
						.accessibilityHidden(true)
						VStack(alignment: .leading, spacing: 2) {
							Text(contact.fullName)
								.foregroundStyle(.primary)
							Text("people_unmatched_subtitle")
								.font(.footnote)
								.foregroundStyle(.secondary)
						}
						Spacer()
						Text("people_assign_action")
							.font(.subheadline.weight(.medium))
							.foregroundStyle(Color.brandGreen)
					}
					.padding(.vertical, 2)
				}
				.buttonStyle(.plain)
			}
		} header: {
			Text("people_unmatched_header")
		} footer: {
			Text("people_unmatched_footer")
		}
	}

	private var toast: some View {
		Label("calendar_export_added", systemImage: "checkmark.circle.fill")
			.font(.subheadline.weight(.semibold))
			.foregroundStyle(.white)
			.padding(.horizontal, 16)
			.padding(.vertical, 10)
			.background(Color.brandGreen, in: Capsule())
			.shadow(radius: 4, y: 2)
			.padding(.bottom, 12)
			.transition(.move(edge: .bottom).combined(with: .opacity))
	}

	// MARK: - Actions

	private func addToCalendar(_ contact: MatchedContact, date: Date) {
		Task {
			do {
				try await CalendarExporter.shared.addAllDayEvent(
					title: String(format: String(localized: "nameday_has_single"), contact.givenName),
					date: date,
					yearly: false
				)
				withAnimation {
					exportedIDs.insert(contact.id)
					toastVisible = true
				}
				toastTask?.cancel()
				toastTask = Task {
					try? await Task.sleep(for: .seconds(2))
					guard !Task.isCancelled else {
						return
					}
					withAnimation {
						toastVisible = false
					}
				}
			} catch {
				exportErrorMessage = error.localizedDescription
				showExportError = true
			}
		}
	}

	// MARK: - Helpers

	/// "Dnes – 22. srpna", "Zítra – 23. srpna", otherwise
	/// "Pátek 29. srpna – za 7 dní".
	private func sectionTitle(for date: Date) -> String {
		let relative = capitalizedFirst(AppFormat.relativeDay(date))
		switch AppFormat.relativeKind(date) {
		case .today, .tomorrow:
			return relative + " – " + AppFormat.dayMonth(date)
		case .other:
			return relative + " – " + AppFormat.inDays(AppFormat.daysUntil(date))
		}
	}

	private func initials(given: String, family: String) -> String {
		let combined = [given, family]
			.compactMap { $0.first.map(String.init) }
			.joined()
			.uppercased(with: AppFormat.locale)
		return combined.isEmpty ? "?" : combined
	}

	private func removeAssignment(_ contact: MatchedContact) {
		ManualAssignmentStore.remove(contactId: contact.id)
		Task { @MainActor in
			await AppRefresher.contactsChanged()
		}
	}

	/// Uppercases only the first letter (String.capitalized would also
	/// capitalise the month name, which is wrong in Czech).
	private func capitalizedFirst(_ text: String) -> String {
		guard let first = text.first else {
			return text
		}
		return String(first).uppercased(with: AppFormat.locale) + text.dropFirst()
	}
}

// MARK: - Row

private struct PersonRow: View {
	let contact: MatchedContact
	let isToday: Bool
	let isExported: Bool

	@ScaledMetric(relativeTo: .subheadline) private var avatarSize: CGFloat = 40

	private var showsMatchedName: Bool {
		contact.matchedName.compare(
			contact.givenName,
			options: [.caseInsensitive],
			range: nil,
			locale: AppFormat.locale
		) != .orderedSame
	}

	private var initials: String {
		let given = contact.givenName.first.map(String.init) ?? ""
		let family = contact.familyName.first.map(String.init) ?? ""
		let combined = (given + family).uppercased(with: AppFormat.locale)
		return combined.isEmpty ? "?" : combined
	}

	var body: some View {
		HStack(spacing: 12) {
			ZStack {
				Circle()
					.fill(Color.brandGreen)
				Text(initials)
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(.white)
			}
			.frame(width: avatarSize, height: avatarSize)
			// Decorative – the full name follows right next to it.
			.accessibilityHidden(true)
			VStack(alignment: .leading, spacing: 2) {
				Text(contact.fullName)
				if contact.isManual {
					Text("contact_assigned_manually")
						.font(.footnote)
						.foregroundStyle(.secondary)
				} else if contact.kind == .fuzzy {
					Text(String(format: String(localized: "contact_match_probable"), contact.matchedName))
						.font(.footnote)
						.foregroundStyle(.secondary)
				} else if showsMatchedName {
					Text(String(format: String(localized: "contact_match_calendar_name"), contact.matchedName))
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
			}
			Spacer()
			if isExported {
				Image(systemName: "checkmark.circle.fill")
					.foregroundStyle(Color.brandGreen)
					.accessibilityLabel("calendar_export_added")
			}
			if isToday {
				// Decorative – the section header already says "Dnes".
				Text(verbatim: "🎉")
					.accessibilityHidden(true)
			}
		}
		.padding(.vertical, 2)
	}
}

// MARK: - Empty state

private struct EmptyStateView<Actions: View>: View {
	let systemImage: String
	let title: LocalizedStringKey
	let message: LocalizedStringKey
	@ViewBuilder let actions: () -> Actions

	@ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 56

	var body: some View {
		VStack(spacing: 16) {
			Image(systemName: systemImage)
				.font(.system(size: iconSize))
				.foregroundStyle(Color.brandGreen)
				.accessibilityHidden(true)
			Text(title)
				.font(.title3.weight(.semibold))
				.multilineTextAlignment(.center)
			Text(message)
				.font(.subheadline)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
			actions()
				.padding(.top, 4)
		}
		.padding(.horizontal, 32)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color(.systemBackground))
	}
}

#Preview {
	PeopleView()
		.environmentObject(ContactsService.shared)
}
