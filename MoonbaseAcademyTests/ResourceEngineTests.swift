import XCTest
@testable import MoonbaseAcademy

final class LightsOutTests: MoonbaseTestCase {
    private func run(_ d: MissionDefinition = MissionCatalog.lightsOut(), arrays: Int, batteries: Int,
                     airA: Double = 1, airB: Double = 1, observe: Bool = false) throws -> ResourceMissionResult {
        let config = ResourceConfiguration(cargo: [.solarArray: arrays, .battery: batteries],
                                           plans: [plan(airA, research: observe ? 1 : 0), plan(airB)])
        return simulateResourceMission(definition: d, configuration: config, science: try science())
    }

    func testTwoArraysTwoBatteriesSucceeds() throws {
        let r = try run(arrays: 2, batteries: 2, observe: true)
        XCTAssertEqual(r.issues, [])
        XCTAssertEqual(r.trace.count, 2)
        XCTAssertEqual(r.trace[0].after.batteryKWh, 6.9, accuracy: 1e-9)
        XCTAssertEqual(r.finalState.batteryKWh, 3.3, accuracy: 1e-9)
        XCTAssertEqual(r.finalState.oxygenKg, 3.685, accuracy: 1e-9)
        XCTAssertTrue(r.success)
        XCTAssertTrue(r.observationBadge)
        XCTAssertGreaterThanOrEqual(r.finalAirHours, 24)
    }

    func testThreeArraysOneBatteryCapsStorage() throws {
        let r = try run(arrays: 3, batteries: 1, observe: true)
        XCTAssertEqual(r.trace[0].after.batteryKWh, 4, accuracy: 1e-9)
        XCTAssertEqual(r.trace[0].curtailedKWh, 8.9, accuracy: 1e-9)
        XCTAssertTrue(r.trace[0].explanations.contains(.surplusCurtailed))
        XCTAssertEqual(r.finalState.batteryKWh, 0.4, accuracy: 1e-9)
        XCTAssertTrue(r.success)
    }

    func testFourArraysNoBatteryFailsInShadow() throws {
        let r = try run(arrays: 4, batteries: 0)
        XCTAssertEqual(r.trace[0].after.batteryKWh, 0, accuracy: 1e-9)
        XCTAssertEqual(r.trace[0].curtailedKWh, 20.4, accuracy: 1e-9)
        XCTAssertFalse(r.success)
        let failure = try XCTUnwrap(r.failure)
        XCTAssertEqual(failure.constraint, .energyShortage)
        XCTAssertEqual(failure.atHour, 6, accuracy: 1e-9)
        XCTAssertEqual(failure.shortfall, 3.6, accuracy: 1e-9, "the real deficit is reported, not clamped")
        XCTAssertEqual(r.failedConstraints, [.energyShortage])
    }

    func testOneArrayThreeBatteriesSpendsOxygenReserve() throws {
        let r = try run(arrays: 1, batteries: 3, airA: 1, airB: 0, observe: true)
        XCTAssertEqual(r.trace[0].after.batteryKWh, 0.9, accuracy: 1e-9)
        XCTAssertEqual(r.finalState.batteryKWh, 0.3, accuracy: 1e-9)
        XCTAssertEqual(r.finalState.oxygenKg, 3.185, accuracy: 1e-9)
        XCTAssertTrue(r.trace[1].explanations.contains(.oxygenReserveSpent))
        XCTAssertTrue(r.success)
    }

    func testFivePointConfigurationIsRejectedWithoutSimulation() throws {
        let r = try run(arrays: 3, batteries: 2)
        XCTAssertTrue(r.issues.contains(.overBudget(cost: 5, budget: 4)))
        XCTAssertTrue(r.trace.isEmpty)
        XCTAssertEqual(r.finalState, r.initialState)
        XCTAssertFalse(r.success)
        XCTAssertFalse(r.wasSimulated)
    }

