# Interior 0.6: courtyard gate, ghost-town streets, walking, TV and clock (handoff)

Branch: `polish-v0.3`, merged to `main`. Written 2026-10-05. The previous handoff is `docs/v5/handoff.md`.

## Owner request (2026-10-05, summary)

Open the downstairs gate (E only unlocks it; the player must push it open). Let the player walk a mysterious,
almost creepy ghost-town neighbourhood in Davao City with parked Philippine tricycles (downloaded models), empty
street-food stalls, and a "Malasugue Street" sign bent almost to the ground by rust. Slow the footsteps to an adult
stride, bob the view in time with the steps, and play different sounds on different ground. Animate the digital clock
every second with nonsense numbers and symbols. The TV can't be carried, but it can be turned on: after about 2 s it
shows "News Order - Davao City" telling people to stay home and lock their doors, through a realistic TV filter; other
channels are static. Then build the EXE and APK and push everything to main.

Mid-run follow-up from the owner: "send me screenshots for progress".

## What was built

| Part | Where | Notes |
|---|---|---|
| Push gate | `scripts/push_gate.gd` (`InteriorPushGate`), built by `_build_gate()` in `balcony_builder.gd` | Two AnimatableBody3D leaves at x 12.6 hinge on the end posts and meet at z 4.1. It's in `interior_doors`, so the player's door targeting and prompt work unchanged. While locked, pushing rattles it. E unlocks it, and it drifts about 4° ajar. Walking into a leaf (player `wish_velocity` against the leaf normal) swings it outward up to 100°; it has momentum, damping and a creak, and won't swing into the player. The "Gate bound" collider was removed. Keep `sync_to_physics = false`: with it on, the bake reset the leaf transforms to the origin. |
| Walkable streets | `neighborhood_builder.gd`: `NeighbourhoodColliders` body, `solid()`, `_curb_collider()`, `_trunk_collider()`, `_play_bounds()` | Box colliders cover houses, lot walls, closed lot gates, poles and tree trunks. Kerbs are bevelled prisms, so the capsule walks up the 12 cm sidewalks. The play area is `PLAY_AREA` (x -24..26, z -18..55): the street loop A/B/C/D, the lane outside the gate and the back alley. The empty fields and our own house are blocked at street level, below the room floor (y < -0.05). |
| Ghost-town dressing | `scripts/street_dressing.gd` (`InteriorStreetDressing`) | Placed before trees are planted, so trees keep out of each prop's footprint. Every placement is checked against houses, walls, poles and other props, and slides or drops if blocked. It holds parked tricycles (`tricycle_a/b`, `trisikad`), a jeepney, food carts and a stall, oil drums, a tipped monobloc chair, yellow-and-black police barricades where streets leave the play area, about 70 pieces of litter, and the bent Malasugue Street sign at the lane mouth on street B (double-sided; texture `assets/outdoor/street/sign_malasugue.png`). |
| Atmosphere | `neighborhood.gd`, `balcony.gd` | Grey depth fog (3 → 70 m). An overcast sky has no sun disc and a dimmer panorama. The sun is weak and cool (0.85 / 0.6). Colour is drained (saturation 0.68) only while the camera is outdoors. Ambience: gusty wind and a low drone at street level, plus distant metal knocks 18-35 m away. |
| Walking | `player.gd` | Walk 2.45 m/s, run 4.7 m/s. Steps are 1.05 m walking and 1.55 m running (about 2.3 and 3 steps/s). The head bob runs on step phase: lowest at heel strike, one sway per left/right pair, slight roll, fading in and out with speed. Signals `stepped(surface, strength)` and `landed(surface, fall_speed)` fire on the heel strike, so sound and bob line up. |
| Surfaces and footsteps | `scripts/surfaces.gd` (`InteriorSurfaces`), `room_audio.gd` | The surface comes from a collider or CollisionShape3D `surface` meta, then a prop's physics material, then the layout (studio carpet, kitchen and balcony tile, room wood, floor rugs, stair and courtyard concrete, road asphalt, sidewalk concrete, otherwise grass). Samples are Kenney Impact Sounds (CC0) in `assets/audio/footsteps`, played through AudioStreamRandomizer with no repeats. |
| TV | `scripts/television.gd` (`InteriorTelevision`), `scripts/crt_screen.gdshader` | It's attached at runtime to `television_4`, which sets `grab_mode = "none"` and the `interactor` meta. E toggles power. Q or the mouse wheel changes channel; on touch, Throw does when aiming at the TV. Power-on squeezes open from a line, shows 2 s of dark snow, then channel 3 locks onto the News Order broadcast (a SubViewport UI: station bug, LIVE, advisory banner, rotating English / Cebuano messages, ticker, occasional tearing, a quiet 853/960 Hz attention tone). Other channels are static with a CH OSD. The CRT shader adds curvature, RGB fringe, scanlines, aperture mask, flicker, rolling bar, grain and vignette. F still opens the screen-lock puzzle. |
| Glitch clock | `scripts/glitch_clock.gd` (`InteriorGlitchClock`) | A red Label3D over the clock's display window; the modelled digits surface is hidden. Every second it shows a nonsense time (27:84, 9#:61, 46 -4, --:--) and sometimes dims. It's a child of the clock body, so it moves with the clock when carried. |
| Models | `game/assets/models/street/` | `tricycle_a` (CC-BY wawa, "Lowpoly Traysikel/Tricycle"), `tricycle_b` (recolour), `trisikad`, `jeepney`, `food_cart_a/b`, `food_stall_c`, `oil_drum`, `tuktuk` (downloaded but unused: Indian signage). Credits are in `game/licenses/THIRD_PARTY_MODELS.md`. Kenney's CC0 licence is `game/licenses/KENNEY_IMPACT_SOUNDS_LICENSE.txt`. |

