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
    @State private var showSettings = false
    @State private var planOpen = false
    @State private var planningPhase = 0
    @Environment(\.appReduceMotion) private var reduceMotion
    @Environment(\.focusView) private var focusView
    @Environment(\.dynamicTypeSize) private var textSize
    @AccessibilityFocusState private var launchFocused: Bool

    /// True while a dialog covers the drill; the controls underneath are hidden from VoiceOver.
    private var overlayShown: Bool {
        session.stage == .predicting || session.stage == .results || (planPhase != nil && session.stage == .planning)
    }

    /// What Read aloud says for the current moment. The same words are always on screen.
    private var narrationText: String {
        switch session.stage {
        case .briefing, .planning:
            return session.novaLine
        case .predicting:
            return session.copy.question
        case .playback:
            guard let checkpoint = session.currentCheckpoint else { return "" }
            return "\(checkpoint.title). \(checkpoint.text)"
        case .results:
            let lead = (session.explanation?.paragraphs ?? []).prefix(2).joined(separator: " ")
            return [session.explanation?.headline ?? "", lead].filter { !$0.isEmpty }.joined(separator: ". ")
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                WorldView(coordinator: model.missionWorld, isActive: isActive, summary: session.worldSummary)
                    .ignoresSafeArea()
                    .accessibilityHidden(overlayShown)
                VStack(spacing: 0) {
                    if !(textSize.isAccessibilitySize && session.stage == .planning) {
                        missionHUD
                            .readHeight { height in
                                topHeight = height + proxy.safeAreaInsets.top
                                updateInsets()
                            }
                    }
                    Spacer(minLength: 0)
                    Group {
                        if session.stage == .planning {
                            VStack(spacing: 10) {
                                if textSize.isAccessibilitySize {
                                    // Let the title and resource summary scroll away so the plan
                                    // retains its reading space at the largest text sizes.
                                    ScrollView {
                                        VStack(spacing: 16) {
                                            missionHUD
                                            bottomArea.padding(.bottom, 6)
                                        }
                                    }
                                    .onAppear { topHeight = 0; updateInsets() }
                                } else if !session.isRover {
                                    MissionPlanningWorkspace(model: model, session: session,
                                                             planOpen: $planOpen, phaseIndex: $planningPhase,
                                                             narrow: proxy.size.width < 600,
                                                             panelMaxHeight: min(340, proxy.size.height * 0.3),
                                                             openPlan: { planPhase = $0 }) {
                                        launchControl(prominent: proxy.size.width >= 600)
                                    }
                                } else {
                                    ViewThatFits(in: .vertical) {
                                        bottomArea
                                        ScrollView { bottomArea.padding(.bottom, 6) }
                                            .frame(maxHeight: max(140, proxy.size.height * 0.52))
                                    }
                                }
                                if textSize.isAccessibilitySize || session.isRover { launchControl() }
                            }
                        } else {
                            ViewThatFits(in: .vertical) {
                                bottomArea
                                ScrollView { bottomArea.padding(.bottom, 4) }
                                    .frame(maxHeight: proxy.size.height * 0.55)
                            }
                        }
                    }
                        .frame(maxWidth: 860)
                        .readHeight { height in
                            bottomHeight = height + proxy.safeAreaInsets.bottom
                            updateInsets()
                        }
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 6)
                .accessibilityHidden(overlayShown)

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
                        .transition(reduceMotion ? .opacity : .scale(scale: 2.2).combined(with: .opacity))
                        .allowsHitTesting(false)
                        .zIndex(4)
                        .accessibilityLabel(number == 0 ? "Go" : "\(number)")
                }
                if session.stage == .predicting {
                    BetOverlay(session: session, readAloud: model.readAloud).transition(.opacity).zIndex(5)
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
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75), value: planPhase)
        }
        .onChange(of: session.currentStep?.phaseID) { _, newPhase in
            guard session.stage == .playback, session.countdown == nil, let newPhase,
                  session.definition.missionID != .livingBase else { return }
            showBanner(for: newPhase)
        }
        .onChange(of: isActive) { _, active in
            session.setAppActive(active)
            if !active { Narrator.shared.stop() }
        }
        .onChange(of: narrationText, initial: true) { _, text in
            guard model.readAloud else { return }
            text.isEmpty ? Narrator.shared.stop() : Narrator.shared.speak(text)
        }
        .onChange(of: session.replayToken) { _, _ in
            if model.readAloud { Narrator.shared.speak(narrationText) }
        }
        .onDisappear { Narrator.shared.stop(); model.missionWorld.setPlanningFocus(false) }
        .onChange(of: session.stage, initial: true) { _, stage in
            if stage == .planning { model.missionWorld.setPlanningFocus(!session.isRover) }
            else if stage == .playback { model.missionWorld.setPlanningFocus(false) }
        }
        // Return VoiceOver focus to the main action when a dialog closes.
        .onChange(of: planPhase) { old, new in
            if old != nil, new == nil { launchFocused = true }
        }
        .onChange(of: session.stage) { old, new in
            if new == .planning, old == .predicting || old == .results { launchFocused = true }
        }
        .sheet(isPresented: $showSettings) { SettingsView(model: model) }
        .onChange(of: session.countdown) { old, value in
            if let value {
                Haptics.thump()
                SoundFX.shared.play(value == 0 ? .go : .tick)
            }
            if old != nil, value == nil, session.stage == .playback, let phase = session.currentStep?.phaseID,
               session.definition.missionID != .livingBase {
                showBanner(for: phase)
            }
        }
        .sheet(isPresented: $showSources) { SourcesView(package: package, focus: session.definition) }
    }

    private var missionHUD: some View {
        MissionTopHUD(session: session, readAloud: model.readAloud, narration: narrationText,
                      onBack: { model.leaveMission() }, onSources: { showSources = true },
                      onSettings: { showSettings = true })
    }

    private func updateInsets() {
        // While a dialog covers the screen there are no bottom controls to measure. Keep the world framed
        // as it was, so it does not shrink or jump behind the dialog.
        guard session.stage != .predicting, session.stage != .results else { return }
        model.missionWorld.setHUDInsets(top: topHeight + 4, bottom: bottomHeight + 4)
    }

    private func showBanner(for phaseID: String) {
        let text: String
        switch phaseID {
        case "sunlit": text = "SUNLIGHT"
        case "shadow": text = "SHADOW DRILL"
        case "assembly": text = session.baseTest?.kind == .storm ? "PREPARE SHELTER" : "BUILD SHELTER"
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
            VStack(spacing: 24) {
                NovaBubble(text: session.novaLine, actionLabel: session.isLastIntroLine ? nil : "Tap for more") {
                    session.advanceIntro()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(session.isLastIntroLine ? "Let's build!" : "Next") { session.advanceIntro() }
                    .buttonStyle(GameButtonStyle(bevel: session.isLastIntroLine ? GamePalette.go : GamePalette.gold, height: 60))
            }
        case .planning:
            VStack(spacing: 16) {
                if session.resumedFromDraft {
                    HStack(spacing: 8) {
                        Label("You were working on this plan. Pick up where you left off.", systemImage: "arrow.uturn.backward.circle.fill")
                            .font(.system(.subheadline, design: .rounded).weight(.heavy))
                            .gameText()
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Button("OK") { session.resumedFromDraft = false }
                            .font(.system(.subheadline, design: .rounded).weight(.black))
                            .foregroundStyle(Color(hex: 0xFFE27A))
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .padding(.horizontal, 12)
                    .background(Capsule().fill(GamePalette.hud))
                }
                NovaBubble(text: session.novaLine, compact: true) {
                    if session.tutorial == .powered {
                        session.dismissTutorial()
                    } else if session.tutorial == .done {
                        session.hintVisible.toggle()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if session.baseTest?.isExample == true { ExampleLabControls(model: model, kind: session.baseTest?.kind ?? .shadow) }
                InvestigationReminder(session: session)
                BuildTray(session: session) { planPhase = $0 }
            }
        case .playback:
            PlaybackPanel(session: session)
        case .predicting, .results:
            EmptyView()
        }
    }
    /// `prominent` is the big corner button beside the shop bar, like a building game's battle button.
    private func launchControl(prominent: Bool = false) -> some View {
        Button {
            session.goToPrediction()
        } label: {
            if textSize.isAccessibilitySize {
                Text("Launch test")
            } else if prominent {
                VStack(spacing: 4) {
                    Image(systemName: "flame.fill").font(.system(size: 34, weight: .black))
                    Text("Launch test")
                }
            } else {
                Label("Launch test", systemImage: "flame.fill")
            }
        }
        .buttonStyle(GameButtonStyle(bevel: GamePalette.go, height: prominent ? 132 : 62,
                                     font: .game(textSize.isAccessibilitySize ? .headline : prominent ? .title3 : .title2)))
        .accessibilityLabel("Launch test")
        .disabled(!session.canLaunch)
        .accessibilityFocused($launchFocused)
        .accessibilityHint(session.canLaunch ? "Then you predict what will happen" : "Finish the plan first")
    }

}

// MARK: Top HUD

struct MissionTopHUD: View {
    let session: MissionSession
    let readAloud: Bool
    let narration: String
    let onBack: () -> Void
    let onSources: () -> Void
    let onSettings: () -> Void
    @Environment(\.focusView) private var focusView
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        if textSize.isAccessibilitySize {
            compactHeader
        } else {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                RoundIconButton(symbol: "chevron.backward", label: "Leave drill", action: onBack)
                VStack(alignment: .leading, spacing: 0) {
                    Text(session.gameCopy.title).font(.game(.headline)).gameText().lineLimit(1)
                    Text(session.definition.drillLabel)
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .gameText(Color(hex: 0xFFE27A))
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                ReadAloudButton(enabled: readAloud, text: narration)
                if session.stage == .playback {
                    RoundIconButton(symbol: "forward.end.fill", label: "Skip to the result", bevel: GamePalette.gold) { session.skipPlayback() }
                } else {
                    RoundIconButton(symbol: "books.vertical.fill", label: "Where the numbers come from", action: onSources)
                    RoundIconButton(symbol: "gearshape.fill", label: "Settings", action: onSettings)
                }
            }
            MissionStepsBar(session: session, emphasized: focusView)
            pills
            if session.stage == .playback && !session.isRover && session.countdown == nil {
                TimelineStrip(session: session)
            }
        }
        }
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.gameCopy.title).font(.headline.weight(.bold)).foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                RoundIconButton(symbol: "chevron.backward", label: "Leave drill", action: onBack)
                RoundIconButton(symbol: "books.vertical.fill", label: "Where the numbers come from", action: onSources)
                RoundIconButton(symbol: "gearshape.fill", label: "Settings", action: onSettings)
                if session.stage == .playback {
                    RoundIconButton(symbol: "forward.end.fill", label: "Skip to the result", bevel: GamePalette.gold) { session.skipPlayback() }
                }
            }
            if !session.isRover {
                let state = session.displayState
                let air = ResourceEngine.airHours(oxygenKg: state.oxygenKg, crewCount: session.definition.initial.crewCount, science: session.science)
                Text("Energy: \(Format.kWh(state.batteryKWh)). Air: \(Format.wholeHours(air)).")
                    .font(.caption).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 14).fill(GamePalette.hud))
    }

    private var pills: some View {
        // Wraps onto two rows at large text sizes instead of shrinking the numbers.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { pillItems }
            VStack(alignment: .leading, spacing: 6) { pillItems }
        }
    }

    @ViewBuilder private var pillItems: some View {
        let d = session.definition
        let state = session.displayState
        let focus = session.currentCheckpoint?.focus
        Group {
            if !d.catalog.isEmpty && session.stage != .playback && !session.isBaseTest {
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
                             value: state.batteryCapacityKWh > 0
                                ? "\(Format.number(state.batteryKWh))/\(Format.number(state.batteryCapacityKWh, digits: 0)) kWh"
                                : "No battery",
                             label: "Battery",
                             fraction: state.batteryCapacityKWh > 0 ? state.batteryKWh / state.batteryCapacityKWh : 0,
                             warning: failure == .energyShortage,
                             highlighted: focus == .battery || focus == .arrays)
                let hours = ResourceEngine.airHours(oxygenKg: state.oxygenKg, crewCount: d.initial.crewCount, science: session.science)
                let full = ResourceEngine.airHours(oxygenKg: state.oxygenCapacityKg, crewCount: d.initial.crewCount, science: session.science)
                ResourcePill(symbol: "wind", bevel: GamePalette.steel, value: "\(Int(hours.rounded(.down))) h air", label: "Air in the tank",
                             fraction: full > 0 ? hours / full : 0,
                             warning: failure == .oxygenExhausted || (session.stage != .planning && hours < d.success.minimumAirHours),
                             highlighted: focus == .air)
                if d.hasGarden {
                    ResourcePill(symbol: "leaf.fill", bevel: GamePalette.go,
                                 value: "\(Format.number(state.cropGrowthDays, digits: 0))/\(Format.number(session.science.cropReferenceDays, digits: 0)) d",
                                 label: "Lettuce growth days",
                                 fraction: state.cropGrowthDays / session.science.cropReferenceDays,
                                 highlighted: focus == .crop)
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
        VStack(spacing: 12) {
            if session.isRover {
                RoverTray(session: session)
            } else {
                PlanningGuide(session: session)
                if session.isBaseTest {
                    BaseGearCard(session: session)
                } else if !session.definition.catalog.isEmpty {
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(session.definition.catalog) { item in
                                BuildCard(session: session, item: item,
                                          highlighted: session.tutorial == .placeFirstArray && item.kind == .solarArray,
                                          dimmed: session.tutorial == .placeFirstArray && item.kind != .solarArray)
                            }
                        }.padding(8)
                    }
                    .accessibilityIdentifier("mission.cargoTray")
                }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) { phaseCards(fullWidth: false) }
                    VStack(spacing: 12) { phaseCards(fullWidth: true) }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .shake(session.shakeToken)
        .animation(.default, value: session.shakeToken)
    }

    @ViewBuilder private func phaseCards(fullWidth: Bool) -> some View {
        ForEach(planIndices, id: \.self) { index in
            Group {
                if session.definition.missionID == .livingBase {
                    PlanCard(session: session, index: index) { openPlan(index) }
                } else {
                    QuickPlanCard(session: session, index: index, openDetails: { openPlan(index) }, fullWidth: fullWidth)
                }
            }
            .overlay {
                if session.revisionPhaseIndex == index {
                    RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.amber, lineWidth: 3).allowsHitTesting(false)
                }
            }
            .disabled(session.tutorial == .placeFirstArray)
            .opacity(session.tutorial == .placeFirstArray ? 0.5 : 1)
        }
    }

    private var planIndices: [Int] {
        if session.definition.missionID == .livingBase && session.sameSettingsForAllBlocks { return [0] }
        return Array(session.definition.phases.indices)
    }
}