    func testExactZeroEnergyAtPhaseEndIsValidButEarlierShortageFails() throws {
        // 1 array, 1 battery, full air: 2.4 kWh stored, shadow demand 0.6 kW.
        let exact = try run(MissionCatalog.lightsOut(shadowHours: 4), arrays: 1, batteries: 1)
        XCTAssertNil(exact.failure)
        XCTAssertEqual(exact.finalState.batteryKWh, 0, accuracy: 1e-9)
        XCTAssertTrue(exact.success)
        let short = try run(MissionCatalog.lightsOut(shadowHours: 4.5), arrays: 1, batteries: 1)
        let failure = try XCTUnwrap(short.failure)
        XCTAssertEqual(failure.atHour, 10, accuracy: 1e-9)
        XCTAssertEqual(failure.shortfall, 0.3, accuracy: 1e-9)
        XCTAssertEqual(failure.deficitKW, 0.6, accuracy: 1e-9)
    }

    func testNineHourVariantIsSeparateAndHarder() throws {
        let variant = MissionCatalog.variant(.lightsOut, science: try science())
        XCTAssertNotEqual(variant.id, MissionCatalog.lightsOut().id)
        XCTAssertEqual(MissionCatalog.lightsOut().phases[1].durationHours, 6)
        let ok = try run(variant, arrays: 2, batteries: 2, observe: true)
        XCTAssertEqual(ok.finalState.batteryKWh, 1.5, accuracy: 1e-9)
        XCTAssertTrue(ok.success)
        let fails = try run(variant, arrays: 3, batteries: 1, observe: true)
        XCTAssertEqual(try XCTUnwrap(fails.failure).atHour, 6 + 4 / 0.6, accuracy: 1e-9)
    }

    func testFailedAttemptIsNotResurrectedByLaterGeneration() throws {
        var d = MissionCatalog.lightsOut()
        var sunrise = d.phases[0]
        sunrise.id = "sunrise"
        sunrise.research = nil
        d.phases.append(sunrise)
        let config = ResourceConfiguration(cargo: [.solarArray: 4], plans: [plan(1), plan(1), plan(1)])
        let r = simulateResourceMission(definition: d, configuration: config, science: try science())
        XCTAssertEqual(r.trace.count, 2, "the third phase must not run")
        XCTAssertEqual(r.failure?.phaseID, "shadow")
        XCTAssertFalse(r.success)
    }

    func testConsumptionScalesWithCrewAndTime() throws {
        let s = try science()
        var d = MissionCatalog.lightsOut()
        let base = try run(d, arrays: 2, batteries: 2)
        XCTAssertEqual(base.trace[0].oxygenConsumedKg, 2 * s.oxygenKgPerPersonDay * 0.25, accuracy: 1e-12)
        XCTAssertEqual(base.initialState.foodDryKg - base.finalState.foodDryKg, 2 * s.foodDryKgPerPersonDay * 0.5, accuracy: 1e-12)
        d.initial.crewCount = 4
        let four = try run(d, arrays: 2, batteries: 2)
        XCTAssertEqual(four.trace[0].oxygenConsumedKg, 2 * base.trace[0].oxygenConsumedKg, accuracy: 1e-12)
        let longer = try run(MissionCatalog.lightsOut(shadowHours: 9), arrays: 2, batteries: 2)
        XCTAssertEqual(longer.trace[1].oxygenConsumedKg, 1.5 * base.trace[1].oxygenConsumedKg, accuracy: 1e-12)
    }

    func testOxygenCapacityBoundary() throws {
        var d = MissionCatalog.lightsOut()
        d.initial.oxygenKg = 7.15
        let r = try run(d, arrays: 2, batteries: 2)
        XCTAssertEqual(r.finalState.oxygenKg, 7.16, accuracy: 1e-9)
        XCTAssertTrue(r.trace[0].explanations.contains(.oxygenTankFull))
    }

    func testOxygenExhaustionFails() throws {
        var d = MissionCatalog.lightsOut()
        d.initial.oxygenKg = 0.5
        let r = try run(d, arrays: 2, batteries: 2, airA: 0, airB: 0)
        let failure = try XCTUnwrap(r.failure)
        XCTAssertEqual(failure.constraint, .oxygenExhausted)
        XCTAssertEqual(failure.atHour, 0.5 / (2 * 0.895) * 24, accuracy: 1e-9)
        XCTAssertEqual(r.finalState.oxygenKg, 0, accuracy: 1e-9)
    }

