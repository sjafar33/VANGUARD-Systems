import XCTest
@testable import MoonbaseAcademy

final class ScienceContentTests: MoonbaseTestCase {
    func testBundledPackageValidatesAndCarriesReferenceValues() throws {
        let package = try bundledPackage()
        let result = validateContent(package: package)
        XCTAssertEqual(result.issues, [])
        let inputs = try XCTUnwrap(result.inputs)
        XCTAssertEqual(inputs.oxygenKgPerPersonDay, 0.895, accuracy: 1e-12)
        XCTAssertEqual(inputs.foodDryKgPerPersonDay, 0.8, accuracy: 1e-12)
        XCTAssertEqual(inputs.cropReferenceDays, 33, accuracy: 1e-12)
        XCTAssertEqual(inputs.gardenOperatingPowerKW, 0.07, accuracy: 1e-12)
        XCTAssertEqual(inputs.moonDistanceKm, 384_400, accuracy: 1e-9)
        XCTAssertEqual(inputs.lightSpeedKmPerSecond, 299_792.458, accuracy: 1e-9)
    }

    func testEveryValueHasUnitProvenanceAndVerification() throws {
        let package = try bundledPackage()
        XCTAssertFalse(package.values.isEmpty)
        for value in package.values {
            XCTAssertFalse(value.unit.isEmpty, value.id)
            XCTAssertFalse(value.notes.isEmpty, value.id)
            let source = try XCTUnwrap(package.source(value.sourceID), "no source for \(value.id)")
            XCTAssertTrue(source.url.hasPrefix("https://"), value.id)
            XCTAssertFalse((value.locator ?? "").isEmpty, value.id)
            XCTAssertTrue(package.verification.contains { $0.sourceID == source.id }, value.id)
            if value.category == .nasaReference {
                XCTAssertEqual(source.agency, "NASA", value.id)
            }
        }
    }

    func testStormDurationsDeriveFromUTCTimestamps() throws {
        let inputs = try science()
        XCTAssertEqual(inputs.stormRisingHours, 19, accuracy: 1e-9)
        XCTAssertEqual(inputs.stormDecliningHours, 79 + 5.0 / 60, accuracy: 1e-9)
        XCTAssertEqual(inputs.stormActiveHours, 98 + 5.0 / 60, accuracy: 1e-9)
    }

    func testDelayIsDistanceOverLightSpeed() throws {
        let inputs = try science()
        XCTAssertEqual(inputs.oneWayDelaySeconds, 1.28222, accuracy: 1e-5)
        XCTAssertEqual(inputs.commandLoopDelaySeconds, 2.56444, accuracy: 1e-5)
        XCTAssertEqual(inputs.commandLoopDelaySeconds, 2 * inputs.moonDistanceKm / inputs.lightSpeedKmPerSecond, accuracy: 1e-12)
    }

    private func replacing(_ package: SciencePackage, values: [ScienceValueRecord]? = nil,
                           events: [ScienceEventRecord]? = nil, sources: [SourceReference]? = nil,
                           schema: Int? = nil) -> SciencePackage {
        SciencePackage(schemaVersion: schema ?? package.schemaVersion,
                       sources: sources ?? package.sources,
                       values: values ?? package.values,
                       events: events ?? package.events,
                       verification: package.verification)
    }

    func testMissingRequiredValueFailsValidation() throws {
        let package = try bundledPackage()
        let broken = replacing(package, values: package.values.filter { $0.id != ScienceKeys.oxygen })
        let result = validateContent(package: broken)
        XCTAssertNil(result.inputs)
        XCTAssertTrue(result.issues.contains(.missingValue(ScienceKeys.oxygen)))
        XCTAssertFalse(result.isValid)
    }

    func testWrongUnitNonPositiveAndUnknownSourceFailValidation() throws {
        let package = try bundledPackage()
        let edited = package.values.map { record -> ScienceValueRecord in
            switch record.id {
            case ScienceKeys.moonDistance:
                return ScienceValueRecord(id: record.id, label: record.label, value: record.value, unit: "miles",
                                          category: record.category, sourceID: record.sourceID, locator: record.locator,
                                          formula: record.formula, notes: record.notes)
            case ScienceKeys.food:
                return ScienceValueRecord(id: record.id, label: record.label, value: -1, unit: record.unit,
                                          category: record.category, sourceID: record.sourceID, locator: record.locator,
                                          formula: record.formula, notes: record.notes)
            case ScienceKeys.growthDays:
                return ScienceValueRecord(id: record.id, label: record.label, value: record.value, unit: record.unit,
                                          category: record.category, sourceID: "N99", locator: record.locator,
                                          formula: record.formula, notes: record.notes)
            default:
                return record
            }
        }
        let result = validateContent(package: replacing(package, values: edited))
        XCTAssertNil(result.inputs)
        XCTAssertTrue(result.issues.contains(.wrongUnit(id: ScienceKeys.moonDistance, expected: "km", found: "miles")))
        XCTAssertTrue(result.issues.contains(.nonFiniteOrNonPositive(ScienceKeys.food)))
        XCTAssertTrue(result.issues.contains(.unknownSource(valueID: ScienceKeys.growthDays, sourceID: "N99")))
    }

    func testBadTimestampsAndMissingEventFailValidation() throws {
        let package = try bundledPackage()
        let event = try XCTUnwrap(package.events.first)
        let unreadable = ScienceEventRecord(id: event.id, label: event.label, sourceID: event.sourceID,
                                            locator: event.locator, thresholdCrossingUTC: "yesterday",
                                            peakUTC: event.peakUTC, endUTC: event.endUTC,
                                            maxFluxPfu: event.maxFluxPfu, notes: event.notes)
        XCTAssertTrue(validateContent(package: replacing(package, events: [unreadable])).issues
            .contains(.invalidTimestamp(eventID: event.id, field: "thresholdCrossingUTC")))
        let reversed = ScienceEventRecord(id: event.id, label: event.label, sourceID: event.sourceID,
                                          locator: event.locator, thresholdCrossingUTC: event.endUTC,
                                          peakUTC: event.peakUTC, endUTC: event.thresholdCrossingUTC,
                                          maxFluxPfu: event.maxFluxPfu, notes: event.notes)
        XCTAssertTrue(validateContent(package: replacing(package, events: [reversed])).issues
            .contains(.timestampsOutOfOrder(eventID: event.id)))
        let none = validateContent(package: replacing(package, events: []))
        XCTAssertTrue(none.issues.contains(.missingEvent(ScienceKeys.stormEvent)))
        XCTAssertNil(none.inputs)
        XCTAssertFalse(validateContent(package: replacing(package, schema: 99)).isValid)
    }

    func testUndecodableDataIsAnErrorNotADefault() {
        XCTAssertThrowsError(try SciencePackage.decode(Data("{\"schemaVersion\":1}".utf8)))
    }
}
