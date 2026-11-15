**Moonbase Academy — Space Apps project fields**

Team: VANGUARD Systems. Challenge: Build a Junior Astronaut Mission Trainer.

**Project name**

Moonbase Academy

**High-level summary**

Moonbase Academy is an offline iPhone and iPad game for ages 7–12 where a lunar base becomes a science experiment. Children build a plan, predict an outcome, choose a reason, observe the simulation, and revise one choice using evidence. Beginner controls explain sunlight, battery storage and oxygen reserves. An extra empty battery cannot create energy; reducing air-maker power saves electricity while spending stored oxygen. Results retain the original hypothesis, identify what changed, and suggest another experiment. A storm rehearsal uses the player's shelter and batteries to protect the crew and complete a science task during an archived NASA event. Four reference drills cover power, life support, food, shielding and communication delay. NASA crew-demand references, Veggie information, CCMC timestamps and the Earth–Moon distance drive calculations. Quick example labs need no unlocks and preserve the player's save. The goal is to teach engineering trade-offs through understandable, repeatable investigations.

**Project demonstration**

https://github.com/sjafar33/VANGUARD-Systems/blob/main/Submission/media/moonbase-academy-demo.mp4

**Final project**

https://github.com/sjafar33/VANGUARD-Systems

**Detailed project description**

A base builder that becomes an engineering experiment

Moonbase Academy turns the question “Would your base keep working?” into a repeatable experiment for children aged 7–12. The player places and upgrades buildings, sets an operating plan, predicts what will happen, chooses a reason, watches a deterministic simulation, and revises one choice using evidence from the actual result.

One concrete lesson

A starter base has one solar array and one battery. With the air maker at Full, sunlight stores 2.4 kWh, while the six-hour shadow needs 3.6 kWh. The test stops at mission hour 10. Adding another empty battery still fails: storage does not create energy. Adding a solar array completes the twelve-hour test. Alternatively, using Half air during shadow saves 1.5 kWh while withdrawing 0.1975 kg from the oxygen reserve. These are different engineering choices with visible costs, calculated from NASA adult crew demand and clearly labeled training equipment assumptions.

Protection and scientific work compete for resources

The own-base Storm test uses working shelter and battery buildings and a pinned September 10, 2017 archived particle event lasting 98 hours 5 minutes. The crew must remain sheltered, retain at least 24 hours of oxygen, and supply 0.5 kWh to a science task. Skipping science keeps the crew supplied but leaves the task unfinished. Half air while early science runs, followed by Full air with science Off, succeeds while spending oxygen. More storage provides another strategy. Preparation costs and backup supply are explicit game rules. The event timestamps are measurements near Earth; the game does not calculate radiation dose on the Moon.

Built for exploration and review

Numbered planning cards explain sunlight and shadow, Off/Half/Full air-maker settings, and the purpose and power cost of science. Replayable help introduces generation, storage and oxygen reserves. Predictions include a reason and a separate Start test action. Results distinguish forecast accuracy, the proposed mechanism, and mission success; a correct forecast of failure does not complete the mission. The next experiment highlights a relevant control.

Drills → Start example lab and Start storm example provide ready-to-use equipment snapshots without grinding coins or unlocking buildings. Equipment choices preserve air/science settings; resetting the lab is explicit. Comparisons identify one or multiple changes and preserve the original forecast and reason. Examples use the same engine and never write campaign progress, rewards, drafts, or playback preferences. Results compare equipment, plan, actual stopping time, energy and oxygen. They do not treat an early failure's reserves as if the full mission had elapsed. Four separate reference drills cover power/life support, a 33-day crop-lighting budget, sheltering during archived storms, and a rover's Earth–Moon picture-and-command delay. Lessons offer three question levels. Optional read-aloud, reduced motion, and large-text layouts support different ways of playing.

Traceable science and honest scope

NASA BVAD oxygen and dry-food references set adult crew consumption; NASA Veggie information sets garden power and a crop reference period; CCMC timestamps set storm phases; NASA's average Earth–Moon distance and the SI speed of light set radio delay. Equipment capacities and level multipliers are authored game rules. Historical records are embedded and labeled archived. There are no live-feed claims. Lettuce is a fresh extra, not a replacement for packed meals. Water, CO2, temperature, full nutrition, radiation transport and realistic rover braking are outside this prototype.

Implementation and validation

The application uses Swift, SwiftUI, SpriteKit, Core Graphics, Foundation and XCTest. The resource engine is deterministic and independent of animation timing. Save migration preserves older records. Engine tests cover boundary failures, source sensitivity, equipment upgrades, the storm task, event timing, and example-save isolation. End-to-end simulator flows exercise a failed attempt, a reasoned revision, success and persisted progress. iPhone, iPad and very large text have been exercised. Full validation and reproducible examples are linked in the public repository. These are technical and usability checks; no child learning-effectiveness study is claimed.

Intended impact

A teacher can ask learners to predict which equipment fixes a failure, change one thing at a time, and explain the result using the trace. The app works offline without accounts, ads, analytics or a backend. The prototype demonstrates a small engineering learning loop; broader classroom evaluation and browser access are future work. NASA does not endorse this project.

**SI disclosure**

AI coding tools (Claude Code and Codex) assisted implementation, tests, debugging, procedural artwork code, documentation, and caption/video assembly, working from the team's design brief. References and software were checked through documented source checks, builds and tests. NASA values were transcribed and checked with AI assistance; their provenance and limits are documented. App visuals and audio are synthesized by project code; no image, video, or voice generation model supplied in-game assets. The demonstration edits actual simulator captures and carries a visible AI-assisted-editing disclosure. The app itself has no runtime AI feature, network service, account, or analytics. Git authorship and repository contribution attribution remain with the project owner.

**NASA data**

- [NASA Life Support Baseline Values and Assumptions (BVAD), Table 3-31](https://ntrs.nasa.gov/citations/20210024855)
- [NASA Veggie fact sheet — growth period and operating power](https://science.nasa.gov/wp-content/uploads/2023/04/veggie_fact_sheet_508.pdf)
- [NASA CCMC SEP archive — observed event timestamps](https://ccmc.gsfc.nasa.gov/challenges/sep/events/)
- [NASA Moon Facts — average Earth–Moon distance](https://science.nasa.gov/moon/facts/)

**Partner and other resources**

- [BIPM SI Brochure — defined speed of light](https://www.bipm.org/en/publications/si-brochure)
- [Apple developer frameworks — SwiftUI, SpriteKit, Core Graphics and XCTest](https://developer.apple.com/documentation/)
- [AI assistance, original procedural art/audio and tool disclosure](https://github.com/sjafar33/VANGUARD-Systems/blob/main/AI_USE.md)
- [Project source code and MIT license](https://github.com/sjafar33/VANGUARD-Systems/blob/main/LICENSE)

The official website still requires the team owner to accept its terms and originality confirmation before submission. Saving progress alone does not submit for judging.
