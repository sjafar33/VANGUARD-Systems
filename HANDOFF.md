# HANDOFF — Moonbase Academy

Read this with `Moonbase_Academy_Claude_Fable_Handoff.md` (the brief, one folder up) before changing anything.

## Project facts

- Path: `/Users/sjafari/Downloads/NASA/MoonbaseAcademy` (git repository, branch `main`)
- Project: `MoonbaseAcademy.xcodeproj`, shared scheme **MoonbaseAcademy** (app + unit tests + UI tests)
- Deployment target: iOS/iPadOS 17.0. Bundle ID `com.vanguardsystems.moonbaseacademy`. No DEVELOPMENT_TEAM set.
- Toolchain observed: Xcode 27.0, iOS 27.0 simulator SDK, Swift 5 language mode.
- DerivedData is project-relative (`DerivedData/`, git-ignored) so build and test logs can be read from the repository folder.
- Unit tests also write a plain summary to `TestResults/last-run.txt` (git-ignored).
- The UI test writes screenshots to `Screenshots/` (committed).

## Verified so far

| What | Evidence |
|---|---|
| App target compiles | Xcode test run 2026-11-14 08:56 EST, iPhone 17 simulator, iOS 27.0 |
| 56 of 56 unit tests pass | Same run: `Executed 56 tests, with 0 failures`. Covers every numeric reference case in brief section 9, invalid input, capacity and exact-zero boundaries, first-exhaustion stop, crew/time scaling, determinism, content validation, save/load/corruption/reset, and the four sensitivity checks |
| NASA references re-checked | 2026-11-14 automated fetch of all four official sources; see `SCIENCE_AND_DATA.md` |

Not yet verified (do not claim): app launch and visuals on iPhone/iPad simulators, the UI test, VoiceOver, Dynamic Type, rotation, background/resume, airplane mode, physical device.

## Files and responsibilities

- `Core/Science/SciencePackage.swift`: provenance types, `validateContent(package:)`, `ScienceInputs` with derived storm durations and radio delay.
- `Core/Simulation/ResourceEngine.swift`: `ResourceEngine`, `RoverEngine`, and the brief's entry points `validateConfiguration`, `simulateResourceMission`, `simulateRoverMission`. Foundation only; deterministic; first boundary crossing stops an attempt; deficits are reported unclamped.
- `Core/Missions/MissionModels.swift`, `MissionCatalog.swift`: all four drills and their labeled variants. Edit numbers only here, then update the matching tests.
- `Core/Missions/MissionContent.swift`: child-facing copy, hints, explanations built from results.
- `Core/Progress/Progress.swift`: `CampaignProgress` (completion awarded once, two attempts kept per drill), `SaveEnvelope`, `SaveStore` (atomic JSON in Application Support; damaged files are preserved as `save-unreadable.json`).
- `Rendering/IsoArt.swift`: the only projection (`Iso`), z-layers, `IsoPainter`, texture cache.
- `Rendering/ComponentArt.swift`: factories for habitat, solar array, battery (+charge bars), greenhouse (+plants, glow, shell), shelter (+glow), rover, pads, terrain, sky, Earth. Add new art here following the same canvas/origin pattern.
- `Rendering/WorldSnapshot.swift`, `WorldScene.swift`: immutable render snapshot; scene reconciles nodes by stable identity; touches only emit `PadID` intents; `WorldCoordinator` retains one scene per world.
- `Features/Mission/MissionSession.swift`: enum-driven stage machine, intents, playback with attempt tokens (stale completions ignored), world snapshot building.
- `Features/Mission/MissionView.swift`: responsive shell (iPad wide ≈62/38 split; phone portrait world on top), panels for every stage.
- `Features/Base/BaseView.swift`, `Features/Science/SourcesView.swift` (sources + settings), `App/` (root, `AppModel`, `LaunchOptions`).

## Deliberate departures from the brief

- Added a fourth evidence category, `physicalConstant`, for the SI speed of light so it is not labeled a NASA value.
- Mission 2 has no cargo; its choices are the per-block air, light and research settings.
- Storm drill battery visuals show two base batteries plus the charged battery; this is cosmetic.

## Known gaps

- Visual acceptance gate not yet passed (no screenshots inspected yet).
- No audio (cut by the brief's cut order).
- Base name editing is in Settings only.

## Next bounded tasks (in order)

1. Run the UI test on an iPhone simulator and an iPad simulator; inspect `Screenshots/`; fix layout or art problems found.
2. Manual checks from brief section 13 (Dynamic Type XXL, VoiceOver labels, reduced motion, rotation, background during playback).
3. Play Missions 2–4 end to end in the simulator and capture result screenshots.
4. Demo video and submission copy (`SUBMISSION.md`).

## Commands

- Build and test: open the project, choose an iPhone or iPad simulator, press ⌘U.
- Log reading without Xcode: the newest `DerivedData/MoonbaseAcademy/Logs/Test/*.xcresult/Data/data.*` files are zstd-compressed and contain the compiler and test output.
