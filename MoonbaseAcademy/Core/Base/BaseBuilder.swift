import Foundation

// MARK: Buildings

/// Things the player can build on the base board. Game rules only: none of these numbers feed the drills'
/// science. Building and upgrading unlock drills, harder drills and new looks.
enum BuildingKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case habitat
    case solarArray
    case battery
    case greenhouse
    case shelter
    case dish
    /// An old landing pad that starts as a ruin. It is repaired, never bought, and it opens "Test My Base".
    case landingStation
    /// Decorations: placed and moved like buildings, but looks only. They change no drill and no test.
    case flag
    case lamp
    case rockGarden

    var id: String { rawValue }

    /// True for things that are only there to make the base the player's own.
    var isDecoration: Bool {
        switch self {
        case .flag, .lamp, .rockGarden: return true
        default: return false
        }
    }

    var name: String {
        switch self {
        case .habitat: return "Habitat"
        case .solarArray: return "Solar array"
        case .battery: return "Battery"
        case .greenhouse: return "Greenhouse"
        case .shelter: return "Storm shelter"
        case .dish: return "Radio dish"
        case .landingStation: return "Landing station"
        case .flag: return "Base flag"
        case .lamp: return "Lamp post"
        case .rockGarden: return "Moon rock garden"
        }
    }

    var symbol: String {
        switch self {
        case .habitat: return "house.fill"
        case .solarArray: return "sun.max.fill"
        case .battery: return "battery.75percent"
        case .greenhouse: return "leaf.fill"
        case .shelter: return "shield.lefthalf.filled"
        case .dish: return "antenna.radiowaves.left.and.right"
        case .landingStation: return "arrow.down.circle.fill"
        case .flag: return "flag.fill"
        case .lamp: return "lightbulb.fill"
        case .rockGarden: return "mountain.2.fill"
        }
    }

    var blurb: String {
        switch self {
        case .habitat: return "Home for the crew. Upgrade it to build more solar arrays and batteries."
        case .solarArray: return "Makes power while the Sun shines."
        case .battery: return "Stores energy for when the Sun is gone."
        case .greenhouse: return "Grows fresh lettuce for the crew."
        case .shelter: return "A safe place to wait out a solar storm."
        case .dish: return "Talks to Mission Control on Earth."
        case .landingStation: return "An old landing pad from an earlier mission. Fix it up to test your real base."
        case .flag: return "Fly your flag so everyone knows whose base this is."
        case .lamp: return "A friendly light for the paths between your buildings."
        case .rockGarden: return "Moon rocks and a glowing crystal the crew collected."
        }
    }

    /// Tiles covered on the board (x by y).
    var footprint: (w: Int, h: Int) {
        switch self {
        case .habitat: return (3, 3)
        case .greenhouse, .shelter, .landingStation: return (2, 2)
        case .solarArray, .battery, .dish, .flag, .lamp, .rockGarden: return (1, 1)
        }
    }

    /// The drill this building helps unlock.
    var drill: MissionID? {
        switch self {
        case .habitat, .landingStation, .flag, .lamp, .rockGarden: return nil
        case .solarArray, .battery: return .lightsOut
        case .greenhouse: return .livingBase
        case .shelter: return .stormDrill
        case .dish: return .signalLag
        }
    }

    static let maxLevel = 3
}

struct PlacedBuilding: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var kind: BuildingKind
    var x: Int
    var y: Int
    var level: Int
    /// True while the building is a ruin that has not been repaired. Optional so older saves still load;
    /// missing means working.
    var damaged: Bool?

    /// A damaged building is only scenery: it gives nothing to any test until it is repaired.
    var isWorking: Bool { damaged != true }

    var footprintTiles: [BoardTile] {
        let size = kind.footprint
        return (0..<size.w).flatMap { dx in (0..<size.h).map { dy in BoardTile(x: x + dx, y: y + dy) } }
    }

    /// Footprint center in grid units, for drawing.
    var centerX: Double { Double(x) + Double(kind.footprint.w) / 2 }
    var centerY: Double { Double(y) + Double(kind.footprint.h) / 2 }
}

