import SwiftUI

// MARK: Build shop

/// Every building, its cost, how many you have, and what unlocks it. Picking one starts placement.
struct BuildShopView: View {
    let model: AppModel
    let close: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Tap a building on your base to upgrade or move it.", systemImage: "hand.tap.fill")
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(.secondary)
                    ForEach(BuildingKind.allCases.filter { $0 != .habitat }) { kind in
                        BuildCardRow(model: model, kind: kind) {
                            model.startBuilding(kind)
                            if model.placement != nil { close() }
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Build")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", action: close) } }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct BuildCardRow: View {
    let model: AppModel
    let kind: BuildingKind
    let build: () -> Void

    var body: some View {
        let base = model.baseState
        let status = base.blueprint(kind, progress: model.progress)
        let cost = BaseState.buildCost(kind)
        let full = base.count(kind) >= base.maxCount(kind)
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: kind.symbol)
                .font(.system(size: 26, weight: .black))
                .gameText()
                .frame(width: 54, height: 54)
                .background(Circle().fill(GamePalette.energy.bottom))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.7), lineWidth: 2))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(kind.name).font(.game(.headline)).foregroundStyle(Theme.ink)
                Text(kind.blurb).font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.inkSecondary)
                if let drill = kind.drill {
                    Label("Opens the \(GameCopy.of(drill).title) drill", systemImage: "flag.checkered")
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .foregroundStyle(Theme.energyInk)
                }
                Text("Built: \(base.count(kind)) of \(base.maxCount(kind))")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.inkSecondary)
                switch status {
                case .locked(let reason):
                    Label(reason, systemImage: "lock.fill")
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Theme.amberInk)
                case .available:
                    Button(action: build) {
                        if full {
                            Label("Upgrade the habitat to build more", systemImage: "house.fill")
                        } else {
                            CoinLabel(title: "Build for", amount: cost)
                        }
                    }
                    .buttonStyle(GameButtonStyle(bevel: base.coins >= cost && !full ? GamePalette.go : GamePalette.steel, height: 48, font: .game(.headline)))
                    .accessibilityLabel(full ? "\(kind.name): upgrade the habitat to build more" : "Build \(kind.name.lowercased()) for \(cost) Moon coins")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(GameCardBackground(corner: 18))
        .accessibilityElement(children: .contain)
    }
}

// MARK: Placement

/// Shown while placing or moving: does it fit, nudge buttons (no dragging needed), cancel and confirm.
struct PlacementBar: View {
    let model: AppModel
    let placement: AppModel.Placement

    var body: some View {
        let fits = model.placementFits
        let moving = placement.movingID != nil
        let cost = BaseState.buildCost(placement.kind)
        VStack(spacing: 10) {
            Text(moving ? "Move your \(placement.kind.name.lowercased())" : "Place your \(placement.kind.name.lowercased())")
                .font(.game(.headline))
                .foregroundStyle(Theme.ink)
            Text("Tap a tile or drag to pick a spot. Pinch to zoom.")
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .foregroundStyle(Theme.inkSecondary)
            Label(fits ? "Fits here" : "Doesn't fit here. Tap or drag to another spot.",
                  systemImage: fits ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(fits ? Theme.plantInk : Theme.warningInk)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                nudge("arrow.up.left", "Move toward the top left", dx: -1, dy: 0)
                nudge("arrow.up.right", "Move toward the top right", dx: 0, dy: -1)
                nudge("arrow.down.left", "Move toward the bottom left", dx: 0, dy: 1)
                nudge("arrow.down.right", "Move toward the bottom right", dx: 1, dy: 0)
            }
            HStack(spacing: 10) {
                Button("Cancel") { model.cancelPlacement() }
                    .buttonStyle(GameButtonStyle(bevel: GamePalette.steel, height: 52, font: .game(.headline)))
                Button {
                    model.confirmPlacement()
                } label: {
                    if moving {
                        Label("Put it here", systemImage: "checkmark")
                    } else {
                        CoinLabel(title: "Build for", amount: cost, size: 22)
                    }
                }
                .buttonStyle(GameButtonStyle(bevel: GamePalette.go, height: 52, font: .game(.headline)))
                .disabled(!fits)
                .guidePulse(fits)
                .accessibilityLabel(moving ? "Put it here" : "Place here")
            }
        }
        .padding(14)
        .background(GameCardBackground(corner: 20))
        .accessibilityElement(children: .contain)
    }

