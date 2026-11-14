import SwiftUI

/// The shared drill shell for every mission: world, mission panel, and a safe-area-aware primary action.
struct MissionView: View {
    let model: AppModel
    let session: MissionSession
    let package: SciencePackage
    let isActive: Bool
    @State private var showSources = false

    var body: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width > 700 && proxy.size.width > proxy.size.height * 1.05
            ZStack {
                Theme.space.ignoresSafeArea()
                if wide {
                    HStack(spacing: 0) {
                        world.frame(width: proxy.size.width * 0.62)
                        panel
                    }
                } else {
                    VStack(spacing: 0) {
                        world.frame(height: min(max(230, proxy.size.height * 0.44), max(230, proxy.size.height - 300)))
                        panel
                    }
                }
            }
        }
        .sheet(isPresented: $showSources) { SourcesView(package: package, focus: session.definition) }
    }

    private var world: some View {
        WorldView(coordinator: model.missionWorld, isActive: isActive, summary: session.worldSummary)
            .overlay(alignment: .topLeading) {
                HStack(spacing: 10) {
                    Button { model.leaveMission() } label: {
                        Image(systemName: "chevron.backward")
                            .font(.headline)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Theme.space.opacity(0.75)))
                            .foregroundStyle(Theme.ceramic)
                    }
                    .accessibilityLabel("Back to base")
                    VStack(alignment: .leading, spacing: 1) {
                        Text(session.definition.title).font(.rounded(.headline))
                        Text(session.definition.drillLabel).font(.footnote.weight(.semibold)).opacity(0.85)
                    }
                    .foregroundStyle(Theme.ceramic)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.space.opacity(0.75)))
                    .accessibilityElement(children: .combine)
                }
                .padding(12)
            }
            .overlay(alignment: .bottomLeading) {
                if session.stage == .playback || session.stage == .results, let label = timelineLabel {
                    Text(label)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(Theme.ceramic)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Theme.space.opacity(0.78)))
                        .padding(12)
                        .accessibilityLabel(label)
                }
            }
    }

    private var timelineLabel: String? {
        if session.isRover { return session.stage == .playback ? "Remote driving replay" : nil }
        guard let step = session.currentStep else { return nil }
        let total = session.definition.totalHours
        if session.definition.missionID == .livingBase {
            return "\(step.label) of \(Format.number(total / 24, digits: 0)) · sped up"
        }
        if step.phaseID == "assembly" { return "Before the storm: building the shelter" }
        return "\(step.label) · \(Format.hours(step.endHour)) of \(Format.hours(total))"
    }

    private var panel: some View {
        VStack(spacing: 0) {
            ScrollView {
                MissionPanel(session: session, showSources: { showSources = true })
                    .padding(16)
            }
            ActionBar(model: model, session: session)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(Theme.panel.shadow(color: .black.opacity(0.12), radius: 6, y: -2))
        }
        .background(Theme.panel)
    }
}

struct ActionBar: View {
    let model: AppModel
    let session: MissionSession

