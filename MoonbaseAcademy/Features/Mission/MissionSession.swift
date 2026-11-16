import Foundation
import Observation
import UIKit

/// Mutually exclusive stages of one drill.
enum MissionStage: Equatable {
    case briefing
    case planning
    case predicting
    case playback
    case results
}

enum TutorialStep: Equatable {
    case placeFirstArray
    case powered
    case done
}

enum RoverPlanChoice: Hashable {
    case earth
    case earthWithCamera
    case onboard
}

/// Cosmetic base improvements earned in the campaign. They change what the world shows, never drill numbers.
struct BaseDecor: Equatable {
    var arrays = 0
    var batteries = 0
    var greenhouse = false
    var shelter = false
    var dish = false

    init(progress: CampaignProgress) {
        arrays = progress.builtArrays
        batteries = progress.builtBatteries
        greenhouse = progress.isCompleted(.livingBase)
        shelter = progress.isCompleted(.stormDrill)
        dish = progress.isCompleted(.signalLag)
    }
}

/// Three independent achievements: mission completion, prediction accuracy and the successful bonus.
struct StarResult: Equatable {
    var finished: Bool
    var predicted: Bool
    var bonus: Bool

    var count: Int { [finished, predicted, bonus].filter { $0 }.count }

    var achievements: Set<Achievement> {
        var set = Set<Achievement>()
        if finished { set.insert(.completed) }
        if predicted { set.insert(.predicted) }
        if bonus { set.insert(.bonus) }
        return set
    }
}

/// Set when the session is a "Test My Base" run: the equipment snapshot taken from the board when the
/// test opened, and the last saved result to compare with.
struct BaseTestContext: Equatable {
    var inputs: BaseTestInputs
    var previous: BaseTestRecord?
    var isExample = false
    var kind: BaseTestKind = .shadow
    var eventID: String? = nil
}

struct AttemptSummary: Equatable {
    var success: Bool
    var headline: String
    var setup: String
    var numbers: [NumberRow]
    var prediction: Prediction? = nil
    var reason: PredictionReason? = nil
    var question: String? = nil
    var configuration: ResourceConfiguration? = nil
    var roverConfiguration: RoverConfiguration? = nil
    var elapsedHours: Double? = nil
    var inputs: BaseTestInputs? = nil
}

struct RevisionSuggestion {
    var text: String
    var phaseIndex: Int?
}

@MainActor
@Observable
final class MissionSession {
    let definition: MissionDefinition
    let science: ScienceInputs
    let copy: MissionCopy
    let gameCopy: GameCopy
    /// Non-nil for "Test My Base". The equipment is then fixed to the player's real base.
    let baseTest: BaseTestContext?
    private(set) var stage: MissionStage = .briefing
    private(set) var configuration: ResourceConfiguration
    private(set) var roverConfiguration: RoverConfiguration
    private(set) var prediction: Prediction?
    private(set) var predictionReason: PredictionReason?
    private(set) var pendingPrediction: Prediction?
    private(set) var pendingReason: PredictionReason?
    private(set) var revisionPhaseIndex: Int?
    private(set) var revisionInstruction: String?
    private(set) var resourceResult: ResourceMissionResult?
    private(set) var roverResult: RoverMissionResult?
    private(set) var explanation: Explanation?
    private(set) var playbackIndex = 0
    private(set) var previousAttempt: AttemptSummary?
    private(set) var currentAttempt: AttemptSummary?
    private(set) var failedAttempts = 0
    private(set) var firstCompletion = false
    private(set) var tutorial: TutorialStep
    private(set) var notice: String?
    private(set) var introIndex = 0
    private(set) var countdown: Int?
    /// Presentation-only playback state. The trace index lives in `playbackIndex`; the checkpoint
    /// cursor is separate, so grouping days never changes event timing or resource values.
    private(set) var playbackMode: PlaybackMode
    private(set) var checkpoints: [PlaybackCheckpoint] = []
    private(set) var checkpointIndex = 0
    private(set) var isPaused = false
    /// How fast a test plays: 1, 2 or 5 times. The player's choice; it never changes a result.
    private(set) var playbackSpeed: Double = 1
    private(set) var pausedByInterruption = false
    /// Bumped to replay the current explanation (restarts reading time and the highlight).
    private(set) var replayToken = 0
    /// True when this drill was reopened from a saved plan; shows a short reminder.
    var resumedFromDraft = false
    private(set) var stars: StarResult?
    private(set) var shakeToken = 0
    /// A placed building the player tapped on the Moon. The planning bar then offers to remove it.
    private(set) var selectedPad: PadID?
    var hintVisible = false
    private(set) var sameSettingsForAllBlocks = true

    @ObservationIgnored private let world: WorldCoordinator
    @ObservationIgnored private let decor: BaseDecor
    @ObservationIgnored private var reduceMotion: Bool
    @ObservationIgnored private var attemptToken = 0
    @ObservationIgnored private var playbackTask: Task<Void, Never>?
    @ObservationIgnored private let onRecord: (AttemptRecord, String?, Set<Achievement>) -> Bool
    @ObservationIgnored private let onModeChange: (PlaybackMode) -> Void
    @ObservationIgnored private var advanceRequested = false
    @ObservationIgnored private var restartDwell = false

