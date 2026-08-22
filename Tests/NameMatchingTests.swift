import XCTest
@testable import SvatekDnes

final class NameMatchingTests: XCTestCase {

	// MARK: - Folding

	func testFoldStripsDiacriticsCaseAndWhitespace() {
		let cases: [(input: String, expected: String)] = [
			("Tomáš", "tomas"),
			(" Tomáš ", "tomas"),
			("KARINA", "karina"),
			("Štěpán", "stepan"),
			("Žofie", "zofie"),
			("", ""),
			("   ", ""),
		]
		for c in cases {
			XCTAssertEqual(NameMatching.fold(c.input), c.expected, "fold(\"\(c.input)\")")
		}
	}

	func testLowerKeepsDiacritics() {
		XCTAssertEqual(NameMatching.lower(" Tomáš "), "tomáš")
		XCTAssertEqual(NameMatching.lower("ŠTĚPÁN"), "štěpán")
	}

	// MARK: - Matching against the real calendar data

	func testExactDiacriticNameMatchesItsDay() {
		// Tomáš is the canonical name on 7. 3. in namedays.json.
		let match = NameMatching.match(givenName: "Tomáš")
		XCTAssertNotNil(match)
		XCTAssertEqual(match?.month, 3)
		XCTAssertEqual(match?.day, 7)
		XCTAssertEqual(match?.calendarName, "Tomáš")
	}

	func testFoldedNameMatchesSameDay() {
		// "tomas" (no diacritics) must resolve via the folded index to the same day.
		let match = NameMatching.match(givenName: "tomas")
		XCTAssertNotNil(match)
		XCTAssertEqual(match?.month, 3)
		XCTAssertEqual(match?.day, 7)
		XCTAssertEqual(match?.calendarName, "Tomáš")
	}

	func testUnknownNameReturnsNil() {
		XCTAssertNil(NameMatching.match(givenName: "Xyzabc"))
	}

	func testEmptyAndWhitespaceNamesReturnNil() {
		XCTAssertNil(NameMatching.match(givenName: ""))
		XCTAssertNil(NameMatching.match(givenName: "   "))
	}

	func testCanonicalNameBeatsAltVariant() {
		// Štefan is canonical on 9. 10. and only an alt variant of Štěpán
		// on 26. 12. – the canonical day must win.
		let match = NameMatching.match(givenName: "Štefan")
		XCTAssertNotNil(match)
		XCTAssertEqual(match?.month, 10)
		XCTAssertEqual(match?.day, 9)
		XCTAssertEqual(match?.calendarName, "Štefan")
	}

	func testMatchingIsCaseInsensitive() {
		// Karina is the canonical name on 2. 1.
		let match = NameMatching.match(givenName: "KARINA")
		XCTAssertNotNil(match)
		XCTAssertEqual(match?.month, 1)
		XCTAssertEqual(match?.day, 2)
		XCTAssertEqual(match?.calendarName, "Karina")
	}

	func testAltVariantMatchesWhenNotCanonicalAnywhere() {
		// Vasil is listed only as an alt variant on 2. 1. (alongside Karina).
		let match = NameMatching.match(givenName: "Vasil")
		XCTAssertNotNil(match)
		XCTAssertEqual(match?.month, 1)
		XCTAssertEqual(match?.day, 2)
		XCTAssertEqual(match?.calendarName, "Vasil")
	}
}
