import SpriteKit
import SwiftUI

@main
struct MoonbaseAcademyApp: App {
    /// Created once per process, so the save file and scenes are never rebuilt by view updates.
    @State private var model = AppModel(store: LaunchOptions.makeStore())

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}

struct RootView: View {
    let model: AppModel
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch model.content {
            case .invalid(let messages):
                ContentErrorView(messages: messages)
            case .ready(let package, _):
                ZStack {
                    if model.route == .mission, let session = model.session {
                        MissionView(model: model, session: session, package: package, isActive: scenePhase == .active)
                            .transition(.opacity)
                    } else {
                        BaseView(model: model, package: package, isActive: scenePhase == .active)
                            .transition(.opacity)
                    }
                }
                .animation(model.reduceMotion ? nil : .easeInOut(duration: 0.3), value: model.route)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            model.setSystemReduceMotion(systemReduceMotion)
            KeyboardDismissal.install()
            SoundFX.shared.startMusic()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: SoundFX.shared.recover()
            case .background: SoundFX.shared.pauseForBackground()
            default: break
            }
        }
        .onChange(of: systemReduceMotion) { _, newValue in model.setSystemReduceMotion(newValue) }
        .alert("Saved progress could not be opened",
               isPresented: Binding(get: { model.saveIssue != nil }, set: { _ in })) {
            Button("Start fresh") { model.startFresh() }
        } message: {
            Text(model.saveIssue ?? "")
        }
    }
}

struct ContentErrorView: View {
    let messages: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Label("Science data problem", systemImage: "exclamationmark.triangle.fill")
                    .font(.rounded(.title2))
                    .foregroundStyle(Theme.warningInk)
                Text("Moonbase Academy will not run with missing or broken reference data, because the drills would show made-up numbers.")
                    .foregroundStyle(Theme.ink)
                ForEach(messages, id: \.self) { message in
                    Text("• \(message)").foregroundStyle(Theme.ink)
                }
            }
            .padding(24)
        }
        .background(Theme.panel.ignoresSafeArea())
    }
}

/// Hosts a retained scene. The scene pauses when the app is not active.
struct WorldView: View {
    let coordinator: WorldCoordinator
    let isActive: Bool
    let summary: String

    var body: some View {
        SpriteView(scene: coordinator.scene, preferredFramesPerSecond: 30, options: [.ignoresSiblingOrder])
            .onChange(of: isActive, initial: true) { _, active in coordinator.scene.isPaused = !active }
            .accessibilityElement()
            .accessibilityLabel(summary)
            .accessibilityAddTraits(.isImage)
    }
}
