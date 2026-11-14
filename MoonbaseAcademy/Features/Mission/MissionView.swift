import SwiftUI

/// A drill, played in the world: build from the tray, predict, launch, watch, earn stars.
struct MissionView: View {
    let model: AppModel
    let session: MissionSession
    let package: SciencePackage
    let isActive: Bool
    @State private var showSources = false
    @State private var planPhase: Int?
    @State private var topHeight: CGFloat = 0
    @State private var bottomHeight: CGFloat = 0
    @State private var banner: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                WorldView(coordinator: model.missionWorld, isActive: isActive, summary: session.worldSummary)
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    MissionTopHUD(session: session, onBack: { model.leaveMission() }, onSources: { showSources = true })
                        .readHeight { height in
                            topHeight = height + proxy.safeAreaInsets.top
                            updateInsets()
                        }
                    Spacer(minLength: 0)
                    bottomArea
                        .frame(maxWidth: 760)
                        .readHeight { height in
                            bottomHeight = height + proxy.safeAreaInsets.bottom
                            updateInsets()
                        }
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 6)

                if let banner {
                    Ribbon(text: banner, bevel: GamePalette.energy, font: .game(.title2))
                        .transition(reduceMotion ? .opacity : .move(edge: .leading).combined(with: .opacity))
                        .allowsHitTesting(false)
                        .zIndex(3)
                }
                if let number = session.countdown {
                    Text(number == 0 ? "GO!" : "\(number)")
                        .font(.system(size: 120, weight: .black, design: .rounded))
                        .gameText(number == 0 ? Color(hex: 0x9FF28F) : .white)
                        .id(number)
                        .transition(.scale(scale: 2.2).combined(with: .opacity))
                        .allowsHitTesting(false)
                        .zIndex(4)
                        .accessibilityLabel(number == 0 ? "Go" : "\(number)")
                }
                if session.stage == .predicting {
                    BetOverlay(session: session).transition(.opacity).zIndex(5)
                }
                if let index = planPhase, session.stage == .planning {
                    PlanPopup(session: session, index: index) { planPhase = nil }
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity))
                        .zIndex(5)
                }
                if session.stage == .results {
                    ResultOverlay(model: model, session: session)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
                        .zIndex(6)
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.72), value: session.stage)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.6), value: session.countdown)
            .animation(.easeOut(duration: 0.25), value: banner)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: planPhase)
        }
        .onChange(of: session.currentStep?.phaseID) { _, newPhase in
            guard session.stage == .playback, let newPhase, session.definition.missionID != .livingBase else { return }
            showBanner(for: newPhase)
        }
        .onChange(of: session.countdown) { _, value in
            if value != nil { Haptics.thump() }
        }
        .sheet(isPresented: $showSources) { SourcesView(package: package, focus: session.definition) }
    }

    private func updateInsets() {
        model.missionWorld.setHUDInsets(top: topHeight + 4, bottom: bottomHeight + 4)
    }

    private func showBanner(for phaseID: String) {
        let text: String
        switch phaseID {
        case "sunlit": text = "SUNLIGHT"
        case "shadow": text = "SHADOW DRILL"
        case "assembly": text = "BUILD SHELTER"
        case "rising": text = "STORM RISING"
        case "declining": text = "STORM FADING"
        default: return
        }
        banner = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            if banner == text { banner = nil }
        }
    }

    @ViewBuilder private var bottomArea: some View {
        switch session.stage {
        case .briefing:
            VStack(spacing: 10) {
                NovaBubble(text: session.novaLine, actionLabel: session.isLastIntroLine ? nil : "Tap for more") {
                    session.advanceIntro()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(session.isLastIntroLine ? "Let's build!" : "Next") { session.advanceIntro() }
                    .buttonStyle(GameButtonStyle(bevel: session.isLastIntroLine ? GamePalette.go : GamePalette.gold, height: 60))
            }
        case .planning:
            VStack(spacing: 8) {
                NovaBubble(text: session.novaLine, compact: true) {
                    if session.tutorial == .powered {
                        session.dismissTutorial()
                    } else if session.tutorial == .done {
                        session.hintVisible.toggle()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                BuildTray(session: session) { planPhase = $0 }
                Button {
                    session.goToPrediction()
                } label: {
                    Label("Launch test", systemImage: "flame.fill")
                }
                .buttonStyle(GameButtonStyle(bevel: GamePalette.go, height: 62, font: .game(.title2)))
                .disabled(!session.canLaunch)
            }
        case .playback:
            NovaBubble(text: session.novaLine, compact: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .predicting, .results:
            EmptyView()
        }
    }
}

// MARK: Top HUD

struct MissionTopHUD: View {
    let session: MissionSession
    let onBack: () -> Void
    let onSources: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                RoundIconButton(symbol: "chevron.backward", label: "Leave drill", action: onBack)
                VStack(alignment: .leading, spacing: 0) {
                    Text(session.gameCopy.title).font(.game(.headline)).gameText().lineLimit(1)
                    Text(session.definition.drillLabel)
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .gameText(Color(hex: 0xFFE27A))
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if session.stage == .playback {
                    RoundIconButton(symbol: "forward.end.fill", label: "Skip animation", bevel: GamePalette.gold) { session.skipPlayback() }
                } else {
                    RoundIconButton(symbol: "books.vertical.fill", label: "Where the numbers come from", action: onSources)
                }
            }
            pills
            if session.stage == .playback && !session.isRover && session.countdown == nil {
                TimelineStrip(session: session)
            }
        }
    }

    @ViewBuilder private var pills: some View {
        let d = session.definition
        let state = session.displayState
        HStack(spacing: 10) {
            if !d.catalog.isEmpty && session.stage != .playback {
                ResourcePill(symbol: "shippingbox.fill", bevel: GamePalette.gold,
                             value: "\(session.cargoCost)/\(d.cargoBudget)", label: "Cargo crates",
                             fraction: d.cargoBudget > 0 ? Double(session.cargoCost) / Double(d.cargoBudget) : 0,
                             warning: session.cargoCost > d.cargoBudget)
            }
            if session.isRover {
                ResourcePill(symbol: "antenna.radiowaves.left.and.right", bevel: GamePalette.energy,
                             value: Format.seconds(session.science.commandLoopDelaySeconds), label: "Picture and command delay")
                if let r = session.roverResult, session.stage != .planning {
                    ResourcePill(symbol: "mappin.and.ellipse", bevel: r.success ? GamePalette.go : GamePalette.coral,
                                 value: Format.meters(r.finalStopM), label: "Stop position")
                }
            } else {
                let failure = session.currentStep?.failure?.constraint
                ResourcePill(symbol: "bolt.fill", bevel: GamePalette.energy,
                             value: "\(Format.number(state.batteryKWh))/\(Format.number(state.batteryCapacityKWh, digits: 0)) kWh",
                             label: "Battery",
                             fraction: state.batteryCapacityKWh > 0 ? state.batteryKWh / state.batteryCapacityKWh : 0,
                             warning: failure == .energyShortage)
                let hours = ResourceEngine.airHours(oxygenKg: state.oxygenKg, crewCount: d.initial.crewCount, science: session.science)
                let full = ResourceEngine.airHours(oxygenKg: state.oxygenCapacityKg, crewCount: d.initial.crewCount, science: session.science)
                ResourcePill(symbol: "wind", bevel: GamePalette.steel, value: "\(Int(hours.rounded(.down))) h air", label: "Air in the tank",
                             fraction: full > 0 ? hours / full : 0,
                             warning: failure == .oxygenExhausted || (session.stage != .planning && hours < d.success.minimumAirHours))
                if d.hasGarden {
                    ResourcePill(symbol: "leaf.fill", bevel: GamePalette.go,
                                 value: "\(Format.number(state.cropGrowthDays, digits: 0))/\(Format.number(session.science.cropReferenceDays, digits: 0)) d",
                                 label: "Lettuce growth days",
                                 fraction: state.cropGrowthDays / session.science.cropReferenceDays)
                }
            }
        }
    }
}

struct TimelineStrip: View {
    let session: MissionSession

    var body: some View {
        let d = session.definition
        let total = max(1e-9, d.totalHours)
        let step = session.currentStep
        let progress = min(1, (step?.endHour ?? 0) / total)
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    HStack(spacing: 3) {
                        ForEach(d.phases) { phase in
                            Capsule()
                                .fill(color(phase.mood))
                                .frame(width: max(6, proxy.size.width * phase.durationHours / total - 3))
                        }
                    }
                    Image(systemName: icon(step?.mood ?? .sunlit))
                        .font(.system(size: 16, weight: .black))
                        .gameText()
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(GamePalette.night))
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                        .offset(x: max(0, min(proxy.size.width - 30, proxy.size.width * progress - 15)))
                        .animation(.linear(duration: 0.3), value: progress)
                }
                .frame(height: 30)
            }
            .frame(height: 30)
            Text(label(step, total: total))
                .font(.system(.caption, design: .rounded).weight(.heavy).monospacedDigit())
                .gameText()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(GamePalette.hud))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label(step, total: total))
    }

    private func label(_ step: ResourceSnapshot?, total: Double) -> String {
        guard let step else { return "" }
        if session.definition.missionID == .livingBase {
            return "\(step.label) of \(Format.number(total / 24, digits: 0)) · sped up"
        }
        if step.phaseID == "assembly" { return "Before the storm" }
        return "\(step.label) · \(Format.hours(step.endHour)) of \(Format.hours(total)) · sped up"
    }

    private func color(_ mood: PhaseMood) -> Color {
        switch mood {
        case .sunlit: return Color(hex: 0xFFD66B)
        case .shadow: return Color(hex: 0x4F6A9A)
        case .steady: return Color(hex: 0x7EDB6E)
        case .storm: return Color(hex: 0x74DFEC)
        }
    }

    private func icon(_ mood: PhaseMood) -> String {
        switch mood {
        case .sunlit: return "sun.max.fill"
        case .shadow: return "moon.fill"
        case .steady: return "leaf.fill"
        case .storm: return "bolt.fill"
        }
    }
}

