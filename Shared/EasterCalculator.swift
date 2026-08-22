import Foundation

/// Gregorian Easter computus (anonymous/Meeus algorithm).
enum EasterCalculator {
	/// Easter Sunday for the given year.
	static func easterSunday(year: Int) -> (month: Int, day: Int) {
		let a = year % 19
		let b = year / 100
		let c = year % 100
		let d = b / 4
		let e = b % 4
		let f = (b + 8) / 25
		let g = (b - f + 1) / 3
		let h = (19 * a + b - d - g + 15) % 30
		let i = c / 4
		let k = c % 4
		let l = (32 + 2 * e + 2 * i - h - k) % 7
		let m = (a + 11 * h + 22 * l) / 451
		let month = (h + l - 7 * m + 114) / 31
		let day = ((h + l - 7 * m + 114) % 31) + 1
		return (month, day)
	}

	/// Velký pátek – two days before Easter Sunday.
	static func goodFriday(year: Int) -> (month: Int, day: Int) {
		offset(from: easterSunday(year: year), by: -2, year: year)
	}

	/// Velikonoční pondělí – the day after Easter Sunday.
	static func easterMonday(year: Int) -> (month: Int, day: Int) {
		offset(from: easterSunday(year: year), by: 1, year: year)
	}

	private static func offset(from md: (month: Int, day: Int), by days: Int, year: Int) -> (month: Int, day: Int) {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "Europe/Prague") ?? .current
		let base = calendar.date(from: DateComponents(year: year, month: md.month, day: md.day))!
		let shifted = calendar.date(byAdding: .day, value: days, to: base)!
		let comps = calendar.dateComponents([.month, .day], from: shifted)
		return (comps.month!, comps.day!)
	}

	/// Den matek – the second Sunday in May.
	static func mothersDay(year: Int) -> (month: Int, day: Int) {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "Europe/Prague") ?? .current
		calendar.firstWeekday = 2
		let first = calendar.date(from: DateComponents(year: year, month: 5, day: 1))!
		let firstWeekday = calendar.component(.weekday, from: first) // 1 = Sunday
		let firstSunday = firstWeekday == 1 ? 1 : 9 - firstWeekday
		return (5, firstSunday + 7)
	}
}
