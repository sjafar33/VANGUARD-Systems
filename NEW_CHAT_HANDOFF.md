# Moonbase Academy — Handoff for a New Chat

_Written 2026-11-14, about 21:05 Toronto time (America/Toronto). Attach this file at the start of a new chat. It replaces the older `NEW_CHAT_HANDOFF.md` and the previous conversation._

---

## 0. Read this first

- **Goal:** win the NASA Space Apps Challenge 2026, challenge "Junior Astronaut Mission Trainer". Team **VANGUARD Systems**. Owner: Sadegh (sadeghj388@gmail.com, attribution only). Hackathon is Nov 14–15, 2026; `SUBMISSION.md` records the deadline as **Nov 15, 11:59 PM EST — unconfirmed, the owner must check the official site**.
- **App:** Moonbase Academy, native iPhone + iPad game (SwiftUI + SpriteKit, iOS 17+, Xcode 27).
- **Where we are:** branch `base-builder`, HEAD `b2a94c8`. The app builds and runs on the owner's iPad up to `496ba10` (owner screenshots + build log at 20:56). **`b2a94c8` has not been built. No unit or UI test has run since before the V2 work.**
- **Immediate next actions:**
  1. Owner: `git push -u origin base-builder` from Terminal (Claude cannot push), ⌘R to check `b2a94c8`, ⌘U to run tests, screenshots of level 2/3 buildings.
  2. Claude: fix whatever the build/test log shows, then build the **Storm Test on the player's own base** (section 7, item 3).
  3. Then presentation: project page text, 30-second demo, dataset explanation.

## 1. The challenge (the owner's attached brief)

- Build an interactive game/app where kids **7–12 manage a lunar or Martian outpost**, making real decisions about **life support, radiation shielding, power budgeting, food production, communication delay**, and seeing consequences over a simulated mission.
- **No choice is free.** Example trade-offs from the brief: oxygen reserves for extra research; shielding against a radiation event at the cost of tonight's power.
- Ground it in **real NASA open data** (the brief names DONKI, OSDR, Artemis/Mars data), attributed in the tool. A curated embedded dataset is fine; **never present static data as live**.
- Pitfalls named in the brief: a "safe" choice with no cost; **visual polish substituting for mechanical accuracy**; too many simultaneous systems (2–3 core resources is better).
- Stand-out factors: linking a shielding decision to real space weather; **replayability** and learning from failure without punishment; a short explanation of which NASA datasets were used and why.
- Low barrier to entry matters (browser is easier for judges; ours is a native app, so the **demo video is the product** to judges).

### Judging (from web search; the official 2026 guides could not be opened)
- Five criteria: **Impact, Creativity, Validity, Relevance, Presentation**. NASA's guide says to give Presentation equal attention.
- Relevant global awards: Best Use of Science, Best Use of Data.
- Demo: **video up to 30 seconds OR up to 7 slides**; going over makes a project ineligible for Global Judging. Public links, English (or English subtitles). These limits come from the 2025 guide — **owner must confirm the 2026 rules**.
- The challenge page and its Resources tab block automated fetching (robots). Do not claim to have read them.

## 2. Where things are

- **Repo on the owner's Mac:** `/Users/sjafari/Downloads/NASA/MoonbaseAcademy` (in Claude's device shell: `$HOME/mnt/NASA/MoonbaseAcademy`).
- **GitHub:** `https://github.com/sadeghj388-star/MoonBase-Academy.git`, added as `origin`. **Nothing pushed yet.**
- **Branches:** `main` @ `107b088` (V1), `v2` @ `40317c9`, **`base-builder` @ `b2a94c8` (current)**.
- **Xcode project:** `MoonbaseAcademy.xcodeproj`, file-system-synchronized groups (new `.swift` files are picked up automatically), shared scheme, targets `MoonbaseAcademy`, `MoonbaseAcademyTests`, `MoonbaseAcademyUITests`.
- **Build logs:** `DerivedData/MoonbaseAcademy/Logs/Build/*.xcactivitylog` (gzip). To read:
  `gunzip -c <log> | tr '\r' '\n' | grep -a -o -E "Build succeeded|Build failed|[A-Za-z]+\.swift:[0-9]+:[0-9]+: error: [^\"]{0,240}"`