// MARK: Build tray

struct BuildTray: View {
    let session: MissionSession
    let openPlan: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if session.isRover {
                    RoverTray(session: session)
                } else {
                    ForEach(session.definition.catalog) { item in
                        BuildCard(session: session, item: item,
                                  highlighted: session.tutorial == .placeFirstArray && item.kind == .solarArray,
                                  dimmed: session.tutorial == .placeFirstArray && item.kind != .solarArray)
                    }
                    ForEach(planIndices, id: \.self) { index in
                        PlanCard(session: session, index: index) { openPlan(index) }
                            .disabled(session.tutorial == .placeFirstArray)
                            .opacity(session.tutorial == .placeFirstArray ? 0.5 : 1)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 2)
        }
        .shake(session.shakeToken)
        .animation(.default, value: session.shakeToken)
    }

    private var planIndices: [Int] {
        if session.definition.missionID == .livingBase && session.sameSettingsForAllBlocks { return [0] }
        return Array(session.definition.phases.indices)
    }
}

struct BuildCard: View {
    let session: MissionSession
    let item: CargoItem
    var highlighted = false
    var dimmed = false
    @State private var pop = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let count = session.count(item.kind)
        let name = CargoCopy.name(item.kind)
        Button {
            if session.addCargo(item.kind) {
                Haptics.thump()
                guard !reduceMotion else { return }
                pop = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { pop = false }
            } else {
                Haptics.warning()
            }
        } label: {
            VStack(spacing: 4) {
                CargoIconView(kind: item.kind)
                    .frame(height: 62)
                Text(name)
                    .font(.system(.footnote, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 3) {
                    Image(systemName: "shippingbox.fill")
                    Text("\(item.cost)")
                }
                .font(.system(.caption, design: .rounded).weight(.black))
                .foregroundStyle(Theme.amberInk)
            }
            .padding(10)
            .frame(width: 118, height: 146)
            .background(GameCardBackground(highlighted: highlighted || count > 0))
            .scaleEffect(pop ? 1.08 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: pop)
        }
        .buttonStyle(PressableStyle())
        .opacity(dimmed ? 0.45 : 1)
        .overlay(alignment: .topTrailing) {
            if count > 0 {
                Text("×\(count)")
                    .font(.game(.subheadline))
                    .gameText()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(GamePalette.energy.bottom).overlay(Capsule().strokeBorder(Color.white, lineWidth: 2)))
                    .offset(x: 6, y: -6)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .topLeading) {
            if count > 0 && session.tutorial != .placeFirstArray {
                RoundIconButton(symbol: "minus", label: "Remove \(name.lowercased())", bevel: GamePalette.coral, size: 32) {
                    session.removeCargo(item.kind)
                }
                .offset(x: -8, y: -10)
            }
        }
        .overlay(alignment: .bottom) {
            if highlighted {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 30, weight: .black))
                    .gameText(Color(hex: 0xFFE27A))
                    .offset(y: 22)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel("Add \(name.lowercased())")
        .accessibilityValue("\(count) on board, costs \(item.cost) crate\(item.cost == 1 ? "" : "s")")
    }
}

