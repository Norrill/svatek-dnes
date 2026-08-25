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

	/// Skip sending a context identical to the last one – the refresh runs
	/// on every activation and the payload usually has not changed.
	private var lastPayloadHash: Int?

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
		guard WCSession.isSupported() else {
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
		guard !context.isEmpty else {
			return
		}

		let hash = (context["snapshot"] as? Data)?.hashValue ?? 0
			^ ((context["remoteData"] as? Data)?.hashValue ?? 0)
		guard hash != lastPayloadHash else {
			return
		}

		do {
			try session.updateApplicationContext(context)
			lastPayloadHash = hash
		} catch {
			// Transient – the next refresh tries again.
			lastPayloadHash = nil
		}
	}
}

extension WatchSync: WCSessionDelegate {
	func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
	}

	/// Switching to a different watch invalidates what we last sent.
	func sessionDidBecomeInactive(_ session: WCSession) {
		lastPayloadHash = nil
	}

	func sessionDidDeactivate(_ session: WCSession) {
		lastPayloadHash = nil
		WCSession.default.activate()
	}

	func sessionWatchStateDidChange(_ session: WCSession) {
		// A newly paired or freshly installed watch has no context yet.
		lastPayloadHash = nil
	}
}
