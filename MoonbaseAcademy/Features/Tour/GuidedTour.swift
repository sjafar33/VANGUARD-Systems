import Foundation
import Observation

/// The beats of the guided mission tour, in order.
enum TourStep: Int, CaseIterable, Equatable {
    case question
    case predict
    case baseline
    case change
    case repredict
    case compare
    case takeaway
}

/// What one tour test really did, copied from the engine's result when the test finished.
struct TourEvidence: Equatable {
    var record: BaseTestRecord
    /// Battery energy when the shadow began, and what this shadow plan needed. From the trace.
    var storedKWh: Double?
    var neededKWh: Double?
    var forecast: String?
    /// Nil when the player chose "not sure".
    var forecastRight: Bool?
}

/// The guided mission tour: a short, repeatable investigation on an example base.
///
/// This object only holds where the tour is and the evidence from its two tests. The mission itself is
/// an ordinary example `MissionSession` using the shared engine, so nothing here can change a result.
/// It never touches saved progress.
@MainActor
@Observable
final class GuidedTour {
    /// The starting plan (starter equipment, Full air) and the one allowed change (shadow air to Half).
    let start: ResourceConfiguration
    let target: ResourceConfiguration
    let shadowIndex: Int
    let halfAir: Double
    let phaseLabels: [String]

    private(set) var baseline: TourEvidence?
    private(set) var revised: TourEvidence?
    private(set) var showTakeaway = false
    private(set) var ended = false

    @ObservationIgnored private var skipTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0

    init(start: ResourceConfiguration, shadowIndex: Int, halfAir: Double, phaseLabels: [String]) {
        self.start = start
        self.shadowIndex = shadowIndex
        self.halfAir = halfAir
        self.phaseLabels = phaseLabels
        var changed = start
        if changed.plans.indices.contains(shadowIndex) { changed.plans[shadowIndex].airFraction = halfAir }
        self.target = changed
    }

    // MARK: Where the tour is

    /// The step is worked out from the real mission stage plus the evidence gathered so far,
    /// so the tour cannot drift away from what the mission is actually showing.
    func step(for stage: MissionStage) -> TourStep {
        if baseline != nil, revised != nil, stage == .results {
            return showTakeaway ? .takeaway : .compare
        }
        if baseline != nil {
            switch stage {
            case .briefing, .planning: return .change
            case .predicting, .playback: return .repredict
            case .results: return .baseline
            }
        }
        switch stage {
        case .briefing, .planning: return .question
        case .predicting: return .predict
        case .playback, .results: return .baseline
        }
    }

    func canGoBack(stage: MissionStage) -> Bool { step(for: stage) != .question || stage == .playback }

    /// Why Launch is unavailable right now, or nil when the plan is the one this step tests.
    func launchBlock(stage: MissionStage, configuration: ResourceConfiguration) -> String? {
        guard stage == .planning else { return nil }
        switch step(for: stage) {
        case .question:
            return configuration == start ? nil : "The tour starts with Full air in both parts. Tap Predict to reset the plan."
        case .change:
            if configuration == target { return nil }
            if configuration == start { return "Tap Half for the shadow air maker first." }
            return "For this tour, change only one thing: the shadow air maker to Half."
        default:
            return nil
        }
    }

    /// The air setting to point at in the plan for this part, if the tour is waiting for it.
    func airToHighlight(stage: MissionStage, phase: Int, configuration: ResourceConfiguration) -> Double? {
        guard step(for: stage) == .change, phase == shadowIndex, configuration != target else { return nil }
        return halfAir
    }

    func wantsLaunch(stage: MissionStage, configuration: ResourceConfiguration) -> Bool {
        stage == .planning && step(for: stage) == .change && configuration == target
    }

    // MARK: Moving through the tour

    /// The Next button. Every branch checks the stage, so repeated taps do nothing extra.
    func next(_ session: MissionSession) {
        guard !ended else { return }
        switch step(for: session.stage) {
        case .question:
            guard session.stage == .planning else { return }
            if session.configuration != start {
                session.restorePlan(configuration: start, rover: nil, isDraft: false)
            }
            session.goToPrediction()
        case .predict, .repredict:
            if session.stage == .playback { session.skipPlayback() }
        case .baseline:
            if session.stage == .playback {
                session.skipPlayback()
            } else if session.stage == .results {
                session.reviseExperiment()
            }
        case .change:
            break
        case .compare:
            showTakeaway = true
        case .takeaway:
            break
        }
    }

