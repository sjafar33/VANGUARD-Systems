# Moonbase Academy V2 — phase tracker

Source brief: `Moonbase_Academy_V2_Phased_Coding_Prompt.md` (owner, 2026-11-14). Work happens on branch `v2`; one commit per completed phase; nothing is pushed or merged without the owner.

| Phase | Status | Notes |
|---|---|---|
| 0 Baseline | complete (see HANDOFF "V2 baseline") | No product changes |
| 1 Pacing and cause/effect | complete (owner reported tests and simulators good on 2026-11-14; my local results file was not refreshed, so I did not see the logs) | See HANDOFF "Phase 1 checkpoint" |
| 2 Rewards and scientific narration | complete (owner reported it works, 2026-11-14) | See HANDOFF "Phase 2 checkpoint"; watch-mode toggle fix 78f67ce |
| 3 Focus & Accessibility | code complete; awaiting owner test run and manual assistive-technology checks | See HANDOFF "Phase 3 checkpoint" |
| 4 Learning evidence and provenance | pending | |
| 5 World presentation | pending | |
| 6 Release verification | pending | |
| 7 Submission materials | pending | |

---

# Base-builder brief — phase tracker

Source brief: `Moonbase_Academy_Base_Builder_Feedback_Prompt.md` (owner, 2026-11-14). Branch `base-builder`. Supersedes the V2 table above for new work; V2 Phases 1–3 stay as built.

| Phase | Status | Notes |
|---|---|---|
| 0 Audit and bounded design | complete 2026-11-14 (audit + design only; awaiting owner review) | See "Phase 0 checkpoint" below |
| 1 Restoration objective (landing station) | code complete 2026-11-14; NOT yet compiled or run (owner build needed) | See "Phases 1-2 checkpoint" |
| 2 Test My Base (shadow/power) | code complete 2026-11-14; NOT yet compiled or run (owner build needed) | See "Phases 1-2 checkpoint" |
| 3 Learning presets | not started | |
| 4 Presentation and personalization | not started | |
| 5 Five-theme campaign | not started | |
| 6 Balance, verify, handoff | not started | |

## Phase 0 checkpoint (2026-11-14, about 15:20 Toronto)

**Verification facts (read from DerivedData, not assumed):**
- App target: `Build succeeded` at 19:32:01 UTC, destination SJ iPad, Debug-iphoneos, one minute after commit `b635419`. So base-builder rounds 1–2 DO compile (NEW_CHAT_HANDOFF.md section 6 says "never compiled"; that is out of date).
- Test targets: NOT compiled or run since before V2. `TestResults/last-run.txt` is the 56/56 run from 14:47 UTC (pre-V2). `Logs/Test/` is empty. The source now has 114 test methods; Xcode's test navigator still lists 57. Compile errors in `BaseBuilderTests`, `FocusAccessibilityTests`, `RewardAndNarrationTests`, `PlaybackTests` are possible.
- Tooling this session: device shell is Linux (no xcodebuild/swift). Xcode is reachable by computer use at "click" tier only: Product menu commands are refused, and plain clicks on the off-Space Xcode window did not start a test run. Owner must press Cmd-U.
- Working tree clean at `68502af` before this note.

**What exists vs. what the brief needs:**
- Exists: board, placement/move/upgrade, coins, 12-goal guide with Show me, EarnAdvisor, style preview (non-spending), one lesson, four reference drills + variants, accessibility/pacing work, optional-field save compatibility.
- Missing: any repairable/ruin object; any link from the real base to a simulation (drills take `MissionCatalog` definitions only; `BaseDecor` is cosmetic); learning presets; non-recolor customization; contextual lessons.