- **Test results:** `TestResults/last-run.txt` (written by `TestSupport`), `DerivedData/.../Logs/Test/` (currently empty).
- **Docs in the repo:** `PHASES.md` (running checkpoints for every round — the most detailed record), `SCIENCE_AND_DATA.md`, `SUBMISSION.md` (draft), `README.md`, `AI_USE.md`, `HANDOFF.md` (older log), `NEW_CHAT_HANDOFF.md` (older; superseded by this file).

## 3. How we work (constraints that shaped everything)

- **Claude cannot build, run or push.**
  - The device shell is a Linux VM: no `xcodebuild`, no Swift.
  - Xcode via computer use is "click" tier only: menu commands and keys are refused; plain clicks on the off-Space Xcode window did not start a run.
  - `git push` is blocked from the shell ("only clone/fetch"). Commits work (delete permission was granted for the NASA folder this session; a new session must request it again with `device_request_delete_permission`, or git leaves `.lock` files).
  - Outbound network from the shell is blocked for NASA sites; `WebFetch` works for some (ccmc.gsfc.nasa.gov) and is refused for others (spaceappschallenge.org, kauai.ccmc DONKI web service).
- **So:** Claude writes code carefully, runs a bracket-balance script, commits, and the owner presses ⌘R / ⌘U. Claude then reads the build log itself (no screenshots needed for errors). Screenshots are needed for anything visual.
- **Every piece of art since `12dd3c9` was drawn without being seen.** Treat art as unverified until the owner sends a screenshot.
- **So far every commit that was built compiled first time**, but that is luck plus care, not proof. Never say "tested" or "verified" for anything that was not.
- **Patch method that worked:** a small Python helper doing exact-string replacement that fails unless the old text matches exactly once, then a brace/paren balance check on changed Swift files. Avoid retyping files from tool output.
- **Git:** commit in sensible chunks on `base-builder`; never push or merge without the owner (and pushing is impossible from Claude anyway). End commit messages with the attribution lines the session provides (`Co-Authored-By: Claude …` and `Claude-Session: …`).
- **Owner's style:** direct, fast, wants a "professional Clash of Clans feel", sends iPad screenshots with red circles. Prefers concise summaries plus a clear "what I need from you". He has pushed back when plans were vague: be specific and act as a senior partner.

## 4. Non-negotiable rules

- **Science integrity:** drill physics and NASA values never change to look better or pass a test. NASA references, derived values, constants and invented game rules stay distinct; game rules are labelled "Game rule". Archived data is labelled archived, never live. No radiation dose is calculated and the app says so.
- **Reference drills stay stable.** New scenarios (Test My Base, storm replays) are separate, labelled definitions that reuse the same engines.
- **No** accounts, ads, analytics, tracking, backend, remote AI, timers, streak loss, loot boxes.
- **Saves:** new persisted fields are optional; old saves must load. Tests use isolated saves.
- Do not describe accessibility options as treatment for anything.

## 5. Architecture

```
MoonbaseAcademy/
  App/            AppModel.swift (central @Observable: progress, routing, board, coins, guide, base test, dev mode)
  Core/
    Science/      SciencePackage.swift + Resources/Science/science_package.json (sources N1–N4, S1; 8 storm events)
    Simulation/   ResourceEngine.swift (deterministic), RoverEngine
    Missions/     MissionModels, MissionCatalog (4 drills + variants), MissionContent (copy, ExplanationWriter), GameCopy
    Progress/     Progress.swift (CampaignProgress, SaveStore schema 1)
    Base/         BaseBuilder.swift (BaseState: board, buildings, coins, station, base-test records)
                  BaseExperiment.swift (Test My Base bridge: inputs, definition, level rule)
                  Guide.swift (14 GuideGoals, EarnAdvisor)
    Learn/        Lessons.swift (LearnLevel, LessonTopic pools, 2 lessons, 54 questions)
  Features/
    Base/         BaseView.swift, BaseBuilderViews.swift (Build shop, PlacementBar, BuildingPanel, StationPanel, Learn, Drills, Style, GoalCard, EarnCoins)
    Mission/      MissionSession.swift (state machine; baseTest context; playbackSpeed), MissionView.swift (QuickPlanCard, BetOverlay, BaseGearCard, BaseTestCard, PlaybackPanel), PlaybackScript.swift
    Learn/        LessonView.swift
    Science/      SourcesView.swift (sources + SettingsView incl. developer section)
  DesignSystem/   GameKit, Theme (Format), Coin, Accessibility, SoundFX (+ .upgrade, .thud), LofiComposer
  Rendering/      WorldScene/WorldSnapshot (drill world), BoardScene/BoardArt (base board), UpgradeArt.swift (level 2/3 buildings),
                  ComponentArt (level 1 art), IsoArt (Iso projection, IsoPainter, ArtCache)
```

