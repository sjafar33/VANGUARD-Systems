import SwiftUI

/// Planning in the style of a base-building game: the base fills the screen, equipment comes from a shop bar
/// along the bottom, a big Launch button sits beside it, and the operating plan opens as a panel above.
/// Only the controls changed. Equipment, operating settings and the shared engine rates work as before.
struct MissionPlanningWorkspace<Launch: View>: View {
    let model: AppModel
    let session: MissionSession
    @Binding var planOpen: Bool
    @Binding var phaseIndex: Int
    /// Phone widths stack Launch under the shop and hide the shop while the plan is open.
    var narrow: Bool
    var panelMaxHeight: CGFloat
    let openPlan: (Int) -> Void
    @ViewBuilder let launch: () -> Launch
    @State private var showHelp = false
    @State private var showRules = false
    @ScaledMetric(relativeTo: .title3) private var launchWidth: CGFloat = 168

    private var indices: [Int] {
        if session.definition.missionID == .livingBase && session.sameSettingsForAllBlocks { return [0] }
        return Array(session.definition.phases.indices)
    }

    private var tutorialActive: Bool { session.tutorial == .placeFirstArray }

    /// Test My Base on the player's own base: the equipment is whatever they built, already visible on the Moon,
    /// so there is no shop. Only the plan and the rules are offered. (Example labs keep their setup choices.)
    private var ownBaseTest: Bool { session.baseTest.map { !$0.isExample } ?? false }

    /// A reference drill whose equipment is already built (The Living Base): every choice is in the plan.
    private var nothingToLoad: Bool { !session.isBaseTest && session.definition.catalog.isEmpty }

    /// The guided tour uses fixed starter equipment, so it shows no shop: only the plan and Launch.
    private var guided: Bool { model.tour != nil }
    private var guidedPlanOffered: Bool { model.tour?.step(for: session.stage) == .change }

