import Foundation

/// Matching of contact given names against calendar names.
///
/// Tiers, in order of confidence:
/// 1. exact (diacritic-preserving) calendar name
/// 2. diminutive dictionary with diacritics ("Láďa" -> Ladislav)
/// 3. diacritic-folded calendar name ("tomas" -> Tomáš)
/// 4. diacritic-folded diminutive dictionary ("kata" -> Kateřina)
/// 5. fuzzy stem matching ("Klárka" -> Klára) – only when unambiguous
enum NameMatching {
	enum Kind: String {
		case exact
		case diminutive
		case fuzzy
	}

	struct Match: Hashable {
		let month: Int
		let day: Int
		/// The calendar name that matched.
		let calendarName: String
		let kind: Kind
	}

	/// Lowercases, trims and strips diacritics: " Tomáš " -> "tomas".
	static func fold(_ s: String) -> String {
		s.trimmingCharacters(in: .whitespacesAndNewlines)
			.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "cs_CZ"))
			.lowercased()
	}

	/// Lowercases and trims, keeps diacritics: " Tomáš " -> "tomáš".
	static func lower(_ s: String) -> String {
		s.trimmingCharacters(in: .whitespacesAndNewlines)
			.lowercased(with: Locale(identifier: "cs_CZ"))
	}

	private struct Index {
		var exact: [String: Match] = [:]
		var folded: [String: Match] = [:]
		var diminutiveLower: [String: Match] = [:]
		var diminutiveFolded: [String: Match] = [:]
	}

	private static var cachedIndex: Index?
	private static let lock = NSLock()

	private static func buildIndex(store: NamedayStore) -> Index {
		var index = Index()
		// Two passes: canonical names first so they win over variants.
		for pass in 0..<2 {
			for entry in store.entries {
				let names = pass == 0 ? entry.names : entry.alt
				for name in names {
					let match = Match(month: entry.m, day: entry.d, calendarName: name, kind: .exact)
					let exactKey = lower(name)
					if index.exact[exactKey] == nil {
						index.exact[exactKey] = match
					}
					let foldedKey = fold(name)
					if index.folded[foldedKey] == nil {
						index.folded[foldedKey] = match
					}
				}
			}
		}
		// Resolve the diminutive dictionary against the calendar. Real
		// calendar names always win over a dictionary entry with the
		// same key, so "Lada" stays Lada while "Láďa" becomes Ladislav.
		for (diminutive, target) in Diminutives.map {
			guard let base = index.exact[lower(target)] ?? index.folded[fold(target)] else {
				continue
			}
			let match = Match(month: base.month, day: base.day, calendarName: base.calendarName, kind: .diminutive)
			let lowerKey = lower(diminutive)
			if index.exact[lowerKey] == nil, index.diminutiveLower[lowerKey] == nil {
				index.diminutiveLower[lowerKey] = match
			}
			let foldedKey = fold(diminutive)
			if index.folded[foldedKey] == nil, index.diminutiveFolded[foldedKey] == nil {
				index.diminutiveFolded[foldedKey] = match
			}
		}
		return index
	}

	/// Finds the nameday for a given first name, or nil when the name
	/// cannot be placed with confidence.
	static func match(givenName: String, store: NamedayStore = .shared) -> Match? {
		let trimmed = givenName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else {
			return nil
		}
		lock.lock()
		if cachedIndex == nil {
			cachedIndex = buildIndex(store: store)
		}
		let index = cachedIndex!
		lock.unlock()

		if let match = index.exact[lower(trimmed)] {
			return match
		}
		if let match = index.diminutiveLower[lower(trimmed)] {
			return match
		}
		let folded = fold(trimmed)
		if let match = index.folded[folded] {
			return match
		}
		if let match = index.diminutiveFolded[folded] {
			return match
		}
		return fuzzyMatch(folded: folded, index: index)
	}

	// MARK: - Fuzzy stem matching

	/// Folded diminutive suffixes, longest first.
	private static let foldedSuffixes = [
		"ousek", "icek", "inek", "anek", "enka", "ecka", "icka", "inka", "unka", "uska", "ulka",
		"ik", "ek", "ka", "ca",
	]

	/// Strips a typical diminutive suffix and looks for calendar names
	/// starting with the stem. A match counts only when every candidate
	/// points to one single calendar day – ambiguous stems ("mar", "alex")
	/// never match.
	private static func fuzzyMatch(folded: String, index: Index) -> Match? {
		var stems: [String] = []
		if folded.count >= 4 {
			stems.append(folded) // "kristy" -> Kristýna
		}
		for suffix in foldedSuffixes where folded.hasSuffix(suffix) {
			let stem = String(folded.dropLast(suffix.count))
			if stem.count >= 3 {
				stems.append(stem)
			}
		}

		for stem in stems {
			var days = Set<Int>()
			var best: Match?
			for (key, match) in index.folded where key.hasPrefix(stem) {
				days.insert(match.month * 100 + match.day)
				if best == nil || match.calendarName.count < best!.calendarName.count {
					best = match
				}
			}
			if days.count == 1, let base = best {
				return Match(month: base.month, day: base.day, calendarName: base.calendarName, kind: .fuzzy)
			}
		}
		return nil
	}

	/// Drops the cached index (call after remote data update).
	static func invalidate() {
		lock.lock()
		cachedIndex = nil
		lock.unlock()
	}
}
