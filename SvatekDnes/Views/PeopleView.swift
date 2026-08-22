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

	var body: some View {
		NavigationStack {
			content
				.navigationTitle("Lidé")
				.overlay(alignment: .bottom) {
					if toastVisible {
						toast
					}
				}
				.alert("Nepodařilo se přidat do kalendáře", isPresented: $showExportError) {
					Button("OK", role: .cancel) {}
				} message: {
					Text(exportErrorMessage ?? "Zkuste to prosím znovu.")
				}
		}
	}

	@ViewBuilder
	private var content: some View {
		if contacts.canRequestAccess {
			requestAccessState
		} else if !contacts.isAuthorized {
			deniedState
		} else if contacts.matched.isEmpty {
			noMatchesState
		} else {
			peopleList
		}
	}

	// MARK: - Permission states

	private var requestAccessState: some View {
		EmptyStateView(
			systemImage: "person.2.badge.plus",
			title: "Svátky vašich blízkých",
			message: "Aplikace porovná křestní jména z vašich kontaktů s kalendářem jmenin a ukáže, kdo má kdy svátek. Vše probíhá jen ve vašem zařízení – kontakty nikam neodesíláme."
		) {
			Button {
				Task {
					await contacts.requestAccessAndLoad()
				}
			} label: {
				Text("Povolit přístup ke kontaktům")
					.fontWeight(.semibold)
			}
			.buttonStyle(.borderedProminent)
			.controlSize(.large)
		}
	}

	private var deniedState: some View {
		EmptyStateView(
			systemImage: "person.2.slash",
			title: "Přístup ke kontaktům je odepřen",
			message: "Bez přístupu ke kontaktům nemůžeme zjistit, kdo z vašich blízkých slaví svátek. Přístup můžete kdykoli povolit v Nastavení."
		) {
			if let url = URL(string: UIApplication.openSettingsURLString) {
				Link("Otevřít Nastavení", destination: url)
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
				title: "Žádný kontakt se svátkem jsme nenašli",
				message: contacts.unmatchedCount > 0
					? unmatchedFooterText(contacts.unmatchedCount)
					: "V kontaktech jsme nenašli žádné křestní jméno z kalendáře jmenin."
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
						.swipeActions(edge: .trailing, allowsFullSwipe: false) {
							Button {
								addToCalendar(contact, date: group.date)
							} label: {
								Label("Přidat do kalendáře", systemImage: "calendar.badge.plus")
							}
							.tint(Color.brandGreen)
						}
						.contextMenu {
							Button {
								addToCalendar(contact, date: group.date)
							} label: {
								Label("Přidat do kalendáře", systemImage: "calendar.badge.plus")
							}
						}
					}
				} header: {
					Text(sectionTitle(for: group.date))
						.foregroundStyle(isToday ? Color.brandGreen : Color.secondary)
						.fontWeight(isToday ? .semibold : .regular)
				}
			}
			if contacts.unmatchedCount > 0 {
				Section {
				} footer: {
					Text(unmatchedFooterText(contacts.unmatchedCount))
				}
			}
		}
		.refreshable {
			await contacts.reloadIfAuthorized()
		}
	}

	private var toast: some View {
		Label("Přidáno do kalendáře", systemImage: "checkmark.circle.fill")
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
					title: "Svátek má \(contact.givenName)",
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

	/// "Dnes – 22. srpna", "Zítra – 23. srpna", otherwise "Pátek 29. srpna"
	/// (the weekday form already contains the date, so it is not repeated).
	private func sectionTitle(for date: Date) -> String {
		let relative = CzechFormat.relativeDay(date)
		if relative == "dnes" || relative == "zítra" {
			return capitalizedFirst(relative) + " – " + CzechFormat.dayMonth(date)
		}
		return capitalizedFirst(relative)
	}

	/// Uppercases only the first letter (String.capitalized would also
	/// capitalise the month name, which is wrong in Czech).
	private func capitalizedFirst(_ text: String) -> String {
		guard let first = text.first else {
			return text
		}
		return String(first).uppercased(with: CzechFormat.locale) + text.dropFirst()
	}

	/// Czech plural selection: 1 → one, 2–4 → few, otherwise many.
	private func czechPlural(_ n: Int, one: String, few: String, many: String) -> String {
		switch n {
		case 1:
			return one
		case 2...4:
			return few
		default:
			return many
		}
	}

	private func unmatchedFooterText(_ n: Int) -> String {
		let noun = czechPlural(n, one: "kontaktu", few: "kontaktů", many: "kontaktů")
		return "U \(n) \(noun) se nepodařilo svátek určit."
	}
}

// MARK: - Row

private struct PersonRow: View {
	let contact: MatchedContact
	let isToday: Bool
	let isExported: Bool

	private var showsMatchedName: Bool {
		contact.matchedName.compare(
			contact.givenName,
			options: [.caseInsensitive],
			range: nil,
			locale: CzechFormat.locale
		) != .orderedSame
	}

	private var initials: String {
		let given = contact.givenName.first.map(String.init) ?? ""
		let family = contact.familyName.first.map(String.init) ?? ""
		let combined = (given + family).uppercased(with: CzechFormat.locale)
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
			.frame(width: 40, height: 40)
			VStack(alignment: .leading, spacing: 2) {
				Text(contact.fullName)
				if showsMatchedName {
					Text("v kalendáři jako \(contact.matchedName)")
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
			}
			Spacer()
			if isExported {
				Image(systemName: "checkmark.circle.fill")
					.foregroundStyle(Color.brandGreen)
					.accessibilityLabel("Přidáno do kalendáře")
			}
			if isToday {
				Text("🎉")
			}
		}
		.padding(.vertical, 2)
	}
}

// MARK: - Empty state

private struct EmptyStateView<Actions: View>: View {
	let systemImage: String
	let title: String
	let message: String
	@ViewBuilder let actions: () -> Actions

	var body: some View {
		VStack(spacing: 16) {
			Image(systemName: systemImage)
				.font(.system(size: 56))
				.foregroundStyle(Color.brandGreen)
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
