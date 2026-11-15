# Moonbase Academy — Handoff for a New Chat

_Written 2026-11-14, about 14:45 Toronto time. Paste or attach this file at the start of a new chat. It replaces the need to read the previous conversation._

---

> **Update, 2026-11-14 evening.** Sections 5-7 below are older than the code. Read the "Base-builder brief" part of `PHASES.md` first: it has the Phase 0 audit, the Phases 1-2 checkpoint (landing station, Test My Base) and "Play-test round 1". Corrections to this file: the app target DOES compile (build logs, commits `12dd3c9` and `38e91c6`); commit `f12c3d8` and later are not yet compiled; no unit or UI test has run since before V2. Claude can read build logs but cannot build: Xcode only accepts plain clicks from it.

## 1. What this is

- **App:** Moonbase Academy, a native **iPhone + iPad** game (SwiftUI + SpriteKit, iOS 17+). It's built for the **NASA Space Apps Challenge 2026** by team **VANGUARD Systems**. The owner (Sadegh) has teammates.
- **Challenge brief (keep this central):**
  - Kids aged 7–12 manage a lunar or Martian outpost.
  - They make real decisions about life support, radiation shielding, power budgeting, food production and communication delay, and see the consequences.
  - **No choice is free:** every decision is a real trade-off.
  - Ground it in **real NASA data** (DONKI, OSDR, Artemis and so on), attributed in the app. Don't present static data as live.
  - Keep it simple: 2–3 core resources. Plain language, with science terms explained in context.
  - Stand-out factors: links to real data, replayability, and learning from failure without punishment.
  - Ship a short explanation of the datasets used.
- **Owner's current vision (most important):** a **Clash-of-Clans-style base builder for kids**.
  - A board where you place, build, move, upgrade and customize (skins, colours, robots).
  - **Coins come from learning** (interactive lessons and quizzes) and from the real trade-off drills.
  - It should be fun enough that kids want to come back, without being hard. There must be **zero friction** for a child, with constant guidance ("what do I do next?").
  - It must look and feel like a **professional, animated game**, not a prototype.

## 2. Where things are

- **Repo on the owner's Mac:** `/Users/sjafari/Downloads/NASA/MoonbaseAcademy`
  - In the Claude device shell it's mounted at `$HOME/mnt/NASA/MoonbaseAcademy`.
- **Xcode project:** `MoonbaseAcademy.xcodeproj`
  - Xcode 27 / iOS 27 SDK, Swift 5 language mode.
  - Uses file-system-synchronized groups (objectVersion 77), so **new .swift files are picked up automatically**.
  - Has a shared scheme.
- **Targets:** `MoonbaseAcademy`, `MoonbaseAcademyTests` (unit), `MoonbaseAcademyUITests`.
- **DerivedData lives inside the project folder:** `DerivedData/MoonbaseAcademy/Logs/Build/*.xcactivitylog` (gzip).
  - To find compile errors, run: `gunzip -c <log> | tr '\r' '\n' | grep -a "error:"`
- **Git branches** (all local; **nothing has been pushed, there is no remote**):
  - `main` @ `107b088`: original V1 plus the music work.
  - `v2` @ `40317c9`: phased V2 work (Phases 0–3).
  - **`base-builder` @ `b635419`: CURRENT working branch.** It branched from `v2`.
- **Docs in the repo:** `HANDOFF.md` (long running log: V2 baseline findings F1–F11, phase checkpoints, base-builder rounds), `PHASES.md` (phase tracker), `README.md`, `SCIENCE_AND_DATA.md`, `AI_USE.md`, `THIRD_PARTY_NOTICES.md`, `SUBMISSION.md`, `LICENSE` (MIT), `Design/AppIcon.svg` (app icon source).
- **Original phased brief:** `Moonbase_Academy_V2_Phased_Coding_Prompt.md`, uploaded by the owner and not in the repo. It defines Phases 0–7 and the checkpoint report format. The owner has since moved to the base-builder direction; the phase rules still apply as good practice.

