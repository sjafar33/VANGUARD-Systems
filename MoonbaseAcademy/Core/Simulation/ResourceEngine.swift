import Foundation

/// Authoritative, deterministic resource model. Foundation only: no UI, timers, or animation callbacks
/// may decide an outcome. Generation and demand are uniform within each reported step
/// (a phase-averaged training model, not an electrical simulator).
enum ResourceEngine {
    static let tolerance = 1e-9

    static func validateDefinition(_ d: MissionDefinition) -> [ConfigurationIssue] {
        var issues: [ConfigurationIssue] = []
        if d.kind != .resource { issues.append(.wrongMissionKind) }
        if d.phases.isEmpty { issues.append(.invalidDefinition("no phases")) }
        for phase in d.phases {
            let numbers = [phase.durationHours, phase.baseSupplyKW, phase.solarKWPerArray, phase.stepHours ?? 1]
            if !numbers.allSatisfy(\.isFinite) {
                issues.append(.nonFiniteValue)
            } else if phase.durationHours <= 0 || (phase.stepHours ?? 1) <= 0
                        || phase.baseSupplyKW < 0 || phase.solarKWPerArray < 0 {
                issues.append(.invalidDefinition("phase \(phase.id) has a negative or zero value"))
            }
        }
        let initial = d.initial
        let stock = [initial.batteryKWh, initial.baseBatteryCapacityKWh, initial.oxygenKg,
                     initial.oxygenCapacityKg, initial.foodDryKg]
        if !stock.allSatisfy(\.isFinite) {
            issues.append(.nonFiniteValue)
        } else if stock.contains(where: { $0 < 0 }) || initial.crewCount <= 0 {
            issues.append(.invalidDefinition("initial resources"))
        }
        if d.cargoBudget < 0 { issues.append(.invalidDefinition("budget")) }
        return issues
    }

    static func validateConfiguration(mission d: MissionDefinition, configuration c: ResourceConfiguration) -> [ConfigurationIssue] {
        var issues: [ConfigurationIssue] = []
        var cost = 0
        for (rawKind, count) in c.cargo.sorted(by: { $0.key < $1.key }) {
            guard let kind = CargoKind(rawValue: rawKind), let item = d.item(kind) else {
                if count != 0 { issues.append(.itemNotAllowed(rawKind)) }
                continue
            }
            if count < 0 || count > item.maxCount {
                issues.append(.countOutOfRange(kind))
            }
            cost += max(0, count) * item.cost
        }
        if cost > d.cargoBudget {
            issues.append(.overBudget(cost: cost, budget: d.cargoBudget))
        }
        guard c.plans.count == d.phases.count else {
            issues.append(.planCountMismatch(expected: d.phases.count, found: c.plans.count))
            return issues
        }
        for (phase, plan) in zip(d.phases, c.plans) {
            guard plan.airFraction.isFinite, plan.gardenFraction.isFinite, plan.researchLevel.isFinite else {
                issues.append(.nonFiniteValue)
                continue
            }
            if !contains(phase.allowedAirFractions, plan.airFraction) {
                issues.append(.invalidAirFraction(phase: phase.id))
            }
            if phase.allowedGardenFractions.isEmpty {
                if abs(plan.gardenFraction) > tolerance { issues.append(.invalidGardenFraction(phase: phase.id)) }
            } else if !contains(phase.allowedGardenFractions, plan.gardenFraction) {
                issues.append(.invalidGardenFraction(phase: phase.id))
            }
            if let research = phase.research {
                if !contains(research.levels, plan.researchLevel) {
                    issues.append(.unsupportedResearch(phase: phase.id))
                } else if plan.researchLevel > tolerance, let needed = research.requiredItem, c.count(needed) == 0 {
                    issues.append(.researchNeedsItem(phase: phase.id, item: needed))
                }
            } else if abs(plan.researchLevel) > tolerance {
                issues.append(.unsupportedResearch(phase: phase.id))
            }
        }
        return issues
    }

    private static func contains(_ options: [Double], _ value: Double) -> Bool {
        options.contains { abs($0 - value) <= tolerance }
    }

