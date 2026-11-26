# Sleep 0.26 — body camera, a closed world, frame rate

Owner request (2026-11-09): copy the reference video in `Reference/` (a body-camera horror shooter) for movement,
weapon handling, aim and atmosphere; fix the map (holes, unwanted paths, blocked paths, the house with no outside);
make the game fast (100-200 FPS everywhere); cut head bob by more than half, with lower and off in the options.

The work ran over three sessions. The first stopped at the usage limit while scanning for holes; the second picked up
from its transcript and stopped before the checks and the export; the third (2026-11-10) ran the checks, fixed what
they showed, exported and captured the build. The Windows build at `builds/windows/Interior.exe` is 0.26.0
(1,180,918,056 bytes, SHA-256 `d7cf2cc756a06d6272ee3f6964c764433cd4df1a5905d2ea24ad12e5133d06fe`, exported directly
because `tools/build.ps1` still stops at `settling`). `builds/windows/README.txt` and `builds/SHA256SUMS.txt` are
updated; `builds/Interior-Windows-x64.zip` was not made. **The Android APK was not rebuilt.**

## What changed

### Body camera (reference video)
- `scripts/bodycam.gd` + `scripts/bodycam_lens.gdshader`: one pass over the finished frame, under the HUD text: barrel
  distortion with the image circle's dark corners and warm rim, colour fringing toward the edges, grain, a smear on
  fast turns, a white-out and gain dip on a shot, a softer glare when the torch comes on. The field of view is 92
  degrees with the lens (78 without). Options: **Lens: Body camera / Clean**.
- **Low-light gain** (second session): outside the lit rooms of the house the sensor turns its gain up. Dark pixels are
  lifted on a curve and tinted cold, and the grain roughly doubles; bright pixels are untouched. It halves while the
  torch is on and dips after a shot. The night road went from near-black to a readable, noisy blue
  (`work/v26/progress/06a-before-low-light.png` -> `06-low-light-bodycam.png`).
- `scripts/player.gd`: the lens leans into turns and sidesteps, has a hand-held tremor that grows with speed, and
  jolts on a shot or a hard landing. Acceleration is a little heavier (9.4 / 11.5 m/s2, was 10.5 / 13.5).
- `scripts/gun.gd`: the pistol is held in both hands low in the frame; the muzzle moves first and the view follows
  (free aim); the right mouse button raises the sights to the lens and slows the walk; the crosshair is a faint mark
  that goes away while the pistol is up.
- **Head bob** is 55 % lower by default (.0153 / .0099 / .005, was .034 / .022 / .011). Options: **Head bob: Default /
  Low (another 25 % less) / Off**.

### The player's house
- `scripts/home_exterior.gd`, `scripts/home_door.gd`: the furnished rooms used to hang 2.9 m over an empty lot. They
  now sit in a two-storey yellow hollow-block house with a splash band, maroon louvre windows with grilles, a
  corrugated roof, a lean-to wing, an air-conditioner, a water tank, a meter and mast, a boarded back door and a street
  door that is bolted from inside (trying it rattles the bolt). The ground storey collides.

### A closed world
`scripts/map_seals.gd` (runtime child of the neighbourhood; `-- --no-seals` leaves it out):

