import SwiftUI

struct SettingsView: View {
	@EnvironmentObject var settings: AppSettings

	@State private var isUpdating = false
	@State private var updateMessage: String?
	@State private var updateSucceeded = false
	@State private var updateMessageToken = UUID()

	private static let updateDateFormatter: DateFormatter = {
		let f = DateFormatter()
		f.locale = AppFormat.locale
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
		return String(localized: "settings_last_update_never")
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
			.navigationTitle("settings_title")
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
		Section("settings_notifications_header") {
			Toggle("settings_notify_contacts", isOn: $settings.notifyContacts)
			Toggle("settings_notify_holidays", isOn: $settings.notifyHolidays)
		}
	}

	private var allNamedaysSection: some View {
		Section {
			Toggle("settings_notify_all_namedays", isOn: $settings.notifyAllNamedays)
		} footer: {
			Text("settings_notify_all_footer")
		}
	}

	private var dayBeforeSection: some View {
		Section {
			Toggle("settings_notify_day_before", isOn: $settings.notifyDayBefore)
				.disabled(!settings.notifyContacts)
		} footer: {
			Text("settings_notify_day_before_footer")
		}
	}

	private var notificationTimeSection: some View {
		Section {
			DatePicker(
				"settings_notification_time",
				selection: notificationTime,
				displayedComponents: .hourAndMinute
			)
		}
	}

	private var dataSection: some View {
		Section {
			LabeledContent("settings_last_update", value: lastUpdateText)
			Button {
				runUpdate()
			} label: {
				HStack {
					Text(isUpdating
						? String(localized: "settings_updating")
						: String(localized: "settings_update_now"))
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
			Text("settings_data_header")
		} footer: {
			Text("settings_data_footer")
		}
	}

	private var aboutSection: some View {
		Section {
			LabeledContent("settings_version", value: appVersion)
			LabeledContent("settings_data_source", value: String(localized: "settings_data_source_value"))
		} header: {
			Text("settings_about_header")
		} footer: {
			Text("settings_privacy_footer")
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
				? String(localized: "settings_update_success")
				: String(localized: "settings_update_failed")

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
