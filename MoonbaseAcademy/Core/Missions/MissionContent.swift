import Foundation

/// Child-facing words for each drill. Kept apart from the engine so copy can change without touching numbers.
struct MissionCopy {
    let topic: String
    let symbol: String
    let story: String
    let objectives: [String]
    let bonus: String?
    let question: String
    let hint: String
    let badge: String?

    static func of(_ id: MissionID) -> MissionCopy {
        switch id {
        case .lightsOut:
            return MissionCopy(
                topic: "Power and life support",
                symbol: "bolt.fill",
                story: "Solar arrays make electricity while the Sun shines. Batteries save it for later. Get the base ready for a six-hour shadow drill with no sunlight at all.",
                objectives: ["Keep the base powered through 6 hours of sunlight and 6 hours of shadow.",
                             "Finish with at least 24 hours of air in the tank."],
                bonus: "Bonus: power a 1.5 kWh science observation while the Sun is up.",
                question: "Will the batteries keep the base powered all through the shadow?",
                hint: "Batteries keep energy for later. Solar arrays only help while the Sun shines. The air maker uses a lot of power, and the oxygen tank can cover a few hours if you turn it down.",
                badge: "observer")
        case .livingBase:
            return MissionCopy(
                topic: "Food and life support",
                symbol: "leaf.fill",
                story: "Fresh food helps crews on long missions. Grow lettuce in the greenhouse while the air maker keeps the crew breathing. The base gets 17 kWh of energy each day.",
                objectives: ["Harvest fresh lettuce by day 33.",
                             "Keep power, air and packaged food from running out."],
                bonus: "Bonus: run research with spare energy.",
                question: "Will the lettuce be ready to harvest by day 33?",
                hint: "Lettuce needs its lights on 16 hours a day to be ready by day 33. Research uses extra energy every single day.",
                badge: "gardenResearcher")
        case .stormDrill:
            return MissionCopy(
                topic: "Radiation shielding",
                symbol: "shield.lefthalf.filled",
                story: "A solar storm drill. Its timing replays a real particle event recorded near Earth on September 10, 2017. The crew must stay inside a shelter for the whole storm.",
                objectives: ["Keep the crew in a shelter for the whole storm.",
                             "Finish with at least 24 hours of air in the tank."],
                bonus: "Bonus: run science during the storm with the science kit.",
                question: "Will there still be at least 24 hours of air when the storm ends?",
                hint: "The shelter is required. Building it uses 3 kWh. You can turn the air maker down for a while, because the oxygen tank is a reserve, but the reserve is not endless.",
                badge: "stormScientist")
        case .signalLag:
            return MissionCopy(
                topic: "Communication delay",
                symbol: "antenna.radiowaves.left.and.right",
                story: "Mission Control on Earth drives the rover using pictures the rover sends home. Radio signals take time to cross 384,400 km. Stop the rover inside the yellow bay, 5 to 6 m along the track.",
                objectives: ["Stop the rover inside the yellow bay (5 to 6 m)."],
                bonus: "Bonus: bring the science camera and stop in the bay.",
                question: "Will the rover stop inside the yellow bay?",
                hint: "A picture takes about 1.3 seconds to reach Earth, and your stop command takes about 1.3 seconds to get back. The rover keeps driving the whole time. Send the command early!",
                badge: "roverPhotographer")
        }
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

    static func detail(_ item: CargoItem) -> String {
        switch item.kind {
        case .solarArray: return "Makes 1 kW in sunlight"
        case .battery: return "Stores up to 4 kWh, starts empty"
        case .chargedBattery: return "Adds 4 kWh, already full"
        case .shelterKit: return "Needs 3 kWh to build"
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
                if d.missionID == .lightsOut && r.configuration.count(.battery) == 0 {
                    headline = "No battery, no power in the dark"
                    paragraphs.append("Your solar arrays made plenty of power in sunlight, but there was nowhere to keep it. When the shadow started, the lights went out right away.")
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
                    paragraphs.append("Try storing more energy, skipping the observation, or turning the air maker down during the shadow.")
                case .livingBase:
                    paragraphs.append("Every kWh of research is used again every day. Small daily extras add up over 33 days.")
                case .stormDrill:
                    paragraphs.append("Building the shelter used 3 kWh first. The air maker and research together needed more power than the base made.")
                case .signalLag:
                    break
                }
            case .oxygenExhausted:
                headline = "The air ran out"
                let daily = Double(d.initial.crewCount) * s.oxygenKgPerPersonDay
                paragraphs.append("The two crew members breathe about \(Format.kg(daily)) of oxygen a day. At this setting the air maker made less than that, so the tank emptied \(into) into the \(phase).")
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
            paragraphs.append("33 days is how long lettuce grew on the International Space Station in NASA's Veggie experiment.")
        } else {
            switch d.missionID {
            case .lightsOut:
                headline = "The lights stayed on!"
                let afterSun = r.trace.first { $0.phaseID == "sunlit" }?.after.batteryKWh ?? 0
                paragraphs.append("In sunlight your arrays ran the base and stored \(Format.kWh(afterSun)) in the batteries. In the shadow the batteries took over and still had \(Format.kWh(r.finalState.batteryKWh)) at the end.")
                if let shadowPlan = r.configuration.plans.last, shadowPlan.airFraction < 1 {
                    paragraphs.append("Turning the air maker down in the shadow saved power. The oxygen tank covered the gap.")
                }
                if r.observationBadge { paragraphs.append("Bonus: your observation was fully powered.") }
            case .livingBase:
                headline = "Fresh lettuce!"
                paragraphs.append("The lights ran long enough every day, and the lettuce was ready on day 33. The air maker kept the tank full the whole time.")
                paragraphs.append("Lettuce is a fresh extra. It does not replace the packaged meals.")
            case .stormDrill:
                headline = "Everyone stayed sheltered"
                paragraphs.append("The crew stayed in the shelter for the whole \(Format.hours(s.stormActiveHours)) storm, timed from the September 2017 event. You finished with \(Format.wholeHours(r.finalAirHours)) of air.")
                if r.researchUnits > 1e-9 {
                    paragraphs.append("Your science ran while the air maker rested. That spent some of the oxygen reserve, and you planned for it.")
                }
            case .signalLag:
                headline = "Done"
            }
        }
        if curtailed > 0.05 {
            paragraphs.append("\(Format.kWh(curtailed)) of sunshine went to waste because the batteries were already full.")
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
            paragraphs.append("Signals still take time to travel. The computer simply does not need the trip to Earth and back. It took up the cargo space, so there was no science camera this time.")
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