    var body: some View {
        switch session.stage {
        case .briefing:
            if session.tutorial == .placeFirstArray {
                Button { session.placeFirstArray() } label: { Label("Place a solar array", systemImage: "plus.circle.fill") }
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                Button { session.beginPlanning() } label: { Text(session.tutorial == .powered ? "Get ready for the shadow drill" : "Plan the drill") }
                    .buttonStyle(PrimaryButtonStyle())
            }
        case .planning:
            Button { session.goToPrediction() } label: { Text("Next: make a prediction") }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!session.canRun)
        case .predicting:
            Button { session.backToPlanning() } label: { Text("Change my plan") }
                .buttonStyle(SecondaryButtonStyle())
        case .playback:
            Button { session.skipPlayback() } label: { Label("Skip animation", systemImage: "forward.end.fill") }
                .buttonStyle(SecondaryButtonStyle())
        case .results:
            let success = session.explanation?.success ?? false
            HStack(spacing: 10) {
                if success {
                    Button { session.retry() } label: { Text("Try another plan") }
                        .buttonStyle(SecondaryButtonStyle())
                    Button { model.leaveMission() } label: { Text("Back to base") }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button { model.leaveMission() } label: { Text("Base") }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: 120)
                    Button { session.retry() } label: { Text("Try again") }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }
}

struct MissionPanel: View {
    let session: MissionSession
    let showSources: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch session.stage {
            case .briefing: BriefingSection(session: session)
            case .planning: PlanningSection(session: session)
            case .predicting: PredictionSection(session: session)
            case .playback: PlaybackSection(session: session)
            case .results: ResultsSection(session: session)
            }
            Button(action: showSources) {
                Label("Where do these numbers come from?", systemImage: "books.vertical")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.energyInk)
                    .frame(minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BriefingSection: View {
    let session: MissionSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch session.tutorial {
            case .placeFirstArray:
                Text("Your habitat is dark.")
                    .font(.rounded(.title2))
                    .foregroundStyle(Theme.ink)
                Text("Tap the glowing pad to place a solar array, or use the button below.")
                    .font(.body)
                    .foregroundStyle(Theme.ink)
            case .powered:
                Label("Power!", systemImage: "bolt.fill")
                    .font(.rounded(.title2))
                    .foregroundStyle(Theme.ink)
                Text("The array runs the habitat while the Sun shines. Next comes a six-hour shadow drill with no sunlight at all.")
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                Text("Your lander carries \(session.definition.cargoBudget) cargo points. Each array or battery costs 1.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
            case .done:
                Label(session.copy.topic, systemImage: session.copy.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.inkSecondary)
                Text(session.copy.story)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Goals").font(.rounded(.headline)).foregroundStyle(Theme.ink)
                    ForEach(session.copy.objectives, id: \.self) { objective in
                        Label(objective, systemImage: "target").foregroundStyle(Theme.ink)
                    }
                    if let bonus = session.copy.bonus {
                        Label(bonus, systemImage: "star.fill").foregroundStyle(Theme.amberInk)
                    }
                }
                .card()
                if session.isVariant {
                    Label("This is a harder version of the drill with different training numbers. The NASA numbers stay the same.",
                          systemImage: "dial.high.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
        }
    }
}

struct PlanningSection: View {
    let session: MissionSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if session.isRover {
                RoverPlanningView(session: session)
            } else {
                if !session.definition.catalog.isEmpty { CargoSection(session: session) }
                if session.definition.missionID == .livingBase {
                    Toggle("Same settings for all 33 days", isOn: Binding(get: { session.sameSettingsForAllBlocks },
                                                                          set: { session.setSameSettingsForAllBlocks($0) }))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .tint(Theme.energyInk)
                }
                ForEach(visiblePhases, id: \.self) { index in
                    PhasePlanCard(session: session, index: index)
                }
            }
            if let notice = session.notice {
                Label(notice, systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(Theme.warningInk)
                    .font(.body.weight(.semibold))
            }
            ForEach(Array(Set(session.issues.map(\.childMessage))).sorted(), id: \.self) { message in
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.warningInk)
            }
            HintView(session: session)
        }
    }

    private var visiblePhases: [Int] {
        if session.definition.missionID == .livingBase && session.sameSettingsForAllBlocks { return [0] }
        return Array(session.definition.phases.indices)
    }
}

struct CargoSection: View {
    let session: MissionSession

    var body: some View {
        let budget = session.definition.cargoBudget
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Cargo").font(.rounded(.headline)).foregroundStyle(Theme.ink)
                Spacer()
                Text("\(session.cargoCost) of \(budget) points")
                    .font(.body.weight(.bold).monospacedDigit())
                    .foregroundStyle(session.cargoCost > budget ? Theme.warningInk : Theme.ink)
            }
            HStack(spacing: 6) {
                ForEach(0..<budget, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(index < session.cargoCost ? Theme.amber : Theme.panelLine)
                        .frame(height: 12)
                }
            }
            .accessibilityHidden(true)
            ForEach(session.definition.catalog) { item in
                CargoRow(session: session, item: item)
            }
        }
        .card()
    }
}

struct CargoRow: View {
    let session: MissionSession
    let item: CargoItem

    var body: some View {
        let count = session.count(item.kind)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(CargoCopy.name(item.kind)).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                Text("\(CargoCopy.detail(item)) · \(item.cost) pt").font(.subheadline).foregroundStyle(Theme.inkSecondary)
            }
            Spacer(minLength: 8)
            if item.maxCount == 1 {
                Toggle("", isOn: Binding(get: { count == 1 }, set: { session.setCount(item.kind, $0 ? 1 : 0) }))
                    .labelsHidden()
                    .tint(Theme.energyInk)
                    .accessibilityLabel(CargoCopy.name(item.kind))
            } else {
                HStack(spacing: 4) {
                    Button { session.setCount(item.kind, count - 1) } label: {
                        Image(systemName: "minus").frame(width: 44, height: 44)
                    }
                    .disabled(count == 0)
                    .accessibilityLabel("Remove \(CargoCopy.name(item.kind).lowercased())")
                    Text("\(count)")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .frame(minWidth: 28)
                        .accessibilityHidden(true)
                    Button { session.setCount(item.kind, count + 1) } label: {
                        Image(systemName: "plus").frame(width: 44, height: 44)
                    }
                    .disabled(!session.canAdd(item.kind))
                    .accessibilityLabel("Add \(CargoCopy.name(item.kind).lowercased())")
                }
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .background(Capsule().fill(Theme.panel))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityValue("\(count)")
    }
}