/// "Test My Base" has no lander: the tray shows the equipment the player's real base already has.
struct BaseGearCard: View {
    let session: MissionSession
    var embedded = false
    @State private var showRules = false
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        let gear = session.baseTest?.inputs ?? BaseTestInputs(arrays: 0, batteries: 0)
        let storm = session.baseTest?.kind == .storm
        let batteries = "\(gear.batteries) \(gear.batteries == 1 ? "battery" : "batteries")"
        VStack(alignment: .leading, spacing: 8) {
            let headingLayout = textSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(alignment: .top))
            headingLayout {
                Label(session.baseTest?.isExample == true ? "Example equipment" : "Your equipment", systemImage: "house.fill")
                    .font(.headline)
                if !textSize.isAccessibilitySize { Spacer(minLength: 4) }
                Button("How this test works", systemImage: "info.circle") { showRules = true }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("mission.testRules")
            }
            Text(storm
                 ? "\(gear.shelter == true ? "Working shelter" : "No shelter") • \(batteries) • \(Format.kWh(session.definition.initial.batteryKWh)) charged"
                 : "\(gear.arrays) solar \(gear.arrays == 1 ? "array" : "arrays") • \(batteries) • Batteries start empty")
                .font(.subheadline.weight(.semibold))
            if storm {
                Text("Preparation: \(Format.kWh(session.definition.item(.shelterKit)?.assemblyEnergyKWh ?? 0)). Backup power: \(Format.kW(session.definition.phases.first?.baseSupplyKW ?? 0)).")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
                    .accessibilityIdentifier("mission.stormPreparation")
            }
        }
        .foregroundStyle(Theme.ink)
        .fixedSize(horizontal: false, vertical: true)
        .padding(embedded ? 0 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { if !embedded { GameCardBackground() } }
        .sheet(isPresented: $showRules) { BaseTestRulesSheet(session: session) { showRules = false } }
    }
}

