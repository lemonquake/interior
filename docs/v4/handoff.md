# Interior: openable door, balcony and stairs (handoff)

Branch: `polish-v0.3` (last commit before this work: `f0b3d5f`). Written 2026-10-05, when the owner was nearly out of
credits. Previous run's handoff: `docs/v3/handoff.md`.

## Owner request (2026-10-05, verbatim)

> The 1st picture as you can see is the blue door for reference. If you open that, it should look like the 2nd image
> where we can see a balcony with an aquarium beside the shoe rack. 3rd image shows the front of that where we can have
> a clear view of the aquarium in front view then the blue door at the right. Then if you turn around, you will see the
> 4th image which shows a stairs going down (just remove those laundry). Lastly at the 5th image you can see downstairs.
> then build the EXE

Reference photos are saved locally at `work/v4/reference/1.webp` … `5.webp`. `work/` is gitignored, so they exist only
on this machine.
1. Current game: the navy door seen from inside.
2. Real: the door open, looking out at the balcony.
3. Real: on the balcony, facing the aquarium end wall, with the door on the right.
4. Real: turned around; the balcony continues to stairs going down. Remove the laundry.
5. Real: looking down the concrete stairs to the ground floor.

Earlier owner rules still apply. Keep it tidy; don't copy the reference's mess. Send progress screenshots while working
and list them in the handoff.

## Status: done (2026-10-05)

The background workflow `wf_69dfb815-b8e` (one builder, then one checker, medium effort) finished. The detailed agent
handoff is `work/v4/balcony/handoff.md`, with Build and Check sections; it is local only because `work/` is gitignored.

| Step | Result |
|---|---|
| 1. Hinged door | `scripts/hinged_door.gd`. Hinge at (2.43, 0, 2.6335). It swings inward to -88° over 0.6 s and stops clear of the TV cabinet. E toggles it, or the Android Hold/Drop button, and the prompt reads "E • Open door". It works when aiming at the leaf or through the open doorway. The door yields to the player and never pushes them, and slows to 30% when it touches a loose prop. Restart closes it. "Rear wall east" is split around a real doorway. |
| 2. Balcony, stairs, courtyard | Built by `scripts/balcony_builder.gd` and baked by `editor/bake_balcony.gd` into `scenes/balcony/balcony.tscn` (assets in `assets/baked/balcony/`, textures in `assets/balcony/`); `main.tscn` instances it. The structure is 28 material batches (36k triangles). Furniture is named nodes. The aquarium has 5 fish (rectangular-tank mode in `aquarium.gd`). There is one smooth ramp collider under the stairs, plus invisible bounds and a lid. |
| Lighting | Outdoor meshes are on visual layer 2, and the Sun, SkyFill and GroundBounce lights only light layer 2. `scripts/balcony.gd` hides the balcony while the door is closed and the camera is indoors. With the door closed the room renders as before, including on Low. Sun shadows are off on Low and on Android below High. |
| 3. Tests | The new `balcony_integration` (63 checks) walks the real player from the room through the door, along the balcony, down the stairs, around the courtyard and back. It also covers the door closing on the player or a prop, the touch path and Restart. It is in `tools/build.ps1`. These all pass: physics_integration, room_integration, tabletop_stability, movement_stress, hamster_stress, surroundings_integration, upgrade_integration and touch_integration. `settling` still fails but is not worse: start drift is 20.75 mm against a 34.8 mm baseline. |
| Perf | look_preview at High, 1920x1080, RTX 4060 (median / p95): door closed 4.27 / 7.19 ms, door open 4.59 / 7.66 ms, on the balcony 2.51 / 5.50 ms. |
| 4. Captures | `--capture-review --capture-views=balcony` renders six views that mirror photos 1-5, plus the courtyard looking up. `--no-balcony` turns the balcony off for A/B renders. |
| 5. Windows EXE | Built: `builds/windows/Interior.exe`, SHA-256 `1193eef100b7b37ab3cc2e1f65a2dbcdba696340f609f38aec378621c59821fd`. Exported with the direct Godot command in "How to resume" step 4. The EXE's own capture run rendered all six balcony views with no errors or warnings in its log (`work/v4/balcony/screens/40-exe-smoke.jpg`). Android APK not rebuilt. |

Commits: `70063b1`, `a594e3b`, `cd63853`, `6a8dbfc`, `76b5958` (builder); `6d8c519`, `4ffb22c`, `58a47a9` (checker).

### Known gaps

- The stairs use one smooth ramp collider, so near the top the player and props ride up to 18 cm above the treads.
- Room lights are masked off the outdoor layer, so no warm room light spills onto the threshold. Props carried outside
  get ambient light only, not sun.
- The game doorway is narrower than the real one, so the photo-2 view shows less of the shoe rack.
- There is no outdoor audio and no animated foliage. The many `*.import` files are still modified and uncommitted.
- `builds/windows/README.txt` still says 0.2. It is written by `tools/build.ps1`, which this export bypassed.

## Known geometry (metres, Y up, room floor y=0)

- The room comes from `game/scripts/room_builder.gd` and `room_surroundings.gd`. It is baked into the editable
  `game/scenes/room/living_room.tscn` by `game/editor/bake_room.gd`. The scene had **no manual edits** at `f0b3d5f`, so
  re-baking after builder changes is safe. `game/editor/compare_bake.gd` renders builder and baked views side by side.
