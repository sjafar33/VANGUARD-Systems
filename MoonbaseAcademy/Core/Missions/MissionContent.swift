import Foundation

/// Child-facing words for each drill. Kept apart from the engine so copy can change without touching numbers.
/// Every number in these sentences is read from the drill definition or the science inputs, so the harder
/// variants never show the standard drill's values.
struct MissionCopy {
    let topic: String
    let symbol: String
    let story: String
    let objectives: [String]
    let bonus: String?
    let question: String
    let hint: String
    let badge: String?

    static func topic(_ id: MissionID) -> String {
        switch id {
        case .lightsOut: return "Power and life support"
        case .livingBase: return "Food and life support"
        case .stormDrill: return "Radiation shielding"
        case .signalLag: return "Communication delay"
        }
    }

    static func symbol(_ id: MissionID) -> String {
        switch id {
        case .lightsOut: return "bolt.fill"
        case .livingBase: return "leaf.fill"
        case .stormDrill: return "shield.lefthalf.filled"
        case .signalLag: return "antenna.radiowaves.left.and.right"
        }
    }

    static func badge(_ id: MissionID) -> String? {
        switch id {
        case .lightsOut: return "observer"
        case .livingBase: return "gardenResearcher"
        case .stormDrill: return "stormScientist"
        case .signalLag: return "roverPhotographer"
        }
    }

    static func of(_ d: MissionDefinition, science s: ScienceInputs) -> MissionCopy {
        let id = d.missionID
        let minAir = Words.hours(d.success.minimumAirHours)
        switch id {
        case .lightsOut:
            let sun = d.phases.first?.durationHours ?? 0
            let shadow = d.phases.last?.durationHours ?? 0
            let observation = (d.phases.first?.research?.powerKWPerLevel ?? 0) * sun
            if BaseExperiment.isBaseTest(d) {
                return MissionCopy(
                    topic: topic(id), symbol: symbol(id),
                    story: "This is your own base. Its solar arrays make electricity while the Sun shines, and its batteries save it for the \(Words.hourAdjective(shadow)) shadow.",
                    objectives: ["Keep your base powered through \(Words.hours(sun)) of sunlight and \(Words.hours(shadow)) of shadow.",
                                 "Finish with at least \(minAir) of air in the tank."],
                    bonus: "Bonus: power a \(Words.kWh(observation)) science observation while the Sun is up.",
                    question: "Will your base stay powered all through the shadow?",
                    hint: "Batteries can only store what your arrays make in sunlight. Turning the air maker down saves power, but then the crew breathes from the oxygen tank. To change the equipment, build at your base.",
                    badge: nil)
            }
            return MissionCopy(
                topic: topic(id), symbol: symbol(id),
                story: "Solar arrays make electricity while the Sun shines. Batteries save it for later. Get the base ready for a \(Words.hourAdjective(shadow)) shadow drill with no sunlight at all.",
                objectives: ["Keep the base powered through \(Words.hours(sun)) of sunlight and \(Words.hours(shadow)) of shadow.",
                             "Finish with at least \(minAir) of air in the tank."],
                bonus: "Bonus: power a \(Words.kWh(observation)) science observation while the Sun is up.",
                question: "Will the batteries keep the base powered all through the shadow?",
                hint: "Batteries keep energy for later. Solar arrays only help while the Sun shines. The air maker uses a lot of power, and the oxygen tank can cover a few hours if you turn it down.",
                badge: badge(id))
        case .livingBase:
            let days = Words.number(d.totalHours / 24)
            let daily = Words.kWh((d.phases.first?.baseSupplyKW ?? 0) * 24)
            let light = Words.number(d.assumptions.gardenFullLightHours)
            return MissionCopy(
                topic: topic(id), symbol: symbol(id),
                story: "Fresh food helps crews on long missions. Grow lettuce in the greenhouse while the air maker keeps the crew breathing. The base gets \(daily) of energy each day.",
                objectives: ["Harvest fresh lettuce by day \(days).",
                             "Keep power, air and packaged food from running out."],
                bonus: "Bonus: run research with spare energy.",
                question: "Will the lettuce be ready to harvest by day \(days)?",
                hint: "In this game, lettuce needs its lights on \(light) hours a day to be ready by day \(days). Research uses extra energy every single day.",
                badge: badge(id))
        case .stormDrill:
            let shelter = Words.kWh(d.item(.shelterKit)?.assemblyEnergyKWh ?? 0)
            return MissionCopy(
                topic: topic(id), symbol: symbol(id),
                story: "A solar storm drill. Its timing replays a real particle event recorded near Earth starting \(Words.date(s.stormThresholdCrossing)). The crew must stay inside a shelter for the whole storm.",
                objectives: ["Keep the crew in a shelter for the whole storm.",
                             "Finish with at least \(minAir) of air in the tank."],
                bonus: "Bonus: run science during the storm with the science kit.",
                question: "Will there still be at least \(minAir) of air when the storm ends?",
                hint: "The shelter is required. Building it uses \(shelter). You can turn the air maker down for a while, because the oxygen tank is a reserve, but the reserve is not endless.",
                badge: badge(id))
        case .signalLag:
            let bay = d.rover.map { "\(Words.number($0.targetBayStartM)) to \(Words.number($0.targetBayEndM)) m" } ?? "the bay"
            let oneWay = Words.number(s.oneWayDelaySeconds)
            return MissionCopy(
                topic: topic(id), symbol: symbol(id),
                story: "Mission Control on Earth drives the rover using pictures the rover sends home. Radio signals take time to cross \(Words.km(s.moonDistanceKm)). Stop the rover inside the yellow bay, \(bay) along the track.",
                objectives: ["Stop the rover inside the yellow bay (\(bay))."],
                bonus: "Bonus: bring the science camera and stop in the bay.",
                question: "Will the rover stop inside the yellow bay?",
                hint: "A picture takes about \(oneWay) seconds to reach Earth, and your stop command takes about \(oneWay) seconds to get back. The rover keeps driving the whole time. Send the command early!",
                badge: badge(id))
        }
    }
}

