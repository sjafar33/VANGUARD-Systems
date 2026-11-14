import XCTest
@testable import MoonbaseAcademy

/// Phase 2: the three stars are separate achievements, saves migrate without loss, and every
/// sentence a child reads is supported by the result or the drill's own numbers.
final class RewardTests: MoonbaseTestCase {
    private func attempt(_ id: MissionID, success: Bool) -> AttemptRecord {
        AttemptRecord(missionID: id, definitionID: id.rawValue, date: Date(timeIntervalSince1970: 1_800_000_000),
                      success: success, headline: "", finalBatteryKWh: nil, finalAirHours: nil,
                      finalStopM: nil, researchUnits: 0, resourceConfiguration: nil, roverConfiguration: nil)
    }

    func testCorrectPredictionOfAFailureEarnsOnlyThePredictionStar() {
        var progress = CampaignProgress()
        XCTAssertFalse(progress.record(attempt(.lightsOut, success: false), badge: nil))
        progress.recordAchievements(.lightsOut, [.predicted])
        XCTAssertEqual(progress.achievementSet(.lightsOut), [.predicted])
        XCTAssertEqual(progress.stars(.lightsOut), 1)
        XCTAssertFalse(progress.isCompleted(.lightsOut))
        XCTAssertFalse(progress.isUnlocked(.livingBase), "A prediction star must not unlock the next drill")
    }

    func testCompletedIsNeverKeptWithoutARealSuccess() {
        var progress = CampaignProgress()
        progress.record(attempt(.lightsOut, success: false), badge: nil)
        progress.recordAchievements(.lightsOut, [.completed, .predicted])
        XCTAssertEqual(progress.achievementSet(.lightsOut), [.predicted])
        XCTAssertFalse(progress.isUnlocked(.livingBase))
    }

    func testAchievementsAddUpAcrossAttemptsAndSurviveAFailedReplay() {
        var progress = CampaignProgress()
        progress.record(attempt(.lightsOut, success: false), badge: nil)
        progress.recordAchievements(.lightsOut, [.predicted])
        progress.record(attempt(.lightsOut, success: true), badge: nil)
        progress.recordAchievements(.lightsOut, [.completed])
        XCTAssertEqual(progress.stars(.lightsOut), 2)
        progress.record(attempt(.lightsOut, success: false), badge: nil)
        progress.recordAchievements(.lightsOut, [])
        XCTAssertEqual(progress.achievementSet(.lightsOut), [.completed, .predicted])
        XCTAssertTrue(progress.isCompleted(.lightsOut))
        XCTAssertTrue(progress.isUnlocked(.livingBase))
        progress.recordAchievements(.lightsOut, [.completed, .predicted])
        XCTAssertEqual(progress.stars(.lightsOut), 2, "The same achievement never counts twice")
    }

    func testStarResultMapsToAchievements() {
        let failedButPredicted = StarResult(finished: false, predicted: true, bonus: false)
        XCTAssertEqual(failedButPredicted.achievements, [.predicted])
        XCTAssertEqual(failedButPredicted.count, 1)
        XCTAssertEqual(StarResult(finished: true, predicted: true, bonus: true).achievements, [.completed, .predicted, .bonus])
    }

    func testLegacyStarCountsAreRebuiltExactly() {
        var progress = CampaignProgress()
        progress.completedMissions = [.lightsOut, .livingBase, .stormDrill]
        progress.badges = ["observer"]
        progress.bestStars = ["lightsOut": 3, "livingBase": 2, "stormDrill": 1]
        XCTAssertEqual(progress.achievementSet(.lightsOut), [.completed, .predicted, .bonus])
        XCTAssertEqual(progress.achievementSet(.livingBase), [.completed, .predicted], "No garden badge, so the second star was the prediction")
        XCTAssertEqual(progress.achievementSet(.stormDrill), [.completed])
        XCTAssertEqual(progress.totalStars, 6, "Migration keeps the old total")
    }

    func testSavesFromBeforeStarsGetCreditForWhatTheyFinished() {
        var progress = CampaignProgress()
        progress.completedMissions = [.lightsOut]
        progress.badges = ["observer"]
        XCTAssertNil(progress.bestStars)
        XCTAssertEqual(progress.achievementSet(.lightsOut), [.completed, .bonus])
    }

