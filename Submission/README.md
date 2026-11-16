# Review Moonbase Academy

[Watch the 27-second gameplay demo](https://youtube.com/shorts/OFn2BLQ81js) · [Science and limits](../SCIENCE_AND_DATA.md) · [Validation](../VALIDATION.md) · [AI/tool disclosure](../AI_USE.md)

Native iPhone/iPad prototype for ages 7–12. Build and run in Xcode using the instructions in the [project README](../README.md). No account, backend or downloads are needed by the running app. Browser and App Store versions are not available.

## A quick investigation

1. Open **Drills → Shadow lab → Play**, then **Reset lab**. Keep one solar array and one battery. Open **Plan** and leave both sunlight and shadow air at Full, with science Off. Launch, choose a forecast and reason, then tap **Start test**. In Step by step playback, use Next and See result. The starter test fails at hour 10: sunlight stored 2.4 kWh; shadow needs 3.6 kWh.
2. Read **Your idea vs. what happened** and check your reason. Tap **Try again**, open **Plan → 2. Shadow drill**, and set air to **Half**. Keep equipment and the sunlight plan unchanged. Make a fresh prediction and test. It reaches 12 hours, saving 1.5 kWh against Full and withdrawing approximately 0.1975 kg of oxygen. Open **Why? See the numbers** to inspect the comparison.
3. For an equipment experiment, reset to one array, one battery and Full air. Adding an empty battery alone does not fix insufficient generation. Reset again and add one solar array while retaining one battery: increased generation completes the test at Full air. Separate additions and removals preserve operating settings.
4. Open **Drills → Storm lab → Play**. Full air with science Off leaves the task unfinished. In **Plan → 1. Storm rising**, retry with air Half and science On; leave fading at air Full and science Off. Inspect the science, oxygen and energy trade-off across the archived 98-hour-5-minute event.
5. A correct forecast of failure is distinct from mission completion. Reason feedback addresses the proposed mechanism. **I'm not sure yet** allows observation, and **Change my plan** returns from prediction without changing the configuration.

Example labs use the same resource engine as the player's base tests. They never write campaign progress, rewards, drafts or playback preferences. Equipment capacities, science objectives and the backup supply are labeled game rules.

## What is real science?

The app uses NASA adult crew oxygen/food demand, a Veggie crop reference, archived CCMC particle-event timestamps, and NASA's average Earth–Moon distance. The SI speed of light supplies radio propagation time. Values have provenance labels in the app and in the science package. The storm is a replay clock based on near-Earth observations; no lunar radiation dose is calculated.

## Demonstration material

The final 27-second demonstration is actual gameplay recorded by the project owner on an iPad Air and edited by the owner in DaVinci Resolve. It is not AI-generated video. Watch it on [YouTube](https://youtube.com/shorts/OFn2BLQ81js). The old simulator montage and its caption/renderer assets have been superseded by this direct video link.

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
