import XCTest
@testable import MoonbaseAcademy

/// The guided mission tour: real engine results, one controlled change, and no effect on a saved game.
@MainActor
final class GuidedTourTests: MoonbaseTestCase {
    private func model() -> (AppModel, SaveStore, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("moonbase-tour-\(UUID().uuidString)").appendingPathComponent("save.json")
        let store = SaveStore(fileURL: url)
        return (AppModel(store: store), store, url)
    }

    /// Chooses a forecast and reason the way the prediction card does, starts the test and goes to its result.
    private func test(_ session: MissionSession, forecast: Prediction = .yes, reason: PredictionReason = .resourceBudget) {
        session.choosePrediction(forecast)
        if forecast != .unsure { session.chooseReason(reason) }
        session.run(predicting: forecast, reason: forecast == .unsure ? .unsure : reason)
        session.skipPlayback()
    }

    func testFirstTestFailsAndOneChangePassesWithAnOxygenCost() throws {
        let (app, _, _) = model()
        app.startGuidedTour()
        let tour = try XCTUnwrap(app.tour)
        let session = try XCTUnwrap(app.session)
        XCTAssertEqual(app.route, .mission)
        XCTAssertEqual(session.stage, .planning)
        XCTAssertEqual(session.configuration, tour.start)
        XCTAssertEqual(session.baseTest?.inputs, ExampleBase.starter.inputs)
        XCTAssertTrue(session.configuration.plans.allSatisfy { $0.airFraction == 1 }, "The tour starts at Full air")
        XCTAssertEqual(tour.step(for: session.stage), .question)

        tour.next(session)
        XCTAssertEqual(session.stage, .predicting)
        XCTAssertEqual(tour.step(for: session.stage), .predict)
        test(session, forecast: .yes, reason: .batteryCreatesEnergy)

        XCTAssertEqual(tour.step(for: session.stage), .baseline)
        let first = try XCTUnwrap(tour.baseline)
        XCTAssertFalse(first.record.success)
        XCTAssertEqual(try XCTUnwrap(first.record.elapsedHours), 10, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(first.storedKWh), 2.4, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(first.neededKWh), 3.6, accuracy: 1e-9)
        XCTAssertEqual(first.forecastRight, false, "A wrong forecast is reported honestly")

        tour.next(session)
        XCTAssertEqual(session.stage, .planning)
        XCTAssertEqual(tour.step(for: session.stage), .change)
        XCTAssertNotNil(tour.launchBlock(stage: session.stage, configuration: session.configuration))
        XCTAssertEqual(tour.airToHighlight(stage: session.stage, phase: tour.shadowIndex, configuration: session.configuration), tour.halfAir)
        session.setAir(tour.shadowIndex, tour.halfAir)
        XCTAssertEqual(session.configuration, tour.target)
        XCTAssertNil(tour.launchBlock(stage: session.stage, configuration: session.configuration))
        XCTAssertTrue(tour.wantsLaunch(stage: session.stage, configuration: session.configuration))

        session.goToPrediction()
        XCTAssertEqual(tour.step(for: session.stage), .repredict)
        test(session)

        XCTAssertEqual(tour.step(for: session.stage), .compare)
        let second = try XCTUnwrap(tour.revised)
        XCTAssertTrue(second.record.success)
        XCTAssertEqual(try XCTUnwrap(second.record.elapsedHours), 12, accuracy: 1e-9)
        XCTAssertEqual(second.record.inputs, first.record.inputs, "Same equipment in both tests")
        XCTAssertEqual(tour.changes.count, 1)
        XCTAssertTrue(tour.changes.first?.contains("Full → Half") == true)
        XCTAssertEqual(try XCTUnwrap(tour.electricitySavedKWh), 1.5, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(tour.oxygenUsedKg), 0.1975, accuracy: 1e-9)

        tour.next(session)
        XCTAssertEqual(tour.step(for: session.stage), .takeaway)
        tour.next(session)
        tour.next(session)
        XCTAssertEqual(tour.step(for: session.stage), .takeaway, "Extra taps on Next do nothing")
        tour.back(session)
        XCTAssertEqual(tour.step(for: session.stage), .compare)
    }