    var body: some View {
        VStack(spacing: 8) {
            // In the guided tour the goal is shown in the tour's instruction area at the top instead.
            if !guided { goalBar }
            if planOpen {
                planPanel.transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let kind = session.selectedKind {
                selectionBar(kind).transition(.opacity)
            }
            if ownBaseTest {
                if narrow {
                    HStack(spacing: 10) { planButton; rulesButton }
                    launch()
                } else {
                    HStack(alignment: .bottom, spacing: 10) {
                        planButton.frame(width: 150)
                        rulesButton.frame(width: 210)
                        Spacer(minLength: 0)
                        launch().frame(width: launchWidth)
                    }
                }
            } else if guided {
                if narrow {
                    if guidedPlanOffered { planButton }
                    launch()
                } else {
                    HStack(alignment: .bottom, spacing: 10) {
                        if guidedPlanOffered { planButton.frame(width: 150) }
                        Spacer(minLength: 0)
                        launch().frame(width: launchWidth)
                    }
                }
            } else if narrow {
                if !planOpen { shopBar }
                launch()
            } else {
                HStack(alignment: .bottom, spacing: 10) {
                    shopBar
                    launch().frame(width: launchWidth)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: planOpen)
        .animation(.easeOut(duration: 0.2), value: session.selectedKind)
        .onAppear {
            if let suggested = session.revisionPhaseIndex { phaseIndex = suggested; planOpen = true }
            // Drills with nothing to load are decided entirely in the plan, so start there.
            else if nothingToLoad && !narrow { planOpen = true }
        }
        .onChange(of: indices) { _, available in
            if !available.contains(phaseIndex) { phaseIndex = available.first ?? 0 }
        }
        .onChange(of: planOpen) { _, open in if open { session.clearSelection() } }
        .sheet(isPresented: $showHelp) { helpSheet }
        .sheet(isPresented: $showRules) { BaseTestRulesSheet(session: session) { showRules = false } }
    }

    // MARK: Goal

    private var goalBar: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: tutorialActive ? "hand.point.down.fill" : "target")
                .font(.system(size: 20, weight: .black))
                .gameText(Color(hex: 0xFFE27A))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(tutorialActive ? "Tap the glowing solar array in the shop to build it on your base."
                     : session.copy.objectives.joined(separator: " • "))
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .gameText()
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                if ownBaseTest, let gear = session.baseTest?.inputs {
                    Text(gear.shelter == true && session.baseTest?.kind == .storm
                         ? "Uses your real base: working shelter, \(gear.batteries) \(gear.batteries == 1 ? "battery" : "batteries"). Build at your base to change it."
                         : "Uses your real base: \(gear.summary). Build at your base to change it.")
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .gameText(Color(hex: 0xC9D6E8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let notice = session.notice ?? session.issues.first?.childMessage, notice != MissionSession.baseGearNotice {
                    Text(notice)
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .gameText(Color(hex: 0xFFC2B3))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 4)
            RoundIconButton(symbol: "questionmark", label: "Mission help", size: 44) { showHelp = true }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    // MARK: Selected building

    private func selectionBar(_ kind: CargoKind) -> some View {
        let name = CargoCopy.name(kind)
        return HStack(spacing: 10) {
            CargoIconView(kind: kind).frame(width: 46, height: 40).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(name).font(.game(.headline)).gameText()
                Text("\(session.count(kind)) on your base").font(.system(.caption, design: .rounded).weight(.heavy))
                    .gameText(Color(hex: 0xC9D6E8))
            }
            Spacer(minLength: 8)
            Button {
                session.removeSelected()
                Haptics.thump()
                SoundFX.shared.play(.remove)
            } label: {
                Label("Remove", systemImage: "trash.fill")
            }
            .buttonStyle(GameButtonStyle(bevel: GamePalette.coral, height: 46, font: .game(.headline)))
            .frame(width: 150)
            .accessibilityLabel("Remove this \(name.lowercased())")
            .accessibilityIdentifier("selected.remove")
            Button { session.clearSelection() } label: {
                Image(systemName: "xmark").font(.system(size: 18, weight: .black)).gameText()
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Keep it")
        }
        .padding(.horizontal, 12).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(GamePalette.hud))
        .accessibilityElement(children: .contain)
    }

    // MARK: Shop

    private var shopTitle: String {
        if nothingToLoad { return "Already built for this drill" }
        guard let test = session.baseTest else { return "Equipment shop" }
        return test.isExample ? "Example lab: build, then test" : "Your base equipment"
    }

    private var shopBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(shopTitle).font(.game(.subheadline)).gameText()
                if !session.isBaseTest && session.definition.cargoBudget > 0 {
                    Label("\(session.cargoCost)/\(session.definition.cargoBudget)", systemImage: "shippingbox.fill")
                        .font(.system(.caption, design: .rounded).weight(.black))
                        .gameText(Color(hex: 0xFFE27A))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.3)))
                        .accessibilityLabel("Lander space: \(session.cargoCost) of \(session.definition.cargoBudget) crates used")
                }
                Spacer(minLength: 4)
                planButton.frame(width: 128)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) { shopItems }
                    .padding(2)
            }
            .accessibilityIdentifier("mission.cargoTray")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x24395A, opacity: 0.94), Color(hex: 0x111D33, opacity: 0.96)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.22), lineWidth: 2))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        }
        .shake(session.shakeToken)
        .animation(.default, value: session.shakeToken)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mission.planningDesk")
    }

    private var planButton: some View {
        Button { planOpen.toggle() } label: {
            Label("Plan", systemImage: "slider.horizontal.3")
        }
        .buttonStyle(GameButtonStyle(bevel: planOpen ? GamePalette.energy : GamePalette.gold, height: 44, font: .game(.subheadline)))
        .disabled(tutorialActive)
        .accessibilityLabel("Operating plan")
        .accessibilityAddTraits(planOpen ? .isSelected : [])
        .accessibilityHint(planOpen ? "Closes the plan" : "Opens the plan")
        .accessibilityIdentifier("planning.section.plan")
    }

    private var rulesButton: some View {
        Button { showRules = true } label: {
            Label("How this test works", systemImage: "info.circle.fill")
        }
        .buttonStyle(GameButtonStyle(bevel: GamePalette.steel, height: 44, font: .game(.subheadline)))
        .accessibilityLabel("How this test works")
        .accessibilityIdentifier("mission.testRules")
    }

    @ViewBuilder private var shopItems: some View {
        if let test = session.baseTest {
            // Example labs build like a base: add or remove equipment, then test again. It is free here.
            if test.kind == .storm {
                ShopFace(cargo: .shelterKit, title: "Working shelter", detail: "Protects the crew")
                    .accessibilityElement(children: .combine)
            } else {
                ExampleGearTile(kind: .solarArray, count: test.inputs.arrays, detail: "Free in the lab",
                                add: { model.changeExampleGear(.solarArray, by: 1) },
                                remove: { model.changeExampleGear(.solarArray, by: -1) })
            }
            ExampleGearTile(kind: .battery, count: test.inputs.batteries,
                            detail: test.kind == .storm ? "Starts charged" : "Starts empty",
                            add: { model.changeExampleGear(.battery, by: 1) },
                            remove: { model.changeExampleGear(.battery, by: -1) })
            ShopFace(symbol: "info.circle.fill", title: "How this test works",
                     detail: test.kind == .storm
                        ? "Prep \(Format.kWh(session.definition.item(.shelterKit)?.assemblyEnergyKWh ?? 0)) • Backup \(Format.kW(session.definition.phases.first?.baseSupplyKW ?? 0))"
                        : "Rules and sources")
                .button { showRules = true }
                .accessibilityLabel("How this test works")
                .accessibilityIdentifier("mission.testRules")
            ShopFace(symbol: "arrow.counterclockwise", title: "Reset lab", detail: "1 of each, Full air")
                .button { model.openExampleMission(.starter, resetHistory: true, kind: test.kind) }
                .accessibilityLabel("Reset lab to starter plan")
                .accessibilityIdentifier("example.reset")
        } else if nothingToLoad {
            if session.definition.missionID == .livingBase {
                ShopFace(symbol: "leaf.fill", title: "Greenhouse", detail: "Ready to grow")
                    .accessibilityElement(children: .combine)
            }
            Text("Nothing to load in this drill. Your choices are in the Plan: greenhouse lights and the air maker for each block.")
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .gameText(Color(hex: 0xC9D6E8))
                .frame(maxWidth: 360, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 4)
        } else {
            ForEach(session.definition.catalog) { item in
                ShopTile(session: session, item: item,
                         highlighted: tutorialActive && item.kind == .solarArray,
                         dimmed: tutorialActive && item.kind != .solarArray)
            }
        }
    }

    // MARK: Plan

    private var planPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Label("Operating plan", systemImage: "slider.horizontal.3")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                Spacer(minLength: 8)
                if indices.contains(phaseIndex) {
                    Button { openPlan(phaseIndex) } label: {
                        Image(systemName: "info.circle").font(.title3).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("\(PlanCard.title(session, phaseIndex)) plan")
                }
                Button { planOpen = false } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close plan")
                .accessibilityIdentifier("planning.section.equipment")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(indices, id: \.self) { index in
                        Button { phaseIndex = index } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(index + 1). \(PlanCard.title(session, index))").fontWeight(.bold)
                                Text(Format.hours(session.definition.phases[index].durationHours)).font(.caption)
                            }
                            .font(.subheadline).padding(.horizontal, 14).frame(minHeight: 48)
                            .foregroundStyle(phaseIndex == index ? Theme.ink : Theme.inkSecondary)
                            .background(RoundedRectangle(cornerRadius: 12).fill(phaseIndex == index ? Theme.amber.opacity(0.3) : Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(phaseIndex == index ? Theme.amber : Theme.panelLine, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("planning.phase.\(index)")
                        .accessibilityAddTraits(phaseIndex == index ? .isSelected : [])
                    }
                }
            }
            ScrollView {
                Group {
                    if indices.contains(phaseIndex) {
                        if session.definition.missionID == .livingBase {
                            PlanCard(session: session, index: phaseIndex) { openPlan(phaseIndex) }
                        } else {
                            QuickPlanCard(session: session, index: phaseIndex,
                                          openDetails: { openPlan(phaseIndex) }, fullWidth: true, embedded: true,
                                          highlightAir: model.tour?.airToHighlight(stage: session.stage, phase: phaseIndex,
                                                                                    configuration: session.configuration))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
            }
            .frame(maxHeight: panelMaxHeight)
            .accessibilityIdentifier("mission.planningDeskContent")
        }
        .foregroundStyle(Theme.ink).tint(Theme.energyInk)
        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 12)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.panel)
            .shadow(color: .black.opacity(0.22), radius: 14, y: 5))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.9), lineWidth: 2))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mission.planPanel")
    }

    private var helpSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(session.copy.objectives, id: \.self) { Text($0).fontWeight(.semibold) }
                    Text(session.novaLine).font(.headline)
                    PlanningGuide(session: session)
                    InvestigationReminder(session: session)
                }.padding()
            }
            .navigationTitle("Mission help")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showHelp = false } } }
        }
    }
}