| What | Where | How it was closed |
| --- | --- | --- |
| 18 dead-end slits between lot walls and behind street B | town block | a leaned sheet of roofing iron wedged across each mouth |
| Open band round the outside of the Nichols fence | x -47..26, z -60 | the front fence line carried on to the boundary both sides |
| Canal district, east lip (0.8 m step down into a strip behind the town's west lots that ran from the Nichols side to the dike) | x -37, z -17.7..71 | sheet fence along the lane's edge, open only where street A comes in; the strip plugged at four places |
| Canal district, north-east and north-west corners and west side | z 71, x -121..-95 and -45..-37; x -120..-121.5, z 59..71 | sheet fence following the ground's edge |
| Sliver behind the warren's back wall, open to the edge of the ground | x -120..-117.6, z 59.6 | sheet fence across its mouth |
| Dike north of the canal district (reachable, every edge open air) | z 72..82, x -122..-15 | no longer reachable (the fences above and the one below) |
| Gap where the block wall stops beside the start of the rice-field road | x 17.3, z 62.6..74.5 | sheet fence up to the road's own side wall |
| One-way drop into the warren's drain from outside its north wall | x -104.5, z 57..59 | short fence |
| Missing segment of the scarecrow islet's rim (one step off it fell through the paddy for ever) | 28.39, 180.79 | unseen collider like its neighbours |

Before: 537 edges where a body could step off into nothing, 368 cells of ground reachable only by falling.
After: 0 and 0, with every key place still reached (`work/v26/progress/04-reach-before.png`, `05-reach-after.png`).

Also in the second session:
- **Lip climbing** (`InteriorPlayer._climb_lip`, 0.16 m): the 7 cm edge where the balcony stair meets its landing could
  stop the player for good when they arrived without momentum (the way back into the house), and the same happened at
  the foot of the warren's bank steps on the canal's far-bank path. A blocked step is now retried from 0.16 m higher
  and settled onto fixed floor; never onto loose props, never off an edge. The eye catches up over a few frames.
- The basement's machete sprang off the work bench at start-up (it was placed through the vice); it now lies on the
  back of the bench.

### Frame rate
`scripts/performance.gd` (desktop; `-- --no-perf` switches it off): visibility ranges for every prop from its size,
lighter trees that only cast moon shadows near the camera on High / Ultra, lights and decals that fade with distance,
whole zones hidden when the camera is far from them (the home, the town from far up the field road, everything above
ground from the cellar), a 3D resolution that follows the frame time, and a frame cap. Sleeping props no longer tick.
Options: **Frame rate: 200 / 144 / 120 / 60 / V-Sync** and **Keep the frame rate: On / Off**.

Measured in the project (not the EXE) at 1280x720, uncapped, RTX 4060, `--performance-audit --audit-quality=N`:

| View | Low (0) | High (2) | Ultra (3) |
| --- | ---: | ---: | ---: |
| Room | 426 FPS | 323 | 123 |
| Street | 476 | 272 | 117 |
| Town | 362 | 226 | 108 |
| Canal | 462 | 196 | 108 |
| Warren | 450 | 330 | 151 |
| Fields | 517 | 426 | 170 |
| Nichols | 514 | 317 | 128 |
| Basement | 828 | 410 | 158 |

Medians. 99th-percentile frames were 9-14 ms on Low and High and 17-23 ms on Ultra. Before this run the first session
measured 120-270 FPS typical with dips to about 70 and up to 17 million triangles on screen in town; the living room
went from 3,648 draw calls to 705.

## Not done, or not verified
- **Low-end PCs**: only an RTX 4060 was available. The "100-200 FPS on a low-end PC" rule is not verified on such a
  machine. Low plus "Keep the frame rate" is the path meant for it.
- **Blocked paths that should have an entrance**: none was opened. The audit found no place that looks like a way in
  and is shut by accident; the shut things it knows of are deliberate (the bolted street door of the house, the locked
  closet, the chained iron door at the end of the tunnel, the sealed rear rooms upstairs in the mansion, locked doors
  in the town and the warren). The owner was asked which ones they meant.
- **Map and texture overhaul**: beyond the house exterior, the seals and the lens, the districts' geometry and
  textures are as they were in 0.25.
- **Android**: `builds/android/Interior.apk` is still 0.25.
- The one-way drops that remain (32 cell edges) are the unrailed bank tops over the canal's catwalk and river. They
  land on ground the player can walk out of.
- The audit's 0.75 m grid cannot enter doorways narrower than about 1 m by itself; the warren's two tin doors and the
  Nichols porch are seeded by hand (`PORTALS` in `tests/world_audit.gd`). The warren's boardwalks are still not walked
  by the audit (its own test, `warren_integration`, walks them with the real player).

## Checks

Run on 2026-11-10 against the scripts that are in the build, each as
`Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path game --script res://tests/<name>.gd`
(`touch_integration` and `mobile_budget_integration` with `-- --mobile-test`).

| Check | Test | Result |
| --- | --- | --- |
| Closed world (new) | `seals_integration` | 30 / 30 passed: 0 step-off edges, 0 fall-only cells, 32 one-way drops (the canal's bank tops) |
| Walled town, hooded man, hut story | `siege_integration`, `stranger_integration`, `hut_story_integration` | 35 / 35, 42 / 42, 75 / 75 passed |
| Debug menu | `debug_menu_integration` | 39 / 39 passed. It first showed two "Trying to cast a freed object" errors from `performance.gd` when the quality changed after a prop had been freed; fixed (the entry is checked before the cast), 0 errors after |
| Nichols, basement | `nichols_integration`, `basement_integration` | 50 / 50, 57 / 57 passed |
| Fields, street, balcony | `fields_integration`, `street_integration`, `balcony_integration` | 25 / 25, 27 / 27, 63 / 63 passed |
| Canal, warren | `canal_integration`, `warren_integration` | 57 / 57, 87 / 87 passed |
| Gun, touch | `gun_integration`, `touch_integration` | 41 / 41, 33 / 33 passed |
| Room, interactions, night, decay | `room_integration`, `neighborhood_interactions`, `night_revision_integration`, `neighborhood_decay_integration` | 271, 29, 28, 32 checks, all passed (decay was 30 / 32 in 0.23) |
| Movement, physics, table tops, hamsters | `movement_stress`, `physics_integration`, `tabletop_stability`, `hamster_stress` | all passed |
| Surroundings, upgrade, mobile budget | `surroundings_integration`, `upgrade_integration`, `mobile_budget_integration` | 29, 839, 3,119 checks, all passed |
| Atmosphere, horror props, particles | `atmosphere_integration`, `horror_props_integration`, `particles_integration` | 15, 504, 27 checks, all passed |
| Prop settling | `settling` | **Fails, as it has since 0.3.** 101 props move more than 3 mm at start-up (worst: "Plastic pail3", 861 mm) and 13 after a wake-all (worst: a sofa cushion, 233.6 mm, the same figure as in 0.15). The numbers are identical with `-- --no-seals --no-perf`, so 0.26 did not cause or change it |
| The EXE itself | `Interior.exe -- --capture-review --capture-views=gun --capture-path=<dir>` | Version resource 0.26.0; 17 frames written, with the lens, the two-hand pistol, the sights, the low-light road and the house from the courtyard and the lane (`work/v26/exe-capture/`, sheet `work/v26/progress/07-exe-capture.png`) |

The gun capture now ends with two frames of the player's house from outside (`gun-17-house-courtyard`,
`gun-18-house-lane`); the hooded man is put away before them, because seeing him at the gate starts his film.

## Tools added
- `tests/world_audit.gd -- --voids --cells --region=-130,-136,230,700 --out=<dir>`: step-off edges, one-way drops,
  fall-only ground, and a cell dump for drawing maps. The fill now also tests the way between neighbouring cells.
- `tests/seals_integration.gd`: the whole-world check above as a pass / fail test.
- `tests/spot_review.gd -- --out=<dir> --probe=x0,z0,x1,z1,count,top --shots=name:x,y,z:lx,ly,lz;...`: what is under a
  line of points, and work-light renders from anywhere.
- `tests/home_review.gd`, `tests/perf_inventory.gd`, `tests/perf_physics.gd`, `tests/perf_movers.gd` (first session).

## Progress renders
`work/v26/progress/`: `00-before-gun.png`, `01-house-exterior.png`, `02-bodycam-road.png`, `03-edge-fences.png`,
`04-reach-before.png`, `05-reach-after.png`, `06a-before-low-light.png`, `06-low-light-bodycam.png`, `07-exe-capture.png`.
