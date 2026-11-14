import SwiftUI

/// The home base: the world fills the screen, with a game HUD around it and mission pins floating in it.
struct BaseView: View {
    let model: AppModel
    let package: SciencePackage
    let isActive: Bool
    @State private var showSources = false
    @State private var showSettings = false
    @State private var topHeight: CGFloat = 0
    @State private var bottomHeight: CGFloat = 0
    @State private var lockedShake = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                WorldView(coordinator: model.baseWorld, isActive: isActive, summary: model.baseSummary)
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    topHUD
                        .readHeight { height in
                            topHeight = height + proxy.safeAreaInsets.top
                            updateInsets()
                        }
                    Spacer(minLength: 0)
                    bottomHUD
                        .frame(maxWidth: 760)
                        .readHeight { height in
                            bottomHeight = height + proxy.safeAreaInsets.bottom
                            updateInsets()
                        }
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 6)
                if let mission = model.selectedMission {
                    MissionBriefCard(model: model, mission: mission)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity))
                        .zIndex(2)
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75), value: model.selectedMission)
        }
        .sheet(isPresented: $showSources) { SourcesView(package: package, focus: nil) }
        .sheet(isPresented: $showSettings) { SettingsView(model: model) }
    }

    private func updateInsets() {
        model.baseWorld.setHUDInsets(top: topHeight + 4, bottom: bottomHeight + 4)
    }

    private var total: Int { model.progress.totalStars }

    private var topHUD: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Image(systemName: "seal.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(LinearGradient(colors: [GamePalette.energy.top, GamePalette.energy.bottom], startPoint: .top, endPoint: .bottom))
                    .shadow(color: GamePalette.night.opacity(0.6), radius: 0, x: 0, y: 3)
                Text("\(model.progress.completedMissions.count)")
                    .font(.game(.title2))
                    .gameText()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(model.progress.completedMissions.count) drills complete")
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
            ResourcePill(symbol: "star.fill", bevel: GamePalette.gold, value: "\(total)/12", label: "Stars")
            RoundIconButton(symbol: "books.vertical.fill", label: "NASA sources") { showSources = true }
            RoundIconButton(symbol: "gearshape.fill", label: "Settings") { showSettings = true }
        }
    }

    private var novaText: String {
        if model.progress.completedMissions.isEmpty {
            return "Hi, I'm Nova! Our habitat is dark. Tap PLAY or the glowing pin to start your first drill."
        }
        if let next = model.nextMission {
            return "Great work! Next up: \(GameCopy.of(next).title). Tap the glowing pin or PLAY."
        }
        return "Every drill done, Commander! Try a harder drill, or go for 3 stars everywhere."
    }

    private var bottomHUD: some View {
        VStack(spacing: 18) {
            NovaBubble(text: novaText, compact: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            ViewThatFits(in: .horizontal) {
                tiles
                ScrollView(.horizontal, showsIndicators: false) { tiles }
            }
            .shake(lockedShake)
            if let next = model.nextMission {
                Button {
                    model.selectedMission = next
                } label: {
                    Label("PLAY", systemImage: "play.fill")
                }
                .buttonStyle(GameButtonStyle(bevel: GamePalette.go, height: 64, font: .game(.title)))
                .accessibilityLabel("Play \(GameCopy.of(next).title)")
            }
        }
    }

    private var tiles: some View {
                HStack(spacing: 12) {
                    ForEach(MissionID.allCases) { id in
                        MissionTile(id: id, progress: model.progress, isNext: model.nextMission == id) {
                            if model.progress.isUnlocked(id) {
                                model.selectedMission = id
                            } else {
                                Haptics.warning()
                                withAnimation(.default) { lockedShake += 1 }
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
    }
}

struct MissionTile: View {
    let id: MissionID
    let progress: CampaignProgress
    let isNext: Bool
    let action: () -> Void

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
                    Image(systemName: unlocked ? MissionCopy.of(id).symbol : "lock.fill")
                        .font(.system(size: 24, weight: .black))
                        .gameText()
                }
                .frame(width: 54, height: 54)
                Text(GameCopy.of(id).title)
                    .font(.system(.footnote, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                MiniStars(count: progress.stars(id))
            }
            .padding(10)
            .frame(width: 118, height: 140)
            .background(GameCardBackground(highlighted: isNext))
            .opacity(unlocked ? 1 : 0.75)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(GameCopy.of(id).title), \(unlocked ? "\(progress.stars(id)) of 3 stars" : "locked")")
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// A mission's briefing card on the base, before entering the drill.
struct MissionBriefCard: View {
    let model: AppModel
    let mission: MissionID

    var body: some View {
        let game = GameCopy.of(mission)
        let copy = MissionCopy.of(mission)
        let done = model.progress.isCompleted(mission)
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { model.selectedMission = nil }
                .accessibilityHidden(true)
            VStack(spacing: 14) {
                Ribbon(text: game.title)
                    .padding(.top, -34)
                Label(copy.topic, systemImage: copy.symbol)
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
                    if done {
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
        }
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