    func testAnOlderSaveFileLoadsWithoutLoss() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("moonbase-legacy-\(UUID().uuidString)")
        let store = SaveStore(fileURL: directory.appendingPathComponent("save.json"))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let json = """
        {"schemaVersion":1,"progress":{"baseName":"Old Base","completedMissions":["lightsOut","livingBase"],
        "badges":["observer"],"bestResearchUnits":{},"attempts":{},"soundEnabled":true,"forceReducedMotion":false,
        "builtArrays":2,"builtBatteries":2,"bestStars":{"lightsOut":3,"livingBase":2}}}
        """
        try Data(json.utf8).write(to: store.fileURL)
        guard case .loaded(var progress) = store.load() else { return XCTFail("The older save should load") }
        XCTAssertEqual(progress.baseName, "Old Base")
        XCTAssertEqual(progress.totalStars, 5)
        XCTAssertNil(progress.achievements)
        progress.recordAchievements(.livingBase, [.bonus])
        XCTAssertEqual(progress.stars(.livingBase), 3)
        XCTAssertEqual(progress.stars(.lightsOut), 3, "Untouched drills keep their rebuilt stars")
        try store.save(progress)
        XCTAssertEqual(store.load(), .loaded(progress))
    }
}

@MainActor
final class PredictionStarSessionTests: MoonbaseTestCase {
    func testCorrectNoOnAFailedDrillIsRecognisedAndSaved() throws {
        let s = try science()
        var earned: Set<Achievement>?
        var success: Bool?
        let session = MissionSession(definition: MissionCatalog.lightsOut(), science: s, world: WorldCoordinator(),
                                     decor: BaseDecor(progress: CampaignProgress()), reduceMotion: true,
                                     firstVisit: false) { record, _, achievements in
            earned = achievements
            success = record.success
            return false
        }
        session.beginPlanning()
        XCTAssertTrue(session.addCargo(.solarArray))
        session.goToPrediction()
        session.run(predicting: .no)
        session.skipPlayback()
        XCTAssertEqual(success, false, "One array and no battery cannot last the shadow")
        XCTAssertEqual(session.predictionWasRight, true)
        XCTAssertEqual(session.stars?.predicted, true)
        XCTAssertEqual(session.stars?.finished, false)
        XCTAssertEqual(earned, [.predicted])
    }

    func testNotSureEarnsNoPredictionStar() throws {
        let s = try science()
        var earned: Set<Achievement>?
        let session = MissionSession(definition: MissionCatalog.lightsOut(), science: s, world: WorldCoordinator(),
                                     decor: BaseDecor(progress: CampaignProgress()), reduceMotion: true,
                                     firstVisit: false) { _, _, achievements in
            earned = achievements
            return false
        }
        session.beginPlanning()
        session.addCargo(.solarArray)
        session.goToPrediction()
        session.run(predicting: .unsure)
        session.skipPlayback()
        XCTAssertNil(session.predictionWasRight)
        XCTAssertEqual(earned, [])
    }
}

final class NarrationTests: MoonbaseTestCase {
    private func resource(_ d: MissionDefinition, _ config: ResourceConfiguration) throws -> (ResourceMissionResult, Explanation) {
        let s = try science()
        let r = simulateResourceMission(definition: d, configuration: config, science: s)
        return (r, ExplanationWriter.resource(r, definition: d, science: s))
    }

    private func gardenConfig(air: Double = 1, garden: Double = 1, research: Double = 0) -> ResourceConfiguration {
        ResourceConfiguration(plans: Array(repeating: plan(air, garden: garden, research: research), count: 3))
    }

    func testGardenSuccessNoLongerClaimsAFullTankUnlessTrue() throws {
        let s = try science()
        let (r, e) = try resource(MissionCatalog.livingBase(science: s), gardenConfig())
        XCTAssertTrue(r.success)
        let text = e.paragraphs.joined(separator: " ")
        XCTAssertFalse(text.contains("kept the tank full"))
        XCTAssertGreaterThan(r.finalState.oxygenKg, r.initialState.oxygenKg)
        XCTAssertTrue(text.contains("filled from \(Format.kg(r.initialState.oxygenKg)) to \(Format.kg(r.finalState.oxygenKg))"))
        XCTAssertTrue(text.contains("day 33"))
    }

