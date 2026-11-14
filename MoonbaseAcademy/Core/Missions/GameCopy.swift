import Foundation

/// The game voice: Nova's lines, star goals and rewards. Short sentences for readers aged 7 to 12.
struct GameCopy {
    let title: String
    var intro: [String]
    var planTip: String
    let bonusStar: String
    let unlock: String

    /// Titles and lines that never depend on a drill's numbers (used on the base map).
    static func of(_ id: MissionID) -> GameCopy {
        switch id {
        case .lightsOut:
            return GameCopy(
                title: "Lights Out",
                intro: ["Hi, I'm Nova, your base robot! Our habitat has no power yet."],
                planTip: "Tip: arrays only work in sunlight. What could keep power for the shadow?",
                bonusStar: "Power the observation",
                unlock: "Solar farm built on your base!")
        case .livingBase:
            return GameCopy(
                title: "The Living Base",
                intro: ["Astronauts love fresh food! Let's grow lettuce in the greenhouse."],
                planTip: "Tap a plan card to set the greenhouse lights and the air maker.",
                bonusStar: "Do some research",
                unlock: "Greenhouse built on your base!")
        case .stormDrill:
            return GameCopy(
                title: "Storm Drill",
                intro: ["A solar storm drill! Its timing comes from a real storm recorded near Earth."],
                planTip: "The shelter is a must. Building it uses battery energy.",
                bonusStar: "Run storm science",
                unlock: "Storm shelter built on your base!")
        case .signalLag:
            return GameCopy(
                title: "Signal Lag",
                intro: ["Mission Control on Earth drives our rover using its camera pictures."],
                planTip: "Tap a flag on the track, or pick one below. When will STOP arrive?",
                bonusStar: "Photo with the camera",
                unlock: "Radio dish built on your base!")
        }
    }

    /// The full briefing for one drill, with numbers read from that drill (standard or harder variant).
    static func of(_ d: MissionDefinition, science s: ScienceInputs) -> GameCopy {
        if BaseExperiment.isBaseTest(d) { return baseTest(d) }
        var copy = of(d.missionID)
        switch d.missionID {
        case .lightsOut:
            let shadow = d.phases.last?.durationHours ?? 0
            copy.intro += ["Solar arrays make power in sunlight. But a \(Words.hourAdjective(shadow)) shadow drill is coming, with no sun at all.",
                           "Build a power system that lasts through the dark!"]
        case .livingBase:
            let days = Words.number(d.totalHours / 24)
            let daily = Words.kWh((d.phases.first?.baseSupplyKW ?? 0) * 24)
            copy.intro += ["Lettuce grown on the space station took about \(Words.number(s.cropReferenceDays)) days. Our drill lasts \(days) days, with \(daily) of energy each day.",
                           "Keep the air maker running too. Plants and people both need power!"]
        case .stormDrill:
            let storm = d.totalHours
            copy.intro += ["That storm started on \(Words.date(s.stormThresholdCrossing)). The crew must stay in a shelter for the whole storm: about \(Int(storm.rounded())) hours.",
                           "The lander has room for \(d.cargoBudget) crates. Choose your cargo wisely!"]
            copy.planTip = "The shelter is a must. Building it uses \(Words.kWh(d.item(.shelterKit)?.assemblyEnergyKWh ?? 0)) of battery."
        case .signalLag:
            copy.intro += ["Radio signals take time to cross \(Words.km(s.moonDistanceKm)) of space, even at the speed of light.",
                           "Park the rover in the yellow bay. Tap a flag to choose when Earth sends STOP!"]
        }
        return copy
    }

    /// "Test My Base": the same shadow as Lights Out, but with the player's own equipment.
    /// Three lines, to match the three Lights Out briefing scenes.
    static func baseTest(_ d: MissionDefinition) -> GameCopy {
        let gear = BaseTestInputs(arrays: d.item(.solarArray)?.maxCount ?? 0,
                                  batteries: d.item(.battery)?.maxCount ?? 0)
        let shadow = d.phases.last?.durationHours ?? 0
        return GameCopy(
            title: "Test My Base",
            intro: ["This test is about YOUR base. No lander and no spare crates: only what you really built.",
                    "You have \(gear.summary). A \(Words.hourAdjective(shadow)) shadow is coming, with no sun at all.",
                    "Set the air maker for sunlight and for the shadow, then test it!"],
            planTip: "Tap Off, Half or Full to set the air maker. Less air saves power, but the crew breathes from the tank.",
            bonusStar: "Power the observation",
            unlock: "Your base passed its first shadow test!")
    }

    static func rank(stars: Int) -> String {
        switch stars {
        case ..<3: return "Cadet"
        case 3..<6: return "Engineer"
        case 6..<9: return "Chief Engineer"
        default: return "Base Commander"
        }
    }

    /// Live commentary for a playback step. The words describe what the engine already computed.
    static func commentary(_ step: ResourceSnapshot, mission: MissionID) -> String {
        let codes = step.explanations
        if codes.contains(.energyRanOut) { return "Oh no! The batteries are empty and the lights go out." }
        if codes.contains(.oxygenRanOut) { return "Uh-oh! The air tank is empty." }
        if codes.contains(.foodRanOut) { return "The food supply ran out!" }
        if codes.contains(.noShelter) { return "No shelter! The crew has nowhere safe to go." }
        if codes.contains(.assembledShelter) {
            return "Building the shelter. That uses \(Words.kWh(max(0, step.before.batteryKWh - step.after.batteryKWh))) of battery."
        }
        if mission == .livingBase {
            if codes.contains(.cropGrowing) { return "\(step.label): the lettuce is growing!" }
            return "\(step.label): the greenhouse is dark, so nothing grows."
        }
        var line: String
        if codes.contains(.shelterOccupied) {
            line = "The crew is safe in the shelter while the storm passes."
        } else if codes.contains(.surplusCurtailed) {
            line = "Sunshine! The batteries are full, so some sunshine goes to waste."
        } else if codes.contains(.solarCharging) {
            line = "Sunshine! The arrays power the base and charge the batteries."
        } else if codes.contains(.batteryBridging) {
            line = step.mood == .shadow ? "Shadow! Now the batteries keep the lights on." : "The base is using battery power."
        } else {
            line = "Power in and power out are balanced."
        }
        if codes.contains(.oxygenReserveSpent) { line += " The air maker rests, so the crew breathes from the tank." }
        if codes.contains(.researchPowered) { line += " Science is running!" }
        return line
    }
}
