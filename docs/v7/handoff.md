# Interior 0.7: night, the moonlit rice fields, night sounds and hold-E pulling (handoff)

Branch: `main`. Written 2026-10-05. The previous handoff is `docs/v6/handoff.md`.

## Owner request (2026-10-05, summary)

Let the player pull objects, doors and gates by holding E. Make the game night. Outside, footsteps should echo, wind
should blow now and then, with distant crickets, toads and an owl in 3D: overall night vibes. Somewhere there is a very
long dirt road through rice fields and other plants, a beautiful landscape with real rendered water that shines and
sparkles in the moonlight; the full moon and small stars are visible, and the moon reflects in the paddies and a pond as
you pass. The dirt road ends for now. Make the fields as atmospheric as possible, creepy and majestic at once. Download free
3D assets and a particle or water system. Push to main, build the EXE and APK.

Mid-run messages from the owner: "send me pictures as you go", and (with a screenshot of the white cycle rickshaw)
"completely remove this model, it doesnt belong in my game".

## What was built

| Part | Where | Notes |
|---|---|---|
| Night | `scripts/night.gd` (`InteriorNight`) | One place for the moon (20 degrees up toward -X/+Z, over the rooftops across street A and ahead of the player on the road), its colour and energy, the sky colours, the night fog and ambient. `apply_room()` turns the kitchen window to a dim blue night at runtime (the room scene was not re-baked). |
| Night sky | `scripts/night_sky.gdshader` + `night_common.gdshaderinc` | Camera-following dome: blue gradient, a 3.2 degree full moon textured with the NASA LRO map (limb darkening, halo), two layers of twinkling stars that fade near the moon and the haze, thin moonlit clouds drifting over the moon, far mountain and tree-line silhouettes. The include is shared with the water so reflections match the sky. |
| Moon and lamps | `balcony_builder.gd` `_build_lights()`, `balcony.gd`, `neighborhood_builder.gd` `_street_lamp()` | The balcony "Sun" is now "Moon" (cool, shadowed), with a faint blue sky fill. A warm porch bulb on the balcony, a cold security lamp over the courtyard (it stutters), sodium street lamps on the poles: most are dead, the one by the gate stutters, and the last one lights the way out at the end of street B. One curtain colour glows warm: someone is home, keeping quiet. |
| Night fog and grade | `scripts/neighborhood.gd` | While the balcony shows: dark blue depth haze. Outdoors: moonlit ambient, cooler grade, a little more exposure. The haze opens up from the town (4-110 m) to the fields (14-300 m) by distance north. Desktop High/Ultra enable volumetric fog with zero global density, so only the paddy mist (`fields.gd` `_add_mist()`, a FogVolume) shows and silhouettes stay dark against the sky. |
| Rice fields | `scripts/fields_builder.gd`, baked by `editor/bake_fields.gd` into `scenes/fields/fields.tscn` (+ `assets/baked/fields/`), runtime `scripts/fields.gd` | Street B's asphalt ends at z 54.5 and a 492 m dirt road (Catmull-Rom spline through `ROAD_POINTS`; ruts, grassy crown, puddles) winds north through flooded paddies to a dead end. Cross-section `PROFILE`: verges, embankments, and an irrigation canal on the moon side. Paddy grid (28 x 22 m, brick-offset columns) with earthen dikes cut around the road; each cell is fallow (a mirror), young or ripe rice (`cell_kind()`, mirrored in the water shader). About 210,000 rice clumps and 13,000 grass clumps near the road are MultiMesh chunks (16 m, visibility range 46/38 m); farther rice is drawn by the water shader. A pond with a shore, lily pads, cattails and rocks lies beside the road with a walkable plank jetty. An abandoned bahay kubo with a flickering lantern, banana and bamboo; a scarecrow that turns to face you whenever you look away; leaning wooden power poles with sagging wires; 87 coconut palms; bamboo, talahib reeds, ferns; a fallen trunk, a SIRADO / ROAD CLOSED barrier and a giant tree in front of the moon at the end. Fireflies: GPUParticles3D swarms (`firefly.gdshader`) over the pond, the hut, bamboo and the giant tree. |
| Water | `scripts/night_water.gdshader` | Built on the downloaded CC0 water shader by StayAtHomeDev (`assets/fields/water/water_stayathomedev_cc0.gdshader`): two scrolling noise normal maps, fresnel, low roughness. Instead of screen and depth textures (not available or slow on Android) it reflects an analytic copy of the night sky, so the moon, its halo and the stars show in every paddy; fine ripples break the moon into a glittering path with twinkling sparkles; gusts roughen it. |
| Rice and grass | `scripts/field_blades.gdshader` | Procedural blade clumps (young, ripe with drooping panicles, verge grass). Gust fronts roll across the field; the global shader value `wind_gust` (declared in `project.godot`) makes them bow harder when the wind is heard. |
| Way out of town | `street_dressing.gd` `_barricades()`, `neighborhood_builder.gd` `_play_bounds()` | The middle sawhorses at the north end of street B were dragged aside; the north bound has a gap there and the fields' road walls continue it. The town ground stops where the paddy water begins (z 66, or z 80 west of x -14). |
| Night sounds | `scripts/night_audio.gd` (`InteriorNightAudio`, added by `interior.gd`) | Footsteps go to a "Steps" bus: dry indoors, a slapback off the houses in town, a long faint echo across the fields. A "Night" bus (light reverb, low-passed indoors) carries: crickets around you in the grass that go quiet when you walk up to them; frogs from the nearest paddies (a far chorus from town); toads close by; tawny owl hoots from tree tops and a rare barn-owl screech; a tokay gecko from a house or the hut; wind gusts that sweep past in 3D, creak the bamboo and drive `wind_gust`; the old low drone and metal knocks in town. |
| Hold-E pulling | `player.gd` (`hold_pressed()`, `hold_released()`, `_update_pull()`), `hinged_door.gd`, `sliding_door.gd`, `push_gate.gd`, `mobile_controls.gd`, `interior.gd` | A press shorter than `TAP_TIME` (0.28 s) is a tap and works as before (pick up / drop, open / close, unlock, TV). Holding E on a door, the studio slider or a gate leaf takes hold where the crosshair meets it; the leaf follows a hand point in front of the camera, keeps momentum when let go and rests where it stops (`_manual` state); a tap afterwards finishes the swing. A locked gate only rattles. Holding E on a prop drags it and drops it when E is released. On Android the Hold / Drop button reports its release (`hold_released`). Prompts show "Hold E • pull" and "Pulling • release E to let go". |
| Removed | `street_dressing.gd`, assets, pipeline, credits | The white cycle rickshaw ("trisikad") at the owner's request: placements, `assets/models/street/trisikad.glb`, fetch/convert entries and its credit row. |

