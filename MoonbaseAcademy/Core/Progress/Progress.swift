import Foundation

struct AttemptRecord: Codable, Equatable, Sendable {
    var missionID: MissionID
    var definitionID: String
    var date: Date
    var success: Bool
    var headline: String
    var finalBatteryKWh: Double?
    var finalAirHours: Double?
    var finalStopM: Double?
    var researchUnits: Double
    var resourceConfiguration: ResourceConfiguration?
    var roverConfiguration: RoverConfiguration?
}

struct CampaignProgress: Codable, Equatable, Sendable {
    var baseName: String = "Moonbase One"
    var completedMissions: [MissionID] = []
    var badges: [String] = []
    var bestResearchUnits: [String: Double] = [:]
    var attempts: [String: [AttemptRecord]] = [:]
    var soundEnabled: Bool = true
    var forceReducedMotion: Bool = false
    /// Cosmetic layout from the first successful power drill. Never applied as a numeric bonus.
    var builtArrays: Int = 0
    var builtBatteries: Int = 0
    /// Background music preference. Optional so older saves still load; missing means on.
    var musicEnabled: Bool?
    /// Best star count per mission (0 to 3). Optional so saves written before stars existed still load.
    var bestStars: [String: Int]?

    func stars(_ id: MissionID) -> Int { bestStars?[id.rawValue] ?? 0 }
    var totalStars: Int { MissionID.allCases.reduce(0) { $0 + stars($1) } }

    /// Keeps the best result only, so replaying cannot farm stars.
    mutating func recordStars(_ id: MissionID, _ count: Int) {
        var all = bestStars ?? [:]
        all[id.rawValue] = max(all[id.rawValue] ?? 0, min(3, max(0, count)))
        bestStars = all
    }

    static let maxAttemptsPerMission = 2

    func isCompleted(_ id: MissionID) -> Bool { completedMissions.contains(id) }

    func isUnlocked(_ id: MissionID) -> Bool {
        guard let index = MissionID.allCases.firstIndex(of: id), index > 0 else { return true }
        return isCompleted(MissionID.allCases[index - 1])
    }

    var nextMission: MissionID? {
        MissionID.allCases.first { !isCompleted($0) }
    }

    func recentAttempts(_ id: MissionID) -> [AttemptRecord] { attempts[id.rawValue] ?? [] }

    /// Records an attempt and awards completion once. Returns true only the first time a mission is completed.
    @discardableResult
    mutating func record(_ attempt: AttemptRecord, badge: String?) -> Bool {
        var list = attempts[attempt.missionID.rawValue] ?? []
        list.append(attempt)
        if list.count > Self.maxAttemptsPerMission {
            list.removeFirst(list.count - Self.maxAttemptsPerMission)
        }
        attempts[attempt.missionID.rawValue] = list
        guard attempt.success else { return false }
        let key = attempt.missionID.rawValue
        bestResearchUnits[key] = max(bestResearchUnits[key] ?? 0, attempt.researchUnits)
        if let badge, !badges.contains(badge) { badges.append(badge) }
        if completedMissions.contains(attempt.missionID) { return false }
        completedMissions.append(attempt.missionID)
        return true
    }
}

struct SaveEnvelope: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    var schemaVersion: Int
    var progress: CampaignProgress
}

enum LoadOutcome: Equatable {
    case fresh
    case loaded(CampaignProgress)
    /// The file could not be read. `preservedAt` is where the original was kept for diagnosis, if that worked.
    case unreadable(reason: String, preservedAt: URL?)
}

struct SaveStore {
    let fileURL: URL

    static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("MoonbaseAcademy", isDirectory: true)
            .appendingPathComponent("save.json")
    }

    init(fileURL: URL = SaveStore.defaultURL()) {
        self.fileURL = fileURL
    }

    func load() -> LoadOutcome {
        let manager = FileManager.default
        guard manager.fileExists(atPath: fileURL.path) else { return .fresh }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(SaveEnvelope.self, from: data)
            guard envelope.schemaVersion == SaveEnvelope.currentSchemaVersion else {
                return .unreadable(reason: "Saved with a different version (\(envelope.schemaVersion)).",
                                   preservedAt: preserveOriginal())
            }
            return .loaded(envelope.progress)
        } catch {
            return .unreadable(reason: "The save file is damaged.", preservedAt: preserveOriginal())
        }
    }

    private func preserveOriginal() -> URL? {
        let backup = fileURL.deletingLastPathComponent().appendingPathComponent("save-unreadable.json")
        let manager = FileManager.default
        try? manager.removeItem(at: backup)
        do {
            try manager.copyItem(at: fileURL, to: backup)
            return backup
        } catch {
            return nil
        }
    }

    func save(_ progress: CampaignProgress) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(SaveEnvelope(schemaVersion: SaveEnvelope.currentSchemaVersion, progress: progress))
        try data.write(to: fileURL, options: .atomic)
    }

    func reset() throws {
        let manager = FileManager.default
        if manager.fileExists(atPath: fileURL.path) {
            try manager.removeItem(at: fileURL)
        }
    }
}
