# Validation — November 15, 2026

## Final regression

**155 passed, 0 failed, 0 skipped**: 147 unit tests and 8 UI tests. Xcode 27.0, iOS Simulator 27.0, iPad Air 11-inch (M4), arm64, Debug, MoonbaseAcademy scheme. [Machine-readable xcresult summary](Submission/final-test-summary.json).

The final run covers the final game implementation. The demonstration uses actual normal-text iPad capture of the same experiment flow; the subsequent accessibility layout correction affects large-text planning. No game code changed after this regression.

| Check | Verified behavior |
|---|---|
| Cargo interaction and original mission | Add and Remove hit separately; placement fixture avoids the landing station; failed plan can be revised to pass; progress survives relaunch |
| Base experiment | Actual failure hour is recorded; upgrades change comparison totals; an extra empty battery cannot fix generation shortage; extra generation or an air/oxygen trade-off can succeed |
| Save isolation | Example labs leave progress, coins, unlocked content, drafts, preferences and the on-disk save unchanged; legacy records decode with missing timing marked unavailable |
| Bounded own-base storm | Working shelter/battery requirements; explicit setup cost; science task required; continuous reserves across phases; repeatable pinned event; reserve-spending and extra-storage strategies |
| Science sensitivity | Changed crew demand, crop reference, Moon distance and archived timestamps change the engine's outcomes |
| Hypothesis and revision | Forecasts and reasons cannot change physics; a correct failure forecast is distinct from mission success; misconception feedback and the original prediction survive revision; changed controls and reserve costs are reported |
| UI flows | Original mission/relaunch, shadow and storm examples, Accessibility XXXL text, correct failure prediction, misconception feedback, and an unskipped Unsure/Back investigation reach their expected results |

Reproduce in Xcode: open `MoonbaseAcademy.xcodeproj`, choose **MoonbaseAcademy** and the iPad simulator, then **Product → Test** (⌘U). Automated UI tests use their own isolated save. See [reviewer examples](Submission/README.md) for manual steps.

## Device usability

Seven focused example UI flows passed on iPhone 17 Simulator, with nine successful executions including repeats of the two accessibility flows after the final layout correction. [Phone verification](Submission/phone-test-summary.json). The checks cover shadow/storm outcomes, correct failure forecasts, misconception feedback, Unsure/Back, unskipped playback, and Accessibility XXXL text.

Screenshot review exposed a problem that successful taps alone missed: at the largest phone text size the fixed header and oversized action left too little reading space, while equipment headings competed for width. The final layout lets the planning header scroll away, stacks the equipment heading/help, and keeps a shorter fixed Launch action. It preserves the chosen text size. Both affected phone flows passed again, including an assertion that the action leaves reading space. Screenshots were inspected for panel containment, result explanations, controls, reserve costs and source labels. The demonstration uses actual iPad capture.

These checks do not establish learning effectiveness. No child participant study, physical-device battery/performance study, complete landscape-device matrix, full VoiceOver/Switch Control pass, or App Store/TestFlight distribution is claimed.

## Scientific provenance

All eight bundled CCMC events were rechecked against the official public HTML on November 15: threshold crossing, peak, end and maximum flux matched for every row. [Result](Submission/ccmc-source-check.json), [recheck script](Submission/check_ccmc.py). BVAD, Veggie, Moon distance and SI constant provenance are documented in [SCIENCE_AND_DATA.md](SCIENCE_AND_DATA.md) and the bundled science package. Source values and training assumptions have separate in-app labels.

## Demonstration

AVFoundation inspection reports exactly **29.000 seconds**, H.264, 1080 × 1920, 30 fps. All six scenes and the final frame were visually checked against the actual results. Captions are burned in and provided as [SRT](Submission/media/captions.srt). There is no voiceover or music. AI-assisted editing is disclosed on every frame and in metadata.

## Submission boundary

The public repository contains source, reproducible examples, screenshots, science explanation, disclosure, captions and the short demo. Saving the Space Apps page is separate from submitting for judging; the website's final submission status is the authoritative confirmation. Participant terms and originality declarations must be accepted by the project owner.
