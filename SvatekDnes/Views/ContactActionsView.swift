import SwiftUI
import Contacts
import ContactsUI
import MessageUI

/// Coordinates the "message a contact" and "show contact card" actions:
/// looks up the live CNContact behind a MatchedContact and drives the
/// sheets hosted by ContactActionsHost.
@MainActor
final class ContactActions: ObservableObject {
	struct MessageTarget: Identifiable {
		let id = UUID()
		let recipient: String
		let body: String
	}

	struct CardTarget: Identifiable {
		let id = UUID()
		let contact: CNContact
	}

	@Published var messageTarget: MessageTarget?
	@Published var cardTarget: CardTarget?
	@Published var showsMessageUnavailable = false

	func composeMessage(for contact: MatchedContact) {
		Task { @MainActor in
			guard MFMessageComposeViewController.canSendText(),
				let number = await Self.phoneNumber(for: contact.id) else {
				showsMessageUnavailable = true
				return
			}
			messageTarget = MessageTarget(
				recipient: number,
				body: String(localized: "message_nameday_wish")
			)
		}
	}

	func showCard(for contact: MatchedContact) {
		Task { @MainActor in
			guard let full = await Self.fullContact(for: contact.id) else {
				return
			}
			cardTarget = CardTarget(contact: full)
		}
	}

	private static func phoneNumber(for contactId: String) async -> String? {
		await Task.detached(priority: .userInitiated) {
			let store = CNContactStore()
			let keys = [CNContactPhoneNumbersKey as CNKeyDescriptor]
			let contact = try? store.unifiedContact(withIdentifier: contactId, keysToFetch: keys)
			return contact?.phoneNumbers.first?.value.stringValue
		}.value
	}

	private static func fullContact(for contactId: String) async -> CNContact? {
		let keys = [CNContactViewController.descriptorForRequiredKeys()]
		return await Task.detached(priority: .userInitiated) {
			let store = CNContactStore()
			return try? store.unifiedContact(withIdentifier: contactId, keysToFetch: keys)
		}.value
	}
}

/// Hosts the sheets and the fallback alert for ContactActions – apply
/// once per screen that offers the actions.
struct ContactActionsHost: ViewModifier {
	@ObservedObject var actions: ContactActions

	func body(content: Content) -> some View {
		content
			.sheet(item: $actions.messageTarget) { target in
				MessageComposeView(recipient: target.recipient, body: target.body)
					.ignoresSafeArea()
			}
			.sheet(item: $actions.cardTarget) { target in
				ContactCardView(contact: target.contact)
					.ignoresSafeArea()
			}
			.alert("contact_message_unavailable_title", isPresented: $actions.showsMessageUnavailable) {
				Button("common_ok", role: .cancel) {}
			} message: {
				Text("contact_message_unavailable_message")
			}
	}
}

/// Context-menu items shared by every row that represents a contact.
struct ContactActionButtons: View {
	let contact: MatchedContact
	let actions: ContactActions

	var body: some View {
		Button {
			actions.composeMessage(for: contact)
		} label: {
			Label("contact_send_message", systemImage: "message")
		}
		Button {
			actions.showCard(for: contact)
		} label: {
			Label("contact_show_card", systemImage: "person.crop.circle")
		}
	}
}

/// The system SMS/iMessage composer with a prefilled nameday wish.
private struct MessageComposeView: UIViewControllerRepresentable {
	let recipient: String
	let body: String

	@Environment(\.dismiss) private var dismiss

	func makeUIViewController(context: Context) -> MFMessageComposeViewController {
		let controller = MFMessageComposeViewController()
		controller.recipients = [recipient]
		controller.body = body
		controller.messageComposeDelegate = context.coordinator
		return controller
	}

	func updateUIViewController(_ controller: MFMessageComposeViewController, context: Context) {}

	func makeCoordinator() -> Coordinator {
		Coordinator { dismiss() }
	}

	final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
		private let dismiss: () -> Void

		init(dismiss: @escaping () -> Void) {
			self.dismiss = dismiss
		}

		func messageComposeViewController(
			_ controller: MFMessageComposeViewController,
			didFinishWith result: MessageComposeResult
		) {
			dismiss()
		}
	}
}

/// The system contact card (read-only, with the standard call/message
/// actions the Contacts app offers).
private struct ContactCardView: UIViewControllerRepresentable {
	let contact: CNContact

	func makeUIViewController(context: Context) -> UINavigationController {
		let controller = CNContactViewController(for: contact)
		controller.allowsEditing = false
		controller.allowsActions = true
		return UINavigationController(rootViewController: controller)
	}

	func updateUIViewController(_ controller: UINavigationController, context: Context) {}
}
