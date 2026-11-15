# Validation — November 15, 2026

## Final regression

**156 unique tests verified**: 147 unit tests and 9 UI tests, with every latest result passing. Xcode 27.0, iOS Simulator 27.0, iPad Air 11-inch (M4), arm64, Debug, MoonbaseAcademy scheme. [Machine-readable latest results](Submission/final-test-summary.json).

The full regression initially had one obsolete UI navigation failure: the original mission test searched for cargo while Operating plan was selected. It was updated to select Equipment explicitly. A focused rerun then passed all 147 unit tests, the expanded workspace test, and the entire original mission/success/relaunch flow (149 passed). The earlier eight example UI checks passed, giving 156 distinct passing latest results. The [initial result](Submission/refinement-ipad-initial-summary.json) and [focused rerun](Submission/refinement-ipad-rerun-summary.json) are retained. Final surface polish was included in that rerun.

| Check | Verified behavior |
|---|---|
| Cargo interaction and original mission | Add and Remove hit separately; placement fixture avoids the landing station; failed plan can be revised to pass; progress survives relaunch |
| Base experiment | Actual failure hour is recorded; upgrades change comparison totals; an extra empty battery cannot fix generation shortage; extra generation or an air/oxygen trade-off can succeed |
| Save isolation | Example labs leave progress, coins, unlocked content, drafts, preferences and the on-disk save unchanged; legacy records decode with missing timing marked unavailable |
| Bounded own-base storm | Working shelter/battery requirements; explicit setup cost; science task required; continuous reserves across phases; repeatable pinned event; reserve-spending and extra-storage strategies |
| Science sensitivity | Changed crew demand, crop reference, Moon distance and archived timestamps change the engine's outcomes |
| Hypothesis and revision | Forecasts and reasons cannot change physics; a correct failure forecast is distinct from mission success; misconception feedback and the original prediction survive revision; changed controls and reserve costs are reported |
| Workspace | The desk leaves a clear base preview; equipment has separate Add/Remove targets; switching Equipment/Operating plan preserves the selected setting |
| UI flows | Original mission/relaunch, shadow and storm examples, Accessibility XXXL text, correct failure prediction, misconception feedback, and an unskipped Unsure/Back investigation reach their expected results |

Reproduce in Xcode: open `MoonbaseAcademy.xcodeproj`, choose **MoonbaseAcademy** and the iPad simulator, then **Product → Test** (⌘U). Automated UI tests use their own isolated save. See [reviewer examples](Submission/README.md) for manual steps.

## Device usability

Four refinement flows passed on iPhone 17 Simulator: the shadow experiment, storm experiment, Accessibility XXXL example, and workspace navigation/equipment interaction. [Phone verification](Submission/refinement-phone-test-summary.json). A final focused workspace check passed again after the slightly taller phone desk and visible validation-message fallback were added. The iPad retains its larger preview area.

Normal-text resource planning now uses one bounded desk with Equipment and Operating plan sections. Phase selection shows one stage at a time. Help and previous predictions remain in a separate sheet. The equipment preview is framed more closely, Add/Remove have separate 44-point targets, and fixed Launch remains reachable. Screenshot review checked final iPad equipment/plan views and the phone plan. Large accessibility text retains its scrolling layout. The demo was refreshed from actual captures and remains exactly 29 seconds.

These checks do not establish learning effectiveness. No child participant study, physical-device battery/performance study, complete landscape-device matrix, full VoiceOver/Switch Control pass, or App Store/TestFlight distribution is claimed.

## Scientific provenance

All eight bundled CCMC events were rechecked against the official public HTML on November 15: threshold crossing, peak, end and maximum flux matched for every row. [Result](Submission/ccmc-source-check.json), [recheck script](Submission/check_ccmc.py). BVAD, Veggie, Moon distance and SI constant provenance are documented in [SCIENCE_AND_DATA.md](SCIENCE_AND_DATA.md) and the bundled science package. Source values and training assumptions have separate in-app labels.

## Demonstration

AVFoundation inspection reports exactly **29.000 seconds**, H.264, 1080 × 1920, 30 fps. All six scenes and the final frame were visually checked against the actual results. Captions are burned in and provided as [SRT](Submission/media/captions.srt). There is no voiceover or music. AI-assisted editing is disclosed on every frame and in metadata.

## Submission boundary

The public repository contains source, reproducible examples, screenshots, science explanation, disclosure, captions and the short demo. Saving the Space Apps page is separate from submitting for judging; the website's final submission status is the authoritative confirmation. Participant terms and originality declarations must be accepted by the project owner.