// MARK: Shop tiles

/// A game-shop card: artwork, name and a short detail on a dark bevelled tile.
struct ShopFace: View {
    var cargo: CargoKind?
    var symbol: String?
    let title: String
    let detail: String
    var selected = false
    var highlighted = false
    @ScaledMetric(relativeTo: .footnote) private var width: CGFloat = 112

    init(cargo: CargoKind, title: String, detail: String, selected: Bool = false, highlighted: Bool = false) {
        self.cargo = cargo; self.title = title; self.detail = detail; self.selected = selected; self.highlighted = highlighted
    }

    init(symbol: String, title: String, detail: String) {
        self.symbol = symbol; self.title = title; self.detail = detail
    }

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if let cargo {
                    CargoIconView(kind: cargo)
                } else if let symbol {
                    Image(systemName: symbol).font(.system(size: 30, weight: .black)).gameText(Color(hex: 0xBFE9F2))
                }
            }
            .frame(height: 46)
            .accessibilityHidden(true)
            Text(title)
                .font(.system(.footnote, design: .rounded).weight(.heavy)).gameText()
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(.system(.caption2, design: .rounded).weight(.bold)).gameText(Color(hex: 0xC9D6E8))
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8).padding(.horizontal, 6)
        .frame(width: width)
        .frame(minHeight: 112, alignment: .top)
        .background(ShopTileBackground(highlighted: highlighted, active: selected))
        .overlay(alignment: .topTrailing) {
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white, Theme.plantInk)
                    .padding(5)
                    .accessibilityHidden(true)
            }
        }
    }

    func button(_ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: { self }
        .buttonStyle(PressableStyle())
    }
}

