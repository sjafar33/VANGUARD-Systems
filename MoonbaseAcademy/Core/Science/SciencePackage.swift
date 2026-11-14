import Foundation

/// How a quantity entered the game. Every scientific or game quantity belongs to exactly one category.
/// `physicalConstant` is a deliberate addition to the brief's three categories so the SI speed of light
/// is not mislabeled as a NASA value.
enum EvidenceCategory: String, Codable, CaseIterable, Sendable {
    case nasaReference
    case derived
    case trainingAssumption
    case physicalConstant

    var childLabel: String {
        switch self {
        case .nasaReference: return "NASA reference"
        case .derived: return "Worked out from references"
        case .trainingAssumption: return "Made up for this training game"
        case .physicalConstant: return "Fixed constant of nature"
        }
    }
}

struct SourceReference: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let agency: String
    let url: String
    let documentID: String?
    let context: String
}

struct ScienceValueRecord: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let value: Double
    let unit: String
    let category: EvidenceCategory
    let sourceID: String?
    let locator: String?
    let formula: String?
    let notes: String
}

struct ScienceEventRecord: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let sourceID: String
    let locator: String
    let thresholdCrossingUTC: String
    let peakUTC: String
    let endUTC: String
    let maxFluxPfu: Double
    let notes: String
}

struct VerificationRecord: Codable, Equatable, Sendable {
    let sourceID: String
    let date: String
    let method: String
    let status: String
}

struct SciencePackage: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let sources: [SourceReference]
    let values: [ScienceValueRecord]
    let events: [ScienceEventRecord]
    let verification: [VerificationRecord]

    static let supportedSchemaVersion = 1
    static let resourceName = "science_package"

    enum LoadError: Error, Equatable {
        case missingResource
        case unreadable(String)
    }

    static func decode(_ data: Data) throws -> SciencePackage {
        do {
            return try JSONDecoder().decode(SciencePackage.self, from: data)
        } catch {
            throw LoadError.unreadable(String(describing: error))
        }
    }

    static func loadBundled(from bundle: Bundle = .main) throws -> SciencePackage {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw LoadError.missingResource
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw LoadError.unreadable(String(describing: error))
        }
        return try decode(data)
    }

    func source(_ id: String?) -> SourceReference? {
        guard let id else { return nil }
        return sources.first { $0.id == id }
    }

    func value(_ id: String) -> ScienceValueRecord? {
        values.first { $0.id == id }
    }
}

/// The reference inputs the simulation actually consumes. Built only by `validateContent(package:)`
/// in production; tests may copy and edit a value to prove the data drives outcomes.
struct ScienceInputs: Equatable, Sendable {
    var oxygenKgPerPersonDay: Double
    var foodDryKgPerPersonDay: Double
    var cropReferenceDays: Double
    var gardenOperatingPowerKW: Double
    var moonDistanceKm: Double
    var lightSpeedKmPerSecond: Double
    var stormThresholdCrossing: Date
    var stormPeak: Date
    var stormEnd: Date

    /// Derived: threshold crossing to peak.
    var stormRisingHours: Double { stormPeak.timeIntervalSince(stormThresholdCrossing) / 3600 }
    /// Derived: peak to the archive's defined end.
    var stormDecliningHours: Double { stormEnd.timeIntervalSince(stormPeak) / 3600 }
    var stormActiveHours: Double { stormRisingHours + stormDecliningHours }
    /// Derived: one trip of a radio signal between Earth and Moon at the average distance.
    var oneWayDelaySeconds: Double { moonDistanceKm / lightSpeedKmPerSecond }
    /// Derived: one image trip plus one command trip.
    var commandLoopDelaySeconds: Double { 2 * oneWayDelaySeconds }

    var isPhysicallyValid: Bool {
        let numbers = [oxygenKgPerPersonDay, foodDryKgPerPersonDay, cropReferenceDays,
                       gardenOperatingPowerKW, moonDistanceKm, lightSpeedKmPerSecond]
        guard numbers.allSatisfy({ $0.isFinite && $0 > 0 }) else { return false }
        return stormThresholdCrossing < stormPeak && stormPeak < stormEnd
    }
}

enum ContentIssue: Equatable, Sendable {
    case unsupportedSchema(Int)
    case duplicateID(String)
    case missingValue(String)
    case missingEvent(String)
    case nonFiniteOrNonPositive(String)
    case wrongUnit(id: String, expected: String, found: String)
    case missingSource(valueID: String)
    case unknownSource(valueID: String, sourceID: String)
    case wrongCategory(id: String)
    case invalidTimestamp(eventID: String, field: String)
    case timestampsOutOfOrder(eventID: String)
    case missingVerification(sourceID: String)

    var message: String {
        switch self {
        case .unsupportedSchema(let v): return "Science data uses schema \(v), which this app cannot read."
        case .duplicateID(let id): return "Science data lists \(id) more than once."
        case .missingValue(let id): return "Required value \(id) is missing."
        case .missingEvent(let id): return "Required event record \(id) is missing."
        case .nonFiniteOrNonPositive(let id): return "Value \(id) is not a usable positive number."
        case .wrongUnit(let id, let expected, let found): return "Value \(id) should be in \(expected) but is in \(found)."
        case .missingSource(let id): return "Value \(id) has no source."
        case .unknownSource(let id, let source): return "Value \(id) names unknown source \(source)."
        case .wrongCategory(let id): return "Value \(id) has an unexpected evidence category."
        case .invalidTimestamp(let id, let field): return "Event \(id) has an unreadable \(field) time."
        case .timestampsOutOfOrder(let id): return "Event \(id) times are not in order."
        case .missingVerification(let source): return "Source \(source) has no verification record."
        }
    }
}