struct PhasePlanCard: View {
    let session: MissionSession
    let index: Int

    var body: some View {
        let phase = session.definition.phases[index]
        let plan = session.plan(index)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: symbol(phase.mood)).foregroundStyle(Theme.ink).accessibilityHidden(true)
                Text(title(phase)).font(.rounded(.headline)).foregroundStyle(Theme.ink)
                Spacer()
                Text(Format.hours(phase.durationHours * (sameAll ? 3 : 1)))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.inkSecondary)
            }
            ChoiceRow(title: "Air maker", options: phase.allowedAirFractions.map { ($0, MissionSession.airLabel($0)) },
                      selection: Binding(get: { plan.airFraction }, set: { session.setAir(index, $0) }))
            if !phase.allowedGardenFractions.isEmpty {
                ChoiceRow(title: "Greenhouse lights", options: phase.allowedGardenFractions.map { ($0, gardenLabel($0)) },
                          selection: Binding(get: { plan.gardenFraction }, set: { session.setGarden(index, $0) }))
            }
            if let research = phase.research {
                ChoiceRow(title: researchTitle, options: research.levels.map { ($0, researchLabel($0, research)) },
                          selection: Binding(get: { plan.researchLevel }, set: { session.setResearch(index, $0) }))
            }
            Text(powerLine(phase, plan))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.inkSecondary)
        }
        .card()
    }

    private var sameAll: Bool { session.definition.missionID == .livingBase && session.sameSettingsForAllBlocks }

    private func title(_ phase: PhaseDefinition) -> String {
        if session.definition.missionID == .livingBase {
            if sameAll { return "Every day" }
            let start = index * 11 + 1
            return "Days \(start) to \(start + 10)"
        }
        return phase.label
    }

    private func symbol(_ mood: PhaseMood) -> String {
        switch mood {
        case .sunlit: return "sun.max.fill"
        case .shadow: return "moon.fill"
        case .steady: return "calendar"
        case .storm: return "shield.lefthalf.filled"
        }
    }

    private func gardenLabel(_ value: Double) -> String {
        value < 0.25 ? "Off" : "\(Int(value * 16)) h a day"
    }

    private var researchTitle: String {
        switch session.definition.missionID {
        case .lightsOut: return "Science observation (1.5 kWh)"
        case .livingBase: return "Research"
        default: return "Science with the kit (0.3 kW)"
        }
    }

    private func researchLabel(_ value: Double, _ option: ResearchOption) -> String {
        if value < 1e-9 { return "Off" }
        if session.definition.missionID == .livingBase { return "\(Int(value)) kWh a day" }
        return "On"
    }

    private func powerLine(_ phase: PhaseDefinition, _ plan: PhasePlan) -> String {
        let a = session.definition.assumptions
        let light = plan.gardenFraction * a.gardenFullLightHours
        let garden = phase.allowedGardenFractions.isEmpty ? 0
            : (session.science.gardenOperatingPowerKW * light + a.gardenStandbyKW * (24 - light)) / 24
        let demand = a.essentialLoadKW + a.fullGeneratorKW * plan.airFraction + garden
            + (phase.research?.powerKWPerLevel ?? 0) * plan.researchLevel
        let supply = phase.baseSupplyKW + Double(session.count(.solarArray)) * phase.solarKWPerArray
        let oxygen = a.fullGeneratorKgPerDay * plan.airFraction
        let breathe = Double(session.definition.initial.crewCount) * session.science.oxygenKgPerPersonDay
        if session.definition.missionID == .livingBase {
            return "Uses \(Format.number(demand * 24)) kWh a day of \(Format.number(supply * 24)) available. Makes \(Format.kg(oxygen)) of oxygen a day; the crew breathes \(Format.kg(breathe, digits: 3))."
        }
        return "Uses \(Format.kW(demand)), makes \(Format.kW(supply)). Air maker: \(Format.kg(oxygen)) a day; the crew breathes \(Format.kg(breathe, digits: 3)) a day."
    }
}

