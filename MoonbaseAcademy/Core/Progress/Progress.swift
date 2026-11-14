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

/// One of the three separate stars a drill can give. Each is earned on its own:
/// finishing the drill, predicting the outcome correctly (pass or fail), and the drill's bonus.
/// Only `completed` unlocks the next drill.
enum Achievement: String, Codable, CaseIterable, Sendable, Hashable {
    case completed
    case predicted
    case bonus
}

/// A saved in-progress plan. Only planning choices are kept; tests are re-run from scratch, so nothing
/// is replayed or awarded twice after the app is closed.
struct MissionDraft: Codable, Equatable, Sendable {
    var missionID: MissionID
    var variant: Bool
    var configuration: ResourceConfiguration?
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
    var musicStyle: MusicStyle?
    /// Best star count per mission (0 to 3). Optional so saves written before stars existed still load.
    var bestStars: [String: Int]?
    /// How the player likes to watch tests. Optional so older saves still load; missing means automatic.
    var playbackMode: PlaybackMode?

    /// Which stars each drill has earned, kept as separate achievements. Optional so older saves still load;
    /// a drill missing here is rebuilt from the older fields by `legacyAchievements`.
    var achievements: [String: [Achievement]]?
    /// Focus & Accessibility preferences. Optional so older saves still load; missing means off (haptics: on).
    var focusView: Bool?
    var readAloud: Bool?
    var hapticsEnabled: Bool?
    /// The plan in progress, so a closed app can reopen at planning. Never holds a running test or a result.
    var draft: MissionDraft?
    /// The base board (coins, buildings, lessons, looks). Optional so older saves load; see `baseState`.
    var base: BaseState?

    /// The saved base, or a starting base built from what this save already completed.
    var baseState: BaseState { base ?? BaseState.starting(from: self) }

    func achievementSet(_ id: MissionID) -> Set<Achievement> {
        if let stored = achievements?[id.rawValue] { return Set(stored) }
        return legacyAchievements(id)
    }

    /// Saves made before separate achievements kept only a best star count, and gave stars only for a
    /// finished drill. Completion and the bonus badge are saved on their own, so the stars can be rebuilt
    /// exactly: completion, the bonus if its badge was earned, and a correct prediction for any star left over.
    /// Nothing is ever taken away: `stars` never reports less than the old count.
    func legacyAchievements(_ id: MissionID) -> Set<Achievement> {
        var set = Set<Achievement>()
        guard completedMissions.contains(id) else { return set }
        set.insert(.completed)
        let legacy = bestStars?[id.rawValue]
        if let badge = MissionCopy.badge(id), badges.contains(badge), legacy == nil || (legacy ?? 0) >= 2 {
            set.insert(.bonus)
        }
        if let legacy, legacy > set.count { set.insert(.predicted) }
        return set
    }

    func stars(_ id: MissionID) -> Int { min(3, max(achievementSet(id).count, bestStars?[id.rawValue] ?? 0)) }
    var totalStars: Int { MissionID.allCases.reduce(0) { $0 + stars($1) } }

    /// Adds newly earned achievements. Earned stars are never removed, so replaying cannot lose them
    /// and cannot farm extra ones either (each achievement counts once).
    mutating func recordAchievements(_ id: MissionID, _ earned: Set<Achievement>) {
        var set = achievementSet(id).union(earned)
        if !completedMissions.contains(id) { set.remove(.completed) }
        var all = achievements ?? [:]
        all[id.rawValue] = Achievement.allCases.filter { set.contains($0) }
        achievements = all
        var best = bestStars ?? [:]
        best[id.rawValue] = max(best[id.rawValue] ?? 0, set.count)
        bestStars = best
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
