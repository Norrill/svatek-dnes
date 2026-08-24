import XCTest

/// Walks the four tabs and saves full-screen PNGs.
/// The output directory is passed via the SCREENSHOT_DIR environment
/// variable; without it the test just smoke-tests the navigation.
final class ScreenshotUITests: XCTestCase {
	private var outputDirectory: String? {
		ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? "/private/tmp/svatek-shots"
	}

	func testWalkTabsAndTakeScreenshots() throws {
		// The dictation onboarding alert fires asynchronously a few seconds
		// after the first typing. Decline it – XCUITest's default handler
		// would tap the highlighted "O Siri, diktování a soukromí…" link
		// and navigate away from the app.
		addUIInterruptionMonitor(withDescription: "Diktování") { alert in
			for label in ["Teď ne", "Not Now"] {
				let button = alert.buttons[label]
				if button.exists {
					button.tap()
					return true
				}
			}
			return false
		}

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
			grantContactsAccess(app: app)
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
				// Match by name, not by date – the localized short date
				// contains a narrow no-break space (U+202F), so a literal
				// "24. 6." never matches.
				let dayRow = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", ", Jan")).firstMatch
				XCTAssertTrue(dayRow.waitForExistence(timeout: 4), "assign sheet must list Jan (24. 6.)")
				dayRow.tap()
				sleep(2)
				// A tap flushes any pending system alert via the monitor
				// before the screenshot is taken.
				app.tabBars.buttons["Lidé"].tap()
				sleep(1)
				snap("3b-lide-assigned")
			}
		}

		app.tabBars.buttons["Nastavení"].tap()
		sleep(1)
		snap("4-nastaveni")

		// Back on Dnes the matched contacts must be visible – the shot has
		// to show the "Svátky vašich lidí" section with upcoming namedays,
		// so wait for it instead of snapping blindly.
		app.tabBars.buttons["Dnes"].tap()
		XCTAssertTrue(
			app.staticTexts["Svátky vašich lidí"].waitForExistence(timeout: 8),
			"Dnes must show upcoming contact namedays after assignment"
		)
		sleep(1)
		snap("5-dnes-kontakty")
	}

	/// Handles both contacts-permission styles: the iOS 18+ full-screen
	/// sheet ("Sdílet všechny kontakty" / "Vybrat kontakty") and the older
	/// plain alert. The sheet choice may be followed by a confirmation
	/// alert, so the alert pass always runs afterwards.
	private func grantContactsAccess(app: XCUIApplication) {
		let shareAll = app.buttons.matching(
			NSPredicate(format: "label BEGINSWITH %@", "Sdílet všechny kontakty")
		).firstMatch
		if shareAll.waitForExistence(timeout: 4) {
			shareAll.tap()
			sleep(1)
		}
		allowSystemAlertIfPresent(timeout: 6)
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
