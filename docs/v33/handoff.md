# Sleep 0.33 — the body, the senses, the place

Owner request (2026-11-17): ten big improvements and a fix for "massive lag + game crash when looking side to side
too fast". The plan was approved with amendments: no infected placed in the real game yet ("there will be a story -
this is not an arcade zombie shooter"; they stay in the debug menu), they are blind in the dark, they hear, a slow
walk, a limp when critical, no rain, movement polished "to the max details".

The work ran over two sessions (the first was cut off mid-way through the senses). This file records where it stands.

Build: `builds/windows/Interior.exe`, 0.33.0, exported 2026-11-17 07:32,
SHA-256 `02430c27ab184de152a5d14abc744106df81d82608d63caf5bf663366c8b07f6`.

## Done and in the EXE

| # | Item | Where | Test |
|---|------|-------|------|
| lag, 1 | Fast-look freezes, crowd cost, outdoor frame rate (first session) | `performance.gd`, `zombies.gd`, `neighborhood.gd` | `tests/fast_look_probe.gd` |
| 6, 10 | Blind in the dark and docile there; they hear steps, landings, thrown things, glass; Ctrl walks slowly and quietly; lamps and bulbs can be shot out | `senses.gd`, `zombie.gd` | `senses_integration` (29) |
| 8 | The body in danger | `body.gd`, `player.gd`, `zombies.gd` | `body_integration` (32) |
| 9 | Movement: lean, climb, vault | `player.gd`, `gun.gd` | `body_integration` |
| 5 | Rounds go through thin cover; rounds, sound and hands ignore the world's unseen walls | `gun.gd`, `surfaces.gd` | `pierce_integration` (10) |
| 4 | The infected find a way round | `zombie_nav.gd`, `zombie.gd`, `zombies.gd` | `nav_integration` (9) |
| 7 | The place is heard: measured rooms, slap-back, muffling behind walls | `sound_stage.gd`, `gun.gd`, `night_audio.gd` | `sound_integration` (13) |

### The body (`scripts/body.gd`)
- No health bar. A blow opens a wound that bleeds (never to death) until it clots (a bad one in about 40 s) or is
  bound: stand still, hold **H** for 2.5 s; the gun is down and does not fire meanwhile.
- Rest brings health back only to a ceiling; each blow lowers the ceiling, which returns slowly.
- Under 62 a limp starts on the side the blow came from. Under 35 (until back over 45) it is full: short hard steps
  on the bad leg, the pace sags on it, the lens dips and tips, no running, a poor jump, slower and lower climbs.
- The heart is heard when hurt or winded and the red edge beats with it. The edge is only an edge now: a lasting
  red wash over the whole picture was tried and thrown out (it fought the subtle look).
- Running empties the lungs in about 13 s; winded, the run is a jog. A fall of more than about 2.5 m hurts; any hard
  landing costs a moment's pace.
- **V** shoves: what stands within arm's reach reels back. Costs breath, one a second.
- Debug menu, Player tab, "Body": Hurt me 20, To critical (30), Heal me.

### Movement (`scripts/player.gd`)
- **Z / X** lean the head and shoulders (0.36 m, rolled), never through a wall; no sprinting while leaning.
- **Space** in front of something between knee and chest height (0.42 to 1.3 m) climbs onto it; off a jump the
  hands catch a ledge up to 1.05 m above the feet (so about 1.85 m from the ground). A low wall too thin to stand
  on (up to 1.05 m, ground within 1 m below on the far side) is vaulted, from the ground only. The eye sinks and
  the lens tips over the edge; the gun is down. Only the fixed world is climbed, never loose props, never an unseen
  wall. Arriving under a low roof leaves the player crouched.
- `--no-mantle` turns climbing off.

### Rounds (`scripts/gun.gd`)
- `COVER`: metres a pistol round gets through (wood .1, metal .11, glass .05, fabric .35); a weapon's `"bore"`
  multiplies it (rifle 2.2, buckshot .5, .338 3.5). Stone, concrete and earth keep every round. The round comes out
  with less, tears an exit hole, and goes on into whatever is behind (at most two covers).
- Rounds no longer stop on the unseen walls (`InteriorSurfaces.unseen`, `seen_ray`): the road and path edges in the
  fields, the "Bound" blocks, guards. Before, a shot across the paddies could stop in mid-air.

### The way round (`scripts/zombie_nav.gd`)
- Nothing baked: the ground is looked at where a search needs it (0.6 m cells, half-cell checks between them) and
  remembered. A* over that, one search a physics tick, asked for only when the straight way is shut or the figure
  has stopped getting anywhere. About 2 to 4 ms for a new 24 m way, under 2 ms once remembered.
- Rises are limited to what their legs take (a first version routed over a 40 cm ledge they could not step up).

### The sound stage (`scripts/sound_stage.gd`)
- The space round the lens is measured five times a second (13 rays): `roofed`, `walled`, `size`, `nearest`.
  Under a roof the gun's reverb is that room (the cellar and the tunnels used to count as outdoors) and there is no
  tail off the fields; between walls with open sky a shot slaps back after the time sound takes to go there and
  return; footsteps under such a roof get the room, not the town's echo.
- Every positional voice on the Gun, Steps and Master buses is muffled while fixed world stands between it and the
  lens (cutoff to 650 Hz, 7 dB down), and comes back in the open.

## Not done

- **2. Loading under 4 s.** The EXE still takes about 9.1 s to the menu. 3.7 s of that is before the scene builds
  (engine 1.1, files read 1.4, main scene read .8, instantiate .4); the rest is builders spread thin: decay and
  weathering .4, canal warren .4, hut and story .6, interactions and chairs .6, seals .35, siege perimeter .3,
  Nichols terrain .3, home exterior .25. Under 4 s needs the whole world as one baked scene, not three more districts.
- **Breakable window glass.** Panes are merged into the baked district meshes with no collider of their own.
  Needs the builders to record each pane (place, size) at bake time. Lamps and bulbs do break.
- **Breathing sounds.** None in the project; the heart is made in code. A CC0 recording would have to be downloaded.
- **Touch controls** for lean, shove, bind and slow walk (`touch_peek`, `touch_sneaking` exist; no buttons).
- **A walkability audit with climbing.** `seals_integration` and `siege_integration` pass, but `tests/world_audit.gd`
  fills by walking only. Vaults were restricted (ground only, 1 m drop) so a perch beside a town wall does not lead
  over it; nobody has yet walked the whole map trying to climb out.

## Tests

`python -I tools/run_tests.py` runs every `tests/*_integration.gd` (30). It prints "NO REPORT" for tests whose last
line is not `INTERIOR_*`: count PASS / FAIL in `work/v30/tests/*.log`. All pass. Three are sometimes flaky when run
three at a time and pass alone: `balcony` (max throw at the railing), `senses` (lamp light margin), `zombies` (a
rifle burst that takes two parts off, "The cut end is a stump").

## Captures (from the EXE, `-- --capture-review --capture-views=body`)

- `captures/body-01-lean-right.png`: X held in the lane by the gate.
- `captures/body-03-climb.png`: half way onto the kariton cart by the gate (the first real place found).
- `captures/body-04-after.png`: on a perch by the town's sheet wall, a metre up.
- `captures/body-07-critical-limp.png`: at 27 of 100, bleeding, the red edge.

These four were taken from the 07:28 export; the 07:32 export differs only in the vault limits.
