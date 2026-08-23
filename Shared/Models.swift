import Foundation

/// One day of the Czech civil nameday calendar.
/// `names` are the canonical calendar names, `alt` are additional variants
/// used for contact matching (spelling variants, foreign forms…).
struct NamedayEntry: Codable, Hashable {
	let m: Int
	let d: Int
	let names: [String]
	let alt: [String]

	var allNames: [String] { names + alt }

	/// "Karina", "Petr a Pavel", "" for days without a nameday.
	var displayText: String { names.joinedNames }

	/// Variants text for secondary UI lines: "též Vasil, Ábel a Dětmar".
	var variantsText: String? {
		alt.isEmpty ? nil : String(localized: "též \(alt.joinedNames)")
	}
}

enum HolidayKind: String, Codable {
	/// Státní svátek (zákon č. 245/2000 Sb.)
	case state
	/// Ostatní svátek – den pracovního klidu (Nový rok, Velikonoce, 1. 5., Vánoce…)
	case other
	/// Významný den bez volna (Tři králové, MDŽ, Den matek…)
	case significant
}

/// A holiday resolved for a concrete year.
struct Holiday: Identifiable, Hashable {
	/// Full official name, e.g. "Den vzniku samostatného československého státu".
	let name: String
	/// Compact name for widgets and lists, e.g. "Vznik Československa".
	let shortName: String
	let kind: HolidayKind
	let month: Int
	let day: Int

	var isDayOff: Bool { kind != .significant }
	var id: String { "\(month)-\(day)-\(shortName)" }

	/// Localized label of the category.
	var kindLabel: String {
		switch kind {
		case .state: return String(localized: "státní svátek")
		case .other: return String(localized: "den pracovního klidu")
		case .significant: return String(localized: "významný den")
		}
	}
}

/// How a contact was linked to its calendar day.
enum ContactMatchKind: String, Codable {
	/// The first name is a calendar name (incl. diacritic-folded form).
	case exact
	/// Known diminutive from the dictionary ("Káťa" -> Kateřina).
	case diminutive
	/// Unambiguous stem guess ("Klárka" -> Klára) – shown as tentative.
	case fuzzy
	/// Assigned by the user.
	case manual
}

/// A contact whose given name (or nickname) matches a calendar name.
struct MatchedContact: Identifiable, Hashable, Codable {
	let id: String
	let givenName: String
	let familyName: String
	/// The calendar name that matched (may differ in diacritics from the contact).
	let matchedName: String
	let month: Int
	let day: Int
	var kind: ContactMatchKind = .exact

	var isManual: Bool { kind == .manual }

	var fullName: String {
		[givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
	}
}

extension Array where Element == String {
	/// Locale-aware name list: "Petr a Pavel" / "Petr and Pavel" / "Petr und Pavel".
	var joinedNames: String {
		switch count {
		case 0:
			return ""
		case 1:
			return self[0]
		default:
			return ListFormatter.localizedString(byJoining: self)
		}
	}
}
