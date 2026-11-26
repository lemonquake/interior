# Interior 0.11: hood up, the ammo box and hand-over, the scarecrow nearer, a usable Glock (handoff)

Branch: `main`, uncommitted (on top of the uncommitted 0.9 and 0.10 work). Written 2026-10-06. The brief was
`docs/v11/brief.md`; the previous handoff is `docs/v10/handoff.md`.

## What was built

| Item | Where | Notes |
|---|---|---|
| 1. Clip names | `game/scripts/stranger.gd` | He now uses the GLB's real clips `interact_pickup` / `interact_talk` (0.10 asked for `pickup` / `talk`, so he stood still under the scarecrow). `LOOPS` loops `interact_talk`. Every clip he plays is listed in `CLIPS`; `_require_clip()` `push_error`s a missing one, and `stranger_integration` checks all of `CLIPS` exist in `stranger.glb`. |
| 2. Hood up | `tools/blender/human/build_human.py` (`HOOD = "up"`, `-- hood_down` builds the 0.9 look) | A closed hood shell from the body's head and neck (3.4 cm off the scalp, ~5 cm at the crown and back), brim 8 cm past the forehead at the eyebrows, sides to the cheekbones; rib drawstring channel, hem, crown seam, the two white strings hang from the opening. Near-black "Hood lining" inside. The face is darkened in the skin texture (x0.24 eyes and forehead, x0.4 nose, x0.55 mouth, x0.68 chin): at night a dark oval with a hint of jaw. Hair mesh removed. Weights: top/brim 100 % `head`, blending into the body's neck/chest weights below. 8 materials, 22.4k triangles. Garments are welded along UV seams before inflating, which removed the black shards on the shoulders that 0.9/0.10 had. |
| 3. Ammo box | `tools/blender/story/ammo_box.py` -> `game/assets/models/story/ammo_box.glb` (+ `ammo_box_label.png`) | Generic olive 9x19 mm box of 60, 120 x 75 x 40 mm, bevelled, lid seam, crushed corner, water stain, no brand; in a crumpled clear plastic bag. 1,032 triangles, 2 materials. |
| 3. Hand-over | `build_human.py` (`hand_over` 2.6 s one-shot, `carry_box` walk loop, `box_grip` node on `hand.R`); `stranger.gd`; `hut_house.gd` | The box lies half-buried and tilted 0.55 m behind the scarecrow's post (away from the road, so it can't be seen from there). DIGGING plays `interact_pickup` at 0.8x; at its lowest frame (0.333 s, `PICKUP_LOW`) the box rises 0.22 s into his right fist (`box_grip`); then one `idle_adjust` beat. BRINGING walks the last 4 m (`carry_box`). GIVING plays `hand_over`; at the release time (1.2 s, `HAND_OVER_RELEASE`) the box goes from his hand to in front of the camera and down out of view in 0.35 s, then `story.receive_ammo()` (and the pickup sound). |
| 4. Scarecrow | `game/scripts/fields_builder.gd` (`_scarecrow`, re-baked `scenes/fields/fields.tscn`) | 38 road samples past the hut (34 m along the road from the hut path), on the hut's side, 9 m off the road, on an islet whose flat top is 2.4 m across; clear of the pond, the jetty and the poles (pole 4 is 5.7 m from the dike). The dike's strip is kept free of rice. Rice counts and the road render match 0.10 (`work/v11/screens/rice_compare.jpg`). |
| 4. Dike | `game/scripts/footpath.gd` (`InteriorFootpath.build(fields, road_index, to_point, half_width, end_y, top, bank, label, pad_radius)`) | The hut's causeway generalised: visible grassy top and mud banks, a tilted walking slab, edge walls, a gap cut in the road's edge wall; with `pad_radius` an islet pad and a ring of walls open toward the path. `hut_house.gd` uses it for the hut path and for a 1 m dike to the scarecrow (`crow_route`, `crow_index`, `crow_frame()`, `box_spot()`). He now runs the dike (no wading) and the player can follow him onto the islet. The scarecrow's turning is frozen (`InteriorFields.crow_frozen`) from DIGGING until he leaves. `FOLLOW_GAP` stays 20 m. |
| 5. Gun | `game/scripts/gun.gd` (`InteriorGun`, owned by `story.gd`) | See below. |

### The Glock (`scripts/gun.gd`)

- **Ammo**: empty out of the drawer; a dry click and "It's empty." (at most every 3 s); the 60 rounds go to reserve;
  17 + 1. The first reload: 17 / 43. A later reload pockets what was left in the old magazine. `story.ammo` is now the
  total (loaded + reserve), and the inventory line reads "Glock 17 • N rounds".
