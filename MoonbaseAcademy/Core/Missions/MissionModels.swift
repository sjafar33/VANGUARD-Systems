import Foundation

enum MissionID: String, Codable, CaseIterable, Sendable, Identifiable {
    case lightsOut
    case livingBase
    case stormDrill
    case signalLag

    var id: String { rawValue }
}

enum MissionKind: String, Codable, Sendable {
    case resource
    case rover
}

enum CargoKind: String, Codable, CaseIterable, Sendable, Hashable {
    case solarArray
    case battery
    case chargedBattery
    case shelterKit
    case scienceKit
    case onboardComputer
    case scienceCamera
}

/// One thing the player can bring. All numbers here are training assumptions.
struct CargoItem: Equatable, Sendable, Identifiable {
    var kind: CargoKind
    var cost: Int
    var maxCount: Int
    var batteryCapacityKWh: Double = 0
    var batteryInitialKWh: Double = 0
    var assemblyEnergyKWh: Double = 0

    var id: CargoKind { kind }
}

enum ResearchReward: Equatable, Sendable {
    /// One badge if the selected observation is fully powered for the phase.
    case observationBadge
    /// Research units earned per supplied kWh.
    case unitsPerKWh(Double)
}

struct ResearchOption: Equatable, Sendable {
    var levels: [Double]
    var powerKWPerLevel: Double
    var requiredItem: CargoKind?
    var reward: ResearchReward
}

enum PhaseMood: String, Sendable {
    case sunlit
    case shadow
    case steady
    case storm
}

struct PhaseDefinition: Equatable, Sendable, Identifiable {
    var id: String
    var label: String
    var durationHours: Double
    /// Length of each reported substep. `nil` reports the phase as a single step.
    var stepHours: Double?
    /// Authored generation that does not depend on player cargo, as a phase-average power.
    var baseSupplyKW: Double
    var solarKWPerArray: Double
    var allowedAirFractions: [Double]
    /// Empty means the mission has no garden.
    var allowedGardenFractions: [Double]
    var research: ResearchOption?
    var requiresShelter: Bool
    var mood: PhaseMood
}

struct InitialResources: Equatable, Sendable {
    var batteryKWh: Double
    var baseBatteryCapacityKWh: Double
    var oxygenKg: Double
    var oxygenCapacityKg: Double
    var foodDryKg: Double
    var crewCount: Int
}

struct SuccessRule: Equatable, Sendable {
    var minimumAirHours: Double
    var requiresHarvest: Bool
    var minimumResearchUnits: Double = 0
}

/// Authored constants shared by the resource drills. None of these is a NASA value or a real hardware specification.
struct TrainingAssumptions: Equatable, Sendable {
    var fullGeneratorKgPerDay: Double = 2.0
    var fullGeneratorKW: Double = 0.5
    var essentialLoadKW: Double = 0.1
    var gardenStandbyKW: Double = 0.01
    var gardenFullLightHours: Double = 16

    static let standard = TrainingAssumptions()
}

struct RoverDefinition: Equatable, Sendable {
    var speedMPerSecond: Double
    var markerChoicesM: [Double]
    var targetBayStartM: Double
    var targetBayEndM: Double
    var onboardStopM: Double
    var trackLengthM: Double
}

struct MissionDefinition: Equatable, Sendable, Identifiable {
    var missionID: MissionID
    /// `nil` is the standard drill. A variant is a separately labeled drill, never a silent change.
    var variant: String?
    var kind: MissionKind
    var title: String
    var drillLabel: String
    var cargoBudget: Int
    var catalog: [CargoItem]
    var initial: InitialResources
    var phases: [PhaseDefinition]
    var success: SuccessRule
    var assumptions: TrainingAssumptions
    var rover: RoverDefinition?
    var sourceIDs: [String]
    var setupLabel: String = "Building the shelter"

    var id: String { variant.map { "\(missionID.rawValue).\($0)" } ?? missionID.rawValue }

    func item(_ kind: CargoKind) -> CargoItem? {
        catalog.first { $0.kind == kind }
    }

    var totalHours: Double { phases.reduce(0) { $0 + $1.durationHours } }
    var hasGarden: Bool { phases.contains { !$0.allowedGardenFractions.isEmpty } }
}

struct PhasePlan: Equatable, Codable, Sendable {
    var airFraction: Double
    var gardenFraction: Double
    var researchLevel: Double

    init(airFraction: Double = 1, gardenFraction: Double = 0, researchLevel: Double = 0) {
        self.airFraction = airFraction
        self.gardenFraction = gardenFraction
        self.researchLevel = researchLevel
    }
}

struct ResourceConfiguration: Equatable, Codable, Sendable {
    var cargo: [String: Int]
    var plans: [PhasePlan]

    init(cargo: [CargoKind: Int] = [:], plans: [PhasePlan]) {
        var raw: [String: Int] = [:]
        for (kind, count) in cargo { raw[kind.rawValue] = count }
        self.cargo = raw
        self.plans = plans
    }

    func count(_ kind: CargoKind) -> Int { cargo[kind.rawValue] ?? 0 }

    mutating func setCount(_ kind: CargoKind, _ count: Int) {
        cargo[kind.rawValue] = count
    }
}