struct CargoIconView: View {
    let kind: CargoKind

    var body: some View {
        if let image = Art.cargoIcon(kind) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(GamePalette.steel.edge).offset(y: 3)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [GamePalette.steel.top, GamePalette.steel.bottom], startPoint: .top, endPoint: .bottom))
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .black))
                    .gameText()
            }
            .frame(width: 56, height: 50)
        }
    }

    private var symbol: String {
        switch kind {
        case .scienceKit: return "flask.fill"
        case .onboardComputer: return "cpu"
        case .scienceCamera: return "camera.fill"
        default: return "shippingbox.fill"
        }
    }
}

struct PlanCard: View {
    let session: MissionSession
    let index: Int
    let action: () -> Void

    var body: some View {
        let phase = session.definition.phases[index]
        let plan = session.plan(index)
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: PlanCard.icon(phase.mood))
                    .font(.system(size: 26, weight: .black))
                    .gameText()
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(PlanCard.bevel(phase.mood).bottom))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.7), lineWidth: 2))
                Text(PlanCard.title(session, index))
                    .font(.system(.footnote, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                VStack(spacing: 1) {
                    status("wind", MissionSession.airLabel(plan.airFraction))
                    if !phase.allowedGardenFractions.isEmpty {
                        status("lightbulb.fill", plan.gardenFraction > 0 ? "\(Int(plan.gardenFraction * 16)) h" : "Off")
                    }
                    if phase.research != nil {
                        status("flask.fill", plan.researchLevel > 0 ? (session.definition.missionID == .livingBase ? "\(Int(plan.researchLevel)) kWh" : "On") : "Off")
                    }
                }
            }
            .padding(10)
            .frame(width: 124, height: 146)
            .background(GameCardBackground())
            .overlay(alignment: .topTrailing) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Theme.inkSecondary)
                    .padding(8)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(PlanCard.title(session, index)) plan")
        .accessibilityHint("Opens the settings for this part of the drill")
    }

    private func status(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 10, weight: .black))
            Text(text).font(.system(.caption2, design: .rounded).weight(.heavy))
        }
        .foregroundStyle(Theme.inkSecondary)
    }

    static func title(_ session: MissionSession, _ index: Int) -> String {
        if session.definition.missionID == .livingBase {
            if session.sameSettingsForAllBlocks { return "Every day" }
            return "Days \(index * 11 + 1)–\(index * 11 + 11)"
        }
        return session.definition.phases[index].label
    }

    static func icon(_ mood: PhaseMood) -> String {
        switch mood {
        case .sunlit: return "sun.max.fill"
        case .shadow: return "moon.stars.fill"
        case .steady: return "calendar"
        case .storm: return "bolt.shield.fill"
        }
    }

    static func bevel(_ mood: PhaseMood) -> GamePalette.Bevel {
        switch mood {
        case .sunlit: return GamePalette.gold
        case .shadow: return GamePalette.steel
        case .steady: return GamePalette.go
        case .storm: return GamePalette.energy
        }
    }
}

