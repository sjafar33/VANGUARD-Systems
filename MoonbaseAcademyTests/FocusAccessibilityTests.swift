import XCTest
@testable import MoonbaseAcademy

/// Phase 3: Focus & Accessibility settings are independent, persist, never change results,
/// and an interrupted plan reopens safely at planning without replaying or awarding anything.
@MainActor
final class FocusAccessibilityTests: MoonbaseTestCase {
    private func temporaryStore() -> SaveStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("moonbase-a11y-\(UUID().uuidString)")
        return SaveStore(fileURL: directory.appendingPathComponent("save.json"))
    }

    override nonisolated func tearDown() {
        Haptics.enabled = true
        super.tearDown()
    }

    func testEachSettingIsIndependentAndPersists() {
        let store = temporaryStore()
        let model = AppModel(store: store)
        model.setFocusView(true)
        XCTAssertFalse(model.readAloud)
        XCTAssertEqual(model.playbackMode, .automatic)
        XCTAssertFalse(model.progress.forceReducedMotion)
        model.setReadAloud(true)
        model.setHapticsEnabled(false)
        model.choosePlaybackMode(.stepByStep)
        model.setFocusView(false)
        XCTAssertTrue(model.readAloud, "Turning Focus view off leaves Read aloud alone")
        XCTAssertEqual(model.playbackMode, .stepByStep, "Pace works without Focus view")

        let reopened = AppModel(store: store)
        XCTAssertFalse(reopened.focusView)
        XCTAssertTrue(reopened.readAloud)
        XCTAssertFalse(reopened.hapticsEnabled)
        XCTAssertFalse(Haptics.enabled)
        XCTAssertEqual(reopened.playbackMode, .stepByStep)
    }

    func testFocusSuggestionsAreOnlyAStartingPoint() {
        let model = AppModel(store: temporaryStore())
        model.applyFocusSuggestions()
        XCTAssertTrue(model.focusView)
        XCTAssertEqual(model.playbackMode, .stepByStep)
        XCTAssertTrue(model.reduceMotion)
        XCTAssertFalse(model.readAloud, "Suggestions do not switch on narration")
        model.setForceReducedMotion(false)
        XCTAssertTrue(model.focusView, "Each setting stays adjustable on its own")
    }

    func testSettingsNeverChangeTheScience() throws {
        let s = try science()
        var results: [ResourceMissionResult] = []
        for (motion, mode) in [(false, PlaybackMode.automatic), (true, .automatic), (false, .stepByStep), (true, .stepByStep)] {
            let session = MissionSession(definition: MissionCatalog.lightsOut(), science: s, world: WorldCoordinator(),
                                         decor: BaseDecor(progress: CampaignProgress()), reduceMotion: motion,
                                         firstVisit: false, playbackMode: mode) { _, _, _ in false }
            session.beginPlanning()
            session.addCargo(.solarArray)
            session.addCargo(.solarArray)
            session.addCargo(.battery)
            session.addCargo(.battery)
            session.goToPrediction()
            session.run(predicting: .yes)
            results.append(try XCTUnwrap(session.resourceResult))
            session.leave()
        }
        XCTAssertTrue(results.allSatisfy { $0 == results[0] })
    }

    func testMotionSettingReachesAnOpenDrill() {
        let model = AppModel(store: temporaryStore())
        model.openMission(.lightsOut)
        model.setForceReducedMotion(true)
        XCTAssertTrue(model.reduceMotion)
        model.setForceReducedMotion(false)
        model.setSystemReduceMotion(true)
        XCTAssertTrue(model.reduceMotion, "The system setting counts too")
        model.leaveMission()
    }

    func testInterruptedPlanReopensAtPlanningWithoutRecording() throws {
        let store = temporaryStore()
        let model = AppModel(store: store)
        model.openMission(.lightsOut)
        let session = try XCTUnwrap(model.session)
        session.beginPlanning()
        session.addCargo(.solarArray)
        session.addCargo(.battery)
        let plan = session.configuration
        session.goToPrediction()
        session.run(predicting: .yes)
        XCTAssertEqual(session.stage, .playback)
        model.saveDraftForInterruption()
        session.leave() // stands in for the process ending: the running test never finishes

        // The process is killed mid-test: a new model starts from the save.
        let reopened = AppModel(store: store)
        XCTAssertTrue(reopened.progress.recentAttempts(.lightsOut).isEmpty, "The running test was never recorded")
        let draft = try XCTUnwrap(reopened.resumableDraft)
        XCTAssertEqual(draft.missionID, .lightsOut)
        XCTAssertFalse(draft.variant)
        reopened.resumeDraft()
        let resumed = try XCTUnwrap(reopened.session)
        XCTAssertEqual(resumed.stage, .planning)
        XCTAssertEqual(resumed.configuration, plan)
        XCTAssertTrue(resumed.resumedFromDraft)
        XCTAssertTrue(reopened.progress.recentAttempts(.lightsOut).isEmpty)
        reopened.leaveMission()
        XCTAssertNil(reopened.progress.draft, "Leaving on purpose clears the saved plan")
    }

    func testHarderVersionIsRestoredAsTheHarderVersion() throws {
        let store = temporaryStore()
        let model = AppModel(store: store)
        model.openMission(.lightsOut, variant: true)
        model.saveDraftForInterruption()
        let reopened = AppModel(store: store)
        reopened.resumeDraft()
        XCTAssertEqual(reopened.session?.isVariant, true)
        XCTAssertEqual(reopened.session?.definition.phases.last?.durationHours, 9)
    }

    func testInvalidSavedPlanIsIgnored() throws {
        let s = try science()
        let session = MissionSession(definition: MissionCatalog.lightsOut(), science: s, world: WorldCoordinator(),
                                     decor: BaseDecor(progress: CampaignProgress()), reduceMotion: true,
                                     firstVisit: false) { _, _, _ in false }
        let tooMuch = ResourceConfiguration(cargo: [.solarArray: 4, .battery: 4], plans: [plan(1), plan(1)])
        session.restorePlan(configuration: tooMuch, rover: nil)
        XCTAssertEqual(session.stage, .briefing)
        XCTAssertFalse(session.resumedFromDraft)
    }

    func testNarrationReadsUnitsAsWords() {
        XCTAssertEqual(Narrator.spoken("Battery 4 → 8 kWh."), "Battery 4 → 8 kilowatt hours.")
        XCTAssertEqual(Narrator.spoken("It needed 0.9 kW of power"), "It needed 0.9 kilowatts of power")
        XCTAssertEqual(Narrator.spoken("from 3.58 kg"), "from 3.58 kilograms")
        XCTAssertEqual(Narrator.spoken("kW is power"), "kW is power", "Only a unit after a number is expanded")
    }
}
