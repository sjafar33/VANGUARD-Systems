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
        // Completion (which unlocks the next drill) is recorded first, so `completed` is only kept for a real success.
        let first = progress.record(attempt, badge: badge)
        progress.recordAchievements(attempt.missionID, earned)
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