    func testAnUnsureForecastChangesNothingPhysical() throws {
        let (app, _, _) = model()
        app.startGuidedTour()
        let tour = try XCTUnwrap(app.tour)
        let session = try XCTUnwrap(app.session)
        tour.next(session)
        test(session, forecast: .unsure)
        let first = try XCTUnwrap(tour.baseline)
        XCTAssertNil(first.forecastRight)
        XCTAssertFalse(first.record.success)
        XCTAssertEqual(try XCTUnwrap(first.record.elapsedHours), 10, accuracy: 1e-9)
    }

    func testBackRepeatedNextAndDeviationsStayConsistent() throws {
        let (app, _, _) = model()
        app.startGuidedTour()
        let tour = try XCTUnwrap(app.tour)
        let session = try XCTUnwrap(app.session)
        XCTAssertFalse(tour.canGoBack(stage: session.stage))

        // Repeated Next from the first step opens the prediction once and then waits.
        tour.next(session)
        tour.next(session)
        XCTAssertEqual(session.stage, .predicting)
        tour.back(session)
        XCTAssertEqual(session.stage, .planning)
        XCTAssertEqual(tour.step(for: session.stage), .question)

        // A plan changed before the first test is put back to the starting plan.
        session.setAir(0, tour.halfAir)
        XCTAssertNotNil(tour.launchBlock(stage: session.stage, configuration: session.configuration))
        tour.next(session)
        XCTAssertEqual(session.configuration, tour.start)
        test(session)
        XCTAssertNotNil(tour.baseline)

        // Back from the first result clears it and returns to the start.
        tour.back(session)
        XCTAssertNil(tour.baseline)
        XCTAssertEqual(session.stage, .planning)
        XCTAssertEqual(tour.step(for: session.stage), .question)

        tour.next(session)
        test(session)
        tour.next(session)
        tour.next(session)
        XCTAssertEqual(tour.step(for: session.stage), .change, "Next waits for the real choice")

        // Changing a second setting is not a one-change experiment, so Launch is held back with a reason.
        session.setAir(tour.shadowIndex, tour.halfAir)
        session.setAir(0, tour.halfAir)
        let reason = try XCTUnwrap(tour.launchBlock(stage: session.stage, configuration: session.configuration))
        XCTAssertTrue(reason.contains("only one thing"))
        XCTAssertFalse(tour.wantsLaunch(stage: session.stage, configuration: session.configuration))
        tour.back(session)
        XCTAssertEqual(session.configuration, tour.start)
        XCTAssertNil(tour.baseline)
    }

    func testTheTourNeverChangesASavedGame() throws {
        let (app, store, url) = model()
        app.devAddCoins(120)
        app.choosePlaybackMode(.stepByStep)
        app.setFocusView(true)
        let progress = app.progress
        let saved = try Data(contentsOf: url)

        app.startGuidedTour()
        let tour = try XCTUnwrap(app.tour)
        let session = try XCTUnwrap(app.session)
        tour.next(session)
        test(session, forecast: .no, reason: .arraysWorkInShadow)
        tour.next(session)
        session.setAir(tour.shadowIndex, tour.halfAir)
        session.goToPrediction()
        test(session)
        XCTAssertEqual(tour.revised?.record.success, true)
        XCTAssertEqual(app.lastDrillCoins, 0)
        session.setPlaybackMode(.automatic)
        app.saveDraftForInterruption()
        tour.next(session)

        // Replay starts the same scenario again with nothing carried over.
        app.startGuidedTour()
        let replay = try XCTUnwrap(app.tour)
        XCTAssertFalse(replay === tour)
        XCTAssertTrue(tour.ended)
        XCTAssertNil(replay.baseline)
        XCTAssertEqual(app.session?.configuration, replay.start)
        XCTAssertEqual(app.session?.stage, .planning)

        app.leaveMission()
        XCTAssertNil(app.tour)
        XCTAssertNil(app.session)
        XCTAssertEqual(app.route, .base)
        XCTAssertEqual(app.progress, progress, "Coins, stars, buildings, drafts, histories and preferences are unchanged")
        XCTAssertEqual(try Data(contentsOf: url), saved)
        XCTAssertEqual(AppModel(store: store).progress, progress, "Still unchanged after a relaunch")
    }

