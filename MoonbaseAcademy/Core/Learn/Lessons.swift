import Foundation

/// How much help and how much maths a lesson's questions use. The facts, the sources and the numbers
/// are the same at every level; only the questions change. It is a free choice, never an age gate.
enum LearnLevel: String, Codable, CaseIterable, Sendable, Identifiable {
    case explorer
    case builder
    case engineer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .explorer: return "Explorer"
        case .builder: return "Builder"
        case .engineer: return "Mission Engineer"
        }
    }

    var blurb: String {
        switch self {
        case .explorer: return "Short questions with two choices."
        case .builder: return "Three choices and simple numbers."
        case .engineer: return "Work it out: sums, reasons and trade-offs."
        }
    }

    var symbol: String {
        switch self {
        case .explorer: return "binoculars.fill"
        case .builder: return "hammer.fill"
        case .engineer: return "gearshape.2.fill"
        }
    }
}

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
    var level: LearnLevel = .builder

    /// The same question with its choices in a new order, so the right answer is not always in one place.
    func shuffled() -> LessonQuestion {
        guard options.indices.contains(correctIndex) else { return self }
        let correct = options[correctIndex]
        let mixed = options.shuffled()
        return LessonQuestion(prompt: prompt, options: mixed, correctIndex: mixed.firstIndex(of: correct) ?? 0,
                              explanation: explanation, sourceID: sourceID, level: level)
    }
}

/// One idea in a lesson: a fact, and a pool of questions about it at every level. Each time the lesson
/// is played, one question at the chosen level is picked, so replays are not always the same.
struct LessonTopic: Equatable, Sendable {
    let fact: LessonFact
    let questions: [LessonQuestion]
}

enum LessonLibrary {
    static let plantsAndAirID = "plantsAndAir"
    static let powerAndBatteriesID = "powerAndBatteries"

    static func all(science s: ScienceInputs, level: LearnLevel = .builder) -> [Lesson] {
        [plantsAndAir(science: s, level: level), powerAndBatteries(level: level)]
    }

    static func lesson(_ id: String, science s: ScienceInputs, level: LearnLevel = .builder) -> Lesson? {
        all(science: s, level: level).first { $0.id == id }
    }

    /// Builds the cards: every fact, each followed by one question picked from its pool for this level.
    static func cards(_ topics: [LessonTopic], level: LearnLevel) -> [LessonCard] {
        var cards: [LessonCard] = []
        for topic in topics {
            cards.append(.teach(topic.fact))
            let pool = topic.questions.filter { $0.level == level }
            if let pick = (pool.isEmpty ? topic.questions : pool).randomElement() {
                cards.append(.question(pick.shuffled()))
            }
        }
        return cards
    }

    private static func ask(_ level: LearnLevel, _ prompt: String, _ options: [String], _ correct: Int,
                            _ explanation: String, source: String? = nil) -> LessonQuestion {
        LessonQuestion(prompt: prompt, options: options, correctIndex: correct, explanation: explanation,
                       sourceID: source, level: level)
    }

    // MARK: Plants and Air

    /// Unlocks the greenhouse. Covers what plants need, how much oxygen a crew breathes, how long space lettuce
    /// took, and the energy trade-off the Living Base drill is about.
    static func plantsAndAir(science s: ScienceInputs, level: LearnLevel = .builder) -> Lesson {
        Lesson(id: plantsAndAirID, title: "Plants and Air", topic: "Food and life support", symbol: "leaf.fill",
               unlocks: .greenhouse, cards: cards(plantsTopics(science: s), level: level))
    }

