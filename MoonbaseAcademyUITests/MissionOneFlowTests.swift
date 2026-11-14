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
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "Missing button: \(label)", file: file, line: line)
        var attempts = 0
        while !button.isHittable && attempts < 4 {
            app.swipeUp()
            attempts += 1
        }
        button.tap()
    }

    private func pause(_ seconds: Double) {
        Thread.sleep(forTimeInterval: seconds)
    }

    func testMissionOneFromLaunchToRelaunch() {
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetProgress"]
        app.launch()
        XCTAssertTrue(app.buttons["Start drill"].waitForExistence(timeout: 10))
        pause(1.5)
        shot("01-base-first-launch")

        tap("Start drill")
        XCTAssertTrue(app.buttons["Place a solar array"].waitForExistence(timeout: 5))
        pause(1)
        shot("02-tutorial-dark-habitat")

        tap("Place a solar array")
        pause(1.2)
        shot("03-first-array-powered")

        tap("Get ready for the shadow drill")
        pause(0.8)
        shot("04-planning")

        // First plan: one array and no battery. The shadow should cut the power.
        tap("Next: make a prediction")
        tap("Yes, run the test")
        pause(0.8)
        shot("05-playback-sunlight")
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 15), "The no-battery plan should fail")
        pause(0.6)
        shot("06-result-no-battery")

        // Improved plan: two arrays and two batteries, from the same starting supplies.
        tap("Try again")
        tap("Add solar array")
        tap("Add battery")
        tap("Add battery")
        pause(0.8)
        shot("07-planning-improved")
        tap("Next: make a prediction")
        tap("Yes, run the test")
        pause(2.4)
        shot("08-playback-shadow")
        XCTAssertTrue(app.buttons["Back to base"].waitForExistence(timeout: 15), "The improved plan should succeed")
        pause(0.6)
        shot("09-result-success")

        tap("Back to base")
        XCTAssertTrue(app.staticTexts["Complete"].waitForExistence(timeout: 5))
        pause(1.2)
        shot("10-base-after-mission-one")

        app.terminate()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Complete"].waitForExistence(timeout: 10), "Progress must survive a relaunch")
        pause(1.2)
        shot("11-base-after-relaunch")
    }
}
