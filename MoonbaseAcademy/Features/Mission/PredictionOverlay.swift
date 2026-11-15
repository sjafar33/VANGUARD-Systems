import SwiftUI

struct BetOverlay: View {
    let session: MissionSession
    var readAloud = false
    @State private var forecast: Prediction?
    @State private var reason: PredictionReason?
    @AccessibilityFocusState private var titleFocused: Bool

    private var reasons: [PredictionReason] { PredictionReason.choices(for: session.definition.missionID) }
    private var ready: Bool { forecast != nil && (forecast == .unsure || reason != nil) }
    private var spoken: String {
        ([session.copy.question] + Prediction.allCases.map { $0.outcome(in: session.definition) }
         + ["Why do you think that?"] + reasons.map(\.text)).joined(separator: ". ")
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().accessibilityHidden(true)
            ViewThatFits(in: .vertical) {
                card
                ScrollView { card.padding(.vertical, 18) }
            }
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { titleFocused = true } }
        .accessibilityAction(.escape) { session.backToPlanning() }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text("Make a prediction").font(.title2.bold()).accessibilityFocused($titleFocused)
                Spacer(minLength: 4)
                ReadAloudButton(enabled: readAloud, text: spoken, size: 44)
            }
            Text(session.copy.question).font(.headline)
            Text(session.copy.objectives.joined(separator: " "))
                .font(.subheadline).foregroundStyle(Theme.inkSecondary)
            ForEach(Prediction.allCases, id: \.self) { choice in
                selection(choice.outcome(in: session.definition), selected: forecast == choice) {
                    forecast = choice
                    if choice == .unsure { reason = .unsure }
                    else if reason == .unsure { reason = nil }
                }
                .accessibilityLabel(choice.label)
                .accessibilityHint(choice.outcome(in: session.definition))
            }
            if forecast != nil && forecast != .unsure {
                Text("Why do you think that?").font(.headline)
                ForEach(reasons, id: \.self) { idea in
                    selection(idea.text, selected: reason == idea) { reason = idea }
                        .accessibilityIdentifier("reason.\(idea.rawValue)")
                }
                selection(PredictionReason.unsure.text, selected: reason == .unsure) { reason = .unsure }
                    .accessibilityIdentifier("reason.unsure")
            }
            Text("Your equipment and settings decide the result. A prediction is an idea we can test.")
                .font(.caption).foregroundStyle(Theme.inkSecondary)
            Button("Start test", systemImage: "play.fill") {
                guard let forecast, ready else { return }
                session.run(predicting: forecast, reason: reason ?? .unsure)
            }
            .buttonStyle(GameButtonStyle(bevel: GamePalette.go, height: 50, font: .game(.headline)))
            .disabled(!ready)
            .accessibilityHint(ready ? "Test this plan and compare with your prediction" : "Choose a prediction and a reason first")
            PlaybackModePicker(session: session)
            Button("Change my plan") { session.backToPlanning() }
                .font(.subheadline.weight(.bold)).foregroundStyle(Theme.energyInk).frame(minHeight: 44)
        }
        .foregroundStyle(Theme.ink)
        .fixedSize(horizontal: false, vertical: true)
        .padding(18)
        .frame(maxWidth: 540)
        .background(GameCardBackground(corner: 24))
        .padding(18)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private func selection(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                Text(text).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(selected ? Color.white : Theme.ink)
            .padding(12).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(selected ? Theme.energyInk : Theme.panel))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.panelLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