    private func nudge(_ symbol: String, _ label: String, dx: Int, dy: Int) -> some View {
        RoundIconButton(symbol: symbol, label: label, bevel: GamePalette.energy, size: 44) {
            model.nudgePlacement(dx: dx, dy: dy)
        }
    }
}

// MARK: Building panel

/// What a building does, its level, the next upgrade, and actions.
struct BuildingPanel: View {
    let model: AppModel
    let building: PlacedBuilding
    let onPlay: (MissionID) -> Void
    let onLearn: () -> Void

    var body: some View {
        let cost = BaseState.upgradeCost(building.kind, from: building.level)
        let coins = model.baseState.coins
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(building.kind.name).font(.game(.title3)).foregroundStyle(Theme.ink)
                    HStack(spacing: 4) {
                        ForEach(0..<BuildingKind.maxLevel, id: \.self) { i in
                            Image(systemName: i < building.level ? "star.fill" : "star")
                                .foregroundStyle(i < building.level ? Color(hex: 0xF5B92E) : Theme.inkSecondary)
                        }
                        Text("Level \(building.level) of \(BuildingKind.maxLevel)")
                            .font(.system(.subheadline, design: .rounded).weight(.heavy))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Level \(building.level) of \(BuildingKind.maxLevel)")
                }
                Spacer()
                RoundIconButton(symbol: "xmark", label: "Close", bevel: GamePalette.coral, size: 40) { model.selectBuilding(nil) }
            }
            Text(building.kind.blurb)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let cost {
                Label("Next level: \(BaseState.levelReward(building.kind, level: building.level + 1))", systemImage: "arrow.up.circle.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.energyInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { actions(cost: cost, coins: coins) }
                VStack(spacing: 8) { actions(cost: cost, coins: coins) }
            }
        }
        .padding(14)
        .background(GameCardBackground(corner: 20))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private func actions(cost: Int?, coins: Int) -> some View {
        if let cost {
            Button {
                model.upgradeBuilding(building.id)
            } label: {
                CoinLabel(title: "Upgrade", amount: cost, size: 22)
            }
            .buttonStyle(GameButtonStyle(bevel: coins >= cost ? GamePalette.gold : GamePalette.steel, height: 50, font: .game(.headline)))
            .accessibilityLabel("Upgrade for \(cost) Moon coins")
        } else {
            Label("Top level!", systemImage: "crown.fill")
                .font(.game(.headline))
                .foregroundStyle(Theme.amberInk)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        Button {
            model.startMoving(building.id)
        } label: {
            Label("Move", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
        }
        .buttonStyle(GameButtonStyle(bevel: GamePalette.steel, height: 50, font: .game(.headline)))
        if let drill = building.kind.drill, model.progress.isUnlocked(drill), model.baseState.drillReady(drill) {
            Button {
                onPlay(drill)
            } label: {
                Label("Drill", systemImage: "play.fill")
            }
            .buttonStyle(GameButtonStyle(bevel: GamePalette.go, height: 50, font: .game(.headline)))
            .accessibilityLabel("Play \(GameCopy.of(drill).title)")
        }
    }
}

// MARK: Learn

struct LearnListView: View {
    let model: AppModel
    let open: (Lesson) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Learn with Nova and earn Moon coins. Answer right on the first try for the most coins.")
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(.secondary)
                    if let science = model.science {
                        ForEach(LessonLibrary.all(science: science)) { lesson in
                            lessonRow(lesson)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("More lessons are being made").font(.game(.headline)).foregroundStyle(Theme.ink)
                        Text("Power and batteries, solar storms, and talking to Earth.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(GameCardBackground(corner: 18))
                }
                .padding(16)
            }
            .navigationTitle("Learn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func lessonRow(_ lesson: Lesson) -> some View {
        let record = model.baseState.lessons[lesson.id]
        let done = record?.completed == true
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: lesson.symbol)
                    .font(.system(size: 24, weight: .black))
                    .gameText()
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(GamePalette.go.bottom))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(lesson.title).font(.game(.headline)).foregroundStyle(Theme.ink)
                    Text(lesson.topic).font(.system(.caption, design: .rounded).weight(.heavy)).foregroundStyle(Theme.inkSecondary)
                }
            }
            if let unlocks = lesson.unlocks {
                Label(done ? "\(unlocks.name) blueprint unlocked" : "Unlocks the \(unlocks.name.lowercased())",
                      systemImage: done ? "checkmark.seal.fill" : "lock.open.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(done ? Theme.plantInk : Theme.energyInk)
            }
            if let record, done {
                Text("Best: \(record.bestCorrect) of \(lesson.questionCount) right on the first try")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.inkSecondary)
            }
            Button {
                open(lesson)
            } label: {
                Label(done ? "Play again" : "Start lesson", systemImage: "play.fill")
            }
            .buttonStyle(GameButtonStyle(bevel: done ? GamePalette.steel : GamePalette.go, height: 50, font: .game(.headline)))
            .accessibilityLabel("\(done ? "Play again" : "Start"): \(lesson.title)")
        }
        .padding(14)
        .background(GameCardBackground(corner: 18))
        .accessibilityElement(children: .contain)
    }
}