struct ShopTileBackground: View {
    var highlighted = false
    var active = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: 0x0A1222))
                .offset(y: 4)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: active ? [Color(hex: 0x3C8C9B), Color(hex: 0x1D5965)]
                                                    : [Color(hex: 0x41618C), Color(hex: 0x293F60)],
                                     startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(highlighted ? Theme.amber : Color.white.opacity(active ? 0.7 : 0.3), lineWidth: highlighted ? 3 : 2)
        }
    }
}

/// A piece of lander cargo: tap the card to build one; the separate − button below removes one.
struct ShopTile: View {
    let session: MissionSession
    let item: CargoItem
    var highlighted = false
    var dimmed = false
    @ScaledMetric(relativeTo: .footnote) private var width: CGFloat = 112
    @Environment(\.appReduceMotion) private var reduceMotion
    @State private var glow = false

    var body: some View {
        let count = session.count(item.kind)
        let name = CargoCopy.name(item.kind)
        let affordable = session.canAdd(item.kind)
        VStack(spacing: 6) {
            Button {
                if session.addCargo(item.kind) { Haptics.thump(); SoundFX.shared.play(.pop) }
                else { Haptics.warning(); SoundFX.shared.play(.denied) }
            } label: {
                VStack(spacing: 4) {
                    CargoIconView(kind: item.kind).frame(height: 46).accessibilityHidden(true)
                    Text(name)
                        .font(.system(.footnote, design: .rounded).weight(.heavy)).gameText()
                        .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                    Label("\(item.cost)", systemImage: "shippingbox.fill")
                        .font(.system(.caption, design: .rounded).weight(.black))
                        .gameText(affordable || count >= item.maxCount ? Color(hex: 0xFFE27A) : Color(hex: 0xFFB4A2))
                }
                .padding(.vertical, 8).padding(.horizontal, 6)
                .frame(width: width)
                .frame(minHeight: 112, alignment: .top)
                .background(ShopTileBackground(highlighted: highlighted, active: count > 0))
                .overlay(alignment: .topLeading) {
                    Text("\(count)/\(item.maxCount)")
                        .font(.system(.caption2, design: .rounded).weight(.black)).monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.black.opacity(0.45)))
                        .padding(5)
                }
                .scaleEffect(highlighted && glow ? 1.06 : 1)
            }
            .buttonStyle(PressableStyle())
            .disabled(dimmed)
            .accessibilityLabel("Add \(name.lowercased())")
            .accessibilityValue("\(count) on board, costs \(item.cost) crate\(item.cost == 1 ? "" : "s")")
            .accessibilityIdentifier("cargo.add.\(item.kind.rawValue)")
            Button {
                session.removeCargo(item.kind)
                SoundFX.shared.play(.remove)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .black))
                    .gameText()
                    .frame(width: width - 24, height: 32)
                    .background(Capsule().fill(LinearGradient(colors: [GamePalette.coral.top, GamePalette.coral.bottom],
                                                              startPoint: .top, endPoint: .bottom)))
                    .frame(width: width, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .disabled(count == 0 || session.tutorial == .placeFirstArray)
            .opacity(count == 0 ? 0.35 : 1)
            .accessibilityLabel("Remove \(name.lowercased())")
            .accessibilityIdentifier("cargo.remove.\(item.kind.rawValue)")
        }
        .opacity(dimmed ? 0.45 : 1)
        .accessibilityElement(children: .contain)
        .onAppear {
            guard highlighted, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}

