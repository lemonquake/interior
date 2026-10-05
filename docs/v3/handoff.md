# Interior v0.3 — Overhaul Handoff

Branch: `polish-v0.3` (from `main` at 5e245ff). Contract: `docs/v3/contract.md`.

## Owner requests

1. "game look atrocious. polish it and completely improve the physics allowing objects to really roll over and
   realistically move. Do not make that messy interior design like in the reference. Overall SIGNIFICANT
   IMPROVEMENT. Then build the EXE and APK." (2026-10-05)
2. "Send screenshots as you make changes so I can follow, also write this in the handoff." (2026-10-05)
   - Every component saves real renders to `work/v3/<component>/screens/NN-<what>.png` (contract §11) and lists
     them in its own handoff.
   - The orchestrator watches those folders and forwards new screenshots to the owner as they appear.
   - Baseline sent: `work/v3/screens/00-before-v0.2.jpg` (current v0.2 look).

3. "continue. then make sure I have an editable Godot project, then compile EXE" (2026-10-05)

## Run 2 (2026-10-05): what happened

- Run 1's seven parallel builders all died at the owner's **Pro-plan 5-hour usage cap** about 12 minutes in, before
  committing. Their partial files were copied to `work/v3/salvage/` and the worktrees were removed. A 3-builder relaunch
  burned 24% of the 5-hour window in about 10 minutes, so it was cut back to two builders: look and physics, at medium effort.
- **Rescope:** rebuilding every prop in Blender (contract §4, the prop-loader/layout parts of §6) is **deferred**. This
  run upgraded the existing room in place.

| Phase | Work | Status |
|---|---|---|
| 0 | Engine switch (Jolt, physics interpolation, Forward+ desktop / Compatibility Android), contract | Done |
| 1a | Look: InteriorLighting, InteriorMaterials, warm-white ceiling, declutter, physics toys | Done (merged, `work/v3/look/handoff.md`) |
| 1b | Physics: Jolt InteriorObject, material table, rolling resistance, push/hold/rotate/charged throw, tests | Done (merged, `work/v3/physics/handoff.md`) |
| 1c | Editable project: room baked to `scenes/room/living_room.tscn`, instanced by `main.tscn` | Done |
| 1d | UI overhaul, audio bank, pets restyle | Not started (salvage in `work/v3/salvage/ui`, `/audio`) |
| 2 | New Blender prop set | Deferred |
| 4 | Windows EXE | Done: `builds/windows/Interior.exe` 0.3.0, SHA-256 `f1674cb1…e9dd037` |
| 4 | Android APK | Not built this run |

## Editable project

- Open `game/project.godot` in Godot 4.7.2. `main.tscn` instances `scenes/room/living_room.tscn`, which holds the whole
  room as nodes: 48 original props as `InteriorObject` bodies with their colliders, the kitchen, rear and right walls,
  lights and the WorldEnvironment. Meshes, materials and textures are standalone files under `assets/baked/`, so they can be
  edited in the inspector.
- **The scene is now the source of truth.** `game/editor/bake_room.gd`
  (`godot --headless --path game --script res://editor/bake_room.gd`) regenerates it from `room_builder.gd` and
  OVERWRITES manual edits. Only re-run it after changing the builder code.
- The bake drops loose props onto their supports. Unstable heavy furniture is anchored until grabbed: currently
  `computer_desk_6`.
- Hamsters and aquariums are rebuilt at runtime by `InteriorPetSpawner`. The scene keeps a static `...Preview` copy so
  they are visible in the editor.
- `editor/compare_bake.gd` renders builder vs baked views. They matched pixel-for-pixel before integration.

## Verification (integrated, commit after 1d3e6d0)

Pass: room_integration, surroundings_integration, upgrade_integration, physics_integration, touch_integration,
tabletop_stability, movement_stress, hamster_stress, physics_rolling, physics_toppling, physics_interaction,
physics_perf. look_preview High: 4.3 ms median / 6.5 ms p95 at 1920x1080 on the RTX 4060. The EXE `--capture-review` run
renders every view, the menus, hamsters and aquariums with no warnings or errors.

**Fails: settling.** Everything is asleep within 3 s and there is no jitter at start. But light props whose authored
pose floats sink 5-16 mm at load (sofa cushions, two shelf plants), and the black storage rack moves 35 mm. When every
prop is woken at once, `potted_plant_38` falls off its shelf.

## Known gaps / next run

- UI is still the v0.2 menu: dark panel, no Settings screen, no keypad. Salvaged theme and icons are in `work/v3/salvage/ui`.
- SDFGI, SSIL and reflection probes are disabled on every tier (they caused artifacts). Compatibility/mobile looks flat.
- Audio is still the v0.2 synthesised tones. `work/v3/salvage/audio/make_audio.py` is untested.
- Android APK not rebuilt for 0.3.

## Screenshots sent to the owner

| File | What it shows |
|---|---|
| `work/v3/screens/00-before-v0.2.jpg` | Baseline: current v0.2 captures |
| `work/v3/look/screens/01-first-light.png` | Look builder first light (too dark, being tuned) |
| `work/v3/look/screens/05-before-after.png` | Before/after: room views |
| `work/v3/look/screens/06-before-after.png` | Before/after: right wall, table, sofa |
| `work/v3/look/screens/03-high-room-wide.png` | High tier, room-wide |
| `work/v3/screens/10-integrated-high.jpg` | Integrated game from the baked editable scene, High |
| `work/v3/screens/11-exe-smoke.jpg` | Exported EXE: menu, play, hamsters, aquariums, pause, notes |
