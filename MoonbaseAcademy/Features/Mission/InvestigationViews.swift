import SwiftUI

struct InvestigationResultCard: View {
    let session: MissionSession
    @State private var showReason = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Compare your idea with the evidence").font(.headline)
            if let forecast = session.prediction {
                Text("You expected: \(forecast.outcome(in: session.definition)).")
                    .fontWeight(.semibold)
                Text(session.predictionWasRight == true
                     ? "Your forecast matched.\(session.currentAttempt?.success == false ? " The mission still needs a working plan." : "")"
                     : session.predictionWasRight == false ? "The result was different. Use this evidence to revise your idea."
                     : "You were unsure. Now you have evidence for your next idea.")
            }
            if let result = session.resourceResult {
                Text("We observed: \(Format.hours(result.trace.last?.endHour ?? 0)) of \(Format.hours(session.definition.totalHours)) completed. \(result.success ? "All mission goals met." : session.explanation?.headline ?? "A goal was missed.")")
                    .fontWeight(.semibold)
            } else if let result = session.roverResult {
                Text("We observed: the rover stopped at \(Format.meters(result.finalStopM)).")
                    .fontWeight(.semibold)
            }
            if let cost = session.learningRecord,
               let saved = cost.energySavedKWh, let spent = cost.oxygenSpentKg, saved > 1e-9 || spent > 1e-9 {
                Text("Reserve cost during this run: saved \(Format.kWh(saved)) against Full air; withdrew \(Format.kg(spent)) from the oxygen tank.")
            }
            if let reason = session.predictionReason {
                Button(showReason ? "Hide the reason check" : "Check your reason", systemImage: "lightbulb") {
                    showReason.toggle()
                }
                .font(.subheadline.weight(.bold)).foregroundStyle(Theme.energyInk).frame(minHeight: 44)
                if showReason {
                    Text("Your reason: \(reason.text)").fontWeight(.semibold)
                    Text(reason.feedback).accessibilityIdentifier("prediction.reasonFeedback")
                }
            }
            if let changes = session.investigationChanges {
                Divider()
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
            Text("Next experiment: \(session.revisionSuggestion.text)")
            Button("Try one change", systemImage: "arrow.counterclockwise") { session.reviseExperiment() }
                .font(.subheadline.weight(.bold)).foregroundStyle(Theme.energyInk).frame(minHeight: 44)
        }
        .font(.subheadline)
        .foregroundStyle(Theme.ink)
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panel))
        .onAppear { showReason = session.predictionReason?.supported == false }
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
