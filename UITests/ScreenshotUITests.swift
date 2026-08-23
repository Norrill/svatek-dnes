import XCTest

/// Walks the four tabs and saves full-screen PNGs.
/// The output directory is passed via the SCREENSHOT_DIR environment
/// variable; without it the test just smoke-tests the navigation.
final class ScreenshotUITests: XCTestCase {
	private var outputDirectory: String? {
		ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? "/private/tmp/svatek-shots"
	}

	func testWalkTabsAndTakeScreenshots() throws {
		let app = XCUIApplication()
		// The walk-through taps Czech labels; force the Czech localization
		// regardless of the simulator language.
		app.launchArguments += ["-AppleLanguages", "(cs)"]
		app.launch()

		allowSystemAlertIfPresent(timeout: 6)
		XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
		snap("1-dnes")

		app.tabBars.buttons["Kalendář"].tap()
		sleep(1)
		snap("2-kalendar")

		app.tabBars.buttons["Lidé"].tap()
		sleep(1)
		let allowButton = app.buttons["Povolit přístup ke kontaktům"]
		if allowButton.waitForExistence(timeout: 2) {
			allowButton.tap()
			allowSystemAlertIfPresent(timeout: 6)
			sleep(2)
		}
		snap("3-lide")

		// Assign a nameday to an unmatched contact (John Appleseed -> 24. 6. Jan).
		let johnRow = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "John Appleseed")).firstMatch
		if johnRow.waitForExistence(timeout: 2) {
			johnRow.tap()
			let search = app.searchFields.firstMatch
			if search.waitForExistence(timeout: 4) {
				search.tap()
				search.typeText("Jan")
				let dayRow = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "24. 6.")).firstMatch
				if dayRow.waitForExistence(timeout: 4) {
					dayRow.tap()
					sleep(2)
					snap("3b-lide-assigned")
				}
			}
		}

		app.tabBars.buttons["Nastavení"].tap()
		sleep(1)
		snap("4-nastaveni")

		app.tabBars.buttons["Dnes"].tap()
		sleep(1)
		snap("5-dnes-final")
	}

	private func allowSystemAlertIfPresent(timeout: TimeInterval) {
		let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
		let deadline = Date().addingTimeInterval(timeout)
		while Date() < deadline {
			let alert = springboard.alerts.firstMatch
			if alert.exists {
				for label in ["Allow", "Povolit", "OK", "Allow Full Access"] {
					let button = alert.buttons[label]
					if button.exists {
						button.tap()
						sleep(1)
						return
					}
				}
			}
			usleep(300_000)
		}
	}

	private func snap(_ name: String) {
		guard let dir = outputDirectory else {
			return
		}
		let png = XCUIScreen.main.screenshot().pngRepresentation
		try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
		let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
		do {
			try png.write(to: url)
		} catch {
			print("SCREENSHOT WRITE FAILED: \(error)")
		}
	}
}
