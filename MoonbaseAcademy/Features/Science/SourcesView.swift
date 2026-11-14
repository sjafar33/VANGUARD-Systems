import SwiftUI

/// Where every number comes from, in words a child can follow, with the full references for adults.
struct SourcesView: View {
    let package: SciencePackage
    let focus: MissionDefinition?
    @Environment(\.dismiss) private var dismiss

    private var inputs: ScienceInputs? { validateContent(package: package).inputs }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Every number in this game is one of three kinds. NASA reference numbers come from NASA documents and data. Worked-out numbers are calculated from those. Training numbers were made up for this game so the drills stay short and fair.")
                        .font(.body)
                    ForEach([EvidenceCategory.nasaReference, .derived, .trainingAssumption], id: \.self) { category in
                        CategoryChip(category: category)
                    }
                }
                if let focus {
                    Section("Used in \(focus.title)") {
                        ForEach(package.values.filter { focus.sourceIDs.contains($0.sourceID ?? "") }) { value in
                            ValueRow(value: value, source: package.source(value.sourceID), verification: verification(value.sourceID))
                        }
                        if focus.missionID == .stormDrill, let event = package.events.first {
                            EventRow(event: event, source: package.source(event.sourceID), inputs: inputs)
                        }
                    }
                }
                Section("NASA references and constants") {
                    ForEach(package.values) { value in
                        ValueRow(value: value, source: package.source(value.sourceID), verification: verification(value.sourceID))
                    }
                    ForEach(package.events) { event in
                        EventRow(event: event, source: package.source(event.sourceID), inputs: inputs)
                    }
                }
                if let inputs {
                    Section("Worked out from the references") {
                        DerivedRow(title: "Radio delay, Earth to Moon", value: Format.seconds(inputs.oneWayDelaySeconds),
                                   formula: "384,400 km ÷ 299,792.458 km/s")
                        DerivedRow(title: "Picture to Earth plus command back", value: Format.seconds(inputs.commandLoopDelaySeconds),
                                   formula: "2 × one-way delay")
                        DerivedRow(title: "Storm rising (threshold to peak)", value: Format.hours(inputs.stormRisingHours),
                                   formula: "2017-09-11 11:45 UTC − 2017-09-10 16:45 UTC")
                        DerivedRow(title: "Storm fading (peak to end)", value: Format.hours(inputs.stormDecliningHours),
                                   formula: "2017-09-14 18:50 UTC − 2017-09-11 11:45 UTC")
                        DerivedRow(title: "Two crew members' oxygen per day", value: Format.kg(2 * inputs.oxygenKgPerPersonDay, digits: 3),
                                   formula: "2 × 0.895 kg")
                        DerivedRow(title: "Garden drill length", value: "\(Format.number(inputs.cropReferenceDays, digits: 0)) days",
                                   formula: "VEG-01 lettuce growth period")
                    }
                }
                Section("Made up for this training game") {
                    ForEach(Self.assumptions, id: \.self) { line in
                        Label(line, systemImage: "wrench.and.screwdriver")
                    }
                }
                Section("What the game does not model") {
                    ForEach(Self.limits, id: \.self) { line in
                        Text("• \(line)")
                    }
                }
                Section {
                    Text("Moonbase Academy is a student project for the NASA Space Apps Challenge. It uses public NASA information but is not made, checked or endorsed by NASA. Historical observations are labeled as historical, never as live data.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Where the numbers come from")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private func verification(_ sourceID: String?) -> VerificationRecord? {
        package.verification.first { $0.sourceID == sourceID }
    }

    static let assumptions = [
        "Two adult crew members live in the base. You, the player, are the engineer.",
        "Full air maker: 2.0 kg of oxygen per day using 0.5 kW. Half and off scale in a straight line.",
        "Lights, fans and controls that always run: 0.1 kW.",
        "Oxygen tank: 7.16 kg, about four days for two people. Each drill starts half full.",
        "Solar array: 1 kW in sunlight. Battery: 4 kWh. Cargo point costs.",
        "Garden: 16 hours of light a day for full growth; 0.01 kW when the lights are off.",
        "Garden drill: 17 kWh of energy available each day.",
        "Storm drill: 0.8 kW available on average; shelter takes 3 kWh to build; the crew must be inside for the whole storm.",
        "Rover: drives at a steady 1 m/s and stops instantly. The yellow bay is 5 to 6 m.",
        "Power and air use stay the same within each drill step. This is a training model, not an electrical simulator."
    ]

    static let limits = [
        "Radiation dose. The storm drill uses a simple shelter rule and never calculates a dose.",
        "Carbon dioxide, water, heat and full nutrition.",
        "Equipment failures and repairs.",
        "The real lunar day and night. The six-hour shadow drill is not a lunar night, which lasts about two weeks.",
        "Rover braking distance, rough ground and radio scheduling.",
        "Changes in the Moon's distance during its orbit."
    ]
}

