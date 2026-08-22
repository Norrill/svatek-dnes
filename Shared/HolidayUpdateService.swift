import Foundation

struct RemoteHolidayDTO: Codable {
	let m: Int
	let d: Int
	let name: String
	let shortName: String?
	let kind: HolidayKind
}

/// Format of the remotely hosted data file (data/svatky.json in the repo).
struct RemoteDataFile: Codable {
	let version: Int
	let updated: String
	/// Replaces the built-in fixed holiday list when present.
	let fixedHolidays: [RemoteHolidayDTO]?
	/// Year (as string) -> movable holidays; replaces the computus for that year.
	let movable: [String: [RemoteHolidayDTO]]?
	/// Per-day overrides of the bundled nameday calendar.
	let namedayOverrides: [NamedayEntry]?
}

/// Downloads the remote data file roughly once a month and stores it in the
/// app group container so both the app and the widget can use it.
final class HolidayUpdateService {
	static let shared = HolidayUpdateService()

	/// Refresh when the stored data is older than 30 days.
	static let updateInterval: TimeInterval = 30 * 24 * 3600
	/// Do not retry failed downloads more than once a day.
	static let attemptInterval: TimeInterval = 24 * 3600

	private(set) var stored: RemoteDataFile?

	private var storageURL: URL {
		AppGroup.dataDirectory.appendingPathComponent("remote-data.json")
	}

	private init() {
		if let data = try? Data(contentsOf: storageURL) {
			stored = try? JSONDecoder().decode(RemoteDataFile.self, from: data)
		}
	}

	/// Downloads fresh data when the stored file is stale.
	/// Returns true when new data was stored.
	@discardableResult
	func updateIfStale(force: Bool = false) async -> Bool {
		let settings = AppSettings.shared
		if !force {
			if let last = settings.lastRemoteUpdate, Date().timeIntervalSince(last) < Self.updateInterval {
				return false
			}
			if let attempt = settings.lastRemoteAttempt, Date().timeIntervalSince(attempt) < Self.attemptInterval {
				return false
			}
		}
		settings.lastRemoteAttempt = Date()

		var request = URLRequest(url: AppGroup.remoteDataURL)
		request.timeoutInterval = 20
		request.cachePolicy = .reloadIgnoringLocalCacheData
		guard let (data, response) = try? await URLSession.shared.data(for: request),
			let http = response as? HTTPURLResponse, http.statusCode == 200,
			let decoded = try? JSONDecoder().decode(RemoteDataFile.self, from: data) else {
			return false
		}

		try? data.write(to: storageURL, options: .atomic)

		// Publish on the main actor – the UI and services read these on main.
		await MainActor.run {
			stored = decoded
			settings.lastRemoteUpdate = Date()
			HolidayCalendar.invalidate()
			NamedayStore.shared.reloadOverrides()
			NameMatching.invalidate()
		}
		return true
	}
}
