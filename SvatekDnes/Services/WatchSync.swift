import Foundation
import WatchConnectivity

/// Pushes contact matches to the paired Apple Watch.
///
/// The watch computes namedays and holidays itself from the bundled data –
/// only the contact matches genuinely have to come from here, because the
/// Contacts framework does not exist on watchOS and app group containers do
/// not span devices. The downloaded holiday overrides ride along so the
/// watch needs no networking of its own.
final class WatchSync: NSObject {
	static let shared = WatchSync()

	// Nil, not empty, until the app has loaded contacts: an early resend
	// would otherwise wipe the names the watch already has.
	private var contacts: [MatchedContact]?

	private override init() {
		super.init()
	}

	func activate() {
		guard WCSession.isSupported() else {
			return
		}
		let session = WCSession.default
		session.delegate = self
		session.activate()
	}

	/// Sends the current contact matches. Cheap to call often.
	func push(contacts: [MatchedContact]) {
		self.contacts = contacts
		send()
	}

	private func send() {
		guard let contacts, WCSession.isSupported() else {
			return
		}
		let session = WCSession.default
		// isPaired/isWatchAppInstalled are iOS-only and false on a phone
		// without a watch – nothing to do then.
		guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else {
			return
		}

		var context: [String: Any] = [:]
		if let encoded = try? JSONEncoder().encode(SnapshotStore.snapshot(from: contacts)) {
			context["snapshot"] = encoded
		}
		if let remote = try? Data(contentsOf: SnapshotStore.remoteDataURL) {
			context["remoteData"] = remote
		}
		try? session.updateApplicationContext(context)
	}
}

extension WatchSync: WCSessionDelegate {
	func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
		DispatchQueue.main.async {
			self.send()
		}
	}

	func sessionDidBecomeInactive(_ session: WCSession) {
	}

	func sessionDidDeactivate(_ session: WCSession) {
		WCSession.default.activate()
	}

	func sessionWatchStateDidChange(_ session: WCSession) {
		DispatchQueue.main.async {
			self.send()
		}
	}
}