struct BoardTile: Hashable, Sendable {
    var x: Int
    var y: Int
}

// MARK: Cosmetics

enum CosmeticKind: String, Codable, Sendable, CaseIterable {
    case habitatColor
    case boardTheme
    case robot

    var title: String {
        switch self {
        case .habitatColor: return "Habitat colour"
        case .boardTheme: return "Base ground"
        case .robot: return "Robot buddy"
        }
    }
}

struct Cosmetic: Identifiable, Equatable, Sendable {
    let id: String
    let kind: CosmeticKind
    let name: String
    let price: Int
    /// Main colour (habitat tint, board colour, or robot shell).
    let color: UInt32
    /// Second colour (robot eyes, board trim).
    let accent: UInt32
}

enum CosmeticCatalog {
    static let all: [Cosmetic] = [
        Cosmetic(id: "habitat.white", kind: .habitatColor, name: "Classic white", price: 0, color: 0xFFFFFF, accent: 0xFFFFFF),
        Cosmetic(id: "habitat.sky", kind: .habitatColor, name: "Sky blue", price: 40, color: 0x7FC8F8, accent: 0x7FC8F8),
        Cosmetic(id: "habitat.mint", kind: .habitatColor, name: "Mint", price: 40, color: 0x8EE3B5, accent: 0x8EE3B5),
        Cosmetic(id: "habitat.peach", kind: .habitatColor, name: "Peach", price: 60, color: 0xFFB38A, accent: 0xFFB38A),
        Cosmetic(id: "habitat.lilac", kind: .habitatColor, name: "Lilac", price: 60, color: 0xC7A6FF, accent: 0xC7A6FF),
        Cosmetic(id: "board.dust", kind: .boardTheme, name: "Moon dust", price: 0, color: 0x9AA2AE, accent: 0xD6DDE5),
        Cosmetic(id: "board.ice", kind: .boardTheme, name: "Ice blue", price: 50, color: 0x86AFC6, accent: 0xDDF3FF),
        Cosmetic(id: "board.sunset", kind: .boardTheme, name: "Sunset", price: 70, color: 0xB98A72, accent: 0xFFD9A8),
        Cosmetic(id: "board.night", kind: .boardTheme, name: "Night glow", price: 90, color: 0x56607A, accent: 0x8BE3EE),
        Cosmetic(id: "robot.nova", kind: .robot, name: "Nova", price: 0, color: 0xFFFFFF, accent: 0x6FE6F2),
        Cosmetic(id: "robot.sprout", kind: .robot, name: "Sprout", price: 50, color: 0xBFF0C8, accent: 0x7EDB6E),
        Cosmetic(id: "robot.comet", kind: .robot, name: "Comet", price: 70, color: 0xFFD3A6, accent: 0xFF9F43),
        Cosmetic(id: "robot.astra", kind: .robot, name: "Astra", price: 90, color: 0xE2D4FF, accent: 0xC77DFF)
    ]

    static func item(_ id: String) -> Cosmetic? { all.first { $0.id == id } }
    static func items(_ kind: CosmeticKind) -> [Cosmetic] { all.filter { $0.kind == kind } }
    static let defaults = ["habitat.white", "board.dust", "robot.nova"]
}

// MARK: Lessons

struct LessonRecord: Codable, Equatable, Sendable {
    var completed = false
    var bestCorrect = 0
    var timesPlayed = 0
}

// MARK: The base

enum BaseActionResult: Equatable {
    case ok
    case notEnoughCoins(needed: Int)
    case blocked
    case limitReached
    case locked(String)
    case maxLevel
}

enum BlueprintStatus: Equatable {
    case available
    case locked(String)
}

