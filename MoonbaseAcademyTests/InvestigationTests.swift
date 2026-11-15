import XCTest
@testable import MoonbaseAcademy

@MainActor
final class InvestigationTests: MoonbaseTestCase {
    private func model() -> (AppModel, URL) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("save.json")
        return (AppModel(store: SaveStore(fileURL: url)), url)
    }

    private func run(_ session: MissionSession, forecast: Prediction = .yes, reason: PredictionReason = .resourceBudget) {
        session.goToPrediction()
        session.run(predicting: forecast, reason: reason)
        session.skipPlayback()
    }

    func testRevisionRetainsTheOriginalIdeaAndIdentifiesOneChange() throws {
        let (app, url) = model()
        let saved = try Data(contentsOf: url)
        app.openExampleMission()
        let session = try XCTUnwrap(app.session)
        run(session, reason: .batteryCreatesEnergy)
        XCTAssertFalse(try XCTUnwrap(session.currentAttempt).success)
        session.reviseExperiment()
        XCTAssertEqual(session.stage, .planning)
        XCTAssertEqual(session.revisionPhaseIndex, 1)
        XCTAssertEqual(session.currentAttempt?.reason, .batteryCreatesEnergy)
        session.setAir(1, 0.5)
        run(session)
        XCTAssertTrue(try XCTUnwrap(session.currentAttempt).success)
        XCTAssertEqual(session.previousAttempt?.prediction, .yes)
        XCTAssertEqual(session.previousAttempt?.reason, .batteryCreatesEnergy)
        XCTAssertEqual(session.previousAttempt?.elapsedHours, 10)
        XCTAssertEqual(session.currentAttempt?.elapsedHours, 12)
        XCTAssertEqual(session.investigationChanges?.count, 1)
        XCTAssertTrue(session.investigationChanges?.first?.contains("Full → Half") == true)
        XCTAssertEqual(try XCTUnwrap(session.learningRecord?.oxygenSpentKg), 0.1975, accuracy: 1e-9)
        XCTAssertEqual(try Data(contentsOf: url), saved)
    }

    func testEquipmentPreservesThePlanAndResetIsExplicit() throws {
        let (app, url) = model()
        let saved = try Data(contentsOf: url)
        app.openExampleMission()
        let first = try XCTUnwrap(app.session)
        first.setAir(1, 0.5)
        first.setResearch(0, 1)
        let choices = first.configuration.plans
        run(first, forecast: .no)
        app.openExampleMission(.moreStorage, resetHistory: false)
        let next = try XCTUnwrap(app.session)
        XCTAssertEqual(next.configuration.plans, choices)
        XCTAssertFalse(next.resumedFromDraft)
        XCTAssertEqual(next.currentAttempt?.prediction, .no)
        run(next)
        XCTAssertEqual(next.investigationChanges, ["Battery: 1 → 2"])
        XCTAssertEqual(next.previousBaseRecord?.inputs, ExampleBase.starter.inputs)
        XCTAssertEqual(next.currentBaseRecord?.predictionReason, .resourceBudget)
        let data = try JSONEncoder().encode(next.currentBaseRecord)
        let decoded = try JSONDecoder().decode(BaseTestRecord?.self, from: data)
        XCTAssertEqual(decoded?.resourceConfiguration, next.configuration)
        app.openExampleMission(.starter, resetHistory: true)
        XCTAssertEqual(app.session?.plan(1).airFraction, 1)
        XCTAssertEqual(app.session?.plan(0).researchLevel, 0)
        XCTAssertNil(app.session?.currentAttempt)
        XCTAssertEqual(try Data(contentsOf: url), saved)
    }

    func testChangingOnlyTheForecastRepeatsTheSamePhysics() throws {
        let (app, _) = model()
        app.openExampleMission()
        let session = try XCTUnwrap(app.session)
        run(session)
        let physical = session.resourceResult
        session.reviseExperiment()
        run(session, forecast: .no, reason: .arraysWorkInShadow)
        XCTAssertEqual(session.resourceResult, physical)
        XCTAssertEqual(session.investigationChanges, [])
        XCTAssertEqual(session.predictionWasRight, true)
        XCTAssertEqual(session.predictionReason?.supported, false, "A right forecast can still have the wrong mechanism")
    }
}
