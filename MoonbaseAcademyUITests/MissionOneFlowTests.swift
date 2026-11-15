import XCTest

/// Plays Mission 1 the way a child would: first placement, a failed plan, an improved retry, success,
/// return to base, and a relaunch that must keep the progress. Saves real simulator screenshots.
final class MissionOneFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func shot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let idiom = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        let size = app.windows.firstMatch.frame.size
        let orientation = size.width > size.height ? "landscape" : "portrait"
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(idiom)-\(orientation)-\(name).png"))
    }

    private func tap(_ label: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        if (label.hasPrefix("cargo.") || label.hasPrefix("Add ")),
           app.buttons["planning.section.equipment"].exists {
            app.buttons["planning.section.equipment"].tap()
        }
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "Missing button: \(label)", file: file, line: line)
        // Wait for overlays to finish animating away instead of swiping, which could touch the world.
        let deadline = Date().addingTimeInterval(3)
        while !button.isHittable && Date() < deadline { pause(0.2) }
        button.tap()
    }

    private func pause(_ seconds: Double) {
        Thread.sleep(forTimeInterval: seconds)
    }

    func testMissionOneFromLaunchToRelaunch() {
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetProgress"]
        app.launch()
        // Base builder: Nova's goal card guides a new player. "Show me" places a solar array, then a battery.
        XCTAssertTrue(app.buttons["Show me"].waitForExistence(timeout: 10))
        pause(1.5)
        shot("01-base-first-launch")
        tap("Show me")
        pause(0.8)
        shot("01c-placing")
        tap("Place here")
        pause(1.2)
        shot("01d-goal-complete")
        tap("Show me")
        tap("Place here")
        pause(1)
        // Goal 3: play the first drill. "Show me" opens its briefing card.
        tap("Show me")
        XCTAssertTrue(app.buttons["Start Lights Out"].waitForExistence(timeout: 5), "The first drill opens once the base has power gear")
        pause(0.8)
        shot("02-mission-card")
        tap("Start Lights Out")
        pause(1)
        shot("03-nova-briefing")
        tap("Next")
        tap("Next")
        tap("Let's build!")
        pause(0.8)
        shot("04-tutorial-build-tray")

        tap("Add solar array")
        pause(1.2)
        shot("05-first-array-powered")

        // First plan: one array and no battery. The shadow should cut the power.
        tap("Launch test")
        pause(0.6)
        shot("06-prediction")
        tap("prediction.yes")
        tap("reason.resourceBudget")
        tap("Start test")
        pause(0.9)
        shot("07-countdown")
        pause(2.2)
        shot("08-playback-sunlight")
        // Automatic playback waits for reading time at every checkpoint, so allow for it.
        XCTAssertTrue(app.buttons["Next step"].waitForExistence(timeout: 8) || app.buttons["See result"].exists,
                      "Playback controls should be visible")
        shot("08b-playback-controls")
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 60), "The no-battery plan should fail")
        pause(1.2)
        shot("09-result-not-yet")

        // Improved plan: two arrays and two batteries, from the same starting supplies.
        tap("Try again")
        XCTAssertTrue(app.buttons["Launch test"].waitForExistence(timeout: 5))
        pause(0.8)
        tap("cargo.add.solarArray")
        tap("cargo.add.battery")
        tap("cargo.remove.battery")
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value BEGINSWITH %@", "0 on board"),
                                                object: app.buttons["cargo.add.battery"])
        let removalWait = XCTWaiter.wait(for: [removed], timeout: 3)
        shot("10a-after-remove")
        XCTAssertEqual(removalWait, .completed,
                       "Remove must leave zero batteries; actual value: \(String(describing: app.buttons["cargo.add.battery"].value))")
        tap("cargo.add.battery")
        tap("cargo.add.battery")
        for kind in ["solarArray", "battery"] {
            let control = app.buttons["cargo.add.\(kind)"]
            XCTAssertTrue(control.exists)
            XCTAssertTrue((control.value as? String)?.hasPrefix("2 on board") == true,
                          "The improved plan must actually contain two \(kind) items before launch")
        }
        pause(0.8)
        shot("10-planning-improved")
        tap("Launch test")
        // Second attempt: the player controls the pace, one checkpoint at a time.
        tap("One step at a time")
        tap("prediction.yes")
        tap("reason.resourceBudget")
        tap("Start test")
        XCTAssertTrue(app.buttons["Next step"].waitForExistence(timeout: 8) || app.buttons["See result"].waitForExistence(timeout: 1))
        pause(0.8)
        shot("11-playback-step-by-step")
        var guardCount = 0
        while !app.buttons["Continue"].exists && guardCount < 12 {
            if app.buttons["See result"].exists {
                app.buttons["See result"].tap()
            } else if app.buttons["Next step"].exists {
                app.buttons["Next step"].tap()
            }
            guardCount += 1
            pause(1.0)
        }
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 10), "The improved plan should succeed")
        pause(1.6)
        shot("12-result-stars")

        tap("Continue")
        // Drill 2 is unlocked in order, and needs a greenhouse, which a lesson unlocks.
        XCTAssertTrue(app.buttons["Learn"].waitForExistence(timeout: 6))
        pause(1.2)
        shot("13-base-after-mission-one")
        tap("Drills")
        XCTAssertTrue(app.buttons["The Living Base, 0 of 3 stars"].waitForExistence(timeout: 5), "Drill 2 should unlock")
        shot("13b-drills")

        app.terminate()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.buttons["Drills"].waitForExistence(timeout: 10))
        tap("Drills")
        XCTAssertTrue(app.buttons["The Living Base, 0 of 3 stars"].waitForExistence(timeout: 5), "Progress must survive a relaunch")
        pause(1.2)
        shot("14-base-after-relaunch")
    }
}
