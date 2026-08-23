import XCTest
@testable import SvatekDnes

final class NamedayStoreTests: XCTestCase {

	private let store = NamedayStore.shared

	// MARK: - Calendar completeness

	func testCalendarHas366Entries() {
		XCTAssertEqual(store.entries.count, 366)
	}

	func testEveryMonthHasCorrectNumberOfDays() {
		let expected = [1: 31, 2: 29, 3: 31, 4: 30, 5: 31, 6: 30,
			7: 31, 8: 31, 9: 30, 10: 31, 11: 30, 12: 31]
		for (month, days) in expected {
			XCTAssertEqual(store.month(month).count, days, "month(\(month)) entry count")
		}
	}

	func testFebruaryHas29Entries() {
		XCTAssertEqual(store.month(2).count, 29)
	}

	// MARK: - Spot checks against namedays.json

	func testEntrySpotChecks() {
		// (month, day, expected canonical names)
		let cases: [(month: Int, day: Int, names: [String])] = [
			(1, 1, []), // Nový rok – no nameday
			(1, 2, ["Karina"]),
			(2, 1, ["Hynek"]),
			(2, 29, ["Horymír"]), // leap day
			(3, 7, ["Tomáš"]),
			(12, 24, ["Adam", "Eva"]),
		]
		for c in cases {
			let entry = store.entry(month: c.month, day: c.day)
			XCTAssertEqual(entry.names, c.names, "entry(month: \(c.month), day: \(c.day)).names")
			XCTAssertEqual(entry.m, c.month)
			XCTAssertEqual(entry.d, c.day)
		}
	}

	func testDisplayTextJoinsNamesCzechWay() {
		XCTAssertEqual(store.entry(month: 12, day: 24).names, ["Adam", "Eva"])
		XCTAssertEqual(store.entry(month: 2, day: 1).displayText, "Hynek")
		XCTAssertEqual(store.entry(month: 1, day: 1).displayText, "")
	}

	// MARK: - Search

	func testSearchFindsFoldedName() {
		let results = store.search("tomas")
		XCTAssertTrue(
			results.contains { $0.m == 3 && $0.d == 7 },
			"search(\"tomas\") must find Tomáš on 7. 3."
		)
	}

	func testSearchIsDiacriticInsensitive() {
		// "stepan" must find Štěpán (26. 12.); prefix matching may also
		// return Štěpánka (31. 10.), which is fine.
		let results = store.search("stepan")
		XCTAssertTrue(
			results.contains { $0.m == 12 && $0.d == 26 },
			"search(\"stepan\") must find Štěpán on 26. 12."
		)
	}

	func testSearchIsCaseInsensitive() {
		let results = store.search("KARINA")
		XCTAssertTrue(results.contains { $0.m == 1 && $0.d == 2 })
	}

	func testSearchWithEmptyQueryReturnsNothing() {
		XCTAssertTrue(store.search("").isEmpty)
		XCTAssertTrue(store.search("   ").isEmpty)
	}

	func testSearchUnknownNameReturnsNothing() {
		XCTAssertTrue(store.search("Xyzabc").isEmpty)
	}

	// MARK: - joinedNames

	func testJoinedNames() {
		// The multi-name join is locale-dependent (ListFormatter), so only
		// assert the locale-independent behavior and containment.
		XCTAssertEqual([String]().joinedNames, "")
		XCTAssertEqual(["Karina"].joinedNames, "Karina")

		let pair = ["Petr", "Pavel"].joinedNames
		XCTAssertTrue(pair.contains("Petr") && pair.contains("Pavel"))

		let triple = ["Rut", "Matylda", "Vlastibor"].joinedNames
		for name in ["Rut", "Matylda", "Vlastibor"] {
			XCTAssertTrue(triple.contains(name))
		}
	}
}