## 3. How we work (important constraints)

- **Claude usually cannot build or run.** Code is edited through the device shell (a Linux VM that can't run `xcodebuild`).
  - Computer-use access to Xcode exists only at the "click" tier: no keyboard, so no ⌘B or ⌘U.
  - Xcode is usually on another macOS Space or full-screen, so clicks don't land.
- **So the owner builds and tests:**
  - Claude writes code very carefully, runs a bracket-balance Python check on changed files, commits, and asks the owner to press ⌘B / ⌘U on the iPad Air 11-inch (M4) simulator, the iPhone simulator, or the physical "SJ iPad".
  - The owner sends screenshots of errors. Claude reads the error from the DerivedData build log (above) and fixes it.
- **Never claim** something was compiled, tested, or verified on a device or with accessibility tools unless it actually was.
- **Git:**
  - Commit in sensible chunks on the current branch.
  - Never push or merge without asking.
  - End commit messages with:
    `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_014fjBMgV32XVUin9g3D96wW` (the new chat may give a new session line).
- **Science integrity rules (non-negotiable):**
  - Drill physics and NASA source values are never changed to make something look better or to pass a test.
  - Game rules (coins, costs, upgrades, cosmetics) never change the numbers inside a drill.
  - Label game assumptions as "Game rule", not NASA data.
  - All copy must use the actual drill and variant numbers (no hard-coded "6 hours / 17 kWh / 33 days").
- **Other rules:**
  - No accounts, ads, analytics, tracking, backend or remote AI.
  - No manipulative retention: no timers, streak loss, loot boxes or waiting.
  - Don't describe accessibility options as ADHD treatment.
  - Preserve user saves: new persisted fields are **optional** for backward compatibility. Tests use isolated saves.
- **Owner's style:** direct and fast. Wants real, polished game feel and kid-first UX. Responds well to concise summaries plus a clear "what I need from you".

## 4. Architecture overview

```
MoonbaseAcademy/
  App/            AppModel.swift (central @Observable model: progress, routing, base board, coins, guide, drafts, settings)
                  MoonbaseAcademyApp.swift (RootView: environments appReduceMotion/focusView/novaColors, scenePhase handling)
                  LaunchOptions.swift (-uiTesting / -resetProgress isolated save), KeyboardDismissal.swift
  Core/
    Science/      SciencePackage.swift + Resources/Science/science_package.json (bundled NASA values, sources N1–N4, S1, validation)
    Simulation/   ResourceEngine.swift (deterministic resource sim), RoverEngine (signal-lag sim)
    Missions/     MissionModels.swift, MissionCatalog.swift (4 drills + harder variants),
                  MissionContent.swift (MissionCopy.of(def,science), ExplanationWriter, Words, UnitHelp, CargoCopy),
                  GameCopy.swift (Nova intro lines per drill, rank, commentary)
    Progress/     Progress.swift (CampaignProgress, AttemptRecord, Achievement, MissionDraft, SaveStore/SaveEnvelope schema 1)
    Base/         BaseBuilder.swift (BaseState: board rules, buildings, costs, upgrades, cosmetics, coins, starting base/migration)
                  Guide.swift (GuideGoal 12-step guide, EarnAdvisor "how to earn coins")
    Learn/        Lessons.swift (Lesson model + LessonLibrary.plantsAndAir)
  Features/
    Base/         BaseView.swift (home: board + HUD + goal card + sheets), BaseBuilderViews.swift (Build shop, PlacementBar,
                  BuildingPanel, Learn list, Drills list, Style shop w/ preview, GoalCard, GoalToast, EarnCoinsView, GuidePulse)
    Mission/      MissionSession.swift (drill state machine), MissionView.swift (drill UI), PlaybackScript.swift (checkpoints)
    Learn/        LessonView.swift (full-screen lesson)
    Science/      SourcesView.swift (sources, assumptions, limits + SettingsView incl. Focus & Accessibility)
  DesignSystem/   GameKit.swift (buttons, pills, Nova avatar + NovaColors, stars, confetti, Haptics), Theme.swift, Coin.swift,
                  Accessibility.swift (appReduceMotion/focusView env keys, Narrator read-aloud, ReadAloudButton),
                  SoundFX.swift + LofiComposer.swift (original synthesized music/SFX)
  Rendering/      WorldScene.swift + WorldSnapshot.swift (drill isometric world, snapshot-driven; briefing SceneBeats),
                  BoardScene.swift + BoardArt.swift (base board scene: zoom/pan, buildings, ghost, idle life),
                  ComponentArt.swift (procedural CoreGraphics art: habitat, arrays, batteries, greenhouse, shelter, rover, terrain…),
                  IsoArt.swift (Iso projection, ZLayer, IsoPainter, ArtCache)
```

**Key patterns:**
- Scenes are driven by immutable snapshots (`WorldSnapshot`, `BoardSnapshot`). Scenes never change game state; they send intents through callbacks.
- `SKNode`, `Art` and `BoardArt` are `@MainActor`.
- Isometric projection: `Iso.point(gx,gy) = ((gx-gy)*32, -(gx+gy)*16)`; depth = `200 + (gx+gy)*10`.
- Procedural art is cached in `ArtCache`. There are no external image assets apart from the app icon PNG.
- Every animation honours `reduceMotion`: the single policy is the system setting OR the in-app switch, via the `appReduceMotion` environment value and `AppModel.reduceMotion`.

## 5. The game today (on `base-builder`)

### 5.1 Base builder (home screen)
- **Board:** 12×12 tiles (coords −6…5) on a raised Moon platform.
- **Footprints:** habitat 3×3 (pre-placed, id `"habitat"` at −2,−2), greenhouse and shelter 2×2, solar array, battery and dish 1×1.
- **Controls:** pinch to zoom 1–2.8×, one-finger pan, plus zoom +/− and "show whole base" buttons. Tap a building to open its panel (upgrade, move, play its drill). Placement shows a green ✓ / red ✕ preview; you can tap or drag it, or use the nudge arrows.
- **Idle life (all off with reduced motion):**
  - Twinkling stars and shooting stars.
  - A rover patrols the platform edge, and the robot buddy hops between free tiles.
  - Solar glints, battery charge bars cycling, habitat beacon and windows, greenhouse glow with swaying plants, shelter glow, dish wobble with signal rings.
  - Gold sparkles at level 3.
  - New buildings drop in like a crate with dust and sparkles; upgrades pop with sparkles.
- **Costs (game rules):**
  - Array or battery 40, greenhouse 120, shelter 150, dish 150.
  - Upgrades go to level 3: habitat 150 then 300; array and battery 60 then 100; others 120 then 200.
- **Upgrade effects:**
  - Habitat level raises the array and battery limit to 2, then 3, then 4.
  - Any drill building at level 2 opens that drill's harder version.
  - Level 3 is cosmetic.
- **Drill gates:**
  - Lights Out needs an array and a battery; The Living Base needs the greenhouse; Storm Drill the shelter; Signal Lag the dish.
  - Drills also unlock in order.
- **Blueprint gates:** the greenhouse needs the lesson "Plants and Air"; the shelter needs The Living Base finished; the dish needs Storm Drill finished.
- **Coins ("Moon coins", gold `CoinIcon`):**
  - Start: 150.
  - Lessons: 15 per first-try correct answer plus 40 on the first finish; replays pay 5 per first-try answer.
  - Drills: 80 for the first completion, 25 per new star, 15 for a later win, 0 for a failure (and nothing is lost).
  - Goal bonus: +25 each.
- **Guide (`GuideGoal`, 12 steps):** build array → build battery → play Lights Out → learn Plants and Air → build greenhouse → play Living Base → decorate → build shelter → play Storm → build dish → play Signal Lag → upgrade habitat.
  - The home screen shows one **GoalCard** with a **"Show me"** button that performs the step.
  - Each goal pays +25 once, with a "Goal complete!" toast.
  - Saves from before the base existed get completed goals marked as claimed, with no back pay.
- **Earn coins:** any unaffordable action opens `EarnCoinsView` (from `AppModel.coinHelpNeeded`). It lists ranked options with Go buttons. It is never empty, because a lesson is always available.
- **Style shop:**
  - 5 habitat colours, 4 ground themes, 4 robot buddies (these recolour Nova everywhere through `novaColors`).
  - "Try it" previews live on the board (`AppModel.previewCosmetic`). The board reframes into the top half while the sheet is open.
  - Buy or Use from the preview; "Get N more" opens Earn coins. Previews never spend or save.
- **Lesson** (`LessonView`, one so far): "Plants and Air", 5 teach cards and 5 questions.
  - Facts: oxygen 0.895 kg per person per day (source N1, NASA BVAD); Veggie lettuce in about 33 days at 70 W (N2).
  - The 16-hour light rule is tagged "Game rule".
  - A wrong answer means "try again", with no lives and no timer. Read aloud and VoiceOver are supported.
- **Migration:** saves without `base` get a seeded base from completed drills, plus 20 coins per star already earned.

### 5.2 The four drills (the real science core; unchanged engines)
1. **Lights Out:** solar arrays and batteries through a 6-hour shadow (9 hours in the harder version). Power vs energy.
2. **The Living Base:** a 33-day greenhouse with 17 kWh/day (16 in the harder version); lights, air maker and research trade-offs.
3. **Storm Drill:** shelter through a real archived SEP event (2017-09-10, GOES-13, CCMC scoreboard, source N3). No radiation dose is calculated (an explicit limitation).
4. **Signal Lag:** drive a rover from Earth with a light-time delay (384,400 km, speed of light).

**Drill flow:** briefing (Nova lines, each with its own animated **SceneBeat**) → planning (build tray, plan cards) → prediction (Yes / No / Not sure, plus a watch-mode choice) → playback (checkpoints; "Plays by itself" or "Step by step"; pause / next / replay; pauses when the app is in the background) → results (three separate stars, explanation, numbers, kW/kWh help, coins earned).

**Briefing beats:**
- Lights Out: dark base, then sunset, then construction.
- The Living Base: plants growing, then energy flowing to the greenhouse, then air bubbles.
- Storm Drill: storm flashes, then the crew walking to the shelter, then cargo crates landing.
- Signal Lag: rover driving, then a signal to Earth and back, then the glowing bay.

### 5.3 Done in the V2 phases (on `v2`, carried into `base-builder`)
- **Phase 1:** player-paced playback, checkpoints built from the trace, reading time not shortened by reduced motion, a garden failure lead based on the daily deficit, VoiceOver announcements.
- **Phase 2:**
  - Separate achievements (completed / predicted / bonus). A correct prediction counts even on a failure; "Not sure" earns nothing and is never shamed.
  - Exact migration from legacy star counts.
  - Narration that follows the trace (no false "tank stayed full").
  - All copy reads the drill's own numbers; science limits are stated explicitly.
- **Phase 3:**
  - Focus & Accessibility settings: Focus view, test pace, Read aloud (AVSpeech, silent while VoiceOver is on), Reduce motion, Haptics, and a Focus suggestions preset.
  - A Build → Predict → Test → Understand step bar.
  - Modal dialogs with VoiceOver focus handling, Dynamic Type layouts, measured contrast fixes.
  - An interrupted plan is restored via `MissionDraft`.
- **Other:** original synthesized music (lofi and space-ambient, `MusicStyle`) and the app icon (Nova on the Moon with Earth; `Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`, source in `Design/AppIcon.svg`).

## 6. Current status and open issues

- **Last action:** fixed a compile error (a missing `)` in `WorldScene.beatCargo`), commit `b635419`.
  - **We are waiting for the owner's ⌘B / ⌘U result.**
  - Everything from commit `0a9877b` onward (base builder rounds 1 and 2) **has never been compiled** apart from that one failed build. **More compile errors are likely**; fix them one by one from the build log.
- **Compile-risk areas to check first if errors appear:**
  - `BoardScene.swift` (touch handling, `zoomLevel` vs `zoom(by:)`).
  - `BoardArt.swift` (`.run {}` closures, robot texture).
  - `WorldScene.swift` beat functions.
  - `BaseView.swift` (sheet enum, `onChange` handlers).
  - `BaseBuilderViews.swift` (StyleCard, EarnCoinsView, GoalCard).
  - `AppModel.swift` (`previewCosmetic` `didSet` inside `@Observable`; `updateBase` generic; init migration block).
  - `GameKit.swift` (`NovaColors` environment; `GameTextModifier` with `@ViewBuilder`).
  - `Accessibility.swift` (Narrator, `SpeechDelegate`).
- **UI test (`MissionOneFlowTests`):** it now follows the guide: "Show me" → "Place here" ×2 → "Show me" → "Start Lights Out" → … → "Drills" → tile "The Living Base, 0 of 3 stars".
  - An older run failed at "The improved plan should succeed" (the step-by-step second attempt); not investigated yet.
  - Waits were raised (60 s for automatic playback).
- **Unit tests:** `BaseBuilderTests` (board, coins, guide, earn advisor, goal bonus once, preview never spends), `FocusAccessibilityTests`, `RewardAndNarrationTests`, `PlaybackTests`, plus the original science and sim tests (about 56).
  - Results file: `TestResults/last-run.txt`, written by `TestSupport`. The last confirmed full pass was 56/56 at 14:47 UTC, before the V2 work.

## 7. Next steps (suggested order)

1. **Get a green build and tests** on `base-builder` (owner runs, Claude fixes). Then play from a fresh start: Settings → Reset All Progress, then follow the "Show me" goals.
2. **Polish based on the owner's play-test.** Their recurring asks: more animation and "professional game" feel, zero friction for kids, clear rewards.
3. **More lessons and blueprint gates:**
   - Power and batteries (kW vs kWh).
   - Solar storms and shielding (SEP event; no dose claims).
   - Talking to Earth (light delay).
   - Each lesson should pay coins and could gate shelter or dish blueprints.
4. **Real NASA data hook (challenge stand-out):** an "archived space weather" card linking the storm drill to real DONKI/CCMC events. It must be curated and bundled and labelled archived, never "live".
5. **Board art upgrades per level, and more decorations.** Possibly a short first-launch tutorial with a pointing hand on the board.
6. **Later V2 phases if wanted:** Phase 4 (learning evidence and provenance in play), Phase 5 (world presentation), Phase 6 (release verification and small owner-run usability check), Phase 7 (submission materials: `SUBMISSION.md`, dataset explanation).

## 8. Quick facts for prompts

- Owner email (for attribution only): sadeghj388@gmail.com. Location: London, Ontario (Toronto time zone).
- Science sources in the package:
  - N1: NASA BVAD (NASA/TP-2015-218570/REV2)
  - N2: NASA Veggie fact sheet
  - N3: CCMC SEP Scoreboard
  - N4: NASA Moon Facts
  - S1: BIPM SI (speed of light)
- Key values: oxygen 0.895 kg per person per day; dry food 0.8 kg per person per day; Veggie lettuce 33 days and 70 W; Moon distance 384,400 km; c = 299,792.458 km/s.
- Training assumptions (game rules):
  - Air maker: 2.0 kg/day at 0.5 kW. Essential load 0.1 kW.
  - Oxygen tank 7.16 kg, starting at 3.58 kg. Crew of 2.
  - Array 1 kW in sun; battery 4 kWh.
  - Garden: 16 h of light; standby 0.01 kW.
  - Storm: 0.8 kW supply; shelter 3 kWh to build.
  - Rover 1 m/s (0.75 in the harder version); bay at 5–6 m.
