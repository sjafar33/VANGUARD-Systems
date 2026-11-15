import XCTest

final class ExampleLabFlowTests: XCTestCase {
    private let app = XCUIApplication()

    private func tap(_ label: String) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 8), "Missing \(label)")
        let tray = app.scrollViews["mission.planningTray"]
        if (label.hasPrefix("Storm rising") || label.hasPrefix("Shadow drill")), tray.exists {
            for _ in 0..<3 where !button.isHittable { tray.swipeLeft() }
        }
        for _ in 0..<5 where !button.isHittable { app.swipeUp() }
        button.tap()
    }

    private func shot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.8) // Capture the settled UI, after the route transition.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let folder = root.appendingPathComponent("Screenshots")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: folder.appendingPathComponent("example-\(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone")-\(name).png"))
    }

    private func runExperiment() {
        tap("Launch test")
        tap("Yes")
        tap("Skip to the result")
    }

    func testExampleCanFailChangeEquipmentAndPassWithoutUnlocks() {
        app.launchArguments = ["-uiTesting", "-resetProgress"]
        app.launch()
        tap("Drills")
        tap("Start example lab")
        shot("01-starter")
        runExperiment()
        XCTAssertTrue(app.staticTexts["The power ran out"].waitForExistence(timeout: 5))
        shot("02-generation-shortage")
        tap("Try again")
        tap("Shadow drill, air maker: Half")
        shot("07-reserve-plan")
        runExperiment()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
        shot("08-reserve-result")
        tap("example.moreStorage")
        runExperiment()
        XCTAssertTrue(app.staticTexts["The power ran out"].waitForExistence(timeout: 5))
        tap("example.moreSunlight")
        runExperiment()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
        shot("03-more-generation-passes")
        tap("Continue")
        XCTAssertTrue(app.buttons["Show me"].waitForExistence(timeout: 5), "The original starting-base guide is preserved")
        shot("09-home-base")
        tap("NASA sources")
        shot("10-nasa-sources")
        tap("Done")
    }
    func testStormExampleRequiresScienceAndCanSpendReservesToSucceed() {
        app.launchArguments = ["-uiTesting", "-resetProgress"]
        app.launch()
        tap("Drills")
        tap("Start storm example")
        runExperiment()
        XCTAssertTrue(app.staticTexts["Crew safe, science task unfinished"].waitForExistence(timeout: 5))
        tap("Try again")
        tap("Storm rising, air maker: Half")
        tap("Storm rising, science: off")
        shot("04-storm-reserve-plan")
        runExperiment()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
        shot("05-storm-task-complete")
        tap("Continue")
        XCTAssertTrue(app.buttons["Show me"].waitForExistence(timeout: 5))
    }

    func testLargeTextExampleStillReachesResult() {
        app.launchArguments = ["-uiTesting", "-resetProgress", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        tap("Drills")
        tap("Start example lab")
        shot("06-large-text-planning")
        runExperiment()
        XCTAssertTrue(app.staticTexts["The power ran out"].waitForExistence(timeout: 5))
        tap("Try again")
        XCTAssertTrue(app.buttons["Launch test"].waitForExistence(timeout: 5))
    }

}