## Downloads (tools/assets/fetch_fields.py)

Poly Haven CC0 models (dead tree trunks, stump, root cluster, mossy rocks, boulder, wooden power pole, lantern, bucket,
fern) and textures (muddy_tracks, brown_mud_02, withered_grass, leafy_grass); Sketchfab CC-BY models through the Objaverse
mirror (bahay kubo, bamboo, cattails, reed pack, scarecrow); the NASA CGI Moon Kit map; nine Wikimedia Commons recordings.
Converted with `tools/blender/process_downloads.py`. Credits: `game/licenses/THIRD_PARTY_MODELS.md` (0.7 section) and
`game/licenses/NIGHT_SOUNDS.md`. A European nightjar recording was rate-limited by Commons and skipped.

## Tests

- New `tests/fields_integration.gd` (run with `--headless --fixed-fps 60`): pulling the navy door open by hand (to 0.77),
  it rests where let go, a tap completes the swing; a tap unlocks the gate, pulling a leaf from the lane opens it (1.43 rad);
  a long press drops a dragged prop, a tap keeps carrying it; the whole dirt road is walkable (sample 544 of 553 reached,
  lowest y -2.86), footsteps say "dirt", the dead-end barrier holds, the jetty can be walked 8.4 m out and sounds like wood;
  the fields hide in the room and show from street B. 25/25 pass.
- `balcony_integration` now taps the touch Hold button (press, then release). 63/63 pass.
- Also passing: street_integration (27), touch_integration (29, `-- --mobile-test`), movement_stress.
  `settling`, physics and hamster suites were not re-run this time.
- Review renders: `godot --path game --script res://tests/v7_views.gd -- --views=night|fields|all --out=<dir>`
  (add `--rendering-method gl_compatibility` for the Android look).

## Builds (2026-10-05)

| File | Size | SHA-256 |
|---|---|---|
| `builds/windows/Interior.exe` (0.7.0, release, embedded PCK) | 636 MB | `d9fb342edbb8f8439ec3f4a76658ed48e97a988dca1382f3dbcce840a7a65ec1` |
| `builds/android/Interior.apk` (0.7.0, code 7, debug-signed) | 584 MB | `71df4daae2f5e0ea1e99d110c609b732f766c3d3ccb1ffb0f98c7ec92801c73a` |

The EXE's own `--capture-review --capture-views=balcony` run rendered all six views with no errors (`work/v7/exe-smoke/`).
The APK has not been installed on a phone this run. `builds/` is gitignored.

## Known gaps

- Android: no paddy mist (the Compatibility renderer has no fog shaders), half the rice and grass, shorter rice range. Not
  profiled on a phone. The moon blooms to a plain disc there.
- Desktop performance in the fields was not benchmarked this run (rice is ~40k instances in view on High).
- Distant palms and bamboo still read a little pale in the haze; the giant tree at the end is a scaled Poly Haven island tree,
  not a true balete.
- The fields bake must run WITHOUT `--headless`: the headless dummy renderer drops MultiMesh instance data, so the rice
  would save empty. `editor/bake_fields.gd` opens a small window for about half a minute.
- The tuktuk model (Indian signage) is still in `assets/models/street/` but unused, as in 0.6.

## Screenshots sent to the owner

| File | What it shows |
|---|---|
| `work/v7/screens/01-night-and-fields-first.jpg` | The moon over the rooftops from the balcony, the last street lamp at the way out, the canal and paddies catching the moon, the jetty and pond with fireflies, ripe rice by the bahay kubo, the dead end |
| `work/v7/screens/02-final-exe-android-fields.jpg` | The balcony and courtyard from the exported EXE, the road and pond under the Android renderer, the pond and scarecrow on desktop |

## How to resume

1. After changing `fields_builder.gd`: `godot --path game --script res://editor/bake_fields.gd --resolution 320x180`
   (not headless). After changing the neighbourhood or balcony builders: `godot --headless --path game --script res://editor/bake_balcony.gd`.
2. Tune the night in `scripts/night.gd` (moon, sky, fog colours) and `scripts/neighborhood.gd` (fog distances, ambient, exposure).
3. Extend the road: add points to `ROAD_POINTS`, move the dead end, re-bake. Audio anchor lists are stored on the Fields node
   as metas (`audio_frog`, `audio_owl`, `audio_gecko`, `audio_bamboo`).
