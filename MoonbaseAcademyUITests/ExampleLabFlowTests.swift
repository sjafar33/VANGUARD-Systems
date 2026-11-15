import XCTest

final class ExampleLabFlowTests: XCTestCase {
    private let app = XCUIApplication()

    private func tap(_ label: String) {
        if app.buttons["planning.section.plan"].exists {
            if label.hasPrefix("Shadow drill") || label.hasPrefix("Storm rising") || label.hasPrefix("Storm fading") {
                app.buttons["planning.section.plan"].tap()
                let index = label.hasPrefix("Shadow drill") || label.hasPrefix("Storm fading") ? 1 : 0
                app.buttons["planning.phase.\(index)"].tap()
            } else if ["Starter base", "Extra battery", "Extra array", "How this test works", "Reset lab to starter plan"].contains(label) {
                app.buttons["planning.section.equipment"].tap()
            }
        }
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
        tap("prediction.yes")
        if app.buttons["reason.shelterAndSupplies"].exists { tap("reason.shelterAndSupplies") }
        else { tap("reason.resourceBudget") }
        tap("Start test")
        tap("Skip to the result")
    }

    func testExampleCanFailChangeEquipmentAndPassWithoutUnlocks() {
        app.launchArguments = ["-uiTesting", "-resetProgress"]
        app.launch()
        tap("Drills")
        tap("Start example lab")
        shot("01-starter")
        tap("Launch test")
        tap("prediction.yes")
        tap("reason.resourceBudget")
        shot("forecast-before-first-test")
        tap("Start test")
        tap("Skip to the result")
        XCTAssertTrue(app.staticTexts["The power ran out"].waitForExistence(timeout: 5))
        shot("02-generation-shortage")
        tap("Try again")
        tap("Shadow drill, air maker: Half")
        shot("07-reserve-plan")
        runExperiment()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
        shot("08-reserve-result")
        tap("example.reset")
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
        tap("Storm rising, science: on")
        shot("04-storm-reserve-plan")
        runExperiment()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
        shot("05-storm-task-complete")
        tap("Continue")
        XCTAssertTrue(app.buttons["Show me"].waitForExistence(timeout: 5))
    }

    func testNoForecastCanMatchAFailedMissionAndLeadToRevision() {
        app.launchArguments = ["-uiTesting", "-resetProgress"]
        app.launch()
        tap("Drills")
        tap("Start example lab")
        tap("Launch test")
        tap("prediction.no")
        tap("reason.resourceBudget")
        tap("Start test")
        tap("Skip to the result")
        XCTAssertTrue(app.staticTexts["Your forecast matched. The mission still needs a working plan."].waitForExistence(timeout: 5))
        shot("correct-forecast-failed-mission")
        tap("Try one change")
        let suggestion = app.staticTexts["Suggested part for your next test"].firstMatch
        for _ in 0..<6 where !suggestion.isHittable { app.swipeUp() }
        XCTAssertTrue(suggestion.exists)
        XCTAssertTrue(app.buttons["Launch test"].isHittable, "Launch stays outside the scrolling plan")
    }

    func testUnsureAndBackAllowACompleteUnskippedInvestigation() {
        app.launchArguments = ["-uiTesting", "-resetProgress"]
        app.launch()
        tap("Drills")
        tap("Start example lab")
        tap("Shadow drill, air maker: Half")
        tap("Launch test")
        tap("prediction.no")
        tap("Change my plan")
        let half = app.buttons["Shadow drill, air maker: Half"]
        for _ in 0..<6 where !half.isHittable { app.swipeUp() }
        XCTAssertTrue(half.isSelected)
        tap("Launch test")
        tap("prediction.unsure")
        tap("Start test")
        for _ in 0..<10 {
            if app.buttons["See result"].exists { tap("See result"); break }
            if app.buttons["Next step"].waitForExistence(timeout: 8) { tap("Next step") }
            else { XCTFail("The unskipped playback must offer its next checkpoint"); break }
        }
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["You were unsure. Now you have evidence for your next idea."].exists)
        shot("unskipped-investigation")
    }

    func testPredictionWaitsForReasonAndExplainsMisconception() {
        app.launchArguments = ["-uiTesting", "-resetProgress"]
        app.launch()
        tap("Drills")
        tap("Start example lab")
        tap("Launch test")
        tap("prediction.yes")
        XCTAssertFalse(app.buttons["Start test"].isEnabled, "A forecast alone does not launch the simulation")
        tap("reason.batteryCreatesEnergy")
        shot("prediction-with-reason")
        tap("Start test")
        tap("Skip to the result")
        let feedback = app.staticTexts["prediction.reasonFeedback"]
        XCTAssertTrue(feedback.waitForExistence(timeout: 5))
        XCTAssertTrue(feedback.label.contains("cannot create"))
        shot("prediction-misconception-feedback")
    }

    func testPlanningDeskKeepsBaseVisibleAndPreservesSettings() {
        app.launchArguments = ["-uiTesting", "-resetProgress"]
        app.launch()
        tap("Drills")
        tap("Start example lab")
        let desk = app.otherElements["mission.planningDesk"].firstMatch
        XCTAssertTrue(desk.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(desk.frame.minY, app.frame.height * 0.4,
                             "Planning controls must leave a clear area for the base")
        shot("workspace-equipment")
        tap("Shadow drill, air maker: Half")
        shot("workspace-plan")
        tap("planning.section.equipment")
        tap("planning.section.plan")
        XCTAssertTrue(app.buttons["Shadow drill, air maker: Half"].isSelected)
        XCTAssertTrue(app.buttons["Launch test"].isHittable)
        tap("Leave drill")
        tap("Show me")
        tap("Place here")
        tap("Show me")
        tap("Place here")
        tap("Show me")
        tap("Start Lights Out")
        tap("Next")
        tap("Next")
        tap("Let's build!")
        tap("cargo.add.solarArray")
        tap("cargo.add.battery")
        let add = app.buttons["cargo.add.battery"]
        let remove = app.buttons["cargo.remove.battery"]
        XCTAssertTrue(add.isHittable && remove.isHittable)
        XCTAssertTrue(add.frame.intersection(remove.frame).isNull,
                      "Adding and removing equipment must have separate touch areas")
        shot("workspace-reference-equipment")
    }

    func testStormEquipmentSummaryAndRulesRemainReachable() {
        for size in ["UICTContentSizeCategoryL", "UICTContentSizeCategoryAccessibilityXXXL"] {
            app.launchArguments = ["-uiTesting", "-resetProgress", "-UIPreferredContentSizeCategoryName", size]
            app.launch()
            tap("Drills")
            tap("Start storm example")
            shot("storm-summary-\(size)")
            tap("How this test works")
            XCTAssertTrue(app.staticTexts["Protect the crew and finish the science task"].waitForExistence(timeout: 5))
            shot("storm-rules-\(size)")
            tap("Done")
            let launch = app.buttons["Launch test"]
            for _ in 0..<8 where !launch.isHittable { app.swipeUp() }
            XCTAssertTrue(launch.isHittable, "Launch stays reachable after reading the equipment rules")
            if size == "UICTContentSizeCategoryAccessibilityXXXL" {
                XCTAssertLessThan(launch.frame.height, app.frame.height * 0.15,
                                  "The fixed action must leave room to read the large-text plan")
            }
            shot("storm-layout-\(size)")
            app.terminate()
        }
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
