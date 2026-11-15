# Science and data

Moonbase Academy uses a small, bundled extract of NASA reference information. Nothing is fetched while the game runs, and no number is labeled live.

The authoritative file is `MoonbaseAcademy/Resources/Science/science_package.json`. `validateContent(package:)` checks it at launch. If a required value is missing, has the wrong unit, is not a positive finite number, names an unknown source or has no verification record, the app shows a content error screen instead of playing with made-up numbers.

## Evidence categories

Every quantity is exactly one of:

| Category | Meaning |
|---|---|
| NASA reference | A value or observation taken from an identified official NASA source |
| Derived | Calculated from reference values with a documented formula |
| Training assumption | A fictional capacity, rate or control choice made for this game |
| Physical constant | The SI speed of light. Added as a fourth label so it is not mislabeled as a NASA value |

## NASA references (verified 2026-11-14)

| ID | Value used | Source and locator | How it changes outcomes |
|---|---|---|---|
| N1 | 0.895 kg O₂ per adult crew member per day; 0.800 kg dry food per crew member per day | Life Support Baseline Values and Assumptions Document, NASA/TP-2015-218570/REV2 (Feb 2022), NTRS 20210024855, Table 3-31 "Summary of Nominal Human Metabolic Interface Values" | Oxygen and food use scale with crew count and simulated time in every resource drill |
| N2 | 33 days of VEG-01 lettuce growth; about 70 W operating power | NASA Veggie fact sheet: VEG-01 A (May 8 to June 10, 2014) and VEG-01 B (July 8 to Aug 10, 2015); "The System" section | Garden drill length and harvest threshold; garden lighting power |
| N3 | 2017-09-10 16:45 UTC threshold crossing, 2017-09-11 11:45 UTC peak (1493.5 pfu), 2017-09-14 18:50 UTC end | NASA CCMC SEP Scoreboard archived events table, GOES-13, >10 MeV, 10 pfu threshold, 0.85×10 pfu end criterion | Storm drill phase durations: 19 h rising, 79 h 5 min fading, 98 h 5 min total |
| N4 | 384,400 km average Earth–Moon distance | NASA Moon Facts, "Size and Distance" | Radio delay: 1.28222 s one way, 2.56444 s picture plus command |

Verification method: each official page or PDF was retrieved by an automated fetch on 2026-11-14 and the values were read from the extracted text, then transcribed by hand into the JSON. No raw snapshots are bundled, so no digests are recorded. The BVAD text extraction placed Table 3-31 on report page 59, while the table of contents lists page 58; the values themselves matched the brief. The CCMC table links to a raw GOES-13 JSON file that was **not** downloaded or parsed.

## Derived values

- Storm phases: differences between the N3 UTC timestamps (`ScienceInputs.stormRisingHours`, `stormDecliningHours`). The table's 98.08 h is rounded; the game uses the exact 98 h 5 min.
- Radio delay: `moonDistanceKm / lightSpeedKmPerSecond`. The rover's command loop is exactly two one-way trips: one picture to Earth, one command back.
- Garden horizon: the N2 33-day reference split into three 11-day planning blocks.

## Training assumptions

Two adult crew; full air maker 2.0 kg O₂/day at 0.5 kW (linear at 0, ½, 1); 0.1 kW essential load; oxygen tank 7.16 kg starting at 3.58 kg; solar array 1 kW in sunlight; battery 4 kWh; garden 16 h light for full growth and 0.01 kW standby; 17 kWh/day for the garden drill; 0.8 kW for the storm drill; shelter assembly 3 kWh; rover 1 m/s with instant braking; 5–6 m target bay; all cargo point costs. These are game design choices, not spacecraft specifications.

## Not modeled

Radiation dose (the storm drill uses a simple shelter rule and never computes mSv), CO₂, water, thermal control, full nutrition, equipment failures, the real ~two-week lunar night, rover braking and terrain, link scheduling, and the changing Earth–Moon distance. Generation and demand are uniform within each drill step (a phase-averaged training model).

## Sensitivity tests

The test suite proves the data is functional, not decorative. Using test-only copies of the inputs:

- Raising oxygen use to 1.2 kg/day makes the successful reserve-spending storm plan fail.
- Raising the crop reference to 35 days removes the harvest from the 33-day full-light drill.
- Doubling the Moon distance makes the marker-3 rover plan overshoot.
- Moving the archived storm end by 10 hours changes the phase duration and food use.

Production data is never modified by tests.

## Test My Base (added 2026-11-14)

"Test My Base" is a separate scenario from the Lights Out reference drill. It runs the same deterministic `ResourceEngine` with the same NASA input (oxygen per crew member per day, source N1) and the same training assumptions as the six-hour Lights Out drill. The only difference is where the equipment comes from: instead of choosing cargo for a lander, the test counts the working solar arrays and batteries on the player's own base when the test opens.

