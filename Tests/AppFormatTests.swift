import XCTest
@testable import SvatekDnes

final class AppFormatTests: XCTestCase {

	/// The day countdown goes through a plural-aware catalog entry
	/// (`relative_in_days`). Guard the localizedStringWithFormat plumbing:
	/// the number must be substituted and no raw key or format may leak.
	func testInDaysResolvesPluralFormat() {
		for days in [1, 2, 5, 100] {
			let text = AppFormat.inDays(days)
			XCTAssertTrue(text.contains("\(days)"), "inDays(\(days)) = \(text)")
			XCTAssertFalse(text.contains("%"), "unresolved format: \(text)")
			XCTAssertFalse(text.contains("relative_in_days"), "raw key leaked: \(text)")
		}
	}

	func testRelativeDayResolvesKeys() {
		let reference = Date()
		let today = AppFormat.relativeDay(reference, reference: reference)
		let tomorrow = AppFormat.relativeDay(
			Calendar.czech.date(byAdding: .day, value: 1, to: reference)!,
			reference: reference
		)
		for text in [today, tomorrow] {
			XCTAssertFalse(text.isEmpty)
			XCTAssertFalse(text.contains("_"), "raw key leaked: \(text)")
		}
		XCTAssertNotEqual(today, tomorrow)
	}

	func testShortDateHandlesLeapDay() {
		// 29. 2. exists in the nameday data (Horymír) – must not roll over to 1. 3.
		let text = AppFormat.shortDate(month: 2, day: 29)
		XCTAssertTrue(text.contains("29"), "leap day rolled over: \(text)")
	}
}
