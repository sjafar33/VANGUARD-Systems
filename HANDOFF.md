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
| F3 | (Addressed in Phase 2, untested) Correctly predicting a failure shows "Good thinking!" but earns no prediction star | Confirmed in source | `finishAttempt`: `predicted: success && predictionWasRight == true`; `ResultOverlay` shows "Good thinking!" from `predictionWasRight` alone |
| F4 | (Addressed in Phase 2, untested) Garden success says "The air maker kept the tank full the whole time" although the drill starts at 3.58 of 7.16 kg | Confirmed | `MissionContent.swift:204` |
| F5 | (Addressed in Phase 1, untested) Garden failure lead is numerically dense ("ran empty 160 h into the sprouting… needed 0.03 kW more… short 0.2 kWh") and uses block labels, not days | Confirmed | `ExplanationWriter.resource` energyShortage branch |
| F6 | (Addressed in Phase 2, untested) Mission copy hard-codes standard values ("6-hour shadow", "17 kWh", "33 days", "4 crates") that variants change | Confirmed | `GameCopy.swift` intros, `MissionContent.swift` stories |
| F7 | (Addressed in Phase 2, untested) "Same starting supplies both times" is always shown, even when cargo (for example a charged battery) differs | Confirmed | `MissionView.swift:825` |
| F8 | Session playback keeps advancing while the app is in the background (only audio and scene rendering pause); a result can appear while away. Attempt tokens and the stage guard should prevent double recording | Addressed in Phase 1: presentation pauses when the scene is not active and waits for Resume (untested) | `MissionSession.startPlayback`, `MoonbaseAcademyApp` scenePhase handler |
| F9 | (Addressed in Phase 3, untested) Large text: six `minimumScaleFactor` uses and fixed-width tray/tile cards (118–124 pt) | Confirmed in source; not tested at accessibility sizes | `GameKit.swift`, `BaseView.swift`, `MissionView.swift` |
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

## Phase 2 checkpoint (rewards and scientific narration)

