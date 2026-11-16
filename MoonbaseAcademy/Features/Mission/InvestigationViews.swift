import SwiftUI

/// "Your idea vs. what happened": the forecast and the observed result side by side, a clear verdict,
/// an optional reason check, and the suggested next experiment. Leaving or retrying is done with the
/// big buttons at the bottom of the result.
struct InvestigationResultCard: View {
    let session: MissionSession
    @State private var showReason = false
    @Environment(\.dynamicTypeSize) private var textSize

    private var verdict: (text: String, icon: String, color: Color) {
        switch session.predictionWasRight {
        case true?:
            return ("Your forecast matched.\(session.currentAttempt?.success == false ? " The mission still needs a working plan." : "")",
                    "checkmark.circle.fill", Theme.plantInk)
        case false?:
            return ("The result was different. Use this evidence to revise your idea.", "arrow.triangle.2.circlepath", Theme.warningInk)
        case nil:
            return ("You were unsure. Now you have evidence for your next idea.", "questionmark.circle.fill", Theme.energyInk)
        }
    }

    private var observed: String {
        if let result = session.resourceResult {
            return "\(Format.hours(result.trace.last?.endHour ?? 0)) of \(Format.hours(session.definition.totalHours)) completed. \(result.success ? "All mission goals met." : session.explanation?.headline ?? "A goal was missed.")"
        }
        if let result = session.roverResult { return "The rover stopped at \(Format.meters(result.finalStopM))." }
        return ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your idea vs. what happened")
                .font(.system(.headline, design: .rounded).weight(.black))
            let layout = textSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
            layout {
                fact("You expected", icon: "lightbulb.fill", tint: Theme.amber,
                     text: session.prediction.map { "\($0.outcome(in: session.definition))." } ?? "No forecast.")
                fact("What happened", icon: "eye.fill", tint: Theme.energy, text: observed)
            }
            if session.prediction != nil {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: verdict.icon).font(.headline).accessibilityHidden(true)
                    Text(verdict.text).fontWeight(.bold)
                }
                .foregroundStyle(verdict.color)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(verdict.color.opacity(0.1)))
            }
            if let cost = session.learningRecord,
               let saved = cost.energySavedKWh, let spent = cost.oxygenSpentKg, saved > 1e-9 || spent > 1e-9 {
                Label("Reserve cost: saved \(Format.kWh(saved)) against Full air; withdrew \(Format.kg(spent)) from the oxygen tank.",
                      systemImage: "lungs.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSecondary)
            }
            if let reason = session.predictionReason {
                PillButton(title: showReason ? "Hide the reason check" : "Check your reason",
                           icon: showReason ? "chevron.up" : "lightbulb", selected: showReason) {
                    withAnimation(.easeOut(duration: 0.2)) { showReason.toggle() }
                }
                if showReason {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your reason: \(reason.text)").fontWeight(.bold)
                        Text(reason.feedback).accessibilityIdentifier("prediction.reasonFeedback")
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white))
                }
            }
            if let changes = session.investigationChanges {
                VStack(alignment: .leading, spacing: 4) {
                    if changes.isEmpty {
                        Text("Equipment and settings stayed the same. The physical result repeats even when your prediction changes.")
                    } else {
                        Text("\(changes.count == 1 ? "One change" : "\(changes.count) changes"): \(changes.joined(separator: "; ")).")
                            .fontWeight(.semibold)
                        if changes.count > 1 { Text("For a clearer comparison, try changing one thing at a time.") }
                    }
                    if let previous = session.previousAttempt, let hours = previous.elapsedHours {
                        Text("Last test: \(previous.success ? "passed" : "stopped") at \(Format.hours(hours)). Compare elapsed time before comparing tank reserves.")
                            .font(.caption).foregroundStyle(Theme.inkSecondary)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Label("Next experiment", systemImage: "flask.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.black))
                    .foregroundStyle(Theme.amberInk)
                Text(session.revisionSuggestion.text)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.amber.opacity(0.18)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.amber.opacity(0.6), lineWidth: 1.5))
        }
        .font(.subheadline)
        .foregroundStyle(Theme.ink)
        .fixedSize(horizontal: false, vertical: true)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.panel))
        .onAppear { showReason = session.predictionReason?.supported == false }
    }

    private func fact(_ title: String, icon: String, tint: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.system(.caption, design: .rounded).weight(.black))
                .foregroundStyle(Theme.inkSecondary)
            Text(text).fontWeight(.semibold)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 4).padding(.vertical, 8)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A rounded, clearly tappable secondary button for toggles inside cards.
struct PillButton: View {
    let title: String
    let icon: String
    var selected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(selected ? Color.white : Theme.energyInk)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(Capsule().fill(selected ? Theme.energyInk : Theme.energyInk.opacity(0.12)))
                .overlay(Capsule().strokeBorder(Theme.energyInk.opacity(0.4), lineWidth: 1.5))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(title)
    }
}

struct InvestigationReminder: View {
    let session: MissionSession
    @State private var expanded = false

    var body: some View {
        if let last = session.currentAttempt {
            VStack(alignment: .leading, spacing: 6) {
                Text("Change one thing, then predict again.").font(.subheadline.weight(.bold))
                Button(expanded ? "Hide last prediction" : "Review last prediction", systemImage: "text.magnifyingglass") { expanded.toggle() }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.energyInk).frame(minHeight: 44)
                if expanded {
                    Text("You expected: \(last.prediction?.outcome(in: session.definition) ?? "not recorded in this older test").")
                    if let reason = last.reason { Text("Your reason: \(reason.text)") }
                    Text("We observed: \(last.headline)")
                    if let hours = last.elapsedHours { Text("Test stopped or finished at \(Format.hours(hours)).") }
                }
            }
            .foregroundStyle(Theme.ink).font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(GameCardBackground())
        }
    }
}
