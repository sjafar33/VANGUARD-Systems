import Foundation

/// Authored hypotheses, evaluated separately from the deterministic mission outcome.
enum PredictionReason: String, Codable, Equatable, CaseIterable {
    case resourceBudget, batteryCreatesEnergy, arraysWorkInShadow
    case shelterAndSupplies, shelterStopsBreathing, scienceNeedsNoPower
    case lightAndPower, instantHarvest, plantsNeedNoPower
    case signalTravelTime, instantRadio, computerHasNoCost
    case unsure

    static func choices(for mission: MissionID) -> [PredictionReason] {
        switch mission {
        case .lightsOut: return [.resourceBudget, .batteryCreatesEnergy, .arraysWorkInShadow]
        case .stormDrill: return [.shelterAndSupplies, .shelterStopsBreathing, .scienceNeedsNoPower]
        case .livingBase: return [.lightAndPower, .instantHarvest, .plantsNeedNoPower]
        case .signalLag: return [.signalTravelTime, .instantRadio, .computerHasNoCost]
        }
    }

    var text: String {
        switch self {
        case .resourceBudget: return "Stored energy and oxygen must cover the crew's needs."
        case .batteryCreatesEnergy: return "Adding a battery makes more electricity."
        case .arraysWorkInShadow: return "Solar arrays keep making electricity in shadow."
        case .shelterAndSupplies: return "The shelter protects the crew, but air and science still use resources."
        case .shelterStopsBreathing: return "The crew stops using oxygen inside the shelter."
        case .scienceNeedsNoPower: return "Science can run without using electricity."
        case .lightAndPower: return "Plants need time and light; the crew also needs supplies."
        case .instantHarvest: return "Switching the lights on makes lettuce ready immediately."
        case .plantsNeedNoPower: return "The greenhouse lights do not use electricity."
        case .signalTravelTime: return "The rover keeps moving while pictures and commands travel."
        case .instantRadio: return "Earth's stop command reaches the rover immediately."
        case .computerHasNoCost: return "The onboard computer takes no cargo space."
        case .unsure: return "I'm not sure of the reason yet."
        }
    }

    /// This checks the proposed mechanism, not whether the player's forecast matched the result.
    var supported: Bool? {
        switch self {
        case .resourceBudget, .shelterAndSupplies, .lightAndPower, .signalTravelTime: return true
        case .unsure: return nil
        default: return false
        }
    }

    var feedback: String {
        switch self {
        case .resourceBudget: return "That is a useful mechanism to check. Compare stored energy, demand and oxygen reserves with what happened."
        case .batteryCreatesEnergy: return "Batteries store energy; they cannot create it. Solar arrays must first supply electricity to charge an empty battery."
        case .arraysWorkInShadow: return "Solar arrays need sunlight. During this shadow drill they supply no electricity, so the base uses stored battery energy."
        case .shelterAndSupplies: return "That mechanism matters. Shelter protection, the crew's oxygen supply and the science power budget are separate needs."
        case .shelterStopsBreathing: return "The crew keeps breathing inside the shelter. NASA crew-demand references still apply throughout the storm."
        case .scienceNeedsNoPower: return "The science instrument uses electricity. Running it leaves less power for other equipment or battery charging."
        case .lightAndPower: return "That mechanism matters. Growth takes time, lights use energy, and the crew keeps using food and oxygen."
        case .instantHarvest: return "Lettuce takes time to grow. The garden drill uses a NASA Veggie growth reference, not instant growth."
        case .plantsNeedNoPower: return "Greenhouse lights use electricity. More lighting can support growth while leaving less energy for other tasks."
        case .signalTravelTime: return "That mechanism matters. Both the picture to Earth and the command back take time; the rover keeps moving."
        case .instantRadio: return "Radio signals travel at the speed of light, but the Earth–Moon distance still creates a delay in each direction."
        case .computerHasNoCost: return "The onboard computer avoids the remote-control delay, but its cargo cost leaves no room for the camera in this drill."
        case .unsure: return "Use the observed result to choose an explanation. You can test another idea without losing progress."
        }
    }
}

extension Prediction {
    func outcome(in d: MissionDefinition) -> String {
        if self == .unsure { return "I'm not sure yet" }
        switch d.missionID {
        case .lightsOut: return self == .yes ? "Power and oxygen goals met" : "Not enough power or oxygen"
        case .livingBase: return self == .yes ? "Crew and harvest succeed" : "A mission goal is missed"
        case .stormDrill:
            if BaseExperiment.isBaseTest(d) { return self == .yes ? "Crew safe, science done" : "A mission goal is missed" }
            return self == .yes ? "Crew sheltered, enough air left" : "A mission goal is missed"
        case .signalLag: return self == .yes ? "Stops in the bay" : "Misses the bay"
        }
    }
}
