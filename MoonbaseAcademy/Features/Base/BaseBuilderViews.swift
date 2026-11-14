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
                        Label(full ? "Upgrade the habitat to build more" : "Build for \(cost)", systemImage: full ? "house.fill" : "moonphase.full.moon")
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
                    Label(moving ? "Put it here" : "Build for \(cost)", systemImage: "checkmark")
                }
                .buttonStyle(GameButtonStyle(bevel: GamePalette.go, height: 52, font: .game(.headline)))
                .disabled(!fits)
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
                Label("Upgrade for \(cost)", systemImage: "arrow.up")
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
                    Text("Looks only. Style never changes how a drill works.")
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
                    Label("\(model.baseState.coins)", systemImage: "moonphase.full.moon")
                        .font(.game(.headline))
                        .accessibilityLabel("\(model.baseState.coins) Moon coins")
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct StyleCard: View {
    let model: AppModel
    let item: Cosmetic

    var body: some View {
        let base = model.baseState
        let owned = base.ownedCosmetics.contains(item.id)
        let wearing = [base.habitatColor, base.boardTheme, base.robot].contains(item.id)
        VStack(spacing: 8) {
            preview.frame(height: 70)
            Text(item.name).font(.game(.headline)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
            if wearing {
                Label("Using", systemImage: "checkmark.circle.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.plantInk)
                    .frame(minHeight: 44)
            } else if owned {
                Button("Use") { model.equipCosmetic(item.id) }
                    .buttonStyle(GameButtonStyle(bevel: GamePalette.energy, height: 44, font: .game(.headline)))
                    .accessibilityLabel("Use \(item.name)")
            } else {
                Button {
                    model.buyCosmetic(item.id)
                } label: {
                    Label("\(item.price)", systemImage: "moonphase.full.moon")
                }
                .buttonStyle(GameButtonStyle(bevel: base.coins >= item.price ? GamePalette.gold : GamePalette.steel, height: 44, font: .game(.headline)))
                .accessibilityLabel("Buy \(item.name) for \(item.price) Moon coins")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(GameCardBackground(corner: 18, highlighted: wearing))
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
