# 0.57 handoff: centred loading screen, physics classroom doors and chairs (synced)

Owner's request (2026-11-22):
- "at the main menu, the loading screen should be at center, not letting the player do anything yet unless
  everything is loaded, then show the main menu items after loading"
- "the open and half-open classroom doors are still frozen, with no collision. They need to become hinged physics
  doors you can push, close and drag."
- "Chairs: all 1,095 chairs still have no collision. They should become pushable physics props."
- "Both have to stay in sync between host and other players."

## Loading screen (scripts/loading_screen.gd, scripts/boot.gd)

- The 0.35 early menu (Play / Multiplayer / Options / Quit on the loading screen from 1.3 s) is gone. The screen is one
  centred column over the shaded menu still: the title block, the caption and percentage, the bar, a tip.
- Every key, click and pad input is swallowed (`_input` + `set_input_as_handled`) until the world stands; the screen
  is the last child of the root so it sees input first. Then it fades and the real menu is underneath.
- `--early-wish=play:ready` (tests) still works: `click` calls `press` directly once the world stands.
- Capture: `-- --capture-loading --capture-path=<dir> --load-quit` (work/v57/loading/).

- Owner (2026-11-22, angry): "A night in Davao City" above the title was never asked for. It came with 0.54's shared
  title block (scripts/ui_menu.gd) and is removed from the menu and the loading screen. Rule: no taglines or
  descriptions unless the owner gives the words; report every on-screen text added.
- Owner (2026-11-23): "DONT EVER PUT IN CORNY FILIPINO REFERENCES EVER AGAIN UNLESS IT'S DIRECTLY FROM ME". The
  loading captions "Digging the estero", "Unlocking the Nichols house" and "Raising the yero wall" (from 0.30) are
  removed; while those parts load the caption stays on the one before or reads "Closing the gaps".

## Doors and chairs (scripts/coop/school_props.gd, new)

What has a body now (seed 57: 1,424 chairs, 22 open/ajar doors, 9 leaves off their hinges, 22 shut-door slots;
the chair count changes with the run's seed, the owner's 1,095 was one run):
- **chairs**: RigidBody3D, 6.5 kg, three boxes (legs+seat, back, writing arm), collision layer **32** (new: nothing
  else uses it). Still drawn by each floor's MultiMesh; an instance follows its body when it moves. Rounds pass
  through (gun.gd MASK has no 32); players (player.gd mask now 6|32), infected (figure.gd mask 2|4|32), doors,
  T shove (mission.gd 4|32) and grenades (grenade.gd 4|1|32) all meet them.
