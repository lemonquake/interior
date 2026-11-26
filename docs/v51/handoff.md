# 0.51 handoff — PILCST made harder and darker (co-op school)

Owner's request (2026-11-21): the school needs much more: creepier, darker halls with flickering lights ahead, doors
breaking as lines of classrooms empty out, teacher infected (3 male, 3 female), janitors, other infected (parents),
a real fight to reach the fifth floor (barricaded ways, a ladder into the ventilation, an outside fire escape), and
resource cleanup so it stays smooth in multiplayer.

## The way up now (`school.gd` `UP`, `BLOCKED`, `route(k)`)

| From → to | Way | What stops the easy way |
|---|---|---|
| 1F → 2F | grand stair from the lobby | both side stairs blocked |
| 2F → 3F | **fire escape**: out the fire door at the east end of the corridor, two steel flights outside, in at the third floor's fire door | both stairwells blocked; the corridor is walled with desks at x 41.6, the way round is through 205 and the broken partition into 206 (`HALL_BLOCKS`, `BREACHES`); 205 is behind a shut door (it bursts) |
| 3F → 4F | west stair | east blocked; the whole corridor (labs) is walked from the fire door at the east end |
| 4F → 5F | **ladder + duct**: 406 is now the MAINTENANCE room; Kuya Boy's ladder goes up through a hatch into the fifth floor's MECHANICAL room (its door welded shut); the supply duct runs west along the back wall of 510 and 509 (1.2 m inside: crouch); its grille is kicked out in 509 | both stairwells blocked; the corridor is walled at x 17.4, round through 403 and 404 (both shut doors that burst) |

Notes at the foot of every blocked stair say where to go (fire exit, the west stair, Kuya Boy's ladder), and the
first arrival on the second and fourth floors puts a line on screen.

- **Players climb** the ladder (new, generic: `InteriorPlayer.ladders` [volume, wall normal, step-off spot]): face it
  and push forward to climb, back to climb down; looking down the hatch, forward goes down. At the top they are carried
  onto the floor beside the hatch. `player.gd _ladder`.
- **The infected and the squad AI** follow over every route: `school.steer` now walks `route(k)` (the fire escape's
  points, the ladder's foot and top, the duct). `school.carry(body, aim, delta)` climbs the ladder by hand (both ways);
  `school.squeeze(fig)` shortens an infected's capsule in the duct (crawl, 45 % pace); bots crawl at crouch pace and
  show "crawl". Crouched players show `crouch_walk` / `crawl` to the others.
- **Fire escape**: steel landings at 2F and 3F outside x 56..58.6, a switchback with a turn landing, rails (colliders);
  the flight from the alley lies torn on the paving, the one on up hangs off the 3F landing. A failing sodium lamp.
  `view()` treats it as inside.

## The creepy part

- **Dark halls**: corridor tubes ~60 % dead, 13 % hanging; a few stutter far ahead; each floor has a tube that hangs
  by one wire and **swings** (a shadowed spot light: the shadows move). One stuttering tube near the way on.
  Rooms are mostly dark too.
- **Shut doors that burst** (`AMBUSH`, 6 groups, 16 doors): pounding from inside when a survivor comes within 9.5 m
  (bangs, the leaf jumping in its frame), then the doors give one after another (1.4-2.2 s, then 0.7-1.5 s apart): the
  leaf is flung into the corridor as a loose physics body and 2-4 of the class pour out each. Groups: 204/205/210,
  304/305, 301/302/303, 403/404/405, 502/503/504, 507/511. **Scare doors** (`SCARES`: 201, 208, 401, 402, 505,
  506) only pound for a few seconds as you pass, once, and stay shut. Host decides (`mission._doors_tick`):
  `flags.pound`, `flags.broke`, `flags.fired` are bit masks over `school.doors`; every peer shakes/breaks its own copy.
  Spawn points behind a shut door are not used until it breaks.
- **A class still standing**: on each floor above the ground, the first arrival puts 5-8 students standing in rows at
  their armchairs facing the board, their teacher at the front facing them, all dormant until they notice someone.
- **Kuya Boy** (janitor_s1) is in the mechanical room, feeding, when you come up his ladder.
- TVs on brackets showing static (animated noise, a hiss, a flickering blue light), chairs stacked under a pulled
  ceiling tile where students tried to hide in the ceiling, broken partitions with rubble, the corridor walls of desks.
- **The bell**: the first time a floor is reached the class bell rings through the building on the dying generator and
  sputters out (`assets/school/audio/bell.wav`, synthesised).
- More dead: a teacher in the faculty room, one in the computer lab, Ate Marites by the second floor's fire door,
  a student halfway along the duct (you crawl over them).

## New infected (`tools/blender/human/build_zombies.py`, INFECTED 67..74)

teacher_m1 (math, blue long sleeves, maroon tie, glasses), teacher_m2 (Monday barong, torn), teacher_m3 (P.E. coach,
maroon track jacket), teacher_f1 (maroon faculty blazer, pencil skirt, bun), teacher_f2 (chemistry, lab coat),
teacher_f3 (guidance, grey bob, cardigan), janitor_s1 (Kuya Boy, navy coveralls), janitor_s2 (Ate Marites, utility
polo). Parents/townsfolk reuse town variants (`mission.PARENTS`). School mix (`_school_kind`): students 66 %,
teachers 14 %, staff 7 %, parents 13 %. Teachers 2.2-3.1 m/s, staff 1.9-2.6 m/s and 1.45x health.
Previews: work/v44/zombies/teacher_*_front.png, janitor_s*; sheet work/v51/screens/staff_zombies_sheet.jpg.

## Resources (no physics cut: ragdolls and corpses untouched, MAX_CORPSES as before)

- `SCHOOL_CEILING` 34 infected alive at once; trickle, rushes, populations and bursts all respect it.
- `_school_cleanup` every 3 s: lets go of living infected two floors or more from every survivor (and >14 m away),
  sleepers on floors below everyone (>16 m), and ones stuck for 8 s far from anyone. Logs `INTERIOR_COOP_SCHOOL cleanup`.
- Drawing: other floors' geometry is drawn only where it can be seen (stairwells and their ends of the corridor, the
  grand stair, the fire escape, the hatch); their lights only from right in the openings; from outside only the ground
  floor's interior. The infected and the dead on undrawn floors are hidden and skip animation (`mission._hide_far`,
  `figure._animate`). Corridor lights no longer cast shadows except the swinging one (a spot, one shadow view).
