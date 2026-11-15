import SwiftUI

/// A bounded desk below the visible base. Equipment and operating settings have separate homes.
struct MissionPlanningWorkspace: View {
    let model: AppModel
    let session: MissionSession
    @Binding var section: Int
    @Binding var phaseIndex: Int
    let openPlan: (Int) -> Void
    @State private var showHelp = false

    private var indices: [Int] {
        if session.definition.missionID == .livingBase && session.sameSettingsForAllBlocks { return [0] }
        return Array(session.definition.phases.indices)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(section == 0 ? "Load your equipment" : "Operating plan",
                      systemImage: section == 0 ? "shippingbox.fill" : "slider.horizontal.3")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                Spacer(minLength: 8)
                if section == 1, indices.contains(phaseIndex) {
                    Button { openPlan(phaseIndex) } label: {
                        Image(systemName: "info.circle").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("\(PlanCard.title(session, phaseIndex)) plan")
                }
                Button("Help", systemImage: "questionmark.circle") { showHelp = true }
                    .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                    .accessibilityLabel("Mission help")
            }
            Text(session.copy.objectives.joined(separator: " • "))
                .font(.caption).foregroundStyle(Theme.inkSecondary).lineLimit(2)
            if let notice = session.notice ?? session.issues.first?.childMessage {
                Text(notice).font(.caption.weight(.bold)).foregroundStyle(Theme.warningInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) {
                sectionButton("Equipment", icon: "shippingbox", value: 0)
                sectionButton("Operating plan", icon: "slider.horizontal.3", value: 1)
            }
            if section == 1 {
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
            }
            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Color.clear.frame(height: 1).id("deskTop")
                        if section == 0 {
                            if session.baseTest?.isExample == true {
                                ExampleLabControls(model: model, kind: session.baseTest?.kind ?? .shadow, compact: true)
                            }
                            if session.isBaseTest {
                                Divider()
                                BaseGearCard(session: session, embedded: true)
                            } else {
                                Text(session.tutorial == .placeFirstArray
                                     ? "Tap + on the solar array to power your base."
                                     : "Tap + to load. Tap − to remove. Watch your base above.")
                                    .font(.subheadline).foregroundStyle(Theme.inkSecondary)
                                ScrollView(.horizontal, showsIndicators: true) {
                                    HStack(alignment: .top, spacing: 12) {
                                        ForEach(session.definition.catalog) { item in
                                            BuildCard(session: session, item: item,
                                                      highlighted: session.tutorial == .placeFirstArray && item.kind == .solarArray,
                                                      dimmed: session.tutorial == .placeFirstArray && item.kind != .solarArray)
                                        }
                                    }.padding(4)
                                }.accessibilityIdentifier("mission.cargoTray")
                            }
                        } else if indices.contains(phaseIndex) {
                            if session.definition.missionID == .livingBase {
                                PlanCard(session: session, index: phaseIndex) { openPlan(phaseIndex) }
                            } else {
                                QuickPlanCard(session: session, index: phaseIndex,
                                              openDetails: { openPlan(phaseIndex) }, fullWidth: true, embedded: true)
                                    .disabled(session.tutorial == .placeFirstArray)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
                }
                .accessibilityIdentifier("mission.planningDeskContent")
                .onChange(of: section) { _, _ in reader.scrollTo("deskTop", anchor: .top) }
                .onChange(of: phaseIndex) { _, _ in reader.scrollTo("deskTop", anchor: .top) }
            }
        }
        .foregroundStyle(Theme.ink).tint(Theme.energyInk)
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.panel)
            .shadow(color: .black.opacity(0.18), radius: 14, y: 5))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.9), lineWidth: 2))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mission.planningDesk")
        .onAppear {
            if let suggested = session.revisionPhaseIndex { section = 1; phaseIndex = suggested }
        }
        .onChange(of: indices) { _, available in
            if !available.contains(phaseIndex) { phaseIndex = available.first ?? 0 }
        }
        .sheet(isPresented: $showHelp) {
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

    private func sectionButton(_ title: String, icon: String, value: Int) -> some View {
        Button { section = value } label: {
            Label(title, systemImage: icon)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(section == value ? .white : Theme.energyInk)
                .background(RoundedRectangle(cornerRadius: 12).fill(section == value ? Theme.energyInk : Color.white))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("planning.section.\(value == 0 ? "equipment" : "plan")")
        .accessibilityAddTraits(section == value ? .isSelected : [])
    }
}