### Reward policy
- Each drill has three separate achievements (`Achievement`): **completed** (the drill succeeded), **predicted** (a Yes or No prediction matched the outcome, whether the drill passed or failed), and **bonus** (the drill's existing bonus; it still needs a successful run).
- "Not sure" never earns the prediction star and is never turned into a correct guess. Its result line says: "You weren't sure, and that's okay. Now you've seen what happens, so next time you can make a guess."
- Achievements accumulate per drill across attempts (standard and harder version share one set) and are never removed. A star counts once, so replays cannot farm stars, and a later failed replay keeps earlier stars and completion.
- Only completion unlocks the next drill (`isUnlocked` still reads `completedMissions`). `recordAchievements` drops `completed` if the drill was not actually completed.

### Save compatibility
- New optional field `CampaignProgress.achievements: [String: [Achievement]]?`. Schema version stays 1; older saves decode unchanged.
- For a drill with no stored achievements, `legacyAchievements` rebuilds them from the older fields: `completed` if the drill is in `completedMissions`, `bonus` if its badge is in `badges` (and the old count allows it), and `predicted` for any star left over. Old saves only gave stars for finished drills, so this is exact in normal cases; when it is ambiguous (old count 2 with a badge), it picks the bonus because the badge is verifiable.
- `stars(_:)` never reports less than the old `bestStars` count, and `bestStars` is still updated, so star totals never drop.
- Saves from before stars existed now show credit for completed drills (and earned badges) instead of 0.

### Narration corrections (examples)
- Garden success: "The air maker kept the tank full the whole time" is replaced by what the trace shows, e.g. "The air maker made more oxygen than the crew breathed, so the air tank filled from 3.58 kg to 7.16 kg." If the tank dipped: "The air tank went down to X at its lowest (about N h of air), but it never ran out."
- Garden success: the lettuce-ready day comes from the trace.
- Lights Out success: the oxygen-tank sentence only appears when the tank actually went down, with its before and after values.
- Lights Out failure: "No battery, no power in the dark" only when the shadow caused it (with no arrays the power fails in sunlight).
- Storm failure: "Building the shelter took X out of the battery first. The air maker and research together needed A kW of power, but only B kW was coming in, so the battery drained until it was empty." Names only what was running; handles failure during shelter building.
- Storm success: research energy and oxygen change only when they happened, plus "The game does not calculate a radiation dose, and the storm's timing near Earth does not tell us the dose on the Moon."
- No harvest: ISS lettuce timing labelled as a training rule that does not prove the same growth on the Moon.
- Curtailed energy says "sunshine energy" only in drills with solar arrays. Rover: the "no camera" sentence only when no camera was carried. Crew count is read from the drill.
- All story, goal, question, hint and briefing numbers come from the drill definition or the science inputs (`MissionCopy.of(_:science:)`, `GameCopy.of(_:science:)`, `Words`), so harder versions show 9 hours, 16 kWh, 3 crates and the slower rover's values.
- "Same starting supplies both times" replaced with "Both tries started from the same base. Only your plan changed." (or "Both tries used the same plan.").
- Power vs energy: planning meters say "Power in / Power used" (kW) or "Energy made / Energy used" (kWh per day); the numbers section and a VoiceOver hint explain: "kW is power: how fast energy is being used right now. kWh is energy: how much is used over time. Using 1 kW for 1 hour uses 1 kWh."
- Sources screen limits now include the near-Earth timing vs lunar dose point, the ISS lettuce limit, and that game numbers are assumptions; assumptions list notes harder-version values.

### Tests added
`MoonbaseAcademyTests/RewardAndNarrationTests.swift`: prediction star on a failure without unlocking, completed never kept without success, achievements across attempts and failed replay, StarResult mapping, legacy rebuild, pre-star saves, an older save file loading and re-saving, session tests for a correct "No" on a failed drill and for "Not sure", and narration tests (garden air story both ways, Lights Out oxygen and no-array copy, storm shortage and success, variant copy, copy following science inputs).

Not verified: not compiled or run by me (Xcode cannot be driven while the desktop is a full-screen Space). No device, VoiceOver or Dynamic Type checks.

## Phase 3 checkpoint (Focus & Accessibility)

### Settings (Settings → "Focus & Accessibility"; reachable from the base and, new, from inside a drill)
Each is its own switch, saved as an optional field (older saves load; missing = off, haptics = on):
- **Focus view**: shows the current goal and a bold "Next:" action under the step bar; no confetti; never hides resources, warnings or answers.
- **Test pace**: Plays by itself / Step by step (the Phase 1 mode; also switchable during a test and in the prediction dialog). Works without Focus view.
- **Read aloud**: on-device `AVSpeechSynthesizer`. Speaks Nova's line, the prediction question, each playback checkpoint and the result lead; every spoken word is on screen. A speaker button repeats, and turns into Stop while speaking. Speech is replaced when the step changes and stopped on leaving the drill or the app. Silent while VoiceOver runs (no double speech; VoiceOver already gets checkpoint announcements). Uses an installed voice for the device language or the system default; never downloads or blocks. Units are read as words ("kilowatt hours").
- **Reduce motion**: unchanged switch; now one policy (`appReduceMotion` = system OR app) used by every SwiftUI view, SpriteKit, countdown, button press springs, shake, confetti, transitions. Changing it (or the system setting) updates an open drill. Reading time never shortens.
- **Haptics**: new independent switch (`Haptics.enabled`). Every haptic event also has a visible change and an accessible description.
- **Use Focus suggestions**: turns on Focus view, Step by step and Reduce motion as a starting point; each stays adjustable.
- Music and Sound effects stay independent (unchanged).

### Orientation
`MissionStepsBar`: Build → Predict → Test → Understand with the current step marked by fill, a numbered/check icon and colour, plus one concrete next action. At large text sizes it becomes "Step n of 4: Predict". VoiceOver reads it as one element.

### Accessible controls and dialogs
- Prediction, plan, result and mission-briefing dialogs are marked modal; the drill or base underneath is hidden from VoiceOver while one is open; VoiceOver focus moves to the dialog title; the two-finger escape gesture closes the plan and briefing dialogs and goes back from the prediction dialog. Focus returns to Launch test after the plan or prediction dialog closes or after Try again.
- Option buttons (air maker, lights, research) show a check/empty circle as well as colour and expose the selected trait. Launch test has a hint. Locked drills have a hint saying how to unlock.

### Readable layouts
- Removed `minimumScaleFactor` from game buttons, ribbons, resource pills, build/plan/rover/mission cards; text wraps (up to 3 lines) instead of shrinking. One remains, on the watch-mode toggle labels (0.85), which also wrap.
- Card widths/heights use `@ScaledMetric`; tray and tile rows already fall back to horizontal scrolling. Resource pills wrap to two rows. Option buttons stack vertically when they don't fit. The bottom control area, prediction, plan and briefing dialogs scroll when they don't fit.
- Removed the remaining hard-coded drill numbers found in the plan cards and plan dialog (16 h light, 11-day blocks, 1.5 kWh), now read from the drill.

### Contrast (measured with the WCAG formula; script logic in this phase's notes)
| Pair | Ratio |
|---|---|
| Ink text on white / darkest card stop | 15.8 / 13.0 |
| Secondary ink on white / card / panel | 7.5 / 6.1 / 7.0 |
| Teal ink (darkened from 1F7E8C to 186A76) on white / card; white on teal | 6.3 / 5.1; 6.3 (was 3.9 on card) |
| Amber ink on white / card | 5.9 / 4.9 |
| Warning ink, plant ink on white | 5.4, 5.1 |
| White / yellow text on HUD over the Moon | 14.6 / 11.4 |
| Ink on the active step chip | 11.4 |
| **White on game buttons, no outline** (gold, energy, go, coral bottoms) | **2.0, 2.6, 3.1, 3.3 — fail on their own** |
| Navy outline vs lightest button face | 13.2 |
Decision: white button text keeps a navy outline (now on four sides). With the system Increase Contrast setting on, light-faced buttons and round icons switch to dark ink text (4.8–11.4:1). This is a measured mitigation, not a full pass of white-on-gold by itself.

### Interruption recovery
- In-memory: backgrounding pauses playback (Phase 1), stops narration, keeps plan, variant and stage.
- Process termination: on going inactive/background the in-progress plan (`MissionDraft`: mission, harder-version flag, cargo/plans or rover choice) is saved. Never a running test or a result. On relaunch the base shows "You were working on Lights Out (harder version)." with Continue / Not now. Continue opens the drill at planning with that plan and a short reminder; invalid saved plans are ignored. Leaving a drill on purpose clears the draft. Results are recorded only by finished tests, so nothing replays or double-awards.

### Tests added
`MoonbaseAcademyTests/FocusAccessibilityTests.swift`: settings independent and persisted, Focus suggestions as a starting point, identical science across motion/pace combinations, motion change reaching an open drill, interrupted plan reopens at planning with no recorded attempt, harder version restored as harder, invalid saved plan ignored, narration unit words.

### Not verified (must be checked by hand)
Not compiled or run by me. No VoiceOver pass of a full drill, no largest accessibility text size check on iPhone or iPad, no Switch Control, Voice Control, Full Keyboard Access, Increase Contrast, Bold Text, Smart Invert or speech-voice availability checks, and no check of Read aloud with the ringer switch silent (speech follows the app audio session). Focus return timing (0.45 s) and dialog focus behaviour need a real VoiceOver check.

## Base-builder redesign (branch `base-builder`, started 2026-11-14)

Owner request: a Clash-of-Clans-style base on a board where you place, build, upgrade and decorate; coins come from learning (lessons) and the real trade-off drills; customization (colours, ground themes, robots); kid-friendly and not too hard. Owner decisions: upgrades unlock things and look better but never change a drill's science numbers; coins from lessons and drills, with no timers, streaks or waiting; build the core loop first and stop for review.

### Core loop built
- **Board** (`Rendering/BoardScene.swift`, `BoardArt.swift`): 12 by 12 tile platform on the Moon. Buildings snap to tiles with footprints (habitat 3x3, greenhouse and shelter 2x2, array, battery and dish 1x1). Tap a building to select it; tap or drag to move the placement preview, which shows green/✓ or red/✕. Level shown by plate rim colour, pips and size, and in words in the panel.
- **Rules** (`Core/Base/BaseBuilder.swift`, game rules only):
  - Start: habitat plus 120 coins, enough for a solar array and a battery.
  - Build costs: array or battery 40, greenhouse 120, shelter 150, dish 150.
  - Upgrades go to level 3:
    - Habitat (150 then 300) raises the array and battery limit to 3 and then 4.
    - Any drill building at level 2 opens that drill's harder version; level 3 adds a gold look.
  - Drills need their building: Lights Out needs an array and a battery, The Living Base needs the greenhouse, Storm Drill the shelter, and Signal Lag the dish. They still unlock in order.
  - Blueprints: the greenhouse is unlocked by the lesson "Plants and Air", the shelter by finishing The Living Base, and the dish by finishing Storm Drill.
- **Coins:**
  - Lessons: the first finish pays 10 per question right on the first try, plus 30. Replays pay 3 per first-try answer.
  - Drills: the first completion pays 60, each new star 20, and a later successful run 10. A failed run pays 0 and costs nothing.
  - Coins are shown on the base, in lessons and on the drill result.
- **Lesson** (`Core/Learn/Lessons.swift`, `Features/Learn/LessonView.swift`): "Plants and Air", 5 teach cards and 5 questions.
  - Facts carry their source: oxygen 0.895 kg per person per day (N1); Veggie lettuce in about 33 days at 70 W (N2).
  - The 16-hour light rule is tagged "Game rule". Numbers are read from the science package.
  - A wrong answer means "try again" (no lives, no timer). VoiceOver announcements and Read aloud are supported.
- **Style shop:** 5 habitat colours, 4 ground themes, 4 robot buddies (Nova's colours change everywhere). Looks only.
- **Home screen:** coins and stars pills; Build, Learn, Drills and Style buttons; contextual Nova guidance; PLAY when the next drill is ready; a building panel (upgrade, move, play); a placement bar with nudge arrows, so no dragging is needed.
- **Old saves:** an optional `CampaignProgress.base`. Saves without it get a starting base seeded from completed drills (arrays, batteries, greenhouse and so on), plus 20 coins per star already earned.
- **Tests:** `BaseBuilderTests` (board rules, limits, upgrades, unlocks, lesson and drill coins, cosmetics, migration, save round trip, lesson facts following the science inputs). The UI test now builds an array and a battery before Lights Out.

### Not done yet / next
- Lessons for power and batteries, storms and shielding, and communication delay (and their blueprint gates).
- Pinch to zoom and pan on the board.
- More art per level.
- A real-data "today's space weather" link (archived DONKI/CCMC data only; no live claims).
- Not compiled or run by me; no device or accessibility checks yet.
