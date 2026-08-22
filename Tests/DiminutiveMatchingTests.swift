import XCTest
@testable import SvatekDnes

final class DiminutiveMatchingTests: XCTestCase {
	/// Compact day key of a name's match, nil when unmatched.
	private func day(of name: String) -> Int? {
		NameMatching.match(givenName: name).map { $0.month * 100 + $0.day }
	}

	func testDictionaryDiminutives() {
		XCTAssertEqual(day(of: "Káťa"), day(of: "Kateřina"))
		XCTAssertEqual(day(of: "Katka"), day(of: "Kateřina"))
		XCTAssertEqual(day(of: "Kačka"), day(of: "Kateřina"))
		XCTAssertEqual(day(of: "Helča"), day(of: "Helena"))
		XCTAssertEqual(day(of: "Natka"), day(of: "Natálie"))
		XCTAssertEqual(day(of: "Honza"), day(of: "Jan"))
		XCTAssertEqual(day(of: "Pepa"), day(of: "Josef"))
		XCTAssertEqual(day(of: "Maruška"), day(of: "Marie"))
		XCTAssertEqual(day(of: "Verča"), day(of: "Veronika"))
		XCTAssertNotNil(day(of: "Káťa"))
	}

	func testDictionaryWorksWithoutDiacriticsAndCase() {
		XCTAssertEqual(day(of: "kata"), day(of: "Kateřina"))
		XCTAssertEqual(day(of: "HONZA"), day(of: "Jan"))
	}

	func testDiacriticDiminutiveDoesNotShadowRealCalendarName() {
		// "Láďa" is Ladislav, but the calendar name Lada must stay Lada.
		XCTAssertEqual(day(of: "Láďa"), day(of: "Ladislav"))
		XCTAssertNotNil(day(of: "Lada"))
		XCTAssertNotEqual(day(of: "Lada"), day(of: "Ladislav"))
	}

	func testFuzzyDiminutives() {
		XCTAssertEqual(day(of: "Klárka"), day(of: "Klára"))
		XCTAssertEqual(day(of: "Zuzka"), day(of: "Zuzana"))
		XCTAssertEqual(day(of: "Kristy"), day(of: "Kristýna"))
		XCTAssertEqual(NameMatching.match(givenName: "Klárka")?.kind, .fuzzy)
	}

	func testAmbiguousStemsDoNotMatch() {
		// Alexandr vs Alexandra, Martin vs Martina – no guessing.
		XCTAssertNil(NameMatching.match(givenName: "Alex"))
		XCTAssertNil(NameMatching.match(givenName: "Marti"))
		// Too short for any tier.
		XCTAssertNil(NameMatching.match(givenName: "Bo"))
	}

	func testExactNamesKeepExactKind() {
		XCTAssertEqual(NameMatching.match(givenName: "Tomáš")?.kind, .exact)
		XCTAssertEqual(NameMatching.match(givenName: "tomas")?.kind, .exact)
	}
}