    static func plantsTopics(science s: ScienceInputs) -> [LessonTopic] {
        let crew = MissionCatalog.standardCrew
        let each = s.oxygenKgPerPersonDay
        let together = each * Double(crew)
        let dayCount = s.cropReferenceDays
        let days = Format.number(dayCount, digits: 0)
        let wattCount = s.gardenOperatingPowerKW * 1000
        let watts = Format.number(wattCount, digits: 0)
        let tenHours = s.gardenOperatingPowerKW * 10
        let light = Format.number(TrainingAssumptions.standard.gardenFullLightHours, digits: 0)
        let eachText = Format.kg(each, digits: 1)
        let togetherText = Format.kg(together, digits: 1)
        return [
            LessonTopic(
                fact: LessonFact(title: "Plants make food from light",
                                 text: "Leaves use light, water and carbon dioxide (the gas we breathe out) to make their food. While they do it, they give off oxygen.",
                                 symbol: "sun.max.fill"),
                questions: [
                    ask(.explorer, "What do plants need to grow?", ["Light", "Darkness"], 0,
                        "Plants need light. That's why space greenhouses have lamps."),
                    ask(.explorer, "What do leaves give off while they make food?", ["Oxygen", "Smoke"], 0,
                        "Leaves give off oxygen, the gas we breathe in."),
                    ask(.builder, "What do plants use light for?", ["To stay warm", "To make their food", "To see in the dark"], 1,
                        "Plants turn light, water and carbon dioxide into food. That's why space greenhouses need lamps."),
                    ask(.builder, "Which three things do leaves use to make food?",
                        ["Light, water and carbon dioxide", "Sand, salt and oxygen", "Heat, rock and wind"], 0,
                        "Light, water and carbon dioxide. Oxygen is what the leaves give back."),
                    ask(.engineer, "A greenhouse on the Moon is closed off from sunlight. What must the base supply so the plants can make food?",
                        ["Electric light, which uses energy", "Extra oxygen", "Nothing. Plants store light"], 0,
                        "Lamps replace the Sun, and lamps use energy. Growing food is an energy decision."),
                    ask(.engineer, "People breathe out carbon dioxide and plants take it in. What do the plants give back?",
                        ["Oxygen", "More carbon dioxide", "Nothing at all"], 0,
                        "Plants take in carbon dioxide and give off oxygen. People do the opposite.")
                ]),
            LessonTopic(
                fact: LessonFact(title: "Astronauts breathe a lot of oxygen",
                                 text: "NASA plans for each astronaut to breathe about \(eachText) of oxygen every day. Our base has \(crew) crew members.",
                                 symbol: "wind", sourceID: "N1"),
                questions: [
                    ask(.explorer, "Do astronauts need oxygen every day?", ["Yes, every day", "Only sometimes"], 0,
                        "Every single day. That's why the air maker matters so much.", source: "N1"),
                    ask(.explorer, "Who breathes more oxygen in a day?", ["One astronaut", "\(crew) astronauts"], 1,
                        "More people breathe more oxygen.", source: "N1"),
                    ask(.builder, "Each of the \(crew) crew members breathes about \(eachText) of oxygen a day. About how much do they breathe together?",
                        [eachText, togetherText, Format.kg(together * 2, digits: 1)], 1,
                        "\(crew) people times \(eachText) each is about \(togetherText) every single day.", source: "N1"),
                    ask(.builder, "One astronaut breathes about \(eachText) of oxygen a day. About how much in 2 days?",
                        [eachText, Format.kg(each * 2, digits: 1), Format.kg(each * 10, digits: 1)], 1,
                        "Two days is two times \(eachText), about \(Format.kg(each * 2, digits: 1)).", source: "N1"),
                    ask(.engineer, "The \(crew) crew members breathe about \(togetherText) of oxygen a day together. About how much in 10 days?",
                        [Format.kg(together * 10, digits: 1), togetherText, Format.kg(together * 100, digits: 1)], 0,
                        "10 days times \(togetherText) is about \(Format.kg(together * 10, digits: 1)). Long missions need a lot of oxygen.", source: "N1"),
                    ask(.engineer, "The air maker is making less oxygen than the crew breathes. What happens to the oxygen tank?",
                        ["It slowly goes down", "It fills up", "Nothing changes"], 0,
                        "The crew makes up the difference from the tank, so the tank goes down. It is a reserve, not an endless supply.", source: "N1")
                ]),
            LessonTopic(
                fact: LessonFact(title: "Lettuce grown in space",
                                 text: "On the International Space Station, NASA's Veggie garden grew lettuce that was ready in about \(days) days. Its lights use about \(watts) watts, a bit like a bright lamp.",
                                 symbol: "leaf.circle.fill", sourceID: "N2"),
                questions: [
                    ask(.explorer, "Where did NASA grow this lettuce?", ["On the space station", "Under the sea"], 0,
                        "On the International Space Station, in a garden called Veggie.", source: "N2"),
                    ask(.explorer, "Does space lettuce grow in one day?", ["No, it takes many days", "Yes, in one day"], 0,
                        "It took about \(days) days. Plants need time.", source: "N2"),
                    ask(.builder, "About how long did lettuce take to grow on the space station?",
                        ["About 3 days", "About \(days) days", "About 300 days"], 1,
                        "About \(days) days. Space lettuce grows at a plant's pace, so the crew has to plan ahead.", source: "N2"),
                    ask(.builder, "What does the Veggie garden's power run?",
                        ["Lights, fans and controls", "A rocket engine", "A heater for the crew"], 0,
                        "Its power runs the lights, fans and control electronics.", source: "N2"),
                    ask(.engineer, "Veggie uses about \(watts) watts. About how much energy is that over 10 hours?",
                        [Words.kWh(tenHours), Words.kWh(tenHours * 10), Words.kWh(tenHours * 100)], 0,
                        "\(watts) watts is \(Format.kW(s.gardenOperatingPowerKW)). Running that for 10 hours uses \(Words.kWh(tenHours)).", source: "N2"),
                    ask(.engineer, "Lettuce took about \(days) days on the space station. Does that prove it takes \(days) days on the Moon?",
                        ["No. It is a real example from a different place", "Yes, exactly the same", "Yes, but only at night"], 0,
                        "It is a real result from the space station. The game uses it as a training rule, not as proof for the Moon.", source: "N2")
                ]),
            LessonTopic(
                fact: LessonFact(title: "Every choice costs something",
                                 text: "In our game, the lettuce needs its lights on \(light) hours a day. Energy used by the lights can't also run research or the air maker.",
                                 symbol: "bolt.fill", isGameRule: true),
                questions: [
                    ask(.explorer, "The lights used some energy. Can that same energy run something else too?", ["No, it is used up", "Yes, twice"], 0,
                        "Energy can only be used once. That is why every choice costs something."),
                    ask(.explorer, "Is anything on the base free to run?", ["No, everything uses energy", "Yes, everything"], 0,
                        "Lights, air and science all use energy."),
                    ask(.builder, "The base gets the same energy every day. You turn on research too. What happens?",
                        ["Research is free", "Less energy is left for the lights and the air maker", "The battery gets bigger"], 1,
                        "Energy spent on research every day is energy the lights and the air maker can't use. Small extras add up."),
                    ask(.builder, "You turn the greenhouse lights down to save energy. What happens to the lettuce?",
                        ["It grows more slowly", "It grows faster", "Nothing changes"], 0,
                        "Less light means slower growing. Saving energy here costs time."),
                    ask(.engineer, "In our game the lights run \(light) hours a day. You run them for half that, all drill long. How much growing does the lettuce get?",
                        ["About half as much", "The same", "Twice as much"], 0,
                        "Half the light gives about half the growth in the same number of days."),
                    ask(.engineer, "An extra 1 kWh of research every day does not sound like much. How much is it over \(days) days?",
                        [Words.kWh(dayCount), Words.kWh(1), Words.kWh(dayCount * 10)], 0,
                        "1 kWh every day for \(days) days is \(Words.kWh(dayCount)). Small daily extras add up.")
                ]),
            LessonTopic(
                fact: LessonFact(title: "Why bases still need machines for air",
                                 text: "A small greenhouse makes only a little oxygen, far less than a crew breathes. So bases still use machines to make air. Fresh lettuce is a treat, not all the food.",
                                 symbol: "gearshape.2.fill"),
                questions: [
                    ask(.explorer, "Can a small greenhouse make all the air a crew needs?", ["No, far too little", "Yes, easily"], 0,
                        "It makes only a little. The air maker does the real work."),
                    ask(.explorer, "Is fresh lettuce all the food the crew eats?", ["No, it is a fresh treat", "Yes, only lettuce"], 0,
                        "The crew still eats packaged meals. Lettuce is a fresh extra."),
                    ask(.builder, "Why does our base still need its air maker?",
                        ["Plants don't make any oxygen", "The greenhouse is too small to make enough oxygen", "The air maker grows the lettuce"], 1,
                        "Plants do make oxygen, but a small greenhouse makes far less than \(crew) people breathe."),
                    ask(.builder, "What is the lettuce for?",
                        ["A fresh extra next to packaged meals", "All of the crew's food", "Making electricity"], 0,
                        "It is a fresh extra. It does not replace the packaged meals."),
                    ask(.engineer, "A designer says: \"We have a greenhouse, so take out the air maker.\" What is wrong with that?",
                        ["A small greenhouse makes far less oxygen than the crew breathes", "Plants make no oxygen", "The air maker grows the lettuce"], 0,
                        "The greenhouse helps a little, but \(crew) people breathe about \(togetherText) a day. The machine is still needed."),
                    ask(.engineer, "Why does this game label some numbers \"Game rule\"?",
                        ["They were made up for play and are not NASA measurements", "They are secret", "They were measured on the Moon"], 0,
                        "Good engineers keep real data and their own assumptions apart. So does this game.")
                ])
        ]
    }

