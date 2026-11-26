# 0.50 handoff — the Prof. Ivan Lawrence College of Science and Technology (co-op)

Owner's request (2026-11-21): build the school from `work/Reference/School` into the multiplayer mode. Creepy, a
mess everywhere (papers, blood), bloody student infected (5 male and 5 female designs, one uniform, senior high and
college) that are persistent and come in numbers. Before the school's entrance a dialogue box tells everyone the
school's story (Prof. Ivan Lawrence College of Science and Technology, founded and run by Ivan, Aljay's friend; the
students trapped inside when the outbreak hit). Then a wounded guard begs for help: survivors on the fifth floor.
Five storeys, flickering lights, dark areas, the cafeteria, the laboratory and so on.

## The run, end to end (stages; `Mission.OVER = WON = 11`, `FAILED = 12`)

| Stage | Objective | What happens |
|---|---|---|
| 8 | Backstreets north to the college | unchanged, except Jonna now names the college |
| (8) | the story | within ~34 m of the back gate the story box comes up for everyone (5 pages, typed out, E turns a page) |
| 9 | Speak to the wounded guard | Rommel calls out from behind the bars; E: his account (12 lines), then he slides the gate open |
| 10 | Get to the fifth floor | the yard and the school; once every survivor is in the yard he drags the gate shut and the backstreets are put away |
| 11 | Survivors found | knock on room 501 (fifth floor, west end) with no infected hunting within 14 m |

The story box: `session._story_box` (centred near the top, maroon frame, typed at 46 characters/s); the pages are
`Mission.STORY`, the page the host is on is `flags.story`. Rommel's lines: `Mission.GUARD_TALK` (the dialogue panel,
like Jonna's).

## The building (`game/scripts/coop/school.gd`, new)

