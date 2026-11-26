# Sleep 0.34 — what 0.33 left undone

Owner request (2026-11-17): "continue". This run took the "Not done" list of `docs/v33/handoff.md` in order of what
could be finished: breakable window glass, the loading time, the touch buttons, and the walk-the-map-trying-to-climb
audit. The audit found real ways out of the world; they are shut.

Build: `builds/windows/Interior.exe`, 0.34.0, exported 2026-11-17 10:52,
SHA-256 `a7351de789c9db9130039353a976b8545ac33123eef25fb611775f93a902723c`.

## Done and in the EXE

| Item | Where | Test |
|------|-------|------|
| Window glass breaks | `window_glass.gd` (new), `gun.gd`, `neighborhood_derelict.gd`, `senses.gd` | `glass_integration` (20) |
| Start-up 1.3 s shorter | `box_kit.gd` (new), `map_seals.gd`, `home_exterior.gd`, `neighborhood_interactions.gd`, `hut_house.gd` | load report |
| Touch buttons for the 0.33 keys | `mobile_controls.gd`, `player.gd`, `body.gd` | `touch_integration` (39) |
| Climbing cannot leave the world | `player.gd`, `surfaces.gd`, `map_seals.gd`, `tests/world_audit.gd` | `climb_integration` (18) |

### Window glass (`scripts/window_glass.gd`)
- The panes are part of merged meshes with no collider of their own, so the game keeps a list of where each one is
  and the gun asks it about every place a round lands (`pane_at`). 321 panes on the town's houses, 136 lights in
  the Nichols sashes (40 of those were built already broken and are openings from the start).
- **Town houses.** The panes are recorded while the facades are dressed (`neighborhood_derelict.gd`,
  "window_panes"). A front or back window is two lights either side of its mullion. One round breaks a light: a
  jagged hole with the dark of the room behind it, teeth of glass left standing in the frame, the pieces falling.
  The round stops in the house. Windows behind a sheet of roofing iron are left out; boarded ones break behind
  their boards.
- **Nichols house.** Four lights to a sash, real see-through glass. Each light's place is worked out from the
  window's record in `layout.json` the way the Blender script laid it, and its triangles are taken out of
  `house_glass` when it breaks. The round goes on into the room (or out of it); the next one goes through the
  opening as through air. Before, every Nichols window stopped every round, broken or not. The window's collider
  still stops feet and hands: nobody climbs in through a window.
- A thing thrown hard enough breaks a pane too. Breaking glass is heard sixteen metres off by the infected.
- Not covered: the louvres of the player's own house, the room's own windows and sliding door, the canal houses.

### Loading
- `scripts/box_kit.gd`: `SurfaceTool.append_from(BoxMesh.new())` makes each box on the graphics card and reads it
  back, about 0.8 ms a box. The map-seal fences (some 400 boxes), the home exterior and the town's gate leaves
  now turn the unit box's corners in script and go into their mesh in one piece. Seals .23 s to under .06,
  gates and chairs .66 to .12, home exterior .28 to .10 (project figures).
- `hut_house.gd` `_clear_approach` asked all 222,599 blades of rice and grass for their place one at a time to
  sink the ones on the hut's path (none are, the bake already left them out): half a second. It now skips every
  patch that does not reach the path and reads the others as one buffer: .67 s to .15.
- Tried and thrown out: turning the screen's sync off while loading. It made loading slower (the main thread
  then spun on the loading screen and took time from the threads reading files).
- **Still not under 4 s.** The EXE has its menu on screen 9.1 s after it starts (8.1 s in 0.30, before the glass, the zombies and the sound stage were added; 10.3 s in the project). 4.0 s of that is before a single thing is built (engine 1.2, reading a
  gigabyte of textures and models 1.3, the main scene .9, instantiating it .4). What is left of the builders is
  spread thin (canal .9, Nichols .8, siege .5, facades .4). Under 4 s needs either the world streamed in behind
  the menu (the districts are not visible from the room where the game starts) or all of it baked as one scene.

### Touch
- A third column on the right: **Slow** (a toggle, the quiet walk), **Shove**, and **Hold: bind** (only while a
  wound is open). **< Lean** and **Lean >** above the stick, each for as long as its finger is down.
- The APK has not been rebuilt since 0.8.

### Climbing and the edge of the world
`tests/climb_integration.gd` runs the walkability fill of `tests/world_audit.gd` over the whole world twice: on
foot as in 0.26, and with what the body of 0.33 can do: a jump up of 0.75 m, a step down of 1.2 m, and every
climb, catch off a jump and vault the player's own `_try_mantle` allows from each cell, eight ways round. The
first run found:

1. **A way out that was already there in 0.26.** Round the east end of the canal's south boundary wall a strip of
   the lane ran on behind it, and west of x -47 its lip was an open 0.8 m step down onto the bare plain south of
   the district: 11,800 cells of nothing, with 219 places to walk off the world. The old fill never stepped down
   more than 0.45 m and never counted a drop under 1.2 m, so it never saw where that led. Shut with a sheet fence
   (`map_seals.gd` EDGES).
2. Off the culvert headwall a jump caught the top of the canal's boundary wall (2.5 m), and from there the far
   side was the same plain. `InteriorSurfaces.NO_PERCH`: in the canal district and the warren nothing more than
   1.35 m above the lane is climbed onto.
3. The warren's boardwalk rails (1.2 m high, 0.4 m wide) could be climbed onto, and off the top of one the drop
   was into its drain, which leads out behind its walls. `InteriorSurfaces.rail`: a rail is vaulted where a vault
   is allowed, never stood on.
4. The lot walls of the town (0.18 m thick) could be taken end-on and walked along; four slits behind them were
   pockets with no way back. A climb now needs a foot's breadth of top either side of where the body will be.

After that: no edge to step off, no ground that can only be fallen into, every sealed place of
`seals_integration` still sealed, and what only climbing reaches is 460 cells of small perches (crates, carts, the
headwall, low walls) plus 230 cells upstairs in the west of the Nichols house (reached by a jump of 0.75 m
somewhere on the way up, not by a climb; inside the house, so not a way out, but nobody has looked at whether
upstairs was meant to be reached).

## Not done

- **Loading under 4 s** (above).
- **Breathing sounds.** Still needs a CC0 recording downloaded; not done without being asked.
- Glass in the player's own house and the canal houses.
- The Nichols upstairs question above. (Answered in 0.35: upstairs is meant to be reached, by the stairs; `nichols_integration` walks it. The audit's fill does not follow that stair on foot.)
- The Android APK.

## Tests

`python -I tools/run_tests.py` runs every `tests/*_integration.gd` (32 now). All 32 passed on 2026-11-17 after the last change to a script (logs in `work/v30/tests/`).

## Captures (from the EXE, `-- --capture-review --capture-views=glass`)

- `captures/glass-house-1-whole.png`, `-2-breaking`, `-3-broken`: a side window of a house west of street D.
- `captures/glass-nichols-outside-1-whole.png`, `-3-broken`: a ground-floor sash from the garden.
- `captures/glass-nichols-inside-1-whole.png`, `-2-breaking`, `-3-broken`: the parlour, from inside.