    func testLowAirReserveIsAFailedConstraintWithoutExhaustion() throws {
        var d = MissionCatalog.lightsOut()
        d.initial.oxygenKg = 2.0
        let r = try run(d, arrays: 1, batteries: 3, airA: 0, airB: 0)
        XCTAssertNil(r.failure)
        XCTAssertEqual(r.failedConstraints, [.airReserveBelowMinimum])
        XCTAssertFalse(r.success)
    }

    func testInvalidInputsAreRejected() throws {
        let s = try science()
        let d = MissionCatalog.lightsOut()
        func issues(_ plans: [PhasePlan], cargo: [CargoKind: Int] = [.solarArray: 1]) -> [ConfigurationIssue] {
            simulateResourceMission(definition: d, configuration: ResourceConfiguration(cargo: cargo, plans: plans), science: s).issues
        }
        XCTAssertTrue(issues([plan(0.3), plan(1)]).contains(.invalidAirFraction(phase: "sunlit")))
        XCTAssertTrue(issues([plan(.nan), plan(1)]).contains(.nonFiniteValue))
        XCTAssertTrue(issues([plan(1), plan(.infinity)]).contains(.nonFiniteValue))
        XCTAssertTrue(issues([plan(1), plan(1, research: 1)]).contains(.unsupportedResearch(phase: "shadow")))
        XCTAssertTrue(issues([plan(1, garden: 0.5), plan(1)]).contains(.invalidGardenFraction(phase: "sunlit")))
        XCTAssertTrue(issues([plan(1)]).contains(.planCountMismatch(expected: 2, found: 1)))
        XCTAssertTrue(issues([plan(1), plan(1)], cargo: [.shelterKit: 1]).contains(.itemNotAllowed("shelterKit")))
        XCTAssertTrue(issues([plan(1), plan(1)], cargo: [.solarArray: -1]).contains(.countOutOfRange(.solarArray)))

        var negative = d
        negative.phases[1].durationHours = -6
        let config = ResourceConfiguration(cargo: [.solarArray: 1], plans: [plan(1), plan(1)])
        XCTAssertFalse(simulateResourceMission(definition: negative, configuration: config, science: s).wasSimulated)
        var infinite = d
        infinite.phases[0].baseSupplyKW = .infinity
        XCTAssertTrue(simulateResourceMission(definition: infinite, configuration: config, science: s).issues.contains(.nonFiniteValue))
        var badScience = s
        badScience.oxygenKgPerPersonDay = .nan
        XCTAssertTrue(simulateResourceMission(definition: d, configuration: config, science: badScience).issues.contains(.invalidScience))
    }

    func testReplayIsDeterministic() throws {
        let first = try run(arrays: 2, batteries: 2, observe: true)
        let second = try run(arrays: 2, batteries: 2, observe: true)
        XCTAssertEqual(first, second)
    }
}

final class LivingBaseTests: MoonbaseTestCase {
    private func run(_ d: MissionDefinition? = nil, air: Double = 1, garden: Double = 1, research: Double = 0,
                     science override: ScienceInputs? = nil) throws -> ResourceMissionResult {
        let s = try science()
        let definition = d ?? MissionCatalog.livingBase(science: s)
        let config = ResourceConfiguration(plans: Array(repeating: plan(air, garden: garden, research: research), count: 3))
        return simulateResourceMission(definition: definition, configuration: config, science: override ?? s)
    }

    func testHorizonDerivesFromCropReference() throws {
        let d = MissionCatalog.livingBase(science: try science())
        XCTAssertEqual(d.totalHours, 33 * 24, accuracy: 1e-9)
        XCTAssertEqual(d.phases.count, 3)
    }

    func testFullAirFullGardenSucceeds() throws {
        let r = try run()
        XCTAssertEqual(r.trace.count, 33)
        XCTAssertEqual(r.trace[0].demand.totalKW * 24, 15.6, accuracy: 1e-9)
        XCTAssertEqual(r.finalState.batteryKWh, 8, accuracy: 1e-9)
        XCTAssertEqual(r.finalState.oxygenKg, 7.16, accuracy: 1e-9)
        XCTAssertEqual(r.finalState.foodDryKg, 3.2, accuracy: 1e-9)
        XCTAssertEqual(r.finalState.cropGrowthDays, 33, accuracy: 1e-9)
        XCTAssertTrue(r.harvestAchieved)
        XCTAssertTrue(r.success)
        XCTAssertEqual(r.trace[32].label, "Day 33")
    }

