import Foundation

/// How the test plays back. Presentation only: both modes show the same authoritative result.
enum PlaybackMode: String, Codable, CaseIterable, Sendable {
    case automatic
    case stepByStep

    var label: String {
        switch self {
        case .automatic: return "Watch automatically"
        case .stepByStep: return "One step at a time"
        }
    }
}

/// What a checkpoint is about, so the world and the HUD can point at it.
enum CheckpointFocus: Equatable, Sendable {
    case battery
    case arrays
    case air
    case crop
    case shelter
    case rover
    case none
}

/// One moment worth explaining during playback. `traceIndex` points into the engine's full trace;
/// checkpoints never invent values or change timing, they only choose which steps to stop on.
struct PlaybackCheckpoint: Equatable, Sendable, Identifiable {
    var traceIndex: Int
    var title: String
    var text: String
    var focus: CheckpointFocus
    var isWarning: Bool = false

    var id: Int { traceIndex }

    /// Time to read the text, independent of motion settings. Generous for young readers.
    var readingSeconds: Double {
        let words = (title + " " + text).split(separator: " ").count
        return max(3.5, 1.5 + Double(words) * 0.32)
    }
}

/// Builds the explanation sequence from a finished result.
enum PlaybackScript {
    static func checkpoints(for r: ResourceMissionResult, definition d: MissionDefinition, science s: ScienceInputs) -> [PlaybackCheckpoint] {
        guard !r.trace.isEmpty else { return [] }
        if d.missionID == .livingBase { return gardenCheckpoints(r, d, s) }
        return r.trace.map { step in stepCheckpoint(step, r, d) }
    }

    static func roverCheckpoints(_ r: RoverMissionResult) -> [PlaybackCheckpoint] {
        let text: String
        if r.configuration.mode == .earthControl, let marker = r.configuration.observedMarkerM {
            text = "The rover passes the \(Format.meters(marker)) flag. The picture flies to Earth, STOP flies back, and the rover keeps rolling the whole time."
        } else {
            text = "The onboard computer watches the track and stops the rover by itself."
        }
        return [PlaybackCheckpoint(traceIndex: 0, title: "Remote driving", text: text, focus: .rover)]
    }

    // MARK: Step-based missions (power and storm drills)

    private static func stepCheckpoint(_ step: ResourceSnapshot, _ r: ResourceMissionResult, _ d: MissionDefinition) -> PlaybackCheckpoint {
        let battery = "Battery \(Format.number(step.before.batteryKWh)) → \(Format.number(step.after.batteryKWh)) kWh."
        if let failure = step.failure {
            let into = Format.hours(failure.atHour - step.startHour)
            switch failure.constraint {
            case .energyShortage:
                return PlaybackCheckpoint(traceIndex: step.index, title: step.label,
                                          text: "The battery ran out \(into) into this part. The base needed more power than it had.",
                                          focus: .battery, isWarning: true)
            case .oxygenExhausted:
                return PlaybackCheckpoint(traceIndex: step.index, title: step.label,
                                          text: "The air tank ran empty \(into) into this part.", focus: .air, isWarning: true)
            case .foodExhausted:
                return PlaybackCheckpoint(traceIndex: step.index, title: step.label,
                                          text: "The food supply ran out \(into) into this part.", focus: .none, isWarning: true)
            case .shelterMissing:
                return PlaybackCheckpoint(traceIndex: step.index, title: step.label,
                                          text: "The storm began and there was no shelter for the crew.", focus: .shelter, isWarning: true)
            default:
                break
            }
        }
        if step.phaseID == "assembly" {
            return PlaybackCheckpoint(traceIndex: step.index, title: "Before the storm",
                                      text: "\(d.setupLabel) used \(Format.number(step.before.batteryKWh - step.after.batteryKWh)) kWh. \(battery)",
                                      focus: .shelter)
        }
        let made = step.generationKW * step.elapsedHours
        let used = step.demand.totalKW * step.elapsedHours
        var text = "In \(Format.hours(step.elapsedHours)) the base made \(Format.number(made)) kWh and used \(Format.number(used)) kWh. \(battery)"
        if step.curtailedKWh > 0.05 {
            let reason = step.after.batteryCapacityKWh <= 1e-9 ? "there was no battery to store it" : "the battery was full"
            text += " \(Format.number(step.curtailedKWh)) kWh was wasted because \(reason)."
        }
        let oxygenChange = step.after.oxygenKg - step.before.oxygenKg
        if oxygenChange < -0.01 {
            text += " The crew breathed from the air tank."
        }
        if step.sheltered { text = "The crew is in the shelter. " + text }
        let focus: CheckpointFocus = step.sheltered ? .shelter : (made > used ? .arrays : .battery)
        return PlaybackCheckpoint(traceIndex: step.index, title: step.label, text: text, focus: focus)
    }

    // MARK: Garden drill: a few meaningful days instead of 33 quick ones

    private static func day(_ step: ResourceSnapshot) -> Int { Int((step.startHour / 24).rounded(.down)) + 1 }

