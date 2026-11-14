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
    private(set) var systemReduceMotion = false

    func setSystemReduceMotion(_ on: Bool) {
        guard on != systemReduceMotion else { return }
        systemReduceMotion = on
        refreshBase()
    }

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
        refreshBase()
    }

    var science: ScienceInputs? {
        if case .ready(_, let inputs) = content { return inputs }
        return nil
    }

    // MARK: Navigation

    func openMission(_ id: MissionID, variant: Bool = false) {
        guard let science, progress.isUnlocked(id) else { return }
        session?.leave()
        let definition = variant ? MissionCatalog.variant(id, science: science) : MissionCatalog.definition(id, science: science)
        let firstVisit = !progress.isCompleted(id) && progress.recentAttempts(id).isEmpty
        session = MissionSession(definition: definition, science: science, world: missionWorld,
                                 decor: BaseDecor(progress: progress), reduceMotion: reduceMotion,
                                 firstVisit: firstVisit) { [weak self] attempt, badge in
            self?.record(attempt, badge: badge) ?? false
        }
        route = .mission
    }

    func leaveMission() {
        session?.leave()
        session = nil
        route = .base
        refreshBase()
    }

    // MARK: Progress

    private func record(_ attempt: AttemptRecord, badge: String?) -> Bool {
        let first = progress.record(attempt, badge: badge)
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

    func setForceReducedMotion(_ on: Bool) {
        progress.forceReducedMotion = on
        save()
        refreshBase()
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
