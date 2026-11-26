# 0.61 handoff: chairs no longer block PILCST doorways

Owner (screenshot of a classroom doorway heaped with chairs): the player had no way past; E and T did nothing.

## What changed
- `scripts/player.gd`: if you keep walking into school chairs (layer 32), or stand on them, and hardly move for
  0.35 s, you walk through them (`_wade`, collision exceptions), the same way the infected already do. Once you're
  wading, the next chair in the heap doesn't stop you again. A chair blocks you again once it's 1.1 m away from you.
- `scripts/coop/mission.gd` `shove` (T): school chairs get about 6 m/s forward and 2 m/s up (before, they got the
  table nudge of 1.6 m/s). Up to 24 bodies, before 8.
- `scripts/coop/school_props.gd`: `woke(i)` lets the shove mark a chair as moving.
- `scripts/coop/school.gd` `_commit`: no chair is built in a classroom doorway (1 m either side of its middle,
  1.9 m into the room, 1.3 m into the corridor; `_door_lanes`). No corridor chair is built inside a desk wall
  (`HALL_BLOCKS`): woken, those burst out (`school_chairs_settle` failed on some seeds). Chairs are taken out after
  the build, so the rng order is the same.
- Version 0.61.0 (project.godot, export_presets.cfg). Exported to builds/windows/Interior.exe + .pck,
  Sleep-0.61.0-windows.zip. Note: the first export of this run still had 0.60.0 in the presets, so
  Sleep-0.60.0-windows.zip was overwritten with this build.

## Tests
- `godot --headless --path game --script res://tests/school_doorway_jam.gd [-- --shots=<dir>]` (new): no built chair
  in a doorway, walk through 14 chairs jammed in a doorway (about 2.2 s, 3/3 runs), waded chairs block again, T
  moves 6+ chairs more than 0.5 m (7-12 seen). Prints DOORWAY_JAM ok|FAIL.
- `school_chairs_settle.gd`: ok on 3 of 4 seeds. On the 4th, one chair on the east stair spill at floor 3 slid
  26 cm down a flight, just over the 25 cm limit (the 0.59 stair-chair case; not touched here).
- `coop_shove_debug.gd`: ok (11 checks).
- The EXE start-up report ran (exit 0). The EXE has no co-op capture mode, so the doorway shots are rendered from
  the project.

## Screenshots sent
| file | what |
|---|---|
| work/v61/doorway/3-before-T.png | test doorway jammed with chairs |
| work/v61/doorway/4-after-T.png | after T |
| work/v61/doorway/2-wading-through.png | walking through the heap |