/// Short help that keeps power and energy apart.
enum UnitHelp {
    static let powerAndEnergy = "kW is power: how fast energy is being used right now. kWh is energy: how much is used over time. Using 1 kW for 1 hour uses 1 kWh."
}

/// Child-friendly number words. Display rounding only; calculations keep full precision.
enum Words {
    static func number(_ value: Double) -> String { Format.number(value) }

    static func hours(_ value: Double) -> String {
        if abs(value - value.rounded()) < 1e-9 {
            let whole = Int(value.rounded())
            return whole == 1 ? "1 hour" : "\(whole) hours"
        }
        return Format.hours(value)
    }

    static func hourAdjective(_ value: Double) -> String {
        abs(value - value.rounded()) < 1e-9 ? "\(Int(value.rounded()))-hour" : Format.hours(value)
    }

    static func kWh(_ value: Double) -> String { "\(Format.number(value)) kWh" }

    static func km(_ value: Double) -> String { "\(Int(value.rounded()).formatted()) km" }

    static func date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}

enum CargoCopy {
    static func name(_ kind: CargoKind) -> String {
        switch kind {
        case .solarArray: return "Solar array"
        case .battery: return "Battery"
        case .chargedBattery: return "Charged battery"
        case .shelterKit: return "Shelter kit"
        case .scienceKit: return "Science kit"
        case .onboardComputer: return "Onboard computer"
        case .scienceCamera: return "Science camera"
        }
    }

    static func detail(_ item: CargoItem, in d: MissionDefinition) -> String {
        switch item.kind {
        case .solarArray:
            let kW = d.phases.map(\.solarKWPerArray).max() ?? 0
            return "Makes \(Format.kW(kW)) of power in sunlight"
        case .battery: return "Stores up to \(Words.kWh(item.batteryCapacityKWh)), starts empty"
        case .chargedBattery: return "Adds \(Words.kWh(item.batteryInitialKWh)), already full"
        case .shelterKit: return "Needs \(Words.kWh(item.assemblyEnergyKWh)) to build"
        case .scienceKit: return "Lets you run research"
        case .onboardComputer: return "Stops the rover by itself"
        case .scienceCamera: return "Takes science photos"
        }
    }
}

enum Prediction: String, CaseIterable, Codable, Sendable {
    case yes
    case no
    case unsure

    var label: String {
        switch self {
        case .yes: return "Yes"
        case .no: return "No"
        case .unsure: return "Not sure"
        }
    }
}

struct NumberRow: Equatable, Hashable {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
}

struct Explanation: Equatable {
    var success: Bool
    var headline: String
    var paragraphs: [String]
    var numbers: [NumberRow]
}

/// Turns an engine result into a cause-and-effect explanation. Every number shown comes from the result.
enum ExplanationWriter {
    static func phaseLabel(_ d: MissionDefinition, _ id: String) -> String {
        if id == "assembly" { return "shelter building" }
        return d.phases.first { $0.id == id }?.label.lowercased() ?? id
    }