- The navy door is built in `_build_rear()` at x=-1.91 and then **mirrored in X** by `_build_rear_mirrored()`. In the
  game it spans x=+1.39..+2.43, with the slab at z≈2.66. The knob is at x=+1.50, which is screen-right from inside
  (facing +Z, screen-right is -X). The hinge therefore goes on the x≈+2.43 side. The white TV cabinet is just
  screen-left of the door, so clamp the inward swing to stay clear of it.
- Directly behind the door is a solid box, "Rear wall east", in `_build_shell()`: centre (2.0,1.45,2.8), size
  (2.6,2.9,0.2), with a collider. Cut a doorway by splitting it into left, right and header pieces. The wall's outer
  face is at z=2.9. Don't touch the studio alcove (x -3.33..-1.18, z 2.8..4.0).

## Layout interpretation (from the photos)

- **Door:** hinged and swinging **inward** into the room, as in photo 2. E toggles it (the Hold/Drop button on Android)
  when the player isn't holding a prop. It starts closed and resets on Restart.
- **Balcony:** a strip along the outside of the rear wall, roughly x 0.95..5.5, z 2.9..4.75, floor y=0, with pale marble
  tiles and a roof slab. Stepping out of the door you face the railing, and the **aquarium end wall is on your right
  (-X)**, about 0.3 m from the door.
  - **End wall:** white plaster, with a navy-framed window and "WORTHWHILE" and "Loves" plaques above it. Ring planters
    with pink flowers hang on both sides. The aquarium sits on a damask bench and holds coral, plants, a toy boat and a
    filter box; reuse `scripts/aquarium.gd` the way `pet_spawner.gd` does. A wooden flower vase and a white 5-tier shoe
    rack stand in the corner by the door.
  - **Railing side:** a white steel railing on a concrete ledge, with a frosted floral screen above it and a sunflower
    and wisteria greenery panel. Add two rattan chairs. No laundry.
- **Stairs (photo 4):** walking +X, the house wall turns yellow with maroon-framed windows. A straight concrete stair
  (about 0.95 m wide) runs down along the wall, with a white handrail, an orange PVC conduit and a doormat at the top.
- **Courtyard (photo 5):** one storey down, with ground at about y=-2.9 (16 risers of 0.18 m). It has a concrete floor,
  a white grille fence, and a neighbour's wall with a caged AC unit.
  - Keep it **tidy**: a neat ladder, one plastic-covered cabinet and a stack of planks.
  - The backdrop is cheap and purely visual: roofs, trees, a utility pole with wires, and sky.
- **Must-haves:**
  - A smooth ramp collider under the stairs, so the player can walk both up and down.
  - Invisible walls above the railings and around the courtyard, so neither the player nor thrown props can escape.
  - Daylight on its own visual layer and light cull mask, so it **doesn't leak into the room**. Low tier has no shadows.
  - The room must look unchanged with the door closed.
  - It must work under the Compatibility renderer (Android).
- **Editable:** put the balcony in its own baked scene (for example `scenes/balcony/balcony.tscn`). Batch the static
  structure by material and keep the furniture as named nodes.

## How to resume

1. Check `git log f0b3d5f..`, `git status` and `work/v4/balcony/handoff.md` to see what landed.
2. Continue from the first unfinished step above. The full agent brief is in the workflow script:
   `C:\Users\Lemon PC\.claude\projects\A--3rd-Harmonik-interior\00e6da5d-aff5-4859-86ca-899b7e6c09b5\workflows\scripts\balcony-stairs-wf_69dfb815-b8e.js`.
3. Tests: run the suite listed in `tools/build.ps1`, plus the new `balcony_integration`. `settling` was already failing
   (see `docs/v3/handoff.md`) and must not get worse.
4. To build the EXE without Android, import with
   `.local\tools\Godot_v4.7.2-stable_win64_console.exe --headless --path game --editor --import --quit`, then export with
   `... --headless --path game --export-release "Windows Desktop" builds\windows\Interior.exe`.
   `tools/build.ps1` stops at the failing `settling` test, so the last run exported the EXE directly.
5. Usage: the owner is on Pro, and weekly usage was **82%** at the start of this run. Use one agent at medium effort
   with incremental commits.

## Screenshots sent to the owner

| File | What it shows |
|---|---|
| `work/v4/balcony/screens/01-door-open.png` | The navy door opened inward on its hinge; the doorway is still dark, with no balcony yet |
| `work/v4/balcony/screens/02-blockout-sheet.png` | First pass, six views: door closed and open, aquarium wall, toward the stairs, down the stairs, courtyard looking up |
| `work/v4/balcony/screens/03-blockout-stairs-down.png` | First pass: looking down the stairs to the courtyard |
| `work/v4/balcony/screens/10-photos-vs-game.png` | Owner photos against the game for all five shots (second pass) |
| `work/v4/balcony/screens/09-courtyard-up.png` | Courtyard looking back up the stairs |
| `work/v4/balcony/screens/11-compatibility-low.png` | Compatibility renderer on Low tier (Android path) |
| `work/v4/balcony/screens/30-compare.png` | Checker's final pass: owner photos against the game for all five shots |
| `work/v4/balcony/screens/25-final-courtyard-up.png` | Checker's final pass: courtyard looking back up the stairs |
| `work/v4/balcony/screens/40-exe-smoke.jpg` | Six balcony views rendered by the exported Interior.exe |