- Frame times (project run, review `--fps`, same spots as 0.50's table where they exist):

| spot | 0.50 | 0.51 |
|---|---|---|
| yard | 9.6 ms | 8.0 ms |
| lobby | 6.7 | 6.2 |
| ground corridor | 8.3 | 8.1 |
| third-floor corridor | 9.7 | 8.2 |
| cafeteria | 5.4 | 5.1 |
| facade from the lane | 9.6 | 6.9 |
| second-floor corridor (dark) | — | 7.0 |
| fire escape | — | 5.0 |
| fourth / fifth corridor | — | 8.6 / 8.0 |

  That is 116-200 fps on this PC; the busiest corridors are not at 200 yet. There is a ~5 ms floor even in a small
  space with ~550 draw calls (fire escape), so the next step is profiling that base cost (post effects, scripts).

## Debug
Jumps added: `fireescape` (on the 2F landing), `ladder` (foot of the ladder), `duct` (mech room by the duct mouth).
`floor2`/`floor4` descriptions updated.

## Tests
- `tests/coop_school.gd` 44 checks (was 30): school's own only (students/staff/parents), staff kinds spawn, both
  stairs blocked at 2F and 4F, west open at 3F, the fire door open, `steer` 3F→2F via the fire escape and 4F→5F via the
  maintenance room, an infected down the fire escape, **an infected up the ladder, through the duct, to a survivor on
  the fifth**, **the player climbs the ladder**, **a door group pounds, bursts, the class pours out, the doorway opens**.
- `tests/coop_school_review.gd`: new views corridor2_dark, hall_block2, breach205, fire_door2, fire_escape(_up/_out),
  corridor4_staff, janitor_room, ladder_up, mech, duct_mouth, duct_510, doors_row3, class_session, door_pound,
  door_burst; `--fps` has four more spots.

## Screenshots sent
| file | what |
|---|---|
| work/v51/screens/staff_zombies_sheet.jpg | the eight new staff infected (Blender previews) |
| work/v50/v51a/new/sheet_new.jpg | project renders: dark halls, desk wall, fire escape, ladder, mech room, standing class, door burst |
| work/v51/exe/ (see below) | from the 0.51 EXE |

## Open
- 200 fps is not reached in the busiest corridors on this PC (see the table).
- Real two-PC play not tested (door states and the ladder are host-driven flags/positions like the rest).
