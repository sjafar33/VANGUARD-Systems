import XCTest

final class ExampleLabFlowTests: XCTestCase {
    private let app = XCUIApplication()

    private func tap(_ label: String) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 8), "Missing \(label)")
        for _ in 0..<5 where !button.isHittable { app.swipeUp() }
        button.tap()
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let folder = root.appendingPathComponent("Screenshots")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: folder.appendingPathComponent("example-\(name).png"))
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
        tap("example.moreStorage")
        runExperiment()
        XCTAssertTrue(app.staticTexts["The power ran out"].waitForExistence(timeout: 5))
        tap("example.moreSunlight")
        runExperiment()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
        shot("03-more-generation-passes")
        tap("Continue")
        XCTAssertTrue(app.buttons["Show me"].waitForExistence(timeout: 5), "The original starting-base guide is preserved")
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

}