- **Controls**: `1` / `G` draw and holster (action `gun`), left click fires while drawn (action `fire`, the click never
  also throws), `R` reloads (action `reload`), `F` while drawn opens the inspect screen on the carried gun (no "Put
  back"; F / Esc / OK close it). Drawing drops what is held; Hold (E) on a prop or door holsters first, then acts
  (`player.use_hook`). Mobile: a Gun / Holster button appears once it is owned; while drawn Throw reads Fire and a
  Reload button appears (fourth row, above Sprint and Inspect). A click that moves the dialogue on doesn't fire.
- **Shot**: hitscan from the camera centre, 80 m, mask 2|4, at most 4 a second. Muzzle flash: an additive card on
  the view model's muzzle and a warm 6-energy, 6 m omni light for 40 ms (at least two drawn frames) in the main world
  where the muzzle would be. Camera kick 1.6 deg, back over 0.25 s (`player.kick()`, `player.recoil`). The Glock's
  own `fire` clip throws the round. Gunshot (3D, own `Gun` bus with a reverb set by indoors / hut / fields) plus a far
  echo tail outdoors. Impacts by surface (wood, stone, metal, dirt, fabric, glass, water): a 6 cm hole (`Decal` on
  desktop; on Android a card with a shader that pulls it toward the camera, since Compatibility has no decals), 40
  at most, oldest reused; a dust / splinter / spark burst (CPU particles and half as many on Android); a ricochet on
  metal; a splash on the paddy water (no hole). Props take 6 N s along the ray; a hit TV stops on static for good
  (`InteriorTelevision.shoot()`). The hamster enclosure and the aquariums: the glass takes a crack and nothing moves.
- **View model**: its own world in a SubViewport under the HUD (under the crosshair, toasts and dialogue), FOV 55,
  sways with the step bob and lags behind fast turns, lit moon-blue outside (warm sodium near the lit town lamps),
  candle-warm in the hut, the room's colour indoors, kept dim. Arms: `tools/blender/human/build_fp_arms.py` -> `game/assets/characters/fp_arms.glb` (forearms and fists from the same rigged body, dark grey long sleeves with rib cuffs, 3.6k triangles; clips `fp_idle`, `fp_draw`, `fp_holster`, `fp_fire`, `fp_reload` (magazine out 0.30 s, seated 0.95 s, slide back 1.27 s, released 1.30 s), `fp_dry`, baked at 100 fps). The Glock is instanced under the `gun_grip` node on `hand.R` with an identity transform; the reload moves `magazine_7` / `magazine_001_8` and the slide in step with `fp_reload`.
- **HUD**: `17 / 43` bottom right while drawn (above the buttons on mobile).
- **Sounds**: `tools/assets/fetch_hut_sfx.py` (see Licences).

## Tests (headless, `--fixed-fps 60`)

| Test | Result |
|---|---|
| `gun_integration` (new) | 41/41; with `-- --mobile-test` 45/45 (buttons only when they apply) |
| `hut_story_integration` | 57/57 (was 48): + scarecrow 34 m past the hut path (< 60), the dike, he reaches it after 12.1 s of following (< 25), the frozen scarecrow, the real player walks the dike onto the islet beside the scarecrow and the islet edge holds, the box in hand.R while bringing, no rounds before the release frame, the box gone after |
| `stranger_integration` | 26/26 (+ every clip in `CLIPS` exists; 7+ surfaces now the hair is gone) |
| `fields_integration` | 25/25 after the re-bake |
| `street_integration` | 27/27 |
| `balcony_integration` | 63/63 |
| `room_integration` | 89/89 |
| `touch_integration` (`-- --mobile-test`) | 29/29 (now expects seven buttons showing plus the hidden Gun and Reload) |

Logs are in `work/v11/` (`gun3.log`, `gun_mobile3.log`, `story5.log`, `stranger_int1.log`, `fields_int1.log`, `reg_*.log`).
Review renders: `godot --path game --script res://tests/hut_views.gd -- --out=<dir>` (now also the gate, the scarecrow
from the hut path and the road, the dike, the box close up and from the road, digging from the islet, carrying, the
hand-over at full reach, after the toast).

## Screenshots sent to the owner

| File | What it shows |
|---|---|
| `work/v11/screens/sheet_a.jpg` | Items 1+4: the scarecrow's new spot from the hut path and the road, the dike, the box, following, digging, carrying (before the hood) |
| `work/v11/gun/sheet_b.jpg` | Item 5 first pass (no arms): drawn, a shot, the hole close up, reload, the moonlit road |
| `work/v11/screens/sheet_b.jpg` | Items 2+3: the hood up at the gate and in the yard, the box, carrying, the hand-over at full reach, the toast |
| `work/v11/human/01-hood-sheet.jpg` | The Blender check sheet: hood in idle, run, gate_grip, pickup, hand_over; the face in day and dim light |
| `work/v11/gun/sheet_c.jpg` | Item 5 with arms: room, flash, mid-reload, hut, road, the mobile buttons (Android look) |
| `work/v11/arms/01-arms-sheet.jpg` | The arms' clips in Blender |
| `work/v11/exe-smoke/sheet.jpg` | From the exported 0.11.0 EXE: the hooded man, the box, the dike, the gun in the room and on the road |

Also in `work/v11/`: `screens/run4/` (the full story sequence), `android-look/` (Compatibility + mobile: `gun1/`, `hut/`),
`screens/rice_compare.jpg` (road render 0.10 vs 0.11).

## Builds

| File | Size | SHA-256 |
|---|---|---|
| `builds/windows/Interior.exe` (0.11.0, release, embedded PCK) | 639 MB | `9da3cb0cd1283f70b3618b2d20f01366af09ef19c623755d9d74b8d0986b5b82` |
| `builds/android/Interior.apk` (0.11.0, code 11, debug-signed) | 587 MB | `ae4d6936c210c78916724414949cdd6134c58de22d9d84e226c6fd28020e58c5` |

`aapt2 dump badging`: versionCode 11, versionName 0.11.0. `game/licenses/*.md` copied into `builds/windows/`. The EXE's
own `-- --capture-review --capture-views=hut` (now 8 views, incl. the hooded man, the box and the dike) and
`--capture-views=gun` (drawn, flash, hole, reload, hut, road) rendered every view (`work/v11/exe-smoke/`). The APK
was not installed on a phone; its look was checked with the project under `--rendering-method gl_compatibility -- --mobile-test`.

## Licences

- `gun_shot.ogg` and `gun_rack.ogg` are CC BY-SA 4.0 (Commons, recordings by Mike Koenig): the only real 9 mm shot and
  slide rack on Commons. The brief asked for PD / CC0 / CC BY; the project already ships CC BY-SA night sounds (the
  dog barks), so they are credited the same way in `game/licenses/NIGHT_SOUNDS.md`. Swap them if the owner wants
  no share-alike files. The magazine, dry-fire, ricochet and impact sounds are synthesised.
- The box, the hood and the arms are this project's own models.

## Known gaps

- The scarecrow is 34 m past the hut path along the road (38 samples), a little short of the brief's "about 40 m":
  further on, the dike would pass pole 4. Change `SCARECROW_PAST_HUT` if wanted.
- Digging happens in the scarecrow's moon shadow: from the islet he reads as a dark crouched figure.
- The box rises ~0.3 m into his hand in 0.22 s, because the library's `interact_pickup` clip stops 0.36 m above the
  ground (a deep crouch, not a reach to the mud).
- The fists keep the body's closed pose: no trigger finger; the rack is a quick flick (1.27-1.30 s in the clip).
- After the ammo the "Now... run." line is up for ~2.6 s; clicks during dialogue move it on and never fire.
- A slight jagged band where the hood's hem overlaps the hoodie collar (visible only in Blender close-ups).
- Gunshots don't alert anyone (no enemies by design); the sirens don't react to them.
- Bullet holes on moving props are parented to the prop; holes on walls stay for the session (40 max, then reused).
- Two gun recordings are CC BY-SA 4.0 (see Licences).

## How to resume

1. Hood / clips / box_grip: `blender -b --factory-startup --python tools/blender/human/build_human.py -- preview export`,
   then `godot --headless --path game --import`. Box: `tools/blender/story/ammo_box.py`. Arms: `tools/blender/human/build_fp_arms.py`.
2. Scarecrow spot: `SCARECROW_PAST_HUT` / `SCARECROW_OFF_ROAD` in `fields_builder.gd`, then re-bake **windowed**:
   `godot --path game --script res://editor/bake_fields.gd --resolution 320x180`.
3. Gun numbers: constants at the top of `gun.gd` (reload timeline `RELOAD_*` must match `fp_reload`).
4. Captures: `Interior.exe -- --capture-review --capture-views=gun|hut --capture-path=<dir>`; the full story renders:
   `godot --path game --script res://tests/hut_views.gd -- --out=<dir>`.