- **classroom doors left open or ajar**: RigidBody3D leaf, 16 kg, on a HingeJoint3D at the frame (hinge 0.14 m inside
  the frame's depth so the leaf never touches the posts), swinging into the room only, 0..1.75 rad. Layer 4, like the
  store's tables. Jolt measures the hinge angle from the pose the leaf has when the joint is made and opposite to +Y:
  the leaf is built where it was left and the limits are set from that (work/v57/hinge_sign*.gd).
- **leaves off their hinges** and **shut doors once they come off** (school.gd `_break` fills a slot reserved at build).

How it plays:
- Walk into a chair or door: it is pushed at your walking pace (player.gd `prop_push_hook` -> session `_prop_push` ->
  host `intent` -> impulse against the body's real motion, as `_push_contacts` does for solo props). A chair is
  pushed through its middle's height, so it slides instead of tipping; one lying on the floor is kicked along.
- Hold E on a chair or door: drag it by the point you hold (host `grab`/`release`, the store tables' spring). You are
  not bumped by what you drag, and walk at 80 %.
- Tap E on a door: it swings shut, or open (1.45 rad) if shut. A chair or a crowd in the way stops it.
- The infected shove chairs and doors aside at their walking pace (no lean/bash as with tables).
- The infected walk into chairs and doors when hunting and when marching or wandering (figure.gd `_shove_light`;
  the march path uses the velocity it meant to walk at, before the slide). One lying on the floor is kicked along;
  one that will not go (a heap shoved against a wall, a broken leaf leaning there) is waded through after half a
  second stuck on it (a collision exception for 1.5 s, `_wading`): a crowd tramples it.
- Bodies start asleep (put to sleep on the first physics ticks: Jolt wakes every new body) and stay as they were left,
  piles and stair barricades included, until something touches them.

Sync: the host simulates; every other peer has the same bodies frozen (kinematic) and eases them to the host's
transforms (`state` / `apply`, slot 15 of the session snapshot, 8 floats per prop, moving ones first, then each settled
prop 4 more times, then 6 that ever moved in turn). A client's pushes go to the host with its pose
(`push_props`, unreliable, checked within 2 m of the sender); its E goes as `prop/<i>/<grip>` and `letgo`.

## Checked

- tests/coop_school_props.gd, two processes over loopback (host `--network-host --sync=<dir>`, client `--peer
  --sync=<dir>`): host 27/27, client 8/8. Tap shuts and reopens, walk pushes a shut door open (and kicks the two
  chairs lying in that doorway through), Hold E drags a door round and a chair along, the chair slides upright and
  the player does not pass through it; the client has the host's props to 0.000 m; the client's own walk into a chair
  moves it on the host and back on the client, and both agree where it ended.
- tests/school_props_awake.gd: 0 props awake after a jump (212 before the sleep fix).
- Frame rate (tests/school_perf.gd, rendered, quality 2), with chair bodies vs `--no-chair-bodies`: no measurable
  cost (lobby 116/117, 2F 71/67, 3F 71/70, 5F 66/66, students coming 35/35, shooting 37/32; this benchmark varies by
  +-10 fps run to run).
- After the infected learned to shove chairs (see below): coop_escape 38/38 three runs running (it failed every run
  before: the horde marched into chairs and a broken door leaf and stood there), coop_school 44/44 (one earlier run
  failed "the school's own in the yard (6)", a non-student in the yard; 2 reruns passed), coop_integration 39/39,
  coop_squad 27/27, coop_backstreets 9/9, coop_jumps 24/24, coop_school_props host 27/27 + client 8/8.
- Full suite (tools/run_tests.py, then one at a time): everything passes except three checks that are not from
  this change: arsenal_integration "both are driven back" (the T shove's second infected moves 1-4 cm) and
  body_integration "...back out of reach" (solo shove) both fail the same with the 0.57 collision masks reverted;
  upgrade_integration "Restart must have stable node allocation (10058, first 10056)" is about the solo room
  (nothing of 0.57 is built there). Not investigated further. The suite's parallel run times co-op tests out (one
  ENet port): run co-op tests one at a time.

## The build

- `builds/windows/Interior.exe` + `Interior.pck` 0.57.0 (2026-11-22 23:40), `Sleep-0.57.0-windows.zip`, exported with
  `python -I tools/export_windows.py`.
- Checked from the EXE itself: `--capture-loading` (work/v57/exe/loading/, centred screen) and `--capture-review
  --capture-views=coop_school` (work/v57/exe/school/, 20 views, school built in 457 ms with the props).
- Start-up in the EXE (warm): engine 1.2 s, files read 9.0 s, menu on screen 16.9 s. Since the loading screen now
  takes no input, that whole time is a wait. The 0.30 note of "menu at 8.1 s" is long out of date (the .pck is
  1.5 GB now); making it faster is its own job.

## Gotchas

- The host ignores a client pose more than 10 m from the last one (`record_pose`): a test that teleports a client must
  move the host's record too.
- A crowd of infected hunting the player at a door shoves it about (as it should): door tests clear the infected.
- A jump into the college runs the chapter screen's catch-up: the player does not move until `session._catching` is
  false.
- `--no-chair-bodies` (measuring only) skips the chair bodies.
- A Jolt body is taken into the world awake on its next step whatever `sleeping` said before: put new bodies to
  sleep a couple of physics ticks later (`_bed`), or 212 chairs wake at build and the stair barricades creep.
- Something lying low is met by a capsule's round foot from above (normal up): push code that skips "standing on
  it" contacts must still kick a low prop along, for the player and the infected.
- Diagnostics kept: tests/school_props_awake.gd (props awake per second after a jump), tests/school_horde_trace.gd
  (`-- --seed=<n>`: where the fifth floor's horde stops and what each stuck one touches).
- Rendered test shots: `coop_school_props.gd -- --shots=<dir>` (windowed).

## Screenshots sent

| file | what |
|---|---|
| work/v57/loading/loading-03.png | the centred loading screen |
| work/v57/exe/exe_sheet.jpg | from the EXE: loading screen, a classroom with its door, two corridors |
| work/v57/shots/sheet.jpg | 2F door left open, tapped shut (prompt), walked open with the doorway's chairs kicked through, a chair under aim (prompt) |
