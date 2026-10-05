# Look component handoff (v0.3)

Worktree branch `worktree-wf_b14bc38a-a2f-1`. The worktree started at 5e245ff, so it was fast-forwarded to polish-v0.3 @ ee6c263 before any work.

## What changed
- **InteriorLighting** (`game/scripts/room_lighting.gd`, salvage reworked). WorldEnvironment uses AgX on desktop and Filmic on Compatibility, with glow and SSAO. It has 9 recessed 2850-3000 K spot downlights with trim and diffuser meshes (7 may cast soft shadows), cool 6500 K kitchen window daylight, and a floor lamp accent (2500 K, black-metal stand, linen shade). It also has 5 warm LED strips (AreaLight3D on desktop, additive wash cards on Compatibility) and TV glow (`set_tv_glow`). Runtime state lives on the nodes: metadata, the persistent groups `interior_lighting` and `interior_lighting_lights`, and `@export tv_glow_on`. So `apply_quality()` works on the baked, reloaded scene (verified, see below). `InteriorLighting.find_in(room)` finds the rig. On mobile/Compatibility only the 2 lights flagged `mobile` stay visible, with 1 shadow on Low.
- **InteriorMaterials** (`game/scripts/material_library.gd`): covers every contract section-5 key. It is cached, uses res:// textures only, drops normal maps on mobile, and uses an ORM material for `marble_gold`.
- **room_visuals.gd**: glb materials are mapped by original name to library keys:
  - oak slat on walls, oak on furniture
  - walnut
  - gold-veined marble: honed on the wall, polished on the table
  - marble floor
  - brown fabric weave, leather grain, wool rug
  - black metal, white satin furniture, warm plaster walls

  The old omni tuning and the large ceiling diffusers are gone; InteriorLighting now owns lighting.
- **room_surroundings.gd**:
  - Ceiling: the blue grid is replaced by a smooth warm-white ceiling.
  - Finishes now come from the library.
  - Removed clutter: dish rack, cookware, counter bottles and utensils, fridge photos and magnets, pastel drawer tower and rack, flower mats, blue bag, door photo, routers and cables, carton, hanging bags, tie-back toys, tins, bottle rack, laundry baskets and clothes, shopping bag.
  - Replaced: the leaf curtain is now sheer linen and the kitchen valance is linen.
  - Calmer finishes: the checker tiles are toned down and the window reads as cool daylight.
  - Gallery: 5 aligned family photos (was 8 scattered).
  - New InteriorObjects:
    - rubber ball 0.22 m and tennis ball on the rug
    - walnut bowl with 3 oranges on the kitchen counter
    - frosted glass bottle and sage vase

    They use Sphere/Cylinder shapes and the defensive hints `set("physics_material", ...)` and `set("rolls", ...)`. The 3 cups are kept.
- **room_manifest.json**: removed storage_bin_36, storage_bin_37 and "Pink toy 1 baby_crib_9". They are listed under the new `declutter` key and their glb meshes are freed. 45 actors remain. The clue props (clock 5, plant 0, frame 8) and the TV are untouched.
- **Assets**: `game/assets/materials/**` and `game/assets/art/**` come from salvage. Salvage had no make_textures.py, so none was added.
- **Edits outside owned files**:
  - `room_builder.gd`: the WorldEnvironment and fixture block is replaced by `InteriorLighting.create`.
  - `interior.gd`: `_apply_quality` supports tiers 0-3 and delegates to lighting. The `_show_menu` quality list adds "Graphics: Ultra" on desktop.
  - Test assertions changed on purpose for the declutter:
    - `room_integration.gd`: 48 to 45 actors
    - `surroundings_integration.gd`: family_photos >= 5, dynamic_props == 11
    - `upgrade_integration.gd`: two checks now read the actor count from the manifest

## Deviations (honest)
- **No SSIL, SDFGI or ReflectionProbes on Low/Medium/High/Ultra.**
  - What I saw: SDFGI and SSIL left blotchy dark smudges on the ceiling. The box probes made the white cupboard, glass and sofa edges glow white. Low without probes was clean; Medium and High with probes glowed.
  - What ships instead: High is SSAO medium, 7 soft shadows and MSAA 2x. Ultra is SSAO high, SSR, MSAA 4x and high soft shadows.
  - The probe code is still there, unused (no tier enables it), for a later fix.
- The desktop default quality in `interior._ready` is still 1 (Medium); that line is outside my allowed region. Integration should set it to 2. High and Medium now look almost the same.
- The Compatibility render is bright and a bit flat. Ambient and exposure were lowered twice and it is still flatter than desktop.
- The rug reads pale under the table. The black display rack beside the TV still holds the glb's built-in dishes (one mesh).

## Verification (Godot 4.7.2 console, RTX 4060)
- Import: `--headless --path game --editor --import --quit` OK.
- Rendered: `--path game --script res://tests/look_preview.gd -- --render-size=1920x1080 --quality=2 --out=<dir> --perf-seconds=10` passed with 7 views. **High p95 8.50 ms** (median 4.21 ms) over 10 s.
- Ultra (`--quality=3 --perf-seconds=10`): p95 9.77 ms. Low and Medium passed.
- Compatibility: `--rendering-method gl_compatibility ... -- --mobile-test --quality=0` passed, with 2 visible lights and 1 shadowed.
- Headless (`--headless --fixed-fps 60 --script res://tests/<t>.gd --quit-after 1200`):
  - room_integration PASS (85 checks)
  - surroundings_integration PASS (29)
  - upgrade_integration PASS (229)
  - touch_integration PASS (`-- --mobile-test`)
  - physics_integration PASS
  - settling PASS
- Not verified:
  - movement_stress printed no marker within 1200 frames (not investigated).
  - tabletop_stability and hamster_stress (16000 frames) were not run.
- Bake:
  - `--headless --script res://editor/bake_room.gd` gave `INTERIOR_BAKE` (1255 nodes).
  - look_preview on the baked scene (no ROOM_READY line, so it loaded `living_room.tscn`) renders the same as the procedural build, with the same lighting stats (High, 16 lights, 7 shadowed).
  - `compare_bake.gd` hung under `--headless`; it needs a rendered run. Not completed.
  - The baked output was deleted and not committed.

## Screenshots (A:/3rd Harmonik/interior/work/v3/look/screens)
- 01-first-light, 02-warm-downlights
- 03-high-room-wide, 04-high-kitchen
- 05-before-after, 06-before-after (before = reference/before/*.jpg, after = High)
- 07-compat-room-wide, 08-ultra-tv-wall
