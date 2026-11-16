# Guided mission tour

**Status: built and verified on iPad Simulator on November 15.** All seven GuidedTourTests and both GuidedTourFlowTests have passing latest results. The end-to-end test reaches failure, revision, success, the science takeaway and return to base. This is automated interaction, not a timed human rehearsal. See [release validation](../VALIDATION.md) and [results](release-test-summary.json).

## How to start it

Base screen (or any drill) → gear button → **Guided mission tour** (first row in Settings). It opens straight into the tour. **Exit** in the tour's instruction area, or the usual back button, returns to the base.

## What it is

The tour is an ordinary example session on the shared resource engine: starter base (1 solar array, 1 battery), Full air, 6 h sunlight then 6 h shadow. The tour only adds an instruction area, a gold ring on the control it is waiting for, and a compact evidence card in place of the full result screen. It never forces a number: every value on the evidence cards is read from the two finished tests.

- Launch is held back until the plan is the one the step tests. In the change step that means the starting plan with only the shadow air maker set to Half; any other difference shows a reason instead.
- The countdown is skipped and playback runs for about 2 seconds before going to the already computed result ("See result" goes there at once). Simulation steps, rates and success rules are untouched.
- Like the example labs, it writes no progress, coins, stars, history, draft or playback preference. A drill plan that was open when the tour started is kept as the usual resumable draft.

## Shot list (target 25 s, 11 taps, not yet rehearsed)

| Time | Tap | On screen |
|---|---|---|
| 0–3 s | **Predict** | "Can this base stay powered through the shadow?" with the starter base |
| 3–7 s | forecast, reason, **Start test** | Prediction card |
| 7–10 s | (none) | About 2 s of playback, then "Power ran out at hour 10 of 12", stored 2.4 kWh, shadow needed 3.6 kWh |
| 10–14 s | **Try one change**, **Half**, **Launch test** | Plan open at the shadow part, Half ringed, then Launch ringed |
| 14–19 s | forecast, reason, **Start test** | Prediction card, playback, result |
| 19–22 s | **Next** | "Shadow drill air: Full → Half", both results, electricity saved 1.5 kWh, stored oxygen used about 0.2 kg |
| 22–25 s | (none) | "Predict. Test. Explain. Improve." with the NASA reference and the training rules |

Choosing "I'm not sure yet" as the forecast needs no reason and saves two taps. The numbers in this table are the engine's expected values from existing unit tests; confirm them on screen.

## Narration (53 words)

Moonbase Academy turns a lunar base into an experiment. Can it stay powered through shadow? I predict, then test. Power fails at hour ten: a useful result. I change one thing, Half air, and test again. It works, but saved electricity cost stored oxygen. NASA crew data drives demand. Predict, test, explain, improve.

## Known limits

- VoiceOver: while the prediction card is open it is a modal, so the tour's instruction area is not reachable until the card closes.
- On a phone the top bar plus the instruction area leave less room; the prediction card and evidence card scroll.
- iPad landscape, phone and largest text sizes are unchecked.