    static func hoursInto(_ d: MissionDefinition, _ failure: FailureEvent) -> Double {
        var start = 0.0
        for phase in d.phases {
            if phase.id == failure.phaseID { return failure.atHour - start }
            start += phase.durationHours
        }
        return failure.atHour
    }

    /// What the air tank actually did, read from the trace.
    static func airStory(_ r: ResourceMissionResult, definition d: MissionDefinition, science s: ScienceInputs) -> String {
        let lowest = r.trace.map(\.after.oxygenKg).min() ?? r.finalState.oxygenKg
        if lowest >= r.initialState.oxygenKg - 1e-9 {
            if r.finalState.oxygenKg > r.initialState.oxygenKg + 1e-9 {
                return "The air maker made more oxygen than the crew breathed, so the air tank filled from \(Format.kg(r.initialState.oxygenKg)) to \(Format.kg(r.finalState.oxygenKg))."
            }
            return "The air maker made as much oxygen as the crew breathed, so the air tank never went down."
        }
        let hours = ResourceEngine.airHours(oxygenKg: lowest, crewCount: d.initial.crewCount, science: s)
        return "The air tank went down to \(Format.kg(lowest)) at its lowest (about \(Format.wholeHours(hours)) of air), but it never ran out."
    }

    /// Why the storm drill ran out of power, from the step where it happened.
    static func stormShortageReason(_ r: ResourceMissionResult) -> String {
        guard let step = r.trace.last(where: { $0.failure != nil }) else { return "" }
        if step.phaseID == "assembly" {
            return "Building the shelter needed more energy than the battery had."
        }
        var parts: [String] = []
        if let assembly = r.trace.first(where: { $0.phaseID == "assembly" }) {
            parts.append("Building the shelter took \(Words.kWh(max(0, assembly.before.batteryKWh - assembly.after.batteryKWh))) out of the battery first.")
        }
        let air = step.demand.airKW > 1e-9
        let research = step.demand.researchKW > 1e-9
        let users = air && research ? "The air maker and research together"
            : air ? "The air maker and the base" : research ? "Research and the base" : "The base"
        parts.append("\(users) needed \(Format.kW(step.demand.totalKW)) of power, but only \(Format.kW(step.generationKW)) was coming in, so the battery drained until it was empty.")
        return parts.joined(separator: " ")
    }

    /// Garden failures happen slowly, so the lead names the recurring daily gap rather than the final step.
    /// Every value comes from the trace; the step-level detail moves into the numbers list.
    static func gardenDeficitLead(_ r: ResourceMissionResult, _ failure: FailureEvent) -> (text: String, numbers: [NumberRow])? {
        guard let failStep = r.trace.last(where: { $0.failure != nil }) ?? r.trace.last else { return nil }
        let made = failStep.generationKW * 24
        let used = failStep.demand.totalKW * 24
        let gap = used - made
        guard gap > 1e-6 else { return nil }
        let day = Int((failure.atHour / 24).rounded(.down)) + 1
        let text = "The base used \(Format.kWh(gap)) more than it made each day. The battery covered the gap until day \(day)."
        let numbers = [
            NumberRow("Made each day", Format.kWh(made)),
            NumberRow("Used each day", Format.kWh(used)),
            NumberRow("Power ran out", "Day \(day)"),
            NumberRow("Short at the end", Format.kWh(failure.shortfall))
        ]
        return (text, numbers)
    }