// MARK: Drills

struct DrillsListView: View {
    let model: AppModel
    let close: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(MissionID.allCases) { id in
                        VStack(spacing: 6) {
                            MissionTile(id: id, progress: model.progress, isNext: model.nextMission == id) {
                                guard model.progress.isUnlocked(id), model.baseState.drillReady(id) else { return }
                                close()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { model.selectedMission = id }
                            }
                            if !model.progress.isUnlocked(id) {
                                Text("Finish the drill before it first.")
                                    .font(.system(.caption, design: .rounded).weight(.heavy))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            } else if let needs = model.baseState.drillNeeds(id) {
                                Text(needs)
                                    .font(.system(.caption, design: .rounded).weight(.heavy))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Drills")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", action: close) } }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: Style

/// Colours, ground themes and robot buddies. Bought with Moon coins; nothing here changes any drill.
struct StyleShopView: View {
    let model: AppModel
    @State private var kind: CosmeticKind = .habitatColor
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Type", selection: $kind) {
                        ForEach(CosmeticKind.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text("Tap Try it to see it on your base above. Looks only: style never changes how a drill works.")
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                        ForEach(CosmeticCatalog.items(kind)) { item in
                            StyleCard(model: model, item: item)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    CoinLabel(amount: model.baseState.coins, size: 22)
                        .font(.game(.headline))
                        .accessibilityLabel("\(model.baseState.coins) Moon coins")
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.fraction(0.5), .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.5)))
    }
}

private struct StyleCard: View {
    let model: AppModel
    let item: Cosmetic