/// Equipment in an example lab: tap the card to add one, the − button below to remove one (1 to 4 of each).
struct ExampleGearTile: View {
    let kind: CargoKind
    let count: Int
    let detail: String
    let add: () -> Bool
    let remove: () -> Bool
    @ScaledMetric(relativeTo: .footnote) private var width: CGFloat = 112

    var body: some View {
        let name = CargoCopy.name(kind)
        let range = AppModel.exampleRange
        VStack(spacing: 6) {
            Button {
                if add() { Haptics.thump(); SoundFX.shared.play(.pop) }
                else { Haptics.warning(); SoundFX.shared.play(.denied) }
            } label: {
                VStack(spacing: 4) {
                    CargoIconView(kind: kind).frame(height: 46).accessibilityHidden(true)
                    Text(name)
                        .font(.system(.footnote, design: .rounded).weight(.heavy)).gameText()
                        .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                    Text(detail)
                        .font(.system(.caption2, design: .rounded).weight(.bold)).gameText(Color(hex: 0xC9D6E8))
                        .multilineTextAlignment(.center).lineLimit(2)
                }
                .padding(.vertical, 8).padding(.horizontal, 6)
                .frame(width: width)
                .frame(minHeight: 112, alignment: .top)
                .background(ShopTileBackground(active: true))
                .overlay(alignment: .topLeading) {
                    Text("\(count)/\(range.upperBound)")
                        .font(.system(.caption2, design: .rounded).weight(.black)).monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.black.opacity(0.45)))
                        .padding(5)
                }
            }
            .buttonStyle(PressableStyle())
            .opacity(count >= range.upperBound ? 0.6 : 1)
            .accessibilityLabel("Add \(name.lowercased())")
            .accessibilityValue("\(count) on board")
            .accessibilityIdentifier("cargo.add.\(kind.rawValue)")
            Button {
                if remove() { SoundFX.shared.play(.remove) }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .black))
                    .gameText()
                    .frame(width: width - 24, height: 32)
                    .background(Capsule().fill(LinearGradient(colors: [GamePalette.coral.top, GamePalette.coral.bottom],
                                                              startPoint: .top, endPoint: .bottom)))
                    .frame(width: width, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .disabled(count <= range.lowerBound)
            .opacity(count <= range.lowerBound ? 0.35 : 1)
            .accessibilityLabel("Remove \(name.lowercased())")
            .accessibilityIdentifier("cargo.remove.\(kind.rawValue)")
        }
        .accessibilityElement(children: .contain)
    }
}

/// The rules for "Test My Base" and its examples, shared by every layout.
struct BaseTestRulesSheet: View {
    let session: MissionSession
    let done: () -> Void

    var body: some View {
        let storm = session.baseTest?.kind == .storm
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(storm ? "Protect the crew and finish the science task" : "Generate energy, then store it")
                        .font(.title2.bold())
                    Text(storm
                         ? "This rehearsal lasts \(Format.hours(session.definition.totalHours)), using an archived storm. Stay sheltered, leave \(Format.wholeHours(session.definition.success.minimumAirHours)) of air, and supply \(Format.kWh(session.definition.success.minimumResearchUnits)) to the science task."
                         : "Solar arrays make electricity in sunlight. Batteries store energy for the shadow. More empty storage cannot create energy.")
                    Text(storm
                         ? "Batteries start charged. Preparing the shelter uses \(Format.kWh(session.definition.item(.shelterKit)?.assemblyEnergyKWh ?? 0)). An independent training backup supplies \(Format.kW(session.definition.phases.first?.baseSupplyKW ?? 0)); solar arrays do not supply this rehearsal."
                         : "Every working array and battery counts the same as in Lights Out. Positions and decorations do not change these calculations.")
                    Text("Equipment values are training rules. Crew oxygen demand comes from NASA references. Storm timing comes from archived observations near Earth; this game does not calculate radiation dose.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding()
            }
            .navigationTitle("How this test works")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", action: done) } }
        }
    }
}
