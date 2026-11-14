import XCTest
@testable import MoonbaseAcademy

/// Phase 1: playback is presentation only. Checkpoints point into the authoritative trace,
/// and every way of watching (automatic, step by step, skip) reaches the same single result.
final class PlaybackScriptTests: MoonbaseTestCase {
    private func garden(research: Double = 0) throws -> (ResourceMissionResult, MissionDefinition, ScienceInputs) {
        let s = try science()
        let d = MissionCatalog.livingBase(science: s)
        let config = ResourceConfiguration(plans: Array(repeating: plan(1, garden: 1, research: research), count: 3))
        return (simulateResourceMission(definition: d, configuration: config, science: s), d, s)
    }

    func testGardenFailureCheckpointsEndOnTheFailureDay() throws {
        let (r, d, s) = try garden(research: 2)
        let points = PlaybackScript.checkpoints(for: r, definition: d, science: s)
        XCTAssertFalse(points.isEmpty)
        XCTAssertEqual(points.first?.traceIndex, 0)
        XCTAssertEqual(points.last?.traceIndex, r.trace.count - 1)
        XCTAssertEqual(points.last?.title, "Day 7")
        XCTAssertTrue(points.last?.isWarning ?? false)
        XCTAssertEqual(points.map(\.traceIndex), points.map(\.traceIndex).sorted())
        XCTAssertEqual(Set(points.map(\.traceIndex)).count, points.count, "One checkpoint per trace step at most")
        XCTAssertTrue(points[0].text.contains("short every day"))
        XCTAssertLessThan(points.count, r.trace.count, "Garden days are grouped, not shown one by one")
    }

    func testGardenSuccessCheckpointsIncludeMilestones() throws {
        let (r, d, s) = try garden()
        XCTAssertTrue(r.success)
        let points = PlaybackScript.checkpoints(for: r, definition: d, science: s)
        XCTAssertTrue(points.contains { $0.text.contains("ready to harvest") })
        XCTAssertTrue(points.contains { $0.text.contains("halfway") })
        XCTAssertEqual(points.last?.traceIndex, 32)
        XCTAssertLessThanOrEqual(points.count, 10)
        for point in points {
            XCTAssertGreaterThanOrEqual(point.readingSeconds, 3.5)
        }
    }

    func testGardenFailureLeadNamesTheDailyGap() throws {
        let (r, d, s) = try garden(research: 2)
        let failure = try XCTUnwrap(r.failure)
        let lead = try XCTUnwrap(ExplanationWriter.gardenDeficitLead(r, failure))
        let last = try XCTUnwrap(r.trace.last)
        let gap = (last.demand.totalKW - last.generationKW) * 24
        XCTAssertGreaterThan(gap, 0)
        XCTAssertTrue(lead.text.contains(Format.kWh(gap)))
        XCTAssertTrue(lead.text.contains("until day 7"))
        let explanation = ExplanationWriter.resource(r, definition: d, science: s)
        XCTAssertTrue(explanation.paragraphs.first?.contains("each day") ?? false)
        XCTAssertTrue(explanation.numbers.contains { $0.label == "Short at the end" })
    }

    func testStepMissionsGetOneCheckpointPerStep() throws {
        let s = try science()
        let d = MissionCatalog.lightsOut()
        let config = ResourceConfiguration(cargo: [.solarArray: 2, .battery: 2], plans: [plan(1), plan(1)])
        let r = simulateResourceMission(definition: d, configuration: config, science: s)
        let points = PlaybackScript.checkpoints(for: r, definition: d, science: s)
        XCTAssertEqual(points.map(\.traceIndex), r.trace.map(\.index))
    }
}

@MainActor
final class PlaybackSessionTests: MoonbaseTestCase {
    private var records: [AttemptRecord] = []

    private func makeSession(mode: PlaybackMode) throws -> MissionSession {
        let s = try science()
        records = []
        let session = MissionSession(definition: MissionCatalog.livingBase(science: s), science: s,
                                     world: WorldCoordinator(), decor: BaseDecor(progress: CampaignProgress()),
                                     reduceMotion: true, firstVisit: false, playbackMode: mode) { [weak self] record, _, _ in
            self?.records.append(record)
            return false
        }
        session.beginPlanning()
        session.goToPrediction()
        return session
    }

    private func settle(_ seconds: Double = 0.35) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    func testSkipRecordsExactlyOnce() async throws {
        let session = try makeSession(mode: .automatic)
        session.run(predicting: .yes)
        XCTAssertEqual(session.stage, .playback)
        session.skipPlayback()
        session.skipPlayback()
        await settle()
        XCTAssertEqual(session.stage, .results)
        XCTAssertEqual(records.count, 1)
    }

    func testStepByStepReachesTheSameResultAsSkip() async throws {
        let skipped = try makeSession(mode: .automatic)
        skipped.run(predicting: .yes)
        let skippedResult = skipped.resourceResult
        skipped.skipPlayback()

        let stepped = try makeSession(mode: .stepByStep)
        stepped.run(predicting: .yes)
        XCTAssertEqual(stepped.resourceResult, skippedResult, "The simulation does not depend on how it is watched")
        await settle()
        XCTAssertEqual(stepped.stage, .playback, "Step by step waits for the player")
        var taps = 0
        while stepped.stage == .playback && taps < 40 {
            stepped.nextCheckpoint()
            await settle(0.25)
            taps += 1
        }
        XCTAssertEqual(stepped.stage, .results)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(taps, stepped.checkpoints.count)
    }

    func testRetryAndLeaveNeverRecordAStaleAttempt() async throws {
        let session = try makeSession(mode: .stepByStep)
        session.run(predicting: .yes)
        session.retry()
        await settle()
        XCTAssertEqual(records.count, 0)
        session.goToPrediction()
        session.run(predicting: .no)
        session.leave()
        await settle()
        XCTAssertEqual(records.count, 0)
    }

    func testLeavingTheAppPausesUntilThePlayerResumes() async throws {
        let session = try makeSession(mode: .automatic)
        session.run(predicting: .yes)
        await settle(0.2)
        session.setAppActive(false)
        XCTAssertTrue(session.isPaused)
        XCTAssertTrue(session.pausedByInterruption)
        let index = session.checkpointIndex
        await settle(4.5)
        XCTAssertEqual(session.checkpointIndex, index, "Paused playback does not move on by itself")
        XCTAssertEqual(session.stage, .playback)
        session.setAppActive(true)
        XCTAssertTrue(session.isPaused, "Coming back does not resume without the player")
        session.resumePlayback()
        XCTAssertFalse(session.isPaused)
        XCTAssertFalse(session.pausedByInterruption)
        session.skipPlayback()
        XCTAssertEqual(records.count, 1)
    }

    func testModeChangeIsReportedForSaving() throws {
        let s = try science()
        var saved: PlaybackMode?
        let session = MissionSession(definition: MissionCatalog.livingBase(science: s), science: s,
                                     world: WorldCoordinator(), decor: BaseDecor(progress: CampaignProgress()),
                                     reduceMotion: true, firstVisit: false,
                                     onModeChange: { saved = $0 }) { _, _, _ in false }
        session.setPlaybackMode(.stepByStep)
        XCTAssertEqual(saved, .stepByStep)
        XCTAssertEqual(session.playbackMode, .stepByStep)
    }
}