/// On the result of a base test: what the base had, how it compares with the last saved test, and the
/// rules that turned buildings into numbers.
struct ExampleLabControls: View {
    let model: AppModel
    let kind: BaseTestKind
    var compact = false

    private var choices: some View {
        ForEach(kind == .storm ? [.starter, .moreStorage] : ExampleBase.allCases, id: \.self) { preset in
            let current = model.session?.baseTest?.inputs
            let selected = current?.arrays == preset.inputs.arrays && current?.batteries == preset.inputs.batteries
            let arrays = "\(preset.inputs.arrays) \(preset.inputs.arrays == 1 ? "array" : "arrays")"
            let batteries = "\(preset.inputs.batteries) \(preset.inputs.batteries == 1 ? "battery" : "batteries")"
            Button {
                model.openExampleMission(preset, resetHistory: false, kind: kind)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Label(preset.title, systemImage: selected ? "checkmark.circle.fill" : "circle")
                    Text(kind == .storm ? batteries : "\(arrays) • \(batteries)")
                        .font(.caption2)
                }
                .frame(minHeight: 44)
            }
            .font(.system(.caption, design: .rounded).weight(.bold))
            .buttonStyle(.borderedProminent).tint(Theme.energyInk).foregroundStyle(.white)
            .accessibilityLabel(preset.title)
            .accessibilityIdentifier("example.\(preset.rawValue)")
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(compact ? "Choose an equipment setup" : "Example lab • choose equipment, keep your settings")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
            ViewThatFits {
                HStack { choices }
                VStack(alignment: .leading) { choices }
            }
            Text(compact ? "Your operating settings stay the same." : "Air and science settings stay the same. No campaign progress is saved.")
                .font(.caption)
            Button("Reset lab to starter plan", systemImage: "arrow.counterclockwise") {
                model.openExampleMission(.starter, resetHistory: true, kind: kind)
            }
            .font(.caption.weight(.bold)).foregroundStyle(Theme.energyInk).frame(minHeight: 44)
            .accessibilityIdentifier("example.reset")
        }
        .foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
        .padding(compact ? 0 : 10).background { if !compact { GameCardBackground() } }
    }
}

