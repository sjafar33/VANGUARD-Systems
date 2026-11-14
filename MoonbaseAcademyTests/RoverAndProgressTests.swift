import XCTest
@testable import MoonbaseAcademy

final class SignalLagTests: MoonbaseTestCase {
    private func earth(_ marker: Double, camera: Bool = false, definition: MissionDefinition = MissionCatalog.signalLag(),
                       science override: ScienceInputs? = nil) throws -> RoverMissionResult {
        let config = RoverConfiguration(mode: .earthControl, observedMarkerM: marker,
                                        cargo: camera ? [.scienceCamera: 1] : [:])
        return simulateRoverMission(definition: definition, configuration: config, science: try override ?? science())
    }

    func testReferenceMarkers() throws {
        let two = try earth(2)
        XCTAssertEqual(two.finalStopM, 4.564440764, accuracy: 1e-8)
        XCTAssertEqual(two.outcome, .stoppedShort)
        XCTAssertFalse(two.success)
        let three = try earth(3)
        XCTAssertEqual(three.finalStopM, 5.564440764, accuracy: 1e-8)
        XCTAssertEqual(three.outcome, .inBay)
        XCTAssertTrue(three.success)
        let four = try earth(4)
        XCTAssertEqual(four.finalStopM, 6.564440764, accuracy: 1e-8)
        XCTAssertEqual(four.outcome, .overshot)
    }

    func testDelayIsExactlyTwoOneWayJourneys() throws {
        let s = try science()
        let r = try earth(3)
        let oneWay = s.moonDistanceKm / s.lightSpeedKmPerSecond
        XCTAssertEqual(r.oneWayDelaySeconds, oneWay, accuracy: 1e-12)
        XCTAssertEqual(r.loopDelaySeconds, 2 * oneWay, accuracy: 1e-12)
        XCTAssertEqual(r.stopAtSecond - r.imageTakenAtSecond, 2 * oneWay, accuracy: 1e-12)
        XCTAssertEqual(r.commandSentAtSecond - r.imageTakenAtSecond, oneWay, accuracy: 1e-12)
        XCTAssertEqual(r.finalStopM - 3, 1 * 2 * oneWay, accuracy: 1e-12)
    }

    func testOnboardComputerStopsLocallyButUsesTheCargo() throws {
        let d = MissionCatalog.signalLag()
        let s = try science()
        let local = simulateRoverMission(definition: d,
                                         configuration: RoverConfiguration(mode: .onboardComputer, cargo: [.onboardComputer: 1]),
                                         science: s)
        XCTAssertEqual(local.finalStopM, 5.5, accuracy: 1e-12)
        XCTAssertTrue(local.success)
        XCTAssertFalse(local.observationEarned)
        let both = simulateRoverMission(definition: d,
                                        configuration: RoverConfiguration(mode: .onboardComputer, cargo: [.onboardComputer: 1, .scienceCamera: 1]),
                                        science: s)
        XCTAssertTrue(both.issues.contains(.overBudget(cost: 4, budget: 2)))
        let missing = simulateRoverMission(definition: d, configuration: RoverConfiguration(mode: .onboardComputer), science: s)
        XCTAssertTrue(missing.issues.contains(.controlModeNeedsComputer))
    }

    func testCameraObservationNeedsASuccessfulStop() throws {
        XCTAssertTrue(try earth(3, camera: true).observationEarned)
        XCTAssertFalse(try earth(4, camera: true).observationEarned)
        XCTAssertFalse(try earth(3).observationEarned)
    }

    func testMarkerMustBeOffered() throws {
        XCTAssertTrue(try earth(5).issues.contains(.markerNotOffered))
        XCTAssertTrue(try earth(.nan).issues.contains(.markerNotOffered))
    }

    func testSensitivityDistanceDrivesTheStop() throws {
        var s = try science()
        let base = try earth(3)
        s.moonDistanceKm *= 2
        let doubled = try earth(3, science: s)
        XCTAssertEqual(doubled.outcome, .overshot)
        XCTAssertEqual(doubled.finalStopM - 3, 2 * (base.finalStopM - 3), accuracy: 1e-9)
        s.moonDistanceKm = 100_000
        XCTAssertNotEqual(try earth(3, science: s).finalStopM, base.finalStopM)
    }

    func testSlowRoverVariantIsDerivedNotMemorized() throws {
        let s = try science()
        let variant = MissionCatalog.variant(.signalLag, science: s)
        let drift = 0.75 * s.commandLoopDelaySeconds
        let short = try earth(2.5, definition: variant)
        XCTAssertEqual(short.finalStopM, 2.5 + drift, accuracy: 1e-12)
        XCTAssertEqual(short.outcome, .stoppedShort)
        XCTAssertEqual(try earth(3.5, definition: variant).outcome, .inBay)
        XCTAssertEqual(try earth(4.5, definition: variant).outcome, .overshot)
        XCTAssertTrue(try earth(3, definition: variant).issues.contains(.markerNotOffered))
    }

    func testResourceEngineRefusesTheRoverMission() throws {
        let r = simulateResourceMission(definition: MissionCatalog.signalLag(),
                                        configuration: ResourceConfiguration(plans: []), science: try science())
        XCTAssertTrue(r.issues.contains(.wrongMissionKind))
    }
}

