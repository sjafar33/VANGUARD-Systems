import XCTest

/// Settings → Guided mission tour, end to end, on the isolated UI-test save.
final class GuidedTourFlowTests: XCTestCase {
    private let app = XCUIApplication()
    private var taps = 0

    private func tap(_ label: String, timeout: TimeInterval = 8) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "Missing \(label)")
        button.tap()
        taps += 1
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "tour-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testTourRunsFromSettingsFailsThenPassesAndReturnsToBase() {
        app.launchArguments = ["-uiTesting", "-resetProgress"]
        app.launch()
        tap("Settings")
        tap("settings.guidedTour")
        XCTAssertTrue(app.buttons["tour.next"].waitForExistence(timeout: 8))
        taps = 0
        let started = Date()
        shot("1-question")

        tap("tour.next")
        tap("prediction.yes")
        tap("reason.batteryCreatesEnergy")
        tap("Start test")
        // Playback is shortened by the tour; the result appears by itself.
        XCTAssertTrue(app.buttons["Try one change"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Power ran out at hour 10 of 12"].exists)
        shot("2-first-result")

        tap("Try one change")
        XCTAssertFalse(app.buttons["Launch test"].isEnabled, "Launch waits for the one change")
        tap("Shadow drill, air maker: Half")
        shot("3-one-change")
        tap("Launch test")
        tap("prediction.yes")
        tap("reason.resourceBudget")
        tap("Start test")
        XCTAssertTrue(app.staticTexts["Shadow drill air: Full → Half"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["1.5 kWh"].exists || app.staticTexts["Electricity saved, 1.5 kWh"].exists)
        shot("4-comparison")

        tap("tour.next")
        XCTAssertTrue(app.buttons["tour.replay"].waitForExistence(timeout: 5))
        shot("5-takeaway")
        let elapsed = Date().timeIntervalSince(started)
        let timing = XCTAttachment(string: "Automated run: \(String(format: "%.1f", elapsed)) s, \(taps) taps (machine pace, not a human rehearsal)")
        timing.name = "tour-timing"
        timing.lifetime = .keepAlways
        add(timing)

        tap("tour.finish")
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["tour.exit"].exists)
    }

    func testExitDuringTheTourReturnsToBase() {
        app.launchArguments = ["-uiTesting", "-resetProgress"]
        app.launch()
        tap("Settings")
        tap("settings.guidedTour")
        tap("tour.next")
        tap("prediction.unsure")
        tap("Start test")
        tap("tour.exit")
        XCTAssertTrue(app.buttons["Drills"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["tour.exit"].exists)
    }
}
