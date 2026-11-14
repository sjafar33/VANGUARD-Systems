import SpriteKit
import SwiftUI

/// The home base: a Clash-style board you build on. Earn Moon coins from lessons and drills, then build,
/// move, upgrade and decorate. Drills open when the base has what they need.
struct BaseView: View {
    let model: AppModel
    let package: SciencePackage
    let isActive: Bool
    @State private var showSources = false
    @State private var showSettings = false
    @State private var sheet: BaseSheet?
    @State private var lesson: Lesson?
    @State private var topHeight: CGFloat = 0
    @State private var bottomHeight: CGFloat = 0
    @State private var coinGain: Int?
    @State private var earnNeeded = 0
    @State private var screenHeight: CGFloat = 800
    @Environment(\.appReduceMotion) private var reduceMotion

    enum BaseSheet: String, Identifiable {
        case build, learn, drills, style, earn
        var id: String { rawValue }
    }

    private var overlayShown: Bool { model.selectedMission != nil }
    private var base: BaseState { model.baseState }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                BoardView(coordinator: model.board, isActive: isActive, summary: model.boardSummary)
                    .ignoresSafeArea()
                    .accessibilityHidden(overlayShown)
                VStack(spacing: 8) {
                    topHUD
                        .readHeight { height in
                            topHeight = height + proxy.safeAreaInsets.top
                            updateInsets()
                        }
                    if let message = model.baseMessage {
                        MessageBanner(text: message) { model.baseMessage = nil }
                    }
                    Spacer(minLength: 0)
                    ViewThatFits(in: .vertical) {
                        bottomHUD
                        ScrollView { bottomHUD.padding(.bottom, 4) }
                            .frame(maxHeight: proxy.size.height * 0.55)
                    }
                    .frame(maxWidth: 760)
                    .readHeight { height in
                        bottomHeight = height + proxy.safeAreaInsets.bottom
                        updateInsets()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 6)
                .accessibilityHidden(overlayShown)
                if model.placement == nil && sheet == nil {
                    zoomControls
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .padding(.trailing, 12)
                        .accessibilityHidden(overlayShown)
                }
                if let goal = model.goalToast {
                    GoalToast(goal: goal)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, topHeight - proxy.safeAreaInsets.top + 6)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        .zIndex(3)
                        .allowsHitTesting(false)
                }
                if let mission = model.selectedMission {
                    MissionBriefCard(model: model, mission: mission)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity))
                        .zIndex(2)
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75), value: model.selectedMission)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.placement)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.selectedBuildingID)
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7), value: model.goalToast)
            .onAppear { screenHeight = proxy.size.height }
            .onChange(of: proxy.size.height) { _, height in screenHeight = height }
        }
        .sheet(item: $sheet, onDismiss: { model.previewCosmetic = nil; updateInsets() }) { which in
            switch which {
            case .build:
                BuildShopView(model: model) { sheet = nil }
            case .learn:
                LearnListView(model: model) { chosen in
                    sheet = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { lesson = chosen }
                }
            case .drills:
                DrillsListView(model: model) { sheet = nil }
            case .style:
                StyleShopView(model: model)
            case .earn:
                EarnCoinsView(model: model, needed: earnNeeded) { option in
                    sheet = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { go(option) }
                }
            }
        }
        .fullScreenCover(item: $lesson) { current in
            LessonView(model: model, lesson: current, package: package) { buildNow in
                lesson = nil
                if buildNow, let kind = current.unlocks {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { model.startBuilding(kind) }
                }
            }
        }
        .sheet(isPresented: $showSources) { SourcesView(package: package, focus: nil) }
        .sheet(isPresented: $showSettings) { SettingsView(model: model) }
        .onChange(of: novaText, initial: true) { _, text in
            if model.readAloud && model.selectedMission == nil && model.placement == nil { Narrator.shared.speak(text) }
        }
        .onChange(of: model.coinHelpNeeded) { _, needed in
            guard let needed else { return }
            earnNeeded = needed
            model.coinHelpNeeded = nil
            if sheet != nil {
                sheet = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { sheet = .earn }
            } else {
                sheet = .earn
            }
        }
        // `initial` matters: a goal finished inside a drill or a base test is already set when this
        // screen comes back, and it must still fade out.
        .onChange(of: model.goalToast, initial: true) { _, goal in
            guard let goal else { return }
            Haptics.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                if model.goalToast == goal { model.goalToast = nil }
            }
        }
        .onChange(of: sheet) { _, _ in updateInsets() }
        .onChange(of: base.coins) { old, new in
            guard new > old else { return }
            coinGain = new - old
            SoundFX.shared.play(.star)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { coinGain = nil }
        }
    }

    private func updateInsets() {
        // While the Style shop is open, frame the base in the top half so the preview is visible.
        let bottom = sheet == .style ? max(bottomHeight, screenHeight * 0.5) : bottomHeight
        model.board.setHUDInsets(top: topHeight + 4, bottom: bottom + 4)
    }

    private var zoomControls: some View {
        VStack(spacing: 10) {
            RoundIconButton(symbol: "plus.magnifyingglass", label: "Zoom in", size: 44) { model.board.zoom(by: 1.35) }
            RoundIconButton(symbol: "minus.magnifyingglass", label: "Zoom out", size: 44) { model.board.zoom(by: 1 / 1.35) }
            RoundIconButton(symbol: "scope", label: "Show the whole base", size: 44) { model.board.resetCamera() }
        }
    }

    /// "Show me": does the next step for the child, or opens exactly where it happens.
    private func perform(_ goal: GuideGoal) {
        switch goal {
        case .buildArray: model.startBuilding(.solarArray)
        case .buildBattery: model.startBuilding(.battery)
        case .buildGreenhouse: model.startBuilding(.greenhouse)
        case .buildShelter: model.startBuilding(.shelter)
        case .buildDish: model.startBuilding(.dish)
        case .playLightsOut: play(.lightsOut)
        case .restoreStation: model.showLandingStation()
        case .testBase:
            if base.baseTestReady {
                model.openBaseTest()
            } else {
                model.showLandingStation()
            }
        case .playLivingBase: play(.livingBase)
        case .playStorm: play(.stormDrill)
        case .playSignal: play(.signalLag)
        case .learnPlants:
            lesson = model.lesson(LessonLibrary.plantsAndAirID)
        case .decorate: sheet = .style
        case .upgradeHabitat: model.selectBuilding("habitat")
        }
    }

    private func play(_ id: MissionID) {
        if model.progress.isUnlocked(id) && base.drillReady(id) {
            model.selectedMission = id
        } else {
            sheet = .drills
        }
    }

    private func go(_ option: EarnOption) {
        switch option.action {
        case .lesson(let id):
            lesson = model.lesson(id)
        case .drill(let id):
            model.selectedMission = id
        }
    }

    private var total: Int { model.progress.totalStars }

    private var topHUD: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Image(systemName: "seal.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(LinearGradient(colors: [GamePalette.energy.top, GamePalette.energy.bottom], startPoint: .top, endPoint: .bottom))
                        .shadow(color: GamePalette.night.opacity(0.6), radius: 0, x: 0, y: 3)
                    Text("\(base.habitatLevel)")
                        .font(.game(.title2))
                        .gameText()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Base level \(base.habitatLevel)")
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.progress.baseName)
                        .font(.game(.headline))
                        .gameText()
                        .lineLimit(1)
                    Text(GameCopy.rank(stars: total))
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .gameText(Color(hex: 0xFFE27A))
                }
                Spacer(minLength: 4)
                RoundIconButton(symbol: "books.vertical.fill", label: "NASA sources") { showSources = true }
                RoundIconButton(symbol: "gearshape.fill", label: "Settings") { showSettings = true }
            }
            HStack(spacing: 12) {
                CoinPill(coins: base.coins)
                    .overlay(alignment: .topTrailing) {
                        if let coinGain {
                            Text("+\(coinGain)")
                                .font(.game(.headline))
                                .gameText(Color(hex: 0xFFE27A))
                                .offset(x: 20, y: -18)
                                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                                .accessibilityLabel("Earned \(coinGain) Moon coins")
                        }
                    }
                    .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: coinGain)
                ResourcePill(symbol: "star.fill", bevel: GamePalette.energy, value: "\(total)/12", label: "Stars")
                Spacer(minLength: 0)
            }
        }
    }

    var novaText: String {
        if let goal = model.currentGoal { return goal.detail }
        guard let next = model.nextMission else {
            return "Every drill done, Commander! Upgrade buildings to open harder drills, or decorate your base in Style."
        }
        let title = GameCopy.of(next).title
        if base.drillReady(next) {
            return model.progress.completedMissions.isEmpty
                ? "Your base has a solar array and a battery! Tap PLAY to try your first drill, \(title)."
                : "\(title) is ready. Tap PLAY when you are!"
        }
        if next == .lightsOut {
            return "Hi, I'm Nova! Tap Build and place a solar array and a battery on the board. Then your first drill, \(title), opens."
        }
        if next == .livingBase, base.lessons[LessonLibrary.plantsAndAirID]?.completed != true {
            return "Next drill: \(title). Tap Learn and finish \"Plants and Air\" to unlock the greenhouse. You'll earn Moon coins too!"
        }
        return "Next drill: \(title). \(base.drillNeeds(next) ?? "") Tap Build."
    }

    @ViewBuilder private var bottomHUD: some View {
        if let placement = model.placement {
            PlacementBar(model: model, placement: placement)
        } else if let id = model.selectedBuildingID, let building = base.buildings.first(where: { $0.id == id }),
                  building.kind == .landingStation {
            StationPanel(model: model, building: building)
        } else if let id = model.selectedBuildingID, let building = base.buildings.first(where: { $0.id == id }) {
            BuildingPanel(model: model, building: building,
                          onPlay: { mission in
                              model.selectBuilding(nil)
                              model.selectedMission = mission
                          },
                          onLearn: { sheet = .learn })
        } else {
            mainHUD
        }
    }

    private var mainHUD: some View {
        VStack(spacing: 14) {
            if let draft = model.resumableDraft {
                ResumeCard(draft: draft, onContinue: { model.resumeDraft() }, onDismiss: { model.discardDraft() })
            }
            if let goal = model.currentGoal {
                GoalCard(goal: goal, readAloud: model.readAloud) { perform(goal) }
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    NovaBubble(text: novaText, compact: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ReadAloudButton(enabled: model.readAloud, text: novaText)
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { actionButtons }
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        actionButton("Build", "hammer.fill", GamePalette.gold) { sheet = .build }
                        actionButton("Learn", "book.fill", GamePalette.energy) { sheet = .learn }
                    }
                    HStack(spacing: 10) {
                        actionButton("Drills", "flag.checkered", GamePalette.go) { sheet = .drills }
                        actionButton("Style", "paintpalette.fill", GamePalette.coral) { sheet = .style }
                    }
                }
            }
            if let next = model.nextMission, base.drillReady(next), model.currentGoal?.title.hasPrefix("Play") != true {
                Button {
                    model.selectedMission = next
                } label: {
                    Label("PLAY", systemImage: "play.fill")
                }
                .buttonStyle(GameButtonStyle(bevel: GamePalette.go, height: 60, font: .game(.title)))
                .accessibilityLabel("Play \(GameCopy.of(next).title)")
            }
        }
    }

    @ViewBuilder private var actionButtons: some View {
        actionButton("Build", "hammer.fill", GamePalette.gold) { sheet = .build }
        actionButton("Learn", "book.fill", GamePalette.energy) { sheet = .learn }
        actionButton("Drills", "flag.checkered", GamePalette.go) { sheet = .drills }
        actionButton("Style", "paintpalette.fill", GamePalette.coral) { sheet = .style }
    }

    private func actionButton(_ title: String, _ symbol: String, _ bevel: GamePalette.Bevel, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.system(size: 22, weight: .black))
                Text(title).font(.game(.subheadline))
            }
        }
        .buttonStyle(GameButtonStyle(bevel: bevel, height: 64, font: .game(.subheadline)))
        .accessibilityLabel(title)
    }
}