**Design for the first slice (Phases 1–2), pending owner approval:**
- Landing station: new `BuildingKind.landingStation`, 2x2, seeded once as a ruin (new optional `PlacedBuilding.damaged: Bool?`), preferred tile (4,4), else the free 2x2 nearest that corner. Never overlaps; cannot be built from the shop. States: damaged -> restored. Repair = one centralized `BaseState.repair(id)` transaction, 60 coins (game rule), immediate, idempotent.
- Purpose when restored: it is the "test pad" that opens **Test My Base: Shadow Test**. Game-fiction, labelled as a game rule. No free oxygen/energy/comms.
- Test My Base adapter (`Core/Base/BaseExperiment.swift`, new): `BaseState` snapshot -> counts of functional (non-damaged) solar arrays and batteries -> a separate `MissionDefinition` (id `lightsOut.myBase`, same phases/assumptions as the six-hour reference drill, cargo fixed to the base's counts) -> the unchanged `ResourceEngine`. Player chooses only the air-maker and observation settings (the trade-off). Levels and cosmetics have no effect (stated in the UI). Result stored in a new optional `BaseState.baseTests` (inputs + compact outcome, last two) for before/after comparison; it never touches drill completion, stars or `attempts`.
- Hand-calculated expectations to be pinned by tests in Phase 2 (not yet run): 1 array + 1 battery, full air both phases -> energy shortage in shadow; same base with half air in shadow -> passes but spends oxygen reserve; adding a 2nd battery alone -> still fails (nothing extra to store); adding a 2nd array -> passes at full air.
- Guide: insert `restoreStation` and `testMyBase` after `playLightsOut`. Saves: all new fields optional; station seeded on load when absent; tests decode a pre-change save fixture.
- Coins (game rules): repair 60; first passed base test +40; later passes 0 (no farming).

**NASA coverage today:** power (Lights Out) playable; life support (Lights Out oxygen reserve, Living Base) playable; food (Living Base, N2) playable; radiation shielding (Storm Drill, N3, no dose model) playable; comms delay (Signal Lag, N4/S1) playable. All as reference drills only; none yet uses the child's real base. After Phases 1–2: power + life support also via Test My Base.

## Phases 1-2 checkpoint (2026-11-14, about 16:30 Toronto) — built together at the owner's request

**Status: written, bracket-checked, committed. Not compiled, not run, not seen on a device by the author.**

**Player-visible changes**
- A ruined **landing station** (2x2, wrench badge) stands on the base board. Tap it: a panel says what it is, what repairing unlocks, and the price. **Repair** (60 coins, game rule) is instant, charged once, and the ruin pops back to life with dust and sparkles (static with reduced motion).
- The repaired station is the **test pad**. "Test my base" (station panel, Drills sheet, or the goal's Show me) opens **Test My Base**: the Lights Out shadow with the child's own working solar arrays and batteries. No lander, no crates; the tray shows "Your base" instead of build cards. The child chooses the air-maker and observation settings, predicts, watches, and gets a result that says what to change back at the base (another array vs another battery is decided from the trace).
- The result card shows the base's equipment, the last saved test, what changed on the base since then, and the game rules that turn buildings into numbers.
- Guide: two new goals after Lights Out: "Fix the old landing station", "Test your real base" (14 goals total). Trying the test completes the goal even if it fails.

**Science inputs/assumptions (all labelled game rules in the UI and in SCIENCE_AND_DATA.md)**
- Each working solar array = the Lights Out array (1 kW in sunlight); each working battery = the Lights Out battery (4 kWh, starts empty). Same phases, demands, crew, oxygen tank and success rule as the six-hour reference drill; same `ResourceEngine`.
- Building level, colour, position and robot have no effect. A damaged building counts for nothing. At most 4 of each kind.
- Repair cost 60 coins; first passed base test +40 coins, later passes 0. Coins never enter the simulation.
- No NASA value changed. Reference drills, their variants and fixtures are untouched (`testTheReferenceDrillIsLeftAlone`).

**Save/economy compatibility**
- New optional fields only: `PlacedBuilding.damaged`, `BaseState.baseTests`, `BaseState.baseTestPassed`. New enum case `BuildingKind.landingStation`.
- Existing saves get the ruin on load at tile (4,4) or the nearest free 2x2; nothing else moves; coins unchanged (`testASaveFromBeforeTheStationKeepsEverythingAndGainsTheRuin`).
- Base tests are stored apart from drills: no completion, stars, attempts or drafts.

**Files**
- New: `Core/Base/BaseExperiment.swift`, `MoonbaseAcademyTests/BaseExperimentTests.swift` (17 tests).
- Changed: `BaseBuilder.swift`, `Guide.swift`, `AppModel.swift`, `MissionSession.swift`, `MissionView.swift`, `GameCopy.swift`, `MissionContent.swift`, `BaseView.swift`, `BaseBuilderViews.swift`, `BoardArt.swift`, `BoardScene.swift`, `BaseBuilderTests.swift`.

**To continue**
1. Owner: Cmd-U on the iPad Air 11-inch (M4) simulator. Compile errors: `gunzip -c DerivedData/MoonbaseAcademy/Logs/Build/<newest>.xcactivitylog | tr '\r' '\n' | grep -a "error:"`.
2. Play-test from Settings -> Reset All Progress: array -> battery -> Lights Out -> fix station -> test base (fails at full air with 1+1) -> turn air to Half in the shadow or build a second array -> pass.
3. Not done from the brief: Phases 3-6 (learning presets, non-recolour customization, base tests for food/storm/comms, balance and submission docs).

## Play-test round 1 (2026-11-14, about 16:50 Toronto) — owner feedback from the iPad

Verified by build log: commits `12dd3c9` and `38e91c6` compile (app target, simulator and SJ iPad). Unit and UI tests still not run.

Fixed or changed in this round (NOT yet compiled):
- **Black band under the drill world** while the prediction or result dialog was open: the world was being re-framed against an empty control area. The framing is now kept while a dialog is up, and the ground continues below the drawn terrain.
- **"Goal complete" toast stayed on screen** when the goal was finished inside a drill or base test. It now always fades after 2.8 s.
- **Plan controls without a popup:** in Lights Out, Storm Drill and Test My Base the air-maker (Off / Half / Full) and science switches sit on the plan card, with a live line for "drains the battery / spare power" and "air maker keeps up / crew breathes from the tank". The popup remains behind the info button. The garden drill keeps its popup.
- **Prediction dialog:** now "What will happen?" with two big outcome buttons in the drill's own words (for example "Lights stay on" / "Lights go out"); "Not sure? Just watch"; the watch-mode choice moved below. VoiceOver labels stay Yes / No / Not sure. Test My Base no longer promises a star.
- **Lessons:** three question levels (Explorer: two choices; Builder: three choices; Mission Engineer: sums and reasons), chosen in Learn and saved (`CampaignProgress.learnLevel`, optional). Each fact has a pool of six questions (two per level); one is picked per play and the answer order is shuffled. 54 questions across the two lessons. Facts, sources and coins are the same at every level.

## Play-test round 2 (2026-11-14, about 20:50 Toronto) — owner feedback

Verified by the owner's screenshots: round 1 (`f12c3d8`) builds and runs on the iPad. Unit and UI tests still not run.

Added in this round (NOT yet compiled; all art drawn without being seen):
- **Upgrades change the building's shape** (`Rendering/UpgradeArt.swift`). Level 2: a cyan-lit tech deck plus new equipment (second solar panel deck, extra battery cell, relay dish, water tank and grow lights, shelter armour, habitat light pylons and a module). Level 3: gold deck, glowing core, hologram ring, and a top piece per building (third panel deck with a sun core, signal spire with rings, bio-tower, shield bubble, habitat spire and second module). Looks only; no drill or base-test number changes.
- **Upgrade moment:** light column, shock ring, two sparkle bursts, a rising "LEVEL N!" tag, the new building popping in, and a new rising-run sound (`SoundFX.Kind.upgrade`, also used for the station repair).
- **Test My Base briefing:** on the "shadow is coming" line the base goes dark with the habitat lights on, then the Sun returns on the next line.
- **Playback speed:** 1x / 2x / 5x buttons in the playback panel. Speeds up reading waits, the fast-forward between checkpoints and the scene's animations; results are unchanged.

## Round 3 (2026-11-14, about 21:30 Toronto) — toward the judging criteria

Verified from build logs: the app target built at 20:56 Toronto including `UpgradeArt.swift` (full redesign commit `496ba10`). Tests still not run. Pushing is not possible from Claude's shell (uploads to GitHub are blocked there): the owner pushes from Terminal.

Added (NOT yet compiled):
- **Upgrades count in Test My Base:** level 2 arrays/batteries are 1.5x, level 3 are 2x (game rule, stated in the UI). `BaseTestInputs` gained optional `arrayLevels`/`batteryLevels`.
- **Eight real archived storms:** `science_package.json` now holds eight CCMC SEP Scoreboard events; Storm Drill replays pick one at random and show its date. First play unchanged. Sources screen lists all of them with their own durations.
- Tests: upgrade rule, every storm usable and survivable, short vs long storm needing different plans.
- Still open from the plan: a Storm Test on the player's own base; project page text; demo.