    init(definition: MissionDefinition, science: ScienceInputs, world: WorldCoordinator, decor: BaseDecor,
         reduceMotion: Bool, firstVisit: Bool, playbackMode: PlaybackMode = .automatic,
         onModeChange: @escaping (PlaybackMode) -> Void = { _ in },
         baseTest: BaseTestContext? = nil,
         previousAttempt: AttemptSummary? = nil,
         onRecord: @escaping (AttemptRecord, String?, Set<Achievement>) -> Bool) {
        self.definition = definition
        self.science = science
        self.copy = MissionCopy.of(definition, science: science)
        self.gameCopy = GameCopy.of(definition, science: science)
        self.world = world
        self.decor = decor
        self.reduceMotion = reduceMotion
        self.onRecord = onRecord
        self.onModeChange = onModeChange
        self.playbackMode = playbackMode
        self.baseTest = baseTest
        self.currentAttempt = previousAttempt
        if previousAttempt == nil, let record = baseTest?.previous {
            self.currentAttempt = AttemptSummary(success: record.success, headline: record.headline,
                setup: record.inputs.summary, numbers: [], prediction: record.prediction,
                reason: record.predictionReason, question: record.predictionQuestion,
                configuration: record.resourceConfiguration, elapsedHours: record.elapsedHours, inputs: record.inputs)
        }
        if let baseTest {
            self.configuration = BaseExperiment.configuration(for: definition, inputs: baseTest.inputs)
        } else {
            self.configuration = MissionCatalog.defaultConfiguration(for: definition)
        }
        self.roverConfiguration = RoverConfiguration(mode: .earthControl,
                                                     observedMarkerM: definition.rover?.markerChoicesM.first)
        self.tutorial = (definition.missionID == .lightsOut && definition.variant == nil && firstVisit) ? .placeFirstArray : .done
        world.onPadTapped = { [weak self] pad in self?.padTapped(pad) }
        world.onFlagTapped = { [weak self] marker in self?.flagTapped(marker) }
        world.onMarkerTapped = nil
        refreshWorld()
    }

    // MARK: Derived state

    var isRover: Bool { definition.kind == .rover }
    var isVariant: Bool { definition.variant != nil }
    var isBaseTest: Bool { baseTest != nil }
    private(set) var currentBaseRecord: BaseTestRecord?
    private(set) var previousBaseRecord: BaseTestRecord?
    static let baseGearNotice = "This test uses your real base. To change it, build at your base, then test again."

    var cargoCost: Int {
        definition.catalog.reduce(0) { total, item in
            total + item.cost * (isRover ? roverConfiguration.count(item.kind) : configuration.count(item.kind))
        }
    }

    var issues: [ConfigurationIssue] {
        isRover
            ? RoverEngine.validateConfiguration(mission: definition, configuration: roverConfiguration)
            : validateConfiguration(mission: definition, configuration: configuration)
    }

    var canRun: Bool { issues.isEmpty }

    func count(_ kind: CargoKind) -> Int { configuration.count(kind) }

    func canAdd(_ kind: CargoKind) -> Bool {
        guard let item = definition.item(kind) else { return false }
        return count(kind) < item.maxCount && cargoCost + item.cost <= definition.cargoBudget
    }

    func plan(_ index: Int) -> PhasePlan {
        configuration.plans.indices.contains(index) ? configuration.plans[index] : PhasePlan()
    }

    /// Resources at the start of the drill for the current cargo choice.
    var startState: ResourceState {
        var capacity = definition.initial.baseBatteryCapacityKWh
        var energy = definition.initial.batteryKWh
        for item in definition.catalog {
            capacity += Double(count(item.kind)) * item.batteryCapacityKWh
            energy += Double(count(item.kind)) * item.batteryInitialKWh
        }
        return ResourceState(batteryKWh: min(energy, capacity), batteryCapacityKWh: capacity,
                             oxygenKg: definition.initial.oxygenKg, oxygenCapacityKg: definition.initial.oxygenCapacityKg,
                             foodDryKg: definition.initial.foodDryKg, cropGrowthDays: 0)
    }

    /// What the HUD shows: the live step during a test, otherwise the starting supplies.
    var displayState: ResourceState {
        if stage == .playback || stage == .results, let step = currentStep { return step.after }
        return startState
    }

    var currentStep: ResourceSnapshot? {
        guard let trace = resourceResult?.trace, !trace.isEmpty else { return nil }
        if stage == .results { return trace.last }
        return trace[min(playbackIndex, trace.count - 1)]
    }

    var roverPlan: RoverPlanChoice {
        if roverConfiguration.mode == .onboardComputer { return .onboard }
        return roverConfiguration.count(.scienceCamera) > 0 ? .earthWithCamera : .earth
    }

    var predictionWasRight: Bool? {
        guard let prediction, prediction != .unsure else { return nil }
        let truth: Bool
        if let r = roverResult {
            truth = r.success
        } else if let r = resourceResult {
            truth = r.success
        } else {
            return nil
        }
        return (prediction == .yes) == truth
    }

    // MARK: Intents

    func placeFirstArray() {
        guard tutorial == .placeFirstArray, stage == .planning else { return }
        configuration.setCount(.solarArray, max(1, count(.solarArray)))
        tutorial = .powered
        refreshWorld()
    }

    var isLastIntroLine: Bool { introIndex >= gameCopy.intro.count - 1 }

    func advanceIntro() {
        guard stage == .briefing else { return }
        if isLastIntroLine {
            beginPlanning()
        } else {
            introIndex += 1
        }
    }

    func beginPlanning() {
        guard stage == .briefing else { return }
        stage = .planning
        refreshWorld()
    }

    func dismissTutorial() {
        if tutorial == .powered { tutorial = .done }
    }

