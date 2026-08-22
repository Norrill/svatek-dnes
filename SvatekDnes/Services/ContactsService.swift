import Foundation
import Contacts

/// Reads given names (and nicknames) from the user's contacts and matches
/// them against the nameday calendar. Contact data never leaves the device.
@MainActor
final class ContactsService: ObservableObject {
	static let shared = ContactsService()

	@Published private(set) var status: CNAuthorizationStatus
	@Published private(set) var matched: [MatchedContact] = []
	@Published private(set) var unmatchedCount: Int = 0

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
		let result = await Task.detached(priority: .userInitiated) { () -> (matched: [MatchedContact], unmatched: Int)? in
			let store = CNContactStore()
			let keys: [CNKeyDescriptor] = [
				CNContactIdentifierKey as CNKeyDescriptor,
				CNContactGivenNameKey as CNKeyDescriptor,
				CNContactFamilyNameKey as CNKeyDescriptor,
				CNContactNicknameKey as CNKeyDescriptor,
			]
			let request = CNContactFetchRequest(keysToFetch: keys)
			request.sortOrder = .givenName
			var matched: [MatchedContact] = []
			var unmatched = 0
			do {
				try store.enumerateContacts(with: request) { contact, _ in
					let candidates = [contact.givenName, contact.nickname]
						.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
					guard !candidates.isEmpty else {
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
							givenName: contact.givenName.isEmpty ? contact.nickname : contact.givenName,
							familyName: contact.familyName,
							matchedName: match.calendarName,
							month: match.month,
							day: match.day
						))
					} else {
						unmatched += 1
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
		unmatchedCount = result.unmatched
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
