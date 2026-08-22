import SwiftUI

struct RootView: View {
	@StateObject private var contacts = ContactsService.shared
	@StateObject private var settings = AppSettings.shared

	var body: some View {
		TabView {
			TodayView()
				.tabItem {
					Label("Dnes", systemImage: "sun.max")
				}
			CalendarListView()
				.tabItem {
					Label("Kalendář", systemImage: "calendar")
				}
			PeopleView()
				.tabItem {
					Label("Lidé", systemImage: "person.2")
				}
			SettingsView()
				.tabItem {
					Label("Nastavení", systemImage: "gearshape")
				}
		}
		.environmentObject(contacts)
		.environmentObject(settings)
	}
}

#Preview {
	RootView()
}
