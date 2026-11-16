import Foundation

/// Nova's step-by-step goals. There is always exactly one next goal with a concrete "Show me" action,
/// so a child never has to guess what to do. Each goal pays a one-time bonus when it is done.
enum GuideGoal: String, CaseIterable, Codable, Sendable {
    case buildArray
    case buildBattery
    case playLightsOut
    case restoreStation
    case testBase
    case learnPlants
    case buildGreenhouse
    case playLivingBase
    case decorate
    case buildShelter
    case playStorm
    case buildDish
    case playSignal

    static let reward = 25

    var title: String {
        switch self {
        case .buildArray: return "Build a solar array"
        case .buildBattery: return "Build a battery"
        case .playLightsOut: return "Play the Lights Out drill"
        case .restoreStation: return "Fix the old landing station"
        case .testBase: return "Test your real base"
        case .learnPlants: return "Learn \"Plants and Air\""
        case .buildGreenhouse: return "Build the greenhouse"
        case .playLivingBase: return "Play The Living Base drill"
        case .decorate: return "Give your base a new look"
        case .buildShelter: return "Build the storm shelter"
        case .playStorm: return "Play the Storm Drill"
        case .buildDish: return "Build the radio dish"
        case .playSignal: return "Play the Signal Lag drill"
        }
    }

    /// What Nova says. Short, one action, and why.
    var detail: String {
        switch self {
        case .buildArray: return "Let's make power! Tap Show me and I'll help you place a solar array."
        case .buildBattery: return "Solar arrays only work in sunlight. A battery saves energy for the dark. Tap Show me."
        case .playLightsOut: return "Your base has power gear! Now test it in your first drill. Tap Show me."
        case .restoreStation: return "There's an old landing station on the edge of your base. Tap Show me, then fix it up!"
        case .testBase: return "The station works! Now test YOUR base: your own arrays and batteries, in a real shadow. Tap Show me."
        case .learnPlants: return "Next, a quick lesson about plants and air. You'll earn Moon coins and unlock the greenhouse."
        case .buildGreenhouse: return "You unlocked the greenhouse! Tap Show me to build it."
        case .playLivingBase: return "Can you grow lettuce and keep the air flowing? Tap Show me to try."
        case .decorate: return "Make the base yours! Place a flag, a lamp or a rock garden from Build, or pick a new look in Style."
        case .buildShelter: return "A solar storm drill is next. Build a storm shelter first. Tap Show me."
        case .playStorm: return "Keep the crew safe through the storm drill. Tap Show me."
        case .buildDish: return "Time to talk to Earth! Build the radio dish. Tap Show me."
        case .playSignal: return "Drive the rover from Earth, with a signal delay. Tap Show me."
        }
    }

    var symbol: String {
        switch self {
        case .buildArray: return "sun.max.fill"
        case .buildBattery: return "battery.75percent"
        case .playLightsOut, .playLivingBase, .playStorm, .playSignal: return "play.fill"
        case .learnPlants: return "book.fill"
        case .restoreStation: return "wrench.and.screwdriver.fill"
        case .testBase: return "bolt.shield.fill"
        case .buildGreenhouse: return "leaf.fill"
        case .decorate: return "paintpalette.fill"
        case .buildShelter: return "shield.lefthalf.filled"
        case .buildDish: return "antenna.radiowaves.left.and.right"
        }
    }

    func isDone(_ base: BaseState, _ progress: CampaignProgress) -> Bool {
        switch self {
        case .buildArray: return base.count(.solarArray) > 0
        case .buildBattery: return base.count(.battery) > 0
        case .playLightsOut: return progress.isCompleted(.lightsOut)
        // A base with no station (a board too full to place one) is never blocked by these two goals.
        case .restoreStation: return base.landingStation.map(\.isWorking) ?? true
        case .testBase: return base.landingStation == nil || base.baseTests?.isEmpty == false
        case .learnPlants: return base.lessons[LessonLibrary.plantsAndAirID]?.completed == true
        case .buildGreenhouse: return base.count(.greenhouse) > 0
        case .playLivingBase: return progress.isCompleted(.livingBase)
        case .decorate: return base.buildings.contains { $0.kind.isDecoration }
            || base.ownedCosmetics.count > CosmeticCatalog.defaults.count
            || base.habitatColor != "habitat.white" || base.boardTheme != "board.dust" || base.robot != "robot.nova"
        case .buildShelter: return base.count(.shelter) > 0
        case .playStorm: return progress.isCompleted(.stormDrill)
        case .buildDish: return base.count(.dish) > 0
        case .playSignal: return progress.isCompleted(.signalLag)
        }
    }

    /// The first goal not done yet, in order.
    static func current(_ base: BaseState, _ progress: CampaignProgress) -> GuideGoal? {
        allCases.first { !$0.isDone(base, progress) }
    }

    var index: Int { GuideGoal.allCases.firstIndex(of: self) ?? 0 }
}

/// A way to earn coins right now, with what it pays. Used when the player is short of coins.
struct EarnOption: Identifiable, Equatable {
    enum Action: Equatable {
        case lesson(String)
        case drill(MissionID)
    }

    let id: String
    let title: String
    let detail: String
    let coins: Int
    let upTo: Bool
    let action: Action
    let symbol: String
}

enum EarnAdvisor {
    /// Best ways to earn coins now, biggest first. Never empty: a lesson can always be replayed.
    static func options(base: BaseState, progress: CampaignProgress, lessons: [Lesson]) -> [EarnOption] {
        var result: [EarnOption] = []
        for lesson in lessons {
            let record = base.lessons[lesson.id]
            if record?.completed != true {
                result.append(EarnOption(id: "lesson.\(lesson.id)", title: "Learn \"\(lesson.title)\"",
                                         detail: "A short lesson with Nova. Answer right on the first try for the most coins.",
                                         coins: BaseState.lessonCoins(firstTryCorrect: lesson.questionCount, firstCompletion: true),
                                         upTo: true, action: .lesson(lesson.id), symbol: "book.fill"))
            }
        }
        for id in MissionID.allCases where progress.isUnlocked(id) && base.drillReady(id) {
            let title = GameCopy.of(id).title
            if !progress.isCompleted(id) {
                result.append(EarnOption(id: "drill.\(id.rawValue)", title: "Play \(title)",
                                         detail: "Finish it for the first time, and earn more for each star.",
                                         coins: BaseState.drillFirstCoins + 3 * BaseState.drillStarCoins, upTo: true,
                                         action: .drill(id), symbol: "play.fill"))
            } else {
                let missing = max(0, 3 - progress.stars(id))
                let pay = missing * BaseState.drillStarCoins + BaseState.drillReplayCoins
                result.append(EarnOption(id: "drill.\(id.rawValue)", title: "Play \(title) again",
                                         detail: missing > 0 ? "Win the \(missing) star\(missing == 1 ? "" : "s") you haven't got yet. Try predicting the result!" : "Every win pays a little.",
                                         coins: pay, upTo: missing > 0, action: .drill(id), symbol: "arrow.counterclockwise"))
            }
        }
        for lesson in lessons where base.lessons[lesson.id]?.completed == true {
            result.append(EarnOption(id: "lesson.\(lesson.id)", title: "Practise \"\(lesson.title)\" again",
                                     detail: "Every answer right on the first try pays coins.",
                                     coins: BaseState.lessonCoins(firstTryCorrect: lesson.questionCount, firstCompletion: false),
                                     upTo: true, action: .lesson(lesson.id), symbol: "book.fill"))
        }
        return result.sorted { $0.coins > $1.coins }
    }
}
