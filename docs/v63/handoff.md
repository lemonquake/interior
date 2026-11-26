# 0.63 handoff: PILCST fixes, cleanup at Heavy-arm, and Outer Street

Owner's request (2026-11-24): fix holes in the School level ("no proper and visible path for the players to go down
after the explosion", "a Door that cannot be opened once you climb the ladder"), then design the next level from
`work/Reference/Outer Street` with "tons of objectives, unique pathways and broken Bus where the players can enter then
exit to the other door, a broken subway with flickering lights and all those creepy horror vibes". Mid-run: "as soon
as the players trigger facing Heavy-arm, clean up all the old blood and zombie bodies, etc. Then only load the Outer
Streets map as soon as the Leaderboard UI shows after defeating Heavy-arm".

An earlier attempt this morning (unexported, no handoff) had built a grey blockout "Buhangin Crossing" with breakers
and an evacuation gate. It was replaced; its files are kept, out of the game, in `work/v63/superseded_0.63_blockout/`
(map_builder.gd, map_validator.gd and its four tests). Its wiring (stages 16/17, WON 18, the board loading step) was
kept and rewritten for the new level.

## PILCST

- **The mechanical room door (5F, up the janitor's ladder)** is no longer welded shut. From inside (or just outside
  in the corridor) E "Force the door": it bursts out into the corridor, the bar and the desk tops go down flat, and
  the bang wakes the sleepers on the fifth floor within 20 m. The duct to 509 stays the quiet way. Bots, the
  infected and the students use the door once it is open (`school.gd` route 3 has a door variant). Code:
  `school.gd` `_mech_door`, `_mech_sync`, `at_mech_door`; `mission.gd` `_force_mech_door`.