    var body: some View {
        let base = model.baseState
        let owned = base.ownedCosmetics.contains(item.id)
        let wearing = [base.habitatColor, base.boardTheme, base.robot].contains(item.id)
        let previewing = model.previewCosmetic == item.id
        let short = max(0, item.price - base.coins)
        VStack(spacing: 8) {
            preview.frame(height: 70)
            Text(item.name).font(.game(.headline)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
            if wearing {
                Label("Using", systemImage: "checkmark.circle.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.plantInk)
                    .frame(minHeight: 44)
            } else if !previewing {
                Button {
                    model.previewCosmetic = item.id
                } label: {
                    Label("Try it", systemImage: "eye.fill")
                }
                .buttonStyle(GameButtonStyle(bevel: GamePalette.energy, height: 44, font: .game(.headline)))
                .accessibilityLabel("Try \(item.name) on your base")
            } else if owned {
                Button("Use it") {
                    model.equipCosmetic(item.id)
                    model.previewCosmetic = nil
                }
                .buttonStyle(GameButtonStyle(bevel: GamePalette.go, height: 44, font: .game(.headline)))
                .accessibilityLabel("Use \(item.name)")
            } else if short == 0 {
                Button {
                    if model.buyCosmetic(item.id) { model.previewCosmetic = nil }
                } label: {
                    CoinLabel(title: "Buy", amount: item.price, size: 22)
                }
                .buttonStyle(GameButtonStyle(bevel: GamePalette.gold, height: 44, font: .game(.headline)))
                .accessibilityLabel("Buy \(item.name) for \(item.price) Moon coins")
            } else {
                Button {
                    model.coinHelpNeeded = short
                } label: {
                    Label("Get \(short) more", systemImage: "plus.circle.fill")
                }
                .buttonStyle(GameButtonStyle(bevel: GamePalette.steel, height: 44, font: .game(.headline)))
                .accessibilityLabel("You need \(short) more Moon coins. Show how to earn them")
            }
            if !wearing && !owned {
                HStack(spacing: 4) {
                    CoinIcon(size: 16)
                    Text("\(item.price)")
                }
                .font(.system(.caption, design: .rounded).weight(.black))
                .foregroundStyle(Theme.amberInk)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Costs \(item.price) Moon coins")
            }
            if previewing {
                Text("Look at your base!")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.energyInk)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(GameCardBackground(corner: 18, highlighted: wearing || previewing))
        .contentShape(Rectangle())
        .onTapGesture { if !wearing { model.previewCosmetic = item.id } }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var preview: some View {
        switch item.kind {
        case .robot:
            NovaAvatar(size: 64)
                .environment(\.novaColors, NovaColors(shell: item.color, eyes: item.accent))
        case .habitatColor:
            Image(systemName: "house.fill")
                .font(.system(size: 44, weight: .black))
                .foregroundStyle(Color(hex: item.color))
                .shadow(color: GamePalette.night.opacity(0.5), radius: 0, x: 0, y: 2)
                .accessibilityHidden(true)
        case .boardTheme:
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: item.color))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color(hex: item.accent), lineWidth: 4))
                .frame(width: 90, height: 56)
                .rotationEffect(.degrees(45))
                .scaleEffect(x: 1, y: 0.55)
                .accessibilityHidden(true)
        }
    }
}

// MARK: Guide

/// A gentle "look here" pulse on the next thing to tap. A steady gold outline when motion is reduced.
struct GuidePulse: ViewModifier {
    var active = true
    @Environment(\.appReduceMotion) private var reduceMotion
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color(hex: 0xFFE27A), lineWidth: 4)
                        .padding(-5)
                        .opacity(reduceMotion ? 1 : (on ? 1 : 0.25))
                        .scaleEffect(reduceMotion ? 1 : (on ? 1.03 : 1))
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                guard active, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { on = true }
            }
    }
}

extension View {
    func guidePulse(_ active: Bool = true) -> some View { modifier(GuidePulse(active: active)) }
}

