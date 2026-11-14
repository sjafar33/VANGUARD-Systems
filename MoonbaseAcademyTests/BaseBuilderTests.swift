import XCTest
@testable import MoonbaseAcademy

/// The base builder: board rules, coins, unlocks and save migration. These are game rules, kept apart
/// from the drills' science, which these tests also check stays untouched.
final class BaseBuilderTests: MoonbaseTestCase {
    private var fresh: BaseState { BaseState.starting(from: CampaignProgress()) }

    func testNewPlayerStartsWithAHabitatAndEnoughForTheFirstDrill() {
        let base = fresh
        XCTAssertEqual(base.buildings.map(\.kind), [.habitat])
        XCTAssertEqual(base.coins, 120)
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
        XCTAssertEqual(base.coins, 40)
        XCTAssertTrue(base.drillReady(.lightsOut))
    }

    func testBuildingsCannotOverlapOrLeaveTheBoard() {
        var base = fresh
        let progress = CampaignProgress()
        XCTAssertFalse(base.canPlace(.solarArray, x: -1, y: -1), "The habitat covers that tile")
        XCTAssertFalse(base.canPlace(.greenhouse, x: BaseState.maxCoord, y: 0), "A 2x2 building can't hang off the edge")
        XCTAssertEqual(base.build(.solarArray, x: -1, y: -1, progress: progress), .blocked)
        XCTAssertEqual(base.coins, 120, "A refused build costs nothing")
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
        XCTAssertEqual(first, 4 * 10 + 30)
        let again = base.recordLesson(LessonLibrary.plantsAndAirID, firstTryCorrect: 5)
        XCTAssertEqual(again, 5 * 3)
        XCTAssertEqual(base.lessons[LessonLibrary.plantsAndAirID]?.bestCorrect, 5)
        XCTAssertEqual(base.lessons[LessonLibrary.plantsAndAirID]?.timesPlayed, 2)
    }

    func testDrillCoinsRewardLearningNotFailingFast() {
        XCTAssertEqual(BaseState.drillCoins(firstCompletion: true, newStars: 2, success: true), 100)
        XCTAssertEqual(BaseState.drillCoins(firstCompletion: false, newStars: 0, success: true), 10)
        XCTAssertEqual(BaseState.drillCoins(firstCompletion: false, newStars: 0, success: false), 0)
        XCTAssertEqual(BaseState.drillCoins(firstCompletion: false, newStars: 1, success: false), 20, "A correct prediction of a failure is a new star")
    }

    func testCosmeticsCostCoinsOnceAndCanBeWornAfter() {
        var base = fresh
        XCTAssertFalse(base.equip("robot.sprout"), "Can't wear what you don't own")
        XCTAssertEqual(base.buyCosmetic("robot.sprout"), .ok)
        XCTAssertEqual(base.coins, 120 - 50)
        XCTAssertEqual(base.buyCosmetic("robot.sprout"), .ok, "Buying again is free")
        XCTAssertEqual(base.coins, 70)
        XCTAssertTrue(base.equip("robot.sprout"))
        XCTAssertEqual(base.robot, "robot.sprout")
        XCTAssertEqual(base.buyCosmetic("robot.astra"), .notEnoughCoins(needed: 20))
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
        XCTAssertEqual(base.coins, 120 + 20 * progress.totalStars)
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
        XCTAssertEqual(loaded.base?.coins, 80)
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
}
