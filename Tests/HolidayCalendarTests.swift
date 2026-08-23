import XCTest
@testable import SvatekDnes

final class HolidayCalendarTests: XCTestCase {

	// MARK: - Movable feasts resolved for 2026

	func testMovableFeasts2026() {
		let holidays = HolidayCalendar.holidays(year: 2026)

		// Easter Sunday 2026 is 5. 4. -> Velký pátek 3. 4., Velikonoční pondělí 6. 4.
		XCTAssertTrue(
			holidays.contains { $0.shortName == "Velký pátek" && $0.month == 4 && $0.day == 3 },
			"Velký pátek 2026 must be on 3. 4."
		)
		XCTAssertTrue(
			holidays.contains { $0.shortName == "Velikonoční pondělí" && $0.month == 4 && $0.day == 6 },
			"Velikonoční pondělí 2026 must be on 6. 4."
		)
		// Den matek 2026 – second Sunday in May.
		XCTAssertTrue(
			holidays.contains { $0.shortName == "Den matek" && $0.month == 5 && $0.day == 10 },
			"Den matek 2026 must be on 10. 5."
		)
	}

	func testEasterHolidaysAreDaysOff() {
		let holidays = HolidayCalendar.holidays(year: 2026)
		let friday = holidays.first { $0.shortName == "Velký pátek" }
		let monday = holidays.first { $0.shortName == "Velikonoční pondělí" }
		XCTAssertEqual(friday?.isDayOff, true)
		XCTAssertEqual(monday?.isDayOff, true)

		let mothers = holidays.first { $0.shortName == "Den matek" }
		XCTAssertEqual(mothers?.kind, .significant)
		XCTAssertEqual(mothers?.isDayOff, false)
	}

	// MARK: - Day-off count

	func testExactlyThirteenDaysOffEveryYear() {
		// 11 fixed days off + Velký pátek + Velikonoční pondělí = 13.
		for year in [2024, 2025, 2026, 2027, 2030] {
			let daysOff = HolidayCalendar.holidays(year: year).filter { $0.isDayOff }
			XCTAssertEqual(daysOff.count, 13, "year \(year): expected 13 days off, got \(daysOff.count)")
		}
	}

	// MARK: - Fixed holidays

	func testNewYearsDay() {
		let holidays = HolidayCalendar.holidays(month: 1, day: 1, year: 2026)
		XCTAssertEqual(holidays.count, 1)
		XCTAssertEqual(holidays.first?.shortName, "Nový rok")
		XCTAssertEqual(holidays.first?.kind, .state)
		XCTAssertEqual(holidays.first?.isDayOff, true)
	}

	func testOctober28IsDayOff() {
		let holidays = HolidayCalendar.holidays(month: 10, day: 28, year: 2026)
		XCTAssertTrue(
			holidays.contains { $0.isDayOff },
			"28. 10. must be a day off (Den vzniku samostatného československého státu)"
		)
	}

	func testEpiphanyIsSignificantOnly() {
		let holidays = HolidayCalendar.holidays(month: 1, day: 6, year: 2026)
		let epiphany = holidays.first { $0.shortName == "Tři králové" }
		XCTAssertNotNil(epiphany)
		XCTAssertEqual(epiphany?.kind, .significant)
		XCTAssertEqual(epiphany?.isDayOff, false)
	}

	func testKindLabels() {
		// Labels are localized – assert they exist and are pairwise distinct.
		let labels = [
			Holiday(name: "Nový rok", shortName: "Nový rok", kind: .state, month: 1, day: 1).kindLabel,
			Holiday(name: "Velký pátek", shortName: "Velký pátek", kind: .other, month: 4, day: 3).kindLabel,
			Holiday(name: "Tři králové", shortName: "Tři králové", kind: .significant, month: 1, day: 6).kindLabel,
		]
		XCTAssertTrue(labels.allSatisfy { !$0.isEmpty })
		XCTAssertEqual(Set(labels).count, labels.count)
	}

	// MARK: - nextDayOff

	func testNextDayOffAfterSeptemberFirst2026() {
		let start = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 1))!
		let next = HolidayCalendar.nextDayOff(after: start)
		XCTAssertNotNil(next)
		XCTAssertEqual(next?.holiday.shortName, "Den české státnosti")
		XCTAssertEqual(next?.holiday.month, 9)
		XCTAssertEqual(next?.holiday.day, 28)

		if let date = next?.date {
			let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
			XCTAssertEqual(comps.year, 2026)
			XCTAssertEqual(comps.month, 9)
			XCTAssertEqual(comps.day, 28)
		}
	}

	func testNextDayOffIsStrictlyAfterGivenDate() {
		// Starting exactly on a holiday must skip it and return the next one:
		// after 28. 9. 2026 comes 28. 10. 2026.
		let start = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 28))!
		let next = HolidayCalendar.nextDayOff(after: start)
		XCTAssertNotNil(next)
		XCTAssertEqual(next?.holiday.month, 10)
		XCTAssertEqual(next?.holiday.day, 28)
	}
}