    static func airHours(oxygenKg: Double, crewCount: Int, science: ScienceInputs) -> Double {
        oxygenKg / (Double(crewCount) * science.oxygenKgPerPersonDay) * 24
    }

    static func simulate(definition d: MissionDefinition,
                         configuration c: ResourceConfiguration,
                         science s: ScienceInputs) -> ResourceMissionResult {
        let a = d.assumptions
        var issues = validateDefinition(d)
        if !s.isPhysicallyValid { issues.append(.invalidScience) }
        if issues.isEmpty { issues += validateConfiguration(mission: d, configuration: c) }

        var capacity = d.initial.baseBatteryCapacityKWh
        var energy = d.initial.batteryKWh
        var assemblyKWh = 0.0
        if issues.isEmpty {
            for item in d.catalog {
                let n = Double(c.count(item.kind))
                capacity += n * item.batteryCapacityKWh
                energy += n * item.batteryInitialKWh
                assemblyKWh += n * item.assemblyEnergyKWh
            }
        }
        let initialState = ResourceState(batteryKWh: min(energy, capacity),
                                         batteryCapacityKWh: capacity,
                                         oxygenKg: min(d.initial.oxygenKg, d.initial.oxygenCapacityKg),
                                         oxygenCapacityKg: d.initial.oxygenCapacityKg,
                                         foodDryKg: d.initial.foodDryKg,
                                         cropGrowthDays: 0)
        guard issues.isEmpty else {
            return ResourceMissionResult(definitionID: d.id, configuration: c, issues: issues,
                                         initialState: initialState, finalState: initialState, trace: [],
                                         failure: nil, failedConstraints: [], researchUnits: 0,
                                         observationBadge: false, harvestAchieved: false,
                                         finalAirHours: 0, success: false)
        }

        var state = initialState
        var trace: [ResourceSnapshot] = []
        var failure: FailureEvent?
        var clock = 0.0
        var researchUnits = 0.0
        var observationBadge = false
        let crew = Double(d.initial.crewCount)
        let hasShelter = c.count(.shelterKit) > 0
        let arrays = Double(c.count(.solarArray))
        let noDemand = DemandBreakdown(essentialKW: 0, airKW: 0, gardenKW: 0, researchKW: 0)

        if assemblyKWh > 0 {
            let before = state
            if assemblyKWh > state.batteryKWh + tolerance {
                failure = FailureEvent(constraint: .energyShortage, atHour: 0, phaseID: "assembly",
                                       shortfall: assemblyKWh - state.batteryKWh, deficitKW: 0)
                state.batteryKWh = 0
            } else {
                state.batteryKWh = max(0, state.batteryKWh - assemblyKWh)
            }
            trace.append(ResourceSnapshot(index: trace.count, phaseID: "assembly", phaseIndex: -1,
                                          label: "Building the shelter", mood: .steady, startHour: 0,
                                          plannedHours: 0, elapsedHours: 0, before: before, after: state,
                                          generationKW: 0, demand: noDemand, curtailedKWh: 0,
                                          oxygenGeneratedKg: 0, oxygenConsumedKg: 0, researchKWh: 0,
                                          sheltered: false, failure: failure,
                                          explanations: failure == nil ? [.assembledShelter] : [.energyRanOut]))
        }

        phaseLoop: for (phaseIndex, phase) in d.phases.enumerated() {
            if failure != nil { break }
            let plan = c.plans[phaseIndex]
            if phase.requiresShelter && !hasShelter {
                let event = FailureEvent(constraint: .shelterMissing, atHour: clock, phaseID: phase.id,
                                         shortfall: 0, deficitKW: 0)
                failure = event
                trace.append(ResourceSnapshot(index: trace.count, phaseID: phase.id, phaseIndex: phaseIndex,
                                              label: phase.label, mood: phase.mood, startHour: clock,
                                              plannedHours: phase.durationHours, elapsedHours: 0,
                                              before: state, after: state, generationKW: 0, demand: noDemand,
                                              curtailedKWh: 0, oxygenGeneratedKg: 0, oxygenConsumedKg: 0,
                                              researchKWh: 0, sheltered: false, failure: event,
                                              explanations: [.noShelter]))
                break
            }

            let hasGarden = !phase.allowedGardenFractions.isEmpty
            let lightHours = plan.gardenFraction * a.gardenFullLightHours
            let gardenKW = hasGarden
                ? (s.gardenOperatingPowerKW * lightHours + a.gardenStandbyKW * (24 - lightHours)) / 24
                : 0
            let researchKW = (phase.research?.powerKWPerLevel ?? 0) * plan.researchLevel
            let demand = DemandBreakdown(essentialKW: a.essentialLoadKW,
                                         airKW: a.fullGeneratorKW * plan.airFraction,
                                         gardenKW: gardenKW,
                                         researchKW: researchKW)
            let generationKW = phase.baseSupplyKW + arrays * phase.solarKWPerArray
            let netKW = generationKW - demand.totalKW
            let oxygenInPerHour = a.fullGeneratorKgPerDay * plan.airFraction / 24
            let oxygenOutPerHour = crew * s.oxygenKgPerPersonDay / 24
            let oxygenNetPerHour = oxygenInPerHour - oxygenOutPerHour
            let foodOutPerHour = crew * s.foodDryKgPerPersonDay / 24

            let stepLength = phase.stepHours ?? phase.durationHours
            var remaining = phase.durationHours
            var stepNumber = 0
            var phaseResearchComplete = true

            while remaining > tolerance {
                let dt = min(stepLength, remaining)
                stepNumber += 1
                let before = state

                // First boundary crossing inside this constant-rate step.
                var elapsed = dt
                var event: FailureEvent?
                if netKW < -tolerance {
                    let t = state.batteryKWh / -netKW
                    // Reaching exactly zero at the end of the step is valid; running out earlier is not.
                    if t < dt - tolerance {
                        elapsed = t
                        event = FailureEvent(constraint: .energyShortage, atHour: clock + t, phaseID: phase.id,
                                             shortfall: -netKW * (dt - t), deficitKW: -netKW)
                    }
                }
                if oxygenNetPerHour < -tolerance {
                    let t = state.oxygenKg / -oxygenNetPerHour
                    if t <= dt + tolerance, t < elapsed - tolerance || event == nil {
                        elapsed = min(t, dt)
                        event = FailureEvent(constraint: .oxygenExhausted, atHour: clock + elapsed, phaseID: phase.id,
                                             shortfall: -oxygenNetPerHour * max(0, dt - t), deficitKW: 0)
                    }
                }
                if foodOutPerHour > tolerance {
                    let t = state.foodDryKg / foodOutPerHour
                    if t <= dt + tolerance, t < elapsed - tolerance || event == nil {
                        elapsed = min(t, dt)
                        event = FailureEvent(constraint: .foodExhausted, atHour: clock + elapsed, phaseID: phase.id,
                                             shortfall: foodOutPerHour * max(0, dt - t), deficitKW: 0)
                    }
                }

                let rawEnergy = state.batteryKWh + netKW * elapsed
                let curtailed = max(0, rawEnergy - state.batteryCapacityKWh)
                state.batteryKWh = min(state.batteryCapacityKWh, max(0, rawEnergy))
                let rawOxygen = state.oxygenKg + oxygenNetPerHour * elapsed
                let oxygenFull = rawOxygen >= state.oxygenCapacityKg - tolerance && oxygenNetPerHour > tolerance
                state.oxygenKg = min(state.oxygenCapacityKg, max(0, rawOxygen))
                state.foodDryKg = max(0, state.foodDryKg - foodOutPerHour * elapsed)
                if hasGarden {
                    state.cropGrowthDays += plan.gardenFraction * elapsed / 24
                }
                let researchKWh = researchKW * elapsed
                if case .unitsPerKWh(let rate)? = phase.research?.reward {
                    researchUnits += rate * researchKWh
                }
                if event != nil { phaseResearchComplete = false }

                var codes: [ExplanationCode] = []
                if phase.requiresShelter { codes.append(.shelterOccupied) }
                if netKW > tolerance {
                    codes.append(curtailed > tolerance ? .surplusCurtailed : .solarCharging)
                } else if netKW < -tolerance {
                    codes.append(.batteryBridging)
                } else {
                    codes.append(.supplyCoversDemand)
                }
                if oxygenNetPerHour < -tolerance {
                    codes.append(.oxygenReserveSpent)
                } else if oxygenFull {
                    codes.append(.oxygenTankFull)
                } else if oxygenNetPerHour > tolerance {
                    codes.append(.oxygenRefilling)
                }
                if hasGarden && plan.gardenFraction > tolerance { codes.append(.cropGrowing) }
                if researchKW > tolerance { codes.append(.researchPowered) }
                if let event {
                    switch event.constraint {
                    case .energyShortage: codes.append(.energyRanOut)
                    case .oxygenExhausted: codes.append(.oxygenRanOut)
                    case .foodExhausted: codes.append(.foodRanOut)
                    default: break
                    }
                }

                let label: String
                if phase.stepHours != nil {
                    let day = Int((clock / 24).rounded(.down)) + 1
                    label = "Day \(day)"
                } else {
                    label = phase.label
                }
                trace.append(ResourceSnapshot(index: trace.count, phaseID: phase.id, phaseIndex: phaseIndex,
                                              label: label, mood: phase.mood, startHour: clock,
                                              plannedHours: dt, elapsedHours: elapsed, before: before, after: state,
                                              generationKW: generationKW, demand: demand, curtailedKWh: curtailed,
                                              oxygenGeneratedKg: oxygenInPerHour * elapsed,
                                              oxygenConsumedKg: oxygenOutPerHour * elapsed,
                                              researchKWh: researchKWh, sheltered: phase.requiresShelter,
                                              failure: event, explanations: codes))
                clock += elapsed
                if let event {
                    // A failed attempt stops here. Later generation cannot resurrect it.
                    failure = event
                    break phaseLoop
                }
                remaining -= dt
            }
            if case .observationBadge? = phase.research?.reward,
               plan.researchLevel > tolerance, phaseResearchComplete {
                observationBadge = true
            }
        }

        var failed: [FailedConstraint] = []
        if let failure { failed.append(failure.constraint) }
        let finalAirHours = airHours(oxygenKg: state.oxygenKg, crewCount: d.initial.crewCount, science: s)
        let harvest = d.hasGarden && state.cropGrowthDays >= s.cropReferenceDays - tolerance
        if failure == nil {
            if finalAirHours < d.success.minimumAirHours - tolerance { failed.append(.airReserveBelowMinimum) }
            if d.success.requiresHarvest && !harvest { failed.append(.harvestNotReached) }
        }
        return ResourceMissionResult(definitionID: d.id, configuration: c, issues: [],
                                     initialState: initialState, finalState: state, trace: trace,
                                     failure: failure, failedConstraints: failed,
                                     researchUnits: researchUnits,
                                     observationBadge: observationBadge && failure == nil,
                                     harvestAchieved: harvest && failure == nil,
                                     finalAirHours: finalAirHours,
                                     success: failed.isEmpty)
    }
}

