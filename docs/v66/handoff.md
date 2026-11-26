# 0.66 handoff: Dodong at the gate, the NOW standard, deep mission checks

Owner's asks (2026-11-26): "deep checks and performance improvements ... Try all the missions in Multiplayer 1 by 1 and
see if the right triggers are in the proper places and trigger properly and consistently. I suggest move Dodong Sikma
outside the gate of the player's house at the beginning so he will lead you to his house from there ... Are there any
locations nearby that look empty ... bland and boring ... make sure that the game focuses on the current mission and
will unload the old ones/finished ones ... close the paths to the old maps ... ULTRA SMOOTH FREAKING BLAZING FAST in
all the scenarios. Make sure this mentality is the STANDARD for this game from now on. then go build the APK and EXE,
update the site and make the players update" and "DISABLE the Single Player for now, so the PLAY NOW heads straight to
Multiplayer".

## What changed

| Area | Change | Files |
|---|---|---|
| Single Player off | The home menu's **Play** opens the squad lobby; the separate Multiplayer button is gone (the solo game has no button). The loading screen's "play" wish goes to the lobby too | interior.gd |
| Dodong at the gate | He waits just outside the courtyard gate (`GATE_SPOT`), facing it, and walks the squad home: up the lane, west along the road, over the canal bridge, up the near bank, across the plank bridge, down the far bank and into the warren, then on through it as before. `GATE_WALK` is 22 world points, each leg found on the ground with zombie_nav's search and pulled straight where a body fits (tests/dodong_gate_probe.gd prints them). Outdoors his feet keep to the ground. The warren part's own waypoint numbers (the fallen-roof line, the crouch) count from `warren_at`. HP 135 -> 200 (the walk is ~3x the old one). A tanod's flashlight (SpotLight, no shadow) pointed at the ground ahead: he is seen at the gate in the dark | coop/mission.gd |
| Chapter one sealed | Once every survivor (up or down) is 11 m up Store Road, the Old Salmonan gate rolls shut behind them (host `flags.road_shut`; scrape + lock sound), and on every peer the home, the town, the canal and the warren are put away (`_unload_road`: hidden, processing off, their dead freed, their meshes let go of). Keep: Store Road + the ramp's landing (`ROAD_KEEP_*`) and everything ahead. The pack that follows now comes from the road's near end (it can no longer come through the gate). The siege start shuts it too if someone hung back; debug jumps past the siege settle it | coop/mission.gd, coop/street.gd |
| Far places on PC | The rice fields and the Nichols property are dropped at the squad game's start on PCs too (phones already did). nichols_property `_beams` stops if the property is gone | coop/session.gd, nichols_property.gd |
| Sliced unloads | `_soft_unload(..., sliced = true)` walks the world and lets go of meshes a little each frame (`UNLOAD_BUDGET_MS` 2 ms). Chapter one in one go was a 70 ms frame; now 13 frames. Used for chapter one, out back (`_leave_behind`) and the backstreets at Rommel's gate. Chapter boards still unload in one go behind their screen. `kept` holds sets of boxes now (`_in_keeps`) | coop/mission.gd |
| Bulk spawns spread | `mission.later(job)`: at most 3 a tick (3 ms). Used for a school floor's sleepers, a standing class and its teacher, the backstreets' sleepers, the horde past 501, Heavy-arm's summoned pack and Outer Street's zones. A debug jump `flush_later()`s before clearing behind. A client builds at most 4 new figures per snapshot (`NEW_PER_SNAPSHOT`) | coop/mission.gd, escape.gd, heavyarm.gd, outer_street.gd, session.gd |
| Nav ground premapped | The ground ahead is read into zombie_nav's map before the squad arrives (`map_ahead`, `premap_step`): Store Road in the background during chapter one (0.8 ms a tick), the college, its yard and field behind the mart's chapter board (10 ms a frame, ~155k half cells, ~2.6 s of the board's loading, caption reused). The college's 50-70 ms frames were searches (waypoint links, infected round corners) over ground nobody had walked | coop/mission.gd, coop/session.gd |
| Canal instancing | `InteriorStaticInstancer` (scripts/static_instancer.gd): reeds, ferns, rocks, shrubs, bamboo, snags and cattails of the canal settlement drawn as one instanced draw per mesh per 24 m square (never trees: performance.gd switches their shadows; never anything scripted, physical, animated or lit). From the canal bridge 677 -> 564 draws of the settlement. `-- --no-instancing` for A/B | static_instancer.gd, canal_settlement.gd |
| The standard | AGENTS.md "The NOW standard": seals + unloads for every area, nothing ahead built early, no bulk work in a frame, never by cutting physics/gore/AI, measure with the sweep, run the mission suite | AGENTS.md |
| Version | 0.66.0, Android version code 66 | project.godot, export_presets.cfg |

## Checks

- `python -I tools/run_mission_suite.py` (new): 23 runs, two at a time on their own ports. All pass (work/v66/suite*.txt,
  logs in work/v66/suite/). Test fixes (expectations that predated Outer Street or the spawn queue, none hiding a game
  bug): coop_jumps (Outer Street places check the city chapter and the college unload; underground spots; PILCST-out's
  unload), coop_school (only infected inside Rommel's gate count as "the school's own"; a backstreets straggler can
  follow up the brick alley), coop_escape (waits for the horde's queue; Market Row's posed dead are not the college's),
  coop_integration (the escort loop is long enough for the new walk; flushes the backstreets' queue).
- New: tests/dodong_escort_walk.gd (the walk from the gate: talk, follow, home; `--fight` with live infected and two
  squad AI defending: home at 45/135 HP before the HP raise), tests/road_seal_check.gd (the seal, the unload, the
  solid gate, the pack's side, the closed teleports, the siege still starts).
- Perf: tests/coop_perf_sweep.gd (new; the whole run place by place, rendered, uncapped, with frame anatomy). PC
  Forward+ High 1920x1080 (RTX 4060, Ryzen 7 5700X), before -> after (same machine, separate runs; numbers vary
  run to run, compare within a row):

| Place | fps before -> after | worst frame ms before -> after | draws before -> after |
|---|---|---|---|
| Courtyard (stage 0) | 87.7 -> 107.6 | 20.4 -> 21.3 | 1517 -> 1259 |
| Canal bridge | 82.1 -> 99.5 | 21.5 -> 14.0 | 2361 -> 2105 |
| Warren gate | 112.3 -> 160.8 | 19.4 -> 12.2 | 1170 -> 940 |
| Plank bridge | 115.1 -> 191.4 | 17.2 -> 15.0 | 736 -> 543 |
| Mart siege (stage 5) | 72.2 -> 98.2 (167 in a later run) | 21.3 -> 21.2 | 3389 -> 2758 |
| PILCST floor 2 | 64.6 -> 72.5 | 60.5 -> 25.0 | 1134 -> 1226 |
| PILCST floor 4 | 79.4 -> 92.9 | 65.1 -> 22.8 | 1965 -> 1846 |
| PILCST floor 5 | 65.3 -> 74.5 | 64.3 -> 27.9 | 1856 -> 1770 |

## Review of the ways and the empty places

- Chapter one, flat-lit at eye level (work/v66/views/start/): the lane outside the gate, the road west, the junction
  and the canal-side alleys are dressed (carts, stalls, bunting, pallets, fences, trees, the old orange arrows); no
  empty stretch along Dodong's walk. At night (work/v66/views/ch1/) the bank lane and the warren mouth are very
  dark: that is the night grade; his flashlight now shows the way.
- Overheads of later chapters (tests/overview_map.gd) come out mostly blank: the game's own culling (Outer Street's
  `_view`, the backstreets put away, the unloads) hides what is away from the player. That is the NOW system working;
  eye-level reviews of those chapters were done in 0.63-0.65.
- Not changed: the canal kit's merged batches (189 draws from the bridge), the town's trees (performance.gd's shadow
  switching), Outer Street's crowd frames (~40 ms at the plaza and the boutique on PC), Store Road's 35 ms frame when
  the pack starts.

## Text on screen added in 0.66

- Objective (replaces "Find Dodong on the far bank. Cross the canal bridge and follow the blood arrows."):
  "Dodong is waiting outside the courtyard gate. Speak to him."
- Debug menu jump description: "Dodong outside the courtyard gate, before he speaks".
- No new loading caption (the college's mapping shows "Waking the backstreets and the college").
- Website (not in game): the solo story marked off for now, Play -> Host game, the chapters to the bridge.
- Release notes: tools/release/notes/0.66.0.md.

## Screenshots sent

| When | File |
|---|---|
| Dodong's route overhead, night route, flat-lit start area | work/v66/map/route66b.jpg, work/v66/views/ch1_sheet.jpg, work/v66/views/start_sheet.jpg |

## Phone mode (this PC on the phone renderer: gl_compatibility, --mobile-test, 1600x720, quality 0)

| Place | fps median | 1% low | worst ms | draws |
|---|---|---|---|---|
| Courtyard | 74.2 | 47.4 | 22.4 | 481 |
| Canal bridge | 73.0 | 56.3 | 18.0 | 834 |
| Warren gate | 92.5 | 67.2 | 15.7 | 439 |
| Store Road (just jumped) | 97.4 | 63.9 | 55.8 | 412 |
| Mart siege | 90.8 | 61.8 | 17.5 | 641 |
| Backstreets | 92.2 | 33.7 | 32.1 | 420 |
| PILCST floor 2 | 96.4 | 46.5 | 33.2 | 374 |
| PILCST floor 5 | 70.7 | 42.0 | 29.2 | 524 |
| Nichols Davao Mart | 71.6 | 46.2 | 29.1 | 865 |
| The bridge | 109.5 | 68.9 | 15.7 | 270 |

No physical phone was measured (as in 0.65).

## Builds and publish (2026-11-26)

- Windows: builds/windows/Interior.exe + Interior.pck (1,491 MB), Sleep-0.66.0-windows.zip (1,601 MB), via
  tools/export_windows.py. EXE start-up: menu at 20.6 s (measured while the mission suite ran beside it). EXE captures
  in work/v66/exe/: the home menu (Play / Options / Quit) and a squad game at Dodong's gate with the new objective.
- Android: builds/android/Interior.apk, `--export-debug "Android"`, 824,378,793 bytes, apksigner verifies, signer
  certificate SHA-256 749565e2... (the same as 0.64 and 0.65: installs over them).
- Published (owner's message: "go build the APK and EXE, update the site and make the players update"): PC 0.66.0
  staged, uploaded (14 new chunks, 0.02 GB), activated; release.json reads 0.66.0 with five notes. APK at
  /downloads/Interior.apk (200, full length); downloads/index.json reads game 0.66.0, android 0.66.0. Website
  republished (77 files) with the 0.66 text.
