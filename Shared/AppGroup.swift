import Foundation

/// Central constants shared by the app and the widget extension.
enum AppGroup {
	static let identifier = "group.cz.fh.svatekdnes"
	static let refreshTaskIdentifier = "cz.fh.svatekdnes.refresh"

	/// Remote data file used for the monthly refresh of holiday/nameday data.
	/// Hosted in the app's own GitHub repository under `data/svatky.json`.
	static let remoteDataURL = URL(string: "https://raw.githubusercontent.com/Norrill/svatek-dnes/main/data/svatky.json")!

	static var defaults: UserDefaults {
		UserDefaults(suiteName: identifier) ?? .standard
	}

	static var containerURL: URL? {
		FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
	}

	/// Directory for shared data files; falls back to Caches when the app
	/// group container is unavailable (e.g. unsigned development builds).
	static var dataDirectory: URL {
		containerURL ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
	}
}
