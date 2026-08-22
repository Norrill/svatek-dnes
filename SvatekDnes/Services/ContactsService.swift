import Foundation
import Contacts

/// A contact whose first name could not be matched to the calendar
/// (candidate for a manual nameday assignment).
struct UnmatchedContact: Identifiable, Hashable {
	let id: String
	let givenName: String
	let familyName: String

	var fullName: String {
		[givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
	}
}

/// Reads given names (and nicknames) from the user's contacts and matches
/// them against the nameday calendar. Contact data never leaves the device.
@MainActor
final class ContactsService: ObservableObject {
	static let shared = ContactsService()

	@Published private(set) var status: CNAuthorizationStatus
	@Published private(set) var matched: [MatchedContact] = []
	@Published private(set) var unmatched: [UnmatchedContact] = []

	var unmatchedCount: Int { unmatched.count }

	private init() {
		status = CNContactStore.authorizationStatus(for: .contacts)
	}

	var isAuthorized: Bool {
		if status == .authorized {
			return true
		}
		if #available(iOS 18.0, *), status == .limited {
			return true
		}
		return false
	}

	var canRequestAccess: Bool {
		status == .notDetermined
	}

	/// Asks for permission (when possible) and loads contacts.
	@discardableResult
	func requestAccessAndLoad() async -> Bool {
		if status == .notDetermined {
			let store = CNContactStore()
			_ = try? await store.requestAccess(for: .contacts)
			status = CNContactStore.authorizationStatus(for: .contacts)
		}
		guard isAuthorized else {
			return false
		}
		await reload()
		return true
	}

	func reloadIfAuthorized() async {
		status = CNContactStore.authorizationStatus(for: .contacts)
		guard isAuthorized else {
			return
		}
		await reload()
	}

	private func reload() async {
		let result = await Task.detached(priority: .userInitiated) { () -> (matched: [MatchedContact], unmatched: [UnmatchedContact])? in
			let store = CNContactStore()
			let keys: [CNKeyDescriptor] = [
				CNContactIdentifierKey as CNKeyDescriptor,
				CNContactGivenNameKey as CNKeyDescriptor,
				CNContactFamilyNameKey as CNKeyDescriptor,
				CNContactNicknameKey as CNKeyDescriptor,
			]
			let request = CNContactFetchRequest(keysToFetch: keys)
			request.sortOrder = .givenName
			let assignments = ManualAssignmentStore.all()
			var matched: [MatchedContact] = []
			var unmatched: [UnmatchedContact] = []
			do {
				try store.enumerateContacts(with: request) { contact, _ in
					let candidates = [contact.givenName, contact.nickname]
						.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
					guard !candidates.isEmpty else {
						return
					}
					let displayGiven = contact.givenName.isEmpty ? contact.nickname : contact.givenName

					// A manual assignment always wins over automatic matching.
					if let manual = assignments[contact.identifier] {
						let entry = NamedayStore.shared.entry(month: manual.month, day: manual.day)
						matched.append(MatchedContact(
							id: contact.identifier,
							givenName: displayGiven,
							familyName: contact.familyName,
							matchedName: entry.names.first ?? displayGiven,
							month: manual.month,
							day: manual.day,
							kind: .manual
						))
						return
					}

					var found: NameMatching.Match?
					for candidate in candidates {
						if let match = NameMatching.match(givenName: candidate) {
							found = match
							break
						}
					}
					if let match = found {
						matched.append(MatchedContact(
							id: contact.identifier,
							givenName: displayGiven,
							familyName: contact.familyName,
							matchedName: match.calendarName,
							month: match.month,
							day: match.day,
							kind: ContactMatchKind(rawValue: match.kind.rawValue) ?? .exact
						))
					} else {
						unmatched.append(UnmatchedContact(
							id: contact.identifier,
							givenName: displayGiven,
							familyName: contact.familyName
						))
					}
				}
			} catch {
				// Enumeration failed – keep the previous published state.
				return nil
			}
			return (matched, unmatched)
		}.value

		guard let result else {
			return
		}
		matched = result.matched
		unmatched = result.unmatched
	}

	/// Contacts having their nameday on the given calendar day.
	func matches(month: Int, day: Int) -> [MatchedContact] {
		matched.filter { $0.month == month && $0.day == day }
	}

	/// Matched contacts sorted by their next upcoming nameday.
	func upcoming(from date: Date = Date()) -> [(date: Date, contacts: [MatchedContact])] {
		let store = NamedayStore.shared
		var byDate: [Date: [MatchedContact]] = [:]
		for contact in matched {
			guard let next = store.nextDate(month: contact.month, day: contact.day, onOrAfter: date) else {
				continue
			}
			byDate[next, default: []].append(contact)
		}
		return byDate
			.sorted { $0.key < $1.key }
			.map { (date: $0.key, contacts: $0.value.sorted { $0.givenName < $1.givenName }) }
	}
}