x 0..56, z 514..534 street-local, five floors of 3.6 m; built when the backstreets wake (`mission._build_school`,
~250-300 ms, every peer, from the street's seed). Double-loaded corridor; cream walls over a gloss green wainscot;
checker in the lobby; drop ceilings of stained tiles. Textures are painted by `tools/school_textures.py`
(game/assets/school/*.png).

- Ground floor: lobby (checker, the founder's plaque, steel letters, the trophy case smashed, the guard's desk, the
  suspension memo), cafeteria (where it began: tables tipped, trays and food, a lot of blood, flies), kitchen, clinic,
  registrar/cashier (records everywhere), guidance, faculty room, the president's office (Ivan's letter to Aljay on
  the desk), the grand stair.
- 2F classrooms 201-210 and the grand stair's gallery; 3F chemistry, biology, physics labs and the stockroom;
  4F library, computer lab, AVR; 5F classrooms, the music room, room 501 (the survivors, barred door, lantern).
- Classrooms: rows of steel-framed armchairs (MultiMesh) thrown about, a board with what the class was doing (some
  with what was written after), the teacher's desk, bags/shoes/notebooks, papers, blood; some with a corner fort.
- Lights: tube fixtures, most dead, some failing (stutter bursts), some dying; red emergency lights on the stair
  turns; green EXIT signs. Floors out of reach are hidden (`view`: your floor and the ones next to it inside; from
  outside every floor's walls but only the ground and fifth floors' lights).
- Outside: the perimeter wall and the sliding back gate, the guard house, Rommel with his torch on the ground, the
  covered walk, the flag at half mast, the school service jeepney, the facade with lit windows, floodlights, the
  name across the top, the foundation-week tarpaulin, and the bedsheet from 501's window ("TULONG / 5TH FLOOR").

### The stairs, and getting the infected up them
The students piled desks into the stair turns, so one way is open between each pair of floors (`UP`): grand stair
1F→2F, east 2F→3F, west 3F→4F, east 4F→5F. A note taped at the foot of every blocked stair says which way is open.
`zombie_nav.gd` searches one level at a time (its closed set is 2D), so `school.steer(from, to)` gives the infected
(mission.gd) and the squad AI (bots.gd) the open stair as a chain of points when what they follow is on another
floor. `Figure.chase(..., strike)` does not stop to attack a waypoint. Bots' follow spots in the school must be on
the leader's floor (`bots.gd`).

## The students (`tools/blender/human/build_zombies.py`, 10 new variants `pilcst_m1..m5`, `pilcst_f1..f5`)
One uniform: white PILCST polo/blouse with the maroon-and-gold crest (`pattern="pilcst"`), maroon necktie, navy
slacks or navy pleated skirt, black school shoes. Different builds, hair, decay, eyes, wounds, glasses, bags, a lost
shoe. `mission.INFECTED` 57..66 (`STUDENT_FIRST`); the school spawns only these, faster than the town's (2.6-3.7 m/s).
Build: `blender -b --factory-startup --python tools/blender/human/build_zombies.py -- export preview noanims only=pilcst_m1 ...`
Rommel: `tools/blender/human/build_school_guard.py` → survivors/school_guard.glb (clean skin like Jonna, bitten).

## The school's infected (host, `mission._school_tick`)
- gate opens: a few wander the yard;
- a floor reached for the first time: 9-15 lying about (`_populate`: wander / sleep / feed), and above the ground a
  rush from the far end of the corridor (`_rush`, 6-14);
- all the while: one every 2.4-4.6 s out of a room doorway near a random survivor (out of sight, 9-34 m), up to
  10 + 4 x squad hunting at once; they are never let go for distance under 80 m.

## Debug
Jumps: `brickalley` (8), `school` (9, at the gate), `lobby`, `floor2`..`floor5` (10). Complete: 8 → story told,
9 → gate open, 10 → 501 opened. EXE capture: `Interior.exe -- --capture-review --capture-views=coop_school --capture-path=<dir>`.

## Tests
- `tests/coop_school.gd` (new, 30 checks): built on wake, story, guard, gate, yard shut and backstreets put away,
  students only, floor population, blocked/open stairs, `steer` answers, an infected up the grand stair to the second
  floor and one down the east stair, the squad AI up the grand stair, 501 refuses with one close, then the win.
- `tests/coop_school_review.gd -- --set=<dir> [--views=..] [--lit]`: photographs → work/v50/<dir>/.
- Updated: `coop_jumps` (new places, the run now ends at 11), `coop_integration` (presses READY on the 0.49 board;
  plays story → guard → 501).

## Results
- Build: `builds/windows/Interior.exe` + `Interior.pck` **0.50.0** (tools/export_windows.py, re-baked), zip
  `Sleep-0.50.0-windows.zip`. Boots to the menu in ~16 s. EXE capture `--capture-views=coop_school`: work/v50/exe/.
- Frame times in the school (project run, review `--fps`): yard 9.6 ms, lobby 6.7, ground corridor 8.3, third-floor
  corridor 9.7, cafeteria 5.4, the facade from the lane 9.6 (103-187 fps). Build of the school: ~250-300 ms at wake.
- Tests (headless, one at a time): coop_school 30/30 (three runs), coop_integration 37/37, coop_jumps --walk 61/61 and
  --direct 23/23, coop_chapters 26/26, coop_backstreets_integration 9/9, coop_kits_modes 35/35,
  coop_squad_integration 27/27.
- Also fixed: `performance.gd _still_shadows` crashed on a node freed during its nine sampling frames (typed loop).
- Not tested: real two-PC play of the story box, Rommel's talk and the school (clients build the school from the same
  seed and read `flags`; the infected come over the existing snapshot). Not run: the full suite (tools/run_tests.py).

## Screenshots sent
| file | what |
|---|---|
| work/v50/screens/student_zombies_sheet.jpg | the ten students (Blender previews) |
| work/v50/pass3/sheet0.jpg .. sheet2.jpg | project renders: story box, gate, Rommel, yard, lobby, corridors, rooms, stairs |
| work/v50/exe/exe_school_sheet.jpg | from the 0.50 EXE: the school end to end |

## Open
- Rommel and the survivors are text only (no voice), like Jonna.
- No chapter board between the backstreets and the school (the owner did not ask; the gate shutting plays that part).
- Room 501's survivors are not shown as people (the door opens on the win); Match Results still has no next map.