enum RoverEngine {
    static let tolerance = 1e-9

    static func validateConfiguration(mission d: MissionDefinition, configuration c: RoverConfiguration) -> [ConfigurationIssue] {
        var issues: [ConfigurationIssue] = []
        guard d.kind == .rover, let rover = d.rover else { return [.wrongMissionKind] }
        let numbers = [rover.speedMPerSecond, rover.targetBayStartM, rover.targetBayEndM, rover.onboardStopM]
        if !numbers.allSatisfy(\.isFinite) {
            issues.append(.nonFiniteValue)
        } else if rover.speedMPerSecond <= 0 || rover.targetBayEndM < rover.targetBayStartM {
            issues.append(.invalidDefinition("rover"))
        }
        var cost = 0
        for (rawKind, count) in c.cargo.sorted(by: { $0.key < $1.key }) {
            guard let kind = CargoKind(rawValue: rawKind), let item = d.item(kind) else {
                if count != 0 { issues.append(.itemNotAllowed(rawKind)) }
                continue
            }
            if count < 0 || count > item.maxCount { issues.append(.countOutOfRange(kind)) }
            cost += max(0, count) * item.cost
        }
        if cost > d.cargoBudget { issues.append(.overBudget(cost: cost, budget: d.cargoBudget)) }
        switch c.mode {
        case .onboardComputer:
            if c.count(.onboardComputer) == 0 { issues.append(.controlModeNeedsComputer) }
        case .earthControl:
            guard let marker = c.observedMarkerM, marker.isFinite else {
                issues.append(.markerNotOffered)
                break
            }
            if !rover.markerChoicesM.contains(where: { abs($0 - marker) <= tolerance }) {
                issues.append(.markerNotOffered)
            }
        }
        return issues
    }

