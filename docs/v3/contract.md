# Interior v0.3 — Polish & Physics Overhaul Contract

Owner request (2026-10-05): "game look atrocious. polish it and completely improve the physics allowing
objects to really roll over and realistically move. Do not make that messy interior design like in the
reference. Overall SIGNIFICANT IMPROVEMENT. Then build the EXE and APK."

This file is the frozen interface every component builds against. If a component needs an interface change,
record it in its handoff (`work/v3/<component>/handoff.md`) instead of silently diverging.

## 1. Paths and tools

- Repo root: `A:/3rd Harmonik/interior` (branch `polish-v0.3`). Godot project: `game/`.
- Godot 4.7.2 console binary (absolute; works from worktrees):
  `A:/3rd Harmonik/interior/.local/tools/Godot_v4.7.2-stable_win64_console.exe`
- Blender 5.2.1 LTS: `C:/Program Files/Blender Foundation/Blender 5.2/blender.exe` (OptiX on RTX 4060 available).
- Python 3.12 with Pillow on PATH (`python`).
- Reference photos (owner's real room; layout/style guide only):
  - Living room, the *good* reference for style: `C:/Users/LEMONP~1/AppData/Local/Temp/claude/A--3rd-Harmonik-interior/8c0388a6-4372-4e13-9474-a049741b10ab/images/1.webp`
  - Rear wall (messy): `.../images/2.webp`; kitchen (messy): `.../images/3.webp`; right wall (messy): `.../images/4.webp`
  - Older copies: `A:/3rd Harmonik/interior/.local/reference-photos/{rear,kitchen,right,enclosure}.png`
- "Before" captures of the current (rejected) look: `C:/Users/LEMONP~1/AppData/Local/Temp/claude/A--3rd-Harmonik-interior/8c0388a6-4372-4e13-9474-a049741b10ab/scratchpad/before/*.jpg`
- Evidence/logs/previews go to the MAIN checkout (gitignored), even when you work in a worktree:
  `A:/3rd Harmonik/interior/work/v3/<component>/`. Never write evidence into `game/`.
- Fresh worktrees have no `.godot/` cache. Import once before running anything:
  `"<godot>" --headless --path <worktree>/game --editor --import --quit`
- Headless test run pattern (dummy renderer, no GPU):
  `"<godot>" --headless --fixed-fps 60 --path game --script res://tests/<name>.gd --quit-after <frames>`
  Each test prints exactly one final marker line `INTERIOR_<NAME> {json}` with `"passed": true|false`.
- Rendered capture runs need a window (no `--headless`): `"<godot>" --path game -- <user args>`.

## 2. Engine configuration (already applied in `game/project.godot`)

- Desktop renderer: **Forward+**. Android renderer: **Compatibility (GLES3)** via `rendering_method.mobile`.
  Everything must render correctly on both. Forward+-only features (SDFGI, SSAO, SSIL, SSR, volumetric fog,
  VoxelGI) are desktop tiers only. Materials must be `StandardMaterial3D` / `ORMMaterial3D` or shaders that
  compile on both renderers.
- Physics: **Jolt Physics**, 60 ticks/s, **physics interpolation ON**. Anything teleported (spawn, reset,
  recover, restart, attaching to a moved parent) must call `reset_physics_interpolation()` afterwards.
  Code that moves visual-only nodes every frame should do so in `_process` or opt out of interpolation.
- Physics layers: 1 Player, 2 Room (static structure), 3 Objects (InteriorObject). Bits: player=1, room=2, objects=4.
  InteriorObject: layer 4, mask 7. Player: layer 1, mask 6. Static room: layer 2, mask 5.

## 3. Art direction (clean, tidy, designer version of the owner's room)

Keep the *room identity* (same footprint, TV wall with marble feature panel flanked by warm oak slat walls,
floating white shelves with small plants, TV console with 5:08 digital clock and flowers, brown fabric sofa and
brown leather sofa, marble-top coffee table with dark wood X-pedestal, plant/tray/tissue box on it, standing
fan, computer desk on a black metal rack, bassinet and rattan-back high chair, guitars, family photo gallery,
hamster habitat with fish bowl, kitchen extension on the left, navy entrance door at the rear) — but designed
like a tidy, styled, modern home interior photographed for a magazine:

- NO clutter: no cables, routers, laundry, bags, boxes piles, toy piles, plastic bins in loud colors, papers.
  A few deliberate styled objects per surface. Toys live neatly in one woven basket, with a couple of balls on
  the rug inviting play.
- Coherent warm palette: cream/ivory, warm oak, walnut accents, gold-veined cream marble, chocolate leather,
  warm brown fabric, black metal accents, brass, deep navy (door + kitchen cabinets), sage/green plants.
  No saturated primary toy colors except small toys. Ceiling: smooth warm white (NOT the blue grid).
- Every hard edge bevelled (2–8 mm); soft goods (cushions, sofa seats) rounded and slightly puffy; wood grain
  and fabric weave via the shared material library; believable proportions (real-world metres).
- Lighting mood: warm evening interior (2700–3000 K downlights, warm LED cove/strip accents under the TV console
  and wall shelves like the reference, a lamp), soft contact shadows; desktop adds GI/AO.

## 4. Prop asset format (GLB + JSON sidecar)

Files: `game/assets/props/<asset_id>.glb` and `game/assets/props/<asset_id>.json`. `asset_id` is
snake_case and unique. One asset per GLB.

GLB conventions (Godot coordinates; Blender glTF export with +Y up does this conversion):
- Metres. Godot +Y up. **Front faces Godot +Z** (Blender −Y).
- Origin: `mount=floor|surface` → bottom-centre of the footprint (lowest point at y=0).
  `mount=wall` → centre of the back face (back plane at z=0, object extends toward +Z).
  `mount=ceiling` → top-centre (top at y=0).
- Root node named `<asset_id>`; visual meshes beneath it. No cameras/lights/empties needed in the GLB.
- Materials are named `M_<library_key>` (see §5). Do not embed textures in GLBs except unique art.
  The Godot loader replaces materials by key, so Blender materials only need approximate base colours.
- UV0: world-scale box/cube projection, **1 UV unit = 1 metre**, so tiling textures are scaled by the library.
  Unique-image materials (`M_photo_<n>`, `M_art_<n>`, `M_clock_face`, `M_screen`) use 0–1 UVs on their face.
- Smooth shading with sharp edges marked/weighted normals; no visible faceting on round objects.
- Triangle budgets: small prop ≤ 3k, medium ≤ 12k, large furniture ≤ 25k, architecture piece ≤ 60k.

Sidecar JSON (`schema: "interior.prop.v1"`), all coordinates in the GLB's local space:
```json
{
  "schema": "interior.prop.v1",
  "id": "coffee_table_marble",
  "label": "Marble coffee table",
  "dimensions": [1.60, 0.78, 1.28],
  "mount": "floor",
  "body": "dynamic",
  "mass_kg": 38.0,
  "physics_material": "stone",
  "center_of_mass": null,
  "grab": "drag",
  "rolls": false,
  "colliders": [
    {"kind": "box", "center": [0, 0.76, 0], "size": [1.60, 0.04, 1.28], "rotation_deg": [0, 0, 0]},
    {"kind": "cylinder", "center": [0, 0.37, 0], "radius": 0.18, "height": 0.74, "axis": "y"},
    {"kind": "sphere", "center": [0, 0.1, 0], "radius": 0.1},
    {"kind": "capsule", "center": [0, 0.3, 0], "radius": 0.05, "height": 0.4, "axis": "x"},
    {"kind": "hull", "points": [[0,0,0],[0.1,0,0],[0,0.1,0],[0,0,0.1]]}
  ],
  "tags": [],
  "anchors": {"top_surface": [0, 0.78, 0]}
}
```
- `body`: `dynamic` (normal rigid body), `static` (StaticBody3D on layer 2, never moves: architecture, TV,
  built-in cabinets, fridge), `wall_anchored` (frozen in place until the player grabs it, then dynamic).
- `physics_material`: one of `wood, stone, fabric, leather, plastic, metal, glass, ceramic, rubber, paper,
  foliage, cardboard, foam`. Friction/bounce/rolling resistance/impact sound come from this key.
- `grab`: `carry` (≤ 15 kg, lifted in hand), `drag` (heavy; dragged along the floor at the grab point),
  `none` (cannot be grabbed; still pushable if dynamic).
- `rolls`: true for spheres/cylinders/rings meant to roll (balls, fruit, cans, bottles, rings, pencils).
- Colliders: primitives preferred; `hull` ≤ 64 points for irregular small props. Colliders must hug the
  visible silhouette (no floating gaps > 5 mm under feet/bases, legs modelled as separate shapes so tables and
  chairs can tip realistically). `center_of_mass: null` = automatic from shapes; set it explicitly for objects
  with dense bases (fan, lamp, plant pot with soil).
- `anchors`: optional named points (e.g. `screen_center`, `led_strip_start`, `led_strip_end`, `photo_slot`,
  `light_<n>`) used by integration for lights and attachments.
- Architecture assets (`arch_*`) use `body: "static"` and box colliders for walls/floor/ceiling/counters.

## 5. Material library keys

`game/scripts/material_library.gd` (class `InteriorMaterials`) provides `static func material(key: String, mobile := false) -> Material`
for these keys (Blender uses `M_<key>`; the loader strips `M_` and any `.001` suffix). Unknown keys fall back to a
neutral material and print a warning.

Woods: `oak`, `oak_slat`, `walnut`, `rattan`, `bamboo` · Paints/finishes: `white_satin`, `white_matte`,
`warm_plaster`, `ceiling_white`, `navy_enamel`, `black_metal`, `brushed_steel`, `chrome`, `brass` ·
Stone/ceramic: `marble_gold` (cream marble with gold veins), `marble_floor`, `quartz_counter`, `tile_white`,
`tile_navy`, `grout`, `ceramic_white`, `ceramic_sage`, `terracotta` · Textiles: `fabric_brown`, `leather_brown`,
`linen_beige`, `linen_white`, `rug_wool`, `canvas_gray`, `sheer_curtain` · Plastics/rubber: `plastic_white`,
`plastic_black`, `rubber_black`, `toy_red`, `toy_yellow`, `toy_blue`, `toy_green`, `toy_pink`, `tennis_felt` ·
Glass/emissive: `glass_clear`, `glass_frosted`, `mirror`, `screen_off`, `led_warm`, `clock_digits`, `water` ·
Organic: `foliage`, `foliage_dark`, `soil`, `petal_red`, `petal_yellow`, `petal_purple`, `petal_white`,
`orange_peel`, `apple_red`, `paper`, `book_cover_a`, `book_cover_b`, `book_cover_c` ·
Unique images: `photo_0`…`photo_7` (owner's family photos `res://assets/family/family_<n>.jpg`), `art_0`…`art_5`
(generated abstract/botanical prints in `res://assets/art/`), `clock_face` (5:08 display), `screen` (TV/monitor
off-glass with faint reflection).
Per-instance photo selection: layout `overrides.photo` remaps every `photo_*` surface of that instance.

## 6. Runtime interfaces (GDScript)

### InteriorObject (`game/scripts/physics_object.gd`, owner: physics)
```gdscript
class_name InteriorObject extends RigidBody3D
signal impact(strength: float, at: Vector3, material: String)  # strength = contact impulse N·s, emitted ≥ ~0.05 N·s with cooldown
var prop_id := ""
var display_name := "Object"
var clue_digit := ""
var clue_text := ""
var discovered := false
var held := false
var anchored := false            # wall_anchored: frozen until grabbed
var grab_mode := "carry"         # carry | drag | none
var physics_material := "wood"
var rolls := false
var home_transform := Transform3D.IDENTITY
func configure(spec: Dictionary) -> void      # builds shapes, mass, material, damping from a sidecar dict; call BEFORE add_child
func activate(detach := false) -> void        # wakes; detach=true unfreezes wall_anchored
func recover() -> void                         # back to home_transform, zero velocity, reset interpolation
func rolling_speed() -> float                  # m/s of rolling contact motion (for audio), 0 if airborne
func is_supported() -> bool                    # has a contact below
```
All InteriorObjects join group `movable`. Bodies start **awake=false/sleeping** at their settled pose (no freeze
for floor/surface props) and wake on contact. Static props are plain `StaticBody3D` (layer 2) built by the same
module: `static func build_static(spec: Dictionary) -> StaticBody3D` in `game/scripts/prop_physics.gd`.

### Player (`game/scripts/player.gd`, owner: physics)
Keeps current public API: signals `grabbed(body)`, `target_changed(body)`, `console_requested`; members `camera`,
`held`, `target`, `playing`, `touch_move`, `touch_sprinting`, `touch_crouching`, `sensitivity`; methods `look()`,
`request_jump()`, `toggle_hold()`, `grab_object()`, `release_object()`, `throw_object()`, `inspect_object()`,
`reset_motion()`, `ray_hit()`, `update_target()`. Adds: `rotate_held(delta: Vector2)`, `set_fov(deg)`,
`throw_charge` (0..1, hold-to-charge on desktop: press LMB charge, release throws).

### Prop loader (`game/scripts/prop_library.gd`, owner: art pipeline)
```gdscript
class_name InteriorPropLibrary extends RefCounted
static func spec(asset_id: String) -> Dictionary                 # parsed sidecar (cached)
static func visual(asset_id: String, overrides := {}, mobile := false) -> Node3D   # GLB instance with library materials applied
static func spawn(asset_id: String, xform: Transform3D, overrides := {}, mobile := false) -> Node3D
	# returns InteriorObject (dynamic / wall_anchored) or StaticBody3D (static) with the visual as child;
	# caller adds it to the tree. overrides: label, mass_kg, body, photo, clue {digit,text}, tags
```

### Lighting (`game/scripts/room_lighting.gd`, owner: lighting)
```gdscript
class_name InteriorLighting extends Node3D
static func create(room: Node3D, layout: Dictionary, mobile: bool) -> InteriorLighting   # WorldEnvironment + lights + probes
func apply_quality(index: int) -> void     # 0 Low, 1 Medium, 2 High, 3 Ultra (Ultra desktop only)
func set_tv_glow(on: bool) -> void
```
Layout `lights` entries: `{"id","type":"spot|omni|directional|strip","position":[x,y,z],"rotation_deg":[x,y,z],
"color":[r,g,b],"energy":f,"range":f,"angle_deg":f,"length":f,"shadow":bool,"mobile":bool}`. `strip` = LED strip
(emissive bar + a few low-cost lights on desktop; emissive only on mobile).

### UI (`game/scripts/ui/game_ui.gd`, owner: UI)
```gdscript
class_name InteriorUI extends CanvasLayer
signal play_requested
signal resume_requested
signal restart_requested
signal quit_requested
signal quality_changed(index: int)
signal settings_changed(settings: Dictionary)   # sensitivity, fov, invert_y, show_fps, master_volume
signal unlock_attempted(code: String)
signal hold_pressed
signal throw_pressed
signal inspect_pressed
signal pause_pressed
var touch: InteriorTouchControls
func setup(player: InteriorPlayer, mobile: bool, control_lab := false) -> void
func show_menu(kind: String) -> void            # "home" | "pause" | "journal" | "console" | "settings"
func hide_menu() -> void
func is_menu_open() -> bool
func show_loading(progress: float, text := "") -> void
func hide_loading() -> void
func set_status(text: String) -> void
func set_notes(found: int, total: int) -> void
func set_journal_entries(entries: Array) -> void
func set_prompt(text: String) -> void
func show_toast(text: String, seconds := 3.0) -> void
func set_console_result(text: String, success: bool) -> void
func set_fps(fps: int) -> void
func set_quality(index: int, max_index: int) -> void
func set_hud_visible(visible: bool) -> void
```
`main.tscn` root `interior.gd` remains the game coordinator (mystery state, pause, restart, capture/benchmark
modes) and is owned by integration. Pause/menus use `get_tree().paused`; UI nodes use PROCESS_MODE_ALWAYS.

### Pets (`game/scripts/hamster_enclosure.gd`, `hamster.gd`, `aquarium.gd`, owner: pets)
```gdscript
static func HamsterEnclosure.create_habitat(parent: Node3D, xform: Transform3D, mobile := false) -> Node3D
```
Self-contained: builds its own tidy black-metal stand, three linked acrylic levels with tubes, three hamsters,
and the aquarium bowl(s) on the lowest shelf; returns the root (a heavy InteriorObject, `grab_mode = "drag"`, or a
StaticBody3D—pets decides and documents). Must not depend on `living_room.glb`.

### Layout (`game/assets/layout/room_layout.json`, owner: integration; draft by art director)
```json
{"schema": "interior.layout.v1",
 "spawn": {"position": [0.62, 0.05, 1.30], "yaw_deg": 0},
 "instances": [{"id": "coffee_table", "asset": "coffee_table_marble", "position": [x,y,z], "rotation_deg": [0,yaw,0],
                "overrides": {"photo": 3, "clue": {"digit": "0", "text": "..."}, "label": "..."}}],
 "lights": [ ... see lighting ... ],
 "pets": {"position": [x,y,z], "yaw_deg": 0}}
```
Room frame (Godot): floor y=0, ceiling ≈2.90, living room x∈[−3.4, 3.4], z∈[−2.8, 2.8]; TV wall at z=−2.8 (front
of furniture against it faces +Z); kitchen extension x∈[−5.65, −3.3], z∈[−2.7, 2.7] entered through an opening in
the left wall near z≈+0.6…+1.95; right wall x=+3.4 (photo gallery); rear wall z=+2.8 (navy entrance door, mirror,
instruments). Previous prop positions for reference: `room/room-layout.json` (Blender coords: godot = (x, z, −y)).

## 7. Mystery (unchanged gameplay)

Visible clock reads 5:08. Holding the clock (digit 5), the coffee-table plant (digit 0) and the small framed photo
on the TV console (digit 8) reveals three notes. Inspecting the TV opens the lock; code `508` with all notes solves
it. Restart reloads the scene.

## 8. Physics acceptance (Jolt)

1. A ball rolled across the floor at 2 m/s actually rolls (|ω·r − v| < 10 % after 0.5 s), travels > 2 m and comes
   to rest within 4–20 s via rolling resistance; never rolls forever, never jitters at rest.
2. A ball on a 10° ramp rolls down; a wooden box on the same ramp stays (static friction).
3. A tall narrow object pushed near its top tips over; pushed near its base it slides.
4. A knocked-over can/bottle lies on its side and rolls; rings roll on edge and wobble down.
5. A 5-block stack is stable at rest (asleep within 3 s, drift < 2 mm) and topples realistically when hit.
6. Furniture/tabletop props at scene start: asleep within 3 s, max drift < 3 mm, no jitter, no explosions.
7. A max-strength throw never tunnels through a 0.1 m wall (CCD); nothing exceeds sane velocity limits.
8. Player pushing: light props get shoved with momentum transfer at the contact point (they can tip); heavy
   furniture slides slowly with friction; nothing gets pushed through walls; the player can stand on sturdy props
   without jitter and is not launched by them.
9. Holding: held props follow smoothly with mass-dependent lag, collide with the world (never pass through walls),
   can be rotated, swing naturally; heavy `drag` props are dragged at the grab point; drop keeps hand velocity;
   throw adds mass-scaled impulse and some spin; obstruction beyond a limit releases the object.
10. Out-of-world or non-finite bodies recover to home; recover/restart reset interpolation.
11. Desktop budget: 80 awake bodies ≤ 2.5 ms physics step on the dev PC (Ryzen 7 5700X).

## 9. Quality tiers and performance

Tiers: 0 Low, 1 Medium, 2 High, 3 Ultra (desktop only). Desktop default High; Android default Low, max High.
Desktop target: High at 1920×1080 on RTX 4060 — p95 frame ≤ 16.7 ms during the 60 s `--benchmark` sweep.
Android: Compatibility renderer, ≤ 2 shadowed lights, render scale 0.65–0.85, 60 FPS cap; must launch and render the
room on the emulator if one is available (physical-device performance stays unmeasured; say so).

## 10. Process rules for every agent

- Own only your files (listed in your task). Read anything. If another component's file must change, describe the
  change in your handoff instead of editing it.
- Match the surrounding GDScript style: tabs, static typing with `:=`, short purposeful comments, snake_case.
- Verify with real runs; report exact commands and results. Do not claim checks you did not run.
- Worktree agents: commit your owned files to your worktree branch when done
  (`git add <your files> && git commit -m "<component>: <summary>"`), ending the message with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never commit `work/`, `.local/`, `builds/`, `.godot/`.
- Write `A:/3rd Harmonik/interior/work/v3/<component>/handoff.md`: what changed, files, how to run/verify, results,
  known gaps, interface deviations, and a **Screenshots** section listing every image you saved (path + one-line
  caption).

## 11. Progress screenshots (owner request, 2026-10-05)

The owner asked to receive screenshots as changes are made so they can follow along. Therefore:

- Every component that changes anything visible (assets, materials, lighting, UI, pets, room integration) saves
  real rendered screenshots of its work to `A:/3rd Harmonik/interior/work/v3/<component>/screens/` as it goes —
  at minimum one early "first working version" shot and one final shot per deliverable. Physics saves frame
  sequences or contact sheets of rolling/toppling/holding behaviour from a rendered sandbox run.
- Use PNG or JPG, 1280×720 or 1920×1080, real renders only (Godot window captures or Blender renders). Name files
  `NN-<what>.png` in the order produced (`01-coffee-table-first.png`, `02-coffee-table-bevels.png`, ...).
- Before/after pairs are encouraged when replacing something that existed.
- List them in the handoff's **Screenshots** section. The orchestrator forwards them to the owner while work is in
  progress; do not send files to the owner yourself.