/// Everything about the player's base board: coins, buildings, lessons and looks. Saved inside
/// `CampaignProgress` as an optional field, so older saves load and get a starting base built from what
/// they already completed.
struct BaseState: Codable, Equatable, Sendable {
    /// Board tiles run from -6 to 5 on both axes (12 by 12).
    static let minCoord = -6
    static let maxCoord = 5
    static let startingCoins = 150

    var coins: Int
    var buildings: [PlacedBuilding]
    var ownedCosmetics: [String]
    var habitatColor: String
    var boardTheme: String
    var robot: String
    var lessons: [String: LessonRecord]
    /// Guide goals whose bonus has been paid. Optional so earlier base saves still load.
    var claimedGoals: [String]?
    /// The most recent "Test My Base" results, oldest first. Optional so earlier base saves still load.
    var baseTests: [BaseTestRecord]?
    /// True once a base test has passed (its one-time coin reward was paid). Optional for older saves.
    var baseTestPassed: Bool?

    // MARK: Rules (game rules, not science)

    static func buildCost(_ kind: BuildingKind) -> Int {
        switch kind {
        case .habitat, .landingStation: return 0
        case .solarArray, .battery: return 40
        case .greenhouse: return 120
        case .shelter: return 150
        case .dish: return 150
        case .lamp: return 25
        case .flag: return 30
        case .rockGarden: return 35
        }
    }

    /// Cost to go from `level` to `level + 1`, or nil at the top level.
    static func upgradeCost(_ kind: BuildingKind, from level: Int) -> Int? {
        guard level < BuildingKind.maxLevel else { return nil }
        switch kind {
        case .habitat: return level == 1 ? 150 : 300
        case .solarArray, .battery: return level == 1 ? 60 : 100
        case .greenhouse, .shelter, .dish: return level == 1 ? 120 : 200
        case .landingStation, .flag, .lamp, .rockGarden: return nil
        }
    }

    /// What reaching a level gives. Never a change to a drill's science numbers.
    static func levelReward(_ kind: BuildingKind, level: Int) -> String {
        switch (kind, level) {
        case (.habitat, 2): return "Build up to 3 solar arrays and 3 batteries. Adds light pylons and a new module."
        case (.habitat, 3): return "Build up to 4 solar arrays and 4 batteries. Adds a spire, a second module and a hologram ring."
        case (.solarArray, 2): return "Makes 1.5 times the power in Test My Base (game rule). Opens the harder Lights Out drill."
        case (.solarArray, 3): return "Makes 2 times the power in Test My Base (game rule). Becomes a solar tree."
        case (.battery, 2): return "Stores 1.5 times the energy in Test My Base (game rule). Opens the harder Lights Out drill."
        case (.battery, 3): return "Stores 2 times the energy in Test My Base (game rule). Becomes a power core."
        case (_, 2): return kind.drill.map { _ in "Unlocks the harder version of its drill, and adds a tech deck and new equipment." } ?? "A bigger, brighter building."
        case (_, 3): return "The futuristic look: gold deck, glowing core and a hologram ring. Looks only."
        default: return ""
        }
    }

    var habitatLevel: Int { buildings.first { $0.kind == .habitat }?.level ?? 1 }

    func count(_ kind: BuildingKind) -> Int { buildings.filter { $0.kind == kind }.count }

    func maxCount(_ kind: BuildingKind) -> Int {
        switch kind {
        case .solarArray, .battery: return habitatLevel + 1
        case .lamp: return 4
        case .rockGarden: return 3
        case .flag: return 2
        default: return 1
        }
    }

    func blueprint(_ kind: BuildingKind, progress: CampaignProgress) -> BlueprintStatus {
        switch kind {
        case .habitat:
            return .locked("Your base already has its habitat.")
        case .solarArray, .battery, .flag, .lamp, .rockGarden:
            return .available
        case .greenhouse:
            return lessons[LessonLibrary.plantsAndAirID]?.completed == true
                ? .available : .locked("Finish the lesson \"Plants and Air\" to unlock it.")
        case .shelter:
            return progress.isCompleted(.livingBase) ? .available : .locked("Finish The Living Base drill to unlock it.")
        case .dish:
            return progress.isCompleted(.stormDrill) ? .available : .locked("Finish the Storm Drill to unlock it.")
        case .landingStation:
            return .locked("The landing station is already on your base. Tap it to fix it up.")
        }
    }