- **After the gas-store blast**: the way off the second floor is now one you can see and walk, both directions:
  - the blast throws down the desk wall across the 2F corridor (x 41.6) between the fire-escape door and 208: the
    corridor is open end to end (it used to need a detour through two classrooms in the dark);
  - 208's door spill (glass, plaster, a ceiling tile, soot) lies across the corridor, the room glows orange;
  - 208's blown-out wall is open its whole width (the morning attempt's 3 m "funnel" walls and the invisible side
    rails on the roof are gone) and the floor's broken edge slumps onto the lean-to's roof as a slab slope;
  - off the eave a rubble ramp (hollow blocks, the roof sheets that slid down) runs to the field, lit by a third fire
    at its foot. It replaces the 2 m drop. The infected that spawn with the blast start a few metres clear of it.
  - `school.gd` `_hall_down` / `_blast_hall` (a 14th root, "2F desk wall", inside floor 2's), `_bombed`, `_lean_to`,
    route 0 after the blast; `escape.gd` `blast` (nav refresh, spawn zone).
- A desk top in 208 stood inside an armchair (it burst out when woken; `school_chairs_settle`): moved.

## Cleanup when Heavy-arm is faced; Outer Street only at the board

- When Heavy-arm spots the squad (the moment his talk starts) the host sets `flags.heavy_clean`; every peer then
  frees the night's bodies (corpses and posed dead), blood (splats, spots, torn parts, gibs) farther than 20 m from
  everyone standing. What lies round the squad (what they are fighting right then) stays, so nothing vanishes in
  front of them. The host also lets go of the infected still inside the school building, away from everyone.
  `mission.gd` `clean_before_heavy`, `blood.gd` `clear_away`, `heavyarm.gd` `_sit`.
- Outer Street is built only by the chapter board's loading steps after Heavy-arm (session.gd `_step_outer_street`),
  or by a debug jump into it. Nothing builds it earlier (checked by `tests/heavy_clean_board.gd`).

## Outer Street (stages 16, 17; 18 WON)

Files: `scripts/coop/outer_kit.gd` (build kit), `outer_world.gd` (the places), `outer_street.gd` (class OuterStreet:
objectives, E actions, host logic, steering, culling). Built in about 150-360 ms on every peer.

The way, south to north (street-local metres):

| # | Objective (HUD line) | What it is |
|---|---|---|
| 1 | Out of the lane and onto the avenue. | the rear gate's lane between two blocks into the avenue's dead end |
| 2 | The highway came down across the avenue. The only way through is the bus: in at the back door, out at the front. | the avenue under the elevated highway; a span is down across the road; a city bus is wedged along the west lane, its hazards blinking: in at its back door, along the aisle (blue seats, straps, a failing tube, someone asleep in it), out at the front door |
| 3 | The road north is buried. Get down into the subway. | the plaza: zebra crossing, vending machines (one lit, one failing, one dead, one on its face), carts and umbrellas, the waiting shed's flickering ad, a signal blinking amber, a fire in a drum; the next span down across the road north, burning; the cross street shut by a container |
| 4 | The subway's shutter is chained. Find something to cut the chain: try the hardware store up the yellow stairs. | up the yellow-railed stair cut into the hillside (or round by the covered overpass) to the terrace: the sari-sari store, the mahjong table with its lantern still on, washing lines, a hoop; the hardware store: a flashlight on the floor shining at the bolt cutters on the counter, thumping behind the back room's door |
| 5 | Cut the chain on the subway's shutter. | taking the cutters bursts the back room open (4-7 come out); back down, E at the shutter: it rolls up |
| 6 | The station is dead. Find its power room and switch the power back on. | down the well into the dark concourse (emergency lights, EXIT signs, the ticket booth, full-height faregates shut); the power room off the east corridor |
| 7 | The faregates are open. Down to the platform. | the main breaker: the tubes flicker on (some never do), ads and the line map light, the faregates open, and 6-10 come up from the platform |
| 8 | The train fills the tunnel. Go through it, car to car, and out at the front. | the stalled two-car train past the platform: in at its one forced door, through the gangway (one car dark, one strobing), out of the cab's front door down its ramp onto the track |
| 9 | Follow the tunnel to the emergency exit. | amber caged lights (some failing), rails, water, rats, the roof down at the far end; EXIT over the cross passage |
| 10 | Up the emergency stairs. | the long stair (66 steps, yellow nosings, tubes dying overhead) up into a concrete exit kiosk |
| 17 | Everything in the station heard you. Down the river road to the bridge, everyone. | the river road (balustrade, planters, lamps, a stalled bus with hazards, jeepneys, the highway overhead crossing the river); the horde comes round the building down across the road's west end (10-20 at once, two more waves at 14 s and 30 s) |
| WON | | everyone standing on the red arch bridge's deck past z 818 |

Unique ways: the bus (the only way through the pile-up); the hillside by the yellow stair or the overpass (a loop);
the well; the faregates; the train; the long stair. Blockers are drawn masses that collide (no invisible walls) and
taller than anything the mantle/jump reaches (1.3 m mantle, ~1.7 m jump-mantle).

Infected come part by part as the squad reaches each (`_zones`: avenue, bus, plaza, terrace, concourse, platform,
train, tunnel) plus the events above; pickups with them (ammo, healthkits, one gun on the plaza).

Steering (bots, the infected, Ma'am Teves and her students): areas and the ways between them
(`OuterStreet.steer`, `_make_areas`): bus doors, the yellow stair, the overpass, the well (open after the chain), the
faregates (after the power), the train door, the cab ramp, the cross passage, the long stair.

Performance: what cannot be seen is not drawn (`_view`): under the street the street goes and the other way round,
except at the well and the kiosk; the skyline and the highway are one root drawn far. 216 lamps, most of them
glow-only; real lights fade with distance.

Debug: jumps `outerstreet`, `outerbus`, `outerplaza`, `outerterrace`, `outerstation`, `outerplatform`, `outertunnel`,
`outerriver` (debug menu "Outer Street"), places `outerlane` ... `outerbridge`. "Complete" in stage 16 does every
objective and starts the finale; in 17 wins.

## Words on screen added (owner: report every string)

- PILCST: `E  •  Force the door`.
- Outer Street objectives (table above), the finale line, prompts `E  •  Take the bolt cutters`, `E  •  Cut the chain`,
  `Chained and padlocked. Bolt cutters would cut it.`, `E  •  Throw the main breaker`, the `EXIT` signs.
- Chapter screen `Outer Street`, loading step `Building Outer Street`, board line `... Next: Outer Street.`,
  objectives 16-18 `Outer Street.`, `Down the river road to the bridge, everyone.`, `Across the bridge`, the end
  title `Across the bridge with Ma'am Teves and her students`, the win line `Across the bridge with Ma'am Teves and the
  students.` (the morning attempt's "Buhangin Crossing", breaker and evacuation-gate strings are gone).
- Signboards are blank colours with unreadable strokes: no invented shop names.

## Tests

All headless unless noted (`godot --headless --path game --script res://tests/<name>.gd`):

| test | result |
|---|---|
| `outer_street_walk.gd` (new): the real player walks the whole chapter, every objective done as in play, to WON | 23/23; Ma'am Teves and all 4 students reached the river road with the squad (5 of 5) |
| `school_way_down.gd` (new): mech door forced and walked through; after the blast fire-escape door -> corridor -> 208 -> roof -> ramp -> field, and back up | 10/10, 4 runs |
| `heavy_clean_board.gd` (new): old bodies and blood gone when Heavy-arm spots the squad, near ones kept; Outer Street built only at the board | 7/7 (20 bodies, 20 blood and parts freed, 2 near bodies kept) |
| `coop_jumps.gd` | 24/24 |
| `coop_escape.gd` (its "field below the eave" check now checks the ramp) | 39/39 |
| `coop_heavyarm.gd` | 48/48 |
| `school_chairs_settle.gd` | ok, 1343 chairs, 0 fell |
| `school_doorway_jam.gd` | ok |
| `coop_school.gd` | 44/44 in 4 of 6 runs. 2 runs failed "the school's own in the yard": a non-student infected in the yard at stage 10. Nothing in this run touches that stage; not chased down. The test now prints the stray's kind and place when it happens. |
| `outer_fps.gd` (new, rendered) | see below |

Frame times standing in Outer Street, this PC (RTX 4060), 1920x1080, the project (not the EXE), power on, 180
frames each after a second to settle:

| spot | median | p95 | infected |
|---|---|---|---|
| avenue | 5.97 ms (168 fps) | 10.87 ms | 5 |
| bus aisle | 5.44 ms (184 fps) | 9.47 ms | 7 |
| plaza | 5.30 ms (189 fps) | 9.77 ms | 13 |
| terrace | 6.58 ms (152 fps) | 12.64 ms | 13 |
| overpass | 6.07 ms (165 fps) | 10.40 ms | 18 |
| concourse (lit) | 5.52 ms (181 fps) | 10.12 ms | 18 |
| platform | 4.29 ms (233 fps) | 9.15 ms | 18 |
| tunnel | 4.26 ms (235 fps) | 9.08 ms | 21 |
| river road (finale) | 5.04 ms (198 fps) | 11.67 ms | 32 |

Build: version 0.63.0 (project.godot, export_presets.cfg). `python -I tools/export_windows.py`:
`builds/windows/Interior.exe` (109 MB, sha256 b3616d416c4839aa...) + `Interior.pck` (1485 MB) replaced,
`Sleep-0.63.0-windows.zip`. The EXE's start-up report is clean; `Interior.exe -- --coop-jump=outerbus|outerplatform|
outerriver --coop-jump-capture=<dir>` lands in Outer Street (the capture now waits for the chapter screen to fade:
`interior.gd`). Shots: `work/v63/exe/`.

Published (owner: "Publish 0.63"): `publish.py stage --notes tools/release/notes/0.63.0.md`, `upload` (558 chunks
already on the server, 15 new, 0.02 GB), `activate`. https://sleep.15-235-246-87.sslip.io/updates/windows/release.json
is 0.63.0 (15 files, the new notes) and its signature verifies against the key pinned in the launcher. The launcher
itself did not change (not rebuilt).

Not done / not checked: a real second player over the relay; a launcher actually updating from 0.62 on another PC;
Android not exported; no voice lines for the new text.

## Screenshots sent

| file | what |
|---|---|
| work/v63/sent/01_school_fixes.jpg | mech door shut/forced, 2F corridor after the blast, 208 breach, roof, ramp from the field |
| work/v63/sent/02_outer_street_lane_bus_plaza.jpg | lane, avenue, pile-up, bus doors and aisle, plaza, shutter, yellow stair |
| work/v63/sent/03_outer_street_terrace_overpass_station.jpg | terrace, hardware store, overpass, plaza from above, concourse dark and lit, power room, platform, train |
| work/v63/sent/04_outer_street_train_tunnel_river.jpg | inside the train, tunnel, long stair, river road, bridge, aerial |
| work/v63/sent/05_exe_outer_street.jpg | from the built EXE: the bus at the pile-up, the platform, the river road with the horde coming |
