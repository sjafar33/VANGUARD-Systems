# HANDOFF — Moonbase Academy

Read with `PHASES.md` and the V2 brief (`Moonbase_Academy_V2_Phased_Coding_Prompt.md`, owner upload). The original foundation brief is `../Moonbase_Academy_Claude_Fable_Handoff.md` (historical context only).

## Project facts (checked 2026-11-14, Phase 0)

- Repository: `/Users/sjafari/Downloads/NASA/MoonbaseAcademy`, git. V2 work branch: `v2` (created from `main` at `107b088`). Nothing pushed; no remote configured.
- No `AGENTS.md` or `CLAUDE.md` in the repository.
- Project `MoonbaseAcademy.xcodeproj`, shared scheme **MoonbaseAcademy** with three targets: app, `MoonbaseAcademyTests` (unit), `MoonbaseAcademyUITests` (UI).
- Version: `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1` (all configurations). Deployment target iOS/iPadOS 17.0. Bundle ID `com.vanguardsystems.moonbaseacademy`. No DEVELOPMENT_TEAM in the project file.
- Toolchain observed: Xcode 27.0, iOS 27.0 simulator SDK, Swift 5 language mode.
- Save schema: `SaveEnvelope.currentSchemaVersion = 1`, JSON in Application Support (`MoonbaseAcademy/save.json`). Fields added after the first release of the schema are optional (`bestStars`, `musicEnabled`, `musicStyle`) so older saves decode. UI tests use an isolated save (`MoonbaseAcademyUITest/save.json`, launch argument `-uiTesting`).
- DerivedData is project-relative (`DerivedData/`, git-ignored). Unit tests write `TestResults/last-run.txt` (git-ignored). The UI test writes PNGs to `Screenshots/` inside the repository (`.gitattributes` marks them `-diff`); treat them as evidence artifacts, not app resources.

## What exists today (main @ 107b088)

- Four drills with deterministic engines, bundled NASA provenance, labeled variants.
- Game presentation: full-screen SpriteKit Moon region with curved horizon, ambient life (rover patrol, twinkling and shooting stars, panel glints, beacon), single quest marker; SwiftUI HUD pills, Nova guide, build tray, plan popups, prediction bet, 3-2-1 countdown, floating numbers, phase banners, star result screen with confetti.
- Audio: synthesized sound effects and two original procedurally composed music tracks (Space ambient default, Lofi chill), with Music, Music style and Sound effects settings. This replaces the old "no audio" note.
- Settings: base name (saves on leaving the field; tap outside dismisses keyboard), Music, Music style, Sound effects, Reduce motion, Reset all progress (centered system alert), About.
- Haptics are used for taps, placement, stars and results; there is no separate haptics preference yet.

## V2 baseline (Phase 0 evidence)

### Build

