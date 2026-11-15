import SwiftUI

/// An always-visible mental model, with replayable help instead of assumed prior knowledge.
struct PlanningGuide: View {
    let session: MissionSession
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if session.definition.missionID == .lightsOut {
                Label("Make energy first. Save it for the shadow.", systemImage: "sun.max.fill")
                    .font(.headline)
                Text(session.definition.phases.enumerated().map {
                    "\($0.offset + 1). \($0.element.mood == .shadow ? "Shadow" : "Sunlight"): \(Format.hours($0.element.durationHours))"
                }.joined(separator: "  →  "))
                    .font(.subheadline.weight(.semibold))
            } else {
                Label("Plan for each part in order", systemImage: "list.number")
                    .font(.headline)
            }
            DisclosureGroup("How do power and air work?", isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Solar arrays make electricity in sunlight. Batteries store energy for later; extra empty storage cannot make electricity.")
                    Text("The air maker uses power to make oxygen. Full makes more oxygen; Half saves power. With Half or Off, the crew can use oxygen already stored in the tank.")
                    Text("Science instruments also need power. Read the goal: science is an extra in some drills and required in the storm example.")
                    Text("This is a shortened training drill. Machine sizes and power settings are game rules. Crew oxygen demand uses NASA adult-astronaut references; open the books button to see the sources.")
                        .foregroundStyle(Theme.inkSecondary)
                }
                .font(.subheadline).padding(.top, 8)
            }
            .tint(Theme.energyInk)
            .frame(minHeight: 44)
        }
        .foregroundStyle(Theme.ink)
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GameCardBackground())
    }
}
