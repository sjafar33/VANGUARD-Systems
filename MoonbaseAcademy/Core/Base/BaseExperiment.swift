import Foundation

enum BaseTestKind: String, Codable { case shadow, storm }

/// The equipment a base test starts with, counted from the player's real, working buildings.
/// The bridge contains the counted arrays and batteries plus their levels; no other board state feeds the test.
struct BaseTestInputs: Codable, Equatable, Sendable {
    var arrays: Int
    var batteries: Int
    /// The level of each counted solar array and battery. Optional so results saved before upgrades
    /// counted still load; missing means every one is level 1.
    var arrayLevels: [Int]?
    var batteryLevels: [Int]?
    var shelter: Bool? = nil

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
    var elapsedHours: Double? = nil
    var plannedHours: Double? = nil
    var oxygenSpentKg: Double? = nil
    var energySavedKWh: Double? = nil
    var kind: BaseTestKind? = nil
    var eventID: String? = nil
    var scienceEnergyKWh: Double? = nil
    var scienceDeclining: Bool? = nil
    var prediction: Prediction? = nil
    var predictionReason: PredictionReason? = nil
    var predictionQuestion: String? = nil
    var resourceConfiguration: ResourceConfiguration? = nil

    var timeSummary: String {
        guard let elapsedHours, let plannedHours else { return "Time not recorded in this older test" }
        return "Reached \(Format.number(elapsedHours)) of \(Format.number(plannedHours)) hours"
    }
}

enum ExampleBase: String, CaseIterable {
    case starter, moreStorage, moreSunlight

    var title: String {
        switch self {
        case .starter: return "Starter base"
        case .moreStorage: return "Extra battery"
        case .moreSunlight: return "Extra array"
        }
    }

    var inputs: BaseTestInputs {
        BaseTestInputs(arrays: self == .moreSunlight ? 2 : 1,
                       batteries: self == .moreStorage ? 2 : 1)
    }
}

/// "Test My Base": a shadow test built from a snapshot of the player's own base.
///
/// It is a separate scenario from the Lights Out reference drill. It reuses that drill's phases and
/// training assumptions and the same `ResourceEngine`, but the equipment is fixed to what the player
/// really built instead of being chosen from a lander. Rules, all stated to the player:
/// - Each working solar array and battery counts once, with the same training numbers as Lights Out.
/// - Array and battery levels scale their strength by 1 / 1.5 / 2 (game rule).
/// - Other building levels, colours, positions and the robot buddy change nothing here.
/// - A damaged building counts for nothing.
/// - The snapshot is taken when the test opens; changing the base later never changes a running test.
enum BaseExperiment {
    static let variantID = "myBase"
    static let stormVariantID = "myBaseStorm"
    /// Coins for the first passed base test. A game rule. Later passes pay nothing, so it cannot be farmed.
    static let firstPassCoins = 40
    /// The drill world has four array pads and four battery pads, which is also the most a base can hold.
    static let maxPerKind = 4