    /// The base has what a drill needs. (Drills still unlock in order, too.)
    func drillReady(_ id: MissionID) -> Bool {
        switch id {
        case .lightsOut: return count(.solarArray) > 0 && count(.battery) > 0
        case .livingBase: return count(.greenhouse) > 0
        case .stormDrill: return count(.shelter) > 0
        case .signalLag: return count(.dish) > 0
        }
    }

    /// What still needs building for a drill, in words.
    func drillNeeds(_ id: MissionID) -> String? {
        guard !drillReady(id) else { return nil }
        switch id {
        case .lightsOut:
            var missing: [String] = []
            if count(.solarArray) == 0 { missing.append("a solar array") }
            if count(.battery) == 0 { missing.append("a battery") }
            return "Build \(missing.joined(separator: " and "))."
        case .livingBase: return "Build a greenhouse."
        case .stormDrill: return "Build a storm shelter."
        case .signalLag: return "Build a radio dish."
        }
    }

    /// Upgrading a drill's building to level 2 opens its harder version.
    func harderReady(_ id: MissionID) -> Bool {
        buildings.contains { $0.kind.drill == id && $0.level >= 2 }
    }

    // MARK: Board geometry

    func occupied(excluding id: String? = nil) -> Set<BoardTile> {
        Set(buildings.filter { $0.id != id }.flatMap(\.footprintTiles))
    }

    func canPlace(_ kind: BuildingKind, x: Int, y: Int, excluding id: String? = nil) -> Bool {
        let size = kind.footprint
        guard x >= Self.minCoord, y >= Self.minCoord,
              x + size.w - 1 <= Self.maxCoord, y + size.h - 1 <= Self.maxCoord else { return false }
        let taken = occupied(excluding: id)
        let probe = PlacedBuilding(id: "probe", kind: kind, x: x, y: y, level: 1)
        return probe.footprintTiles.allSatisfy { !taken.contains($0) }
    }

    /// The free spot nearest the middle of the board, so placing works without dragging.
    func firstFreeSpot(for kind: BuildingKind, excluding id: String? = nil) -> BoardTile? {
        var spots: [BoardTile] = []
        for x in Self.minCoord...Self.maxCoord {
            for y in Self.minCoord...Self.maxCoord { spots.append(BoardTile(x: x, y: y)) }
        }
        spots.sort { a, b in
            let da = abs(Double(a.x) + 0.5) + abs(Double(a.y) + 0.5)
            let db = abs(Double(b.x) + 0.5) + abs(Double(b.y) + 0.5)
            return da == db ? (a.x, a.y) < (b.x, b.y) : da < db
        }
        return spots.first { canPlace(kind, x: $0.x, y: $0.y, excluding: id) }
    }

    // MARK: Actions

    mutating func build(_ kind: BuildingKind, x: Int, y: Int, progress: CampaignProgress, id: String = UUID().uuidString) -> BaseActionResult {
        if case .locked(let reason) = blueprint(kind, progress: progress) { return .locked(reason) }
        guard count(kind) < maxCount(kind) else { return .limitReached }
        let cost = Self.buildCost(kind)
        guard coins >= cost else { return .notEnoughCoins(needed: cost - coins) }
        guard canPlace(kind, x: x, y: y) else { return .blocked }
        coins -= cost
        buildings.append(PlacedBuilding(id: id, kind: kind, x: x, y: y, level: 1))
        return .ok
    }

    mutating func move(_ id: String, x: Int, y: Int) -> BaseActionResult {
        guard let index = buildings.firstIndex(where: { $0.id == id }) else { return .blocked }
        guard canPlace(buildings[index].kind, x: x, y: y, excluding: id) else { return .blocked }
        buildings[index].x = x
        buildings[index].y = y
        return .ok
    }

