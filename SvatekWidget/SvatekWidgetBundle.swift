import WidgetKit
import SwiftUI

@main
struct SvatekWidgetBundle: WidgetBundle {
	var body: some Widget {
		SvatekWidget()
	}
}

// MARK: - Entry data

/// Everything the widget needs to render one day.
struct SvatekDayData: Hashable {
	let date: Date
	/// Canonical calendar names of the day.
	let names: [String]
	/// Additional name variants (not shown prominently, kept for completeness).
	let alt: [String]
	/// Compact name of the day's most important holiday, if any.
	let holidayShortName: String?
	let holidayKind: HolidayKind?
	let isDayOff: Bool
	/// Given names of the user's contacts having their nameday this day.
	let contactNames: [String]

	var month: Int { Calendar.czech.component(.month, from: date) }
	var day: Int { Calendar.czech.component(.day, from: date) }
}

struct SvatekEntry: TimelineEntry {
	let date: Date
	/// The entry's own day.
	let today: SvatekDayData
	/// The three following days (medium widget, lock screen preview).
	let upcoming: [SvatekDayData]
}

// MARK: - Provider

struct SvatekProvider: TimelineProvider {
	func placeholder(in context: Context) -> SvatekEntry {
		Self.entry(at: Date(), snapshot: nil)
	}

	func getSnapshot(in context: Context, completion: @escaping (SvatekEntry) -> Void) {
		completion(Self.entry(at: Date(), snapshot: SnapshotStore.load()))
	}

	func getTimeline(in context: Context, completion: @escaping (Timeline<SvatekEntry>) -> Void) {
		let calendar = Calendar.czech
		let now = Date()
		let snapshot = SnapshotStore.load()
		let startOfToday = calendar.startOfDay(for: now)

		// First entry right now, then one at each of the next six midnights.
		var entries: [SvatekEntry] = [Self.entry(at: now, snapshot: snapshot)]
		for offset in 1...6 {
			guard let midnight = calendar.date(byAdding: .day, value: offset, to: startOfToday) else {
				continue
			}
			entries.append(Self.entry(at: midnight, snapshot: snapshot))
		}
		completion(Timeline(entries: entries, policy: .atEnd))
	}

	static func entry(at date: Date, snapshot: WidgetSnapshot?) -> SvatekEntry {
		let calendar = Calendar.czech
		let start = calendar.startOfDay(for: date)
		let upcoming: [SvatekDayData] = (1...3).compactMap { offset in
			guard let day = calendar.date(byAdding: .day, value: offset, to: start) else {
				return nil
			}
			return dayData(for: day, snapshot: snapshot)
		}
		return SvatekEntry(
			date: date,
			today: dayData(for: date, snapshot: snapshot),
			upcoming: upcoming
		)
	}

	static func dayData(for date: Date, snapshot: WidgetSnapshot?) -> SvatekDayData {
		let info = CalendarComposer.info(for: date)
		let comps = Calendar.czech.dateComponents([.month, .day], from: date)
		var contacts: [String] = []
		if let month = comps.month, let day = comps.day {
			contacts = snapshot?.contacts(month: month, day: day) ?? []
		}
		let holiday = info.primaryHoliday
		return SvatekDayData(
			date: date,
			names: info.entry.names,
			alt: info.entry.alt,
			holidayShortName: holiday?.shortName,
			holidayKind: holiday?.kind,
			isDayOff: info.isDayOff,
			contactNames: contacts
		)
	}
}

// MARK: - Widget

struct SvatekWidget: Widget {
	var body: some WidgetConfiguration {
		StaticConfiguration(kind: "SvatekWidget", provider: SvatekProvider()) { entry in
			SvatekWidgetEntryView(entry: entry)
		}
		.configurationDisplayName("Svátek dnes")
		.description("Kdo má dnes svátek a jaké svátky nás čekají.")
		.supportedFamilies([
			.systemSmall,
			.systemMedium,
			.accessoryInline,
			.accessoryRectangular,
			.accessoryCircular,
		])
	}
}