/// Hosts the board scene. It pauses when the app is not active.
struct BoardView: View {
    let coordinator: BoardCoordinator
    let isActive: Bool
    let summary: String

    var body: some View {
        SpriteView(scene: coordinator.scene, preferredFramesPerSecond: 30, options: [.ignoresSiblingOrder])
            .onChange(of: isActive, initial: true) { _, active in coordinator.scene.isPaused = !active }
            .accessibilityElement()
            .accessibilityLabel(summary)
            .accessibilityHint("Use the buttons below to build, move and upgrade.")
            .accessibilityAddTraits(.isImage)
    }
}

struct MessageBanner: View {
    let text: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(action: dismiss) { Image(systemName: "xmark.circle.fill") }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Dismiss message")
        }
        .font(.system(.subheadline, design: .rounded).weight(.heavy))
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: 0xFFF4D6)))
        .accessibilityElement(children: .combine)
    }
}

struct MissionTile: View {
    let id: MissionID
    let progress: CampaignProgress
    let isNext: Bool
    let action: () -> Void
    // Cards grow with Dynamic Type; the row scrolls instead of shrinking text.
    @ScaledMetric(relativeTo: .footnote) private var cardWidth: CGFloat = 118
    @ScaledMetric(relativeTo: .footnote) private var cardHeight: CGFloat = 140

