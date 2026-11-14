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

    static func chargeLevel(_ fraction: Double) -> Int {
        guard fraction.isFinite, fraction > 1e-6 else { return 0 }
        return min(5, max(1, Int((fraction * 5).rounded(.up))))
    }
}
