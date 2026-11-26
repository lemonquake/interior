# Interior 0.9: the man in the black hoodie (handoff)

Branch: `main`, uncommitted. Written 2026-10-05. The previous handoff is `docs/v8/handoff.md`.

## Owner request (2026-10-05, summary)

Use the base body in `models/generic_body*` for the game's humans, rigged with plenty of animations. For this
part of the game: a casually dressed man (black hoodie, generic black hair) stands at the courtyard gate holding it
with his arms spread wide, breathing in place (owner's picture 1, the view down the stair). As soon as the player
sees him he runs off to the right and waits near the dirt road (picture 2, by the utility pole at the north end of
street B). As soon as the player passes the food cart on the corner of streets A and B (picture 3), he runs away
down the middle of the dirt road. Mid-run: "give me screenshots as you go".

Interpretation: "holding the gate wide" was built as gripping the closed gate's bars with both arms spread (the
gate stays closed and locked, so the unlock / push-open puzzle is unchanged). If the owner meant holding the leaves
open, the gate would have to start open; see "How to resume".

## What was built

| Part | Where | Notes |
|---|---|---|
| Rigged body | `models/generic_body_rigged.glb` | generic_body.obj skinned to a 24-bone humanoid skeleton with 132 clips, made by the owner's Beyond Heroes hero pipeline (`A:\Python\beyond-heroes\tools\blender\hero\hero_body.py -- export`, the same OBJ, byte-identical). Copied in as the source; hair models in `models/generic_body_hair/`. |
| Human builder | `tools/blender/human/build_human.py` | Blender 5.2: `-- hair` (hair candidates), `-- preview` (renders to `work/v9/human/`), `-- export` (`game/assets/characters/stranger.glb`, ~1.6 MB). Clothes are offset shells of the body, so they share its skin weights exactly: hoodie (loose body, ribbed cuffs/hem/collar, hood down on the back, kangaroo pocket, white drawstrings), dark straight jeans, dark sneakers with pale soles, side-part black hair. Covered skin is deleted. One skinned mesh, 8 materials, 9.5k vertices. |
| Clips | same | 34 civilian clips from the library (idle, idle_look, walk, run, run_start/stop, turns, strafe, hits, staggers, knockdown, getup, deaths, pickup, talk, the five retargeted source clips) plus two new 4 s loops baked with IK: `gate_grip` (wrists pinned 0.32 m ahead at chest height, elbows down and out, leaning in, heavy breathing, looking up at the house, head tilted) and `stand_stare` (still, breathing, head tilted). IK pole angles: left 180, right 0 (mirrored rolls). |
| Behaviour | `game/scripts/stranger.gd` (`InteriorStranger`), spawned in `interior.gd` (`--no-stranger` skips him) | States AT_GATE, SPOTTED, TO_ROAD, WAITING, FLEEING, GONE. "Seen" = chest or head in the camera frustum, within the central 80 % of the frame, within 48 m, and a clear ray from the camera (stopped 0.75 m short so the gate he holds doesn't block it), for 0.25 s; also if the player comes within 5 m. Then the gate clanks (`InteriorPushGate.rattle_from_outside()`), he turns and runs at 5.7 m/s (player 4.7) along the lane and street B to `WAIT_SPOT` (19.05, 45.1) by utility pole 9, turning to face the player. Past the corner cart (player z > 17.6, x > 9) or within 20 m, he runs through the barricade gap and down the dirt road's centre line (`Fields` meta `road_samples`), and is freed once 120 m away or 230 m down the road and out of view. Run clip speed-matched (5.0 m/s clip), 3D footsteps on the Night bus (concrete in town, grass on the road), ground height by ray. No collider. Pausable; Restart replays it. |
| Rendering | same | Meshes on the outdoor layer (2) so the moon and street lamps light him, room lights don't. |

## Tests

- New `tests/stranger_integration.gd` (headless, `--fixed-fps 60`): 22/22. Covers start state and loops, outdoor layer,
  8 surfaces, 36 clips; not set off from the room or from the stair looking at the house; set off 25 frames after
  looking at the gate; pause holds him; the whole route (lane, street B, barricade gap, first 60 m of the road) is
  clear of every street collider for a 0.25 m capsule; waits within 0.6 m of pole 9, faces the player, stays while the
  player is short of the cart; runs once past it, stays within 0.01 m of the road centre line, reaches z 138, freed.
  The capsule sweep caught the first route running through the oil drum, the bent sign and the parked tricycle.
- Regression with the stranger present: `street_integration` 27/27, `fields_integration` 25/25, `room_integration`
  89/89, `balcony_integration` 63/63. One earlier balcony run failed "Max throw at the railing stays on the
  balcony" (the bottle cleared the rail); three reruns, with and without `--no-stranger`, all passed and the bottle
  landed in a different place each time, so that check is flaky, not caused by the stranger (he has no collider).
- Review renders: `godot --path game --script res://tests/stranger_views.gd -- --out=<dir>` (windowed) plays the
  sequence with stills at the gate, the picture-1 and picture-2 viewpoints, the bolt, the wait and the road.

## Screenshots sent to the owner

| File | What it shows |
|---|---|
| `work/v9/probe/sheet1.jpg` | Locating picture 2 (street B, pole 9) and picture 3 (food_cart_a on the A/B corner) in-engine |
| `work/v9/human/hair_sheet.jpg` | Hair candidates fitted on the generic_body head |
| `work/v9/human/01-stranger-model.jpg` | The dressed man in Blender, gate_grip, stand_stare and run |
| `work/v9/screens/02-stranger-sequence.jpg` | In-game: at the gate, picture-1 view, the bolt, waiting at the picture-2 spot, the dirt road |
| `work/v9/exe-smoke/gate_crop.png` | The rebuilt 0.9.0 EXE: the stranger at the gate from the stair |

## Build (2026-10-05)

| File | Size | SHA-256 |
|---|---|---|
| `builds/windows/Interior.exe` (0.9.0, release, embedded PCK) | 602 MB | `fce272113af870d752f94eee2c89b3163149e149efd097ae603b75ddab9bdf8f` |

`export_presets.cfg` is 0.9.0 (Android code 9). The EXE's own `-- --capture-review --capture-views=balcony` run
rendered all six views; `balcony-5-stairs-down` shows the stranger at the gate (`work/v9/exe-smoke/gate_crop.png`).

## Known gaps

- No APK was built this run. (The owner first ran the old 0.8 EXE and saw no stranger: the EXE must be re-exported after changes.)
- Fists rather than wrapped fingers on the bars (the body's hands are modelled as fists); reads fine at gate distance.
- He has no collider and doesn't avoid the player; he never comes near them by design.
- The hair is the Beyond Heroes "sidepart" shell (no strands); at night it reads as short black hair.

## How to resume

1. Change clothes or clips in `build_human.py`, then `blender -b --factory-startup --python tools/blender/human/build_human.py -- preview export`
   and `godot --headless --path game --import`.
2. More people: call the same builder with other outfits (the shell functions take any body region); the rigged body
   and clip library are shared.
3. Spots, routes and triggers are constants at the top of `stranger.gd`; rerun `stranger_integration` after moving any
   route point (it sweeps the route against the street colliders).
4. Holding the gate open instead: snap the leaves open at start (`snap_open()`), move `GATE_SPOT` into the gateway and
   re-aim `GRIP_L/R` in the builder at the leaves' free ends.
