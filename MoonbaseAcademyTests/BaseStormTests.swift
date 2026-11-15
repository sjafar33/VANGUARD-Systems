import XCTest
@testable import MoonbaseAcademy

final class BaseStormTests: MoonbaseTestCase {
    private func simulate(_ inputs: BaseTestInputs, _ s: ScienceInputs, firstAir: Double = 1,
                          scienceOn: Bool = false) -> ResourceMissionResult {
        let d = BaseExperiment.stormTest(inputs: inputs, science: s)
        var c = BaseExperiment.configuration(for: d, inputs: inputs)
        c.plans[0].airFraction = firstAir
        c.plans[0].researchLevel = scienceOn ? 1 : 0
        return ResourceEngine.simulate(definition: d, configuration: c, science: s)
    }

    func testStormHasARealOpportunityCostAndTwoFeasibleStrategies() throws {
        let s = try science()
        let gear = BaseTestInputs(arrays: 1, batteries: 1, shelter: true)
        let noScience = simulate(gear, s)
        XCTAssertNil(noScience.failure)
        XCTAssertFalse(noScience.success)
        XCTAssertTrue(noScience.failedConstraints.contains(.researchGoalNotReached))
        let ambitious = simulate(gear, s, scienceOn: true)
        XCTAssertEqual(ambitious.failure?.constraint, .energyShortage)
        XCTAssertEqual(try XCTUnwrap(ambitious.failure?.atHour), 10, accuracy: 1e-9)
        let reserves = simulate(gear, s, firstAir: 0.5, scienceOn: true)
        XCTAssertTrue(reserves.success)
        XCTAssertEqual(reserves.trace.first?.after.batteryKWh, 1, "4 kWh charged storage minus 3 kWh preparation")
        XCTAssertLessThan(reserves.trace[1].after.oxygenKg, reserves.initialState.oxygenKg)
        XCTAssertEqual(reserves.trace[2].before, reserves.trace[1].after, "No resource refill at the phase boundary")
        let moreStorage = simulate(BaseTestInputs(arrays: 1, batteries: 2, shelter: true), s, scienceOn: true)
        XCTAssertTrue(moreStorage.success)
        XCTAssertGreaterThan(moreStorage.finalAirHours, reserves.finalAirHours)
        let missing = simulate(BaseTestInputs(arrays: 1, batteries: 1), s, scienceOn: true)
        XCTAssertEqual(missing.failure?.constraint, .shelterMissing)
        XCTAssertEqual(simulate(gear, s, firstAir: 0.5, scienceOn: true), reserves)
    }

    func testAllArchivedStormsSupportTheReserveStrategyAndKeepReferenceRules() throws {
        let original = MissionCatalog.stormDrill(science: try science())
        for event in try bundledPackage().usableStorms {
            let s = try XCTUnwrap(try science().with(storm: event))
            let result = simulate(BaseTestInputs(arrays: 1, batteries: 1, shelter: true), s,
                                  firstAir: 0.5, scienceOn: true)
            XCTAssertTrue(result.success, event.id)
            XCTAssertEqual(result.trace.last?.endHour ?? 0, s.stormActiveHours, accuracy: 1e-9)
        }
        XCTAssertEqual(MissionCatalog.stormDrill(science: try science()), original)
        XCTAssertEqual(original.success.minimumResearchUnits, 0)
    }

    @MainActor
    func testOwnBaseStormRecordsArePinnedSeparateAndSurviveRelaunch() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("save.json")
        let store = SaveStore(fileURL: url)
        var b = BaseState.starting(from: CampaignProgress())
        b.buildings[b.buildings.firstIndex { $0.kind == .landingStation }!].damaged = nil
        b.buildings.append(PlacedBuilding(id: "array", kind: .solarArray, x: -4, y: -4, level: 1))
        b.buildings.append(PlacedBuilding(id: "battery", kind: .battery, x: -4, y: -3, level: 1))
        b.buildings.append(PlacedBuilding(id: "shelter", kind: .shelter, x: 2, y: 2, level: 1))
        try store.save(CampaignProgress(base: b))
        let model = AppModel(store: store)
        model.openBaseTest(kind: .storm)
        let session = try XCTUnwrap(model.session)
        session.beginPlanning()
        session.setAir(0, 0.5)
        session.setResearch(0, 1)
        session.goToPrediction()
        session.run(predicting: .yes)
        session.skipPlayback()
        XCTAssertEqual(session.predictionWasRight, true)
        XCTAssertEqual(model.baseState.baseTests?.last?.kind, .storm)
        XCTAssertEqual(model.baseState.baseTests?.last?.eventID, ScienceKeys.stormEvent)
        XCTAssertEqual(model.baseState.baseTests?.last?.success, true)
        model.leaveMission()
        let reopened = AppModel(store: store)
        reopened.openBaseTest()
        XCTAssertNil(reopened.session?.baseTest?.previous, "Never compare a storm with a shadow")
        reopened.openBaseTest(kind: .storm)
        XCTAssertEqual(reopened.session?.baseTest?.previous?.eventID, ScienceKeys.stormEvent)
        let before = reopened.progress
        let saved = try Data(contentsOf: url)
        reopened.openExampleMission(kind: .storm)
        let example = try XCTUnwrap(reopened.session)
        example.setAir(0, 0.5)
        example.setResearch(0, 1)
        example.goToPrediction()
        example.run(predicting: .yes)
        example.skipPlayback()
        XCTAssertTrue(try XCTUnwrap(example.currentBaseRecord).success)
        reopened.leaveMission()
        XCTAssertEqual(reopened.progress, before)
        XCTAssertEqual(try Data(contentsOf: url), saved)
    }
}
