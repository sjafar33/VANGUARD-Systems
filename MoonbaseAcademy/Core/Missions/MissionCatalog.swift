import Foundation

/// Builds the four training drills. Capacities, rates, budgets and control choices are authored training
/// assumptions. Durations of the storm drill and the garden horizon are derived from the science inputs.
enum MissionCatalog {
    static let airChoices: [Double] = [0, 0.5, 1]

    static func standard(science: ScienceInputs) -> [MissionDefinition] {
        [lightsOut(), livingBase(science: science), stormDrill(science: science), signalLag()]
    }

    static func definition(_ id: MissionID, science: ScienceInputs) -> MissionDefinition {
        switch id {
        case .lightsOut: return lightsOut()
        case .livingBase: return livingBase(science: science)
        case .stormDrill: return stormDrill(science: science)
        case .signalLag: return signalLag()
        }
    }

    /// Explicitly labeled alternative drills. They never replace the standard drill's inputs.
    static func variant(_ id: MissionID, science: ScienceInputs) -> MissionDefinition {
        switch id {
        case .lightsOut: return lightsOut(shadowHours: 9, variant: "nineHourShadow")
        case .livingBase: return livingBase(science: science, dailyEnergyKWh: 16, variant: "tightEnergy")
        case .stormDrill: return stormDrill(science: science, cargoBudget: 3, variant: "smallLander")
        case .signalLag: return signalLag(speed: 0.75, markers: [2.5, 3.5, 4.5], variant: "slowRover")
        }
    }

    static let standardCrew = 2
    static let startingOxygenKg = 3.58
    static let oxygenCapacityKg = 7.16

    static func lightsOut(shadowHours: Double = 6, variant: String? = nil) -> MissionDefinition {
        let sunlitHours = 6.0
        let observation = ResearchOption(levels: [0, 1], powerKWPerLevel: 1.5 / sunlitHours,
                                         requiredItem: nil, reward: .observationBadge)
        return MissionDefinition(
            missionID: .lightsOut,
            variant: variant,
            kind: .resource,
            title: "Lights Out",
            drillLabel: variant == nil ? "Six-hour shadow drill" : "Nine-hour shadow drill",
            cargoBudget: 4,
            catalog: [
                CargoItem(kind: .solarArray, cost: 1, maxCount: 4),
                CargoItem(kind: .battery, cost: 1, maxCount: 4, batteryCapacityKWh: 4, batteryInitialKWh: 0)
            ],
            initial: InitialResources(batteryKWh: 0, baseBatteryCapacityKWh: 0,
                                      oxygenKg: startingOxygenKg, oxygenCapacityKg: oxygenCapacityKg,
                                      foodDryKg: 4.8, crewCount: standardCrew),
            phases: [
                PhaseDefinition(id: "sunlit", label: "Sunlight", durationHours: sunlitHours, stepHours: nil,
                                baseSupplyKW: 0, solarKWPerArray: 1, allowedAirFractions: airChoices,
                                allowedGardenFractions: [], research: observation, requiresShelter: false,
                                mood: .sunlit),
                PhaseDefinition(id: "shadow", label: "Shadow drill", durationHours: shadowHours, stepHours: nil,
                                baseSupplyKW: 0, solarKWPerArray: 0, allowedAirFractions: airChoices,
                                allowedGardenFractions: [], research: nil, requiresShelter: false,
                                mood: .shadow)
            ],
            success: SuccessRule(minimumAirHours: 24, requiresHarvest: false),
            assumptions: .standard,
            rover: nil,
            sourceIDs: ["N1"])
    }

    static func livingBase(science: ScienceInputs, dailyEnergyKWh: Double = 17, variant: String? = nil) -> MissionDefinition {
        let blockHours = science.cropReferenceDays / 3 * 24
        let research = ResearchOption(levels: [0, 1, 2], powerKWPerLevel: 1.0 / 24,
                                      requiredItem: nil, reward: .unitsPerKWh(1))
        let labels = ["Sprouting", "Growing", "Almost ready"]
        let phases = labels.enumerated().map { index, label in
            PhaseDefinition(id: "block\(index + 1)", label: label, durationHours: blockHours, stepHours: 24,
                            baseSupplyKW: dailyEnergyKWh / 24, solarKWPerArray: 0,
                            allowedAirFractions: airChoices, allowedGardenFractions: [0, 0.5, 1],
                            research: research, requiresShelter: false, mood: .steady)
        }
        return MissionDefinition(
            missionID: .livingBase,
            variant: variant,
            kind: .resource,
            title: "The Living Base",
            drillLabel: variant == nil ? "Garden drill" : "Garden drill with less energy",
            cargoBudget: 0,
            catalog: [],
            initial: InitialResources(batteryKWh: 4, baseBatteryCapacityKWh: 8,
                                      oxygenKg: startingOxygenKg, oxygenCapacityKg: oxygenCapacityKg,
                                      foodDryKg: 56, crewCount: standardCrew),
            phases: phases,
            success: SuccessRule(minimumAirHours: 0, requiresHarvest: true),
            assumptions: .standard,
            rover: nil,
            sourceIDs: ["N1", "N2"])
    }

