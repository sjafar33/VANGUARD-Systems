import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    enum Route: Equatable {
        case base
        case mission
    }

    enum Content {
        case ready(SciencePackage, ScienceInputs)
        case invalid([String])
    }

    let content: Content
    private(set) var progress: CampaignProgress
    private(set) var route: Route = .base
    private(set) var session: MissionSession?
    private(set) var saveIssue: String?
    private(set) var lastSaveError: String?
    /// Mission whose briefing card is open on the base screen.
    var selectedMission: MissionID?
    private(set) var systemReduceMotion = false

    func setSystemReduceMotion(_ on: Bool) {
        guard on != systemReduceMotion else { return }
        systemReduceMotion = on
        applyMotionPolicy()
    }

    /// Pushes the one reduced-motion answer to the base world and to a drill that is already open.
    private func applyMotionPolicy() {
        session?.setReduceMotion(reduceMotion)
        refreshBase()
    }

    var focusView: Bool { progress.focusView ?? false }
    var readAloud: Bool { progress.readAloud ?? false }
    var hapticsEnabled: Bool { progress.hapticsEnabled ?? true }
    var playbackMode: PlaybackMode { progress.playbackMode ?? .automatic }

    var reduceMotion: Bool { systemReduceMotion || progress.forceReducedMotion }

    @ObservationIgnored let baseWorld = WorldCoordinator()
    @ObservationIgnored let board = BoardCoordinator()

    // MARK: Base board editing (transient; never saved)

    /// A building being placed (new) or moved (existing), with the tile under its corner.
    struct Placement: Equatable {
        var kind: BuildingKind
        var movingID: String?
        var x: Int
        var y: Int
    }

    private(set) var placement: Placement?
    private(set) var selectedBuildingID: String?
    /// A short message for the base screen ("You need 20 more Moon coins").
    var baseMessage: String?
    /// Coins from the most recent finished drill, shown on the result screen.
    private(set) var lastDrillCoins = 0
    /// Set when the player tried something they can't afford: how many more coins they need (0 = just show ways).
    var coinHelpNeeded: Int?
    /// The goal just completed, for a short celebration.
    var goalToast: GuideGoal?
    /// A style being tried on in the shop. Shown on the board and on Nova; never saved.
    var previewCosmetic: String? {
        didSet { if previewCosmetic != oldValue { refreshBoard() } }
    }
    @ObservationIgnored let missionWorld = WorldCoordinator()
    @ObservationIgnored private let store: SaveStore
    @ObservationIgnored private var canSave = true

    init(store: SaveStore = SaveStore(), bundle: Bundle = .main) {
        self.store = store
        do {
            let package = try SciencePackage.loadBundled(from: bundle)
            let validation = validateContent(package: package)
            if let inputs = validation.inputs {
                content = .ready(package, inputs)
            } else {
                content = .invalid(validation.issues.map(\.message))
            }
        } catch {
            content = .invalid(["The bundled science data could not be read (\(error))."])
        }
        switch store.load() {
        case .fresh:
            progress = CampaignProgress()
        case .loaded(let saved):
            progress = saved
        case .unreadable(let reason, let preserved):
            progress = CampaignProgress()
            saveIssue = reason + (preserved == nil ? "" : " The original file was kept so it can be checked.")
            canSave = false
        }
        SoundFX.shared.enabled = progress.soundEnabled
        SoundFX.shared.musicStyle = progress.musicStyle ?? .spaceAmbient
        SoundFX.shared.musicEnabled = progress.musicEnabled ?? true
        Haptics.enabled = progress.hapticsEnabled ?? true
        baseWorld.onMarkerTapped = { [weak self] id in
            Haptics.tap()
            self?.selectedMission = id
        }
        // A save from before the base existed: give it a base now, and count goals it already did as
        // done (no bonus), so only new progress pays.
        if progress.base == nil {
            var base = progress.baseState
            base.claimedGoals = GuideGoal.allCases.filter { $0.isDone(base, progress) }.map(\.rawValue)
            progress.base = base
            save()
        }
        // A base saved before the landing station existed gets the ruin now. Nothing else on it changes.
        if var base = progress.base, base.seedLandingStation() {
            progress.base = base
            save()
        }
        board.scene.onTileTapped = { [weak self] x, y in self?.boardTileTapped(x, y) }
        board.scene.onBuildingTapped = { [weak self] id in self?.selectBuilding(id) }
        refreshBase()
    }

    var science: ScienceInputs? {
        if case .ready(_, let inputs) = content { return inputs }
        return nil
    }

    // MARK: Navigation

    func openMission(_ id: MissionID, variant: Bool = false, restoring draft: MissionDraft? = nil) {
        guard let science, progress.isUnlocked(id) else { return }
        session?.leave()
        let definition = variant ? MissionCatalog.variant(id, science: science) : MissionCatalog.definition(id, science: science)
        let firstVisit = !progress.isCompleted(id) && progress.recentAttempts(id).isEmpty
        session = MissionSession(definition: definition, science: science, world: missionWorld,
                                 decor: BaseDecor(progress: progress), reduceMotion: reduceMotion,
                                 firstVisit: firstVisit,
                                 playbackMode: progress.playbackMode ?? .automatic,
                                 onModeChange: { [weak self] mode in self?.setPlaybackMode(mode) }) { [weak self] attempt, badge, earned in
            self?.record(attempt, badge: badge, earned: earned) ?? false
        }
        if let draft, draft.missionID == id, draft.variant == variant {
            session?.restorePlan(configuration: draft.configuration, rover: draft.roverConfiguration)
        }
        selectedMission = nil
        route = .mission
    }

    // MARK: Test My Base

    /// Opens the shadow test for the player's real base. The equipment is snapshotted here, so nothing
    /// done to the base afterwards can change this test. Reference drills are not touched.
    func openBaseTest() {
        guard let science else { return }
        let base = progress.baseState
        if let needs = base.baseTestNeeds {
            baseMessage = needs
            Haptics.warning()
            return
        }
        session?.leave()
        let inputs = BaseExperiment.inputs(from: base)
        let definition = BaseExperiment.shadowTest(inputs: inputs)
        let context = BaseTestContext(inputs: inputs, previous: base.baseTests?.last)
        session = MissionSession(definition: definition, science: science, world: missionWorld,
                                 decor: BaseDecor(progress: progress), reduceMotion: reduceMotion,
                                 firstVisit: false,
                                 playbackMode: progress.playbackMode ?? .automatic,
                                 onModeChange: { [weak self] mode in self?.setPlaybackMode(mode) },
                                 baseTest: context) { [weak self] attempt, _, _ in
            self?.recordBaseTest(attempt, inputs: inputs) ?? false
        }
        selectedMission = nil
        selectedBuildingID = nil
        baseMessage = nil
        route = .mission
    }

    /// Saves a base test. It never counts as a drill: no completion, no stars, no drill attempts.
    private func recordBaseTest(_ attempt: AttemptRecord, inputs: BaseTestInputs) -> Bool {
        var base = progress.baseState
        let plans = attempt.resourceConfiguration?.plans ?? []
        let record = BaseTestRecord(inputs: inputs,
                                    airSunlight: plans.first?.airFraction ?? 1,
                                    airShadow: plans.last?.airFraction ?? 1,
                                    observation: (plans.first?.researchLevel ?? 0) > 0,
                                    success: attempt.success,
                                    headline: attempt.headline,
                                    finalBatteryKWh: attempt.finalBatteryKWh ?? 0,
                                    finalAirHours: attempt.finalAirHours ?? 0,
                                    date: attempt.date)
        let first = base.recordBaseTest(record)
        lastDrillCoins = first ? BaseExperiment.firstPassCoins : 0
        progress.base = base
        claimGoals()
        save()
        return first
    }

    // MARK: Interruption recovery

    /// The plan the player was working on before the app was closed, if it can still be opened.
    var resumableDraft: MissionDraft? {
        guard route == .base, let draft = progress.draft, progress.isUnlocked(draft.missionID) else { return nil }
        return draft
    }

    func resumeDraft() {
        guard let draft = resumableDraft else { return }
        openMission(draft.missionID, variant: draft.variant, restoring: draft)
    }

    func discardDraft() {
        progress.draft = nil
        save()
    }

    /// Called when the app stops being active. Keeps only the planning choices (never a running test),
    /// so reopening starts safely at planning and cannot replay or double-award a result.
    func saveDraftForInterruption() {
        guard route == .mission, let session else { return }
        // A base test is rebuilt from the base itself, so there is no plan to keep.
        guard !session.isBaseTest else { return }
        progress.draft = MissionDraft(missionID: session.definition.missionID,
                                      variant: session.isVariant,
                                      configuration: session.isRover ? nil : session.configuration,
                                      roverConfiguration: session.isRover ? session.roverConfiguration : nil)
        save()
    }

    func setPlaybackMode(_ mode: PlaybackMode) {
        progress.playbackMode = mode
        save()
    }

    func leaveMission() {
        progress.draft = nil
        save()
        Narrator.shared.stop()
        session?.leave()
        session = nil
        route = .base
        refreshBase()
    }

    // MARK: Progress

    private func record(_ attempt: AttemptRecord, badge: String?, earned: Set<Achievement>) -> Bool {
        let starsBefore = progress.stars(attempt.missionID)
        var base = progress.baseState
        // Completion (which unlocks the next drill) is recorded first, so `completed` is only kept for a real success.
        let first = progress.record(attempt, badge: badge)
        progress.recordAchievements(attempt.missionID, earned)
        let newStars = max(0, progress.stars(attempt.missionID) - starsBefore)
        lastDrillCoins = BaseState.drillCoins(firstCompletion: first, newStars: newStars, success: attempt.success)
        base.coins += lastDrillCoins
        progress.base = base
        claimGoals()
        if first, attempt.success, attempt.missionID == .lightsOut, let config = attempt.resourceConfiguration {
            progress.builtArrays = config.count(.solarArray)
            progress.builtBatteries = config.count(.battery)
        }
        save()
        return first
    }

    func setBaseName(_ name: String) {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
        progress.baseName = trimmed.isEmpty ? "Moonbase One" : trimmed
        save()
    }

    func setMusicStyle(_ style: MusicStyle) {
        progress.musicStyle = style
        SoundFX.shared.musicStyle = style
        save()
    }

    func setMusicEnabled(_ on: Bool) {
        progress.musicEnabled = on
        SoundFX.shared.musicEnabled = on
        save()
    }

    func setSoundEnabled(_ on: Bool) {
        progress.soundEnabled = on
        SoundFX.shared.enabled = on
        save()
    }

    func setForceReducedMotion(_ on: Bool) {
        progress.forceReducedMotion = on
        save()
        applyMotionPolicy()
    }

    func setFocusView(_ on: Bool) {
        progress.focusView = on
        save()
    }

    func setReadAloud(_ on: Bool) {
        progress.readAloud = on
        if !on { Narrator.shared.stop() }
        save()
    }

    func setHapticsEnabled(_ on: Bool) {
        progress.hapticsEnabled = on
        Haptics.enabled = on
        save()
    }

    /// From settings: also updates a drill that is open, which reports back through `setPlaybackMode`.
    func choosePlaybackMode(_ mode: PlaybackMode) {
        if let session {
            session.setPlaybackMode(mode)
        }
        setPlaybackMode(mode)
    }

    /// A starting point only. Each setting stays individually adjustable afterwards.
    func applyFocusSuggestions() {
        progress.focusView = true
        progress.playbackMode = .stepByStep
        progress.forceReducedMotion = true
        session?.setPlaybackMode(.stepByStep)
        save()
        applyMotionPolicy()
    }

    func startFresh() {
        canSave = true
        saveIssue = nil
        progress = CampaignProgress()
        save()
        refreshBase()
    }

    func resetProgress() {
        session?.leave()
        session = nil
        route = .base
        do {
            try store.reset()
            lastSaveError = nil
        } catch {
            lastSaveError = "Progress could not be cleared."
        }
        canSave = true
        progress = CampaignProgress()
        save()
        refreshBase()
    }

    private func save() {
        guard canSave else { return }
        do {
            try store.save(progress)
            lastSaveError = nil
        } catch {
            lastSaveError = "Progress could not be saved on this device."
        }
    }

    // MARK: Base world

    var nextMission: MissionID? { progress.nextMission }

    func baseSnapshot() -> WorldSnapshot {
        let decor = BaseDecor(progress: progress)
        var w = WorldSnapshot()
        w.mood = .sunlit
        w.arrays = decor.arrays
        w.batteries = decor.batteries
        w.batteryFraction = decor.batteries > 0 ? 0.8 : 0
        w.habitatLit = decor.arrays > 0
        w.greenhouse = decor.greenhouse
        w.cropFraction = 1
        w.gardenLights = decor.greenhouse
        w.shelter = decor.shelter
        w.dish = decor.dish
        w.flow = .none
        w.ambient = true
        // One quest marker at a time, standing on the site the next drill will build.
        w.markers = progress.nextMission.map { [MapMarker(mission: $0, symbol: MissionCopy.symbol($0), state: .next)] } ?? []
        return w
    }

    func refreshBase() {
        baseWorld.show(baseSnapshot(), reduceMotion: reduceMotion)
        refreshBoard()
    }

    // MARK: Base board

    var baseState: BaseState { progress.baseState }

    func boardSnapshot() -> BoardSnapshot {
        var base = progress.baseState
        if let preview = previewCosmetic, let item = CosmeticCatalog.item(preview) {
            switch item.kind {
            case .habitatColor: base.habitatColor = preview
            case .boardTheme: base.boardTheme = preview
            case .robot: base.robot = preview
            }
        }
        var s = BoardSnapshot()
        s.buildings = base.buildings.filter { $0.id != placement?.movingID }
        s.robotShell = CosmeticCatalog.item(base.robot)?.color ?? 0xFFFFFF
        s.robotEyes = CosmeticCatalog.item(base.robot)?.accent ?? 0x6FE6F2
        s.habitatTint = CosmeticCatalog.item(base.habitatColor)?.color ?? 0xFFFFFF
        let theme = CosmeticCatalog.item(base.boardTheme)
        s.boardColor = theme?.color ?? 0x9AA2AE
        s.boardTrim = theme?.accent ?? 0xD6DDE5
        s.selectedID = placement == nil ? selectedBuildingID : nil
        if let p = placement {
            s.ghost = .init(kind: p.kind, x: p.x, y: p.y, valid: placementFits)
        }
        return s
    }

    func refreshBoard() {
        board.show(boardSnapshot(), reduceMotion: reduceMotion)
    }

    var placementFits: Bool {
        guard let p = placement else { return false }
        return progress.baseState.canPlace(p.kind, x: p.x, y: p.y, excluding: p.movingID)
    }

    @discardableResult
    private func updateBase<T>(_ change: (inout BaseState) -> T) -> T {
        var base = progress.baseState
        let result = change(&base)
        progress.base = base
        claimGoals()
        save()
        refreshBoard()
        return result
    }

    // MARK: Guide and coins help

    var currentGoal: GuideGoal? { GuideGoal.current(progress.baseState, progress) }

    /// Pays the one-time bonus for every goal that is now done.
    private func claimGoals() {
        var base = progress.baseState
        var claimed = Set(base.claimedGoals ?? [])
        var newest: GuideGoal?
        for goal in GuideGoal.allCases where goal.isDone(base, progress) && !claimed.contains(goal.rawValue) {
            claimed.insert(goal.rawValue)
            base.coins += GuideGoal.reward
            newest = goal
        }
        guard let newest else { return }
        base.claimedGoals = GuideGoal.allCases.map(\.rawValue).filter { claimed.contains($0) }
        progress.base = base
        goalToast = newest
        save()
    }

    var earnOptions: [EarnOption] {
        guard let science else { return [] }
        return EarnAdvisor.options(base: progress.baseState, progress: progress, lessons: LessonLibrary.all(science: science))
    }

    func showCoinHelp() { coinHelpNeeded = 0 }

    private func explain(_ result: BaseActionResult) {
        switch result {
        case .ok: baseMessage = nil
        case .notEnoughCoins(let needed):
            baseMessage = nil
            coinHelpNeeded = needed
        case .blocked: baseMessage = "That spot is taken or off the board. Try another spot."
        case .limitReached: baseMessage = "You have as many as your habitat allows. Upgrade the habitat to build more."
        case .locked(let reason): baseMessage = reason
        case .maxLevel: baseMessage = "This building is already at the top level."
        }
        if result != .ok { Haptics.warning() }
    }

    /// Opens placement for a new building at the free spot nearest the middle.
    func startBuilding(_ kind: BuildingKind) {
        let base = progress.baseState
        if case .locked(let reason) = base.blueprint(kind, progress: progress) { return explain(.locked(reason)) }
        guard base.count(kind) < base.maxCount(kind) else {
            if kind.isDecoration {
                baseMessage = "You've placed all of those. Tap one on your base to move it."
                Haptics.warning()
                return
            }
            return explain(.limitReached)
        }
        let cost = BaseState.buildCost(kind)
        guard base.coins >= cost else { return explain(.notEnoughCoins(needed: cost - base.coins)) }
        guard let spot = base.firstFreeSpot(for: kind) else { return explain(.blocked) }
        selectedBuildingID = nil
        baseMessage = nil
        placement = Placement(kind: kind, movingID: nil, x: spot.x, y: spot.y)
        refreshBoard()
    }

    func startMoving(_ id: String) {
        guard let b = progress.baseState.buildings.first(where: { $0.id == id }) else { return }
        placement = Placement(kind: b.kind, movingID: id, x: b.x, y: b.y)
        baseMessage = nil
        refreshBoard()
    }

    func nudgePlacement(dx: Int, dy: Int) {
        guard var p = placement else { return }
        p.x = min(BaseState.maxCoord, max(BaseState.minCoord, p.x + dx))
        p.y = min(BaseState.maxCoord, max(BaseState.minCoord, p.y + dy))
        placement = p
        refreshBoard()
    }

    private func boardTileTapped(_ x: Int, _ y: Int) {
        if var p = placement {
            p.x = x
            p.y = y
            placement = p
            refreshBoard()
        } else if selectedBuildingID != nil {
            selectedBuildingID = nil
            refreshBoard()
        }
    }

    func selectBuilding(_ id: String?) {
        guard placement == nil else { return }
        if id != nil {
            Haptics.tap()
            SoundFX.shared.play(.tap)
        }
        selectedBuildingID = id
        baseMessage = nil
        refreshBoard()
    }

    func cancelPlacement() {
        placement = nil
        refreshBoard()
    }

    /// Builds or moves. Returns true when it happened.
    @discardableResult
    func confirmPlacement() -> Bool {
        guard let p = placement else { return false }
        let progressCopy = progress
        let result: BaseActionResult = updateBase { base in
            if let id = p.movingID { return base.move(id, x: p.x, y: p.y) }
            return base.build(p.kind, x: p.x, y: p.y, progress: progressCopy)
        }
        explain(result)
        guard result == .ok else { return false }
        Haptics.success()
        SoundFX.shared.play(p.movingID == nil ? .success : .pop)
        placement = nil
        refreshBoard()
        return true
    }

    @discardableResult
    func upgradeBuilding(_ id: String) -> Bool {
        let result = updateBase { $0.upgrade(id) }
        explain(result)
        if result == .ok {
            Haptics.success()
            SoundFX.shared.play(.star)
        }
        return result == .ok
    }

    /// Repairs the landing station. One charge, however many times it is tapped.
    @discardableResult
    func repairBuilding(_ id: String) -> Bool {
        let wasDamaged = progress.baseState.buildings.first { $0.id == id }?.damaged == true
        let result = updateBase { $0.repair(id) }
        explain(result)
        if result == .ok && wasDamaged {
            Haptics.success()
            SoundFX.shared.play(.success)
        }
        return result == .ok
    }

    /// "Show me" for the landing station: selects it and moves the camera to it.
    func showLandingStation() {
        guard placement == nil, let station = progress.baseState.landingStation else { return }
        selectBuilding(station.id)
        board.focus(x: station.centerX, y: station.centerY)
    }

    @discardableResult
    func buyCosmetic(_ id: String) -> Bool {
        let result = updateBase { base -> BaseActionResult in
            let bought = base.buyCosmetic(id)
            if bought == .ok { _ = base.equip(id) }
            return bought
        }
        explain(result)
        return result == .ok
    }

    func equipCosmetic(_ id: String) {
        updateBase { _ = $0.equip(id) }
    }

    /// Records a finished lesson and returns the coins earned.
    func completeLesson(_ id: String, firstTryCorrect: Int) -> Int {
        updateBase { $0.recordLesson(id, firstTryCorrect: firstTryCorrect) }
    }

    /// The board in words, for VoiceOver.
    var boardSummary: String {
        let base = progress.baseState
        var parts = ["Your base board, level \(base.habitatLevel)"]
        for kind in BuildingKind.allCases where kind != .habitat {
            let count = base.count(kind)
            if count > 0 { parts.append("\(count) \(kind.name.lowercased())\(count == 1 ? "" : "s")") }
        }
        if let p = placement {
            parts.append("Placing a \(p.kind.name.lowercased()), \(placementFits ? "it fits here" : "it does not fit here")")
        }
        return parts.joined(separator: ", ")
    }

    private var previewRobot: String? {
        guard let id = previewCosmetic, CosmeticCatalog.item(id)?.kind == .robot else { return nil }
        return id
    }

    /// Robot buddy colours for Nova.
    var novaColors: NovaColors {
        let robot = CosmeticCatalog.item(previewRobot ?? progress.baseState.robot)
        return NovaColors(shell: robot?.color ?? 0xFFFFFF, eyes: robot?.accent ?? 0x6FE6F2)
    }

    var baseSummary: String {
        let w = baseSnapshot()
        var parts = ["\(progress.baseName): a Moon base with a habitat and a rover"]
        if w.arrays > 0 { parts.append("\(w.arrays) solar arrays and \(w.batteries) batteries") }
        if w.greenhouse { parts.append("a greenhouse") }
        if w.shelter { parts.append("a storm shelter") }
        if w.dish { parts.append("a radio dish") }
        if !w.habitatLit { parts.append("the habitat is dark and needs power") }
        return parts.joined(separator: ", ")
    }
}
