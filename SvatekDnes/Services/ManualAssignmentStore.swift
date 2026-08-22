import Foundation

/// User-made nameday assignments for contacts the matcher could not place
/// automatically. Maps contact identifier -> "m-d" in the shared app-group
/// defaults, so assignments survive re-imports and reach the widget snapshot
/// through the regular contact reload.
enum ManualAssignmentStore {
	private static let key = "manualNamedayAssignments"

	static func all(defaults: UserDefaults = AppGroup.defaults) -> [String: (month: Int, day: Int)] {
		guard let raw = defaults.dictionary(forKey: key) as? [String: String] else {
			return [:]
		}
		var result: [String: (month: Int, day: Int)] = [:]
		for (id, value) in raw {
			let parts = value.split(separator: "-").compactMap { Int($0) }
			guard parts.count == 2, (1...12).contains(parts[0]), (1...31).contains(parts[1]) else {
				continue
			}
			result[id] = (parts[0], parts[1])
		}
		return result
	}

	static func assignment(for contactId: String, defaults: UserDefaults = AppGroup.defaults) -> (month: Int, day: Int)? {
		all(defaults: defaults)[contactId]
	}

	static func assign(contactId: String, month: Int, day: Int, defaults: UserDefaults = AppGroup.defaults) {
		var raw = (defaults.dictionary(forKey: key) as? [String: String]) ?? [:]
		raw[contactId] = "\(month)-\(day)"
		defaults.set(raw, forKey: key)
	}

	static func remove(contactId: String, defaults: UserDefaults = AppGroup.defaults) {
		var raw = (defaults.dictionary(forKey: key) as? [String: String]) ?? [:]
		raw.removeValue(forKey: contactId)
		defaults.set(raw, forKey: key)
	}
}
