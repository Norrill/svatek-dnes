import Foundation

/// Matching of contact given names against calendar names.
/// Exact (diacritic-preserving) matches are preferred over folded ones,
/// canonical calendar names over variants.
enum NameMatching {
	struct Match: Hashable {
		let month: Int
		let day: Int
		/// The calendar name that matched.
		let calendarName: String
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
					let match = Match(month: entry.m, day: entry.d, calendarName: name)
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
		return index
	}

	/// Finds the nameday for a given first name, or nil when the name
	/// is not in the calendar. Diacritic-exact match wins over folded.
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

		if let exact = index.exact[lower(trimmed)] {
			return exact
		}
		return index.folded[fold(trimmed)]
	}

	/// Drops the cached index (call after remote data update).
	static func invalidate() {
		lock.lock()
		cachedIndex = nil
		lock.unlock()
	}
}
