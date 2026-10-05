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

## Status when this was written

| Step | State |
|---|---|
| Plan and layout interpretation (below) | Done |
| 1. Hinged door | **Started.** `game/scripts/hinged_door.gd` (77 lines, uncommitted) is a door leaf on an `AnimatableBody3D` that swings about its hinge. It is not yet wired into the room builder; the doorway is not cut. |
| 2. Balcony, stairs, courtyard | Not started |
| 3. `balcony_integration` test | Not started |
| 4. Capture views and screenshots | Not started; nothing in `work/v4/balcony/screens/` yet |
| 5. Windows EXE | Not built. `builds/windows/Interior.exe` is still the 0.3.0 build from the previous run. |

A background workflow (`wf_69dfb815-b8e`: one builder agent, then one checker agent) was still running when this was
written. If it finishes, it commits on `polish-v0.3` and writes `work/v4/balcony/handoff.md`. **Check `git log f0b3d5f..`
and that file first.** If neither exists, the run died at the usage cap, and only uncommitted files remain in the working
tree.

The many modified `game/assets/**/*.import` files predate this work (Godot re-import churn). Don't commit them unless a
build needs them.

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
