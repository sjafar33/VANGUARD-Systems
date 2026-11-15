import Foundation

/// The equipment a base test starts with, counted from the player's real, working buildings.
/// This is the whole bridge between the board and the simulation: two counts, nothing hidden.
struct BaseTestInputs: Codable, Equatable, Sendable {
    var arrays: Int
    var batteries: Int
    /// The level of each counted solar array and battery. Optional so results saved before upgrades
    /// counted still load; missing means every one is level 1.
    var arrayLevels: [Int]?
    var batteryLevels: [Int]?

    var summary: String {
        "\(arrays) solar array\(arrays == 1 ? "" : "s"), \(batteries) batter\(batteries == 1 ? "y" : "ies")"
    }

    /// Average strength of the solar arrays compared with a level 1 array (1 when all are level 1).
    var arrayFactor: Double { Self.average(arrayLevels, count: arrays) }
    /// Average size of the batteries compared with a level 1 battery.
    var batteryFactor: Double { Self.average(batteryLevels, count: batteries) }

    private static func average(_ levels: [Int]?, count: Int) -> Double {
        guard let levels, !levels.isEmpty, count > 0 else { return 1 }
        let used = levels.prefix(count)
        return used.reduce(0) { $0 + BaseExperiment.levelFactor($1) } / Double(used.count)
    }
}

/// A finished "Test My Base" run: what the base had, what the player chose, and what the engine computed.
/// Small on purpose, so two runs can be compared honestly later. Never holds scene nodes or running tasks.
struct BaseTestRecord: Codable, Equatable, Sendable {
    var inputs: BaseTestInputs
    var airSunlight: Double
    var airShadow: Double
    var observation: Bool
    var success: Bool
    var headline: String
    var finalBatteryKWh: Double
    var finalAirHours: Double
    var date: Date
}

/// "Test My Base": a shadow test built from a snapshot of the player's own base.
///
/// It is a separate scenario from the Lights Out reference drill. It reuses that drill's phases and
/// training assumptions and the same `ResourceEngine`, but the equipment is fixed to what the player
/// really built instead of being chosen from a lander. Rules, all stated to the player:
/// - Each working solar array and battery counts once, with the same training numbers as Lights Out.
/// - Building levels, colours, positions and the robot buddy change nothing here.
/// - A damaged building counts for nothing.
/// - The snapshot is taken when the test opens; changing the base later never changes a running test.
enum BaseExperiment {
    static let variantID = "myBase"
    /// Coins for the first passed base test. A game rule. Later passes pay nothing, so it cannot be farmed.
    static let firstPassCoins = 40
    /// The drill world has four array pads and four battery pads, which is also the most a base can hold.
    static let maxPerKind = 4

    static func isBaseTest(_ d: MissionDefinition) -> Bool { d.variant == variantID }

    /// Game rule: how much stronger an upgraded solar array or battery is than a level 1 one.
    /// Level 1 is exactly the Lights Out equipment; level 2 is 1.5 times; level 3 is 2 times.
    /// Other buildings' levels, and every colour and decoration, change nothing.
    static func levelFactor(_ level: Int) -> Double {
        switch level {
        case ...1: return 1
        case 2: return 1.5
        default: return 2
        }
    }

    static func inputs(from base: BaseState) -> BaseTestInputs {
        func levels(_ kind: BuildingKind) -> [Int] {
            Array(base.buildings.filter { $0.kind == kind && $0.isWorking }.map(\.level).sorted(by: >).prefix(maxPerKind))
        }
        let arrays = levels(.solarArray)
        let batteries = levels(.battery)
        return BaseTestInputs(arrays: arrays.count, batteries: batteries.count,
                              arrayLevels: arrays.allSatisfy { $0 <= 1 } ? nil : arrays,
                              batteryLevels: batteries.allSatisfy { $0 <= 1 } ? nil : batteries)
    }

    /// The scenario for these inputs. The reference drill's own definition is never modified:
    /// this starts from a copy and only fixes the equipment.
    static func shadowTest(inputs: BaseTestInputs) -> MissionDefinition {
        var d = MissionCatalog.lightsOut()
        d.variant = variantID
        d.title = "Test My Base"
        d.drillLabel = "Shadow test of your real base"
        d.cargoBudget = max(0, inputs.arrays) + max(0, inputs.batteries)
        d.catalog = d.catalog.map { item in
            var fixed = item
            switch item.kind {
            case .solarArray: fixed.maxCount = max(0, inputs.arrays)
            case .battery: fixed.maxCount = max(0, inputs.batteries)
            default: fixed.maxCount = 0
            }
            // Upgraded batteries hold more. The engine counts identical items, so the base's batteries are
            // entered as that many batteries of their average size: the total is exactly the same.
            if item.kind == .battery { fixed.batteryCapacityKWh = item.batteryCapacityKWh * inputs.batteryFactor }
            return fixed
        }
        // Upgraded solar arrays make more power, entered the same way as an average per array.
        d.phases = d.phases.map { phase in
            var changed = phase
            changed.solarKWPerArray = phase.solarKWPerArray * inputs.arrayFactor
            return changed
        }
        return d
    }

    /// The starting plan: the base's own equipment, with the default air and observation settings.
    static func configuration(for d: MissionDefinition, inputs: BaseTestInputs) -> ResourceConfiguration {
        var c = MissionCatalog.defaultConfiguration(for: d)
        c.setCount(.solarArray, max(0, inputs.arrays))
        c.setCount(.battery, max(0, inputs.batteries))
        return c
    }

    /// One plain sentence saying what changed on the base between two tests.
    static func change(from old: BaseTestInputs, to new: BaseTestInputs) -> String {
        if old == new { return "Same base as last time. Only your plan changed." }
        var parts: [String] = []
        let arrays = new.arrays - old.arrays
        let batteries = new.batteries - old.batteries
        if arrays != 0 { parts.append("\(arrays > 0 ? "+" : "−")\(abs(arrays)) solar array\(abs(arrays) == 1 ? "" : "s")") }
        if batteries != 0 { parts.append("\(batteries > 0 ? "+" : "−")\(abs(batteries)) batter\(abs(batteries) == 1 ? "y" : "ies")") }
        return "You changed your base: \(parts.joined(separator: " and "))."
    }
}
