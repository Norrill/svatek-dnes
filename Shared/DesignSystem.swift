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
		c.locale = Locale.autoupdatingCurrent
		return c
	}()
}

/// Date formatting helpers following the app language (cs/en/de…).
/// The underlying calendar stays Gregorian – see `Calendar.czech`.
enum AppFormat {
	/// The locale used for all user-facing formatting.
	static var locale: Locale { .autoupdatingCurrent }

	/// How a date relates to the reference day.
	enum RelativeKind {
		case today
		case tomorrow
		case other
	}

	private static func makeFormatter(template: String) -> DateFormatter {
		let f = DateFormatter()
		f.locale = .autoupdatingCurrent
		f.calendar = Calendar(identifier: .gregorian)
		f.setLocalizedDateFormatFromTemplate(template)
		return f
	}

	private static let fullFormatter = makeFormatter(template: "EEEEdMMMMy")
	private static let weekdayDayMonthFormatter = makeFormatter(template: "EEEEdMMMM")
	private static let dayMonthFormatter = makeFormatter(template: "dMMMM")
	private static let shortDateFormatter = makeFormatter(template: "Md")
	private static let monthNameFormatter = makeFormatter(template: "LLLL")
	private static let weekdayFormatter = makeFormatter(template: "EEEE")

	/// Weekday name alone: "pátek" / "Friday" / "Freitag".
	static func weekday(_ date: Date) -> String {
		weekdayFormatter.string(from: date)
	}

	/// cs "pátek 22. srpna 2026", en "Friday, August 22, 2026"
	static func fullDate(_ date: Date) -> String {
		fullFormatter.string(from: date)
	}

	/// cs "pátek 22. srpna", en "Friday, August 22"
	static func weekdayDayMonth(_ date: Date) -> String {
		weekdayDayMonthFormatter.string(from: date)
	}

	/// cs "22. srpna", en "August 22"
	static func dayMonth(_ date: Date) -> String {
		dayMonthFormatter.string(from: date)
	}

	/// cs "22. 8.", en "8/22", de "22.8."
	static func shortDate(month: Int, day: Int) -> String {
		var comps = DateComponents()
		// A leap year, so 29. 2. (Horymír) does not overflow to 1. 3.
		comps.year = 2028
		comps.month = month
		comps.day = day
		guard let date = Calendar.czech.date(from: comps) else {
			return "\(day). \(month)."
		}
		return shortDateFormatter.string(from: date)
	}

	/// Standalone month name in the app language: "leden" / "January" / "Januar".
	static func monthName(_ month: Int) -> String {
		var comps = DateComponents()
		comps.year = 2026
		comps.month = month
		comps.day = 1
		let date = Calendar.czech.date(from: comps) ?? Date()
		return monthNameFormatter.string(from: date)
	}

	static func relativeKind(_ date: Date, reference: Date = Date()) -> RelativeKind {
		let calendar = Calendar.czech
		if calendar.isDate(date, inSameDayAs: reference) {
			return .today
		}
		if let tomorrow = calendar.date(byAdding: .day, value: 1, to: reference),
			calendar.isDate(date, inSameDayAs: tomorrow) {
			return .tomorrow
		}
		return .other
	}

	/// "dnes", "zítra", or weekday+date for later days – localized.
	static func relativeDay(_ date: Date, reference: Date = Date()) -> String {
		switch relativeKind(date, reference: reference) {
		case .today:
			return String(localized: "dnes")
		case .tomorrow:
			return String(localized: "zítra")
		case .other:
			return weekdayDayMonth(date)
		}
	}

	/// Whole days from the reference day to the given date.
	static func daysUntil(_ date: Date, reference: Date = Date()) -> Int {
		let calendar = Calendar.czech
		return calendar.dateComponents(
			[.day],
			from: calendar.startOfDay(for: reference),
			to: calendar.startOfDay(for: date)
		).day ?? 0
	}

	/// "za 5 dní" / "in 5 days" / "in 5 Tagen" – plural-aware.
	static func inDays(_ days: Int) -> String {
		String(localized: "za \(days) dní")
	}
}