    func testOneResearchUnitPerDayStillSucceeds() throws {
        let r = try run(research: 1)
        XCTAssertEqual(r.trace[0].demand.totalKW * 24, 16.6, accuracy: 1e-9)
        XCTAssertEqual(r.finalState.batteryKWh, 8, accuracy: 1e-9)
        XCTAssertTrue(r.success)
        XCTAssertEqual(r.researchUnits, 33, accuracy: 1e-9)
    }

    func testTwoResearchUnitsFailDuringDaySeven() throws {
        let r = try run(research: 2)
        XCTAssertEqual(r.trace[0].demand.totalKW * 24, 17.6, accuracy: 1e-9)
        let failure = try XCTUnwrap(r.failure)
        XCTAssertEqual(failure.constraint, .energyShortage)
        XCTAssertEqual(r.trace.last?.label, "Day 7")
        XCTAssertEqual(failure.atHour, 6 * 24 + 16, accuracy: 1e-6)
        XCTAssertFalse(r.success)
        XCTAssertFalse(r.harvestAchieved)
    }

    func testHalfAirRunsOutOfOxygen() throws {
        let r = try run(air: 0.5)
        let failure = try XCTUnwrap(r.failure)
        XCTAssertEqual(failure.constraint, .oxygenExhausted)
        XCTAssertEqual(failure.atHour, 3.58 / 0.79 * 24, accuracy: 1e-6)
        XCTAssertLessThan(r.trace.count, 33)
    }

    func testHalfLightSurvivesButHasNoHarvest() throws {
        let r = try run(garden: 0.5)
        XCTAssertNil(r.failure)
        XCTAssertEqual(r.finalState.cropGrowthDays, 16.5, accuracy: 1e-9)
        XCTAssertFalse(r.harvestAchieved)
        XCTAssertEqual(r.failedConstraints, [.harvestNotReached])
        XCTAssertFalse(r.success)
    }

    func testHarvestIsNeverAddedToPackagedFood() throws {
        let withGarden = try run(garden: 1)
        let withoutGarden = try run(garden: 0)
        XCTAssertEqual(withGarden.finalState.foodDryKg, withoutGarden.finalState.foodDryKg, accuracy: 1e-12)
    }

    func testSensitivityLongerCropReferenceMeansNoHarvestInThe33DayDrill() throws {
        var s = try science()
        let d = MissionCatalog.livingBase(science: s)
        s.cropReferenceDays = 35
        let r = try run(d, science: s)
        XCTAssertEqual(r.finalState.cropGrowthDays, 33, accuracy: 1e-9)
        XCTAssertFalse(r.harvestAchieved)
        XCTAssertFalse(r.success)
    }

    func testTightEnergyVariant() throws {
        let variant = MissionCatalog.variant(.livingBase, science: try science())
        XCTAssertTrue(try run(variant).success)
        let r = try run(variant, research: 1)
        XCTAssertEqual(try XCTUnwrap(r.failure).constraint, .energyShortage)
    }
}

final class StormDrillTests: MoonbaseTestCase {
    private func run(_ d: MissionDefinition? = nil, cargo: [CargoKind: Int], rising: PhasePlan, declining: PhasePlan,
                     science override: ScienceInputs? = nil) throws -> ResourceMissionResult {
        let s = try override ?? science()
        let definition = d ?? MissionCatalog.stormDrill(science: s)
        return simulateResourceMission(definition: definition,
                                       configuration: ResourceConfiguration(cargo: cargo, plans: [rising, declining]),
                                       science: s)
    }

    func testShelterAndBatteryIsSafe() throws {
        let r = try run(cargo: [.shelterKit: 1, .chargedBattery: 1], rising: plan(1), declining: plan(1))
        XCTAssertTrue(r.success)
        XCTAssertEqual(r.initialState.batteryKWh, 8, accuracy: 1e-9)
        XCTAssertEqual(r.trace[0].after.batteryKWh, 5, accuracy: 1e-9, "assembly costs 3 kWh")
        XCTAssertEqual(r.finalState.batteryKWh, 12, accuracy: 1e-9)
        XCTAssertEqual(r.researchUnits, 0)
    }

