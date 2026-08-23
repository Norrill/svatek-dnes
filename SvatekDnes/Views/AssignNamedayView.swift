import SwiftUI

/// A contact the assignment sheet is opened for – either an unmatched
/// contact or a matched one whose day the user wants to change.
struct AssignmentTarget: Identifiable {
	let id: String
	let givenName: String
}

/// Full-year day picker used to assign a nameday to a contact.
struct AssignNamedayView: View {
	let target: AssignmentTarget

	@Environment(\.dismiss) private var dismiss
	@State private var query = ""

	private var trimmedQuery: String {
		query.trimmingCharacters(in: .whitespaces)
	}

	var body: some View {
		NavigationStack {
			List {
				if trimmedQuery.isEmpty {
					ForEach(1...12, id: \.self) { month in
						Section(AppFormat.monthName(month).capitalized(with: AppFormat.locale)) {
							ForEach(NamedayStore.shared.month(month), id: \.self) { entry in
								row(entry)
							}
						}
					}
				} else {
					let results = NamedayStore.shared.search(trimmedQuery)
					if results.isEmpty {
						ContentUnavailableView.search(text: trimmedQuery)
					} else {
						ForEach(results, id: \.self) { entry in
							row(entry)
						}
					}
				}
			}
			.searchable(text: $query, prompt: "Hledat jméno")
			.navigationTitle("Svátek – \(target.givenName)")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Zrušit") {
						dismiss()
					}
				}
			}
		}
	}

	private func row(_ entry: NamedayEntry) -> some View {
		Button {
			assign(entry)
		} label: {
			HStack(spacing: 12) {
				Text(AppFormat.shortDate(month: entry.m, day: entry.d))
					.font(.subheadline.monospacedDigit())
					.foregroundStyle(.secondary)
					.frame(width: 56, alignment: .leading)
				VStack(alignment: .leading, spacing: 2) {
					if entry.displayText.isEmpty {
						Text("bez jmenin")
							.foregroundStyle(.secondary)
					} else {
						Text(entry.displayText)
							.foregroundStyle(.primary)
					}
					if let variants = entry.variantsText {
						Text(variants)
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}
			}
		}
	}

	private func assign(_ entry: NamedayEntry) {
		ManualAssignmentStore.assign(contactId: target.id, month: entry.m, day: entry.d)
		dismiss()
		Task { @MainActor in
			await AppRefresher.contactsChanged()
		}
	}
}

#Preview {
	AssignNamedayView(target: AssignmentTarget(id: "x", givenName: "Kate"))
}
