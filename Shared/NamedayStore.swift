import Foundation

private final class BundleToken {}

/// Loads and serves the Czech nameday calendar (366 days).
/// Bundled data can be partially overridden by the remotely updated file.
final class NamedayStore {
	static let shared = NamedayStore()

	private(set) var entries: [NamedayEntry] = []
	private var byDay: [Int: NamedayEntry] = [:]

	private init() {
		load()
	}

	private static func dayKey(_ month: Int, _ day: Int) -> Int {
		month * 100 + day
	}

	private func load() {
		let bundle = Bundle(for: BundleToken.self)
		guard let url = bundle.url(forResource: "namedays", withExtension: "json"),
			let data = try? Data(contentsOf: url),
			let decoded = try? JSONDecoder().decode([NamedayEntry].self, from: data) else {
			assertionFailure("namedays.json missing or invalid")
			return
		}
		var result = decoded
		if let overrides = HolidayUpdateService.shared.stored?.namedayOverrides {
			var index = Dictionary(uniqueKeysWithValues: result.map { (Self.dayKey($0.m, $0.d), $0) })
			for override in overrides {
				index[Self.dayKey(override.m, override.d)] = override
			}
			result = index.values.sorted { ($0.m, $0.d) < ($1.m, $1.d) }
		}
		entries = result
		byDay = Dictionary(uniqueKeysWithValues: result.map { (Self.dayKey($0.m, $0.d), $0) })
	}

	/// Re-applies remote overrides (call after a successful data update).
	func reloadOverrides() {
		load()
	}

	func entry(month: Int, day: Int) -> NamedayEntry {
		byDay[Self.dayKey(month, day)] ?? NamedayEntry(m: month, d: day, names: [], alt: [])
	}

	func entry(for date: Date) -> NamedayEntry {
		let comps = Calendar.czech.dateComponents([.month, .day], from: date)
		return entry(month: comps.month!, day: comps.day!)
	}

	func month(_ m: Int) -> [NamedayEntry] {
		entries.filter { $0.m == m }
	}

	/// Diacritic- and case-insensitive search across canonical and variant names.
	func search(_ query: String) -> [NamedayEntry] {
		let folded = NameMatching.fold(query)
		guard !folded.isEmpty else {
			return []
		}
		return entries.filter { entry in
			entry.allNames.contains { NameMatching.fold($0).hasPrefix(folded) }
		}
	}

	/// Next occurrence of the m/d combination on or after the given date.
	/// Handles 29 February by rolling forward to the next leap year.
	func nextDate(month: Int, day: Int, onOrAfter date: Date) -> Date? {
		let calendar = Calendar.czech
		let start = calendar.startOfDay(for: date)
		let todayComps = calendar.dateComponents([.month, .day], from: start)
		if todayComps.month == month && todayComps.day == day {
			return start
		}
		return calendar.nextDate(
			after: start,
			matching: DateComponents(month: month, day: day),
			matchingPolicy: .strict
		)
	}
}
