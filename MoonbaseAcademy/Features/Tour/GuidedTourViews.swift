import SwiftUI

/// A gold ring around the control the tour is waiting for. Steady, not pulsing, with reduced motion.
struct TourHighlight: ViewModifier {
    let active: Bool
    var corner: CGFloat = 16
    @Environment(\.appReduceMotion) private var reduceMotion
    @State private var pulse = false

    func body(content: Content) -> some View {
        content.overlay {
            if active {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color(hex: 0xFFD66B), lineWidth: 4)
                    .opacity(reduceMotion || pulse ? 1 : 0.35)
                    .padding(-4)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = true }
                    }
                    .onDisappear { pulse = false }
            }
        }
    }
}

extension View {
    func tourHighlight(_ active: Bool, corner: CGFloat = 16) -> some View {
        modifier(TourHighlight(active: active, corner: corner))
    }
}

/// The tour's one instruction area: where you are, what to do next, and Back / Next / Exit.
struct TourBanner: View {
    let tour: GuidedTour
    let session: MissionSession
    let onExit: () -> Void

    private var step: TourStep { tour.step(for: session.stage) }
    private var running: Bool { session.stage == .playback }
    private var testingLine: String {
        "Testing: \(Format.number(session.definition.totalHours)) mission hours play in a few seconds."
    }

    private var title: String {
        switch step {
        case .question:
            return "Can this base stay powered through the shadow?"
        case .predict:
            return running ? testingLine : "Make a prediction, then test it."
        case .baseline:
            if running { return testingLine }
            return tour.baseline?.record.success == true ? "This plan worked. Try one change anyway." : "The power ran out. A failed test is useful evidence."
        case .change:
            if session.configuration == tour.target { return "Only one thing changed. Now tap Launch test." }
            if session.configuration == tour.start { return "Change one thing: tap Half for the shadow air maker." }
            return "For this tour, change only one thing: the shadow air maker to Half."
        case .repredict:
            return running ? "Testing the changed plan with the same engine." : "Predict again: will Half air last through the shadow?"
        case .compare:
            return "One change, two results."
        case .takeaway:
            return "Predict. Test. Explain. Improve."
        }
    }

    private var detail: String? {
        switch step {
        case .question:
            let gear = session.baseTest?.inputs.summary ?? "Starter base"
            let parts = session.definition.phases.map { "\(Format.hours($0.durationHours)) of \($0.id == "shadow" ? "shadow" : $0.label.lowercased())" }
            return "\(gear), air maker on Full. \(parts.joined(separator: ", then "))."
        case .predict, .repredict:
            return running ? nil : "Choose a forecast and a reason, then tap Start test."
        case .baseline:
            return nil
        case .change:
            return "Half saves electricity, but the crew then breathes stored oxygen."
        case .compare:
            return "Saving electricity used another limited resource."
        case .takeaway:
            return nil
        }
    }

    private var nextLabel: String? {
        if running { return "See result" }
        switch step {
        case .question: return "Predict"
        case .baseline: return "Try one change"
        case .compare: return "Next"
        case .predict, .repredict, .change, .takeaway: return nil
        }
    }

    var body: some View {
        let canGoBack = tour.canGoBack(stage: session.stage)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label("Guided mission tour", systemImage: "map.fill")
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .foregroundStyle(Color(hex: 0xFFE27A))
                Text("Step \(step.rawValue + 1) of \(TourStep.allCases.count)")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color(hex: 0xC9D6E8))
                    .accessibilityIdentifier("tour.progress")
                Spacer(minLength: 4)
                Button(action: onExit) {
                    Label("Exit", systemImage: "xmark")
                        .font(.system(.subheadline, design: .rounded).weight(.black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(minWidth: 44, minHeight: 44)
                        .background(Capsule().fill(Color.white.opacity(0.16)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Exit tour")
                .accessibilityHint("Returns to your base. Your saved game is unchanged.")
                .accessibilityIdentifier("tour.exit")
            }
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("tour.instruction")
            if let detail {
                Text(detail)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color(hex: 0xC9D6E8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if session.stage == .planning {
                Label {
                    Text("Goal: " + session.copy.objectives.joined(separator: " "))
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "target").accessibilityHidden(true)
                }
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(Color(hex: 0xFFE27A))
                .accessibilityIdentifier("tour.goal")
            }
            if canGoBack || nextLabel != nil {
                HStack(spacing: 10) {
                    if canGoBack {
                        Button { tour.back(session) } label: { Label("Back", systemImage: "chevron.left") }
                            .buttonStyle(GameButtonStyle(bevel: GamePalette.steel, height: 44, font: .game(.subheadline)))
                            .frame(maxWidth: 150)
                            .accessibilityLabel("Back one step")
                            .accessibilityIdentifier("tour.back")
                    }
                    Spacer(minLength: 0)
                    if let nextLabel {
                        Button { tour.next(session) } label: { Label(nextLabel, systemImage: "arrow.right") }
                            .buttonStyle(GameButtonStyle(bevel: GamePalette.gold, height: 44, font: .game(.subheadline)))
                            .frame(maxWidth: 230)
                            .accessibilityLabel(nextLabel)
                            .accessibilityIdentifier("tour.next")
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 640, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: 0x0B1426, opacity: 0.95)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color(hex: 0xFFD66B, opacity: 0.85), lineWidth: 2))
        .accessibilityElement(children: .contain)
    }
}

/// The tour's evidence, shown below the instruction area in place of the full result screen.
/// Every number is read from the two finished tests; nothing here is typed in.
struct TourEvidenceLayer: View {
    let tour: GuidedTour
    let session: MissionSession
    let topInset: CGFloat
    let onReplay: () -> Void
    let onLeave: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.45).ignoresSafeArea().accessibilityHidden(true)
            ScrollView {
                card
                    .foregroundStyle(Theme.ink)
                    .padding(16)
                    .frame(maxWidth: 560, alignment: .leading)
                    .background(GameCardBackground(corner: 24))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .contain)
            }
            .padding(.top, topInset)
        }
    }

