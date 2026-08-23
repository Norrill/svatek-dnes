import SwiftUI

struct RootView: View {
	@StateObject private var contacts = ContactsService.shared
	@StateObject private var settings = AppSettings.shared

	var body: some View {
		TabView {
			TodayView()
				.tabItem {
					Label("tab_today", systemImage: "sun.max")
				}
			CalendarListView()
				.tabItem {
					Label("tab_calendar", systemImage: "calendar")
				}
			PeopleView()
				.tabItem {
					Label("tab_people", systemImage: "person.2")
				}
			SettingsView()
				.tabItem {
					Label("tab_settings", systemImage: "gearshape")
				}
		}
		.environmentObject(contacts)
		.environmentObject(settings)
	}
}

#Preview {
	RootView()
}