    /// Adds one item from the build tray. Returns false (and shakes) when the lander has no room.
    @discardableResult
    func addCargo(_ kind: CargoKind) -> Bool {
        guard stage == .planning else { return false }
        if tutorial == .placeFirstArray {
            guard kind == .solarArray else { return false }
            placeFirstArray()
            return true
        }
        if isBaseTest {
            notice = Self.baseGearNotice
            shakeToken += 1
            return false
        }
        guard canAdd(kind) else {
            let atMax = count(kind) >= (definition.item(kind)?.maxCount ?? 0)
            notice = atMax ? "That's all the \(CargoCopy.name(kind).lowercased()) pads we have." : "The lander is full! Remove something to make room."
            shakeToken += 1
            return false
        }
        setCount(kind, count(kind) + 1)
        if tutorial == .powered { tutorial = .done }
        return true
    }

    func removeCargo(_ kind: CargoKind) {
        guard stage == .planning, tutorial != .placeFirstArray else { return }
        setCount(kind, count(kind) - 1)
    }

    private func flagTapped(_ marker: Double) {
        guard stage == .planning, roverPlan != .onboard else { return }
        setMarker(marker)
        Haptics.tap()
    }

    var canLaunch: Bool { canRun && tutorial != .placeFirstArray }

    var unlockText: String? { firstCompletion ? gameCopy.unlock : nil }

    /// What Nova says right now.
    var novaLine: String {
        switch stage {
        case .briefing:
            return gameCopy.intro[min(introIndex, gameCopy.intro.count - 1)]
        case .planning:
            if tutorial == .placeFirstArray { return "Tap + on the solar array to build your first array!" }
            if tutorial == .powered {
                return "Power! The array lights the habitat while the Sun shines. Now a 6-hour shadow is coming, and the lander holds 4 crates. Plan for the dark!"
            }
            if let notice { return notice }
            if let issue = issues.first { return issue.childMessage }
            if let revisionInstruction { return revisionInstruction }
            if hintVisible { return copy.hint }
            return gameCopy.planTip
        case .predicting:
            return copy.question
        case .playback:
            if countdown != nil { return "Test starting. Watch closely!" }
            if let checkpoint = currentCheckpoint { return checkpoint.text }
            if isRover { return "The picture flies to Earth, then STOP flies back. The rover keeps rolling..." }
            guard let step = currentStep else { return "" }
            return GameCopy.commentary(step, mission: definition.missionID)
        case .results:
            return explanation?.paragraphs.first ?? ""
        }
    }

    func setCount(_ kind: CargoKind, _ value: Int) {
        guard stage == .planning, let item = definition.item(kind) else { return }
        if isBaseTest {
            notice = Self.baseGearNotice
            return
        }
        let target = max(0, min(item.maxCount, value))
        let extra = (target - count(kind)) * item.cost
        if extra > 0 && cargoCost + extra > definition.cargoBudget {
            notice = "Not enough cargo points. Remove something first."
            return
        }
        notice = nil
        configuration.setCount(kind, target)
        if kind == .scienceKit && target == 0 {
            for index in configuration.plans.indices { configuration.plans[index].researchLevel = 0 }
        }
        refreshWorld()
    }

    private func changePlans(_ index: Int, _ change: (inout PhasePlan) -> Void) {
        guard stage == .planning, configuration.plans.indices.contains(index) else { return }
        let all = definition.missionID == .livingBase && sameSettingsForAllBlocks
        for target in all ? Array(configuration.plans.indices) : [index] {
            change(&configuration.plans[target])
        }
        refreshWorld()
    }

    func setSameSettingsForAllBlocks(_ same: Bool) {
        guard stage == .planning else { return }
        sameSettingsForAllBlocks = same
        if same, let first = configuration.plans.first {
            for index in configuration.plans.indices { configuration.plans[index] = first }
        }
        refreshWorld()
    }

    func setAir(_ index: Int, _ value: Double) { changePlans(index) { $0.airFraction = value } }
    func setGarden(_ index: Int, _ value: Double) { changePlans(index) { $0.gardenFraction = value } }

    func setResearch(_ index: Int, _ value: Double) {
        if value > 0, let needed = definition.phases[index].research?.requiredItem, count(needed) == 0 {
            notice = "Research needs the \(CargoCopy.name(needed).lowercased()) on board."
            return
        }
        notice = nil
        changePlans(index) { $0.researchLevel = value }
    }

    func setRoverPlan(_ choice: RoverPlanChoice) {
        guard stage == .planning else { return }
        let marker = roverConfiguration.observedMarkerM ?? definition.rover?.markerChoicesM.first
        switch choice {
        case .earth:
            roverConfiguration = RoverConfiguration(mode: .earthControl, observedMarkerM: marker)
        case .earthWithCamera:
            roverConfiguration = RoverConfiguration(mode: .earthControl, observedMarkerM: marker, cargo: [.scienceCamera: 1])
        case .onboard:
            roverConfiguration = RoverConfiguration(mode: .onboardComputer, observedMarkerM: marker, cargo: [.onboardComputer: 1])
        }
        refreshWorld()
    }

    func setMarker(_ marker: Double) {
        guard stage == .planning else { return }
        roverConfiguration.observedMarkerM = marker
        refreshWorld()
    }

