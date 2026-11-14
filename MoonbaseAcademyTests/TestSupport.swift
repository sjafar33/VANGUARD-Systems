import XCTest
@testable import MoonbaseAcademy

/// Writes a plain-text summary of each test run into `TestResults/last-run.txt` at the repository root
/// so a run can be checked without opening Xcode. Best effort: a failed write never fails a test.
final class ResultRecorder: NSObject, XCTestObservation {
    static let shared = ResultRecorder()
    private var lines: [String] = []
    private var failures = 0
    private var passed = 0
    private var registered = false

    func registerOnce() {
        guard !registered else { return }
        registered = true
        XCTestObservationCenter.shared.addTestObserver(self)
    }

    func testCase(_ testCase: XCTestCase, didRecord issue: XCTIssue) {
        failures += 1
        let location = issue.sourceCodeContext.location.map { "\($0.fileURL.lastPathComponent):\($0.lineNumber)" } ?? "?"
        lines.append("FAIL \(testCase.name) @ \(location): \(issue.compactDescription)")
    }

    func testCaseDidFinish(_ testCase: XCTestCase) {
        if let run = testCase.testRun, run.hasSucceeded {
            passed += 1
            lines.append("PASS \(testCase.name)")
        }
        write(finished: false)
    }

    func testBundleDidFinish(_ testBundle: Bundle) {
        write(finished: true)
    }

    private func write(finished: Bool) {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent("TestResults", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date())
        let header = "Moonbase Academy test run \(stamp) | finished=\(finished) | passed=\(passed) | failure records=\(failures)"
        let text = ([header] + lines).joined(separator: "\n") + "\n"
        try? text.write(to: directory.appendingPathComponent("last-run.txt"), atomically: true, encoding: .utf8)
    }
}

class MoonbaseTestCase: XCTestCase {
    override class func setUp() {
        super.setUp()
        ResultRecorder.shared.registerOnce()
    }

    func bundledPackage(file: StaticString = #filePath, line: UInt = #line) throws -> SciencePackage {
        try SciencePackage.loadBundled(from: AppBundleMarker.bundle)
    }

    func science(file: StaticString = #filePath, line: UInt = #line) throws -> ScienceInputs {
        let result = validateContent(package: try bundledPackage())
        return try XCTUnwrap(result.inputs, "bundled science package failed validation: \(result.issues)", file: file, line: line)
    }

    func plan(_ air: Double, garden: Double = 0, research: Double = 0) -> PhasePlan {
        PhasePlan(airFraction: air, gardenFraction: garden, researchLevel: research)
    }
}
