import Foundation

/// A short interactive lesson: Nova teaches a little, then asks. Facts carry the ID of the bundled NASA
/// source they come from; game rules are labelled as game rules. Numbers are read from the science inputs.
struct Lesson: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let topic: String
    let symbol: String
    /// Building whose blueprint this lesson unlocks, if any.
    let unlocks: BuildingKind?
    let cards: [LessonCard]

    var questionCount: Int { cards.filter { if case .question = $0 { return true } else { return false } }.count }
}

enum LessonCard: Equatable, Sendable {
    case teach(LessonFact)
    case question(LessonQuestion)
}

struct LessonFact: Equatable, Sendable {
    let title: String
    let text: String
    let symbol: String
    /// Source ID from the science package (for example "N2"), or nil for common science.
    var sourceID: String? = nil
    /// True for a rule this game made up for play, shown as "Game rule".
    var isGameRule = false
}

struct LessonQuestion: Equatable, Sendable {
    let prompt: String
    let options: [String]
    let correctIndex: Int
    /// Shown after answering, right or wrong. Never shaming.
    let explanation: String
    var sourceID: String? = nil
}

enum LessonLibrary {
    static let plantsAndAirID = "plantsAndAir"

    static let powerAndBatteriesID = "powerAndBatteries"

    static func all(science s: ScienceInputs) -> [Lesson] { [plantsAndAir(science: s), powerAndBatteries()] }

    /// Power, energy and why a battery is only as useful as the sunshine that fills it. Every number is
    /// read from the Lights Out drill's training assumptions, which are game rules, not NASA data.
    static func powerAndBatteries() -> Lesson {
        let d = MissionCatalog.lightsOut()
        let arrayKW = d.phases.map(\.solarKWPerArray).max() ?? 0
        let batteryKWh = d.item(.battery)?.batteryCapacityKWh ?? 0
        let baseKW = d.assumptions.essentialLoadKW + d.assumptions.fullGeneratorKW
        let shadow = d.phases.last?.durationHours ?? 0
        let needed = baseKW * shadow
        let spare = max(0, arrayKW - baseKW)
        return Lesson(
            id: powerAndBatteriesID,
            title: "Power and Batteries",
            topic: "Power budgeting",
            symbol: "bolt.fill",
            unlocks: nil,
            cards: [
                .teach(LessonFact(title: "Power and energy are different",
                                  text: "Power is how fast energy is being used right now. We measure it in kilowatts (kW). Energy is how much gets used over time, in kilowatt-hours (kWh). Using 1 kW for 1 hour uses 1 kWh.",
                                  symbol: "bolt.badge.clock.fill")),
                .question(LessonQuestion(prompt: "A heater uses 1 kW of power for 3 hours. How much energy is that?",
                                         options: ["1 kWh", "3 kWh", "30 kWh"],
                                         correctIndex: 1,
                                         explanation: "1 kW for 3 hours is 1 times 3, which is 3 kWh. Power times time gives energy.")),
                .teach(LessonFact(title: "Solar arrays need the Sun",
                                  text: "In our game, one solar array makes \(Format.kW(arrayKW)) of power in sunlight. In shadow it makes nothing at all.",
                                  symbol: "sun.max.fill", isGameRule: true)),
                .question(LessonQuestion(prompt: "The base is in shadow. How much power do its solar arrays make?",
                                         options: ["The same as in sunlight", "None", "Twice as much"],
                                         correctIndex: 1,
                                         explanation: "No sunlight, no solar power. That is why a base needs a way to save energy for later.")),
                .teach(LessonFact(title: "Batteries save energy for the dark",
                                  text: "In our game, one battery holds up to \(Words.kWh(batteryKWh)). It starts empty, so the solar arrays have to fill it while the Sun is up.",
                                  symbol: "battery.75percent", isGameRule: true)),
                .question(LessonQuestion(prompt: "In the shadow, our base uses \(Format.kW(baseKW)) for \(Words.hours(shadow)). How much stored energy does it need?",
                                         options: [Words.kWh(baseKW), Words.kWh(needed), Words.kWh(needed * 10)],
                                         correctIndex: 1,
                                         explanation: "\(Format.kW(baseKW)) for \(Words.hours(shadow)) is \(Words.kWh(needed)). If the batteries hold less than that, the lights go out.")),
                .teach(LessonFact(title: "A battery is only as good as its sunshine",
                                  text: "With one solar array, the base itself uses \(Format.kW(baseKW)) of the \(Format.kW(arrayKW)) it makes. Only \(Format.kW(spare)) is left over to charge the battery. A bigger battery does not help if there is nothing extra to put in it.",
                                  symbol: "arrow.triangle.2.circlepath", isGameRule: true)),
                .question(LessonQuestion(prompt: "Your battery is not even full when the shadow starts. You add a second battery, but no more solar arrays. What changes?",
                                         options: ["Twice as much energy is stored", "Nothing: there is no extra energy to fill it", "The shadow gets shorter"],
                                         correctIndex: 1,
                                         explanation: "An empty battery adds no energy. More solar arrays would fill the batteries faster. You can check this yourself with Test My Base!"))
            ])
    }

