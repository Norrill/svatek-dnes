import SwiftUI

struct RootView: View {
	enum Tab: Hashable {
		case today, calendar, people, settings
	}

	@StateObject private var contacts = ContactsService.shared
	@StateObject private var settings = AppSettings.shared
	@State private var selection: Tab = .today

	var body: some View {
		TabView(selection: $selection) {
			TodayView(showPeople: { selection = .people })
				.tabItem {
					Label("tab_today", systemImage: "sun.max")
				}
				.tag(Tab.today)
			CalendarListView()
				.tabItem {
					Label("tab_calendar", systemImage: "calendar")
				}
				.tag(Tab.calendar)
			PeopleView()
				.tabItem {
					Label("tab_people", systemImage: "person.2")
				}
				.tag(Tab.people)
			SettingsView()
				.tabItem {
					Label("tab_settings", systemImage: "gearshape")
				}
				.tag(Tab.settings)
		}
		.environmentObject(contacts)
		.environmentObject(settings)
	}
}

#Preview {
	RootView()
}