    static func isBaseTest(_ d: MissionDefinition) -> Bool { d.variant == variantID || d.variant == stormVariantID }

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
                              batteryLevels: batteries.allSatisfy { $0 <= 1 } ? nil : batteries,
                              shelter: base.workingCount(.shelter) > 0 ? true : nil)
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
    static func stormTest(inputs: BaseTestInputs, science: ScienceInputs) -> MissionDefinition {
        var d = MissionCatalog.stormDrill(science: science)
        d.variant = stormVariantID
        d.title = "Storm test"
        d.drillLabel = "Archived storm • \(Words.date(science.stormThresholdCrossing))"
        d.cargoBudget = 0
        d.catalog = [CargoItem(kind: .shelterKit, cost: 0, maxCount: inputs.shelter == true ? 1 : 0, assemblyEnergyKWh: 3),
                     CargoItem(kind: .scienceKit, cost: 0, maxCount: 1)]
        let capacity = Double(inputs.batteries) * inputs.batteryFactor * 4
        d.initial.batteryKWh = capacity
        d.initial.baseBatteryCapacityKWh = capacity
        d.success.minimumResearchUnits = 0.5
        d.setupLabel = "Preparing the shelter"
        return d
    }

    static func configuration(for d: MissionDefinition, inputs: BaseTestInputs) -> ResourceConfiguration {
        var c = MissionCatalog.defaultConfiguration(for: d)
        if d.missionID == .stormDrill {
            c.setCount(.shelterKit, inputs.shelter == true ? 1 : 0)
            c.setCount(.scienceKit, 1)
        } else {
            c.setCount(.solarArray, max(0, inputs.arrays))
            c.setCount(.battery, max(0, inputs.batteries))
        }
        return c
    }

    static func record(inputs: BaseTestInputs, result: ResourceMissionResult,
                       definition: MissionDefinition, headline: String, date: Date = Date(), eventID: String? = nil) -> BaseTestRecord {
        let plans = result.configuration.plans
        var record = BaseTestRecord(inputs: inputs, airSunlight: plans.first?.airFraction ?? 1,
                                    airShadow: plans.last?.airFraction ?? 1,
                                    observation: (plans.first?.researchLevel ?? 0) > 0,
                                    success: result.success, headline: headline,
                                    finalBatteryKWh: result.finalState.batteryKWh,
                                    finalAirHours: result.finalAirHours, date: date)
        record.kind = definition.missionID == .stormDrill ? .storm : .shadow
        record.eventID = eventID
        record.scienceEnergyKWh = result.trace.reduce(0) { $0 + $1.researchKWh }
        record.scienceDeclining = (plans.last?.researchLevel ?? 0) > 0
        record.elapsedHours = result.trace.last?.endHour ?? 0
        record.plannedHours = definition.totalHours
        record.oxygenSpentKg = result.trace.reduce(0) { $0 + max(0, $1.oxygenConsumedKg - $1.oxygenGeneratedKg) }
        record.energySavedKWh = zip(definition.phases, plans).reduce(0) { sum, pair in
            let (phase, plan) = pair
            let hours = result.trace.filter { $0.phaseID == phase.id }.reduce(0) { $0 + $1.elapsedHours }
            return sum + definition.assumptions.fullGeneratorKW * (1 - plan.airFraction) * hours
        }
        return record
    }

    /// One plain sentence saying what changed on the base between two tests.
    static func change(from old: BaseTestInputs, to new: BaseTestInputs) -> String {
        if old == new { return "Same base as last time. Only your plan changed." }
        var parts: [String] = []
        let arrays = new.arrays - old.arrays
        let batteries = new.batteries - old.batteries
        if arrays != 0 { parts.append("\(arrays > 0 ? "+" : "−")\(abs(arrays)) solar array\(abs(arrays) == 1 ? "" : "s")") }
        if batteries != 0 { parts.append("\(batteries > 0 ? "+" : "−")\(abs(batteries)) batter\(abs(batteries) == 1 ? "y" : "ies")") }
        let oldPower = Double(old.arrays) * old.arrayFactor
        let newPower = Double(new.arrays) * new.arrayFactor
        let oldStorage = 4 * Double(old.batteries) * old.batteryFactor
        let newStorage = 4 * Double(new.batteries) * new.batteryFactor
        if arrays == 0, abs(newPower - oldPower) > 1e-9 {
            parts.append("solar power \(Format.number(oldPower)) → \(Format.number(newPower)) kW")
        }
        if batteries == 0, abs(newStorage - oldStorage) > 1e-9 {
            parts.append("battery storage \(Format.number(oldStorage)) → \(Format.number(newStorage)) kWh")
        }
        guard !parts.isEmpty else { return "Your base has the same power and storage as last time." }
        return "You changed your base: \(parts.joined(separator: " and "))."
    }
}
