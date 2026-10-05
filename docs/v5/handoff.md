# Interior: music studio, neighbourhood and downloaded assets (handoff)

Branch: `polish-v0.3`. Written 2026-10-05. The previous run's handoff is `docs/v4/handoff.md`.

## Owner request (2026-10-05, verbatim)

> 1st picture, download some 3D models of trees and environmental objects, and create actual houses with different
> designs that have actual textures that look realistic. I wanna see a neighborhood full of trees and some houses that I
> can see from this view in the 1st image. There should be a mysterious atmosphere, almost foggy out the distance,
> skybox, time is 3 oclock in the afternoon. 2nd pic I want this to be an actual music studio with a gaming PC (2
> monitors), download 3D models of music instruments, download actual interior objects for the house. I want the house
> full of details and interior design. The door in 2nd pic should be a sliding door (glass), and it should be a big room
> full of black foam noise cancelling walls. I want you to make sure that you use downloaded 3D assets of guitars and
> music instruments. then compile EXE

Follow-ups during the run:
- "send screenshots with every progress"
- "fix: trees in the middle of roads, trees going through houses and roofs"

## Status: done (2026-10-05)

| Part | Result |
|---|---|
| Asset pipeline | `tools/assets/fetch_objaverse.py` downloads 24 CC-BY Sketchfab models through the Objaverse mirror. `tools/assets/fetch_polyhaven.py` downloads 31 CC0 Poly Haven models, 21 PBR texture sets and the `kloofendal_28d_misty_puresky` HDRI. Downloads land in `.local/downloads/`. `tools/blender/process_downloads.py` (Blender 5.2) joins, scales to real size, re-pivots, decimates, and thins tree leaf cards island by island, writing to `game/assets/models/{studio,nature,street,decor}`. `tools/assets/make_sky.py` paints out the HDRI sun and packs the sky into `game/assets/outdoor/sky/misty_afternoon_sky.png`. Credits are in `game/licenses/THIRD_PARTY_MODELS.md`, also copied next to the EXE. |
| Studio | Built by `scripts/studio_builder.gd` and baked by `editor/bake_studio.gd` into `scenes/studio/studio.tscn`, which `main.tscn` instances. It's a 4.4 x 4.4 m room (x -5.65..-1.25, z 2.9..7.3) lined floor to ceiling with black wedge foam, plus two foam ceiling clouds. A glass sliding door (`scripts/sliding_door.gd`, `InteriorSlidingDoor`, toggled with E like the navy door) closes the old alcove opening. Downloaded models: a guitar wall (Ibanez, Gibson SG, Les Paul, two acoustics) on hangers, a Fender P-bass on a stand, a Natal drum kit, a 61-key synth with an analogue synth on a two-tier stand, Marshall and Orange amps, a gaming desk with **two** curved monitors (DAW and game screens generated in `scripts/studio.gd`), an RGB tower, keyboard, mouse, MIDI controller, audio interface, KRK monitors on stands, headphones, a gaming chair and a boom mic. Poly Haven decor: a Chesterfield couch, plants, books, a boombox, a cassette player, a clock, a vase and a pendant lamp. Also a purple LED cove and a "3RD HARMONIK" neon. The old procedural alcove and guitars were removed from `room_surroundings.gd`, and the room was re-baked. |
| Neighbourhood | `scripts/neighborhood_builder.gd` is called from `balcony_builder.gd` and baked into `scenes/balcony/balcony.tscn`. It has four streets with sidewalks and lane markings, and about 50 generated houses in 5 styles. The styles combine gable corrugated-iron roofs, hip clay or grey tile roofs, flat roofs with parapets and water tanks, unfinished hollow-block top floors with rebar, and brick lower storeys. Houses have windows with grilles and curtains, doors or sari-sari store shutters, balconies, AC units, downpipes, and gated fence walls. Trees are palms, island trees, `tree_small_02`, jacaranda, bananas and searsia, set in yards, vacant lots, a grove by the courtyard gate and a far ring. Utility poles carry sagging wires. **Tree guards:** no trunk stands on a road, sidewalk, wall or pole. No crown overlaps a house (roof overhang and balcony included) or our house, or covers more than 45% of another crown. Trees that don't fit are moved or dropped: 94 planted, 42 dropped. |
| Atmosphere | The HDRI sky dome is `scripts/sky_dome.gdshader`. The sun is 40° up, about 3 pm, from -X/+Z (`SUN_DIRECTION` in `balcony_builder.gd`), with a sun disc drawn there. `scripts/neighborhood.gd` turns on depth fog (8 → 150 m, curve 0.7, grey-blue, with a little sun scatter) and raises the camera far plane to 900 m **only while the balcony is visible**, so the closed room renders as before. |
| Tests | These pass: physics_integration, room_integration, tabletop_stability, movement_stress, hamster_stress, surroundings_integration, upgrade_integration, touch_integration and balcony_integration. surroundings now checks the glass door and the studio rear wall; balcony filters out the studio slider. `settling` still fails but is not worse: start drift is 19.4 mm against 20.75 mm last run. |
| Perf | look_preview at High, 1920x1080, RTX 4060 (median / p95): outdoor orbit 5.69 / 7.82 ms (2.51 / 5.50 ms before the neighbourhood). Room with the door closed: 4.98 / 7.27 ms (4.27 before; the studio shows through the glass). |
| Windows EXE | `builds/windows/Interior.exe`, 554 MB, SHA-256 `eac3797021bb9ab179b9a512bbf60b14438ed425b38d1084899c7dc759b2b86e`. Exported directly, because `tools/build.ps1` stops at `settling`. The EXE's own `--capture-review --capture-views=balcony` run rendered all six views with no errors (`work/v5/screens/09-exe-smoke.jpg`). The Android APK was not rebuilt. |

