import XCTest
@testable import MoonbaseAcademy

final class PlanningRatesTests: MoonbaseTestCase {
    func testPlanningRatesIncludeScienceAndNASAConsumption() throws {
        var s = try science()
        let d = MissionCatalog.lightsOut()
        var c = ResourceConfiguration(cargo: [.solarArray: 1, .battery: 1], plans: [plan(1), plan(0.5)])
        c.plans[0].researchLevel = 1
        let sunlight = ResourceEngine.rates(definition: d, configuration: c, phaseIndex: 0, science: s)
        XCTAssertEqual(sunlight.demand.totalKW, 0.85, accuracy: 1e-9)
        XCTAssertEqual(sunlight.netKW, 0.15, accuracy: 1e-9)
        let shadow = ResourceEngine.rates(definition: d, configuration: c, phaseIndex: 1, science: s)
        XCTAssertEqual(-shadow.oxygenNetPerHour * 6, 0.1975, accuracy: 1e-9)
        s.oxygenKgPerPersonDay = 1.2
        let changed = ResourceEngine.rates(definition: d, configuration: c, phaseIndex: 1, science: s)
        XCTAssertGreaterThan(-changed.oxygenNetPerHour, -shadow.oxygenNetPerHour)
        let result = ResourceEngine.simulate(definition: d, configuration: c, science: s)
        let step = try XCTUnwrap(result.trace.first { $0.phaseID == "shadow" })
        XCTAssertEqual(step.oxygenConsumedKg, changed.oxygenOutPerHour * step.elapsedHours, accuracy: 1e-9)
    }
}
