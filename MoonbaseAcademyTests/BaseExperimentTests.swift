import XCTest
@testable import MoonbaseAcademy

/// The landing station (repair, save compatibility) and "Test My Base" (the bridge from the player's
/// real base to the unchanged resource engine). The reference Lights Out drill must stay untouched.
final class BaseExperimentTests: MoonbaseTestCase {
    private var fresh: BaseState { BaseState.starting(from: CampaignProgress()) }

    private func base(arrays: Int, batteries: Int, restored: Bool = true) -> BaseState {
        var base = fresh
        for i in 0..<arrays {
            base.buildings.append(PlacedBuilding(id: "array\(i)", kind: .solarArray, x: -6 + i, y: -6, level: 1))
        }
        for i in 0..<batteries {
            base.buildings.append(PlacedBuilding(id: "battery\(i)", kind: .battery, x: -6 + i, y: -5, level: 1))
        }
        if restored, let index = base.buildings.firstIndex(where: { $0.kind == .landingStation }) {
            base.buildings[index].damaged = nil
        }
        return base
    }

    private func simulate(arrays: Int, batteries: Int, airSun: Double = 1, airShadow: Double = 1,
                     observe: Bool = false) throws -> ResourceMissionResult {
        let inputs = BaseTestInputs(arrays: arrays, batteries: batteries)
        let d = BaseExperiment.shadowTest(inputs: inputs)
        var config = BaseExperiment.configuration(for: d, inputs: inputs)
        config.plans = [plan(airSun, research: observe ? 1 : 0), plan(airShadow)]
        return simulateResourceMission(definition: d, configuration: config, science: try science())
    }

    // MARK: Landing station

    func testTheStationIsARuinThatNeverOverlapsAndCannotBeBought() {
        let base = fresh
        let station = base.landingStation
        XCTAssertNotNil(station)
        XCTAssertEqual(station?.isWorking, false)
        let tiles = base.buildings.flatMap(\.footprintTiles)
        XCTAssertEqual(tiles.count, Set(tiles).count)
        XCTAssertFalse(base.stationRestored)
        if case .available = base.blueprint(.landingStation, progress: CampaignProgress()) {
            XCTFail("The landing station is repaired, never bought")
        }
        var again = base
        XCTAssertFalse(again.seedLandingStation(), "Seeding twice adds nothing")
        XCTAssertEqual(again, base)
    }

    func testRepairChargesExactlyOnce() {
        var base = fresh
        let coins = base.coins
        XCTAssertEqual(base.repair("landingStation"), .ok)
        XCTAssertEqual(base.coins, coins - BaseState.repairCost)
        XCTAssertTrue(base.stationRestored)
        XCTAssertEqual(base.repair("landingStation"), .ok, "Tapping again is harmless")
        XCTAssertEqual(base.coins, coins - BaseState.repairCost, "and never charges twice")
        XCTAssertEqual(base.repair("nothing"), .blocked)
    }

    func testRepairWithTooFewCoinsChangesNothing() {
        var base = fresh
        base.coins = BaseState.repairCost - 10
        XCTAssertEqual(base.repair("landingStation"), .notEnoughCoins(needed: 10))
        XCTAssertEqual(base.coins, BaseState.repairCost - 10)
        XCTAssertFalse(base.stationRestored)
    }

