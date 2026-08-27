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

	/// Re-reads the permission after the user may have changed it in the
	/// system settings. `AppRefresher` is debounced by 30 s and would miss
	/// the usual trip out to Settings and straight back, so this runs on
	/// every foreground – it only touches the contacts when the status
	/// actually flipped.
	func refreshAuthorization() async {
		let wasAuthorized = isAuthorized
		status = CNContactStore.authorizationStatus(for: .contacts)
		switch (wasAuthorized, isAuthorized) {
		case (false, true):
			await reload()
		case (true, false):
			// Access revoked from the outside – drop the names we still hold.
			matched = []
			unmatched = []
		default:
			break
		}
	}

	/// Returns whether the matched set actually changed, so callers can skip
	/// rewriting the widget snapshot and rescheduling notifications when the
	/// address book came back identical.
	@discardableResult
	func reloadIfAuthorized() async -> Bool {
		status = CNContactStore.authorizationStatus(for: .contacts)
		guard isAuthorized else {
			return false
		}
		return await reload()
	}

	@discardableResult
	private func reload() async -> Bool {
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

					// Evaluate all candidates and keep the strongest match –
					// an exact nickname must beat a fuzzy guess on the given name.
					func rank(_ kind: NameMatching.Kind) -> Int {
						switch kind {
						case .exact: return 3
						case .diminutive: return 2
						case .fuzzy: return 1
						}
					}
					var found: NameMatching.Match?
					for candidate in candidates {
						guard let match = NameMatching.match(givenName: candidate) else {
							continue
						}
						if found == nil || rank(match.kind) > rank(found!.kind) {
							found = match
						}
						if match.kind == .exact {
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
			return false
		}
		guard result.matched != matched || result.unmatched != unmatched else {
			return false
		}
		matched = result.matched
		unmatched = result.unmatched
		return true
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