    static func lesson(_ id: String, science s: ScienceInputs) -> Lesson? { all(science: s).first { $0.id == id } }

    /// Unlocks the greenhouse. Covers what plants need, how much oxygen a crew breathes, how long space lettuce
    /// took, and the energy trade-off the Living Base drill is about.
    static func plantsAndAir(science s: ScienceInputs) -> Lesson {
        let crew = MissionCatalog.standardCrew
        let each = s.oxygenKgPerPersonDay
        let together = each * Double(crew)
        let days = Format.number(s.cropReferenceDays, digits: 0)
        let watts = Format.number(s.gardenOperatingPowerKW * 1000, digits: 0)
        let light = Format.number(TrainingAssumptions.standard.gardenFullLightHours, digits: 0)
        return Lesson(
            id: plantsAndAirID,
            title: "Plants and Air",
            topic: "Food and life support",
            symbol: "leaf.fill",
            unlocks: .greenhouse,
            cards: [
                .teach(LessonFact(title: "Plants make food from light",
                                  text: "Leaves use light, water and carbon dioxide (the gas we breathe out) to make their food. While they do it, they give off oxygen.",
                                  symbol: "sun.max.fill")),
                .question(LessonQuestion(prompt: "What do plants use light for?",
                                         options: ["To stay warm", "To make their food", "To see in the dark"],
                                         correctIndex: 1,
                                         explanation: "Plants turn light, water and carbon dioxide into food. That's why space greenhouses need lamps.")),
                .teach(LessonFact(title: "Astronauts breathe a lot of oxygen",
                                  text: "NASA plans for each astronaut to breathe about \(Format.kg(each, digits: 1)) of oxygen every day. Our base has \(crew) crew members.",
                                  symbol: "wind", sourceID: "N1")),
                .question(LessonQuestion(prompt: "Each of the \(crew) crew members breathes about \(Format.kg(each, digits: 1)) of oxygen a day. About how much do they breathe together?",
                                         options: [Format.kg(each, digits: 1), Format.kg(together, digits: 1), Format.kg(together * 2, digits: 1)],
                                         correctIndex: 1,
                                         explanation: "\(crew) people times \(Format.kg(each, digits: 1)) each is about \(Format.kg(together, digits: 1)) every single day.",
                                         sourceID: "N1")),
                .teach(LessonFact(title: "Lettuce grown in space",
                                  text: "On the International Space Station, NASA's Veggie garden grew lettuce that was ready in about \(days) days. Its lights use about \(watts) watts, a bit like a bright lamp.",
                                  symbol: "leaf.circle.fill", sourceID: "N2")),
                .question(LessonQuestion(prompt: "About how long did lettuce take to grow on the space station?",
                                         options: ["About 3 days", "About \(days) days", "About 300 days"],
                                         correctIndex: 1,
                                         explanation: "About \(days) days. Space lettuce grows at a plant's pace, so the crew has to plan ahead.",
                                         sourceID: "N2")),
                .teach(LessonFact(title: "Every choice costs something",
                                  text: "In our game, the lettuce needs its lights on \(light) hours a day. Energy used by the lights can't also run research or the air maker.",
                                  symbol: "bolt.fill", isGameRule: true)),
                .question(LessonQuestion(prompt: "The base gets the same energy every day. You turn on research too. What happens?",
                                         options: ["Research is free", "Less energy is left for the lights and the air maker", "The battery gets bigger"],
                                         correctIndex: 1,
                                         explanation: "Energy spent on research every day is energy the lights and the air maker can't use. Small extras add up.")),
                .teach(LessonFact(title: "Why bases still need machines for air",
                                  text: "A small greenhouse makes only a little oxygen, far less than a crew breathes. So bases still use machines to make air. Fresh lettuce is a treat, not all the food.",
                                  symbol: "gearshape.2.fill")),
                .question(LessonQuestion(prompt: "Why does our base still need its air maker?",
                                         options: ["Plants don't make any oxygen", "The greenhouse is too small to make enough oxygen", "The air maker grows the lettuce"],
                                         correctIndex: 1,
                                         explanation: "Plants do make oxygen, but a small greenhouse makes far less than \(crew) people breathe."))
            ])
    }
}
