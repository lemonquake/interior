# Build output

- Always replace the main Windows build at `builds/windows/Interior.exe` when building an update.
- Do not create alternate executable builds such as `Interior-room-update.exe`.
- If the main executable is running and prevents replacement, close that game process as needed to update the main build.

# The NOW standard (performance first, owner's rule since 0.66)

The game only pays for what the squad is doing now. "ULTRA SMOOTH ... BLAZING FAST in all the scenarios" on PC and
phones is the bar for every change, not a polish pass at the end.

- **Behind the squad is gone.** Every chapter or area ends at a seal the story explains (a gate rolls shut, a shutter
  is padlocked, a rear gate is chained), and on every peer what lies behind it is put away: hidden, processing off,
  its dead and infected freed, its meshes let go of (`mission._soft_unload(..., sliced = true)` during play, or in
  one go behind a chapter screen). A new area is not finished until it has its seal and its unload. Current seals:
  the Old Salmonan gate (chapter one, `_road_seal_check`), the mart's shutter (board), the service gate (backstreets),
  Rommel's gate (`school_shut`), PILCST's rear gate (city board). Outer Street hides its districts by viewpoint
  (`outer_street._view`).
- **Ahead is not built until it is needed.** Districts ahead are built or woken at a chapter board or just before the
  squad reaches them (`wake_ahead`, `build_outer_street`), never at the start of the run.
- **No frame carries bulk work.** Spawns made in bulk go through `mission.later` (a few a tick); unloads are sliced
  (`UNLOAD_BUDGET_MS`); a client builds at most `session.NEW_PER_SNAPSHOT` new figures per snapshot; anything that
  would take more than a couple of milliseconds at once is split or moved behind a loading screen.
- **Never by cutting physics, gore or AI.** Ragdolls, bodies, hit boxes, wounds, blood amounts, AI tick rates and
  the physics rate are untouchable. Frame rate comes from drawing, processing and loading less of what is not now.
- **Measure before and after.** `tests/coop_perf_sweep.gd` walks the whole run (rendered, uncapped) and prints fps,
  1% low, worst frame, draw calls and where the long frames went; run it on PC (Forward+, High, 1920x1080) and in
  phone mode (`--rendering-method gl_compatibility -- --mobile-test --render-size=1600x720 --quality=0`). Targets:
  PC median ≥ 144 fps and no frame over 25 ms; phone mode a steady 60 with no frame over 33 ms. Report the numbers
  for the places a change touches.
- **Mission checks run every time.** `python -I tools/run_mission_suite.py` runs every squad-game test (triggers,
  debug jumps, walks, chapters, seals). A new trigger needs a line in `mission._settle` and a check in
  `tests/coop_jumps.gd`.