struct RoverPlanningView: View {
    let session: MissionSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Who stops the rover?").font(.rounded(.headline)).foregroundStyle(Theme.ink)
                Text("The lander carries 2 cargo points. The onboard computer and the science camera each take 2.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                ChoiceRow(title: "Control",
                          options: [(RoverPlanChoice.earth, "Earth, no camera"),
                                    (.earthWithCamera, "Earth + science camera"),
                                    (.onboard, "Onboard computer")],
                          selection: Binding(get: { session.roverPlan }, set: { session.setRoverPlan($0) }))
            }
            .card()
            if session.roverPlan != .onboard, let rover = session.definition.rover {
                VStack(alignment: .leading, spacing: 10) {
                    Text("When should Earth send STOP?").font(.rounded(.headline)).foregroundStyle(Theme.ink)
                    Text("Mission Control sends the stop command as soon as a picture shows the rover at this flag.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                    ChoiceRow(title: "Send STOP when the picture shows",
                              options: rover.markerChoicesM.map { ($0, Format.meters($0)) },
                              selection: Binding(get: { session.roverConfiguration.observedMarkerM ?? rover.markerChoicesM[0] },
                                                 set: { session.setMarker($0) }))
                    Text("The rover drives at \(Format.meters(rover.speedMPerSecond)) per second. The yellow bay is \(Format.meters(rover.targetBayStartM)) to \(Format.meters(rover.targetBayEndM)).")
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                }
                .card()
            }
        }
    }
}

struct HintView: View {
    let session: MissionSession

    var body: some View {
        if session.hintVisible {
            Label(session.copy.hint, systemImage: "lightbulb.fill")
                .font(.body)
                .foregroundStyle(Theme.ink)
                .card()
        } else {
            Button { reveal() } label: {
                Label("Show a hint", systemImage: "lightbulb")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.amberInk)
                    .frame(minHeight: 44)
            }
        }
    }

    private func reveal() {
        session.hintVisible = true
    }
}

struct PredictionSection: View {
    let session: MissionSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Make a prediction").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.inkSecondary)
            Text(session.copy.question).font(.rounded(.title3)).foregroundStyle(Theme.ink)
            Text("Your plan: \(session.setupDescription)").font(.subheadline).foregroundStyle(Theme.inkSecondary)
            ForEach(Prediction.allCases, id: \.self) { choice in
                Button { session.run(predicting: choice) } label: {
                    Text("\(choice.label), run the test")
                }
                .buttonStyle(PrimaryButtonStyle(tint: choice == .unsure ? Theme.panelLine : Theme.amber))
            }
        }
    }
}

struct PlaybackSection: View {
    let session: MissionSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let r = session.roverResult {
                RoverStepsView(result: r, definition: session.definition)
            } else if let step = session.currentStep {
                TimelineBar(session: session, step: step)
                ResourceMeters(session: session, step: step)
            }
        }
    }
}

struct TimelineBar: View {
    let session: MissionSession
    let step: ResourceSnapshot

    var body: some View {
        let total = max(1e-9, session.definition.totalHours)
        let progress = min(1, step.endHour / total)
        VStack(alignment: .leading, spacing: 6) {
            Text(step.phaseID == "assembly" ? "Building the shelter" : step.label)
                .font(.rounded(.headline))
                .foregroundStyle(Theme.ink)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    HStack(spacing: 2) {
                        ForEach(session.definition.phases) { phase in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(color(phase.mood).opacity(0.35))
                                .frame(width: max(4, proxy.size.width * phase.durationHours / total - 2))
                        }
                    }
                    Capsule().fill(Theme.ink)
                        .frame(width: 4, height: 18)
                        .offset(x: max(0, proxy.size.width * progress - 2))
                }
            }
            .frame(height: 18)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private func color(_ mood: PhaseMood) -> Color {
        switch mood {
        case .sunlit: return Theme.amber
        case .shadow: return Theme.solar
        case .steady: return Theme.plant
        case .storm: return Theme.energy
        }
    }
}

struct ResourceMeters: View {
    let session: MissionSession
    let step: ResourceSnapshot