    var body: some View {
        let unlocked = progress.isUnlocked(id)
        let done = progress.isCompleted(id)
        let bevel = done ? GamePalette.go : (isNext ? GamePalette.gold : GamePalette.steel)
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(bevel.edge).offset(y: 3)
                    Circle().fill(LinearGradient(colors: [bevel.top, bevel.bottom], startPoint: .top, endPoint: .bottom))
                    Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 2)
                    Image(systemName: unlocked ? MissionCopy.symbol(id) : "lock.fill")
                        .font(.system(size: 24, weight: .black))
                        .gameText()
                }
                .frame(width: 54, height: 54)
                Text(GameCopy.of(id).title)
                    .font(.system(.footnote, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                MiniStars(count: progress.stars(id))
            }
            .padding(10)
            .frame(width: cardWidth)
            .frame(minHeight: cardHeight)
            .background(GameCardBackground(highlighted: isNext))
            .opacity(unlocked ? 1 : 0.75)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(GameCopy.of(id).title), \(unlocked ? "\(progress.stars(id)) of 3 stars" : "locked")")
        .accessibilityHint(unlocked ? "Opens the drill briefing" : "Finish the drill before it to unlock this one")
    }
}

struct PressableStyle: ButtonStyle {
    @Environment(\.appReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.18, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// A mission's briefing card on the base, before entering the drill.
struct MissionBriefCard: View {
    let model: AppModel
    let mission: MissionID
    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { model.selectedMission = nil }
                .accessibilityHidden(true)
            ViewThatFits(in: .vertical) {
                card
                ScrollView { card.padding(.vertical, 30) }
            }
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { titleFocused = true } }
        .accessibilityAction(.escape) { model.selectedMission = nil }
    }