    mutating func upgrade(_ id: String) -> BaseActionResult {
        guard let index = buildings.firstIndex(where: { $0.id == id }) else { return .blocked }
        let building = buildings[index]
        guard let cost = Self.upgradeCost(building.kind, from: building.level) else { return .maxLevel }
        guard coins >= cost else { return .notEnoughCoins(needed: cost - coins) }
        coins -= cost
        buildings[index].level += 1
        return .ok
    }

    // MARK: Landing station (game rules)

    /// Coins to repair the landing station. A game rule, not a NASA number.
    static let repairCost = 60
    /// Where the ruin appears when that corner of the board is free.
    static let stationPreferredTile = BoardTile(x: 4, y: 4)

    var landingStation: PlacedBuilding? { buildings.first { $0.kind == .landingStation } }
    var stationRestored: Bool { landingStation?.isWorking == true }

    /// Buildings of a kind that are in working order. Only these count in "Test My Base".
    func workingCount(_ kind: BuildingKind) -> Int { buildings.filter { $0.kind == kind && $0.isWorking }.count }

    /// Puts the ruined landing station on the board once. It never covers another building: it takes the
    /// free spot nearest its corner. Returns true when it was added.
    @discardableResult
    mutating func seedLandingStation() -> Bool {
        guard landingStation == nil else { return false }
        let want = Self.stationPreferredTile
        var spots: [BoardTile] = []
        for x in Self.minCoord...Self.maxCoord {
            for y in Self.minCoord...Self.maxCoord { spots.append(BoardTile(x: x, y: y)) }
        }
        spots.sort { a, b in
            let da = abs(a.x - want.x) + abs(a.y - want.y)
            let db = abs(b.x - want.x) + abs(b.y - want.y)
            return da == db ? (a.x, a.y) < (b.x, b.y) : da < db
        }
        guard let spot = spots.first(where: { canPlace(.landingStation, x: $0.x, y: $0.y) }) else { return false }
        buildings.append(PlacedBuilding(id: "landingStation", kind: .landingStation, x: spot.x, y: spot.y,
                                        level: 1, damaged: true))
        return true
    }

    /// Repairs a damaged building. Charged once: repairing something already fixed costs nothing and
    /// changes nothing, so a double tap or a retry can never charge twice.
    mutating func repair(_ id: String) -> BaseActionResult {
        guard let index = buildings.firstIndex(where: { $0.id == id }) else { return .blocked }
        guard buildings[index].damaged == true else { return .ok }
        guard coins >= Self.repairCost else { return .notEnoughCoins(needed: Self.repairCost - coins) }
        coins -= Self.repairCost
        buildings[index].damaged = nil
        return .ok
    }

    // MARK: Test My Base (game rules around a real simulation)

    /// The base can run its own shadow test: the station is repaired and there is power gear to test.
    var baseTestReady: Bool { baseTestNeeds == nil }

    /// What is still missing before the base can be tested, in words. Nil when it is ready.
    var baseTestNeeds: String? {
        guard let station = landingStation else { return "The landing station is missing from this base." }
        if !station.isWorking { return "Fix the landing station first. Tap it on your base." }
        var missing: [String] = []
        if workingCount(.solarArray) == 0 { missing.append("a solar array") }
        if workingCount(.battery) == 0 { missing.append("a battery") }
        return missing.isEmpty ? nil : "Build \(missing.joined(separator: " and ")) first, so there is something to test."
    }

    static let maxStoredBaseTests = 4

    /// Saves a finished base test. Returns true the first time a test passes; that is the only time it pays.
    /// A failed test costs nothing and never removes or damages a building.
    @discardableResult
    mutating func recordBaseTest(_ record: BaseTestRecord) -> Bool {
        var list = baseTests ?? []
        list.append(record)
        if list.count > Self.maxStoredBaseTests { list.removeFirst(list.count - Self.maxStoredBaseTests) }
        baseTests = list
        guard record.success, baseTestPassed != true else { return false }
        baseTestPassed = true
        coins += BaseExperiment.firstPassCoins
        return true
    }