    func padTapped(_ pad: PadID) {
        if tutorial == .placeFirstArray {
            if case .array = pad { placeFirstArray() }
            return
        }
        guard stage == .planning, definition.missionID == .lightsOut else { return }
        if tutorial == .powered { tutorial = .done }
        let (kind, index): (CargoKind, Int) = {
            switch pad {
            case .array(let index): return (.solarArray, index)
            case .battery(let index): return (.battery, index)
            }
        }()
        if index < count(kind) {
            // Like a building game: tapping something already built selects it instead of deleting it.
            selectedPad = selectedPad == pad ? nil : pad
        } else {
            selectedPad = nil
            addCargo(kind)
        }
    }

    /// The equipment type of the selected building, while it still exists.
    var selectedKind: CargoKind? {
        guard let selectedPad else { return nil }
        switch selectedPad {
        case .array(let index): return index < count(.solarArray) ? .solarArray : nil
        case .battery(let index): return index < count(.battery) ? .battery : nil
        }
    }

    func removeSelected() {
        guard let kind = selectedKind else { selectedPad = nil; return }
        selectedPad = nil
        removeCargo(kind)
    }

    func clearSelection() { selectedPad = nil }

    func goToPrediction() {
        guard stage == .planning, canLaunch else { return }
        notice = nil
        selectedPad = nil
        prediction = nil
        predictionReason = nil
        pendingPrediction = nil
        pendingReason = nil
        revisionPhaseIndex = nil
        revisionInstruction = nil
        stage = .predicting
    }

    func choosePrediction(_ choice: Prediction) {
        guard stage == .predicting else { return }
        pendingPrediction = choice
        if choice == .unsure { pendingReason = .unsure }
        else if pendingReason == .unsure { pendingReason = nil }
    }

    func chooseReason(_ reason: PredictionReason) {
        guard stage == .predicting, pendingPrediction != nil else { return }
        pendingReason = reason
    }

    func backToPlanning() {
        guard stage == .predicting else { return }
        stage = .planning
    }

    func run(predicting choice: Prediction, reason: PredictionReason? = nil) {
        guard stage == .predicting, canRun else { return }
        prediction = choice
        predictionReason = reason
        attemptToken += 1
        let token = attemptToken
        if isRover {
            let result = simulateRoverMission(definition: definition, configuration: roverConfiguration, science: science)
            guard result.wasSimulated else { stage = .planning; return }
            roverResult = result
            resourceResult = nil
            explanation = ExplanationWriter.rover(result, definition: definition)
        } else {
            let result = simulateResourceMission(definition: definition, configuration: configuration, science: science)
            guard result.wasSimulated else { stage = .planning; return }
            resourceResult = result
            roverResult = nil
            explanation = ExplanationWriter.resource(result, definition: definition, science: science)
        }
        playbackIndex = 0
        checkpointIndex = 0
        isPaused = false
        pausedByInterruption = false
        advanceRequested = false
        if let r = resourceResult {
            checkpoints = PlaybackScript.checkpoints(for: r, definition: definition, science: science)
        } else if let r = roverResult {
            checkpoints = PlaybackScript.roverCheckpoints(r)
        }
        stars = nil
        stage = .playback
        world.setSpeed(CGFloat(playbackSpeed))
        countdown = reduceMotion ? nil : 3
        refreshWorld()
        startPlayback(token: token)
    }

    var currentCheckpoint: PlaybackCheckpoint? {
        guard stage == .playback, countdown == nil, checkpoints.indices.contains(checkpointIndex) else { return nil }
        return checkpoints[checkpointIndex]
    }

    var isLastCheckpoint: Bool { checkpointIndex >= checkpoints.count - 1 }

    /// The player's reading time at a checkpoint. Motion settings never shorten it.
    private func dwellSeconds(_ checkpoint: PlaybackCheckpoint) -> Double {
        var seconds = checkpoint.readingSeconds
        if let r = roverResult, !reduceMotion {
            seconds = max(seconds, r.stopAtSecond + 1.2)
        }
        return seconds / playbackSpeed
    }

    /// Speeds the playback up (2x, 5x) or back to normal. Presentation only: the result was already computed.
    func setPlaybackSpeed(_ speed: Double) {
        playbackSpeed = max(1, min(5, speed))
        if stage == .playback { world.setSpeed(CGFloat(playbackSpeed)) }
    }

    private func startPlayback(token: Int) {
        playbackTask?.cancel()
        let countdownSteps = reduceMotion ? [] : [3, 2, 1, 0]
        playbackTask = Task { @MainActor [weak self] in
            for number in countdownSteps {
                guard let self, self.attemptToken == token, !Task.isCancelled else { return }
                await self.waitWhilePaused(token: token)
                self.countdown = number
                try? await Task.sleep(nanoseconds: number == 0 ? 450_000_000 : 420_000_000)
            }
            guard let self, self.attemptToken == token, !Task.isCancelled else { return }
            self.countdown = nil
            for index in self.checkpoints.indices {
                guard self.attemptToken == token, !Task.isCancelled else { return }
                await self.present(index, token: token)
                guard self.attemptToken == token, !Task.isCancelled else { return }
                await self.waitForAdvance(token: token)
            }
            guard self.attemptToken == token, !Task.isCancelled else { return }
            self.finishAttempt(token: token)
        }
    }

    /// Moves the world to a checkpoint. Between checkpoints the days run by quickly as motion only;
    /// with reduced motion the world jumps straight there.
    private func present(_ index: Int, token: Int) async {
        let target = checkpoints[index].traceIndex
        advanceRequested = false
        if !reduceMotion && !isRover {
            var step = index == 0 ? 0 : checkpoints[index - 1].traceIndex + 1
            while step < target {
                guard attemptToken == token, !Task.isCancelled, !advanceRequested else { break }
                await waitWhilePaused(token: token)
                playbackIndex = step
                refreshWorld()
                try? await Task.sleep(nanoseconds: UInt64(110_000_000 / playbackSpeed))
                step += 1
            }
        }
        guard attemptToken == token, !Task.isCancelled else { return }
        advanceRequested = false
        checkpointIndex = index
        playbackIndex = target
        refreshWorld()
        announce(checkpoints[index])
    }