    /// Earth control: the image of the rover at the chosen marker takes one trip to reach Earth and the brake
    /// command takes one trip back. Exactly two one-way journeys; the rover keeps driving the whole time.
    static func simulate(definition d: MissionDefinition,
                         configuration c: RoverConfiguration,
                         science s: ScienceInputs) -> RoverMissionResult {
        var issues = validateConfiguration(mission: d, configuration: c)
        if !s.isPhysicallyValid { issues.append(.invalidScience) }
        let oneWay = s.isPhysicallyValid ? s.oneWayDelaySeconds : 0
        guard issues.isEmpty, let rover = d.rover else {
            return RoverMissionResult(definitionID: d.id, configuration: c, issues: issues,
                                      oneWayDelaySeconds: oneWay, loopDelaySeconds: 2 * oneWay,
                                      imageTakenAtSecond: 0, commandSentAtSecond: 0, stopAtSecond: 0,
                                      distanceDuringDelayM: 0, finalStopM: 0, outcome: .stoppedShort,
                                      observationEarned: false, success: false)
        }
        let speed = rover.speedMPerSecond
        let imageTaken: Double
        let commandSent: Double
        let stopTime: Double
        let finalStop: Double
        let driftM: Double
        switch c.mode {
        case .earthControl:
            let marker = c.observedMarkerM ?? 0
            imageTaken = marker / speed
            commandSent = imageTaken + oneWay
            stopTime = imageTaken + 2 * oneWay
            driftM = speed * (2 * oneWay)
            finalStop = marker + driftM
        case .onboardComputer:
            imageTaken = rover.onboardStopM / speed
            commandSent = imageTaken
            stopTime = imageTaken
            driftM = 0
            finalStop = rover.onboardStopM
        }
        let outcome: RoverOutcome
        if finalStop < rover.targetBayStartM - tolerance {
            outcome = .stoppedShort
        } else if finalStop > rover.targetBayEndM + tolerance {
            outcome = .overshot
        } else {
            outcome = .inBay
        }
        let success = outcome == .inBay
        return RoverMissionResult(definitionID: d.id, configuration: c, issues: [],
                                  oneWayDelaySeconds: oneWay, loopDelaySeconds: 2 * oneWay,
                                  imageTakenAtSecond: imageTaken, commandSentAtSecond: commandSent,
                                  stopAtSecond: stopTime, distanceDuringDelayM: driftM, finalStopM: finalStop,
                                  outcome: outcome,
                                  observationEarned: success && c.count(.scienceCamera) > 0,
                                  success: success)
    }
}

// Entry points named as in the engineering brief.

func validateConfiguration(mission: MissionDefinition, configuration: ResourceConfiguration) -> [ConfigurationIssue] {
    ResourceEngine.validateDefinition(mission) + ResourceEngine.validateConfiguration(mission: mission, configuration: configuration)
}

func simulateResourceMission(definition: MissionDefinition, configuration: ResourceConfiguration, science: ScienceInputs) -> ResourceMissionResult {
    ResourceEngine.simulate(definition: definition, configuration: configuration, science: science)
}

func simulateRoverMission(definition: MissionDefinition, configuration: RoverConfiguration, science: ScienceInputs) -> RoverMissionResult {
    RoverEngine.simulate(definition: definition, configuration: configuration, science: science)
}
