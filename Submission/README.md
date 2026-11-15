# Review Moonbase Academy

[Watch the 29-second demo](media/moonbase-academy-demo.mp4) · [Caption transcript](media/captions.srt) · [Science and limits](../SCIENCE_AND_DATA.md) · [Validation](../VALIDATION.md) · [AI/tool disclosure](../AI_USE.md)

Native iPhone/iPad prototype for ages 7–12. Build and run in Xcode using the instructions in the [project README](../README.md). No account, backend or downloads are needed by the running app. Browser and App Store versions are not available.

## A quick investigation

1. Open **Drills → Start example lab**. Use **Equipment** to inspect the setup, then **Operating plan** to inspect the numbered sunlight/shadow stages. Leave the air maker at Full. Launch, choose a forecast and a reason, then tap **Start test**. Use Step by step to watch each checkpoint or skip to the result. The starter test fails at hour 10: sunlight stored 2.4 kWh; shadow needs 3.6 kWh.
2. Read **You expected / We observed** and check the explanation of your reason. Tap **Try one change**. The **Operating plan → 2. Shadow drill** controls are highlighted. Set shadow air to **Half**, make a fresh prediction, and test. It reaches 12 hours, saving 1.5 kWh against Full and withdrawing 0.1975 kg of oxygen. The comparison identifies exactly one change.
3. To compare equipment at Full air, use **Reset lab to starter plan**, run the starter test, then choose **Extra battery**. It still fails: empty capacity does not generate energy. For a one-variable solar comparison, choose Starter base and run it again before choosing Extra array; it completes 12 hours. Equipment buttons show their counts and preserve air/science settings. The result reports every change if you switch several variables.
4. Open **Drills → Start storm example**. Full air with science Off keeps the crew safe but leaves the task unfinished. Open **Operating plan → 1. Storm rising** and retry with **air Half, science On**; leave fading at **air Full, science Off**. The crew completes the pinned 98-hour-5-minute event and science task. Inspect the oxygen and energy trade-off.
5. A correct forecast of failure receives recognition while the engineering objective remains unfinished. An incorrect mechanism receives corrective feedback even when the forecast was right. **I'm not sure yet** allows observation, and **Change my plan** returns without consuming a trial or changing its settings.

Example labs use the same resource engine as the player's base tests. They never write campaign progress, rewards, drafts or playback preferences. Equipment capacities, science objectives and the backup supply are labeled game rules.

## What is real science?

The app uses NASA adult crew oxygen/food demand, a Veggie crop reference, archived CCMC particle-event timestamps, and NASA's average Earth–Moon distance. The SI speed of light supplies radio propagation time. Values have provenance labels in the app and in the science package. The storm is a replay clock based on near-Earth observations; no lunar radiation dose is calculated.

## Demonstration material

The 29.000-second, 1080 × 1920 H.264 video contains edited actual iPad Simulator capture. Captions are burned in, with a separate SRT transcript. There is no narration or music. AI-assisted captions/editing are disclosed visibly throughout and in file metadata. The Swift renderer is included as `render_demo.swift`; the longer raw capture is kept outside this repository.

| Screenshot | What to inspect |
|---|---|
| [Equipment workspace](media/planning.png) | Visible base, separate Add/Remove controls and equipment counts |
| [Operating plan](media/operating-plan.png) | One numbered stage at a time, clear settings and reserve consequences |
| [Prediction and reason](media/prediction-with-reason.png) | Selected hypothesis and separate Start test action |
| [Power failure](media/power-failure.png) | Stored energy, required energy, actual stopping time |
| [Reserve trade-off](media/oxygen-tradeoff.png) | Energy saved and oxygen withdrawn at the same elapsed time |
| [Storm success](media/storm-success.png) | Crew protection and a completed science task |
| [NASA sources](media/nasa-sources.png) | Reference, derived, training-assumption and physical-constant labels |

Project-page copy is in [SUBMISSION.md](../SUBMISSION.md), with matching structured fields in [fields.json](fields.json).
