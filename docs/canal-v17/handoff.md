# Canal settlement rebuilt — Windows 0.17.0

Updated 2026-10-08. This replaces the 0.16 canal district, which was a flat grid of boxes beside a straight concrete channel, with the owner's reference concept: an abandoned Davao squatter settlement on a river ravine, at night.

## What is there

- **Ravine and river.** The river runs about 9 m wide and 4 m below the lanes, along a gentle S-curve. The east bank is a battered rubble-stone retaining wall with concrete patches, runoff streaks, a black-green tide line, ferns and vines. The far bank is a muddy slope with weeds, bananas, bamboo, trees and a dirt footpath at the waterline. The water is a new murky, slow-flowing shader with oily scum. It reflects the sky and the moon only where the ravine leaves the sky open, and three box-projected reflection probes pick up the houses and bulbs. Faint volumetric mist lies on the water (Forward+ High and Ultra).
- **Custom models.** There are 32 stilt shanties and 15 rubbish and rubble pieces, all generated in Blender (`tools/blender/canal/build_canal_kit.py` → `game/assets/models/canal/kit/` + `kit.json`).
  - **House construction:** patchwork plank, painted plywood and corrugated-sheet walls over timber frames, hollow-block bases, and upper storeys that lean and cantilever out over the catwalk on knee braces.
  - **Underneath and roofs:** some ground floors stand on timber or steel stilts in the river, with rotten joists visible from the catwalk. Lean-to roofs have deep eaves and are weighed down with tyres and rocks, and some sheets have blown off.
  - **Openings and fittings:** broken jalousies, grilles, boarded and gaping doors, hanging shutters, torn curtains, tin awnings, PVC drains to the river, water drums, satellite dishes, rotten laundry and torn tarps.
  - Every house is spray-numbered by a relocation census.
- **Paths.** You can walk all of these:
  - the lane between the river row and the lane row, entered from street A down the dirt ramp;
  - a trench stair cast through the bank down to the rusted catwalk;
  - the catwalk itself: warped planks, some missing, chain-link railing torn in places, stilts in the rubble;
  - a sagging plank footbridge to the far-bank path;
  - the path climbing to a concrete road bridge (the reference photo's viewpoint);
  - the catwalk stair back down.
  Both river ends close at concrete headwalls with black box culverts behind bent grates.
- **Filth and vandalism.** About 130 rubbish heaps, litter strips, floating rafts, mattresses, rubble and furniture, plus loose bottles and bags in the water. 72 world decals plus the per-house marks use original spray symbols, random-letter tags, bubble letters, census numbers and brushed signs ("BAWAL MAGTAPON NG BASURA DITO", "BAWAL UMIHI DITO", "BAWAL PUMASOK", "DELIKADO"…). They come from `tools/assets/make_canal_graffiti.py`. There is a tangle of power and service lines, some cut and hanging, plus a stripped tricycle and a rotten basketball hoop.
- **Light (dark and scary).** The shared WorldEnvironment is unchanged, as `docs/canal-darkness` requires. The only light sources are:
  - the moon;
  - five caged bulbs that swing and fail, three on wall brackets over the catwalk and two on lane wires;
  - a sodium lamp on the bridge that is mostly dead;
  - a red votive candle in a roadside shrine on the far-bank path.
  No window is lit, because the settlement is abandoned.

## Engine changes outside the canal

- The town's street-level ground slab used to run under the whole district, at street height. `canal_settlement.gd` now cuts a hole in it at runtime:
  - The ground colliders are split around the hole.
  - Kerb convex shapes are trimmed at its east edge.
  - The ground, asphalt, pavement and road-paint meshes are clipped exactly, with attributes interpolated.
- `player.gd`: the out-of-world reset moved from y < −6 to y < −12. The riverbed is at −6.6, so stepping into the river used to teleport the player home.
- `interior.gd`: new built-in capture route `-- --capture-review --capture-views=canal`.
- `street_integration.gd`: the stale "end of street A is blocked" check now asserts the 0.16+ opening instead.

## Verification

- `canal_integration.gd`: **57/57 passed.** A real player walks the full loop (house street → ramp → lane → trench stair → catwalk → footbridge → far-bank path → climb → road bridge → catwalk stair → catwalk → trench stair → lane → street A). The test also checks:
  - footstep surfaces: dirt, wood, concrete;
  - railing containment, and wading out of the river up the far bank;
  - bulb swing and flicker, the bridge lamp dying, and the district hiding indoors.
- Regressions:
  - balcony 62/62
  - neighbourhood interactions 29/29
  - neighbourhood decay 32/32
  - street 27/27
  - stranger 26/26
  - hut story 63/63
  - night revision 28/28
- Rendered review: `tests/canal_review.gd`, Forward+ High at 1600×900 on the RTX 4060. Most views draw about 1,200–1,700 calls; the bridge view draws about 6,400. All views held 60 FPS with vsync on this machine. Shanties and rubbish are merged into per-material batches in 24 m chunks.
- **Exported EXE:** `builds/windows/Interior.exe` 0.17.0, 669,809,536 bytes, SHA-256 `e9affa2c8f71c7a5fc9c4a74f032038b8f7f1dac9e31cd0b94e3391071371dc7`. Its own capture (`canal-*.png` here) reports 30 houses, 72 decals and 8 lights, with no script errors.

## Screenshots sent

| File | View |
| --- | --- |
| `06-far-path.png` | East-bank shanties and stone wall from the far-bank path (sent mid-run) |
| `02-catwalk-north.png` | Catwalk under the overhangs, bulb and moonlit water (sent mid-run) |
| `canal-1-bridge.png` | Reference-photo angle from the road bridge (EXE) |
| `canal-2-catwalk.png` … `canal-5-shrine.png` | EXE captures: catwalk, far path, lane, shrine |

## Known gaps

- The Android APK was not rebuilt. Compatibility gets no volumetric mist and limited reflection probes.
- The river has no water sound yet: there is no CC0 flowing-water recording in the project.
- The old 0.16 `graffiti_0..3.png` files are unused. The previous, untracked `tools/assets/make_canal_graffiti.py` that made them was overwritten by the new generator.
- Merged kit batches drop per-model LODs: about 11–15 M primitives per frame including shadow passes. That is fine on the RTX 4060 but untested on weaker GPUs.

Rebuild everything:

```text
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P tools/blender/canal/build_canal_kit.py
python tools/assets/make_canal_graffiti.py
Godot_v4.7.2-stable_win64_console.exe --headless --path game --import
Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path game --script res://tests/canal_integration.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path game --export-release "Windows Desktop" <abs>/builds/windows/Interior.exe
Interior.exe -- --capture-review --capture-views=canal --capture-path=<dir>
```
