import SwiftUI

struct BaseView: View {
    let model: AppModel
    let package: SciencePackage
    let isActive: Bool
    @State private var showSources = false
    @State private var showSettings = false

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
                        world.frame(height: max(250, proxy.size.height * 0.46))
                        panel
                    }
                }
            }
        }
        .sheet(isPresented: $showSources) { SourcesView(package: package, focus: nil) }
        .sheet(isPresented: $showSettings) { SettingsView(model: model) }
    }

    private var world: some View {
        WorldView(coordinator: model.baseWorld, isActive: isActive, summary: model.baseSummary)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.progress.baseName)
                        .font(.rounded(.title2))
                    Text("VANGUARD Systems training base")
                        .font(.footnote.weight(.semibold))
                        .opacity(0.8)
                }
                .foregroundStyle(Theme.ceramic)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.space.opacity(0.72)))
                .padding(12)
                .accessibilityElement(children: .combine)
            }
    }

    private var completedCount: Int { model.progress.completedMissions.count }

    private var panel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(completedCount == 0 ? "Welcome, engineer!" : "Training progress")
                        .font(.rounded(.title2))
                        .foregroundStyle(Theme.ink)
                    Text(completedCount == MissionID.allCases.count
                         ? "All four drills complete. Replay any drill or try a harder version."
                         : "Finish each short drill to improve your base. \(completedCount) of \(MissionID.allCases.count) done.")
                        .font(.body)
                        .foregroundStyle(Theme.inkSecondary)
                }
                ForEach(MissionID.allCases) { id in
                    MissionCard(id: id, progress: model.progress, isNext: model.nextMission == id,
                                open: { model.openMission(id) },
                                openVariant: { model.openMission(id, variant: true) })
                }
                HStack(spacing: 10) {
                    Button { showSources = true } label: {
                        Label("NASA sources", systemImage: "books.vertical.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    Button { showSettings = true } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                if let error = model.lastSaveError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.warningInk)
                        .font(.footnote)
                }
            }
            .padding(16)
        }
        .background(Theme.panel)
    }
}

struct MissionCard: View {
    let id: MissionID
    let progress: CampaignProgress
    let isNext: Bool
    let open: () -> Void
    let openVariant: () -> Void

    var body: some View {
        let copy = MissionCopy.of(id)
        let done = progress.isCompleted(id)
        let unlocked = progress.isUnlocked(id)
        let number = (MissionID.allCases.firstIndex(of: id) ?? 0) + 1
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: copy.symbol)
                    .font(.title2)
                    .foregroundStyle(unlocked ? Theme.ink : Theme.inkSecondary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(done ? Theme.plant.opacity(0.35) : (isNext ? Theme.amber.opacity(0.45) : Theme.panel)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Drill \(number): \(title)")
                        .font(.rounded(.headline))
                        .foregroundStyle(Theme.ink)
                    Text(copy.topic)
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                    if done {
                        Label("Complete", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.plantInk)
                    } else if !unlocked {
                        Label("Finish the drill before this one", systemImage: "lock.fill")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            if unlocked {
                HStack(spacing: 8) {
                    Button(action: open) {
                        Text(done ? "Replay" : (isNext ? "Start drill" : "Open"))
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: done ? Theme.panelLine : Theme.amber))
                    if done {
                        Button(action: openVariant) {
                            Text("Harder drill")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
            }
        }
        .card()
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(isNext ? Theme.amber : Color.clear, lineWidth: 2.5))
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        switch id {
        case .lightsOut: return "Lights Out"
        case .livingBase: return "The Living Base"
        case .stormDrill: return "Storm Drill"
        case .signalLag: return "Signal Lag"
        }
    }
}
