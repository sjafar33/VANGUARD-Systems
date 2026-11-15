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
        "Garden drill: 17 kWh of energy available each day (16 kWh in the harder version).",
        "Storm drill: 0.8 kW available on average; shelter takes 3 kWh to build; the crew must be inside for the whole storm. The lander holds 4 crates (3 in the harder version).",
        "Rover: drives at a steady 1 m/s (0.75 m/s in the harder version) and stops instantly. The yellow bay is 5 to 6 m.",
        "Power and air use stay the same within each drill step. This is a training model, not an electrical simulator.",
        "Building the base, Moon coins, upgrades and styles are game rules. They unlock drills and looks but never change the numbers inside a drill."
    ]

    static let limits = [
        "Radiation dose. The storm drill uses a simple shelter rule and never calculates a dose. The storm's timing was recorded near Earth and does not by itself tell us the dose on the Moon's surface.",
        "Lettuce on the Moon. The garden uses how long lettuce took on the space station as a training rule. It does not prove lettuce would grow the same way on the Moon.",
        "Training numbers. Power, battery, cargo, shadow length and rover numbers are game assumptions, not NASA measurements.",
        "Carbon dioxide, water, heat and full nutrition.",
        "Equipment failures and repairs.",
        "The real lunar day and night. The shadow drill (6 hours, or 9 in the harder version) is not a lunar night, which lasts about two weeks.",
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
    @State private var aboutTaps = 0
    @FocusState private var nameFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Your base") {
                    TextField("Base name", text: $name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .onSubmit { nameFocused = false }
                }
                Section("Sound") {
                    Toggle("Music", isOn: Binding(get: { model.progress.musicEnabled ?? true },
                                                  set: { model.setMusicEnabled($0) }))
                    Picker("Music style", selection: Binding(get: { model.progress.musicStyle ?? .spaceAmbient },
                                                             set: { model.setMusicStyle($0) })) {
                        ForEach(MusicStyle.allCases, id: \.self) { style in
                            Text(style.label).tag(style)
                        }
                    }
                    .disabled(!(model.progress.musicEnabled ?? true))
                    Toggle("Sound effects", isOn: Binding(get: { model.progress.soundEnabled },
                                                          set: { model.setSoundEnabled($0) }))
                }
                Section {
                    Toggle("Focus view", isOn: Binding(get: { model.focusView }, set: { model.setFocusView($0) }))
                    Picker("Test pace", selection: Binding(get: { model.playbackMode }, set: { model.choosePlaybackMode($0) })) {
                        ForEach(PlaybackMode.allCases, id: \.self) { mode in
                            Text(mode == .automatic ? "Plays by itself" : "Step by step").tag(mode)
                        }
                    }
                    Toggle("Read aloud", isOn: Binding(get: { model.readAloud }, set: { model.setReadAloud($0) }))
                    Toggle("Reduce motion", isOn: Binding(get: { model.progress.forceReducedMotion },
                                                          set: { model.setForceReducedMotion($0) }))
                    Toggle("Haptics", isOn: Binding(get: { model.hapticsEnabled }, set: { model.setHapticsEnabled($0) }))
                    Button("Use Focus suggestions") { model.applyFocusSuggestions() }
                } header: {
                    Text("Focus & Accessibility")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Focus view: calmer screens that keep the goal and the next step in front, with no confetti.")
                        Text("Test pace: \"Step by step\" waits for you to tap Next at each moment of a test.")
                        Text("Read aloud: Nova's words are spoken with this device's voice. It stays quiet while VoiceOver is on, because VoiceOver already reads the screen.")
                        Text("Reduce motion: swaps moving animations for simple changes. It also turns on when Reduce Motion is on in the device's settings. Reading time never gets shorter.")
                        Text("Use Focus suggestions turns on Focus view, Step by step and Reduce motion. You can change each one afterwards.")
                        Text("None of these settings change the science results.")
                    }
                }
                Section {
                    Button("Reset All Progress", role: .destructive) {
                        nameFocused = false
                        confirmReset = true
                    }
                } header: {
                    Text("Progress")
                }
                if model.developerMode {
                    developerSection
                }
                Section("About") {
                    Text("Moonbase Academy by VANGUARD Systems, made for the NASA Space Apps Challenge 2026. Works offline. No accounts, ads or tracking.")
                        .contentShape(Rectangle())
                        .onTapGesture {
                            aboutTaps += 1
                            if aboutTaps >= 7 && !model.developerMode { model.enableDeveloperMode() }
                        }
                    Text("Code was written with help from an AI assistant. The team checked the science numbers against the NASA sources listed in the app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            // Tapping anywhere outside the field, or scrolling, puts the keyboard away.
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        nameFocused = false
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { nameFocused = false }
                }
            }
            .onAppear { name = model.progress.baseName }
            .onChange(of: nameFocused) { _, focused in
                if !focused { model.setBaseName(name) }
            }
            .onDisappear { model.setBaseName(name) }
            .alert("Reset All Progress?", isPresented: $confirmReset) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    model.resetProgress()
                    name = model.progress.baseName
                }
            } message: {
                Text("This removes all completed drills, stars and base upgrades on this device. This can't be undone.")
            }
        }
        .preferredColorScheme(.light)
    }

    /// Demo tools, shown after seven taps on "About". Game rules only: coins, levels and unlocks.
    @ViewBuilder private var developerSection: some View {
        Section {
            HStack {
                Text("Moon coins")
                Spacer()
                Text("\(model.baseState.coins)").font(.headline.monospacedDigit())
            }
            HStack(spacing: 10) {
                Button("+100") { model.devAddCoins(100) }
                Button("+1,000") { model.devAddCoins(1_000) }
                Button("+10,000") { model.devAddCoins(10_000) }
                Button("Zero", role: .destructive) { model.devAddCoins(-model.baseState.coins) }
            }
            .buttonStyle(.bordered)
            HStack(spacing: 10) {
                Text("All buildings")
                Spacer()
                ForEach(1...BuildingKind.maxLevel, id: \.self) { level in
                    Button("L\(level)") { model.devSetAllLevels(level) }
                }
            }
            .buttonStyle(.bordered)
            ForEach(model.baseState.buildings.filter { UpgradeArt.applies(to: $0.kind) }) { building in
                Stepper("\(building.kind.name): level \(building.level)",
                        value: Binding(get: { building.level }, set: { model.devSetLevel(building.id, $0) }),
                        in: 1...BuildingKind.maxLevel)
            }
            Button("Unlock every drill, lesson and blueprint") { model.devUnlockEverything() }
        } header: {
            Text("Developer mode (demo only)")
        } footer: {
            Text("Changes coins, building levels and unlocks so the whole game can be shown quickly. It never changes a science number or a test result. It turns off when the app is closed.")
        }
    }
}