    private var card: some View {
        let game = GameCopy.of(mission)
        let done = model.progress.isCompleted(mission)
        return VStack(spacing: 14) {
                Ribbon(text: game.title)
                    .padding(.top, -34)
                    .accessibilityFocused($titleFocused)
                Label(MissionCopy.topic(mission), systemImage: MissionCopy.symbol(mission))
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.inkSecondary)
                NovaBubble(text: game.intro[0], compact: true)
                VStack(alignment: .leading, spacing: 10) {
                    goal("Finish the drill")
                    goal("Predict the result")
                    goal(game.bonusStar)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.panel))
                if done {
                    HStack {
                        Text("Your best").font(.system(.subheadline, design: .rounded).weight(.heavy)).foregroundStyle(Theme.ink)
                        MiniStars(count: model.progress.stars(mission), size: 20)
                    }
                }
                HStack(spacing: 12) {
                    if done && model.baseState.harderReady(mission) {
                        Button("Harder") { model.openMission(mission, variant: true) }
                            .buttonStyle(GameButtonStyle(bevel: GamePalette.steel))
                    }
                    Button {
                        model.openMission(mission)
                    } label: {
                        Label(done ? "Replay" : "Start", systemImage: "play.fill")
                    }
                    .buttonStyle(GameButtonStyle(bevel: GamePalette.go))
                    .accessibilityLabel("Start \(game.title)")
                }
            }
            .padding(20)
            .padding(.top, 14)
            .frame(maxWidth: 460)
            .background(GameCardBackground(corner: 26))
            .overlay(alignment: .topTrailing) {
                RoundIconButton(symbol: "xmark", label: "Close", bevel: GamePalette.coral, size: 40) { model.selectedMission = nil }
                    .offset(x: 10, y: -14)
            }
            .padding(24)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
    }

    private func goal(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "star.fill")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Color(hex: 0xF5B92E))
                .shadow(color: GamePalette.night.opacity(0.4), radius: 0, x: 0, y: 1)
            Text(text)
                .font(.system(.body, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.ink)
        }
        .accessibilityElement(children: .combine)
    }
}


/// Interruption recovery: offers to reopen the plan the player was working on before the app closed.
struct ResumeCard: View {
    let draft: MissionDraft
    let onContinue: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("You were working on \(GameCopy.of(draft.missionID).title)\(draft.variant ? " (harder version)" : "").",
                  systemImage: "arrow.uturn.backward.circle.fill")
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Your plan was saved. The test starts fresh, so nothing is counted twice.")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { buttons }
                VStack(spacing: 8) { buttons }
            }
        }
        .padding(14)
        .background(GameCardBackground(corner: 18))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var buttons: some View {
        Button("Not now", action: onDismiss)
            .buttonStyle(GameButtonStyle(bevel: GamePalette.steel, height: 48, font: .game(.headline)))
        Button(action: onContinue) { Label("Continue", systemImage: "play.fill") }
            .buttonStyle(GameButtonStyle(bevel: GamePalette.go, height: 48, font: .game(.headline)))
            .accessibilityLabel("Continue \(GameCopy.of(draft.missionID).title)")
    }
}
