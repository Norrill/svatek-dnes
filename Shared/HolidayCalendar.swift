import Foundation

/// Czech public holidays and significant days, resolved per year.
/// Fixed-date holidays can be overridden by the remotely updated data file;
/// movable feasts are computed from the Easter computus unless the remote
/// file provides an explicit list for the year.
enum HolidayCalendar {
	private struct FixedHoliday {
		let m: Int
		let d: Int
		let short: String
		let full: String
		let kind: HolidayKind
	}

	private static let builtInFixed: [FixedHoliday] = [
		FixedHoliday(m: 1, d: 1, short: "Nový rok", full: "Den obnovy samostatného českého státu", kind: .state),
		FixedHoliday(m: 5, d: 1, short: "Svátek práce", full: "Svátek práce", kind: .other),
		FixedHoliday(m: 5, d: 8, short: "Den vítězství", full: "Den vítězství", kind: .state),
		FixedHoliday(m: 7, d: 5, short: "Cyril a Metoděj", full: "Den slovanských věrozvěstů Cyrila a Metoděje", kind: .state),
		FixedHoliday(m: 7, d: 6, short: "Jan Hus", full: "Den upálení mistra Jana Husa", kind: .state),
		FixedHoliday(m: 9, d: 28, short: "Den české státnosti", full: "Den české státnosti", kind: .state),
		FixedHoliday(m: 10, d: 28, short: "Vznik Československa", full: "Den vzniku samostatného československého státu", kind: .state),
		FixedHoliday(m: 11, d: 17, short: "Den boje za svobodu", full: "Den boje za svobodu a demokracii a Mezinárodní den studentstva", kind: .state),
		FixedHoliday(m: 12, d: 24, short: "Štědrý den", full: "Štědrý den", kind: .other),
		FixedHoliday(m: 12, d: 25, short: "1. svátek vánoční", full: "1. svátek vánoční", kind: .other),
		FixedHoliday(m: 12, d: 26, short: "2. svátek vánoční", full: "2. svátek vánoční", kind: .other),
		// Významné dny (no day off)
		FixedHoliday(m: 1, d: 6, short: "Tři králové", full: "Tři králové", kind: .significant),
		FixedHoliday(m: 3, d: 8, short: "Mezinárodní den žen", full: "Mezinárodní den žen", kind: .significant),
		FixedHoliday(m: 6, d: 1, short: "Den dětí", full: "Mezinárodní den dětí", kind: .significant),
		FixedHoliday(m: 11, d: 2, short: "Památka zesnulých", full: "Památka zesnulých (Dušičky)", kind: .significant),
	]

	private static var cache: [Int: [Holiday]] = [:]
	private static let lock = NSLock()

	/// All holidays and significant days of the given year, sorted by date.
	static func holidays(year: Int) -> [Holiday] {
		lock.lock()
		defer { lock.unlock() }
		if let cached = cache[year] {
			return cached
		}

		var result: [Holiday] = []
		let remote = HolidayUpdateService.shared.stored

		if let fixed = remote?.fixedHolidays, !fixed.isEmpty {
			result += fixed.map {
				Holiday(name: $0.name, shortName: $0.shortName ?? $0.name, kind: $0.kind, month: $0.m, day: $0.d)
			}
		} else {
			result += builtInFixed.map {
				Holiday(name: $0.full, shortName: $0.short, kind: $0.kind, month: $0.m, day: $0.d)
			}
		}

		if let movable = remote?.movable?[String(year)], !movable.isEmpty {
			result += movable.map {
				Holiday(name: $0.name, shortName: $0.shortName ?? $0.name, kind: $0.kind, month: $0.m, day: $0.d)
			}
		} else {
			let friday = EasterCalculator.goodFriday(year: year)
			let monday = EasterCalculator.easterMonday(year: year)
			let mothers = EasterCalculator.mothersDay(year: year)
			result.append(Holiday(name: "Velký pátek", shortName: "Velký pátek", kind: .other, month: friday.month, day: friday.day))
			result.append(Holiday(name: "Velikonoční pondělí", shortName: "Velikonoční pondělí", kind: .other, month: monday.month, day: monday.day))
			result.append(Holiday(name: "Den matek", shortName: "Den matek", kind: .significant, month: mothers.month, day: mothers.day))
		}

		result.sort {
			($0.month, $0.day, $0.isDayOff ? 0 : 1) < ($1.month, $1.day, $1.isDayOff ? 0 : 1)
		}
		cache[year] = result
		return result
	}

	static func holidays(month: Int, day: Int, year: Int) -> [Holiday] {
		holidays(year: year).filter { $0.month == month && $0.day == day }
	}

	static func holidays(for date: Date) -> [Holiday] {
		let comps = Calendar.czech.dateComponents([.year, .month, .day], from: date)
		return holidays(month: comps.month!, day: comps.day!, year: comps.year!)
	}

	/// The next day off (state or other holiday) strictly after the given date's day.
	static func nextDayOff(after date: Date) -> (date: Date, holiday: Holiday)? {
		let calendar = Calendar.czech
		var day = calendar.startOfDay(for: date)
		for _ in 0..<400 {
			day = calendar.date(byAdding: .day, value: 1, to: day)!
			if let holiday = holidays(for: day).first(where: { $0.isDayOff }) {
				return (day, holiday)
			}
		}
		return nil
	}

	/// Drops the per-year cache (call after remote data update).
	static func invalidate() {
		lock.lock()
		cache.removeAll()
		lock.unlock()
	}
}