struct ContentValidationResult: Equatable, Sendable {
    let issues: [ContentIssue]
    let inputs: ScienceInputs?
    var isValid: Bool { issues.isEmpty && inputs != nil }
}

enum ScienceKeys {
    static let oxygen = "bvad.oxygenConsumption"
    static let food = "bvad.foodDryMass"
    static let growthDays = "veggie.growthDays"
    static let gardenPower = "veggie.operatingPower"
    static let moonDistance = "moon.averageDistance"
    static let lightSpeed = "si.lightSpeed"
    static let stormEvent = "sep.2017-09-10"

    static let requiredValues: [(id: String, unit: String, category: EvidenceCategory)] = [
        (oxygen, "kg/person/day", .nasaReference),
        (food, "kg/person/day", .nasaReference),
        (growthDays, "day", .nasaReference),
        (gardenPower, "W", .nasaReference),
        (moonDistance, "km", .nasaReference),
        (lightSpeed, "km/s", .physicalConstant)
    ]
}

func parseUTC(_ text: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: text)
}

/// Checks the bundled science package and, only if every mandatory reference is present and well formed,
/// returns the inputs the engines use. A failed check is a visible content error, never a silent default.
func validateContent(package: SciencePackage) -> ContentValidationResult {
    var issues: [ContentIssue] = []
    if package.schemaVersion != SciencePackage.supportedSchemaVersion {
        issues.append(.unsupportedSchema(package.schemaVersion))
    }
    var seen = Set<String>()
    for id in package.sources.map(\.id) + package.values.map(\.id) + package.events.map(\.id) {
        if !seen.insert(id).inserted { issues.append(.duplicateID(id)) }
    }
    let sourceIDs = Set(package.sources.map(\.id))
    var numbers: [String: Double] = [:]
    for required in ScienceKeys.requiredValues {
        guard let record = package.value(required.id) else {
            issues.append(.missingValue(required.id))
            continue
        }
        if !(record.value.isFinite && record.value > 0) {
            issues.append(.nonFiniteOrNonPositive(record.id))
        }
        if record.unit != required.unit {
            issues.append(.wrongUnit(id: record.id, expected: required.unit, found: record.unit))
        }
        if record.category != required.category {
            issues.append(.wrongCategory(id: record.id))
        }
        if let sourceID = record.sourceID {
            if !sourceIDs.contains(sourceID) {
                issues.append(.unknownSource(valueID: record.id, sourceID: sourceID))
            } else if !package.verification.contains(where: { $0.sourceID == sourceID }) {
                issues.append(.missingVerification(sourceID: sourceID))
            }
        } else {
            issues.append(.missingSource(valueID: record.id))
        }
        numbers[required.id] = record.value
    }
    var dates: [Date] = []
    if let event = package.events.first(where: { $0.id == ScienceKeys.stormEvent }) {
        if !sourceIDs.contains(event.sourceID) {
            issues.append(.unknownSource(valueID: event.id, sourceID: event.sourceID))
        }
        let fields = [("thresholdCrossingUTC", event.thresholdCrossingUTC),
                      ("peakUTC", event.peakUTC),
                      ("endUTC", event.endUTC)]
        for (name, text) in fields {
            if let date = parseUTC(text) {
                dates.append(date)
            } else {
                issues.append(.invalidTimestamp(eventID: event.id, field: name))
            }
        }
        if dates.count == 3, !(dates[0] < dates[1] && dates[1] < dates[2]) {
            issues.append(.timestampsOutOfOrder(eventID: event.id))
        }
        if !(event.maxFluxPfu.isFinite && event.maxFluxPfu > 0) {
            issues.append(.nonFiniteOrNonPositive(event.id))
        }
    } else {
        issues.append(.missingEvent(ScienceKeys.stormEvent))
    }
    guard issues.isEmpty, dates.count == 3,
          let oxygen = numbers[ScienceKeys.oxygen],
          let food = numbers[ScienceKeys.food],
          let growth = numbers[ScienceKeys.growthDays],
          let gardenWatts = numbers[ScienceKeys.gardenPower],
          let distance = numbers[ScienceKeys.moonDistance],
          let light = numbers[ScienceKeys.lightSpeed] else {
        return ContentValidationResult(issues: issues, inputs: nil)
    }
    let inputs = ScienceInputs(
        oxygenKgPerPersonDay: oxygen,
        foodDryKgPerPersonDay: food,
        cropReferenceDays: growth,
        gardenOperatingPowerKW: gardenWatts / 1000,
        moonDistanceKm: distance,
        lightSpeedKmPerSecond: light,
        stormThresholdCrossing: dates[0],
        stormPeak: dates[1],
        stormEnd: dates[2])
    return ContentValidationResult(issues: [], inputs: inputs)
}