struct BaseTestCard: View {
    let session: MissionSession

    private func resultLine(_ title: String, _ record: BaseTestRecord) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(title): \(record.success ? "passed" : "stopped") • \(record.timeSummary)")
                .fontWeight(.bold)
            Text(record.inputs.summary)
            Text("Air maker: \(MissionSession.airLabel(record.airSunlight)) then \(MissionSession.airLabel(record.airShadow)). Science: \(record.observation ? "On" : "Off") then \(record.scienceDeclining == true ? "On" : "Off").")
            if record.kind == .storm {
                Text("Archive: \(record.eventID ?? "unknown"). Science supplied: \(Format.kWh(record.scienceEnergyKWh ?? 0)).")
            }
            Text("At that stopping time: \(Format.kWh(record.finalBatteryKWh)) energy; \(Format.wholeHours(record.finalAirHours)) of stored oxygen.")
        }
        .font(.system(.caption, design: .rounded))
        .accessibilityElement(children: .combine)
    }

    var body: some View {
        if let context = session.baseTest {
            VStack(alignment: .leading, spacing: 8) {
                Label(context.isExample ? "Example experiment" : "Your base experiment", systemImage: "house.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.black))
                if let current = session.currentBaseRecord {
                    resultLine("Now", current)
                    if let spent = current.oxygenSpentKg, let saved = current.energySavedKWh, spent > 1e-9 {
                        Text("The reserve cost: saved \(Format.kWh(saved)) vs Full air, spent \(Format.kg(spent)) from the oxygen tank during this run.")
                            .font(.subheadline).fontWeight(.bold)
                    }
                    if let previous = session.previousBaseRecord {
                        Divider()
                        resultLine("Last", previous)
                        Text(BaseExperiment.change(from: previous.inputs, to: current.inputs))
                            .font(.subheadline).fontWeight(.bold)
                        Text(context.kind == .storm
                             ? "Same archived event and starting air; batteries start charged each test. Compare stopping times before reserves."
                             : "Every shadow test restarts with the same air supply and empty batteries. Compare the stopping times before comparing reserves.")
                            .font(.caption)
                    }
                }
                if context.kind == .storm {
                    Text("Game rules: \(Format.kWh(session.definition.initial.batteryKWh)) charged storage; 3 kWh shelter preparation; 0.8 kW backup supply independent of arrays. The training station supplies the science instrument. No radiation dose is calculated.")
                        .font(.caption)
                } else {
                Text("Game rules: \(Format.kW((session.definition.phases.map(\.solarKWPerArray).max() ?? 0) * Double(context.inputs.arrays))) of sunlight power; \(Format.kWh((session.definition.item(.battery)?.batteryCapacityKWh ?? 0) * Double(context.inputs.batteries))) of storage. Each counts the same; positions and decoration change nothing.")
                        .font(.caption)
                }
            }
            .foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panel))
        }
    }
}

struct BuildCard: View {
    let session: MissionSession
    let item: CargoItem
    var highlighted = false
    var dimmed = false
    @ScaledMetric(relativeTo: .footnote) private var cardWidth: CGFloat = 148