    private static func gardenCheckpoints(_ r: ResourceMissionResult, _ d: MissionDefinition, _ s: ScienceInputs) -> [PlaybackCheckpoint] {
        var result: [PlaybackCheckpoint] = []
        func add(_ checkpoint: PlaybackCheckpoint) {
            if let existing = result.firstIndex(where: { $0.traceIndex == checkpoint.traceIndex }) {
                result[existing].text += " " + checkpoint.text
                result[existing].isWarning = result[existing].isWarning || checkpoint.isWarning
            } else {
                result.append(checkpoint)
            }
        }
        func budgetText(_ step: ResourceSnapshot) -> String {
            let made = step.generationKW * 24
            let used = step.demand.totalKW * 24
            let net = made - used
            let trend: String
            if net > 0.005 {
                trend = "The extra \(Format.number(net)) kWh goes into the battery."
            } else if net < -0.005 {
                trend = "That is \(Format.number(-net)) kWh short every day, so the battery has to cover the gap."
            } else {
                trend = "Power in and power out are exactly balanced."
            }
            return "Each day the base makes \(Format.number(made)) kWh and uses \(Format.number(used)) kWh. \(trend)"
        }

        let trace = r.trace
        add(PlaybackCheckpoint(traceIndex: trace[0].index, title: "Day 1", text: budgetText(trace[0]), focus: .battery))

        // A new plan block that changes the daily budget.
        for i in 1..<trace.count where trace[i].phaseIndex != trace[i - 1].phaseIndex {
            if abs(trace[i].demand.totalKW - trace[i - 1].demand.totalKW) > 1e-9 {
                add(PlaybackCheckpoint(traceIndex: trace[i].index, title: "Day \(day(trace[i]))",
                                       text: "New plan from today. " + budgetText(trace[i]), focus: .battery))
            }
        }
        // First time the battery is full, and first time the air tank is full.
        if let full = trace.first(where: { $0.after.batteryKWh >= $0.after.batteryCapacityKWh - 1e-9 && $0.before.batteryKWh < $0.before.batteryCapacityKWh - 1e-9 }) {
            add(PlaybackCheckpoint(traceIndex: full.index, title: "Day \(day(full))",
                                   text: "The battery is full. Any extra energy after this is wasted.", focus: .battery))
        }
        if let tankFull = trace.first(where: { $0.after.oxygenKg >= $0.after.oxygenCapacityKg - 1e-9 && $0.before.oxygenKg < $0.before.oxygenCapacityKg - 1e-9 }) {
            add(PlaybackCheckpoint(traceIndex: tankFull.index, title: "Day \(day(tankFull))",
                                   text: "The air maker has filled the air tank.", focus: .air))
        }
        // First warning: battery under a quarter and falling, or air under a day and falling.
        if let low = trace.first(where: { $0.after.batteryKWh < $0.after.batteryCapacityKWh * 0.25 && $0.after.batteryKWh < $0.before.batteryKWh - 1e-9 && $0.failure == nil }) {
            add(PlaybackCheckpoint(traceIndex: low.index, title: "Day \(day(low))",
                                   text: "Warning: the battery is getting low, only \(Format.number(low.after.batteryKWh)) kWh left.",
                                   focus: .battery, isWarning: true))
        }
        let crew = d.initial.crewCount
        if let thin = trace.first(where: {
            ResourceEngine.airHours(oxygenKg: $0.after.oxygenKg, crewCount: crew, science: s) < 24
                && $0.after.oxygenKg < $0.before.oxygenKg - 1e-9 && $0.failure == nil }) {
            add(PlaybackCheckpoint(traceIndex: thin.index, title: "Day \(day(thin))",
                                   text: "Warning: less than one day of air is left in the tank.", focus: .air, isWarning: true))
        }
        // Growth milestones.
        let reference = s.cropReferenceDays
        if let half = trace.first(where: { $0.after.cropGrowthDays >= reference / 2 - 1e-9 && $0.before.cropGrowthDays < reference / 2 - 1e-9 }) {
            add(PlaybackCheckpoint(traceIndex: half.index, title: "Day \(day(half))",
                                   text: "The lettuce is halfway grown.", focus: .crop))
        }
        if let ready = trace.first(where: { $0.after.cropGrowthDays >= reference - 1e-9 && $0.before.cropGrowthDays < reference - 1e-9 }) {
            add(PlaybackCheckpoint(traceIndex: ready.index, title: "Day \(day(ready))",
                                   text: "The lettuce is ready to harvest!", focus: .crop))
        }
        // The outcome.
        let last = trace[trace.count - 1]
        if let failure = last.failure {
            let text: String
            switch failure.constraint {
            case .energyShortage: text = "The battery ran out. The base did not have enough energy for this plan."
            case .oxygenExhausted: text = "The air tank ran empty. The air maker made less oxygen than the crew breathes."
            case .foodExhausted: text = "The packaged food ran out."
            default: text = "The drill stopped."
            }
            add(PlaybackCheckpoint(traceIndex: last.index, title: "Day \(day(last))", text: text,
                                   focus: failure.constraint == .oxygenExhausted ? .air : .battery, isWarning: true))
        } else {
            let grown = Format.number(last.after.cropGrowthDays)
            let text = last.after.cropGrowthDays >= reference - 1e-9
                ? "Day \(day(last)) is done, and the drill is complete."
                : "The drill is over. The lettuce grew \(grown) of the \(Format.number(reference, digits: 0)) days it needs."
            add(PlaybackCheckpoint(traceIndex: last.index, title: "Day \(day(last))", text: text, focus: .crop,
                                   isWarning: last.after.cropGrowthDays < reference - 1e-9))
        }
        return result.sorted { $0.traceIndex < $1.traceIndex }
    }
}
