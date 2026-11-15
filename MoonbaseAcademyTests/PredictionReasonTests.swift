import XCTest
@testable import MoonbaseAcademy

@MainActor
final class PredictionReasonTests: MoonbaseTestCase {
    private func make(_ d: MissionDefinition, _ s: ScienceInputs, inputs: BaseTestInputs = ExampleBase.starter.inputs,
                      onRecord: @escaping (AttemptRecord, String?, Set<Achievement>) -> Bool = { _, _, _ in false }) -> MissionSession {
        let session = MissionSession(definition: d, science: s, world: WorldCoordinator(),
                                     decor: BaseDecor(progress: CampaignProgress()), reduceMotion: true,
                                     firstVisit: false, playbackMode: .stepByStep,
                                     baseTest: BaseTestContext(inputs: inputs), onRecord: onRecord)
        session.beginPlanning()
        return session
    }

    func testForecastAndReasonNeverChangeThePhysicalResult() throws {
        let s = try science()
        let d = BaseExperiment.shadowTest(inputs: ExampleBase.starter.inputs)
        var baseline: ResourceMissionResult?
        for forecast in Prediction.allCases {
            for reason in PredictionReason.choices(for: .lightsOut) + [.unsure] {
                let session = make(d, s)
                session.goToPrediction()
                session.run(predicting: forecast, reason: reason)
                session.skipPlayback()
                let result = try XCTUnwrap(session.resourceResult)
                if let baseline { XCTAssertEqual(result, baseline) } else { baseline = result }
                XCTAssertEqual(session.predictionReason, reason)
            }
        }
        XCTAssertFalse(try XCTUnwrap(baseline).success)
    }

    func testPredictionChecksOxygenGoalAsWellAsElectricity() throws {
        var s = try science()
        s.oxygenKgPerPersonDay = 1.2
        let inputs = ExampleBase.moreSunlight.inputs
        var d = BaseExperiment.shadowTest(inputs: inputs)
        d.initial.oxygenKg = 0.001
        let session = make(d, s, inputs: inputs)
        session.goToPrediction()
        session.run(predicting: .no, reason: .resourceBudget)
        session.skipPlayback()
        XCTAssertEqual(session.resourceResult?.failure?.constraint, .oxygenExhausted)
        XCTAssertEqual(session.predictionWasRight, true, "A power-only verdict would mis-score this forecast")
        XCTAssertTrue(session.copy.question.contains("oxygen"))
    }

    func testPredictionMetadataLoadsFromNewAndOldRecords() throws {
        let s = try science()
        let d = BaseExperiment.shadowTest(inputs: ExampleBase.starter.inputs)
        var saved: AttemptRecord?
        let session = make(d, s) { record, _, _ in saved = record; return false }
        session.goToPrediction()
        session.run(predicting: .yes, reason: .batteryCreatesEnergy)
        session.skipPlayback()
        let record = try XCTUnwrap(saved)
        XCTAssertEqual(record.prediction, .yes)
        XCTAssertEqual(record.predictionReason?.supported, false)
        XCTAssertEqual(record.predictionQuestion, session.copy.question)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
        for key in ["prediction", "predictionReason", "predictionQuestion"] { object.removeValue(forKey: key) }
        let legacy = try JSONDecoder().decode(AttemptRecord.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(legacy.prediction)
        XCTAssertNil(legacy.predictionReason)
        XCTAssertEqual(legacy.resourceConfiguration, record.resourceConfiguration)
    }
}