    func testResearchPlusFullAirFailsAboutTenHoursIn() throws {
        let r = try run(cargo: [.shelterKit: 1, .scienceKit: 1], rising: plan(1, research: 1), declining: plan(1))
        XCTAssertEqual(r.trace[0].after.batteryKWh, 1, accuracy: 1e-9)
        let failure = try XCTUnwrap(r.failure)
        XCTAssertEqual(failure.constraint, .energyShortage)
        XCTAssertEqual(failure.deficitKW, 0.1, accuracy: 1e-9)
        XCTAssertEqual(failure.atHour, 10, accuracy: 1e-6)
    }

    func testReserveTradeOffSucceeds() throws {
        let r = try run(cargo: [.shelterKit: 1, .scienceKit: 1], rising: plan(0, research: 1), declining: plan(1))
        XCTAssertTrue(r.success)
        XCTAssertEqual(r.finalState.oxygenKg, 2.854895833, accuracy: 1e-8)
        XCTAssertEqual(r.finalState.batteryKWh, 8, accuracy: 1e-9)
        XCTAssertEqual(r.researchUnits, 0.3 * 19, accuracy: 1e-9)
    }

    func testHalfAirDuringRisingPhase() throws {
        let r = try run(cargo: [.shelterKit: 1, .scienceKit: 1], rising: plan(0.5, research: 1), declining: plan(1))
        XCTAssertTrue(r.success)
        XCTAssertEqual(r.finalState.oxygenKg, 3.6465625, accuracy: 1e-8)
    }

    func testNoShelterFailsProtectionObjective() throws {
        let r = try run(cargo: [.chargedBattery: 1, .scienceKit: 1], rising: plan(1), declining: plan(1))
        let failure = try XCTUnwrap(r.failure)
        XCTAssertEqual(failure.constraint, .shelterMissing)
        XCTAssertEqual(failure.atHour, 0, accuracy: 1e-12)
        XCTAssertFalse(r.success)
    }

    func testAllThreeItemsExceedCargo() throws {
        let r = try run(cargo: [.shelterKit: 1, .chargedBattery: 1, .scienceKit: 1], rising: plan(1), declining: plan(1))
        XCTAssertTrue(r.issues.contains(.overBudget(cost: 6, budget: 4)))
        XCTAssertTrue(r.trace.isEmpty)
    }

    func testResearchNeedsTheScienceKit() throws {
        let r = try run(cargo: [.shelterKit: 1], rising: plan(1, research: 1), declining: plan(1))
        XCTAssertTrue(r.issues.contains(.researchNeedsItem(phase: "rising", item: .scienceKit)))
    }

    func testSensitivityHigherOxygenUseBreaksTheReservePlan() throws {
        var s = try science()
        s.oxygenKgPerPersonDay = 1.2
        let r = try run(cargo: [.shelterKit: 1, .scienceKit: 1], rising: plan(0, research: 1), declining: plan(1), science: s)
        XCTAssertFalse(r.success)
    }

    func testSensitivityMovingTheArchivedEndChangesDurationAndConsumables() throws {
        let base = try science()
        var moved = base
        moved.stormEnd = base.stormEnd.addingTimeInterval(10 * 3600)
        let d = MissionCatalog.stormDrill(science: moved)
        XCTAssertEqual(d.phases[1].durationHours, base.stormDecliningHours + 10, accuracy: 1e-9)
        let cargo: [CargoKind: Int] = [.shelterKit: 1, .chargedBattery: 1]
        let a = try run(cargo: cargo, rising: plan(1), declining: plan(1))
        let b = try run(cargo: cargo, rising: plan(1), declining: plan(1), science: moved)
        XCTAssertEqual(a.finalState.foodDryKg - b.finalState.foodDryKg, 2 * 0.8 * 10 / 24, accuracy: 1e-9)
    }

    func testSmallLanderVariantKeepsTheEventRecord() throws {
        let s = try science()
        let variant = MissionCatalog.variant(.stormDrill, science: s)
        XCTAssertEqual(variant.totalHours, s.stormActiveHours, accuracy: 1e-9)
        let r = try run(variant, cargo: [.shelterKit: 1, .chargedBattery: 1], rising: plan(1), declining: plan(1))
        XCTAssertTrue(r.issues.contains(.overBudget(cost: 4, budget: 3)))
    }
}
