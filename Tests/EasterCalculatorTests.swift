import XCTest
@testable import SvatekDnes

final class EasterCalculatorTests: XCTestCase {

	// MARK: - Easter Sunday

	func testEasterSundayKnownValues() {
		// (year, expected month, expected day)
		let cases: [(year: Int, month: Int, day: Int)] = [
			(2024, 3, 31),
			(2025, 4, 20),
			(2026, 4, 5),
			(2027, 3, 28),
			(2028, 4, 16),
			(2029, 4, 1),
			(2030, 4, 21),
			(2038, 4, 25), // latest possible extreme in this century
			(1943, 4, 25),
			(2008, 3, 23), // early Easter
		]
		for c in cases {
			let result = EasterCalculator.easterSunday(year: c.year)
			XCTAssertEqual(result.month, c.month, "Easter Sunday \(c.year): expected month \(c.month), got \(result.month)")
			XCTAssertEqual(result.day, c.day, "Easter Sunday \(c.year): expected day \(c.day), got \(result.day)")
		}
	}

	// MARK: - Good Friday and Easter Monday

	func testGoodFridayAndEasterMondayAcrossMonthBoundaries() {
		// 2024: Easter Sunday 31. 3. -> Good Friday 29. 3., Easter Monday 1. 4.
		// (Monday crosses the March/April boundary.)
		let gf2024 = EasterCalculator.goodFriday(year: 2024)
		XCTAssertEqual(gf2024.month, 3)
		XCTAssertEqual(gf2024.day, 29)

		let em2024 = EasterCalculator.easterMonday(year: 2024)
		XCTAssertEqual(em2024.month, 4)
		XCTAssertEqual(em2024.day, 1)

		// 2027: Easter Sunday 28. 3. -> both derived days stay in March.
		let gf2027 = EasterCalculator.goodFriday(year: 2027)
		XCTAssertEqual(gf2027.month, 3)
		XCTAssertEqual(gf2027.day, 26)

		let em2027 = EasterCalculator.easterMonday(year: 2027)
		XCTAssertEqual(em2027.month, 3)
		XCTAssertEqual(em2027.day, 29)
	}

	func testGoodFridayIsTwoDaysBeforeAndMondayOneDayAfterSunday() {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "Europe/Prague") ?? .current
		for year in 2020...2040 {
			let sunday = EasterCalculator.easterSunday(year: year)
			let friday = EasterCalculator.goodFriday(year: year)
			let monday = EasterCalculator.easterMonday(year: year)

			let sundayDate = calendar.date(from: DateComponents(year: year, month: sunday.month, day: sunday.day))!
			let fridayDate = calendar.date(from: DateComponents(year: year, month: friday.month, day: friday.day))!
			let mondayDate = calendar.date(from: DateComponents(year: year, month: monday.month, day: monday.day))!

			XCTAssertEqual(
				calendar.dateComponents([.day], from: fridayDate, to: sundayDate).day, 2,
				"Good Friday \(year) is not two days before Easter Sunday"
			)
			XCTAssertEqual(
				calendar.dateComponents([.day], from: sundayDate, to: mondayDate).day, 1,
				"Easter Monday \(year) is not one day after Easter Sunday"
			)
		}
	}

	// MARK: - Mother's Day (second Sunday in May)

	func testMothersDayKnownValues() {
		let cases: [(year: Int, day: Int)] = [
			(2024, 12),
			(2025, 11),
			(2026, 10),
			(2027, 9),
		]
		for c in cases {
			let result = EasterCalculator.mothersDay(year: c.year)
			XCTAssertEqual(result.month, 5, "Mother's Day \(c.year) must be in May")
			XCTAssertEqual(result.day, c.day, "Mother's Day \(c.year): expected 5/\(c.day), got 5/\(result.day)")
		}
	}

	func testMothersDayIsAlwaysASunday() {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "Europe/Prague") ?? .current
		for year in 2020...2040 {
			let md = EasterCalculator.mothersDay(year: year)
			let date = calendar.date(from: DateComponents(year: year, month: md.month, day: md.day))!
			XCTAssertEqual(calendar.component(.weekday, from: date), 1, "Mother's Day \(year) is not a Sunday")
			XCTAssertTrue((8...14).contains(md.day), "Mother's Day \(year) is not the second Sunday (day \(md.day))")
		}
	}
}