    // MARK: Power and Batteries

    /// Power, energy and why a battery is only as useful as the sunshine that fills it. Every number is
    /// read from the Lights Out drill's training assumptions, which are game rules, not NASA data.
    static func powerAndBatteries(level: LearnLevel = .builder) -> Lesson {
        Lesson(id: powerAndBatteriesID, title: "Power and Batteries", topic: "Power budgeting", symbol: "bolt.fill",
               unlocks: nil, cards: cards(powerTopics(), level: level))
    }

    static func powerTopics() -> [LessonTopic] {
        let d = MissionCatalog.lightsOut()
        let arrayKW = d.phases.map(\.solarKWPerArray).max() ?? 0
        let batteryKWh = d.item(.battery)?.batteryCapacityKWh ?? 0
        let baseKW = d.assumptions.essentialLoadKW + d.assumptions.fullGeneratorKW
        let halfKW = d.assumptions.essentialLoadKW + d.assumptions.fullGeneratorKW / 2
        let sun = d.phases.first?.durationHours ?? 0
        let shadow = d.phases.last?.durationHours ?? 0
        let needed = baseKW * shadow
        let spare = max(0, arrayKW - baseKW)
        let gap = abs(batteryKWh - needed)
        return [
            LessonTopic(
                fact: LessonFact(title: "Power and energy are different",
                                 text: "Power is how fast energy is being used right now. We measure it in kilowatts (kW). Energy is how much gets used over time, in kilowatt-hours (kWh). Using 1 kW for 1 hour uses 1 kWh.",
                                 symbol: "bolt.badge.clock.fill"),
                questions: [
                    ask(.explorer, "Which one tells you how FAST energy is being used?", ["Power", "Energy"], 0,
                        "Power is how fast. Energy is how much in total."),
                    ask(.explorer, "A lamp is left on for longer. Does it use more energy or less?", ["More energy", "Less energy"], 0,
                        "The longer something runs, the more energy it uses."),
                    ask(.builder, "A heater uses 1 kW of power for 3 hours. How much energy is that?", ["1 kWh", "3 kWh", "30 kWh"], 1,
                        "1 kW for 3 hours is 1 times 3, which is 3 kWh. Power times time gives energy."),
                    ask(.builder, "A machine uses 2 kW of power for 2 hours. How much energy is that?", ["2 kWh", "4 kWh", "22 kWh"], 1,
                        "2 kW for 2 hours is 2 times 2, which is 4 kWh."),
                    ask(.engineer, "A machine used 6 kWh of energy in 4 hours. What was its power?", ["1.5 kW", "24 kW", "10 kW"], 0,
                        "Energy divided by time gives power: 6 kWh divided by 4 hours is 1.5 kW."),
                    ask(.engineer, "A pump uses 0.5 kW for 6 hours. How much energy is that?", ["3 kWh", "6.5 kWh", "12 kWh"], 0,
                        "0.5 kW times 6 hours is 3 kWh.")
                ]),
            LessonTopic(
                fact: LessonFact(title: "Solar arrays need the Sun",
                                 text: "In our game, one solar array makes \(Format.kW(arrayKW)) of power in sunlight. In shadow it makes nothing at all.",
                                 symbol: "sun.max.fill", isGameRule: true),
                questions: [
                    ask(.explorer, "Do solar arrays make power in the dark?", ["No", "Yes"], 0,
                        "No sunlight, no solar power."),
                    ask(.explorer, "What do solar arrays need to make power?", ["Sunlight", "Moon rocks"], 0,
                        "Solar arrays turn sunlight into electricity."),
                    ask(.builder, "The base is in shadow. How much power do its solar arrays make?",
                        ["The same as in sunlight", "None", "Twice as much"], 1,
                        "No sunlight, no solar power. That is why a base needs a way to save energy for later."),
                    ask(.builder, "One solar array makes \(Format.kW(arrayKW)) in sunlight. How much do two make?",
                        [Format.kW(arrayKW), Format.kW(arrayKW * 2), Format.kW(arrayKW * 20)], 1,
                        "Two arrays make twice as much: \(Format.kW(arrayKW * 2))."),
                    ask(.engineer, "Three solar arrays shine for \(Words.hours(sun)). How much energy do they make?",
                        [Words.kWh(arrayKW * 3 * sun), Words.kWh(arrayKW * 3), Words.kWh(arrayKW * sun)], 0,
                        "Three arrays make \(Format.kW(arrayKW * 3)). Over \(Words.hours(sun)) that is \(Words.kWh(arrayKW * 3 * sun))."),
                    ask(.engineer, "Why can't solar arrays alone get a base through a shadow?",
                        ["They make nothing in the dark, so energy must be saved before", "They are too heavy", "They only work on Earth"], 0,
                        "In shadow they make nothing. The energy for the dark has to be made and stored while the Sun is up.")
                ]),
            LessonTopic(
                fact: LessonFact(title: "Batteries save energy for the dark",
                                 text: "In our game, one battery holds up to \(Words.kWh(batteryKWh)) and starts empty. In the shadow our base uses \(Format.kW(baseKW)) for \(Words.hours(shadow)), which is \(Words.kWh(needed)) of stored energy.",
                                 symbol: "battery.75percent", isGameRule: true),
                questions: [
                    ask(.explorer, "What is a battery for?", ["Saving energy for later", "Making sunlight"], 0,
                        "A battery saves energy so the base can use it in the dark."),
                    ask(.explorer, "In our game, is a new battery full or empty?", ["Empty", "Full"], 0,
                        "It starts empty. The solar arrays have to fill it."),
                    ask(.builder, "In the shadow, our base uses \(Format.kW(baseKW)) for \(Words.hours(shadow)). How much stored energy does it need?",
                        [Words.kWh(baseKW), Words.kWh(needed), Words.kWh(needed * 10)], 1,
                        "\(Format.kW(baseKW)) for \(Words.hours(shadow)) is \(Words.kWh(needed)). If the batteries hold less than that, the lights go out."),
                    ask(.builder, "One battery holds up to \(Words.kWh(batteryKWh)). How much can two batteries hold?",
                        [Words.kWh(batteryKWh), Words.kWh(batteryKWh * 2), Words.kWh(batteryKWh / 2)], 1,
                        "Two batteries hold twice as much: \(Words.kWh(batteryKWh * 2)). But only if there is enough sunshine to fill them."),
                    ask(.engineer, "The shadow needs \(Words.kWh(needed)). One battery holds \(Words.kWh(batteryKWh)). Is one FULL battery enough?",
                        ["Yes, with \(Words.kWh(gap)) to spare", "No, it is \(Words.kWh(gap)) short", "There is no way to tell"],
                        batteryKWh >= needed ? 0 : 1,
                        "Compare what the battery holds with what the shadow needs: \(Words.kWh(batteryKWh)) and \(Words.kWh(needed))."),
                    ask(.engineer, "Turning the air maker to Half cuts the base's power use from \(Format.kW(baseKW)) to \(Format.kW(halfKW)). How much energy does the \(Words.hourAdjective(shadow)) shadow need then?",
                        [Words.kWh(halfKW * shadow), Words.kWh(needed), Words.kWh(halfKW)], 0,
                        "\(Format.kW(halfKW)) for \(Words.hours(shadow)) is \(Words.kWh(halfKW * shadow)). It saves power, but then the crew breathes from the oxygen tank.")
                ]),
            LessonTopic(
                fact: LessonFact(title: "A battery is only as good as its sunshine",
                                 text: "With one solar array, the base itself uses \(Format.kW(baseKW)) of the \(Format.kW(arrayKW)) it makes. Only \(Format.kW(spare)) is left over to charge the battery. A bigger battery does not help if there is nothing extra to put in it.",
                                 symbol: "arrow.triangle.2.circlepath", isGameRule: true),
                questions: [
                    ask(.explorer, "You add an empty battery. Does it bring any energy with it?", ["No, it is empty", "Yes, lots"], 0,
                        "An empty battery brings no energy. Something has to fill it."),
                    ask(.explorer, "What fills the batteries?", ["Solar arrays in sunlight", "The shadow"], 0,
                        "The solar arrays fill the batteries while the Sun is up."),
                    ask(.builder, "Your battery is not even full when the shadow starts. You add a second battery, but no more solar arrays. What changes?",
                        ["Twice as much energy is stored", "Nothing: there is no extra energy to fill it", "The shadow gets shorter"], 1,
                        "An empty battery adds no energy. More solar arrays would fill the batteries faster. You can check this yourself with Test My Base!"),
                    ask(.builder, "Your batteries are full early, and sunshine is going to waste. What would let you keep more of it?",
                        ["Another battery", "Another solar array", "A bigger flag"], 0,
                        "When the batteries are full, extra sunshine has nowhere to go. Another battery gives it somewhere to go."),
                    ask(.engineer, "One array makes \(Format.kW(arrayKW)) and the base uses \(Format.kW(baseKW)). Over \(Words.hours(sun)) of sunlight, how much energy goes into the battery?",
                        [Words.kWh(spare * sun), Words.kWh(arrayKW * sun), Words.kWh(spare)], 0,
                        "Only the spare \(Format.kW(spare)) charges the battery. Over \(Words.hours(sun)) that is \(Words.kWh(spare * sun))."),
                    ask(.engineer, "A base stores \(Words.kWh(spare * sun)) but the shadow needs \(Words.kWh(needed)). Its battery is not full. Which change fixes that without using the oxygen tank?",
                        ["Add a solar array", "Add a battery", "Add a lamp post"], 0,
                        "The battery is not full, so storage is not the problem. More solar power fills it. Try it in Test My Base!")
                ])
        ]
    }
}
