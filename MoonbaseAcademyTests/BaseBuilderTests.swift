import XCTest
@testable import MoonbaseAcademy

/// The base builder: board rules, coins, unlocks and save migration. These are game rules, kept apart
/// from the drills' science, which these tests also check stays untouched.
final class BaseBuilderTests: MoonbaseTestCase {
    private var fresh: BaseState { BaseState.starting(from: CampaignProgress()) }

    func testNewPlayerStartsWithAHabitatAndEnoughForTheFirstDrill() {
        let base = fresh
        XCTAssertEqual(base.buildings.map(\.kind), [.habitat, .landingStation])
        XCTAssertEqual(base.landingStation?.damaged, true, "The landing station starts as a ruin")
        XCTAssertEqual(base.coins, BaseState.startingCoins)
        XCTAssertGreaterThanOrEqual(base.coins, BaseState.buildCost(.solarArray) + BaseState.buildCost(.battery))
        XCTAssertFalse(base.drillReady(.lightsOut))
        XCTAssertEqual(base.drillNeeds(.lightsOut), "Build a solar array and a battery.")
    }

    func testBuildingSpendsCoinsAndOpensTheDrill() throws {
        var base = fresh
        let progress = CampaignProgress()
        let spot = try XCTUnwrap(base.firstFreeSpot(for: .solarArray))
        XCTAssertEqual(base.build(.solarArray, x: spot.x, y: spot.y, progress: progress), .ok)
        let spot2 = try XCTUnwrap(base.firstFreeSpot(for: .battery))
        XCTAssertEqual(base.build(.battery, x: spot2.x, y: spot2.y, progress: progress), .ok)
        XCTAssertEqual(base.coins, BaseState.startingCoins - 80)
        XCTAssertTrue(base.drillReady(.lightsOut))
    }

    func testBuildingsCannotOverlapOrLeaveTheBoard() {
        var base = fresh
        let progress = CampaignProgress()
        XCTAssertFalse(base.canPlace(.solarArray, x: -1, y: -1), "The habitat covers that tile")
        XCTAssertFalse(base.canPlace(.greenhouse, x: BaseState.maxCoord, y: 0), "A 2x2 building can't hang off the edge")
        XCTAssertEqual(base.build(.solarArray, x: -1, y: -1, progress: progress), .blocked)
        XCTAssertEqual(base.coins, BaseState.startingCoins, "A refused build costs nothing")
    }

    func testHabitatLevelLimitsArraysAndBatteries() throws {
        var base = fresh
        base.coins = 10_000
        let progress = CampaignProgress()
        for _ in 0..<2 {
            let spot = try XCTUnwrap(base.firstFreeSpot(for: .solarArray))
            XCTAssertEqual(base.build(.solarArray, x: spot.x, y: spot.y, progress: progress), .ok)
        }
        let spot = try XCTUnwrap(base.firstFreeSpot(for: .solarArray))
        XCTAssertEqual(base.build(.solarArray, x: spot.x, y: spot.y, progress: progress), .limitReached)
        XCTAssertEqual(base.upgrade("habitat"), .ok)
        XCTAssertEqual(base.build(.solarArray, x: spot.x, y: spot.y, progress: progress), .ok)
    }

    func testUpgradesCostCoinsAndStopAtTheTop() {
        var base = fresh
        base.coins = 1_000
        XCTAssertEqual(base.upgrade("habitat"), .ok)
        XCTAssertEqual(base.upgrade("habitat"), .ok)
        XCTAssertEqual(base.upgrade("habitat"), .maxLevel)
        XCTAssertEqual(base.coins, 1_000 - 150 - 300)
        base.coins = 0
        var other = fresh
        other.coins = 10
        XCTAssertEqual(other.upgrade("habitat"), .notEnoughCoins(needed: 140))
    }

    func testMovingKeepsTheBuildingAndChecksTheSpot() throws {
        var base = fresh
        XCTAssertEqual(base.move("habitat", x: 2, y: 2), .ok)
        XCTAssertEqual(base.buildings.first?.x, 2)
        XCTAssertEqual(base.move("habitat", x: 4, y: 4), .blocked, "3x3 at 4,4 runs off a board that ends at 5")
    }