enum ConfigurationIssue: Equatable, Sendable {
    case overBudget(cost: Int, budget: Int)
    case itemNotAllowed(String)
    case countOutOfRange(CargoKind)
    case planCountMismatch(expected: Int, found: Int)
    case invalidAirFraction(phase: String)
    case invalidGardenFraction(phase: String)
    case unsupportedResearch(phase: String)
    case researchNeedsItem(phase: String, item: CargoKind)
    case nonFiniteValue
    case invalidDefinition(String)
    case invalidScience
    case markerNotOffered
    case controlModeNeedsComputer
    case wrongMissionKind

    var childMessage: String {
        switch self {
        case .overBudget(let cost, let budget):
            return "That needs \(cost) cargo points, but the lander only carries \(budget)."
        case .itemNotAllowed, .countOutOfRange:
            return "That part is not available for this drill."
        case .planCountMismatch, .nonFiniteValue, .invalidDefinition, .invalidScience, .wrongMissionKind:
            return "This drill has a setup problem. Please tell a grown-up."
        case .invalidAirFraction, .invalidGardenFraction, .unsupportedResearch:
            return "Pick one of the offered settings."
        case .researchNeedsItem:
            return "Research needs the science kit on board."
        case .markerNotOffered:
            return "Pick one of the marked spots."
        case .controlModeNeedsComputer:
            return "Local stopping needs the onboard computer."
        }
    }
}

enum FailedConstraint: String, Codable, Sendable {
    case energyShortage
    case oxygenExhausted
    case foodExhausted
    case shelterMissing
    case airReserveBelowMinimum
    case harvestNotReached
    case researchGoalNotReached
}

struct ResourceState: Equatable, Codable, Sendable {
    var batteryKWh: Double
    var batteryCapacityKWh: Double
    var oxygenKg: Double
    var oxygenCapacityKg: Double
    var foodDryKg: Double
    var cropGrowthDays: Double
}

struct DemandBreakdown: Equatable, Sendable {
    var essentialKW: Double
    var airKW: Double
    var gardenKW: Double
    var researchKW: Double

    var totalKW: Double { essentialKW + airKW + gardenKW + researchKW }
}

enum ExplanationCode: String, Sendable {
    case assembledShelter
    case solarCharging
    case surplusCurtailed
    case batteryBridging
    case supplyCoversDemand
    case oxygenReserveSpent
    case oxygenTankFull
    case oxygenRefilling
    case cropGrowing
    case researchPowered
    case shelterOccupied
    case energyRanOut
    case oxygenRanOut
    case foodRanOut
    case noShelter
}

struct FailureEvent: Equatable, Sendable {
    var constraint: FailedConstraint
    /// Mission hours from the start of the first phase.
    var atHour: Double
    var phaseID: String
    /// How much more the plan needed to finish this step: kWh for energy, kg for oxygen and food. Never clamped.
    var shortfall: Double
    /// For energy: how far demand exceeded supply, in kW.
    var deficitKW: Double
}

struct ResourceSnapshot: Equatable, Sendable, Identifiable {
    var index: Int
    var phaseID: String
    var phaseIndex: Int
    var label: String
    var mood: PhaseMood
    var startHour: Double
    var plannedHours: Double
    var elapsedHours: Double
    var before: ResourceState
    var after: ResourceState
    var generationKW: Double
    var demand: DemandBreakdown
    var curtailedKWh: Double
    var oxygenGeneratedKg: Double
    var oxygenConsumedKg: Double
    var researchKWh: Double
    var sheltered: Bool
    var failure: FailureEvent?
    var explanations: [ExplanationCode]

    var id: Int { index }
    var endHour: Double { startHour + elapsedHours }
}

struct ResourceMissionResult: Equatable, Sendable {
    var definitionID: String
    var configuration: ResourceConfiguration
    var issues: [ConfigurationIssue]
    var initialState: ResourceState
    var finalState: ResourceState
    var trace: [ResourceSnapshot]
    var failure: FailureEvent?
    var failedConstraints: [FailedConstraint]
    var researchUnits: Double
    var observationBadge: Bool
    var harvestAchieved: Bool
    var finalAirHours: Double
    var success: Bool

    var wasSimulated: Bool { issues.isEmpty }
}

enum RoverControlMode: String, Codable, Sendable {
    case earthControl
    case onboardComputer
}

struct RoverConfiguration: Equatable, Codable, Sendable {
    var mode: RoverControlMode
    var observedMarkerM: Double?
    var cargo: [String: Int]

    init(mode: RoverControlMode, observedMarkerM: Double? = nil, cargo: [CargoKind: Int] = [:]) {
        self.mode = mode
        self.observedMarkerM = observedMarkerM
        var raw: [String: Int] = [:]
        for (kind, count) in cargo { raw[kind.rawValue] = count }
        self.cargo = raw
    }

    func count(_ kind: CargoKind) -> Int { cargo[kind.rawValue] ?? 0 }
}

enum RoverOutcome: String, Codable, Sendable {
    case stoppedShort
    case inBay
    case overshot
}

struct RoverMissionResult: Equatable, Sendable {
    var definitionID: String
    var configuration: RoverConfiguration
    var issues: [ConfigurationIssue]
    var oneWayDelaySeconds: Double
    var loopDelaySeconds: Double
    /// Rover time when the image used for the decision was taken.
    var imageTakenAtSecond: Double
    /// Rover time when that image reached Earth and the command was sent.
    var commandSentAtSecond: Double
    /// Rover time when the brake command arrived (or the onboard computer acted).
    var stopAtSecond: Double
    var distanceDuringDelayM: Double
    var finalStopM: Double
    var outcome: RoverOutcome
    var observationEarned: Bool
    var success: Bool

    var wasSimulated: Bool { issues.isEmpty }
}