## Tests

- `tests/street_integration.gd` (new) covers: a locked gate holds; E unlocks; it stays nearly shut (about 0.06 rad)
  until pushed; walking pushes it open (about 1.74 rad); the route through the lane, street B and street A is walkable;
  cadence is about 2.27 steps/s; footsteps report asphalt, grass and concrete; the play-area edge holds; the TV can't be
  carried, turns on, shows news after the warm-up, is static on CH 4, and shows news again back on CH 3; the clock display exists.
- `balcony_integration` was updated: the hinged entry door is filtered with `is InteriorHingedDoor and not is InteriorSlidingDoor`
  (the slider subclasses the hinged door), and the bottle thrown at the gate may now land in the lane.
- Passing (2026-10-05, final bake): street_integration, balcony_integration, movement_stress, surroundings_integration,
  physics_integration, room_integration, touch_integration (run with `-- --mobile-test`, otherwise it never finishes),
  upgrade_integration, tabletop_stability and hamster_stress. `settling` was not re-run; it failed before this run.

## Builds (2026-10-05)

| File | Size | SHA-256 |
|---|---|---|
| `builds/windows/Interior.exe` (0.6.0, release, embedded PCK) | 553 MB | `5112f0b9a915a66b4428ba352fe8d8489d61d2a74926c4dc1ed8cc1c5559617f` |
| `builds/android/Interior.apk` (0.6.0, code 6, debug-signed) | 502 MB | `266cfb0ed1f25a6565d658b117e38103a16b61a6948b1b12990a8c0dc19b2352` |

The EXE's own `--capture-review --capture-views=balcony` run rendered all six views with no errors
(`work/v6/exe-smoke/`). The APK has not been installed on a phone this run. `builds/` is gitignored.
- Review renders: `godot --path game --script res://tests/v6_views.gd -- --views=tv|street|all --out=<dir>`.

## Known gaps

- Only one Philippine tricycle model was available under CC (wawa's). `tricycle_b` is a recolour of it, and it is
  low-poly and flat-shaded.
- The food stall's awning reads "Elotes y Tamales" and cart A has Chinese lettering. Both were kept away from the gate.
- At ground level, our own house is a solid invisible block from the lane side, and its east facade at x 12.6..13 is
  not modelled in detail.
- On Android (Compatibility), the outdoor sky shows a bright patch overhead and the colour grading is weaker. It
  hasn't been profiled on a phone.
- `tools/build.ps1` still stops at `settling` (a pre-existing failure). Exports run directly.

## Screenshots sent to the owner

| File | What it shows |
|---|---|
| `work/v6/screens/01-tv-clock-first.jpg` | TV off, warming up, News Order broadcast, static on CH 4, and three seconds of the glitching clock |
| `work/v6/screens/03-street-second.jpg` | The gate closed and pushed open, the lane with the cart and drum, Malasugue Street with the tricycle and bent sign, street A in fog |
| `work/v6/screens/04-android-renderer.jpg` | The same TV, clock, gate and streets under the Android Compatibility renderer |
| `work/v6/screens/05-final-exe-and-streets.jpg` | Final pass: the balcony and stair captured from the exported EXE, then the open gate, the lane and both streets |

## How to resume

1. After builder changes, re-bake: `godot --headless --path game --script res://editor/bake_balcony.gd`. It includes
   the neighbourhood and the street dressing. Run `--editor --import --quit` first when new `class_name` scripts or
   assets appear.
2. Add street props in `street_dressing.gd` with `_place(path, at, yaw, scale, slide)`. It refuses footprints on houses or walls.
3. Builds: `.local\tools\Godot_v4.7.2-stable_win64_console.exe --headless --path game --export-release "Windows Desktop" builds\windows\Interior.exe`
   and `--export-debug "Android" builds\android\Interior.apk`.