struct CategoryChip: View {
    let category: EvidenceCategory

    var body: some View {
        Label(category.childLabel, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
    }

    private var symbol: String {
        switch category {
        case .nasaReference: return "checkmark.seal.fill"
        case .derived: return "function"
        case .trainingAssumption: return "wrench.and.screwdriver.fill"
        case .physicalConstant: return "atom"
        }
    }

    private var color: Color {
        switch category {
        case .nasaReference: return Theme.energyInk
        case .derived: return Theme.plantInk
        case .trainingAssumption: return Theme.amberInk
        case .physicalConstant: return Theme.inkSecondary
        }
    }
}

struct ValueRow: View {
    let value: ScienceValueRecord
    let source: SourceReference?
    let verification: VerificationRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value.label).font(.headline)
            Text("\(Format.number(value.value, digits: 3)) \(value.unit)")
                .font(.title3.weight(.bold).monospacedDigit())
            CategoryChip(category: value.category)
            Text(value.notes).font(.subheadline).foregroundStyle(.secondary)
            if let source {
                if let url = URL(string: source.url) {
                    Link(source.title, destination: url).font(.subheadline)
                }
                Text(source.context).font(.footnote).foregroundStyle(.secondary)
            }
            if let locator = value.locator {
                Text("Where: \(locator)").font(.footnote).foregroundStyle(.secondary)
            }
            if let verification {
                Text("Checked \(verification.date): \(verification.method)").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct EventRow: View {
    let event: ScienceEventRecord
    let source: SourceReference?
    let inputs: ScienceInputs?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.label).font(.headline)
            Text("Crossed 10 pfu: \(event.thresholdCrossingUTC)\nPeak (\(Format.number(event.maxFluxPfu)) pfu): \(event.peakUTC)\nEnded: \(event.endUTC)")
                .font(.subheadline.monospacedDigit())
            if let inputs {
                Text("Active for \(Format.hours(inputs.stormActiveHours)), worked out from these times.")
                    .font(.subheadline.weight(.semibold))
            }
            CategoryChip(category: .nasaReference)
            Text(event.notes).font(.footnote).foregroundStyle(.secondary)
            if let source, let url = URL(string: source.url) {
                Link(source.title, destination: url).font(.subheadline)
                Text(source.context).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct DerivedRow: View {
    let title: String
    let value: String
    let formula: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text(value).font(.headline.monospacedDigit())
            }
            Text(formula).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct SettingsView: View {
    let model: AppModel
    @State private var name = ""
    @State private var confirmReset = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Your base") {
                    TextField("Base name", text: $name)
                        .submitLabel(.done)
                        .onSubmit { model.setBaseName(name) }
                }
                Section("Sound") {
                    Toggle("Sound effects", isOn: Binding(get: { model.progress.soundEnabled },
                                                          set: { model.setSoundEnabled($0) }))
                }
                Section("Motion") {
                    Toggle("Reduce motion", isOn: Binding(get: { model.progress.forceReducedMotion },
                                                          set: { model.setForceReducedMotion($0) }))
                    Text("Replaces moving animations with short step-by-step changes. Results are exactly the same.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Progress") {
                    Button("Reset all progress", role: .destructive) { confirmReset = true }
                }
                Section("About") {
                    Text("Moonbase Academy by VANGUARD Systems, made for the NASA Space Apps Challenge 2026. Works offline. No accounts, ads or tracking.")
                    Text("Code was written with help from an AI assistant. The team checked the science numbers against the NASA sources listed in the app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        model.setBaseName(name)
                        dismiss()
                    }
                }
            }
            .onAppear { name = model.progress.baseName }
            .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset progress", role: .destructive) {
                    model.resetProgress()
                    name = model.progress.baseName
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes completed drills and base improvements on this device.")
            }
        }
        .preferredColorScheme(.light)
    }
}