Game rules (not NASA data), shown to the player on the result card:
- Each working solar array counts as one Lights Out array (1 kW in sunlight). Each working battery counts as one Lights Out battery (4 kWh, starts empty). At most four of each.
- Array and battery levels scale power and capacity: level 1 = 1×, level 2 = 1.5×, level 3 = 2× (game rules, not NASA hardware figures). Other building levels, colour, position and the robot buddy do not change any number. A damaged building counts for nothing.
- The landing station is fictional. Repairing it costs Moon coins and only opens the test. It adds no power, oxygen, supplies or communication.
- Coins (repair price, the one-time reward for a first pass) never enter the simulation.

Limits: this is still a phase-averaged training model, not an electrical simulator. Board distance and layout are not modelled, so no cables or adjacency are implied. The reference drills, their harder versions and their test fixtures are unchanged.

## Upgrades in Test My Base (added 2026-11-14, evening)

Game rule, shown on the building panel and on the test result: a level 1 solar array or battery is exactly the Lights Out equipment (1 kW in sunlight, 4 kWh). Level 2 counts 1.5 times and level 3 counts 2 times. The engine receives the base's arrays and batteries as that many items of their average strength, so the totals are exact. Levels of other buildings, colours and decorations change nothing. These multipliers are invented for play; they are not NASA hardware figures.

## Eight real archived storms (added 2026-11-14, evening)

The Storm Drill's timing comes from NASA's CCMC SEP Scoreboard archive (source N3): GOES-13, protons above 10 MeV, the 10 pfu threshold crossing, the peak, and the archive's 0.85 x 10 pfu end. The first play always uses the event of 2017-09-10. Once the drill is finished, each replay picks one of eight archived events at random (2012-03-07, 2012-05-17, 2012-07-12, 2013-04-11, 2014-01-06, 2014-01-07, 2017-07-14, 2017-09-10), named on screen with its real date. They last from about 27 hours to about 138 hours, so a plan that works for a short storm (air maker on Half) fails for a long one. All are replayed archive data and are never presented as live.

How the seven added rows were entered: read from the official archive page by an automated fetch and entered by an AI assistant on 2026-11-14. Two checks were made: the same fetch returned the 2017-09-10 row identical to the record transcribed by hand earlier, and for five of the seven rows the duration derived from the timestamps equals the table's own duration column (the other two differ by less than 0.3 hours). **A team member should still re-read the seven rows against the source page before submission.**

Limits that still apply: these are particle measurements by a satellite near Earth. They are not a radiation dose on the Moon, and the game does not calculate a dose. The shelter rule is a simple training rule. DONKI itself is not used: it could not be reached from the build environment, so the game makes no DONKI claim.

## Experiment comparison and example lab (November 15)

Results record elapsed and planned hours separately. A failed run stops at its actual failure time; its remaining oxygen must not be treated as a full-mission reserve. Saved records from older versions still load with timing marked unavailable.

Reserve expenditure sums net oxygen withdrawn during each simulated step. Energy saved compares the air maker with Full over the same elapsed time, using the authored generator-power assumption. For one array and one battery, Full air fails at hour 10; Half air in the six-hour shadow completes hour 12, saving 1.5 kWh and spending 0.1975 kg from the oxygen tank during the shadow. These are outputs of NASA crew demand plus the training assumptions, not hardware specifications.

The Example lab provides fixed equipment snapshots (1 array/1 battery, 1 array/2 batteries, 2 arrays/1 battery). Selecting equipment restores the default Full-air plan and the same initial resources. Example results remain in memory only; they do not award coins, unlock missions, replace the base, clear an existing draft, or save playback preferences.

## Own-base storm rehearsal (November 15)

This is a separate definition, `stormDrill.myBaseStorm`, using the same resource engine. The landing station's Storm test uses the player's working shelter and batteries. It replays the pinned September 10, 2017 archived event, including both timestamp-derived phases; retries keep that event. Storm records include kind, event identity, actual stopping time, reserve expenditure, and science energy. They are never compared with shadow records or other events.

Authored game rules: batteries start fully charged, level multipliers remain 1 / 1.5 / 2, and preparing the already-built shelter uses 3 kWh. This represents fictional emergency preparation, not powered radiation shielding. An independent training backup supplies 0.8 kW; the player's arrays do not generate power in this rehearsal. The training station supplies the science instrument. Success requires shelter throughout, at least 24 hours of stored oxygen remaining, and 0.5 kWh supplied to the science task. NASA does not prescribe these equipment or objective values.

The crew-safe/science-off plan does not complete the task. With one level-1 battery, Full air plus science during the rising phase runs out of power at hour 10. Half air plus science during rising, followed by Full air and science Off during fading, succeeds while spending oxygen reserves. A second battery permits the early science task at Full air. Engine checks cover both strategies, missing shelter, boundary continuity without resource refills, deterministic retry, all eight archived timings, and saved-record isolation. The quick Storm example uses the same rules without modifying the player's base or save.

No dose, shielding attenuation, individual health risk, or lunar radiation measurement is calculated. The near-Earth event timestamps supply a replay clock, not a prediction of dose on the Moon. The original Storm Drill retains its original optional-science objective.
