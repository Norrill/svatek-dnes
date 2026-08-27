import XCTest
@testable import SvatekDnes

/// `ContactsService.reload()` skips rewriting the widget snapshot and
/// rescheduling notifications when the freshly enumerated contacts compare
/// equal to the ones already held. That optimisation is only safe while
/// `MatchedContact` equality covers every field a manual assignment can
/// change – replacing the synthesised `==` with an identity comparison on
/// `id` would silently stop manual assignments reaching the widget.
final class MatchedContactEqualityTests: XCTestCase {
	private func contact(
		matchedName: String = "Josef",
		month: Int = 3,
		day: Int = 19,
		kind: ContactMatchKind = .exact
	) -> MatchedContact {
		MatchedContact(
			id: "id1",
			givenName: "Pepa",
			familyName: "Novák",
			matchedName: matchedName,
			month: month,
			day: day,
			kind: kind
		)
	}

	/// Assigning a contact the same day it already matched automatically
	/// changes nothing but `kind`. If that went undetected the row would
	/// keep claiming an automatic match.
	func testKindParticipatesInEquality() {
		XCTAssertNotEqual(contact(kind: .exact), contact(kind: .manual))
		XCTAssertNotEqual(contact(kind: .diminutive), contact(kind: .manual))
		XCTAssertNotEqual(contact(kind: .fuzzy), contact(kind: .manual))
	}

	func testDayParticipatesInEquality() {
		XCTAssertNotEqual(contact(month: 3, day: 19), contact(month: 3, day: 20))
		XCTAssertNotEqual(contact(month: 3, day: 19), contact(month: 4, day: 19))
	}

	/// A remote nameday override can rename the day under a contact whose
	/// assignment itself did not move.
	func testMatchedNameParticipatesInEquality() {
		XCTAssertNotEqual(contact(matchedName: "Josef"), contact(matchedName: "Jozef"))
	}

	func testIdenticalContactsCompareEqual() {
		XCTAssertEqual(contact(), contact())
	}

	/// Array equality is what `reload()` actually tests, and it is
	/// order-sensitive – the fetch request sorts by given name.
	func testArrayEqualityIsOrderSensitive() {
		let josef = contact()
		let klara = MatchedContact(
			id: "id2",
			givenName: "Klárka",
			familyName: "Dvořáková",
			matchedName: "Klára",
			month: 8,
			day: 12,
			kind: .diminutive
		)
		XCTAssertEqual([josef, klara], [josef, klara])
		XCTAssertNotEqual([josef, klara], [klara, josef])
	}
}