### Known gaps

- **Living room decor:** the downloaded Poly Haven decor went into the studio only. The living room was left as it was,
  because of the earlier "tidy, not messy" rule. Placing decor there needs a pass with renders.
- The Sketchfab mango tree was dropped (its leaf cards render black), and the rest of its config was removed.
- The sun is at a 3 pm elevation (40°), but the HDRI's own sun (28.5°) was painted out. A faint glow remains below the
  drawn sun.
- The Compatibility (Android) renderer was not checked visually for the studio or the neighbourhood. On mobile, trees
  fade at 160 m and the studio keeps two lights.
- The repository grew by about 230 MB of GLB and texture files.
- `tools/build.ps1` still stops at `settling`. `builds/windows/README.txt` still says 0.2.
- Review renders: `godot --path game --script res://tests/v5_views.gd -- --views=studio|outdoor|all --out=<dir>`.
  Model orientation sheets: `tests/model_lineup.gd -- --group=studio`.

## How to resume

1. To re-bake after builder changes: `editor/bake_studio.gd`, `editor/bake_balcony.gd` (it includes the
   neighbourhood) and `editor/bake_room.gd`. Run the editor import first (`--editor --import --quit`) whenever new
   `class_name` scripts or assets appear. Model instances carry the `keep_instance` meta and stay linked to their GLBs.
2. To add a model, add it to `tools/assets/fetch_*.py` and `ASSETS` in `tools/blender/process_downloads.py`, run
   Blender, then place it with `InteriorModelKit.place()`.
3. To build the EXE: `.local\tools\Godot_v4.7.2-stable_win64_console.exe --headless --path game --export-release "Windows Desktop" builds\windows\Interior.exe`.
4. Usage: weekly usage was at 87% at the start of this run and about 93% at the end, on Pro.

## Screenshots sent to the owner

| File | What it shows |
|---|---|
| `work/v5/screens/01-studio-first-pass.jpg` | The studio, first pass: glass door closed and open, desk, guitar wall, drums, door wall |
| `work/v5/screens/05-photo1-view.jpg` | The neighbourhood from the owner's photo-1 spot (third pass) |
| `work/v5/screens/05-outdoor-third-pass.jpg` | Four outdoor views (third pass) |
| `work/v5/screens/08-trees-denser.jpg` | After the tree fix: no trees on roads or through roofs, with denser yards and a lane grove |
