import SwiftUI

extension Color {
	/// Brand dark green (adapts slightly in dark mode, stays green).
	static let brandGreen = Color("BrandGreen")
}

extension Calendar {
	/// The nameday and holiday tables are Gregorian month/day keys.
	/// Never index them through `Calendar.current` – a device set to a
	/// non-Gregorian calendar (buddhist, islamic…) would produce wrong keys.
	static let czech: Calendar = {
		var c = Calendar(identifier: .gregorian)
		c.locale = CzechFormat.locale
		return c
	}()
}

/// Czech date formatting helpers (always cs_CZ, independent of device locale).
enum CzechFormat {
	static let locale = Locale(identifier: "cs_CZ")

	private static func makeFormatter(_ format: String) -> DateFormatter {
		let f = DateFormatter()
		f.locale = locale
		f.calendar = Calendar(identifier: .gregorian)
		f.dateFormat = format
		return f
	}

	private static let fullFormatter = makeFormatter("EEEE d. MMMM yyyy")
	private static let weekdayDayMonthFormatter = makeFormatter("EEEE d. MMMM")
	private static let dayMonthFormatter = makeFormatter("d. MMMM")
	private static let monthNameFormatter = makeFormatter("LLLL")

	/// "pátek 22. srpna 2026"
	static func fullDate(_ date: Date) -> String {
		fullFormatter.string(from: date)
	}

	/// "pátek 22. srpna"
	static func weekdayDayMonth(_ date: Date) -> String {
		weekdayDayMonthFormatter.string(from: date)
	}

	/// "22. srpna"
	static func dayMonth(_ date: Date) -> String {
		dayMonthFormatter.string(from: date)
	}

	/// "22. 8." – note the space, Czech typographic convention.
	static func shortDate(month: Int, day: Int) -> String {
		"\(day). \(month)."
	}

	/// Standalone month name: "leden" … "prosinec".
	static func monthName(_ month: Int) -> String {
		var comps = DateComponents()
		comps.year = 2026
		comps.month = month
		comps.day = 1
		let date = Calendar.czech.date(from: comps) ?? Date()
		return monthNameFormatter.string(from: date)
	}

	/// "dnes", "zítra", or weekday+date for later days.
	static func relativeDay(_ date: Date, reference: Date = Date()) -> String {
		let calendar = Calendar.czech
		if calendar.isDate(date, inSameDayAs: reference) {
			return "dnes"
		}
		if let tomorrow = calendar.date(byAdding: .day, value: 1, to: reference),
			calendar.isDate(date, inSameDayAs: tomorrow) {
			return "zítra"
		}
		return weekdayDayMonth(date)
	}
}