struct RoverTray: View {
    let session: MissionSession

    var body: some View {
        HStack(spacing: 12) {
            choice(.earth, "Earth control", "globe.americas.fill", cost: 0)
            choice(.earthWithCamera, "Earth + camera", "camera.fill", cost: 2)
            choice(.onboard, "Onboard computer", "cpu", cost: 2)
            if session.roverPlan != .onboard, let rover = session.definition.rover {
                VStack(spacing: 8) {
                    Text("Send STOP when the picture shows")
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .frame(width: 150)
                    ForEach(rover.markerChoicesM, id: \.self) { marker in
                        let selected = abs((session.roverConfiguration.observedMarkerM ?? -1) - marker) < 1e-9
                        Button(Format.meters(marker)) { session.setMarker(marker) }
                            .buttonStyle(GameButtonStyle(bevel: selected ? GamePalette.gold : GamePalette.steel, height: 34, font: .game(.subheadline)))
                            .frame(width: 120)
                            .accessibilityLabel("Stop at the \(Format.meters(marker)) flag")
                            .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(10)
                .background(GameCardBackground())
            }
        }
    }

    private func choice(_ plan: RoverPlanChoice, _ title: String, _ symbol: String, cost: Int) -> some View {
        let selected = session.roverPlan == plan
        return Button {
            session.setRoverPlan(plan)
            Haptics.thump()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 28, weight: .black))
                    .gameText()
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(selected ? GamePalette.gold.bottom : GamePalette.steel.bottom))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.7), lineWidth: 2))
                Text(title)
                    .font(.system(.footnote, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                HStack(spacing: 3) {
                    Image(systemName: "shippingbox.fill")
                    Text(cost == 0 ? "Free" : "\(cost)")
                }
                .font(.system(.caption, design: .rounded).weight(.black))
                .foregroundStyle(Theme.amberInk)
            }
            .padding(10)
            .frame(width: 118, height: 150)
            .background(GameCardBackground(highlighted: selected))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: Plan popup

struct PlanPopup: View {
    let session: MissionSession
    let index: Int
    let close: () -> Void

    var body: some View {
        let phase = session.definition.phases[index]
        let plan = session.plan(index)
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture(perform: close).accessibilityHidden(true)
            VStack(spacing: 14) {
                Ribbon(text: PlanCard.title(session, index), bevel: PlanCard.bevel(phase.mood))
                    .padding(.top, -34)
                GameChoice(title: "Air maker", symbol: "wind",
                           options: phase.allowedAirFractions.map { ($0, MissionSession.airLabel($0)) },
                           selection: plan.airFraction) { session.setAir(index, $0) }
                if !phase.allowedGardenFractions.isEmpty {
                    GameChoice(title: "Greenhouse lights", symbol: "lightbulb.fill",
                               options: phase.allowedGardenFractions.map { ($0, $0 > 0 ? "\(Int($0 * 16)) h" : "Off") },
                               selection: plan.gardenFraction) { session.setGarden(index, $0) }
                }
                if let research = phase.research {
                    GameChoice(title: researchTitle, symbol: "flask.fill",
                               options: research.levels.map { ($0, $0 > 0 ? (session.definition.missionID == .livingBase ? "\(Int($0)) kWh" : "On") : "Off") },
                               selection: plan.researchLevel) { session.setResearch(index, $0) }
                }
                if session.definition.missionID == .livingBase {
                    Toggle("Same plan every day", isOn: Binding(get: { session.sameSettingsForAllBlocks },
                                                                set: { session.setSameSettingsForAllBlocks($0) }))
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Theme.ink)
                        .tint(GamePalette.go.bottom)
                }
                PowerBalance(session: session, index: index)
                if let notice = session.notice {
                    Label(notice, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.warningInk)
                }
                Button("Done", action: close)
                    .buttonStyle(GameButtonStyle(bevel: GamePalette.go, height: 56))
            }
            .padding(20)
            .padding(.top, 14)
            .frame(maxWidth: 460)
            .background(GameCardBackground(corner: 26))
            .padding(24)
        }
    }

    private var researchTitle: String {
        switch session.definition.missionID {
        case .lightsOut: return "Science observation (1.5 kWh)"
        case .livingBase: return "Research each day"
        default: return "Storm science (needs the kit)"
        }
    }
}