    static func resource(_ r: ResourceMissionResult, definition d: MissionDefinition, science s: ScienceInputs) -> Explanation {
        var numbers: [NumberRow] = [
            NumberRow("Battery at the end", Format.kWh(r.finalState.batteryKWh)),
            NumberRow("Air left", Format.wholeHours(r.finalAirHours))
        ]
        if d.hasGarden {
            numbers.append(NumberRow("Lettuce growth", "\(Format.number(r.finalState.cropGrowthDays)) of \(Format.number(s.cropReferenceDays, digits: 0)) days"))
        }
        if r.researchUnits > 1e-9 { numbers.append(NumberRow("Research", Format.number(r.researchUnits))) }
        let curtailed = r.trace.reduce(0) { $0 + $1.curtailedKWh }
        var paragraphs: [String] = []
        let headline: String

        if let failure = r.failure {
            let into = Format.hours(hoursInto(d, failure))
            let phase = phaseLabel(d, failure.phaseID)
            switch failure.constraint {
            case .energyShortage:
                if d.missionID == .lightsOut && r.configuration.count(.battery) == 0 && failure.phaseID == "shadow" {
                    headline = "No battery, no power in the dark"
                    paragraphs.append("Your solar arrays made power in sunlight, but there was nowhere to keep it. When the shadow started, the lights went out right away.")
                } else if d.missionID == .livingBase, let lead = gardenDeficitLead(r, failure) {
                    headline = "The power ran out"
                    paragraphs.append(lead.text)
                    numbers.append(contentsOf: lead.numbers)
                } else {
                    headline = "The power ran out"
                    paragraphs.append("The batteries ran empty \(into) into the \(phase). The base needed \(Format.kW(failure.deficitKW)) more than it was getting, so it was short \(Format.kWh(failure.shortfall)) by the end of that step.")
                }
                switch d.missionID {
                case .lightsOut:
                    if BaseExperiment.isBaseTest(d) {
                        // Read from the trace: were the batteries full before the dark, or still filling?
                        let sunlit = r.trace.first { $0.phaseID == "sunlit" }
                        let wereFull = sunlit.map { $0.after.batteryKWh >= $0.after.batteryCapacityKWh - 1e-9 } ?? false
                        if wereFull {
                            paragraphs.append("Your batteries were already full when the shadow started, and it still wasn't enough. Back at your base, another battery or a battery upgrade would store more.")
                        } else {
                            paragraphs.append("Your batteries were not full when the shadow started. Back at your base, another solar array or a solar array upgrade would fill them faster.")
                        }
                        paragraphs.append("Or turn the air maker down in the shadow. That saves power, but the crew then breathes from the tank.")
                    } else {
                        paragraphs.append("Try storing more energy, skipping the observation, or turning the air maker down during the shadow.")
                    }
                case .livingBase:
                    paragraphs.append("Every kWh of research is used again every day. Small daily extras add up over \(Words.number(d.totalHours / 24)) days.")
                case .stormDrill:
                    paragraphs.append(stormShortageReason(r))
                case .signalLag:
                    break
                }
            case .oxygenExhausted:
                headline = "The air ran out"
                let daily = Double(d.initial.crewCount) * s.oxygenKgPerPersonDay
                paragraphs.append("The \(d.initial.crewCount) crew members breathe about \(Format.kg(daily)) of oxygen a day. At this setting the air maker made less than that, so the tank emptied \(into) into the \(phase).")
            case .foodExhausted:
                headline = "The packaged food ran out"
                paragraphs.append("Each crew member eats about \(Format.kg(s.foodDryKgPerPersonDay)) of dry food a day, and the supply ran out \(into) into the \(phase).")
            case .shelterMissing:
                headline = "No shelter for the storm"
                paragraphs.append("In this drill the crew must stay inside a shelter for the whole storm. Without the shelter kit, the protection goal failed as soon as the storm began.")
                paragraphs.append("The game does not calculate a radiation dose. The shelter rule is a simple training rule.")
            default:
                headline = "The drill stopped"
            }
        } else if r.failedConstraints.contains(.airReserveBelowMinimum) {
            headline = "Not enough air left"
            paragraphs.append("Nothing ran out, but only \(Format.wholeHours(r.finalAirHours)) of air was left at the end. The drill needs at least \(Format.wholeHours(d.success.minimumAirHours)) in the tank, in case something goes wrong.")
        } else if r.failedConstraints.contains(.harvestNotReached) {
            headline = "No harvest yet"
            paragraphs.append("The base kept running, but the lettuce only grew \(Format.number(r.finalState.cropGrowthDays)) of the \(Format.number(s.cropReferenceDays, digits: 0)) days it needs. With less light, plants grow more slowly.")
            paragraphs.append("About \(Words.number(s.cropReferenceDays)) days is how long lettuce grew on the International Space Station in NASA's Veggie experiment. The game uses that as a training rule; it does not prove lettuce would grow the same way on the Moon.")
        } else {
            switch d.missionID {
            case .lightsOut:
                headline = "The lights stayed on!"
                let afterSun = r.trace.first { $0.phaseID == "sunlit" }?.after.batteryKWh ?? 0
                paragraphs.append("In sunlight your arrays ran the base and stored \(Format.kWh(afterSun)) in the batteries. In the shadow the batteries took over and still had \(Format.kWh(r.finalState.batteryKWh)) at the end.")
                if let shadowPlan = r.configuration.plans.last, shadowPlan.airFraction < 1,
                   let shadowStep = r.trace.last(where: { $0.phaseID == "shadow" }),
                   shadowStep.after.oxygenKg < shadowStep.before.oxygenKg - 1e-9 {
                    paragraphs.append("Turning the air maker down in the shadow saved power. The crew breathed from the oxygen tank, which went from \(Format.kg(shadowStep.before.oxygenKg)) to \(Format.kg(shadowStep.after.oxygenKg)).")
                } else if let shadowPlan = r.configuration.plans.last, shadowPlan.airFraction < 1 {
                    paragraphs.append("Turning the air maker down in the shadow saved power.")
                }
                if r.observationBadge { paragraphs.append("Bonus: your observation was fully powered.") }
            case .livingBase:
                headline = "Fresh lettuce!"
                let readyDay = r.trace.first { $0.after.cropGrowthDays >= s.cropReferenceDays - 1e-9 }
                    .map { Int(($0.startHour / 24).rounded(.down)) + 1 }
                paragraphs.append("The greenhouse lights ran long enough, and the lettuce was ready on day \(readyDay ?? Int((d.totalHours / 24).rounded())).")
                paragraphs.append(airStory(r, definition: d, science: s))
                paragraphs.append("Lettuce is a fresh extra. It does not replace the packaged meals.")
            case .stormDrill:
                headline = "Everyone stayed sheltered"
                paragraphs.append("The crew stayed in the shelter for the whole \(Format.hours(s.stormActiveHours)) storm, timed from the \(Words.date(s.stormThresholdCrossing)) event. You finished with \(Format.wholeHours(r.finalAirHours)) of air.")
                if r.researchUnits > 1e-9 {
                    paragraphs.append("Your storm science ran and used \(Words.kWh(r.trace.reduce(0) { $0 + $1.researchKWh })) of energy.")
                }
                if r.finalState.oxygenKg < r.initialState.oxygenKg - 1e-9 {
                    paragraphs.append("The crew breathed some of the oxygen reserve: the tank went from \(Format.kg(r.initialState.oxygenKg)) to \(Format.kg(r.finalState.oxygenKg)).")
                }
                paragraphs.append("The game does not calculate a radiation dose, and the storm's timing near Earth does not tell us the dose on the Moon. The shelter rule is a simple training rule.")
            case .signalLag:
                headline = "Done"
            }
        }
        if curtailed > 0.05 {
            let what = d.phases.contains { $0.solarKWPerArray > 0 } ? "sunshine energy" : "energy"
            paragraphs.append("\(Format.kWh(curtailed)) of \(what) went to waste because the batteries were already full.")
        }
        return Explanation(success: r.success, headline: headline, paragraphs: paragraphs, numbers: numbers)
    }