    func testLeavingDuringATestStopsTheTourCleanly() async throws {
        let (app, _, url) = model()
        let saved = try Data(contentsOf: url)
        app.startGuidedTour()
        let tour = try XCTUnwrap(app.tour)
        let session = try XCTUnwrap(app.session)
        tour.next(session)
        session.choosePrediction(.yes)
        session.chooseReason(.resourceBudget)
        session.run(predicting: .yes, reason: .resourceBudget)
        XCTAssertEqual(session.stage, .playback)
        tour.playbackStarted(session, reduceMotion: true)

        app.leaveMission()
        XCTAssertTrue(tour.ended)
        XCTAssertEqual(app.route, .base)
        try await Task.sleep(nanoseconds: 900_000_000)
        // Neither the tour's delayed skip nor a late finish may record anything.
        XCTAssertEqual(session.stage, .playback)
        session.skipPlayback()
        XCTAssertNil(tour.baseline)
        XCTAssertNil(app.tour)
        XCTAssertEqual(try Data(contentsOf: url), saved)
    }

    func testPlaybackIsShortenedButTheResultIsTheEngineResult() async throws {
        let (app, _, _) = model()
        app.startGuidedTour()
        let tour = try XCTUnwrap(app.tour)
        let session = try XCTUnwrap(app.session)
        tour.next(session)
        session.choosePrediction(.yes)
        session.chooseReason(.resourceBudget)
        session.run(predicting: .yes, reason: .resourceBudget)
        XCTAssertNil(session.countdown, "The tour skips the countdown")
        let computed = try XCTUnwrap(session.resourceResult)
        tour.playbackStarted(session, reduceMotion: true)
        try await Task.sleep(nanoseconds: 1_200_000_000)
        XCTAssertEqual(session.stage, .results)
        XCTAssertEqual(session.resourceResult, computed)
        XCTAssertEqual(tour.baseline?.record.success, computed.success)

        // Back during the second test cancels it and keeps the first result.
        tour.next(session)
        session.setAir(tour.shadowIndex, tour.halfAir)
        session.goToPrediction()
        session.choosePrediction(.yes)
        session.chooseReason(.resourceBudget)
        session.run(predicting: .yes, reason: .resourceBudget)
        tour.playbackStarted(session, reduceMotion: true)
        tour.back(session)
        XCTAssertEqual(session.stage, .planning)
        try await Task.sleep(nanoseconds: 900_000_000)
        XCTAssertEqual(session.stage, .planning)
        XCTAssertNil(tour.revised)
        XCTAssertNotNil(tour.baseline)
        XCTAssertEqual(tour.step(for: session.stage), .change)
    }

    func testStartingTheTourFromADrillKeepsThatPlanResumable() throws {
        let (app, _, _) = model()
        app.openMission(.lightsOut)
        try XCTSkipUnless(app.session != nil, "Lights Out is not open in a fresh save")
        app.startGuidedTour()
        XCTAssertNotNil(app.tour)
        XCTAssertEqual(app.progress.draft?.missionID, .lightsOut)
        app.leaveMission()
        XCTAssertEqual(app.progress.draft?.missionID, .lightsOut, "Leaving the tour does not discard the drill plan")
    }
}