final class ProgressTests: MoonbaseTestCase {
    private func attempt(_ id: MissionID, success: Bool, research: Double = 0) -> AttemptRecord {
        AttemptRecord(missionID: id, definitionID: id.rawValue, date: Date(timeIntervalSince1970: 1_800_000_000),
                      success: success, headline: success ? "ok" : "retry", finalBatteryKWh: 1, finalAirHours: 30,
                      finalStopM: nil, researchUnits: research, resourceConfiguration: nil, roverConfiguration: nil)
    }

    private func temporaryStore() -> SaveStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("moonbase-tests-\(UUID().uuidString)")
        return SaveStore(fileURL: directory.appendingPathComponent("save.json"))
    }

    func testCompletionIsAwardedOnce() {
        var progress = CampaignProgress()
        XCTAssertFalse(progress.record(attempt(.lightsOut, success: false), badge: nil))
        XCTAssertFalse(progress.isCompleted(.lightsOut))
        XCTAssertTrue(progress.record(attempt(.lightsOut, success: true, research: 2), badge: "observer"))
        XCTAssertFalse(progress.record(attempt(.lightsOut, success: true, research: 1), badge: "observer"))
        XCTAssertEqual(progress.completedMissions, [.lightsOut])
        XCTAssertEqual(progress.badges, ["observer"])
        XCTAssertEqual(progress.bestResearchUnits["lightsOut"], 2)
        XCTAssertEqual(progress.recentAttempts(.lightsOut).count, 2, "history is bounded")
    }

    func testReplayFailureKeepsCompletion() {
        var progress = CampaignProgress()
        progress.record(attempt(.lightsOut, success: true), badge: nil)
        progress.record(attempt(.lightsOut, success: false), badge: nil)
        XCTAssertTrue(progress.isCompleted(.lightsOut))
    }

    func testMissionsUnlockInOrder() {
        var progress = CampaignProgress()
        XCTAssertTrue(progress.isUnlocked(.lightsOut))
        XCTAssertFalse(progress.isUnlocked(.livingBase))
        XCTAssertEqual(progress.nextMission, .lightsOut)
        progress.record(attempt(.lightsOut, success: true), badge: nil)
        XCTAssertTrue(progress.isUnlocked(.livingBase))
        XCTAssertEqual(progress.nextMission, .livingBase)
    }

    func testSaveAndReloadRoundTrip() throws {
        let store = temporaryStore()
        XCTAssertEqual(store.load(), .fresh)
        var progress = CampaignProgress()
        progress.baseName = "Tranquility"
        var record = attempt(.lightsOut, success: true)
        record.resourceConfiguration = ResourceConfiguration(cargo: [.solarArray: 2, .battery: 2], plans: [plan(1), plan(0.5)])
        progress.record(record, badge: "observer")
        try store.save(progress)
        XCTAssertEqual(store.load(), .loaded(progress))
    }

    func testDamagedSaveIsReportedAndPreserved() throws {
        let store = temporaryStore()
        try FileManager.default.createDirectory(at: store.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.fileURL)
        guard case .unreadable(_, let preserved) = store.load() else {
            return XCTFail("damaged data must not load as progress")
        }
        let backup = try XCTUnwrap(preserved)
        XCTAssertEqual(try Data(contentsOf: backup), Data("not json".utf8))
    }

    func testUnsupportedSchemaIsNotLoaded() throws {
        let store = temporaryStore()
        try store.save(CampaignProgress())
        var text = try String(contentsOf: store.fileURL, encoding: .utf8)
        text = text.replacingOccurrences(of: "\"schemaVersion\" : 1", with: "\"schemaVersion\" : 99")
        try Data(text.utf8).write(to: store.fileURL)
        guard case .unreadable = store.load() else { return XCTFail("unsupported schema must be reported") }
    }

    func testResetClearsTheSave() throws {
        let store = temporaryStore()
        try store.save(CampaignProgress())
        try store.reset()
        XCTAssertEqual(store.load(), .fresh)
    }
}

final class MusicTests: MoonbaseTestCase {
    func testLofiLoopIsDeterministicAudibleAndNeverClips() {
        let rate = 8_000.0
        let first = LofiComposer.render(sampleRate: rate)
        let second = LofiComposer.render(sampleRate: rate)
        XCTAssertEqual(first.count, Int(LofiComposer.loopSeconds() * rate))
        XCTAssertEqual(first, second)
        let peak = first.map { abs($0) }.max() ?? 0
        XCTAssertLessThanOrEqual(peak, 0.81)
        XCTAssertGreaterThan(peak, 0.5)
        XCTAssertEqual(LofiComposer.loopSeconds(), 16 * 4 * 60 / 72, accuracy: 1e-9)
    }
}

final class AmbientMusicTests: MoonbaseTestCase {
    func testAmbientLoopIsDeterministicAndNeverClips() {
        let rate = 8_000.0
        let first = LofiComposer.renderAmbient(sampleRate: rate)
        XCTAssertEqual(first.count, Int(LofiComposer.ambientLoopSeconds() * rate))
        XCTAssertEqual(first, LofiComposer.renderAmbient(sampleRate: rate))
        let peak = first.map { abs($0) }.max() ?? 0
        XCTAssertLessThanOrEqual(peak, 0.81)
        XCTAssertGreaterThan(peak, 0.5)
    }
}