    func testAirStoryMatchesATankThatWentDown() throws {
        let s = try science()
        let d = MissionCatalog.livingBase(science: s)
        let r = simulateResourceMission(definition: d, configuration: gardenConfig(), science: s)
        var edited = r
        edited.trace[3].after.oxygenKg = r.initialState.oxygenKg - 1
        let story = ExplanationWriter.airStory(edited, definition: d, science: s)
        XCTAssertTrue(story.contains("never ran out"))
        XCTAssertTrue(story.contains(Format.kg(r.initialState.oxygenKg - 1)))
    }

    func testLightsOutOxygenSentenceOnlyWhenTheTankWentDown() throws {
        let fullAir = ResourceConfiguration(cargo: [.solarArray: 2, .battery: 2], plans: [plan(1), plan(1)])
        let (r1, e1) = try resource(MissionCatalog.lightsOut(), fullAir)
        XCTAssertTrue(r1.success)
        XCTAssertFalse(e1.paragraphs.joined().contains("oxygen tank"))
        let halfAir = ResourceConfiguration(cargo: [.solarArray: 1, .battery: 3], plans: [plan(1), plan(0.5)])
        let (r2, e2) = try resource(MissionCatalog.lightsOut(), halfAir)
        if let shadow = r2.trace.last, shadow.after.oxygenKg < shadow.before.oxygenKg - 1e-9 {
            XCTAssertTrue(e2.paragraphs.joined().contains("breathed from the oxygen tank"))
        }
    }

    func testNoBatteryCopyOnlyWhenTheShadowCausedIt() throws {
        let noArrays = ResourceConfiguration(cargo: [:], plans: [plan(1), plan(1)])
        let (r, e) = try resource(MissionCatalog.lightsOut(), noArrays)
        XCTAssertEqual(r.failure?.phaseID, "sunlit")
        XCTAssertFalse(e.paragraphs.joined().contains("made power in sunlight"))
    }

    func testStormShortageNamesWhatWasRunning() throws {
        let s = try science()
        let d = MissionCatalog.stormDrill(science: s)
        let config = ResourceConfiguration(cargo: [.shelterKit: 1, .scienceKit: 1],
                                           plans: [plan(1, research: 1), plan(1, research: 1)])
        let (r, e) = try resource(d, config)
        XCTAssertEqual(r.failure?.constraint, .energyShortage)
        let text = e.paragraphs.joined(separator: " ")
        XCTAssertTrue(text.contains("research together"))
        XCTAssertTrue(text.contains("out of the battery first"))
    }

    func testStormSuccessStatesTheDoseLimitAndRealOxygenChange() throws {
        let s = try science()
        let d = MissionCatalog.stormDrill(science: s)
        let config = ResourceConfiguration(cargo: [.shelterKit: 1, .chargedBattery: 1], plans: [plan(1), plan(1)])
        let (r, e) = try resource(d, config)
        XCTAssertTrue(r.success)
        let text = e.paragraphs.joined(separator: " ")
        XCTAssertTrue(text.contains("does not calculate a radiation dose"))
        XCTAssertEqual(text.contains("oxygen reserve"), r.finalState.oxygenKg < r.initialState.oxygenKg - 1e-9)
    }

    func testVariantCopyUsesTheVariantsNumbers() throws {
        let s = try science()
        let shadow = MissionCopy.of(MissionCatalog.variant(.lightsOut, science: s), science: s)
        XCTAssertTrue(shadow.story.contains("9-hour"))
        XCTAssertTrue(shadow.objectives[0].contains("9 hours of shadow"))
        let garden = GameCopy.of(MissionCatalog.variant(.livingBase, science: s), science: s)
        XCTAssertTrue(garden.intro.joined().contains("16 kWh"))
        XCTAssertFalse(garden.intro.joined().contains("17 kWh"))
        let storm = GameCopy.of(MissionCatalog.variant(.stormDrill, science: s), science: s)
        XCTAssertTrue(storm.intro.joined().contains("3 crates"))
        let standardStorm = GameCopy.of(MissionCatalog.stormDrill(science: s), science: s)
        XCTAssertTrue(standardStorm.intro.joined().contains("September 10, 2017"))
        XCTAssertTrue(standardStorm.intro.joined().contains("4 crates"))
    }

    func testCopyFollowsTheScienceInputs() throws {
        var s = try science()
        s.moonDistanceKm = 400_000
        let copy = MissionCopy.of(MissionCatalog.signalLag(), science: s)
        XCTAssertTrue(copy.story.contains("400,000 km"))
        XCTAssertTrue(copy.hint.contains(Format.number(400_000 / s.lightSpeedKmPerSecond)))
    }
}
