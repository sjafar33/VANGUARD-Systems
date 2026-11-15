import XCTest
@testable import MoonbaseAcademy

final class ExperimentLearningTests: MoonbaseTestCase {
    func testShadowReportsActualStoppingTimeAndReserveCost() throws {
        let inputs = ExampleBase.starter.inputs
        let d = BaseExperiment.shadowTest(inputs: inputs)
        let s = try science()
        var c = BaseExperiment.configuration(for: d, inputs: inputs)
        let failed = ResourceEngine.simulate(definition: d, configuration: c, science: s)
        let first = BaseExperiment.record(inputs: inputs, result: failed, definition: d, headline: "")
        XCTAssertEqual(try XCTUnwrap(first.elapsedHours), 10, accuracy: 1e-9)
        XCTAssertEqual(first.plannedHours, 12)
        let explanation = ExplanationWriter.resource(failed, definition: d, science: s)
        XCTAssertTrue(explanation.paragraphs.first?.contains("2.4 kWh") == true)
        XCTAssertTrue(explanation.paragraphs.first?.contains("3.6 kWh") == true)
        c.plans[1].airFraction = 0.5
        let result = ResourceEngine.simulate(definition: d, configuration: c, science: s)
        let record = BaseExperiment.record(inputs: inputs, result: result, definition: d, headline: "")
        XCTAssertTrue(record.success)
        XCTAssertEqual(record.elapsedHours, 12)
        XCTAssertEqual(try XCTUnwrap(record.oxygenSpentKg), 0.1975, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(record.energySavedKWh), 1.5, accuracy: 1e-9)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
        for key in ["elapsedHours", "plannedHours", "oxygenSpentKg", "energySavedKWh"] { json.removeValue(forKey: key) }
        let legacy = try JSONDecoder().decode(BaseTestRecord.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(legacy.elapsedHours)
        XCTAssertTrue(legacy.timeSummary.contains("older test"))
    }

    @MainActor
    func testExampleEquipmentExperimentsPreserveThePlayersSave() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("save.json")
        let model = AppModel(store: SaveStore(fileURL: url))
        let progress = model.progress
        let saved = try Data(contentsOf: url)
        func run(_ preset: ExampleBase, reset: Bool) throws -> MissionSession {
            model.openExampleMission(preset, resetHistory: reset)
            let session = try XCTUnwrap(model.session)
            session.goToPrediction()
            session.run(predicting: .yes)
            session.skipPlayback()
            return session
        }
        let first = try run(.starter, reset: true)
        XCTAssertFalse(try XCTUnwrap(first.currentBaseRecord).success)
        let storage = try run(.moreStorage, reset: false)
        XCTAssertFalse(try XCTUnwrap(storage.currentBaseRecord).success)
        XCTAssertEqual(storage.previousBaseRecord?.inputs, ExampleBase.starter.inputs)
        let sun = try run(.moreSunlight, reset: false)
        XCTAssertTrue(try XCTUnwrap(sun.currentBaseRecord).success)
        XCTAssertEqual(sun.previousBaseRecord?.inputs, ExampleBase.moreStorage.inputs)
        XCTAssertEqual(sun.previousBaseRecord?.elapsedHours, 10)
        XCTAssertEqual(sun.currentBaseRecord?.elapsedHours, 12)
        sun.setPlaybackMode(.automatic)
        model.saveDraftForInterruption()
        model.leaveMission()
        XCTAssertEqual(model.progress, progress)
        XCTAssertEqual(try Data(contentsOf: url), saved)
    }
}