struct GameChoice: View {
    let title: String
    let symbol: String
    let options: [(value: Double, label: String)]
    let selection: Double
    let choose: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(Theme.inkSecondary)
            HStack(spacing: 8) {
                ForEach(options.indices, id: \.self) { i in
                    let option = options[i]
                    let selected = abs(option.value - selection) < 1e-9
                    Button(option.label) { choose(option.value) }
                        .buttonStyle(GameButtonStyle(bevel: selected ? GamePalette.gold : GamePalette.steel, height: 46, font: .game(.headline)))
                        .accessibilityLabel("\(title): \(option.label)")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
}

struct PowerBalance: View {
    let session: MissionSession
    let index: Int

    var body: some View {
        let phase = session.definition.phases[index]
        let plan = session.plan(index)
        let a = session.definition.assumptions
        let light = plan.gardenFraction * a.gardenFullLightHours
        let garden = phase.allowedGardenFractions.isEmpty ? 0
            : (session.science.gardenOperatingPowerKW * light + a.gardenStandbyKW * (24 - light)) / 24
        let demand = a.essentialLoadKW + a.fullGeneratorKW * plan.airFraction + garden + (phase.research?.powerKWPerLevel ?? 0) * plan.researchLevel
        let supply = phase.baseSupplyKW + Double(session.count(.solarArray)) * phase.solarKWPerArray
        let oxygen = a.fullGeneratorKgPerDay * plan.airFraction
        let breathe = Double(session.definition.initial.crewCount) * session.science.oxygenKgPerPersonDay
        let daily = session.definition.missionID == .livingBase
        HStack(spacing: 10) {
            meter("bolt.fill", "Makes", daily ? "\(Format.number(supply * 24)) kWh/day" : Format.kW(supply), Theme.energyInk)
            meter("powerplug.fill", "Uses", daily ? "\(Format.number(demand * 24)) kWh/day" : Format.kW(demand),
                  demand > supply + 1e-9 ? Theme.warningInk : Theme.ink)
            meter("wind", "Air made", "\(Format.number(oxygen)) of \(Format.number(breathe, digits: 2)) kg/day",
                  oxygen + 1e-9 < breathe ? Theme.warningInk : Theme.plantInk)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.panel))
    }

    private func meter(_ symbol: String, _ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Image(systemName: symbol).font(.system(size: 16, weight: .black)).foregroundStyle(color)
            Text(title).font(.system(.caption2, design: .rounded).weight(.heavy)).foregroundStyle(Theme.inkSecondary)
            Text(value).font(.system(.caption, design: .rounded).weight(.black).monospacedDigit()).foregroundStyle(color)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: Prediction

struct BetOverlay: View {
    let session: MissionSession

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().accessibilityHidden(true)
            VStack(spacing: 14) {
                Ribbon(text: "Make a prediction!", bevel: GamePalette.energy)
                    .padding(.top, -34)
                HStack(alignment: .top, spacing: 10) {
                    NovaAvatar(size: 62, talking: true)
                    Text(session.copy.question)
                        .font(.system(.title3, design: .rounded).weight(.heavy))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Label("Guess right to earn a star", systemImage: "star.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.amberInk)
                HStack(spacing: 10) {
                    Button { session.run(predicting: .yes) } label: { Label("Yes", systemImage: "hand.thumbsup.fill") }
                        .buttonStyle(GameButtonStyle(bevel: GamePalette.go, height: 60))
                        .accessibilityLabel("Yes")
                    Button { session.run(predicting: .no) } label: { Label("No", systemImage: "hand.thumbsdown.fill") }
                        .buttonStyle(GameButtonStyle(bevel: GamePalette.coral, height: 60))
                        .accessibilityLabel("No")
                }
                Button { session.run(predicting: .unsure) } label: { Text("Not sure") }
                    .buttonStyle(GameButtonStyle(bevel: GamePalette.steel, height: 48, font: .game(.headline)))
                    .accessibilityLabel("Not sure")
                Button("Change my plan") { session.backToPlanning() }
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.energyInk)
                    .frame(minHeight: 44)
            }
            .padding(20)
            .padding(.top, 14)
            .frame(maxWidth: 460)
            .background(GameCardBackground(corner: 26))
            .padding(24)
        }
    }
}

// MARK: Results

struct ResultOverlay: View {
    let model: AppModel
    let session: MissionSession
    @State private var showWhy = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let success = session.explanation?.success ?? false
        let stars = session.stars ?? StarResult(finished: false, predicted: false, bonus: false)
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().accessibilityHidden(true)
            if success && !reduceMotion {
                ConfettiView().ignoresSafeArea()
            }
            ScrollView {
                VStack(spacing: 14) {
                    Ribbon(text: success ? "DRILL COMPLETE!" : "NOT YET!", bevel: success ? GamePalette.go : GamePalette.coral, font: .game(.title))
                        .padding(.top, -38)
                    Text(session.explanation?.headline ?? "")
                        .font(.game(.title3))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                    HStack(alignment: .top, spacing: 8) {
                        StarSlot(filled: stars.finished, label: "Finish the drill", delay: 0.25)
                        StarSlot(filled: stars.predicted, label: "Predict it right", delay: 0.55)
                        StarSlot(filled: stars.bonus, label: session.gameCopy.bonusStar, delay: 0.85)
                    }
                    if let unlock = session.unlockText {
                        Label(unlock, systemImage: "gift.fill")
                            .font(.system(.headline, design: .rounded).weight(.black))
                            .gameText()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(LinearGradient(colors: [GamePalette.gold.top, GamePalette.gold.bottom], startPoint: .top, endPoint: .bottom)))
                    }
                    NovaBubble(text: explanationLead, compact: true)
                    if let right = session.predictionWasRight, let prediction = session.prediction {
                        Label(right ? "You predicted \"\(prediction.label)\". Good thinking!" : "You predicted \"\(prediction.label)\". Now you know why!",
                              systemImage: right ? "brain.head.profile" : "sparkles")
                            .font(.system(.subheadline, design: .rounded).weight(.heavy))
                            .foregroundStyle(Theme.ink)
                    }
                    if !success {
                        Label(session.copy.hint, systemImage: "lightbulb.fill")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.ink)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: 0xFFF4D6)))
                    }
                    whySection
                    if let previous = session.previousAttempt, let current = session.currentAttempt {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last try vs this try").font(.system(.subheadline, design: .rounded).weight(.black)).foregroundStyle(Theme.ink)
                            AttemptLine(title: "Last", summary: previous)
                            AttemptLine(title: "Now", summary: current)
                            Text("Same starting supplies both times.").font(.caption).foregroundStyle(Theme.inkSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.panel))
                    }
                    HStack(spacing: 10) {
                        if success {
                            Button("Replay") { session.retry() }
                                .buttonStyle(GameButtonStyle(bevel: GamePalette.steel))
                            Button { model.leaveMission() } label: { Label("Continue", systemImage: "arrow.right") }
                                .buttonStyle(GameButtonStyle(bevel: GamePalette.go))
                                .accessibilityLabel("Continue")
                        } else {
                            Button("Base") { model.leaveMission() }
                                .buttonStyle(GameButtonStyle(bevel: GamePalette.steel))
                            Button { session.retry() } label: { Label("Try again", systemImage: "arrow.counterclockwise") }
                                .buttonStyle(GameButtonStyle(bevel: GamePalette.gold))
                                .accessibilityLabel("Try again")
                        }
                    }
                }
                .padding(20)
                .padding(.top, 18)
                .frame(maxWidth: 520)
                .background(GameCardBackground(corner: 28))
                .padding(.horizontal, 18)
                .padding(.vertical, 50)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { success ? Haptics.success() : Haptics.warning() }
    }

    private var explanationLead: String {
        let paragraphs = session.explanation?.paragraphs ?? []
        return paragraphs.prefix(2).joined(separator: " ")
    }

    @ViewBuilder private var whySection: some View {
        if let e = session.explanation {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showWhy.toggle() }
                } label: {
                    Label(showWhy ? "Hide the numbers" : "Why? See the numbers", systemImage: "magnifyingglass")
                        .font(.system(.subheadline, design: .rounded).weight(.black))
                        .foregroundStyle(Theme.energyInk)
                        .frame(minHeight: 44)
                }
                if showWhy {
                    ForEach(e.numbers, id: \.self) { row in
                        HStack {
                            Text(row.label).foregroundStyle(Theme.inkSecondary)
                            Spacer()
                            Text(row.value).font(.body.weight(.bold).monospacedDigit()).foregroundStyle(Theme.ink)
                        }
                        .font(.system(.subheadline, design: .rounded))
                        .accessibilityElement(children: .combine)
                    }
                    ForEach(Array(e.paragraphs.dropFirst(2)), id: \.self) { paragraph in
                        Text(paragraph).font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.ink)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct AttemptLine: View {
    let title: String
    let summary: AttemptSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label("\(title): \(summary.headline)", systemImage: summary.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(summary.success ? Theme.plantInk : Theme.warningInk)
            Text(summary.setup).font(.caption).foregroundStyle(Theme.inkSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}
