import Foundation

enum PadID: Hashable, Sendable {
    case array(Int)
    case battery(Int)
}

enum EnergyFlow: Equatable, Sendable {
    case none
    case solarToBase
    case batteryToBase
}

struct RoverTrackVisual: Equatable, Sendable {
    var markers: [Double]
    var selectedMarker: Double?
    var bayStartM: Double
    var bayEndM: Double
    var lengthM: Double
}

/// A precomputed rover run. The scene only animates it; the engine already decided where the rover stops.
struct RoverRun: Equatable, Sendable {
    var id: Int
    var stopM: Double
    var speed: Double
    var imageAtSecond: Double?
    var oneWaySeconds: Double
    var stopAtSecond: Double
}

enum FloaterAnchor: Equatable, Sendable {
    case arrays
    case batteries
    case habitat
    case greenhouse
    case shelter
}

/// A floating feedback number, such as "+1.4 kWh" above the arrays. Shown once per id.
struct Floater: Equatable, Sendable {
    var id: Int
    var text: String
    var color: UInt32
    var anchor: FloaterAnchor
}

/// A structure the current explanation is about. Drawn as a restrained ring, never the only cue.
enum HighlightTarget: Equatable, Sendable {
    case arrays
    case batteries
    case habitat
    case greenhouse
    case shelter
    case rover
}

enum MarkerState: Equatable, Sendable {
    case next
    case done
    case locked
}

/// A mission pin floating over the part of the base that drill improves.
struct MapMarker: Equatable, Sendable {
    var mission: MissionID
    var symbol: String
    var state: MarkerState
}

/// Immutable description of what the world should show. Built from model state; the renderer owns no
/// authoritative cargo, energy, oxygen, harvest or mission state.
struct WorldSnapshot: Equatable, Sendable {
    var mood: PhaseMood = .sunlit
    var arrays = 0
    var batteries = 0
    var batteryFraction: Double = 0
    var habitatLit = false
    var habitatWarning = false
    var greenhouse = false
    var cropFraction: Double = 0
    var gardenLights = false
    var shelter = false
    var shelterOccupied = false
    var dish = false
    var roverTrack: RoverTrackVisual?
    var roverRun: RoverRun?
    var roverPositionM: Double = 0
    var flow: EnergyFlow = .none
    var padsVisible = false
    var highlightedPads: Set<PadID> = []
    var stormParticles = false
    var floaters: [Floater] = []
    /// Idle life on the home base: the rover patrols. Sky effects run everywhere.
    var ambient = false
    var highlight: HighlightTarget?
    var highlightToken = 0

    static func highlightTarget(for focus: CheckpointFocus) -> HighlightTarget? {
        switch focus {
        case .battery: return .batteries
        case .arrays: return .arrays
        case .air: return .habitat
        case .crop: return .greenhouse
        case .shelter: return .shelter
        case .rover: return .rover
        case .none: return nil
        }
    }
    var markers: [MapMarker] = []

    static func chargeLevel(_ fraction: Double) -> Int {
        guard fraction.isFinite, fraction > 1e-6 else { return 0 }
        return min(5, max(1, Int((fraction * 5).rounded(.up))))
    }
}