/// Nova's next goal with one big "Show me" button and the bonus it pays.
struct GoalCard: View {
    let goal: GuideGoal
    let readAloud: Bool
    let showMe: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                NovaAvatar(size: 54, talking: true)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("GOAL \(goal.index + 1) OF \(GuideGoal.allCases.count)")
                            .font(.system(.caption, design: .rounded).weight(.black))
                            .foregroundStyle(Theme.energyInk)
                        Spacer(minLength: 4)
                        HStack(spacing: 4) {
                            Text("+\(GuideGoal.reward)")
                            CoinIcon(size: 18)
                        }
                        .font(.system(.subheadline, design: .rounded).weight(.black))
                        .foregroundStyle(Theme.amberInk)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Bonus: \(GuideGoal.reward) Moon coins")
                    }
                    Label(goal.title, systemImage: goal.symbol)
                        .font(.game(.headline))
                        .foregroundStyle(Theme.ink)
                    Text(goal.detail)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ReadAloudButton(enabled: readAloud, text: "\(goal.title). \(goal.detail)", size: 40)
            }
            Button(action: showMe) {
                Label("Show me", systemImage: "hand.point.right.fill")
            }
            .buttonStyle(GameButtonStyle(bevel: GamePalette.go, height: 58, font: .game(.title3)))
            .guidePulse()
            .accessibilityLabel("Show me")
            .accessibilityHint(goal.title)
        }
        .padding(14)
        .background(GameCardBackground(corner: 22))
        .accessibilityElement(children: .contain)
    }
}

/// "Goal complete!" with the coin bonus.
struct GoalToast: View {
    let goal: GuideGoal

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(Color(hex: 0x7EDB6E))
            VStack(alignment: .leading, spacing: 2) {
                Text("Goal complete!").font(.game(.headline)).foregroundStyle(Theme.ink)
                Text(goal.title).font(.system(.subheadline, design: .rounded).weight(.heavy)).foregroundStyle(Theme.inkSecondary)
            }
            HStack(spacing: 4) {
                Text("+\(GuideGoal.reward)")
                CoinIcon(size: 28)
            }
            .font(.game(.title3))
            .foregroundStyle(Theme.amberInk)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(GameCardBackground(corner: 20, highlighted: true))
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Goal complete: \(goal.title). Plus \(GuideGoal.reward) Moon coins.")
    }
}

// MARK: Earn coins

/// Shown whenever the player can't afford something: exactly how to get more, with Go buttons.
struct EarnCoinsView: View {
    let model: AppModel
    let needed: Int
    let go: (EarnOption) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        NovaAvatar(size: 56, talking: true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(needed > 0 ? "You need \(needed) more Moon coins." : "Here's how to earn Moon coins.")
                                .font(.game(.title3))
                                .foregroundStyle(.primary)
                            Text("Pick one and I'll take you there!")
                                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(Array(model.earnOptions.enumerated()), id: \.element.id) { index, option in
                        optionCard(option, best: index == 0)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Earn coins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    CoinLabel(amount: model.baseState.coins, size: 22)
                        .font(.game(.headline))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("You have \(model.baseState.coins) Moon coins")
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func optionCard(_ option: EarnOption, best: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: option.symbol)
                .font(.system(size: 22, weight: .black))
                .gameText()
                .frame(width: 50, height: 50)
                .background(Circle().fill(best ? GamePalette.go.bottom : GamePalette.energy.bottom))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(option.title).font(.game(.headline)).foregroundStyle(Theme.ink)
                Text(option.detail)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    Text(option.upTo ? "Up to +\(option.coins)" : "+\(option.coins)")
                    CoinIcon(size: 18)
                }
                .font(.system(.subheadline, design: .rounded).weight(.black))
                .foregroundStyle(Theme.amberInk)
            }
            Spacer(minLength: 4)
            Button("Go") { go(option) }
                .buttonStyle(GameButtonStyle(bevel: GamePalette.go, height: 48, font: .game(.headline)))
                .frame(width: 84)
                .guidePulse(best)
                .accessibilityLabel("Go: \(option.title)")
        }
        .padding(12)
        .background(GameCardBackground(corner: 18, highlighted: best))
        .accessibilityElement(children: .contain)
    }
}