    func testASaveFromBeforeTheStationKeepsEverythingAndGainsTheRuin() throws {
        // A base exactly as it was written before this feature: no `damaged`, no `baseTests`,
        // and a solar array standing on the station's preferred corner.
        let json = """
        {"coins":77,"buildings":[{"id":"habitat","kind":"habitat","x":-2,"y":-2,"level":2},
        {"id":"a1","kind":"solarArray","x":4,"y":4,"level":1}],
        "ownedCosmetics":["habitat.white","board.dust","robot.nova","robot.sprout"],
        "habitatColor":"habitat.white","boardTheme":"board.dust","robot":"robot.sprout","lessons":{}}
        """
        var base = try JSONDecoder().decode(BaseState.self, from: Data(json.utf8))
        let before = base
        XCTAssertNil(base.landingStation)
        XCTAssertTrue(base.seedLandingStation())
        XCTAssertEqual(base.coins, 77)
        XCTAssertEqual(base.robot, "robot.sprout")
        XCTAssertEqual(Array(base.buildings.prefix(2)), before.buildings, "Existing buildings are untouched")
        let station = try XCTUnwrap(base.landingStation)
        XCTAssertEqual(station.damaged, true)
        let tiles = base.buildings.flatMap(\.footprintTiles)
        XCTAssertEqual(tiles.count, Set(tiles).count, "The ruin takes a free spot, never an occupied one")
        XCTAssertTrue(station.footprintTiles.allSatisfy {
            (BaseState.minCoord...BaseState.maxCoord).contains($0.x) && (BaseState.minCoord...BaseState.maxCoord).contains($0.y)
        })
        // And it survives a save round trip, damaged flag included.
        let data = try JSONEncoder().encode(base)
        XCTAssertEqual(try JSONDecoder().decode(BaseState.self, from: data), base)
    }

    // MARK: The bridge from the base to the test

    func testOnlyWorkingPowerGearBecomesTestInputs() {
        var b = base(arrays: 2, batteries: 1)
        XCTAssertEqual(BaseExperiment.inputs(from: b), BaseTestInputs(arrays: 2, batteries: 1))
        b.buildings[b.buildings.firstIndex { $0.id == "array0" }!].damaged = true
        XCTAssertEqual(BaseExperiment.inputs(from: b).arrays, 1, "A damaged building supplies nothing")
    }

    func testCosmeticsPositionsAndOtherBuildingsNeverChangeTheTest() {
        var b = base(arrays: 1, batteries: 1)
        b.coins = 10_000
        let before = BaseExperiment.shadowTest(inputs: BaseExperiment.inputs(from: b))
        XCTAssertEqual(b.buyCosmetic("board.night"), .ok)
        XCTAssertTrue(b.equip("board.night"))
        XCTAssertEqual(b.move("array0", x: 5, y: -6), .ok)
        XCTAssertEqual(BaseExperiment.shadowTest(inputs: BaseExperiment.inputs(from: b)), before)
    }