Key patterns: scenes are driven by immutable snapshots and send intents back through callbacks; `Iso.point(gx,gy) = ((gx-gy)*32, -(gx+gy)*16)`; procedural art cached by key in `ArtCache`; every animation honours the single reduced-motion policy; `IsoPainter` draws into a y-down context with `pt.p(x,y,z)`, `box`, `cylinder`, `domePath`, `gradient`, `line`, `fill`, `stroke`.

## 6. What the game is now

### Home base (Clash-style board)
- 12×12 board, pinch/pan/zoom, tap a building for its panel (it bounces and clicks), place/move with tap, drag or nudge arrows.
- **Buildings:** habitat (3×3, pre-placed), solar array, battery, dish (1×1), greenhouse, shelter (2×2), **landing station** (2×2, starts as a ruin), **decorations**: base flag 30, lamp post 25, Moon rock garden 35 (looks only, no levels, max 2/4/3).
- **Costs (game rules):** array/battery 40, greenhouse 120, shelter 150, dish 150. Upgrades to level 3: habitat 150/300, array & battery 60/100, others 120/200. Station repair 60.
- **Levels change the building's whole look** (`UpgradeArt.swift`): habitat → two-storey → three-storey tower; battery → twin cells → reactor core; solar array → tracking panel → solar tree; dish → tower → taller gold-rimmed tower with rings; greenhouse → glass garden hall → bio-dome tower; shelter → two-storey bunker → shielded fortress. Plus a cyan (L2) or gold (L3) deck, hologram ring at L3, upgrade celebration (light column, shock ring, sparkles, "LEVEL N!" tag) and a new upgrade sound.
- **Coins:** start 150; lessons 15 per first-try answer + 40 first finish (5 per answer on replays); drills 80 first completion, 25 per new star, 15 later win, 0 on failure; goal bonus +25; first passed base test +40.
- **Guide:** 14 goals with one "Show me" each: build array → battery → Lights Out → **fix the landing station → test your real base** → Plants and Air → greenhouse → Living Base → decorate → shelter → Storm → dish → Signal Lag → upgrade habitat. Goal toast now always fades.
- **Lessons:** "Plants and Air" (unlocks greenhouse) and "Power and Batteries". Three levels chosen in Learn and saved: Explorer (2 choices), Builder (3 choices), Mission Engineer (sums and reasons). Each fact has 6 questions (2 per level); one is picked per play, answers shuffled.
- **Developer mode (demo only):** Settings → About → tap the "Moonbase Academy by VANGUARD Systems…" line 7 times. Add/zero coins, set any/all building levels, unlock every drill/lesson/blueprint and repair the station. Session only; game rules only. Do not show it in the demo.

### Test My Base (the core new mechanic)
- Opens from the repaired landing station, the Drills sheet, or its goal.
- Counts the player's **working** solar arrays and batteries (max 4 each) and runs the six-hour Lights Out shadow through the unchanged `ResourceEngine` as a separate definition (`lightsOut.myBase`).
- **Game rule:** level 1 = Lights Out equipment (1 kW per array in sunlight, 4 kWh per battery); **level 2 counts 1.5×, level 3 counts 2×**. Entered into the engine as N items of average strength (totals exact). Other buildings' levels, colours, decorations and positions change nothing.
- The child sets the air maker (Off/Half/Full) for sunlight and shadow and the science observation directly on the plan cards, which show live "drains the battery / spare power" and "air maker keeps up / crew breathes from the tank".
- Result says, from the trace, whether more storage or more generation was needed; shows the base's gear, the last saved test and what changed.
- Records are stored apart from drills (`BaseState.baseTests`, last 4): no completion, stars, attempts or drafts. A failed test costs nothing.
- Hand-checked outcomes pinned in tests: 1 array + 1 battery at full air fails; half air in shadow passes but spends oxygen; a second battery alone still fails; a second array (or a level 2 array) passes.