    var body: some View {
        let d = session.definition
        let s = session.science
        let after = step.after
        let airHours = ResourceEngine.airHours(oxygenKg: after.oxygenKg, crewCount: d.initial.crewCount, science: s)
        let fullAirHours = ResourceEngine.airHours(oxygenKg: after.oxygenCapacityKg, crewCount: d.initial.crewCount, science: s)
        VStack(alignment: .leading, spacing: 12) {
            MeterView(title: "Battery", valueText: "\(Format.kWh(after.batteryKWh)) of \(Format.number(after.batteryCapacityKWh, digits: 0))",
                      fraction: after.batteryCapacityKWh > 0 ? after.batteryKWh / after.batteryCapacityKWh : 0,
                      tint: Theme.energyInk, systemImage: "battery.75percent",
                      warning: step.failure?.constraint == .energyShortage)
            MeterView(title: "Air in the tank", valueText: Format.wholeHours(airHours),
                      fraction: fullAirHours > 0 ? airHours / fullAirHours : 0,
                      tint: Theme.solar, systemImage: "wind",
                      warning: step.failure?.constraint == .oxygenExhausted || airHours < d.success.minimumAirHours)
            if d.hasGarden {
                MeterView(title: "Lettuce growth", valueText: "\(Format.number(after.cropGrowthDays)) of \(Format.number(s.cropReferenceDays, digits: 0)) days",
                          fraction: after.cropGrowthDays / s.cropReferenceDays, tint: Theme.plantInk, systemImage: "leaf.fill")
            }
            if d.phases.contains(where: \.requiresShelter) {
                Label(step.sheltered ? "Crew inside the shelter" : (session.count(.shelterKit) > 0 ? "Shelter ready" : "No shelter"),
                      systemImage: step.sheltered ? "shield.checkered" : "shield.slash")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(step.failure?.constraint == .shelterMissing ? Theme.warningInk : Theme.ink)
                if step.mood == .storm {
                    Text("The moving specks are just a picture of a storm, not measured radiation.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
        }
        .card()
    }
}

struct RoverStepsView: View {
    let result: RoverMissionResult
    let definition: MissionDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What happens").font(.rounded(.headline)).foregroundStyle(Theme.ink)
            if result.configuration.mode == .earthControl, let marker = result.configuration.observedMarkerM {
                step(1, "The rover passes the \(Format.meters(marker)) flag and takes a picture.", "camera.fill")
                step(2, "The picture travels to Earth: \(Format.seconds(result.oneWayDelaySeconds)).", "arrow.up.right")
                step(3, "Mission Control sends STOP. It travels back: \(Format.seconds(result.oneWayDelaySeconds)).", "arrow.down.left")
                step(4, "The rover keeps rolling the whole time, then stops.", "stop.circle.fill")
            } else {
                step(1, "The onboard computer watches the track itself.", "cpu")
                step(2, "At \(Format.meters(result.finalStopM)) it stops the rover without asking Earth.", "stop.circle.fill")
            }
        }
        .card()
    }

    private func step(_ number: Int, _ text: String, _ symbol: String) -> some View {
        Label { Text("\(number). \(text)").foregroundStyle(Theme.ink) } icon: {
            Image(systemName: symbol).foregroundStyle(Theme.energyInk)
        }
    }
}

struct ResultsSection: View {
    let session: MissionSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let e = session.explanation {
                VStack(alignment: .leading, spacing: 10) {
                    Label(e.headline, systemImage: e.success ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.rounded(.title2))
                        .foregroundStyle(e.success ? Theme.plantInk : Theme.warningInk)
                    ForEach(e.paragraphs, id: \.self) { paragraph in
                        Text(paragraph).font(.body).foregroundStyle(Theme.ink)
                    }
                    if let right = session.predictionWasRight, let prediction = session.prediction {
                        Label(right ? "You predicted \"\(prediction.label)\". Good thinking!"
                                    : "You predicted \"\(prediction.label)\". Surprise! Now you know why.",
                              systemImage: right ? "brain.head.profile" : "sparkles")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                    }
                    if session.firstCompletion {
                        Label("Drill complete! Your base just got an upgrade.", systemImage: "star.fill")
                            .font(.body.weight(.bold))
                            .foregroundStyle(Theme.amberInk)
                    }
                }
                .card()
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(e.numbers, id: \.self) { row in
                        HStack {
                            Text(row.label).foregroundStyle(Theme.inkSecondary)
                            Spacer()
                            Text(row.value).font(.body.weight(.bold).monospacedDigit()).foregroundStyle(Theme.ink)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .card()
            }
            if let previous = session.previousAttempt, let current = session.currentAttempt {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Compare with your last try").font(.rounded(.headline)).foregroundStyle(Theme.ink)
                    AttemptLine(title: "Last try", summary: previous)
                    AttemptLine(title: "This try", summary: current)
                    Text("Both tries started with exactly the same supplies.").font(.footnote).foregroundStyle(Theme.inkSecondary)
                }
                .card()
            }
            if session.explanation?.success == false { HintView(session: session) }
        }
    }
}

struct AttemptLine: View {
    let title: String
    let summary: AttemptSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("\(title): \(summary.headline)", systemImage: summary.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(summary.success ? Theme.plantInk : Theme.warningInk)
            Text(summary.setup).font(.subheadline).foregroundStyle(Theme.inkSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}
