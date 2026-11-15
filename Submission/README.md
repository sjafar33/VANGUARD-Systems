# Review Moonbase Academy

[Watch the 29-second demo](media/moonbase-academy-demo.mp4) · [Caption transcript](media/captions.srt) · [Science and limits](../SCIENCE_AND_DATA.md) · [Validation](../VALIDATION.md) · [AI/tool disclosure](../AI_USE.md)

Native iPhone/iPad prototype for ages 7–12. Build and run in Xcode using the instructions in the [project README](../README.md). No account, backend or downloads are needed by the running app. Browser and App Store versions are not available.

## A two-minute investigation

1. Open **Drills → Start example lab**. Leave the air maker at Full, launch, predict, and skip to the result. The test fails at hour 10: sunlight stored 2.4 kWh, but shadow needs 3.6 kWh.
2. Choose **Extra battery**. Launch again. The extra empty storage still fails because it does not generate energy.
3. Choose **Extra array**. The same starting supplies now last all 12 hours. The result compares this run with the starter base.
4. Choose **Starter base**, then set shadow air to **Half**. This also passes, saving 1.5 kWh against Full over 12 hours but withdrawing 0.1975 kg from the oxygen tank.
5. Open **Drills → Start storm example**. Full air with science Off keeps the crew safe but leaves the task unfinished. Retry with **Storm rising: air Half, science On**; leave the fading phase at **air Full, science Off**. The crew survives the pinned 98-hour-5-minute event and completes the science task. Compare oxygen withdrawn and energy saved.

Example labs use the same resource engine as the player's base tests. They never write campaign progress, rewards, drafts or playback preferences. Equipment capacities, science objectives and the backup supply are labeled game rules.

## What is real science?

The app uses NASA adult crew oxygen/food demand, a Veggie crop reference, archived CCMC particle-event timestamps, and NASA's average Earth–Moon distance. The SI speed of light supplies radio propagation time. Values have provenance labels in the app and in the science package. The storm is a replay clock based on near-Earth observations; no lunar radiation dose is calculated.

## Demonstration material

The 29.000-second, 1080 × 1920 H.264 video contains edited actual iPad Simulator capture. Captions are burned in, with a separate SRT transcript. There is no narration or music. AI-assisted captions/editing are disclosed visibly throughout and in file metadata. The Swift renderer is included as `render_demo.swift`; the longer raw capture is kept outside this repository.

| Screenshot | What to inspect |
|---|---|
| [Power failure](media/power-failure.png) | Stored energy, required energy, actual stopping time |
| [Reserve trade-off](media/oxygen-tradeoff.png) | Energy saved and oxygen withdrawn at the same elapsed time |
| [Storm success](media/storm-success.png) | Crew protection and a completed science task |
| [NASA sources](media/nasa-sources.png) | Reference, derived, training-assumption and physical-constant labels |

Project-page copy is in [SUBMISSION.md](../SUBMISSION.md), with matching structured fields in [fields.json](fields.json).
