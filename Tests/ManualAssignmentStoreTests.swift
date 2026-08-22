import XCTest
@testable import SvatekDnes

final class ManualAssignmentStoreTests: XCTestCase {
	private let suiteName = "manual-assignment-tests"
	private var defaults: UserDefaults!

	override func setUp() {
		super.setUp()
		defaults = UserDefaults(suiteName: suiteName)
		defaults.removePersistentDomain(forName: suiteName)
	}

	override func tearDown() {
		defaults.removePersistentDomain(forName: suiteName)
		super.tearDown()
	}

	func testAssignReadRemove() {
		XCTAssertNil(ManualAssignmentStore.assignment(for: "id1", defaults: defaults))

		ManualAssignmentStore.assign(contactId: "id1", month: 2, day: 17, defaults: defaults)
		let assignment = ManualAssignmentStore.assignment(for: "id1", defaults: defaults)
		XCTAssertEqual(assignment?.month, 2)
		XCTAssertEqual(assignment?.day, 17)

		ManualAssignmentStore.remove(contactId: "id1", defaults: defaults)
		XCTAssertNil(ManualAssignmentStore.assignment(for: "id1", defaults: defaults))
	}

	func testOverwriteKeepsSingleAssignment() {
		ManualAssignmentStore.assign(contactId: "id1", month: 1, day: 2, defaults: defaults)
		ManualAssignmentStore.assign(contactId: "id1", month: 12, day: 24, defaults: defaults)

		let all = ManualAssignmentStore.all(defaults: defaults)
		XCTAssertEqual(all.count, 1)
		XCTAssertEqual(all["id1"]?.month, 12)
		XCTAssertEqual(all["id1"]?.day, 24)
	}

	func testMultipleContacts() {
		ManualAssignmentStore.assign(contactId: "a", month: 6, day: 24, defaults: defaults)
		ManualAssignmentStore.assign(contactId: "b", month: 7, day: 26, defaults: defaults)

		let all = ManualAssignmentStore.all(defaults: defaults)
		XCTAssertEqual(all.count, 2)
		XCTAssertEqual(all["a"]?.day, 24)
		XCTAssertEqual(all["b"]?.day, 26)

		ManualAssignmentStore.remove(contactId: "a", defaults: defaults)
		XCTAssertEqual(ManualAssignmentStore.all(defaults: defaults).count, 1)
	}

	func testGarbageValuesAreIgnored() {
		defaults.set(
			["bad": "not-a-date", "worse": "13-40", "empty": "", "ok": "6-24"],
			forKey: "manualNamedayAssignments"
		)

		let all = ManualAssignmentStore.all(defaults: defaults)
		XCTAssertEqual(all.count, 1)
		XCTAssertEqual(all["ok"]?.month, 6)
		XCTAssertEqual(all["ok"]?.day, 24)
	}
}