    static func stormDrill(science: ScienceInputs, cargoBudget: Int = 4, variant: String? = nil) -> MissionDefinition {
        let research = ResearchOption(levels: [0, 1], powerKWPerLevel: 0.3,
                                      requiredItem: .scienceKit, reward: .unitsPerKWh(1))
        return MissionDefinition(
            missionID: .stormDrill,
            variant: variant,
            kind: .resource,
            title: "Storm Drill",
            drillLabel: variant == nil ? "Solar storm shelter drill" : "Storm drill with a smaller lander",
            cargoBudget: cargoBudget,
            catalog: [
                CargoItem(kind: .shelterKit, cost: 2, maxCount: 1, assemblyEnergyKWh: 3),
                CargoItem(kind: .chargedBattery, cost: 2, maxCount: 1, batteryCapacityKWh: 4, batteryInitialKWh: 4),
                CargoItem(kind: .scienceKit, cost: 2, maxCount: 1)
            ],
            initial: InitialResources(batteryKWh: 4, baseBatteryCapacityKWh: 8,
                                      oxygenKg: startingOxygenKg, oxygenCapacityKg: oxygenCapacityKg,
                                      foodDryKg: 9.6, crewCount: standardCrew),
            phases: [
                PhaseDefinition(id: "rising", label: "Storm rising", durationHours: science.stormRisingHours,
                                stepHours: nil, baseSupplyKW: 0.8, solarKWPerArray: 0,
                                allowedAirFractions: airChoices, allowedGardenFractions: [],
                                research: research, requiresShelter: true, mood: .storm),
                PhaseDefinition(id: "declining", label: "Storm fading", durationHours: science.stormDecliningHours,
                                stepHours: nil, baseSupplyKW: 0.8, solarKWPerArray: 0,
                                allowedAirFractions: airChoices, allowedGardenFractions: [],
                                research: research, requiresShelter: true, mood: .storm)
            ],
            success: SuccessRule(minimumAirHours: 24, requiresHarvest: false),
            assumptions: .standard,
            rover: nil,
            sourceIDs: ["N1", "N3"])
    }

    static func signalLag(speed: Double = 1, markers: [Double] = [2, 3, 4], variant: String? = nil) -> MissionDefinition {
        MissionDefinition(
            missionID: .signalLag,
            variant: variant,
            kind: .rover,
            title: "Signal Lag",
            drillLabel: variant == nil ? "Remote driving drill" : "Remote driving drill with a slower rover",
            cargoBudget: 2,
            catalog: [
                CargoItem(kind: .onboardComputer, cost: 2, maxCount: 1),
                CargoItem(kind: .scienceCamera, cost: 2, maxCount: 1)
            ],
            initial: InitialResources(batteryKWh: 0, baseBatteryCapacityKWh: 0, oxygenKg: 0,
                                      oxygenCapacityKg: 0, foodDryKg: 0, crewCount: standardCrew),
            phases: [],
            success: SuccessRule(minimumAirHours: 0, requiresHarvest: false),
            assumptions: .standard,
            rover: RoverDefinition(speedMPerSecond: speed, markerChoicesM: markers,
                                   targetBayStartM: 5, targetBayEndM: 6, onboardStopM: 5.5, trackLengthM: 8),
            sourceIDs: ["N4", "S1"])
    }

    /// A sensible starting plan so the first screen is never empty.
    static func defaultConfiguration(for d: MissionDefinition) -> ResourceConfiguration {
        let plans = d.phases.map { phase in
            PhasePlan(airFraction: 1,
                      gardenFraction: phase.allowedGardenFractions.isEmpty ? 0 : 1,
                      researchLevel: 0)
        }
        return ResourceConfiguration(cargo: [:], plans: plans)
    }
}
