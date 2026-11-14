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

/// Up to three stars per attempt. Stars are only earned on a successful drill, and only the best result is kept.
struct StarResult: Equatable {
    var finished: Bool
    var predicted: Bool
    var bonus: Bool

    var count: Int { [finished, predicted, bonus].filter { $0 }.count }
}

struct AttemptSummary: Equatable {
    var success: Bool
    var headline: String
    var setup: String
    var numbers: [NumberRow]
}

@MainActor
@Observable
final class MissionSession {
    let definition: MissionDefinition
    let science: ScienceInputs
    let copy: MissionCopy
    let gameCopy: GameCopy
    private(set) var stage: MissionStage = .briefing
    private(set) var configuration: ResourceConfiguration
    private(set) var roverConfiguration: RoverConfiguration
    private(set) var prediction: Prediction?
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
    private(set) var stars: StarResult?
    private(set) var shakeToken = 0
    var hintVisible = false
    private(set) var sameSettingsForAllBlocks = true

    @ObservationIgnored private let world: WorldCoordinator
    @ObservationIgnored private let decor: BaseDecor
    @ObservationIgnored private let reduceMotion: Bool
    @ObservationIgnored private var attemptToken = 0
    @ObservationIgnored private var playbackTask: Task<Void, Never>?
    @ObservationIgnored private let onRecord: (AttemptRecord, String?, Int) -> Bool

    init(definition: MissionDefinition, science: ScienceInputs, world: WorldCoordinator, decor: BaseDecor,
         reduceMotion: Bool, firstVisit: Bool, onRecord: @escaping (AttemptRecord, String?, Int) -> Bool) {
        self.definition = definition
        self.science = science
        self.copy = MissionCopy.of(definition.missionID)
        self.gameCopy = GameCopy.of(definition.missionID)
        self.world = world
        self.decor = decor
        self.reduceMotion = reduceMotion
        self.onRecord = onRecord
        self.configuration = MissionCatalog.defaultConfiguration(for: definition)
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
            switch definition.missionID {
            case .lightsOut: truth = r.failure?.constraint != .energyShortage
            case .livingBase: truth = r.harvestAchieved
            case .stormDrill: truth = r.failure == nil && r.finalAirHours >= definition.success.minimumAirHours - 1e-9
            case .signalLag: truth = r.success
            }
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
            if tutorial == .placeFirstArray { return "Tap the Solar array card below to build your first array!" }
            if tutorial == .powered {
                return "Power! The array lights the habitat while the Sun shines. Now a 6-hour shadow is coming, and the lander holds 4 crates. Plan for the dark!"
            }
            if let notice { return notice }
            if let issue = issues.first { return issue.childMessage }
            if hintVisible { return copy.hint }
            return gameCopy.planTip
        case .predicting:
            return copy.question
        case .playback:
            if countdown != nil { return "Test starting. Watch closely!" }
            if isRover { return "The picture flies to Earth, then STOP flies back. The rover keeps rolling..." }
            guard let step = currentStep else { return "" }
            return GameCopy.commentary(step, mission: definition.missionID)
        case .results:
            return explanation?.paragraphs.first ?? ""
        }
    }

    func setCount(_ kind: CargoKind, _ value: Int) {
        guard stage == .planning, let item = definition.item(kind) else { return }
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
        switch pad {
        case .array(let index):
            setCount(.solarArray, index < count(.solarArray) ? count(.solarArray) - 1 : count(.solarArray) + 1)
        case .battery(let index):
            setCount(.battery, index < count(.battery) ? count(.battery) - 1 : count(.battery) + 1)
        }
    }

    func goToPrediction() {
        guard stage == .planning, canLaunch else { return }
        notice = nil
        prediction = nil
        stage = .predicting
    }

    func backToPlanning() {
        guard stage == .predicting else { return }
        stage = .planning
    }

    func run(predicting choice: Prediction) {
        guard stage == .predicting, canRun else { return }
        prediction = choice
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
        stars = nil
        stage = .playback
        countdown = reduceMotion ? nil : 3
        refreshWorld()
        startPlayback(token: token)
    }

    private func playbackDurations() -> [Double] {
        if let r = roverResult {
            return [reduceMotion ? 0.8 : r.stopAtSecond + 0.9]
        }
        guard let trace = resourceResult?.trace else { return [] }
        return trace.map { step in
            if step.phaseID == "assembly" { return reduceMotion ? 0.5 : 1.1 }
            if step.plannedHours <= 24 + 1e-9 && definition.missionID == .livingBase { return reduceMotion ? 0.1 : 0.26 }
            return reduceMotion ? 0.7 : 1.7
        }
    }

    private func startPlayback(token: Int) {
        playbackTask?.cancel()
        let durations = playbackDurations()
        let countdownSteps = reduceMotion ? [] : [3, 2, 1, 0]
        playbackTask = Task { @MainActor [weak self] in
            for number in countdownSteps {
                guard let self, self.attemptToken == token, !Task.isCancelled else { return }
                self.countdown = number
                try? await Task.sleep(nanoseconds: number == 0 ? 450_000_000 : 420_000_000)
            }
            if let self, self.attemptToken == token { self.countdown = nil }
            for (index, duration) in durations.enumerated() {
                guard let self, self.attemptToken == token, !Task.isCancelled else { return }
                self.playbackIndex = index
                self.refreshWorld()
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            }
            guard let self, self.attemptToken == token, !Task.isCancelled else { return }
            self.finishAttempt(token: token)
        }
    }

    /// Animation is presentation only. Skipping keeps the already computed result.
    func skipPlayback() {
        guard stage == .playback else { return }
        playbackTask?.cancel()
        countdown = nil
        finishAttempt(token: attemptToken)
    }

    private func finishAttempt(token: Int) {
        guard token == attemptToken, stage == .playback else { return }
        stage = .results
        let success = resourceResult?.success ?? roverResult?.success ?? false
        let summary = AttemptSummary(success: success, headline: explanation?.headline ?? "",
                                     setup: setupDescription, numbers: explanation?.numbers ?? [])
        previousAttempt = currentAttempt
        currentAttempt = summary
        if !success {
            failedAttempts += 1
            hintVisible = true
        }
        let result = StarResult(finished: success,
                                predicted: success && predictionWasRight == true,
                                bonus: success && earnedBadge != nil)
        stars = result
        firstCompletion = onRecord(makeRecord(success: success), earnedBadge, result.count)
        refreshWorld()
    }

    func retry() {
        playbackTask?.cancel()
        attemptToken += 1
        countdown = nil
        stars = nil
        notice = nil
        stage = .planning
        resourceResult = nil
        roverResult = nil
        explanation = nil
        prediction = nil
        playbackIndex = 0
        refreshWorld()
    }

    func leave() {
        playbackTask?.cancel()
        attemptToken += 1
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
                      roverConfiguration: isRover ? roverConfiguration : nil)
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
            return "\(cargo) · air \(Self.airLabel(plan(0).airFraction)) then \(Self.airLabel(plan(1).airFraction))"
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

    func worldSnapshot() -> WorldSnapshot {
        var w = WorldSnapshot()
        w.dish = decor.dish
        w.greenhouse = decor.greenhouse || definition.missionID == .livingBase
        w.shelter = decor.shelter || (definition.missionID == .stormDrill && count(.shelterKit) > 0)
        switch definition.missionID {
        case .lightsOut:
            w.arrays = count(.solarArray)
            w.batteries = count(.battery)
            w.padsVisible = stage == .planning
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
        return w
    }
}