### The four reference drills (unchanged engines)
1. **Lights Out** — arrays vs batteries through a 6 h shadow (9 h harder version). Power, life support.
2. **The Living Base** — 33-day greenhouse on a daily energy budget. Food, life support.
3. **Storm Drill** — shelter through a real archived particle event. Radiation shielding. **Replays now pick one of 8 real storms** (27 h to 138 h) and name the date; first play is always 2017-09-10.
4. **Signal Lag** — drive a rover with Earth–Moon light delay. Communication delay.

Drill flow: briefing → plan → **"What will happen?"** (two outcome buttons per drill; VoiceOver labels remain Yes / No / Not sure) → playback (Plays by itself / Step by step, pause, replay, **1× / 2× / 5× speed**, skip) → result.

### Science sources in the package
- N1 NASA BVAD (oxygen 0.895 kg/person/day, dry food 0.8) · N2 NASA Veggie fact sheet (33 days, 70 W) · N3 **CCMC SEP Scoreboard** archive (8 GOES-13 events) · N4 NASA Moon Facts (384,400 km) · S1 BIPM SI (c).
- **Not used: DONKI, OSDR, Artemis data.** DONKI could not be reached; the docs make no DONKI claim.
- **Open check:** seven storm rows were entered by an AI from an automated fetch. They cross-check (2017-09-10 matched the hand-transcribed row; 5 of 7 derived durations equal the table's own column, the other two within 0.3 h), but **a team member must re-read them against https://ccmc.gsfc.nasa.gov/challenges/sep/events/ before submission**.

## 7. The plan we agreed (to win)

Assessment against the criteria:

| Criterion | Now | Gap |
|---|---|---|
| Relevance | Strong: five topics, ages 7–12, trade-offs | Radiation and "simulated mission" are thin |
| Validity | Strong engine and sourcing, unverified | No tests run; (fixed) upgrades used to do nothing |
| Creativity | Build a base, then test the base you built | Only one base-test type |
| Impact | Unproven | No child has played it |
| Presentation | Nothing exists | No demo, no pushed repo, no project page text |

Build order:
1. ✅ **Upgrades matter in Test My Base** (done, `b2a94c8`, unbuilt).
2. ✅ **Real archived storms, different each replay** (done, `b2a94c8`, unbuilt; CCMC archive, not DONKI).
3. ⏭ **Storm Test on the player's own base** — NEXT. A second test at the landing station: a real archived storm hits *your* base; your shelter and batteries decide whether the crew stays sheltered with enough air. This makes radiation shielding a first-class mechanic and matches the brief's "shielding at the cost of tonight's power".
   - Suggested design: mirror `BaseExperiment.shadowTest`. Start from `MissionCatalog.stormDrill(science:)` with a storm picked from `package.usableStorms`; variant id e.g. `"myBaseStorm"`; shelter present only if the base has a working shelter (else actionable message "Build a storm shelter"); starting battery capacity from the base's batteries with the level rule; keep the 0.8 kW supply and 3 kWh shelter-activation cost as labelled game rules; store results in `baseTests` (the record needs a `kind` field, optional for old records). Reuse `MissionSession(baseTest:)`; note `isBaseTest` currently assumes Lights Out copy (`GameCopy.baseTest`, `MissionCopy` branch, `BetOverlay` outcomes, `BaseGearCard`), so each needs a storm branch. Add tests like the shadow ones.
4. ⏭ **Presentation:** project page text for `SUBMISSION.md`, dataset explanation (mostly in `SCIENCE_AND_DATA.md`), 30-second shot list: title over the base → place array and battery, repair the station → Test My Base fails → upgrade or add an array → passes → sources screen → closing line. Owner records and submits.

Deliberately left out (and why):
- **Multi-day mission mode** — biggest remaining gap against "simulated mission", too large to build and verify blind.
- **OSDR health data / radiation dose** — no dose model; inventing one would hurt Validity.
- **More building art** — Presentation points only; enough spent.
- **V2 Phases 4–7** and base tests for food and comms.

## 8. Commit log on `base-builder` since the previous handoff

| Commit | What | Built? |
|---|---|---|
| `12dd3c9` | Landing station (ruin → repair) + Test My Base | Yes (log 15:39) |
| `38e91c6` | Decorations, Power lesson, tap feedback | Yes (logs 16:05–16:11) |
| `f12c3d8` | Play-test round 1: black band fix, toast fix, inline plan switches, outcome prediction, lesson levels | Yes (owner screenshots 20:22) |
| `21eba85` | README + handoff docs | n/a |
| `97abdef` | Upgrade add-ons, celebration + sound, shadow briefing, playback speed | Yes (owner used it) |
| `496ba10` | **Full building redesign**, developer mode | Yes (log 20:56) — art not yet seen by Claude |
| `b2a94c8` | Upgrades count in tests; 8 real storms | **No** |

## 9. Verification status (be honest about this)

- **Compiles:** through `496ba10`. `b2a94c8` unknown.
- **Unit tests:** 137 test methods in source; the last recorded run is 56/56 from before V2. `BaseExperimentTests.swift` (23 tests: station, migration fixture, bridge, engine outcomes, rewards, full loop, decorations, lessons, upgrade rule, storms) has **never been compiled**. Expect failures and fix from the log.
- **UI test** (`MissionOneFlowTests`): follows the guide through Lights Out. An old failure at "The improved plan should succeed" was never investigated. The prediction dialog was rearranged; its accessibility labels (Yes, No, Not sure, "One step at a time") were kept on purpose.
- **Seen on the owner's iPad:** board, landing station repaired, Test My Base planning/prediction, round 1 fixes. **Not seen:** decorations, level 2/3 redesigned buildings, upgrade celebration, speed buttons, storm replays, developer panel, anything on iPhone.
- **Not done at all:** VoiceOver pass, largest text, child play-test, team re-read of the seven storm rows.

## 10. Known risks and likely first failures

- `Lessons.swift` has long array literals of questions; if the compiler reports "unable to type-check in reasonable time", split each topic into its own `let`.
- `UpgradeArt.swift` geometry may sit off-tile or clip; canvases were sized by hand.
- `BaseExperimentTests` uses `@MainActor` tests creating `AppModel`; the full-loop test drives `MissionSession` through `beginPlanning → goToPrediction → run → skipPlayback`.
- `EventRow` in `SourcesView` now derives duration from the event itself.
- Storm replays change `drillLabel` and pass a modified `ScienceInputs`; drafts always restore with the standard storm.
- The Xcode test navigator showed only 57 tests earlier (stale index).

## 11. Quick reference values

- Training assumptions (game rules): air maker 2.0 kg/day at 0.5 kW; essential load 0.1 kW; oxygen tank 7.16 kg starting at 3.58 kg; crew 2; array 1 kW in sun; battery 4 kWh; garden 16 h light, 0.01 kW standby; storm 0.8 kW supply, shelter 3 kWh; rover 1 m/s, bay 5–6 m.
- Test My Base at level 1: sunlight 6 h, shadow 6 h; base uses 0.6 kW at full air (0.35 at half); shadow needs 3.6 kWh; one array stores 2.4 kWh in the sunlit phase.
- Storms bundled (start UTC → end UTC): 2012-03-07 05:10 → 03-12 22:55 · 2012-05-17 02:10 → 05-18 17:45 · 2012-07-12 18:35 → 07-14 23:00 · 2013-04-11 10:55 → 04-13 00:50 · 2014-01-06 09:15 → 01-07 19:30 · 2014-01-07 19:30 → 01-11 20:35 · 2017-07-14 09:00 → 07-15 12:15 · 2017-09-10 16:45 → 09-14 18:50.

## 12. How to start the new chat

1. Attach this file and select the folder `/Users/sjafari/Downloads/NASA`.
2. Tell Claude what happened since: did `b2a94c8` build, did ⌘U run, was the push done.
3. Claude should: request delete permission for the folder (for git), read the newest build/test logs, fix failures, then continue at section 7 item 3.