    var body: some View {
        let count = session.count(item.kind)
        let name = CargoCopy.name(item.kind)
        VStack(spacing: 8) {
            CargoIconView(kind: item.kind).frame(height: 64).accessibilityHidden(true)
            Text(name).font(.system(.footnote, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.ink).multilineTextAlignment(.center)
            Label("\(item.cost) crate\(item.cost == 1 ? "" : "s") each", systemImage: "shippingbox")
                .font(.caption).foregroundStyle(Theme.inkSecondary)
            HStack(spacing: 6) {
                Button {
                    session.removeCargo(item.kind)
                    SoundFX.shared.play(.remove)
                } label: {
                    Image(systemName: "minus").font(.headline).frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.panel))
                }
                .disabled(count == 0 || session.tutorial == .placeFirstArray)
                .accessibilityLabel("Remove \(name.lowercased())")
                .accessibilityIdentifier("cargo.remove.\(item.kind.rawValue)")
                Text("\(count)").font(.game(.headline)).monospacedDigit().frame(minWidth: 24)
                    .accessibilityLabel("\(count) on board")
                Button {
                    if session.addCargo(item.kind) { Haptics.thump(); SoundFX.shared.play(.pop) }
                    else { Haptics.warning(); SoundFX.shared.play(.denied) }
                } label: {
                    Image(systemName: "plus").font(.headline).frame(width: 44, height: 44)
                        .foregroundStyle(.white)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.energyInk))
                }
                .disabled(dimmed)
                .accessibilityLabel("Add \(name.lowercased())")
                .accessibilityValue("\(count) on board, costs \(item.cost) crate\(item.cost == 1 ? "" : "s")")
                .accessibilityIdentifier("cargo.add.\(item.kind.rawValue)")
            }.buttonStyle(.plain).tint(Theme.energyInk)
        }
        .padding(12).frame(width: cardWidth)
        .background(RoundedRectangle(cornerRadius: 18).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(highlighted ? Theme.amber : count > 0 ? Theme.energyInk : Theme.panelLine, lineWidth: highlighted ? 3 : 1.5))
        .opacity(dimmed ? 0.45 : 1)
        .accessibilityElement(children: .contain)
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
    @ScaledMetric(relativeTo: .footnote) private var cardWidth: CGFloat = 124
    @ScaledMetric(relativeTo: .footnote) private var cardHeight: CGFloat = 146

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
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 1) {
                    status("wind", MissionSession.airLabel(plan.airFraction))
                    if !phase.allowedGardenFractions.isEmpty {
                        status("lightbulb.fill", PlanCard.lightLabel(session, plan.gardenFraction))
                    }
                    if phase.research != nil {
                        status("flask.fill", plan.researchLevel > 0 ? (session.definition.missionID == .livingBase ? "\(Int(plan.researchLevel)) kWh" : "On") : "Off")
                    }
                }
            }
            .padding(10)
            .frame(width: cardWidth)
            .frame(minHeight: cardHeight)
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

    /// Greenhouse light hours from the drill's own assumption (not a fixed 16).
    static func lightLabel(_ session: MissionSession, _ fraction: Double) -> String {
        fraction > 0 ? "\(Format.number(fraction * session.definition.assumptions.gardenFullLightHours)) h" : "Off"
    }

    static func title(_ session: MissionSession, _ index: Int) -> String {
        if session.definition.missionID == .livingBase {
            if session.sameSettingsForAllBlocks { return "Every day" }
            // Day ranges come from the block lengths, so a different crop reference changes them too.
            let phases = session.definition.phases
            let startHour = phases.prefix(index).reduce(0) { $0 + $1.durationHours }
            let first = Int((startHour / 24).rounded()) + 1
            let last = Int(((startHour + phases[index].durationHours) / 24).rounded())
            return "Days \(first)–\(last)"
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

/// A plan card with its switches right on it. One tap changes the air maker or the science, and the
/// card says at once what that does to the battery and the air. The full numbers are one tap away.
struct QuickPlanCard: View {
    let session: MissionSession
    let index: Int
    let openDetails: () -> Void
    var fullWidth = false
    var embedded = false
    @ScaledMetric(relativeTo: .footnote) private var cardWidth: CGFloat = 270

    var body: some View {
        let phase = session.definition.phases[index]
        let plan = session.plan(index)
        let a = session.definition.assumptions
        let rates = ResourceEngine.rates(definition: session.definition, configuration: session.configuration,
                                         phaseIndex: index, science: session.science)
        let draining = rates.netKW < -1e-9
        let fromTank = rates.oxygenNetPerHour < -1e-9
        let title = PlanCard.title(session, index)
        VStack(alignment: .leading, spacing: 6) {
            if session.revisionPhaseIndex == index {
                Label("Suggested part for your next test", systemImage: "lightbulb.fill")
                    .font(.caption.weight(.bold)).foregroundStyle(Theme.amberInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !embedded {
                HStack(spacing: 8) {
                    Image(systemName: PlanCard.icon(phase.mood))
                        .font(.system(size: 17, weight: .black))
                        .gameText()
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(PlanCard.bevel(phase.mood).bottom))
                        .accessibilityHidden(true)
                    Text("\(index + 1). \(title)")
                        .font(.game(.subheadline))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button(action: openDetails) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Theme.energyInk)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("\(title) plan")
                    .accessibilityHint("Shows the numbers for this part")
                }
            }
            Text("\(Format.hours(phase.durationHours)) • \(phase.mood == .shadow ? "No solar electricity" : phase.mood == .sunlit ? "Solar arrays can charge batteries" : "Follow this part of your plan")")
                .font(.caption).foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Label("Air maker", systemImage: "wind")
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .foregroundStyle(Theme.inkSecondary)
            HStack(spacing: 6) {
                ForEach(phase.allowedAirFractions, id: \.self) { value in
                    chip(MissionSession.airLabel(value), selected: abs(value - plan.airFraction) < 1e-9,
                         label: "\(title), air maker: \(MissionSession.airLabel(value))") {
                        session.setAir(index, value)
                    }
                }
            }
            Text(plan.airFraction == 0 ? "Off: the crew breathes from the oxygen tank."
                 : plan.airFraction < 1 ? "Half: saves power; the tank supplies the missing oxygen."
                 : "Full: makes more oxygen and uses more power.")
                .font(.caption).foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let research = phase.research {
                Text(session.baseTest?.kind == .storm ? "Science task • required, uses extra power" : "Extra science • optional, uses extra power")
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    ForEach([false, true], id: \.self) { on in
                        chip(on ? "Science On" : "Science Off", selected: (plan.researchLevel > 0) == on,
                             label: "\(title), science: \(on ? "on" : "off")") {
                            session.setResearch(index, on ? (research.levels.max() ?? 1) : 0)
                        }
                    }
                }
            }
            Label(draining ? "Battery energy is being used" : rates.netKW > 1e-9 ? "Spare power can charge batteries" : "Power in matches power used",
                  systemImage: draining ? "battery.25percent" : "bolt.fill")
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .foregroundStyle(draining ? Theme.warningInk : Theme.plantInk)
                .fixedSize(horizontal: false, vertical: true)
            Label(fromTank ? "The crew uses some tank oxygen" : "The air maker covers the crew's needs",
                  systemImage: fromTank ? "lungs.fill" : "checkmark.circle.fill")
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .foregroundStyle(fromTank ? Theme.warningInk : Theme.plantInk)
                .fixedSize(horizontal: false, vertical: true)
            if plan.airFraction < 1 {
                Text("Over this part: save \(Format.kWh(a.fullGeneratorKW * (1 - plan.airFraction) * phase.durationHours)); withdraw \(Format.kg(max(0, -rates.oxygenNetPerHour) * phase.durationHours)) of oxygen if it runs for the full time.")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(width: fullWidth ? nil : cardWidth, alignment: .leading)
        .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background { if !embedded { GameCardBackground() } }
        .accessibilityElement(children: .contain)
    }

    private func chip(_ text: String, selected: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            SoundFX.shared.play(.tap)
            action()
        } label: {
            Text(text)
                .font(.system(.subheadline, design: .rounded).weight(.black))
                .foregroundStyle(selected ? Color.white : Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(selected ? Theme.energyInk : Theme.panel))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Color.white.opacity(0.7) : Theme.panelLine, lineWidth: 1.5))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct RoverTray: View {
    let session: MissionSession
    @ScaledMetric(relativeTo: .footnote) private var cardWidth: CGFloat = 118
    @ScaledMetric(relativeTo: .footnote) private var cardHeight: CGFloat = 150
    @ScaledMetric(relativeTo: .caption) private var markerWidth: CGFloat = 150

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
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: markerWidth)
                    ForEach(rover.markerChoicesM, id: \.self) { marker in
                        let selected = abs((session.roverConfiguration.observedMarkerM ?? -1) - marker) < 1e-9
                        Button(Format.meters(marker)) { session.setMarker(marker) }
                            .buttonStyle(GameButtonStyle(bevel: selected ? GamePalette.gold : GamePalette.steel, height: 34, font: .game(.subheadline)))
                            .frame(width: markerWidth * 0.8)
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
            SoundFX.shared.play(.pop)
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
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 3) {
                    Image(systemName: "shippingbox.fill")
                    Text(cost == 0 ? "Free" : "\(cost)")
                }
                .font(.system(.caption, design: .rounded).weight(.black))
                .foregroundStyle(Theme.amberInk)
            }
            .padding(10)
            .frame(width: cardWidth)
            .frame(minHeight: cardHeight)
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
    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture(perform: close).accessibilityHidden(true)
            ViewThatFits(in: .vertical) {
                card
                ScrollView { card.padding(.vertical, 30) }
            }
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { titleFocused = true } }
        .accessibilityAction(.escape, close)
    }

    private var card: some View {
        let phase = session.definition.phases[index]
        let plan = session.plan(index)
        return VStack(spacing: 14) {
                Ribbon(text: PlanCard.title(session, index), bevel: PlanCard.bevel(phase.mood))
                    .padding(.top, -34)
                    .accessibilityFocused($titleFocused)
                GameChoice(title: "Air maker", symbol: "wind",
                           options: phase.allowedAirFractions.map { ($0, MissionSession.airLabel($0)) },
                           selection: plan.airFraction) { session.setAir(index, $0) }
                if !phase.allowedGardenFractions.isEmpty {
                    GameChoice(title: "Greenhouse lights", symbol: "lightbulb.fill",
                               options: phase.allowedGardenFractions.map { ($0, PlanCard.lightLabel(session, $0)) },
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
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
    }

    private var researchTitle: String {
        switch session.definition.missionID {
        case .lightsOut:
            let phase = session.definition.phases[index]
            return "Science observation (\(Words.kWh((phase.research?.powerKWPerLevel ?? 0) * phase.durationHours)))"
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
            // Side by side when they fit; stacked at large text sizes.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { buttons }
                VStack(spacing: 6) { buttons }
            }
        }
    }

    @ViewBuilder private var buttons: some View {
        ForEach(options.indices, id: \.self) { i in
            let option = options[i]
            let selected = abs(option.value - selection) < 1e-9
            Button {
                choose(option.value)
            } label: {
                Label(option.label, systemImage: selected ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(GameButtonStyle(bevel: selected ? GamePalette.gold : GamePalette.steel, height: 46, font: .game(.headline)))
            .accessibilityLabel("\(title): \(option.label)")
            .accessibilityAddTraits(selected ? .isSelected : [])
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
            // Power (kW) is a rate; the garden drill shows a day's energy (kWh) instead, so the labels say which.
            meter("bolt.fill", daily ? "Energy made" : "Power in", daily ? "\(Format.number(supply * 24)) kWh/day" : Format.kW(supply), Theme.energyInk)
            meter("powerplug.fill", daily ? "Energy used" : "Power used", daily ? "\(Format.number(demand * 24)) kWh/day" : Format.kW(demand),
                  demand > supply + 1e-9 ? Theme.warningInk : Theme.ink)
            meter("wind", "Air made", "\(Format.number(oxygen)) of \(Format.number(breathe, digits: 2)) kg/day",
                  oxygen + 1e-9 < breathe ? Theme.warningInk : Theme.plantInk)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.panel))
        .accessibilityHint(UnitHelp.powerAndEnergy)
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

// MARK: Results

struct ResultOverlay: View {
    let model: AppModel
    let session: MissionSession
    @State private var showWhy = false
    @Environment(\.appReduceMotion) private var reduceMotion
    @Environment(\.focusView) private var focusView
    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        let success = session.explanation?.success ?? false
        let stars = session.stars ?? StarResult(finished: false, predicted: false, bonus: false)
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().accessibilityHidden(true)
            // Confetti is decoration: off with reduced motion and in Focus view.
            if success && !reduceMotion && !focusView {
                ConfettiView().ignoresSafeArea()
            }
            ScrollView {
                VStack(spacing: 14) {
                    Ribbon(text: success ? (session.isBaseTest ? "TEST PASSED!" : "DRILL COMPLETE!") : "NOT YET!", bevel: success ? GamePalette.go : GamePalette.coral, font: .game(.title))
                        .padding(.top, -38)
                        .accessibilityFocused($titleFocused)
                    HStack {
                        Spacer()
                        ReadAloudButton(enabled: model.readAloud,
                                        text: [session.explanation?.headline ?? "", explanationLead].joined(separator: ". "),
                                        size: 40)
                    }
                    Text(session.explanation?.headline ?? "")
                        .font(.game(.title3))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                    if !session.isBaseTest {
                        HStack(alignment: .top, spacing: 8) {
                            StarSlot(filled: stars.finished, label: "Finish the drill", delay: 0.25)
                            StarSlot(filled: stars.predicted, label: "Predict it right", delay: 0.55)
                            StarSlot(filled: stars.bonus, label: session.gameCopy.bonusStar, delay: 0.85)
                        }
                    }
                    if model.lastDrillCoins > 0 {
                        HStack(spacing: 8) {
                            CoinIcon(size: 34)
                            Text("+\(model.lastDrillCoins) Moon coins for your base")
                        }
                        .font(.game(.headline))
                        .foregroundStyle(Theme.amberInk)
                        .accessibilityElement(children: .combine)
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
                    InvestigationResultCard(session: session)
                    whySection
                    HStack(spacing: 10) {
                        if success {
                            Button { session.reviseExperiment() } label: { Label("Replay", systemImage: "arrow.counterclockwise") }
                                .buttonStyle(GameButtonStyle(bevel: GamePalette.steel, height: 56, font: .game(.headline)))
                                .accessibilityLabel("Replay")
                            Button { model.leaveMission() } label: { Label("Continue", systemImage: "arrow.right") }
                                .buttonStyle(GameButtonStyle(bevel: GamePalette.go, height: 56, font: .game(.headline)))
                                .accessibilityLabel("Continue")
                        } else {
                            Button { model.leaveMission() } label: { Label(leaveTitle, systemImage: leaveIcon) }
                                .buttonStyle(GameButtonStyle(bevel: GamePalette.steel, height: 56, font: .game(.headline)))
                                .accessibilityLabel(leaveTitle)
                            // Back to planning with the suggested part highlighted: change one thing, then test again.
                            Button { session.reviseExperiment() } label: { Label("Try again", systemImage: "arrow.counterclockwise") }
                                .buttonStyle(GameButtonStyle(bevel: GamePalette.gold, height: 56, font: .game(.headline)))
                                .accessibilityLabel("Try again")
                                .accessibilityHint("Change one thing, then test again")
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
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { titleFocused = true }
            if success {
                Haptics.success()
                SoundFX.shared.play(.success)
            } else {
                Haptics.warning()
                SoundFX.shared.play(.fail)
            }
        }
    }

    private var leaveTitle: String {
        if session.baseTest?.isExample == true { return "Leave lab" }
        return session.isBaseTest ? "Improve base" : "Base"
    }

    private var leaveIcon: String {
        if session.baseTest?.isExample == true { return "xmark" }
        return session.isBaseTest ? "hammer.fill" : "house.fill"
    }

    private var explanationLead: String {
        let paragraphs = session.explanation?.paragraphs ?? []
        return paragraphs.prefix(session.isBaseTest ? 1 : 2).joined(separator: " ")
    }

    @ViewBuilder private var whySection: some View {
        if let e = session.explanation {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { showWhy.toggle() }
                } label: {
                    HStack {
                        Label(showWhy ? "Hide the numbers" : "Why? See the numbers", systemImage: "chart.bar.fill")
                        Spacer(minLength: 8)
                        Image(systemName: showWhy ? "chevron.up" : "chevron.down").accessibilityHidden(true)
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.black))
                    .foregroundStyle(Theme.energyInk)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.energyInk.opacity(0.1)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.energyInk.opacity(0.35), lineWidth: 1.5))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(showWhy ? "Hide the numbers" : "Why? See the numbers")
                if showWhy {
                    if session.isBaseTest { BaseTestCard(session: session) }
                    ForEach(e.numbers, id: \.self) { row in
                        HStack {
                            Text(row.label).foregroundStyle(Theme.inkSecondary)
                            Spacer()
                            Text(row.value).font(.body.weight(.bold).monospacedDigit()).foregroundStyle(Theme.ink)
                        }
                        .font(.system(.subheadline, design: .rounded))
                        .accessibilityElement(children: .combine)
                    }
                    ForEach(Array(e.paragraphs.dropFirst(session.isBaseTest ? 1 : 2)), id: \.self) { paragraph in
                        Text(paragraph).font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.ink)
                    }
                    if !session.isRover {
                        Label(UnitHelp.powerAndEnergy, systemImage: "bolt.badge.clock.fill")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
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


// MARK: Playback (Phase 1: the player's pace)

/// How the test is watched. Both choices show exactly the same result.
/// Drawn as a two-option toggle (not game buttons) so it never looks like it starts the test.
struct PlaybackModePicker: View {
    let session: MissionSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How do you want to watch?")
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(Theme.inkSecondary)
            HStack(spacing: 4) {
                ForEach(PlaybackMode.allCases, id: \.self) { mode in
                    option(mode)
                }
            }
            .padding(4)
            .background(Capsule().fill(Theme.panel))
            .overlay(Capsule().strokeBorder(Theme.inkSecondary.opacity(0.25), lineWidth: 1))
            Text(session.playbackMode == .automatic
                 ? "The test plays by itself. You can pause any time."
                 : "You tap Next to move to each step.")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
    }

    private func option(_ mode: PlaybackMode) -> some View {
        let selected = session.playbackMode == mode
        return Button {
            if !selected { Haptics.tap() }
            withAnimation(.easeOut(duration: 0.15)) { session.setPlaybackMode(mode) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .bold))
                Text(mode == .automatic ? "Plays by itself" : "Step by step")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(selected ? Color.white : Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Capsule().fill(selected ? Theme.energyInk : Color.clear))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Nova explains each checkpoint; the player can pause, replay, or move on whenever they are ready.
struct PlaybackPanel: View {
    let session: MissionSession

    var body: some View {
        VStack(spacing: 12) {
            if let checkpoint = session.currentCheckpoint {
                HStack(spacing: 8) {
                    Label(checkpoint.title, systemImage: checkpoint.isWarning ? "exclamationmark.triangle.fill" : "clock.fill")
                        .font(.game(.subheadline))
                        .gameText(checkpoint.isWarning ? Color(hex: 0xFFB3A0) : .white)
                    Spacer()
                    Text("Step \(session.checkpointIndex + 1) of \(session.checkpoints.count)")
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .gameText()
                }
                .accessibilityElement(children: .combine)
                NovaBubble(text: checkpoint.text, compact: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                NovaBubble(text: session.novaLine, compact: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if session.pausedByInterruption {
                Label("Paused while you were away. Tap Resume to keep watching.", systemImage: "pause.circle.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .gameText()
            }
            if session.countdown == nil {
                HStack(spacing: 10) {
                    if session.playbackMode == .automatic || session.isPaused {
                        Button {
                            session.isPaused ? session.resumePlayback() : session.pausePlayback()
                        } label: {
                            Label(session.isPaused ? "Resume" : "Pause", systemImage: session.isPaused ? "play.fill" : "pause.fill")
                        }
                        .buttonStyle(GameButtonStyle(bevel: GamePalette.steel, height: 52, font: .game(.headline)))
                        .accessibilityLabel(session.isPaused ? "Resume" : "Pause")
                    }
                    Button {
                        session.replayCheckpoint()
                    } label: {
                        Label("Replay", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(GameButtonStyle(bevel: GamePalette.steel, height: 52, font: .game(.headline)))
                    .accessibilityLabel("Replay explanation")
                    .disabled(session.currentCheckpoint == nil)
                    Button {
                        session.nextCheckpoint()
                    } label: {
                        Label(session.isLastCheckpoint ? "See result" : "Next", systemImage: "arrow.right")
                    }
                    .buttonStyle(GameButtonStyle(bevel: session.isLastCheckpoint ? GamePalette.go : GamePalette.gold, height: 52, font: .game(.headline)))
                    .accessibilityLabel(session.isLastCheckpoint ? "See result" : "Next step")
                }
                HStack(spacing: 6) {
                    Text("Pace:")
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .gameText()
                    ForEach(PlaybackMode.allCases, id: \.self) { mode in
                        let selected = session.playbackMode == mode
                        Button(mode.label) { session.setPlaybackMode(mode) }
                            .font(.system(.caption, design: .rounded).weight(.heavy))
                            .foregroundStyle(selected ? Theme.ink : .white)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 36)
                            .background(Capsule().fill(selected ? Color(hex: 0xFFD66B) : GamePalette.hud))
                            .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 6) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                    Text("Speed:")
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .gameText()
                    ForEach([1.0, 2.0, 5.0], id: \.self) { speed in
                        let selected = session.playbackSpeed == speed
                        Button("\(Int(speed))×") {
                            Haptics.tap()
                            session.setPlaybackSpeed(speed)
                        }
                        .font(.system(.subheadline, design: .rounded).weight(.black))
                        .foregroundStyle(selected ? Theme.ink : .white)
                        .padding(.horizontal, 16)
                        .frame(minWidth: 52, minHeight: 40)
                        .background(Capsule().fill(selected ? Color(hex: 0xFFD66B) : GamePalette.hud))
                        .accessibilityLabel("\(Int(speed)) times speed")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}


// MARK: Orientation (Phase 3)

/// Build → Predict → Test → Understand, with the current step marked by shape and colour, plus one concrete
/// next action. At large text sizes it becomes a single "Step n of 4" line instead of four squeezed labels.
struct MissionStepsBar: View {
    let session: MissionSession
    var emphasized = false

    private static let steps = ["Build", "Predict", "Test", "Understand"]

    private var current: Int {
        switch session.stage {
        case .briefing, .planning: return 0
        case .predicting: return 1
        case .playback: return 2
        case .results: return 3
        }
    }

    private var nextAction: String {
        switch session.stage {
        case .briefing:
            return session.isLastIntroLine ? "Tap Let's build! to start planning." : "Tap Next to hear the mission."
        case .planning:
            if session.tutorial == .placeFirstArray { return "Tap + on the solar array." }
            if session.isRover { return session.canLaunch ? "Pick a plan, then tap Launch test." : "Pick a plan that fits the cargo." }
            return session.canLaunch ? "Change the plan if you like, then tap Launch test." : "Fix the plan so it fits, then launch."
        case .predicting:
            return "Choose a prediction and explain your idea."
        case .playback:
            if session.countdown != nil { return "Get ready to watch." }
            if session.isPaused { return "Tap Resume or Next when you're ready." }
            return session.playbackMode == .stepByStep ? "Read, then tap Next." : "Watch and read. Pause any time."
        case .results:
            return (session.explanation?.success ?? false) ? "Read why it worked, then continue." : "Read why, then try a new plan."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 4) {
                    ForEach(Self.steps.indices, id: \.self) { index in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                        chip(index)
                    }
                }
                Label("Step \(current + 1) of 4: \(Self.steps[current])", systemImage: "\(current + 1).circle.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.black))
                    .gameText(Color(hex: 0xFFE27A))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if emphasized {
                VStack(alignment: .leading, spacing: 2) {
                    if let goal = session.copy.objectives.first {
                        Label("Goal: \(goal)", systemImage: "scope")
                            .font(.system(.subheadline, design: .rounded).weight(.heavy))
                            .foregroundStyle(Theme.ink)
                    }
                    Label("Next: \(nextAction)", systemImage: "hand.point.right.fill")
                        .font(.system(.body, design: .rounded).weight(.black))
                        .foregroundStyle(Theme.energyInk)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .frame(maxWidth: 560, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
            } else {
                Text("Next: \(nextAction)")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .gameText()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(current + 1) of 4, \(Self.steps[current]). Next: \(nextAction)")
    }

    private func chip(_ index: Int) -> some View {
        let active = index == current
        let done = index < current
        return HStack(spacing: 3) {
            Image(systemName: done ? "checkmark.circle.fill" : (active ? "\(index + 1).circle.fill" : "\(index + 1).circle"))
                .font(.system(size: 12, weight: .black))
            Text(Self.steps[index])
                .font(.system(.caption, design: .rounded).weight(.black))
                .lineLimit(1)
        }
        .foregroundStyle(active ? Theme.ink : Color.white.opacity(done ? 0.9 : 0.7))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(active ? Color(hex: 0xFFD66B) : GamePalette.hud))
        .overlay(Capsule().strokeBorder(active ? Color.white : Color.white.opacity(0.2), lineWidth: active ? 2 : 1))
    }
}