    @ViewBuilder private var card: some View {
        switch tour.step(for: session.stage) {
        case .compare: comparison
        case .takeaway: takeaway
        default: firstResult
        }
    }

    // MARK: First test

    @ViewBuilder private var firstResult: some View {
        if let evidence = tour.baseline {
            VStack(alignment: .leading, spacing: 10) {
                Text("Test 1 • shadow air on \(MissionSession.airLabel(evidence.record.airShadow))")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.inkSecondary)
                outcome(evidence.record, large: true)
                if let stored = evidence.storedKWh, let needed = evidence.neededKWh {
                    HStack(alignment: .top, spacing: 10) {
                        fact("Stored in sunlight", Format.kWh(stored), symbol: "battery.50percent")
                        fact("This shadow needed", Format.kWh(needed), symbol: "moon.fill")
                    }
                }
                forecastLine(evidence)
            }
            .accessibilityIdentifier("tour.firstResult")
        }
    }

    // MARK: Comparison

    @ViewBuilder private var comparison: some View {
        if let first = tour.baseline, let second = tour.revised {
            let changes = tour.changes
            VStack(alignment: .leading, spacing: 10) {
                Text("Same base, same shadow. What changed:")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.inkSecondary)
                ForEach(changes, id: \.self) { change in
                    Label(change, systemImage: "arrow.left.arrow.right")
                        .font(.game(.headline))
                        .foregroundStyle(Theme.energyInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if changes.count != 1 {
                    Text(changes.isEmpty ? "Nothing changed between these tests."
                         : "\(changes.count) things changed, so this is not a one-change comparison.")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.warningInk)
                }
                HStack(alignment: .top, spacing: 10) {
                    column("Test 1", first.record)
                    column("Test 2", second.record)
                }
                HStack(alignment: .top, spacing: 10) {
                    if let saved = tour.electricitySavedKWh {
                        fact("Electricity saved", Format.kWh(saved), symbol: "bolt.fill")
                    }
                    if let oxygen = tour.oxygenUsedKg {
                        fact("Stored oxygen used", Format.kg(oxygen), symbol: "lungs.fill")
                    }
                }
                forecastLine(second)
            }
            .accessibilityIdentifier("tour.comparison")
        }
    }

    // MARK: Takeaway

    private var takeaway: some View {
        let shadowHours = session.definition.phases.indices.contains(tour.shadowIndex)
            ? session.definition.phases[tour.shadowIndex].durationHours : 0
        return VStack(alignment: .leading, spacing: 10) {
            source("checkmark.seal.fill", Theme.plantInk,
                   "From a NASA reference: crew oxygen use, \(Format.number(session.science.oxygenKgPerPersonDay, digits: 3)) kg per person per day (NASA BVAD).")
            source("gamecontroller.fill", Theme.amberInk,
                   "Training rules made for this game: solar array and battery sizes, the simple air maker, and the \(Format.hours(shadowHours)) shadow. A real lunar night is far longer.")
            source("info.circle.fill", Theme.inkSecondary,
                   "No live data. Hours of mission time play in seconds. NASA does not endorse this app.")
            Text("More to investigate in the game: growing food, a solar storm, and rover signal delay.")
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button(action: onReplay) { Label("Replay tour", systemImage: "arrow.counterclockwise") }
                    .buttonStyle(GameButtonStyle(bevel: GamePalette.steel, height: 52, font: .game(.headline)))
                    .accessibilityLabel("Replay tour")
                    .accessibilityIdentifier("tour.replay")
                Button(action: onLeave) { Label("Return to base", systemImage: "house.fill") }
                    .buttonStyle(GameButtonStyle(bevel: GamePalette.go, height: 52, font: .game(.headline)))
                    .accessibilityLabel("Return to base")
                    .accessibilityIdentifier("tour.finish")
            }
            .padding(.top, 4)
        }
    }

    // MARK: Pieces

    private func outcome(_ record: BaseTestRecord, large: Bool) -> some View {
        let planned = Format.number(record.plannedHours ?? session.definition.totalHours)
        let text = record.success
            ? "Powered for all \(planned) hours"
            : "Power ran out at hour \(Format.number(record.elapsedHours ?? 0)) of \(planned)"
        return Label(text, systemImage: record.success ? "checkmark.circle.fill" : "bolt.slash.fill")
            .font(.game(large ? .title3 : .subheadline))
            .foregroundStyle(record.success ? Theme.plantInk : Theme.warningInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func column(_ title: String, _ record: BaseTestRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.black))
                .foregroundStyle(Theme.inkSecondary)
            Text("Shadow air: \(MissionSession.airLabel(record.airShadow))")
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
            outcome(record, large: false)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.panel))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.panelLine, lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }

    private func fact(_ label: String, _ value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(label, systemImage: symbol)
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.black).monospacedDigit())
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.energyInk.opacity(0.1)))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func forecastLine(_ evidence: TourEvidence) -> some View {
        if let forecast = evidence.forecast {
            let verdict = evidence.forecastRight == nil ? "You were unsure. Now you have evidence."
                : (evidence.forecastRight == true ? "It matched what happened." : "The result was different.")
            Text("Your forecast: \(forecast). \(verdict)")
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func source(_ symbol: String, _ color: Color, _ text: String) -> some View {
        Label {
            Text(text)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).foregroundStyle(color)
        }
    }
}
