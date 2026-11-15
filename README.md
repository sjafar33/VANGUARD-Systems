# Moonbase Academy

**VANGUARD Systems · NASA Space Apps Challenge 2026 · Junior Astronaut Mission Trainer**

Moonbase Academy is an offline iPhone and iPad base-building game for children aged 7 to 12. The player owns a small lunar outpost: they place, move, upgrade and decorate buildings on a board, earn Moon coins from short lessons, repair an old landing station, and then **test the base they really built**. In every drill and test they notice a problem, set a plan, predict what will happen, watch the consequences, and improve.

- **Build:** solar arrays, batteries, greenhouse, storm shelter, radio dish, plus decorations (flag, lamp post, rock garden) that are looks only.
- **Learn:** lessons at three question levels (Explorer, Builder, Mission Engineer) with question pools, so replays differ.
- **Test My Base:** a shadow test that counts the player's own working solar arrays and batteries and runs them through the same engine as the Lights Out drill. Colours, levels and decorations change nothing in it.
- **Four reference drills** cover all five challenge topics:

| Drill | Topic | The engineering trade-off |
|---|---|---|
| 1. Lights Out | Power, life support | Solar arrays versus batteries through a six-hour shadow; the oxygen tank can bridge a powered-down air maker |
| 2. The Living Base | Food, life support | Greenhouse light hours versus the air maker versus optional research, on a fixed daily energy budget |
| 3. Storm Drill | Radiation shielding | A shelter costs cargo and 3 kWh to build; its timing replays a real solar particle event from September 2017 |
| 4. Signal Lag | Communication delay | Earth-controlled braking must allow for the 2.56 s picture-and-command round trip; an onboard computer avoids it but takes the camera's cargo space |

Real NASA numbers drive the simulation: crew oxygen and food use (BVAD), the Veggie lettuce growth period, the archived CCMC event timestamps, and the average Earth–Moon distance. See [SCIENCE_AND_DATA.md](SCIENCE_AND_DATA.md) and the in-app **NASA sources** screen.

## Running it

Requirements: Xcode 16 or later (built and tested with Xcode 27.0), iOS/iPadOS 17 or later.

1. Open `MoonbaseAcademy.xcodeproj`.
2. Choose the **MoonbaseAcademy** scheme and an iPhone or iPad simulator.
3. Press ⌘R to play, or ⌘U to run the unit and UI tests.

No signing team is needed for the simulator. To install on a device, select your own team under Signing & Capabilities.

## Project layout

```
MoonbaseAcademy/
  App/             app entry, root view, app model, launch options
  Core/Science/    science package model and content validation
  Core/Simulation/ deterministic resource and rover engines (Foundation only)
  Core/Missions/   mission models, the four drill definitions, child-facing copy
  Core/Progress/   campaign progress and the JSON save store
  Core/Base/       base board rules, coins, guide goals, landing station, Test My Base bridge
  Core/Learn/      lessons, question pools and levels
  Features/        base, mission shell, sources and settings screens
  Rendering/       isometric projection, procedural art, SpriteKit world scene
  DesignSystem/    palette, buttons, meters, formatting
  Resources/Science/science_package.json
MoonbaseAcademyTests/    engine, content, progress, base-builder and base-test unit tests
MoonbaseAcademyUITests/  end-to-end Mission 1 flow with screenshots
```

## Status

See [HANDOFF.md](HANDOFF.md) for exactly what has been built and verified, and what is still to do.

## Credits and licenses

Code: MIT (see [LICENSE](LICENSE)). NASA information is used with attribution and is not covered by the code license. This project is not endorsed by NASA. AI assistance is disclosed in [AI_USE.md](AI_USE.md). Third-party notices: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