    static func rover(_ r: RoverMissionResult, definition d: MissionDefinition) -> Explanation {
        let speed = d.rover?.speedMPerSecond ?? 1
        var paragraphs: [String] = []
        let headline: String
        switch r.outcome {
        case .inBay: headline = "Stopped in the bay!"
        case .stoppedShort: headline = "Stopped too early"
        case .overshot: headline = "Rolled past the bay"
        }
        if r.configuration.mode == .earthControl, let marker = r.configuration.observedMarkerM {
            paragraphs.append("You sent the stop command when the picture showed the rover at \(Format.meters(marker)).")
            paragraphs.append("That picture took \(Format.seconds(r.oneWayDelaySeconds)) to reach Earth, and your command took another \(Format.seconds(r.oneWayDelaySeconds)) to get back. The rover kept rolling at \(Format.meters(speed)) per second for \(Format.seconds(r.loopDelaySeconds)), about \(Format.meters(r.distanceDuringDelayM)) farther.")
            paragraphs.append("So it stopped at \(Format.meters(r.finalStopM)).")
        } else {
            paragraphs.append("The onboard computer stopped the rover at \(Format.meters(r.finalStopM)) by itself, without waiting for Earth.")
            paragraphs.append("Signals still take time to travel. The computer simply does not need the trip to Earth and back.")
            if r.configuration.count(.scienceCamera) == 0 {
                paragraphs.append("The computer took up the cargo space, so there was no science camera this time.")
            }
        }
        if r.observationEarned { paragraphs.append("Bonus: the science camera took its photo in the bay.") }
        let numbers = [
            NumberRow("Stop position", Format.meters(r.finalStopM)),
            NumberRow("Signal delay, one way", Format.seconds(r.oneWayDelaySeconds)),
            NumberRow("Picture + command", Format.seconds(r.loopDelaySeconds))
        ]
        return Explanation(success: r.success, headline: headline, paragraphs: paragraphs, numbers: numbers)
    }
}
