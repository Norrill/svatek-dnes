import Foundation

/// Contact-match snapshot shared with the widget extension.
/// The widget can compute namedays and holidays itself from the bundled
/// data; only contact matches need to be handed over by the app
/// (the widget must not read the contact database).
struct WidgetSnapshot: Codable {
	var createdAt: Date
	/// Key "m-d" -> given names of contacts having their nameday that day.
	var contactsByDay: [String: [String]]

	static func key(month: Int, day: Int) -> String {
		"\(month)-\(day)"
	}

	func contacts(month: Int, day: Int) -> [String] {
		contactsByDay[Self.key(month: month, day: day)] ?? []
	}
}

enum SnapshotStore {
	static var fileURL: URL {
		AppGroup.dataDirectory.appendingPathComponent("widget-snapshot.json")
	}

	static func save(_ snapshot: WidgetSnapshot) {
		guard let data = try? JSONEncoder().encode(snapshot) else {
			return
		}
		try? data.write(to: fileURL, options: .atomic)
	}

	static func load() -> WidgetSnapshot? {
		guard let data = try? Data(contentsOf: fileURL) else {
			return nil
		}
		return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
	}

	/// Rebuilds the snapshot from the current contact matches.
	static func update(with contacts: [MatchedContact]) {
		var byDay: [String: [String]] = [:]
		for contact in contacts {
			let key = WidgetSnapshot.key(month: contact.month, day: contact.day)
			byDay[key, default: []].append(contact.givenName)
		}
		// Two contacts named Jana must not produce "Jana a Jana".
		let deduped = byDay.mapValues { names in
			var seen = Set<String>()
			return names.filter { !$0.isEmpty && seen.insert($0).inserted }
		}
		save(WidgetSnapshot(createdAt: Date(), contactsByDay: deduped))
	}
}