    func back(_ session: MissionSession) {
        guard !ended else { return }
        skipTask?.cancel()
        let stage = session.stage
        switch step(for: stage) {
        case .question:
            if stage == .playback { session.retry() }
        case .predict:
            session.backToPlanning()
        case .repredict:
            if stage == .playback { session.retry() } else { session.backToPlanning() }
        case .baseline:
            baseline = nil
            session.retry()
        case .change:
            baseline = nil
            session.restorePlan(configuration: start, rover: nil, isDraft: false)
        case .compare:
            revised = nil
            session.retry()
        case .takeaway:
            showTakeaway = false
        }
    }

    /// Called by the tour's own session when a test finishes. The numbers come from the engine result.
    func attemptFinished(_ session: MissionSession) {
        skipTask?.cancel()
        guard !ended, let record = session.currentBaseRecord else { return }
        var evidence = TourEvidence(record: record)
        if let result = session.resourceResult {
            if let sun = result.trace.first(where: { $0.phaseID == "sunlit" }) {
                evidence.storedKWh = sun.after.batteryKWh
            }
            if let shadow = result.trace.last(where: { $0.phaseID == "shadow" }) {
                evidence.neededKWh = max(0, shadow.demand.totalKW - shadow.generationKW) * shadow.plannedHours
            }
        }
        evidence.forecast = session.prediction?.outcome(in: session.definition)
        evidence.forecastRight = session.predictionWasRight
        if baseline == nil {
            baseline = evidence
        } else {
            revised = evidence
            showTakeaway = false
        }
    }

    /// Playback is presentation only. The tour shows a moment of it, then goes to the already computed result.
    func playbackStarted(_ session: MissionSession, reduceMotion: Bool) {
        skipTask?.cancel()
        guard !ended else { return }
        generation += 1
        let token = generation
        let delay: UInt64 = reduceMotion ? 500_000_000 : 2_200_000_000
        skipTask = Task { @MainActor [weak self, weak session] in
            try? await Task.sleep(nanoseconds: delay)
            guard let self, let session, !Task.isCancelled, !self.ended,
                  self.generation == token, session.stage == .playback else { return }
            session.skipPlayback()
        }
    }

    /// Stops anything the tour started. After this the tour never touches a session again.
    func cancel() {
        ended = true
        generation += 1
        skipTask?.cancel()
        skipTask = nil
    }

    // MARK: Comparison

    /// Every difference between the two tested plans, in words. One entry means a one-change experiment.
    var changes: [String] {
        guard let a = baseline?.record.resourceConfiguration, let b = revised?.record.resourceConfiguration else { return [] }
        return Self.differences(a, b, phaseLabels: phaseLabels)
    }

    static func differences(_ a: ResourceConfiguration, _ b: ResourceConfiguration, phaseLabels: [String]) -> [String] {
        var list: [String] = []
        for kind in CargoKind.allCases where a.count(kind) != b.count(kind) {
            list.append("\(CargoCopy.name(kind)): \(a.count(kind)) → \(b.count(kind))")
        }
        for index in 0..<min(a.plans.count, b.plans.count) {
            let before = a.plans[index], after = b.plans[index]
            let label = phaseLabels.indices.contains(index) ? phaseLabels[index] : "Part \(index + 1)"
            if before.airFraction != after.airFraction {
                list.append("\(label) air: \(MissionSession.airLabel(before.airFraction)) → \(MissionSession.airLabel(after.airFraction))")
            }
            if before.researchLevel != after.researchLevel {
                list.append("\(label) science: \(before.researchLevel > 0 ? "On" : "Off") → \(after.researchLevel > 0 ? "On" : "Off")")
            }
            if before.gardenFraction != after.gardenFraction {
                list.append("\(label) greenhouse light changed")
            }
        }
        return list
    }

    /// Electricity the changed plan saved compared with the first plan, and the stored oxygen it used.
    var electricitySavedKWh: Double? {
        guard let a = baseline?.record.energySavedKWh, let b = revised?.record.energySavedKWh else { return nil }
        return b - a
    }

    var oxygenUsedKg: Double? { revised?.record.oxygenSpentKg }
}