    /// Automatic: wait the reading time (pausing stops the clock). Step by step: wait for Next.
    private func waitForAdvance(token: Int) async {
        var elapsed = 0.0
        while attemptToken == token && !Task.isCancelled {
            if advanceRequested {
                advanceRequested = false
                return
            }
            if restartDwell {
                restartDwell = false
                elapsed = 0
            }
            if playbackMode == .automatic && !isPaused {
                if elapsed >= dwellSeconds(checkpoints[checkpointIndex]) { return }
                elapsed += 0.1
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func waitWhilePaused(token: Int) async {
        while isPaused && attemptToken == token && !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func announce(_ checkpoint: PlaybackCheckpoint) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: "\(checkpoint.title). \(checkpoint.text)")
    }

    // MARK: Playback controls

    /// The motion setting can change while a drill is open (system or in-app switch). Animation only.
    func setReduceMotion(_ on: Bool) {
        guard on != reduceMotion else { return }
        reduceMotion = on
        refreshWorld()
    }

    /// Reopens a saved plan after the app was closed. Starts at planning; nothing is simulated or recorded.
    func restorePlan(configuration saved: ResourceConfiguration?, rover: RoverConfiguration?, isDraft: Bool = true) {
        if isRover, let rover, RoverEngine.validateConfiguration(mission: definition, configuration: rover).isEmpty {
            roverConfiguration = rover
        } else if !isRover, let saved, validateConfiguration(mission: definition, configuration: saved).isEmpty {
            configuration = saved
            if let first = saved.plans.first {
                sameSettingsForAllBlocks = saved.plans.allSatisfy { $0 == first }
            }
        } else {
            return
        }
        tutorial = .done
        stage = .planning
        resumedFromDraft = isDraft
        refreshWorld()
    }

    func setPlaybackMode(_ mode: PlaybackMode) {
        guard mode != playbackMode else { return }
        playbackMode = mode
        restartDwell = true
        onModeChange(mode)
    }

    func pausePlayback() {
        guard stage == .playback, !isPaused else { return }
        isPaused = true
    }

    func resumePlayback() {
        guard stage == .playback, isPaused else { return }
        isPaused = false
        pausedByInterruption = false
        restartDwell = true
    }

    /// Next checkpoint (or the result after the last one). Also skips the quick run-up of days.
    func nextCheckpoint() {
        guard stage == .playback, countdown == nil else { return }
        if isPaused {
            isPaused = false
            pausedByInterruption = false
        }
        advanceRequested = true
    }

    func replayCheckpoint() {
        guard let checkpoint = currentCheckpoint else { return }
        restartDwell = true
        replayToken += 1
        refreshWorld()
        announce(checkpoint)
    }

    /// The app lost or regained active status. Losing it pauses presentation; the player resumes.
    func setAppActive(_ active: Bool) {
        guard stage == .playback else { return }
        if !active && !isPaused {
            isPaused = true
            pausedByInterruption = true
        }
    }

    /// Animation is presentation only. Skipping keeps the already computed result.
    func skipPlayback() {
        guard stage == .playback else { return }
        playbackTask?.cancel()
        countdown = nil
        isPaused = false
        pausedByInterruption = false
        finishAttempt(token: attemptToken)
    }

    private func finishAttempt(token: Int) {
        guard token == attemptToken, stage == .playback else { return }
        stage = .results
        world.setSpeed(1)
        let success = resourceResult?.success ?? roverResult?.success ?? false
        if let context = baseTest, let result = resourceResult {
            previousBaseRecord = currentBaseRecord ?? context.previous
            currentBaseRecord = BaseExperiment.record(inputs: context.inputs, result: result,
                                                      definition: definition, headline: explanation?.headline ?? "", eventID: context.eventID)
            currentBaseRecord?.prediction = prediction
            currentBaseRecord?.predictionReason = predictionReason
            currentBaseRecord?.predictionQuestion = copy.question
            currentBaseRecord?.resourceConfiguration = configuration
        }
        let summary = AttemptSummary(success: success, headline: explanation?.headline ?? "",
                                     setup: setupDescription, numbers: explanation?.numbers ?? [],
                                     prediction: prediction, reason: predictionReason, question: copy.question,
                                     configuration: isRover ? nil : configuration,
                                     roverConfiguration: isRover ? roverConfiguration : nil,
                                     elapsedHours: resourceResult?.trace.last?.endHour, inputs: baseTest?.inputs)
        previousAttempt = currentAttempt
        currentAttempt = summary
        if !success {
            failedAttempts += 1
            hintVisible = true
        }
        // Each star is its own achievement: a correct prediction counts even when the drill fails.
        let result = StarResult(finished: success,
                                predicted: predictionWasRight == true,
                                bonus: success && earnedBadge != nil)
        stars = result
        firstCompletion = onRecord(makeRecord(success: success), earnedBadge, result.achievements)
        refreshWorld()
    }

    func retry() {
        playbackTask?.cancel()
        attemptToken += 1
        countdown = nil
        checkpoints = []
        checkpointIndex = 0
        isPaused = false
        pausedByInterruption = false
        stars = nil
        notice = nil
        revisionPhaseIndex = nil
        revisionInstruction = nil
        stage = .planning
        world.setSpeed(1)
        resourceResult = nil
        roverResult = nil
        explanation = nil
        prediction = nil
        predictionReason = nil
        playbackIndex = 0
        refreshWorld()
    }

    /// Keeps the prior hypothesis while returning to the relevant part of the same scenario.
    func reviseExperiment() {
        let suggestion = revisionSuggestion
        retry()
        revisionPhaseIndex = suggestion.phaseIndex
        revisionInstruction = suggestion.text
    }

    var revisionSuggestion: RevisionSuggestion {
        if let r = resourceResult {
            if r.failedConstraints.contains(.researchGoalNotReached) {
                return RevisionSuggestion(text: "Try science On during the first storm part. Watch what it costs in power, then test your idea.", phaseIndex: 0)
            }
            if r.failure?.constraint == .oxygenExhausted || r.failedConstraints.contains(.airReserveBelowMinimum) {
                let index = configuration.plans.firstIndex { $0.airFraction < 1 } ?? 0
                return RevisionSuggestion(text: "Try a higher air-maker setting in one part. Check the extra power it needs.", phaseIndex: index)
            }
            if r.failure?.constraint == .energyShortage {
                let index = definition.phases.firstIndex { $0.id == r.failure?.phaseID } ?? 0
                return RevisionSuggestion(text: "Try changing one power choice in this part. Lower air-maker power uses more oxygen from the tank; extra sunlight generation can help before shadow.", phaseIndex: index)
            }
            if r.failedConstraints.contains(.harvestNotReached) {
                return RevisionSuggestion(text: "Try more greenhouse light in one part. Compare growth with the energy left for the crew.", phaseIndex: configuration.plans.firstIndex { $0.gardenFraction < 1 } ?? 0)
            }
            if r.failure?.constraint == .shelterMissing {
                return RevisionSuggestion(text: "Rebalance the cargo to include a shelter within the crate limit. The crew must stay protected.", phaseIndex: nil)
            }
        }
        return RevisionSuggestion(text: isRover ? "Try a different STOP marker and predict where the rover will stop." : "Change one equipment or operating choice, then predict whether the mission will still work.", phaseIndex: isRover ? nil : 0)
    }

    var learningRecord: BaseTestRecord? {
        if let currentBaseRecord { return currentBaseRecord }
        guard let result = resourceResult else { return nil }
        let gear = BaseTestInputs(arrays: configuration.count(.solarArray), batteries: configuration.count(.battery))
        return BaseExperiment.record(inputs: gear, result: result, definition: definition, headline: explanation?.headline ?? "")
    }

    /// A concrete difference list. It never claims a controlled experiment when several settings changed.
    var investigationChanges: [String]? {
        guard let old = previousAttempt, let now = currentAttempt else { return nil }
        if let before = old.configuration, let after = now.configuration {
            var changes: [String] = []
            for kind in CargoKind.allCases where before.count(kind) != after.count(kind) {
                changes.append("\(CargoCopy.name(kind)): \(before.count(kind)) → \(after.count(kind))")
            }
            for index in 0..<min(before.plans.count, after.plans.count) {
                let a = before.plans[index], b = after.plans[index]
                let label = definition.phases.indices.contains(index) ? definition.phases[index].label : "Part \(index + 1)"
                if a.airFraction != b.airFraction { changes.append("\(label) air: \(Self.airLabel(a.airFraction)) → \(Self.airLabel(b.airFraction))") }
                if a.researchLevel != b.researchLevel { changes.append("\(label) science: \(a.researchLevel > 0 ? "On" : "Off") → \(b.researchLevel > 0 ? "On" : "Off")") }
                if a.gardenFraction != b.gardenFraction { changes.append("\(label) greenhouse light changed") }
            }
            return changes
        }
        if let before = old.roverConfiguration, let after = now.roverConfiguration {
            return before == after ? [] : ["The rover's control, marker or cargo changed"]
        }
        return nil
    }

    func leave() {
        playbackTask?.cancel()
        attemptToken += 1
        world.setSpeed(1)
        world.onPadTapped = nil
        world.onFlagTapped = nil
    }

    private var earnedBadge: String? {
        guard let badge = copy.badge else { return nil }
        if let r = resourceResult, r.success {
            if r.observationBadge || r.researchUnits > 1e-9 { return badge }
        }
        if let r = roverResult, r.observationEarned { return badge }
        return nil
    }

    private func makeRecord(success: Bool) -> AttemptRecord {
        AttemptRecord(missionID: definition.missionID, definitionID: definition.id, date: Date(), success: success,
                      headline: explanation?.headline ?? "",
                      finalBatteryKWh: resourceResult?.finalState.batteryKWh,
                      finalAirHours: resourceResult?.finalAirHours,
                      finalStopM: roverResult?.finalStopM,
                      researchUnits: resourceResult?.researchUnits ?? (roverResult?.observationEarned == true ? 1 : 0),
                      resourceConfiguration: isRover ? nil : configuration,
                      roverConfiguration: isRover ? roverConfiguration : nil,
                      prediction: prediction, predictionReason: predictionReason,
                      predictionQuestion: copy.question)
    }

    // MARK: Descriptions

    static func airLabel(_ value: Double) -> String {
        value < 0.25 ? "Off" : (value < 0.75 ? "Half" : "Full")
    }

    var setupDescription: String {
        switch definition.missionID {
        case .lightsOut:
            let observation = plan(0).researchLevel > 0 ? ", observation on" : ""
            return "\(count(.solarArray)) arrays, \(count(.battery)) batteries · air \(Self.airLabel(plan(0).airFraction)) then \(Self.airLabel(plan(1).airFraction))\(observation)"
        case .livingBase:
            let parts = configuration.plans.map { p in
                "air \(Self.airLabel(p.airFraction)), light \(Int(p.gardenFraction * 16)) h, research \(Int(p.researchLevel))"
            }
            return Set(parts).count == 1 ? parts[0] : parts.joined(separator: " / ")
        case .stormDrill:
            let items = definition.catalog.filter { count($0.kind) > 0 }.map { CargoCopy.name($0.kind) }
            let cargo = items.isEmpty ? "No cargo" : items.joined(separator: " + ")
            return "\(cargo) · air \(Self.airLabel(plan(0).airFraction)) then \(Self.airLabel(plan(1).airFraction)); science \(plan(0).researchLevel > 0 ? "On" : "Off") then \(plan(1).researchLevel > 0 ? "On" : "Off")"
        case .signalLag:
            switch roverPlan {
            case .onboard: return "Onboard computer"
            case .earth, .earthWithCamera:
                let camera = roverPlan == .earthWithCamera ? " + camera" : ""
                return "Earth control at \(Format.meters(roverConfiguration.observedMarkerM ?? 0))\(camera)"
            }
        }
    }

    var worldSummary: String {
        let w = worldSnapshot()
        var parts = ["Moon base with a habitat"]
        if w.arrays > 0 { parts.append("\(w.arrays) solar arrays") }
        if w.batteries > 0 { parts.append("\(w.batteries) batteries at \(Int((w.batteryFraction * 100).rounded())) percent") }
        if w.greenhouse { parts.append("a greenhouse") }
        if w.shelter { parts.append(w.shelterOccupied ? "a shelter with the crew inside" : "a shelter") }
        if w.mood == .shadow { parts.append("in shadow") }
        if w.habitatWarning { parts.append("warning light on") }
        return parts.joined(separator: ", ")
    }

    // MARK: World

    func refreshWorld() {
        world.show(worldSnapshot(), reduceMotion: reduceMotion)
    }

    private func signed(_ value: Double, digits: Int = 1) -> String {
        (value >= 0 ? "+" : "−") + Format.number(abs(value), digits: digits)
    }

    /// Floating numbers for one playback step. Consolidated so the garden drill does not flood the screen.
    private func floaters(for step: ResourceSnapshot, world w: WorldSnapshot) -> [Floater] {
        let base = (attemptToken * 1000 + playbackIndex) * 4
        var result: [Floater] = []
        if definition.missionID == .livingBase {
            let phaseSteps = resourceResult?.trace.filter { $0.phaseIndex == step.phaseIndex } ?? []
            guard step.id == phaseSteps.last?.id, step.phaseIndex >= 0 else { return [] }
            let days = plan(step.phaseIndex).gardenFraction * definition.phases[step.phaseIndex].durationHours / 24
            if days > 0 {
                result.append(Floater(id: base, text: "+\(Format.number(days)) days of growth", color: 0x9FE7A4, anchor: .greenhouse))
            }
            return result
        }
        let solar = step.generationKW * step.elapsedHours
        if step.mood == .sunlit && w.arrays > 0 && solar > 0.05 {
            result.append(Floater(id: base, text: "+\(Format.number(solar)) kWh", color: 0xFFD66B, anchor: .arrays))
        }
        let energy = step.after.batteryKWh - step.before.batteryKWh
        if abs(energy) > 0.05 && w.batteries > 0 {
            result.append(Floater(id: base + 1, text: "\(signed(energy)) kWh", color: energy > 0 ? 0x74DFEC : 0xF7A68C, anchor: .batteries))
        }
        let oxygen = step.after.oxygenKg - step.before.oxygenKg
        if abs(oxygen) > 0.01 {
            result.append(Floater(id: base + 2, text: "\(signed(oxygen, digits: 2)) kg air", color: oxygen > 0 ? 0x9FE7A4 : 0xF7A68C, anchor: .habitat))
        }
        if step.curtailedKWh > 0.05 {
            result.append(Floater(id: base + 3, text: "\(Format.number(step.curtailedKWh)) kWh wasted", color: 0xC9D1DA, anchor: .arrays))
        }
        return result
    }

    /// While Nova briefs the drill, the scene changes with each line. Presentation only.
    private func applyBriefingBeat(_ w: inout WorldSnapshot) {
        guard stage == .briefing else { return }
        // "Test My Base" has no lander story: the briefing shows the player's own equipment. On the line
        // about the coming shadow, the base goes dark with its lights still on, then the Sun returns.
        guard !isBaseTest else {
            if introIndex == 1 {
                w.mood = .shadow
                w.habitatLit = true
            }
            return
        }
        let beats = SceneBeat.briefing(for: definition.missionID)
        let beat = beats[min(introIndex, beats.count - 1)]
        w.beat = beat
        switch beat {
        case .darkBase:
            w.arrays = 0
            w.batteries = 0
            w.habitatLit = false
            w.mood = .steady
        case .sunset:
            w.arrays = 2
            w.batteries = 0
            w.habitatLit = true
            w.mood = .sunlit
        case .construction:
            w.arrays = 0
            w.batteries = 0
            w.habitatLit = false
            w.padsVisible = true
            w.highlightedPads = [.array(0), .array(1), .battery(0), .battery(1)]
        case .greenhouseGrow:
            w.greenhouse = true
            w.gardenLights = true
            w.cropFraction = 0
        case .energyToGarden, .airFlow:
            w.greenhouse = true
            w.gardenLights = true
            w.cropFraction = 0.6
            w.habitatLit = true
        case .storm:
            w.mood = .storm
            w.stormParticles = true
        case .shelterUp:
            w.mood = .storm
            w.stormParticles = true
            w.shelter = true
            w.shelterOccupied = true
        case .cargoDrop:
            w.mood = .steady
        case .roverDrive, .signal, .bay, .none:
            break
        }
    }

    func worldSnapshot() -> WorldSnapshot {
        var w = WorldSnapshot()
        w.dish = decor.dish
        w.greenhouse = decor.greenhouse || definition.missionID == .livingBase
        w.shelter = decor.shelter || (definition.missionID == .stormDrill && count(.shelterKit) > 0)
        switch definition.missionID {
        case .lightsOut:
            w.arrays = count(.solarArray)
            w.batteries = count(.battery)
            w.padsVisible = stage == .planning && !isBaseTest
            if tutorial == .placeFirstArray {
                w.highlightedPads = [.array(0)]
            } else if stage == .planning {
                var pads: Set<PadID> = []
                if canAdd(.solarArray) { pads.insert(.array(count(.solarArray))) }
                if canAdd(.battery) { pads.insert(.battery(count(.battery))) }
                w.highlightedPads = pads
            }
        case .livingBase, .stormDrill:
            w.arrays = max(2, decor.arrays)
            w.batteries = 2 + count(.chargedBattery)
        case .signalLag:
            w.arrays = max(2, decor.arrays)
            w.batteries = max(1, decor.batteries)
        }
        w.cropFraction = decor.greenhouse && definition.missionID != .livingBase ? 1 : 0
        w.gardenLights = decor.greenhouse && definition.missionID != .livingBase

        if let rover = definition.rover {
            w.habitatLit = true
            w.mood = .sunlit
            w.batteryFraction = 0.8
            let marker = roverConfiguration.mode == .earthControl ? roverConfiguration.observedMarkerM : nil
            w.roverTrack = RoverTrackVisual(markers: rover.markerChoicesM, selectedMarker: marker,
                                            bayStartM: rover.targetBayStartM, bayEndM: rover.targetBayEndM, lengthM: rover.trackLengthM)
            if let r = roverResult {
                if stage == .playback {
                    w.roverRun = RoverRun(id: attemptToken, stopM: r.finalStopM, speed: rover.speedMPerSecond,
                                          imageAtSecond: r.configuration.mode == .earthControl ? r.imageTakenAtSecond : nil,
                                          oneWaySeconds: r.oneWayDelaySeconds, stopAtSecond: r.stopAtSecond)
                } else {
                    w.roverPositionM = r.finalStopM
                }
                w.habitatWarning = stage == .results && !r.success
            }
            applyBriefingBeat(&w)
            return w
        }

        let initialCapacity = resourceResult?.initialState.batteryCapacityKWh ?? (definition.initial.baseBatteryCapacityKWh
            + definition.catalog.reduce(0) { $0 + Double(count($1.kind)) * $1.batteryCapacityKWh })
        if let step = currentStep, stage == .playback || stage == .results {
            w.mood = step.mood
            let capacity = step.after.batteryCapacityKWh
            w.batteryFraction = capacity > 0 ? step.after.batteryKWh / capacity : 0
            let energyFailed = step.failure?.constraint == .energyShortage
            w.habitatLit = !energyFailed
            w.habitatWarning = step.failure != nil || (stage == .results && resourceResult?.success == false)
            if w.greenhouse && definition.missionID == .livingBase {
                w.cropFraction = step.after.cropGrowthDays / science.cropReferenceDays
                w.gardenLights = step.phaseIndex >= 0 && plan(step.phaseIndex).gardenFraction > 0 && !energyFailed
            }
            w.shelterOccupied = step.sheltered
            w.stormParticles = step.mood == .storm && stage == .playback
            if stage == .playback && countdown == nil {
                w.floaters = floaters(for: step, world: w)
                if let checkpoint = currentCheckpoint, checkpoint.traceIndex == playbackIndex {
                    w.highlight = WorldSnapshot.highlightTarget(for: checkpoint.focus)
                    w.highlightToken = replayToken
                }
            }
            if stage == .playback {
                if step.mood == .sunlit && w.arrays > 0 && step.generationKW > step.demand.totalKW + 1e-9 {
                    w.flow = .solarToBase
                } else if step.after.batteryKWh < step.before.batteryKWh - 1e-9 && w.batteries > 0 && step.phaseID != "assembly" {
                    w.flow = .batteryToBase
                }
            }
        } else {
            switch definition.missionID {
            case .lightsOut:
                w.mood = .sunlit
                w.habitatLit = count(.solarArray) > 0
                w.batteryFraction = 0
                if tutorial == .powered { w.flow = .solarToBase }
            default:
                w.mood = .steady
                w.habitatLit = true
                w.batteryFraction = initialCapacity > 0 ? min(1, (definition.initial.batteryKWh
                    + definition.catalog.reduce(0) { $0 + Double(count($1.kind)) * $1.batteryInitialKWh }) / initialCapacity) : 0
                if definition.missionID == .livingBase {
                    w.cropFraction = 0
                    w.gardenLights = plan(0).gardenFraction > 0
                }
            }
        }
        applyBriefingBeat(&w)
        return w
    }
}