    func testGreenhouseNeedsTheLessonAndHarderDrillsNeedLevelTwo() throws {
        var base = fresh
        base.coins = 1_000
        let progress = CampaignProgress()
        guard case .locked = base.blueprint(.greenhouse, progress: progress) else { return XCTFail("Greenhouse should start locked") }
        _ = base.recordLesson(LessonLibrary.plantsAndAirID, firstTryCorrect: 5)
        XCTAssertEqual(base.blueprint(.greenhouse, progress: progress), .available)
        let spot = try XCTUnwrap(base.firstFreeSpot(for: .greenhouse))
        XCTAssertEqual(base.build(.greenhouse, x: spot.x, y: spot.y, progress: progress), .ok)
        XCTAssertTrue(base.drillReady(.livingBase))
        XCTAssertFalse(base.harderReady(.livingBase))
        let id = try XCTUnwrap(base.buildings.first { $0.kind == .greenhouse }?.id)
        XCTAssertEqual(base.upgrade(id), .ok)
        XCTAssertTrue(base.harderReady(.livingBase))
    }

    func testLessonCoinsArePaidFullyOnceThenSmall() {
        var base = fresh
        let first = base.recordLesson(LessonLibrary.plantsAndAirID, firstTryCorrect: 4)
        XCTAssertEqual(first, 4 * 15 + 40)
        let again = base.recordLesson(LessonLibrary.plantsAndAirID, firstTryCorrect: 5)
        XCTAssertEqual(again, 5 * 5)
        XCTAssertEqual(base.lessons[LessonLibrary.plantsAndAirID]?.bestCorrect, 5)
        XCTAssertEqual(base.lessons[LessonLibrary.plantsAndAirID]?.timesPlayed, 2)
    }

    func testDrillCoinsRewardLearningNotFailingFast() {
        XCTAssertEqual(BaseState.drillCoins(firstCompletion: true, newStars: 2, success: true), 130)
        XCTAssertEqual(BaseState.drillCoins(firstCompletion: false, newStars: 0, success: true), 15)
        XCTAssertEqual(BaseState.drillCoins(firstCompletion: false, newStars: 0, success: false), 0)
        XCTAssertEqual(BaseState.drillCoins(firstCompletion: false, newStars: 1, success: false), 25, "A correct prediction of a failure is a new star")
    }

    func testCosmeticsCostCoinsOnceAndCanBeWornAfter() {
        var base = fresh
        XCTAssertFalse(base.equip("robot.sprout"), "Can't wear what you don't own")
        XCTAssertEqual(base.buyCosmetic("robot.sprout"), .ok)
        XCTAssertEqual(base.coins, BaseState.startingCoins - 50)
        XCTAssertEqual(base.buyCosmetic("robot.sprout"), .ok, "Buying again is free")
        XCTAssertEqual(base.coins, BaseState.startingCoins - 50)
        XCTAssertTrue(base.equip("robot.sprout"))
        XCTAssertEqual(base.robot, "robot.sprout")
        base.coins = 10
        XCTAssertEqual(base.buyCosmetic("robot.astra"), .notEnoughCoins(needed: 80))
    }

    func testOlderSavesGetTheBuildingsTheyAlreadyEarned() {
        var progress = CampaignProgress()
        progress.completedMissions = [.lightsOut, .livingBase]
        progress.builtArrays = 2
        progress.builtBatteries = 2
        progress.bestStars = ["lightsOut": 3, "livingBase": 1]
        XCTAssertNil(progress.base)
        let base = progress.baseState
        XCTAssertEqual(base.count(.solarArray), 2)
        XCTAssertEqual(base.count(.battery), 2)
        XCTAssertEqual(base.count(.greenhouse), 1)
        XCTAssertTrue(base.drillReady(.lightsOut))
        XCTAssertTrue(base.drillReady(.livingBase))
        XCTAssertEqual(base.coins, BaseState.startingCoins + 20 * progress.totalStars)
        let tiles = base.buildings.flatMap(\.footprintTiles)
        XCTAssertEqual(tiles.count, Set(tiles).count, "Seeded buildings never overlap")
    }

    func testBaseSurvivesASaveRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("moonbase-base-\(UUID().uuidString)")
        let store = SaveStore(fileURL: directory.appendingPathComponent("save.json"))
        var progress = CampaignProgress()
        var base = progress.baseState
        _ = base.buyCosmetic("habitat.sky")
        _ = base.equip("habitat.sky")
        progress.base = base
        try store.save(progress)
        guard case .loaded(let loaded) = store.load() else { return XCTFail("Should load") }
        XCTAssertEqual(loaded.base?.habitatColor, "habitat.sky")
        XCTAssertEqual(loaded.base?.coins, BaseState.startingCoins - 40)
    }

    func testLessonFactsAreBuiltFromTheScienceInputs() throws {
        var s = try science()
        let lesson = LessonLibrary.plantsAndAir(science: s)
        XCTAssertEqual(lesson.unlocks, .greenhouse)
        XCTAssertGreaterThanOrEqual(lesson.questionCount, 4)
        for card in lesson.cards {
            if case .question(let q) = card {
                XCTAssertTrue(q.options.indices.contains(q.correctIndex))
                XCTAssertEqual(Set(q.options).count, q.options.count, "Options must differ")
            }
        }
        let text = lesson.cards.map { card -> String in
            switch card {
            case .teach(let f): return f.text
            case .question(let q): return q.prompt + q.options.joined()
            }
        }.joined()
        XCTAssertTrue(text.contains("33 days"))
        s.cropReferenceDays = 40
        let changed = LessonLibrary.plantsAndAir(science: s).cards.compactMap { card -> String? in
            if case .teach(let f) = card { return f.text } else { return nil }
        }.joined()
        XCTAssertTrue(changed.contains("40 days"), "Numbers come from the science package, not the lesson text")
    }

    // MARK: Guide and coin help

    func testGuideAlwaysHasOneConcreteNextGoalInOrder() throws {
        var progress = CampaignProgress()
        var base = BaseState.starting(from: progress)
        XCTAssertEqual(GuideGoal.current(base, progress), .buildArray)
        let a = try XCTUnwrap(base.firstFreeSpot(for: .solarArray))
        _ = base.build(.solarArray, x: a.x, y: a.y, progress: progress)
        XCTAssertEqual(GuideGoal.current(base, progress), .buildBattery)
        let b = try XCTUnwrap(base.firstFreeSpot(for: .battery))
        _ = base.build(.battery, x: b.x, y: b.y, progress: progress)
        XCTAssertEqual(GuideGoal.current(base, progress), .playLightsOut)
        progress.completedMissions = [.lightsOut]
        XCTAssertEqual(GuideGoal.current(base, progress), .restoreStation)
        XCTAssertEqual(base.repair("landingStation"), .ok)
        XCTAssertEqual(GuideGoal.current(base, progress), .testBase)
        base.recordBaseTest(BaseTestRecord(inputs: BaseTestInputs(arrays: 1, batteries: 1), airSunlight: 1, airShadow: 1,
                                           observation: false, success: false, headline: "The power ran out",
                                           finalBatteryKWh: 0, finalAirHours: 40, date: Date()))
        XCTAssertEqual(GuideGoal.current(base, progress), .learnPlants, "A failed test still counts as trying it")
        _ = base.recordLesson(LessonLibrary.plantsAndAirID, firstTryCorrect: 3)
        XCTAssertEqual(GuideGoal.current(base, progress), .buildGreenhouse)
    }

    func testANewPlayerCanAlwaysAffordTheFirstGoals() {
        let base = BaseState.starting(from: CampaignProgress())
        XCTAssertGreaterThanOrEqual(base.coins, BaseState.buildCost(.solarArray) + BaseState.buildCost(.battery))
    }

    func testEarnAdvisorAlwaysOffersAWayAndPutsTheBiggestFirst() throws {
        let s = try science()
        let lessons = LessonLibrary.all(science: s)
        var progress = CampaignProgress()
        var base = BaseState.starting(from: progress)
        base.coins = 0
        let fresh = EarnAdvisor.options(base: base, progress: progress, lessons: lessons)
        XCTAssertFalse(fresh.isEmpty, "Even with no buildings, a lesson pays coins")
        XCTAssertEqual(fresh.first?.action, .lesson(LessonLibrary.plantsAndAirID))
        // Spent everything on two batteries and no array: still never stuck.
        _ = base.recordLesson(LessonLibrary.plantsAndAirID, firstTryCorrect: 5)
        base.coins = 0
        let afterLesson = EarnAdvisor.options(base: base, progress: progress, lessons: lessons)
        XCTAssertFalse(afterLesson.isEmpty)
        XCTAssertEqual(afterLesson.map(\.coins), afterLesson.map(\.coins).sorted(by: >))
        // A ready drill shows up with what it pays.
        progress = CampaignProgress()
        base.buildings.append(PlacedBuilding(id: "a", kind: .solarArray, x: 3, y: 3, level: 1))
        base.buildings.append(PlacedBuilding(id: "b", kind: .battery, x: 4, y: 4, level: 1))
        let withDrill = EarnAdvisor.options(base: base, progress: progress, lessons: lessons)
        XCTAssertTrue(withDrill.contains { $0.action == .drill(.lightsOut) })
    }

    @MainActor
    func testGoalBonusesArePaidOnceAndOldSavesDontGetBackPay() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("moonbase-goals-\(UUID().uuidString)")
        let store = SaveStore(fileURL: directory.appendingPathComponent("save.json"))
        let model = AppModel(store: store)
        let start = model.baseState.coins
        model.startBuilding(.solarArray)
        XCTAssertNotNil(model.placement)
        XCTAssertTrue(model.confirmPlacement())
        XCTAssertEqual(model.baseState.coins, start - BaseState.buildCost(.solarArray) + GuideGoal.reward)
        XCTAssertEqual(model.goalToast, .buildArray)
        let reopened = AppModel(store: store)
        XCTAssertEqual(reopened.baseState.coins, model.baseState.coins, "Reopening pays nothing again")

        // A save from before the base existed: completed goals count as done, with no bonus.
        var old = CampaignProgress()
        old.completedMissions = [.lightsOut]
        let oldStore = SaveStore(fileURL: directory.appendingPathComponent("old.json"))
        try oldStore.save(old)
        let migrated = AppModel(store: oldStore)
        XCTAssertEqual(migrated.baseState.coins, BaseState.startingCoins + 20 * old.totalStars)
        XCTAssertEqual(migrated.currentGoal, .restoreStation)
    }

    @MainActor
    func testRunningOutOfCoinsOpensHelpInsteadOfAMessage() {
        let model = AppModel(store: SaveStore(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("moonbase-help-\(UUID().uuidString)").appendingPathComponent("save.json")))
        model.upgradeBuilding("habitat") // 150: affordable at the start
        model.upgradeBuilding("habitat") // 300: not affordable
        XCTAssertNotNil(model.coinHelpNeeded)
        XCTAssertNil(model.baseMessage)
        XCTAssertFalse(model.earnOptions.isEmpty)
    }

    @MainActor
    func testStylePreviewNeverSpendsOrSaves() {
        let model = AppModel(store: SaveStore(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("moonbase-preview-\(UUID().uuidString)").appendingPathComponent("save.json")))
        let coins = model.baseState.coins
        model.previewCosmetic = "board.night"
        XCTAssertEqual(model.boardSnapshot().boardColor, CosmeticCatalog.item("board.night")?.color)
        XCTAssertEqual(model.baseState.boardTheme, "board.dust", "Trying on changes nothing saved")
        XCTAssertEqual(model.baseState.coins, coins)
        model.previewCosmetic = nil
        XCTAssertEqual(model.boardSnapshot().boardColor, CosmeticCatalog.item("board.dust")?.color)
    }
}
