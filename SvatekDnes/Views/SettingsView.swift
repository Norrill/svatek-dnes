import SwiftUI

struct SettingsView: View {
	@EnvironmentObject var settings: AppSettings

	@State private var isUpdating = false
	@State private var updateMessage: String?
	@State private var updateSucceeded = false
	@State private var updateMessageToken = UUID()

	private static let updateDateFormatter: DateFormatter = {
		let f = DateFormatter()
		f.locale = CzechFormat.locale
		f.dateStyle = .medium
		f.timeStyle = .short
		return f
	}()

	/// Bridges `notificationMinutesFromMidnight` to a `Date` for the picker.
	private var notificationTime: Binding<Date> {
		Binding(
			get: {
				let calendar = Calendar.current
				let startOfDay = calendar.startOfDay(for: Date())
				return calendar.date(
					byAdding: .minute,
					value: settings.notificationMinutesFromMidnight,
					to: startOfDay
				) ?? startOfDay
			},
			set: { newValue in
				let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
				settings.notificationMinutesFromMidnight = (comps.hour ?? 8) * 60 + (comps.minute ?? 0)
			}
		)
	}

	private var lastUpdateText: String {
		if let date = settings.lastRemoteUpdate {
			return Self.updateDateFormatter.string(from: date)
		}
		return "zatím nikdy – vestavěná data"
	}

	private var appVersion: String {
		Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
	}

	var body: some View {
		NavigationStack {
			Form {
				notificationTogglesSection
				allNamedaysSection
				dayBeforeSection
				notificationTimeSection
				dataSection
				aboutSection
			}
			.navigationTitle("Nastavení")
			.tint(Color.brandGreen)
		}
		.onChange(of: settings.notifyContacts) { rescheduleNotifications() }
		.onChange(of: settings.notifyHolidays) { rescheduleNotifications() }
		.onChange(of: settings.notifyAllNamedays) { rescheduleNotifications() }
		.onChange(of: settings.notifyDayBefore) { rescheduleNotifications() }
		.onChange(of: settings.notificationMinutesFromMidnight) { rescheduleNotifications() }
	}

	// MARK: - Sections

	private var notificationTogglesSection: some View {
		Section("Oznámení") {
			Toggle("Svátky vašich kontaktů", isOn: $settings.notifyContacts)
			Toggle("Státní svátky a dny volna", isOn: $settings.notifyHolidays)
		}
	}

	private var allNamedaysSection: some View {
		Section {
			Toggle("Každodenní jmeniny", isOn: $settings.notifyAllNamedays)
		} footer: {
			Text("Oznámení o svátku pošleme každý den – i když jméno nemáte v kontaktech.")
		}
	}

	private var dayBeforeSection: some View {
		Section {
			Toggle("Připomenout večer předem", isOn: $settings.notifyDayBefore)
				.disabled(!settings.notifyContacts)
		} footer: {
			Text("Připomínka přijde den předem v 19.00.")
		}
	}

	private var notificationTimeSection: some View {
		Section {
			DatePicker(
				"Čas oznámení",
				selection: notificationTime,
				displayedComponents: .hourAndMinute
			)
		}
	}

	private var dataSection: some View {
		Section {
			LabeledContent("Poslední aktualizace", value: lastUpdateText)
			Button {
				runUpdate()
			} label: {
				HStack {
					Text(isUpdating ? "Aktualizuji…" : "Aktualizovat nyní")
					if isUpdating {
						Spacer()
						ProgressView()
					}
				}
			}
			.disabled(isUpdating)
			if let updateMessage {
				Text(updateMessage)
					.font(.footnote)
					.foregroundStyle(updateSucceeded ? Color.accentColor : Color.secondary)
			}
		} header: {
			Text("Data svátků")
		} footer: {
			Text("Kalendář svátků se aktualizuje automaticky přibližně jednou měsíčně.")
		}
	}

	private var aboutSection: some View {
		Section {
			LabeledContent("Verze", value: appVersion)
			LabeledContent("Zdroj dat", value: "český občanský kalendář")
		} header: {
			Text("O aplikaci")
		} footer: {
			Text("Kontakty zůstávají ve vašem zařízení. Aplikace neodesílá žádná osobní data.")
		}
	}

	// MARK: - Actions

	private func rescheduleNotifications() {
		Task { @MainActor in
			await NotificationScheduler.shared.requestAuthorizationIfNeeded()
			await NotificationScheduler.shared.rescheduleAll()
		}
	}

	private func runUpdate() {
		guard !isUpdating else {
			return
		}
		isUpdating = true
		updateMessage = nil
		Task { @MainActor in
			let ok = await HolidayUpdateService.shared.updateIfStale(force: true)
			isUpdating = false
			updateSucceeded = ok
			updateMessage = ok
				? "Data byla aktualizována."
				: "Aktualizace se nepodařila – zkusíme to později automaticky."

			// Hide the result text after a while, unless a newer run replaced it.
			let token = UUID()
			updateMessageToken = token
			try? await Task.sleep(for: .seconds(6))
			if updateMessageToken == token {
				withAnimation {
					updateMessage = nil
				}
			}
		}
	}
}

#Preview {
	SettingsView()
		.environmentObject(AppSettings.shared)
}
