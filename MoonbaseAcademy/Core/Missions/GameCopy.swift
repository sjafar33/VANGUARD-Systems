import Foundation

/// The game voice: Nova's lines, star goals and rewards. Short sentences for readers aged 7 to 12.
struct GameCopy {
    let title: String
    let intro: [String]
    let planTip: String
    let bonusStar: String
    let unlock: String

    static func of(_ id: MissionID) -> GameCopy {
        switch id {
        case .lightsOut:
            return GameCopy(
                title: "Lights Out",
                intro: ["Hi, I'm Nova, your base robot! Our habitat has no power yet.",
                        "Solar arrays make power in sunlight. But a 6-hour shadow drill is coming, with no sun at all.",
                        "Build a power system that lasts through the dark!"],
                planTip: "Tip: arrays only work in sunlight. What could keep power for the shadow?",
                bonusStar: "Power the observation",
                unlock: "Solar farm built on your base!")
        case .livingBase:
            return GameCopy(
                title: "The Living Base",
                intro: ["Astronauts love fresh food! Let's grow lettuce in the greenhouse.",
                        "NASA grew lettuce on the space station in 33 days. We have 33 days and 17 kWh of energy each day.",
                        "Keep the air maker running too. Plants and people both need power!"],
                planTip: "Tap a plan card to set the greenhouse lights and the air maker.",
                bonusStar: "Do some research",
                unlock: "Greenhouse built on your base!")
        case .stormDrill:
            return GameCopy(
                title: "Storm Drill",
                intro: ["A solar storm drill! Its timing comes from a real storm seen on September 10, 2017.",
                        "The crew must stay in a shelter for the whole storm: about 98 hours.",
                        "The lander carries 4 crates. Choose your cargo wisely!"],
                planTip: "The shelter is a must. Building it uses 3 kWh of battery.",
                bonusStar: "Run storm science",
                unlock: "Storm shelter built on your base!")
        case .signalLag:
            return GameCopy(
                title: "Signal Lag",
                intro: ["Mission Control on Earth drives our rover using its camera pictures.",
                        "Radio signals take time to cross 384,400 km of space, even at the speed of light.",
                        "Park the rover in the yellow bay. Tap a flag to choose when Earth sends STOP!"],
                planTip: "Tap a flag on the track, or pick one below. When will STOP arrive?",
                bonusStar: "Photo with the camera",
                unlock: "Radio dish built on your base!")
        }
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
        if codes.contains(.assembledShelter) { return "Building the shelter. That uses 3 kWh of battery." }
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