    func testEveryWorkingArrayAndBatteryCountsExactlyAsLightsOutEquipment() throws {
        var b = base(arrays: 1, batteries: 1)
        b.coins = 10_000
        let reference = MissionCatalog.lightsOut()
        var inputs = BaseExperiment.inputs(from: b)
        var d = BaseExperiment.shadowTest(inputs: inputs)
        XCTAssertEqual(d.phases, reference.phases, "Base equipment is exactly the Lights Out equipment")
        XCTAssertEqual(d.item(.battery)?.batteryCapacityKWh ?? 0, 4, accuracy: 1e-9)
        var r = simulateResourceMission(definition: d, configuration: BaseExperiment.configuration(for: d, inputs: inputs),
                                        science: try science())
        XCTAssertFalse(r.success, "One array and one battery run out at Full air")

        // Another empty battery cannot create the missing energy.
        let twoBatteries = BaseTestInputs(arrays: 1, batteries: 2)
        d = BaseExperiment.shadowTest(inputs: twoBatteries)
        r = simulateResourceMission(definition: d, configuration: BaseExperiment.configuration(for: d, inputs: twoBatteries),
                                    science: try science())
        XCTAssertFalse(r.success)

        // Another solar array does: the base gets through at Full air.
        let spot = try XCTUnwrap(b.firstFreeSpot(for: .solarArray))
        XCTAssertEqual(b.build(.solarArray, x: spot.x, y: spot.y, progress: CampaignProgress()), .ok)
        inputs = BaseExperiment.inputs(from: b)
        XCTAssertEqual(inputs, BaseTestInputs(arrays: 2, batteries: 1))
        d = BaseExperiment.shadowTest(inputs: inputs)
        r = simulateResourceMission(definition: d, configuration: BaseExperiment.configuration(for: d, inputs: inputs),
                                    science: try science())
        XCTAssertTrue(r.success)

        // Results saved when upgrades existed still load; their old level lists are ignored.
        let old = try JSONDecoder().decode(BaseTestInputs.self,
                                           from: Data(#"{"arrays":2,"batteries":1,"arrayLevels":[3,1]}"#.utf8))
        XCTAssertEqual(old, BaseTestInputs(arrays: 2, batteries: 1))
    }

    func testOldSavesLoadEveryBuildingAtLevelOne() throws {
        let json = #"{"id":"array0","kind":"solarArray","x":1,"y":2,"level":3}"#
        let building = try JSONDecoder().decode(PlacedBuilding.self, from: Data(json.utf8))
        XCTAssertEqual(building.level, 1, "Buildings have no upgrades")
        XCTAssertEqual(building.x, 1)
        XCTAssertTrue(building.isWorking)
    }

    func testComparisonNamesTheChangedEquipment() {
        let old = BaseTestInputs(arrays: 1, batteries: 1)
        XCTAssertEqual(BaseExperiment.change(from: old, to: BaseTestInputs(arrays: 2, batteries: 1)),
                       "You changed your base: +1 solar array.")
        XCTAssertEqual(BaseExperiment.change(from: old, to: old),
                       "Same base as last time. Only your plan changed.")
    }

    // MARK: Real archived storms

    func testEveryArchivedStormIsUsableAndCanBeSurvived() throws {
        let package = try bundledPackage()
        let s = try science()
        XCTAssertGreaterThanOrEqual(package.usableStorms.count, 8)
        XCTAssertEqual(package.usableStorms.count, package.events.count, "Every bundled storm record is well formed")
        XCTAssertEqual(package.events.first?.id, ScienceKeys.stormEvent)
        XCTAssertEqual(s.with(storm: try XCTUnwrap(package.events.first)), s, "The first storm is the standard drill's storm")
        for storm in package.usableStorms {
            let inputs = try XCTUnwrap(s.with(storm: storm))
            XCTAssertTrue(inputs.isPhysicallyValid, storm.id)
            let d = MissionCatalog.stormDrill(science: inputs)
            XCTAssertEqual(d.totalHours, try XCTUnwrap(storm.activeHours), accuracy: 1e-6)
            let config = ResourceConfiguration(cargo: [.shelterKit: 1], plans: [plan(1), plan(1)])
            let r = simulateResourceMission(definition: d, configuration: config, science: inputs)
            XCTAssertTrue(r.success, "The shelter with the air maker on Full gets through \(storm.id)")
        }
    }

    func testAShortStormAndALongStormNeedDifferentPlans() throws {
        let package = try bundledPackage()
        let s = try science()
        func halfAir(_ id: String) throws -> ResourceMissionResult {
            let storm = try XCTUnwrap(package.events.first { $0.id == id })
            let inputs = try XCTUnwrap(s.with(storm: storm))
            let config = ResourceConfiguration(cargo: [.shelterKit: 1], plans: [plan(0.5), plan(0.5)])
            return simulateResourceMission(definition: MissionCatalog.stormDrill(science: inputs), configuration: config, science: inputs)
        }
        XCTAssertTrue(try halfAir("sep.2017-07-14").success, "A one-day storm can be ridden out on half air")
        let long = try halfAir("sep.2012-03-07")
        XCTAssertFalse(long.success, "Nearly six days on half air empties the oxygen tank")
        XCTAssertEqual(long.failure?.constraint, .oxygenExhausted)
    }

    func testTheReferenceDrillIsLeftAlone() {
        let reference = MissionCatalog.lightsOut()
        let mine = BaseExperiment.shadowTest(inputs: BaseTestInputs(arrays: 3, batteries: 2))
        XCTAssertNil(reference.variant)
        XCTAssertEqual(reference.cargoBudget, 4)
        XCTAssertEqual(reference.item(.solarArray)?.maxCount, 4)
        XCTAssertNotEqual(mine.id, reference.id)
        XCTAssertTrue(BaseExperiment.isBaseTest(mine))
        XCTAssertFalse(BaseExperiment.isBaseTest(reference))
        // Same physics and training numbers: only the equipment source differs.
        XCTAssertEqual(mine.phases, reference.phases)
        XCTAssertEqual(mine.assumptions, reference.assumptions)
        XCTAssertEqual(mine.initial, reference.initial)
        XCTAssertEqual(mine.success, reference.success)
        XCTAssertEqual(mine.item(.battery)?.batteryCapacityKWh, reference.item(.battery)?.batteryCapacityKWh)
    }

    func testBaseTestNeedsSayWhatToDo() {
        XCTAssertNotNil(base(arrays: 1, batteries: 1, restored: false).baseTestNeeds)
        XCTAssertNotNil(base(arrays: 0, batteries: 1).baseTestNeeds)
        XCTAssertNotNil(base(arrays: 1, batteries: 0).baseTestNeeds)
        XCTAssertNil(base(arrays: 1, batteries: 1).baseTestNeeds)
        XCTAssertTrue(base(arrays: 1, batteries: 1).baseTestReady)
    }

    func testDecorationsAreLooksOnly() throws {
        var b = base(arrays: 1, batteries: 1)
        b.coins = 1_000
        let before = BaseExperiment.shadowTest(inputs: BaseExperiment.inputs(from: b))
        XCTAssertFalse(GuideGoal.decorate.isDone(b, CampaignProgress()))
        for kind in BuildingKind.allCases where kind.isDecoration {
            let spot = try XCTUnwrap(b.firstFreeSpot(for: kind))
            XCTAssertEqual(b.build(kind, x: spot.x, y: spot.y, progress: CampaignProgress()), .ok)
            XCTAssertNil(kind.drill)
        }
        XCTAssertEqual(b.coins, 1_000 - BaseState.buildCost(.flag) - BaseState.buildCost(.lamp) - BaseState.buildCost(.rockGarden))
        XCTAssertEqual(BaseExperiment.shadowTest(inputs: BaseExperiment.inputs(from: b)), before, "Decorations change no test")
        XCTAssertTrue(GuideGoal.decorate.isDone(b, CampaignProgress()))
        let tiles = b.buildings.flatMap(\.footprintTiles)
        XCTAssertEqual(tiles.count, Set(tiles).count)
    }

    func testThePowerLessonReadsItsNumbersFromTheDrill() {
        let lesson = LessonLibrary.powerAndBatteries()
        XCTAssertEqual(lesson.questionCount, 4)
        XCTAssertNil(lesson.unlocks)
        for card in lesson.cards {
            if case .question(let q) = card {
                XCTAssertTrue(q.options.indices.contains(q.correctIndex))
                XCTAssertEqual(Set(q.options).count, q.options.count, "Options must differ")
            }
        }
        let d = MissionCatalog.lightsOut()
        let needed = (d.assumptions.essentialLoadKW + d.assumptions.fullGeneratorKW) * (d.phases.last?.durationHours ?? 0)
        let text = lesson.cards.map { card -> String in
            switch card {
            case .teach(let f): return f.text
            case .question(let q): return q.prompt + q.options.joined()
            }
        }.joined()
        XCTAssertTrue(text.contains(Words.kWh(needed)), "The shadow energy question uses the drill's own numbers")
    }

    func testEveryLessonQuestionIsValidAtEveryLevel() throws {
        let s = try science()
        let topics = LessonLibrary.plantsTopics(science: s) + LessonLibrary.powerTopics()
        for topic in topics {
            for level in LearnLevel.allCases {
                XCTAssertGreaterThanOrEqual(topic.questions.filter { $0.level == level }.count, 2,
                                            "\(topic.fact.title) needs more than one question at \(level.title)")
            }
            for q in topic.questions {
                XCTAssertTrue(q.options.indices.contains(q.correctIndex), q.prompt)
                XCTAssertEqual(Set(q.options).count, q.options.count, "Options must differ: \(q.prompt)")
                XCTAssertEqual(q.options.count, q.level == .explorer ? 2 : 3, q.prompt)
                let mixed = q.shuffled()
                XCTAssertEqual(mixed.options[mixed.correctIndex], q.options[q.correctIndex], "Shuffling keeps the right answer right")
            }
        }
        for level in LearnLevel.allCases {
            for lesson in LessonLibrary.all(science: s, level: level) {
                XCTAssertEqual(lesson.questionCount * 2, lesson.cards.count, "Every fact is followed by one question")
                for card in lesson.cards {
                    if case .question(let q) = card { XCTAssertEqual(q.level, level) }
                }
            }
        }
    }

    func testTheLearnLevelIsSavedAndOldSavesDefaultToBuilder() throws {
        XCTAssertNil(CampaignProgress().learnLevel)
        var progress = CampaignProgress()
        progress.learnLevel = .engineer
        let data = try JSONEncoder().encode(progress)
        XCTAssertEqual(try JSONDecoder().decode(CampaignProgress.self, from: data).learnLevel, .engineer)
    }

    // MARK: What the engine says about real bases

    func testOneArrayOneBatteryRunsOutAtFullAir() throws {
        let r = try simulate(arrays: 1, batteries: 1)
        XCTAssertEqual(r.issues, [])
        XCTAssertFalse(r.success)
        XCTAssertEqual(r.failure?.constraint, .energyShortage)
        XCTAssertEqual(r.failure?.phaseID, "shadow")
        XCTAssertEqual(r.trace[0].after.batteryKWh, 2.4, accuracy: 1e-9)
    }

    func testTurningTheAirDownSavesPowerButSpendsOxygen() throws {
        let r = try simulate(arrays: 1, batteries: 1, airShadow: 0.5)
        XCTAssertTrue(r.success)
        XCTAssertEqual(r.finalState.batteryKWh, 0.3, accuracy: 1e-9)
        XCTAssertLessThan(r.finalState.oxygenKg, r.trace[0].after.oxygenKg, "The crew breathed from the tank in the shadow")
        XCTAssertGreaterThanOrEqual(r.finalAirHours, 24)
    }

    func testAnotherBatteryAloneDoesNotHelpWhenThereIsNothingExtraToStore() throws {
        let r = try simulate(arrays: 1, batteries: 2)
        XCTAssertFalse(r.success)
        XCTAssertEqual(r.failure?.constraint, .energyShortage)
        XCTAssertEqual(r.trace[0].after.batteryKWh, 2.4, accuracy: 1e-9, "Same stored energy as with one battery")
    }

    func testAnotherArrayFixesItAtFullAir() throws {
        let r = try simulate(arrays: 2, batteries: 1)
        XCTAssertTrue(r.success)
        XCTAssertEqual(r.trace[0].after.batteryKWh, 4, accuracy: 1e-9)
        XCTAssertEqual(r.finalState.batteryKWh, 0.4, accuracy: 1e-9)
        XCTAssertEqual(r.finalState.oxygenKg, 3.685, accuracy: 1e-9)
    }

    func testTheSameBaseAndPlanAlwaysGiveTheSameResult() throws {
        XCTAssertEqual(try simulate(arrays: 2, batteries: 2, airShadow: 0.5, observe: true),
                       try simulate(arrays: 2, batteries: 2, airShadow: 0.5, observe: true))
    }

    func testTheEquipmentCannotBeChangedInsideTheTest() throws {
        let inputs = BaseTestInputs(arrays: 1, batteries: 1)
        let d = BaseExperiment.shadowTest(inputs: inputs)
        var config = BaseExperiment.configuration(for: d, inputs: inputs)
        config.setCount(.solarArray, 3)
        let r = simulateResourceMission(definition: d, configuration: config, science: try science())
        XCTAssertFalse(r.wasSimulated, "More equipment than the base really has is rejected, not simulated")
    }

    // MARK: Rewards and records

    func testTheFirstPassPaysOnceAndFailuresCostNothing() {
        var b = base(arrays: 1, batteries: 1)
        let coins = b.coins
        let buildings = b.buildings
        func record(_ success: Bool) -> BaseTestRecord {
            BaseTestRecord(inputs: BaseTestInputs(arrays: 1, batteries: 1), airSunlight: 1, airShadow: 1,
                           observation: false, success: success, headline: "", finalBatteryKWh: 0,
                           finalAirHours: 30, date: Date())
        }
        XCTAssertFalse(b.recordBaseTest(record(false)))
        XCTAssertEqual(b.coins, coins, "A failed test costs nothing")
        XCTAssertEqual(b.buildings, buildings, "and never damages the base")
        XCTAssertTrue(b.recordBaseTest(record(true)))
        XCTAssertEqual(b.coins, coins + BaseExperiment.firstPassCoins)
        XCTAssertFalse(b.recordBaseTest(record(true)))
        XCTAssertEqual(b.coins, coins + BaseExperiment.firstPassCoins, "Passing again cannot be farmed")
        for _ in 0..<10 { b.recordBaseTest(record(false)) }
        XCTAssertEqual(b.baseTests?.count, BaseState.maxStoredBaseTests)
    }

    @MainActor
    func testTheWholeLoopRestoreTestFailReviseAndPass() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("moonbase-basetest-\(UUID().uuidString)")
        let store = SaveStore(fileURL: directory.appendingPathComponent("save.json"))
        let model = AppModel(store: store)
        model.startBuilding(.solarArray)
        XCTAssertTrue(model.confirmPlacement())
        model.startBuilding(.battery)
        XCTAssertTrue(model.confirmPlacement())

        // Not repaired yet: the test explains what to do instead of opening.
        model.openBaseTest()
        XCTAssertEqual(model.route, .base)
        XCTAssertNotNil(model.baseMessage)

        let beforeRepair = model.baseState.coins
        XCTAssertTrue(model.repairBuilding("landingStation"))
        XCTAssertEqual(model.baseState.coins, beforeRepair - BaseState.repairCost + GuideGoal.reward)
        XCTAssertTrue(model.repairBuilding("landingStation"))
        XCTAssertEqual(model.baseState.coins, beforeRepair - BaseState.repairCost + GuideGoal.reward, "No double charge, no double bonus")

        // First test: the real base (1 array, 1 battery) at full air runs out of power.
        let beforeTest = model.baseState.coins
        model.openBaseTest()
        XCTAssertEqual(model.route, .mission)
        let session = try XCTUnwrap(model.session)
        XCTAssertTrue(session.isBaseTest)
        XCTAssertEqual(session.count(.solarArray), 1)
        XCTAssertEqual(session.count(.battery), 1)
        session.beginPlanning()
        XCTAssertFalse(session.addCargo(.solarArray), "Equipment comes from the base, not from a lander")
        XCTAssertEqual(session.count(.solarArray), 1)
        session.goToPrediction()
        session.setPlaybackSpeed(5)
        XCTAssertEqual(session.playbackSpeed, 5)
        session.setPlaybackSpeed(40)
        XCTAssertEqual(session.playbackSpeed, 5, "Speed is limited to the offered range")
        session.run(predicting: .yes)
        session.skipPlayback()
        XCTAssertEqual(session.stage, .results)
        XCTAssertEqual(model.baseState.baseTests?.count, 1)
        XCTAssertEqual(model.baseState.baseTests?.last?.success, false)
        XCTAssertEqual(model.baseState.coins, beforeTest + GuideGoal.reward, "Trying the test completes its goal; failing costs nothing")

        // Revise the plan: half air in the shadow. Same base, different choice, different outcome.
        session.retry()
        session.setAir(1, 0.5)
        session.goToPrediction()
        session.run(predicting: .yes)
        session.skipPlayback()
        XCTAssertEqual(model.baseState.baseTests?.last?.success, true)
        XCTAssertEqual(model.baseState.baseTests?.last?.airShadow, 0.5)
        XCTAssertEqual(model.baseState.coins, beforeTest + GuideGoal.reward + BaseExperiment.firstPassCoins)

        // A base test is never a drill: no completion, stars or drill attempts.
        XCTAssertTrue(model.progress.completedMissions.isEmpty)
        XCTAssertEqual(model.progress.totalStars, 0)
        XCTAssertTrue(model.progress.attempts.isEmpty)
        XCTAssertFalse(model.baseState.buildings.contains { $0.damaged == true })

        model.leaveMission()
        let reopened = AppModel(store: store)
        XCTAssertTrue(reopened.baseState.stationRestored, "The repair survives a relaunch")
        XCTAssertEqual(reopened.baseState.baseTests?.count, 2)
        XCTAssertEqual(reopened.baseState.coins, model.baseState.coins)
    }
}