    mutating func buyCosmetic(_ id: String) -> BaseActionResult {
        guard let item = CosmeticCatalog.item(id) else { return .blocked }
        if ownedCosmetics.contains(id) { return .ok }
        guard coins >= item.price else { return .notEnoughCoins(needed: item.price - coins) }
        coins -= item.price
        ownedCosmetics.append(id)
        return .ok
    }

    mutating func equip(_ id: String) -> Bool {
        guard let item = CosmeticCatalog.item(id), ownedCosmetics.contains(id) else { return false }
        switch item.kind {
        case .habitatColor: habitatColor = id
        case .boardTheme: boardTheme = id
        case .robot: robot = id
        }
        return true
    }

    // MARK: Coins (game rules)

    /// Lessons: 15 coins per question right on the first try and 40 for finishing, the first time.
    /// Replaying pays 5 per first-try answer, so practice still counts.
    static let lessonCoinsPerAnswer = 15
    static let lessonFinishBonus = 40
    static let lessonReplayPerAnswer = 5
    static func lessonCoins(firstTryCorrect: Int, firstCompletion: Bool) -> Int {
        firstCompletion ? firstTryCorrect * lessonCoinsPerAnswer + lessonFinishBonus : firstTryCorrect * lessonReplayPerAnswer
    }

    /// Drills: 80 for the first completion, 25 for each new star, 15 for a later successful run.
    /// A failed run pays nothing but loses nothing.
    static let drillFirstCoins = 80
    static let drillStarCoins = 25
    static let drillReplayCoins = 15
    static func drillCoins(firstCompletion: Bool, newStars: Int, success: Bool) -> Int {
        (firstCompletion ? drillFirstCoins : (success ? drillReplayCoins : 0)) + newStars * drillStarCoins
    }

    mutating func recordLesson(_ id: String, firstTryCorrect: Int) -> Int {
        var record = lessons[id] ?? LessonRecord()
        let first = !record.completed
        record.completed = true
        record.bestCorrect = max(record.bestCorrect, firstTryCorrect)
        record.timesPlayed += 1
        lessons[id] = record
        let earned = Self.lessonCoins(firstTryCorrect: firstTryCorrect, firstCompletion: first)
        coins += earned
        return earned
    }

    // MARK: Starting base

    /// A new player's base: the habitat in the middle and enough coins for a solar array and a battery.
    /// Older saves also get the buildings their completed drills used, plus 20 coins per star already earned.
    static func starting(from progress: CampaignProgress) -> BaseState {
        var state = BaseState(coins: startingCoins + 20 * progress.totalStars,
                              buildings: [PlacedBuilding(id: "habitat", kind: .habitat, x: -2, y: -2, level: 1)],
                              ownedCosmetics: CosmeticCatalog.defaults,
                              habitatColor: "habitat.white", boardTheme: "board.dust", robot: "robot.nova",
                              lessons: [:])
        func add(_ kind: BuildingKind, _ x: Int, _ y: Int) {
            state.buildings.append(PlacedBuilding(id: "\(kind.rawValue).\(x).\(y)", kind: kind, x: x, y: y, level: 1))
        }
        if progress.isCompleted(.lightsOut) {
            for i in 0..<max(1, min(2, progress.builtArrays)) { add(.solarArray, -5, -3 + i) }
            for i in 0..<max(1, min(2, progress.builtBatteries)) { add(.battery, -3 + i, -5) }
        }
        if progress.isCompleted(.livingBase) {
            add(.greenhouse, 2, -2)
            state.lessons[LessonLibrary.plantsAndAirID] = LessonRecord(completed: true, bestCorrect: 0, timesPlayed: 0)
        }
        if progress.isCompleted(.stormDrill) { add(.shelter, -2, 2) }
        if progress.isCompleted(.signalLag) { add(.dish, 2, 2) }
        state.seedLandingStation()
        return state
    }
}