| Evidence | Result |
|---|---|
| Xcode build log 2026-11-14 15:38 UTC, Debug, iPad Air 11-inch (M4) simulator, after the last commit (15:34 UTC) | Build succeeded |
| Xcode build logs 16:09 and 16:10 UTC, Debug, destination "SJ iPad" (owner's physical iPad) | Build succeeded |

These builds were started by the owner. No compiler errors in either log.

### Tests

- Last recorded unit run: `TestResults/last-run.txt`, 2026-11-14 14:47 UTC: 56 passed, 0 failure records. That run predates the two music tests now in the suite (current unit total is 58).
- The "57 tests, one failure" observation: in the 09:47–09:48 EST (14:47 UTC) run the 57th test was the UI test `MissionOneFlowTests.testMissionOneFromLaunchToRelaunch`, failing at `MissionOneFlowTests.swift:91` "The improved plan should succeed". Its screenshots showed the retry plan with 0 arrays and 0 batteries: the test helper swiped the screen when a button was briefly not hittable, and SpriteKit counted the swipe as a tap on the placed array's pad, removing it. Commit `8a12fd4` changed the helper to wait instead of swipe and made the world ignore drags. The result bundle for that run has since been cleared from DerivedData, so this explanation rests on the log excerpt read during that session plus the code change.
- **Not yet done in Phase 0:** a fresh full run (unit + UI) on iPhone and iPad after `8a12fd4`. Required before Phase 1 code lands.

### Findings

| # | Finding | Status | Evidence |
|---|---|---|---|
| F1 | Garden playback is 0.26 s per simulated day (0.1 s with reduced motion) | Addressed in Phase 1 (untested) | `MissionSession.playbackDurations()` |
| F2 | Reduced motion shortens reading time (1.7 s → 0.7 s per step; 0.26 → 0.1 s per day) | Addressed in Phase 1 (untested) | same function |
| F3 | Correctly predicting a failure shows "Good thinking!" but earns no prediction star | Confirmed in source | `finishAttempt`: `predicted: success && predictionWasRight == true`; `ResultOverlay` shows "Good thinking!" from `predictionWasRight` alone |
| F4 | Garden success says "The air maker kept the tank full the whole time" although the drill starts at 3.58 of 7.16 kg | Confirmed | `MissionContent.swift:204` |
| F5 | (Addressed in Phase 1, untested) Garden failure lead is numerically dense ("ran empty 160 h into the sprouting… needed 0.03 kW more… short 0.2 kWh") and uses block labels, not days | Confirmed | `ExplanationWriter.resource` energyShortage branch |
| F6 | Mission copy hard-codes standard values ("6-hour shadow", "17 kWh", "33 days", "4 crates") that variants change | Confirmed | `GameCopy.swift` intros, `MissionContent.swift` stories |
| F7 | "Same starting supplies both times" is always shown, even when cargo (for example a charged battery) differs | Confirmed | `MissionView.swift:825` |
| F8 | Session playback keeps advancing while the app is in the background (only audio and scene rendering pause); a result can appear while away. Attempt tokens and the stage guard should prevent double recording | Addressed in Phase 1: presentation pauses when the scene is not active and waits for Resume (untested) | `MissionSession.startPlayback`, `MoonbaseAcademyApp` scenePhase handler |
| F9 | Large text: six `minimumScaleFactor` uses and fixed-width tray/tile cards (118–124 pt) | Confirmed in source; not tested at accessibility sizes | `GameKit.swift`, `BaseView.swift`, `MissionView.swift` |
| F10 | Home and planning views leave large empty terrain on portrait iPad | Observed in owner screenshots; framing changed since (Moon region) — recheck in Phase 5 | screenshots |
| F11 | HANDOFF and SUBMISSION were stale (no audio, unverified visuals, placeholder links) | Fixed for HANDOFF in this phase; SUBMISSION deferred to Phase 7 | this file |

### Not verified in Phase 0

Fresh unit/UI runs; baseline screenshots on iPhone and iPad; interactive reproduction of F3 and F8; Missions 2–4 played end to end at runtime; VoiceOver, Dynamic Type, Switch Control.

## Proposed version for the release phase

`MARKETING_VERSION 2.0`, `CURRENT_PROJECT_VERSION 2` (one build-number bump per uploaded build if distribution is authorized). Signing untouched.

## Phase 1 plan (bounded)

Goal: a child can follow why the outcome happens, at their own pace. No simulation changes.

1. **Presentation model** in `Features/Mission/MissionSession.swift`: add `PlaybackMode` (`.automatic`, `.stepByStep`) and a checkpoint list derived from the authoritative trace (`[Checkpoint]` with `traceIndex`, kind, text). Extend `MissionStage.playback` handling with `isPaused`, `next()`, `pause()`, `resume()`, `replayExplanation()`; keep `attemptToken` guards so stale tasks cannot finish a later attempt. Trace indices and checkpoint indices stay separate.
2. **Garden checkpoints**: start, first battery trend, first warning (reserve under a threshold), growth milestones (half, ready), failure or final day. Values come from the trace; days are grouped only in presentation.
3. **Reading time independent of motion**: automatic dwell based on text length (minimum about 3 s); reduced motion changes animation only. Step-by-step waits for Next.
4. **Lifecycle**: on scenePhase not active, pause presentation; on return, stay on the same checkpoint with a Resume control.
5. **UI** in `Features/Mission/MissionView.swift`: Watch automatically / One step at a time choice before launch (remembered in progress as an optional field), Pause/Resume, Next, Replay controls; restrained highlight of the affected object via the existing snapshot (`WorldSnapshot`) and the matching HUD pill.
6. **Garden failure copy** in `Core/Missions/MissionContent.swift`: lead with the computed recurring deficit, e.g. "The base used 0.6 kWh more than it made each day. The battery covered the gap until day 7." Move hours/kW/step shortfall into the numbers disclosure.
7. **Accessibility**: post one VoiceOver announcement per checkpoint, never per tick.
8. **Tests**: checkpoint mapping (failure day matches the trace; no checkpoint invents values), simulation identical across presentation modes, skip/retry/leave never record twice. Manual readability checks on iPhone and iPad.

Risks: SwiftUI animation state tied to `stage`; playback task cancellation; UI test selectors may need updating for new controls.

## Phase 1 checkpoint (pacing and cause/effect)

Branch `v2`. Simulation engines, physics and source values are unchanged; this phase changes presentation only.

What changed:
- `Features/Mission/PlaybackScript.swift` (new, Foundation-level): `PlaybackMode` (Watch automatically / One step at a time), `PlaybackCheckpoint` (trace index, title, text, focus, warning) and `PlaybackScript`. Power and storm drills get one checkpoint per engine step. The garden drill gets grouped checkpoints from the trace: day 1 budget and trend, plan changes, battery first full, air tank first full, first low-battery or low-air warning, lettuce halfway and ready, and the final day or failure day. Rover gets one checkpoint.
- `MissionSession`: one playback task per attempt, guarded by `attemptToken`. Countdown, then for each checkpoint a quick run-up of the in-between days (motion only, skipped with reduced motion or Next), then the checkpoint. Automatic mode waits a reading time from the text length (at least 3.5 s), independent of reduced motion; step-by-step waits for Next. New intents: `nextCheckpoint`, `pausePlayback`, `resumePlayback`, `replayCheckpoint`, `setPlaybackMode`, `setAppActive`. Skip still finishes through the same `finishAttempt` guard.
- Lifecycle: when the scene is not active, presentation pauses and shows "Paused while you were away"; it resumes only when the player taps Resume.
- `MissionView`: `PlaybackPanel` (title, "Step n of m", Nova text, Pause/Resume, Replay, Next / See result, pace switch) and a watch-mode choice in the prediction overlay. The mode is saved as optional `CampaignProgress.playbackMode` (older saves still load; schema version unchanged).
- Highlight: `WorldSnapshot.highlight` draws a restrained pulsing ring (static with reduced motion) on the arrays, batteries, habitat, greenhouse, shelter or rover; the matching HUD pill gets a gold outline and the accessibility "selected" trait. Text always says the same thing, so colour is never the only cue.
- VoiceOver: one announcement per checkpoint (and on Replay), never per animation tick.
- Garden power failure lead: "The base used X kWh more than it made each day. The battery covered the gap until day N." Made/used per day, failure day and final shortfall move into the numbers list. Other missions' explanations are unchanged.
- Tests: `MoonbaseAcademyTests/PlaybackTests.swift` (checkpoint mapping, failure day, daily-gap lead, one checkpoint per step for step drills, identical simulation across modes, skip/retry/leave never record twice, background pause waits for the player, mode change reported for saving). UI test now watches attempt 1 automatically (wait raised to 60 s) and plays attempt 2 one step at a time.

Not verified yet: the project has not been compiled since these changes (Xcode was on another Space and could not be driven), and no unit, UI, device, VoiceOver or Dynamic Type run has happened. Reading times are estimates, not tested with children.

Known limits: F3, F4, F6, F7 are left for Phase 2 as planned. Rover mission is a single checkpoint.
