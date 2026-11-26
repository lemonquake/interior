# 0.52 handoff — out of PILCST with the survivors of 501 (co-op)

Owner's request (2026-11-22): carry the multiplayer story on from the school. The survivors on the fifth floor thank
the squad and warn them a horde is coming: everyone turns their flashlights off and stays still while it passes (it
is heard coming closer). Then they are stuck and have to get out: slowly out of the classroom to the emergency fire
exit stairs; a shot alarms the zombies nearby and they chase, so the squad can stay stealthy or fight while the
students follow. At the second floor the way is blocked; a classroom with its windows blown out (as if bombed) lets
everyone jump onto a roof, down into the school field, where the zombies are alarmed: fight across to the back exit,
its gate already open and broken, into the heart of Davao City (the next level, to be built later). Show the
scoreboard there and clean up the mess and the dead.

## The run (`Mission.OVER = WON = 16`, `FAILED = 17`; was 11/12)

| Stage | Objective (HUD line) | What happens |
|---|---|---|
| 10 | Get to the fifth floor… | unchanged, except 501 will not open while a door down the hall is still being beaten |
| 11 | Listen to Ma'am Teves. | 501's door swings in, the desks dragged aside; Ma'am Teves and four students (Bea, Paolo, Jerome, Trisha: "Group 3" from a board). Her talk (8 lines, E hurries it): who sent you, Sir Ivan, and the warning |
| 12 | Lights off. Everyone inside room 501, and stay still until the horde has passed. | The door shuts once every survivor of the squad is inside (warning at 22 s, shuts anyway at 40 s). A crowd heard on the stairs, then the east stair's desks give (crash), and 16-26 infected shuffle west along the corridor past the door and stop, standing in the dark the length of the hall (a few past the door at the west end). A light on in 501 while one is at the door, a shot, or running gives the room away; awake ones at the door force it |
| 13 | Get the students out: the fire exit at the far end of the corridor. Stay low and quiet. A shot will bring the whole horde. | Teves whispers: they won't leave till morning, they're in the vent too (a few in the mechanical room and duct), the fire exit at the far end, chained by the students: here's the key. Crouch past the horde (it stands on alternating sides: weave), or fight. E at the fifth floor's fire door: the chain comes off, the door swings out onto the fire escape |
| 14 | The way down is gone. Find another way off the second floor. | Halfway down the fire escape (below the fourth floor's landing) the kitchen's LPG store goes up under room 208: explosion, shake, fire and smoke behind the building, 208's door blown into the corridor, the second floor's gallery ceiling down onto the grand stair (buried, solid). The fire escape still ends at the second floor (the flight to the alley was torn off in 0.51). Paolo: "the wall's gone, there's a roof under it!" |
| 15 | Across the school field to the rear gate. Bring the students. | Out through 208's blown-out wall, a short drop onto the lean-to's yero roof, off its eave into the field. Everything out there heard the blast: the near ones come at once, more over the walls and through the gate. The rear gate hangs open (one leaf down in the grass, the other hanging) onto a city street |
| (15) | the board | Every survivor of the squad at the gate: the chapter's board ("Prof. Ivan Lawrence College": out with Ma'am Teves and her students, 5 of 5; next: the heart of Davao City), READY each. Everything behind is put away: the school, its dead and every corpse of the night, the infected, the drops |
| 16 | Out of PILCST | everyone READY: Match Results ("Out of PILCST with Ma'am Teves and her students • next: Davao City") |

## The survivors (`scripts/coop/escape.gd`)

- Models: `tools/blender/human/build_school_survivors.py` (like Jonna/Rommel: a variant's body and garments, clean
  skin, the hair kit) → `game/assets/characters/survivors/pilcst_{teves,bea,paolo,jerome,trisha}.glb`.
  Teves: the maroon faculty blazer, glasses, a cut forearm tied off; students in the clean PILCST uniform.
- They follow in a line: Teves behind the survivor of the squad nearest her (a human first), each student behind the
  one before. Crouched (crouch_walk) in stage 13, walking/running after. Over every way the squad goes: the fire
  escape, 208's wall and the roof, the ladder and duct if anyone goes back that way. Lost ones (30 m behind, or stuck
  6 s) are put back in the line.
- **They cannot be hurt and the infected ignore them** (the infected go for the squad). This keeps stealth fair (only
  the squad is heard and seen) and the mission from failing on AI followers. Open question for the owner: should
  students be killable (a "brought out N of 5" count is already on the board)?
- Host moves them; the snapshot carries them (`state[14]`); every peer builds them when `flags.survivors` arrives.

## The horde and keeping quiet (mission `sense`, `fired`, escape `_give_away`)

- The horde: `Figure.idle_mode = "march"` (asleep, walking `march` points at ~1 m/s, then `march_then` sleep/
  wander/feed). Each walks a nav path to its own spot (straight lines jammed on the desks at the welded mechanical
  room door). The fifth floor's remaining shut classroom doors stop bursting once the horde comes.
- Stage 13 rules (dark, crouched, light off): a sleeper hears crouched steps within 0.96 m and wakes if touched within
  0.8 m; walking is heard at 2.7 m, running at 6.6 m; a light on it within 16 m wakes it; one that is wandering or
  feeding sees you within 3 m if it faces you (5.5 m elsewhere). A shot wakes everything within 32-42 m (19-25 m
  through walls). Any that wakes wakes the others within 7.5 m.
- The squad AI keeps quiet with you: lights off, crouched, never shooting the ones standing asleep, and in stage 13
  it steps where its leader stepped (footstep trail) instead of fanning out beside them. In stage 12 it sits along
  501's back wall.

## The building (school.gd)

- **Fire escape** to the fifth floor: landings at 2F-5F, three switchbacks, rails (colliders 1.6 m: nobody goes over
  into the alley); the fourth's and fifth's fire doors chained from inside ("CHAINED / wag buksan - 12-B"); the fifth's
  opens with the key (`flags.fire5`). The old hanging flight above the third floor is gone. FIRE EXIT signs on every floor.
- **501's door** is a hinged body now (`flags.door501` 0 shut, 1 open, 2 forced), its barricade desks a node dragged
  aside when it opens.
- **Room 208** (over the kitchen) is built blown out: the outer wall gone from the floor to near the ceiling
  (`BREACH`), ragged concrete and rebar, soot up the wall outside, the room burnt, the chairs thrown against the
  corridor wall. Its door stays a scare door until the blast blows it off.
- **The lean-to** under it: the kitchen's LPG store, hollow-block walls (the north one blown out into the field),
  burnt cylinders, a buckled yero roof at 3.05 m at the wall sloping to 2.45 m (the drop from 208 is ~0.6 m, the eave
  2.45 m); fires and smoke lit by the blast.
- **The gallery collapse** (built hidden, solid only after the blast): slabs, a beam, rubble and dust across the
  gallery's openings on the second floor; the grand stair is no way down any more.
- **The field** (root "Field", index 12): grass worn to dirt, goals, the covered court (slab, lines, hoops, steel
  roof, the stage with the INTRAMURALS 2026 tarpaulin), bleachers, the Gulayan sa Paaralan garden, bamboo, coconut
  palms, an acacia, lamp poles (two lit, failing), litter; the perimeter walls carried round; the **rear gate**
  (REAR GATE sign, chain cut on the ground) and beyond it a city street (asphalt, a jeepney, a tricycle, a row of
  dark shophouses with a few lit windows, a fire glow and smoke toward downtown, a wall at the end).
  Drawn only from where it can be seen (behind the building, the north rooms, the ends, the fire escape).
- **Routes** (`steer`): `ROUTE_ESC` (4) the whole fire escape 2F↔5F once `fire5`; after the blast `route(0)` is the
  way out through 208, the roof and the eave (one way). The mechanical room is sealed: anything in it off its way goes
  back to the ladder's top and by the duct. The duct's mouth was 0.55 m wide between its end and the hatch rail
  (bodies wedged there); the duct now ends at x 34.2 (0.9 m gap) with a waypoint at the mouth.

## Debug
Jumps added: `teves` (11), `horde` (12), `sneak`, `firedoor` (13), `blast`, `room208` (14), `field`, `reargate` (15);
`complete` steps each stage as play would (15: the board). `jump <0-15>`.

## Tests
- `tests/coop_escape.gd` (new, 38 checks): 501, the talk, the door waiting for everyone, the horde coming up and
  standing past the door with nobody woken, crouched-past is not heard / running is / a shot wakes them, the squad
  AI's light off, the fire door, Teves following onto the fire escape, the blast (gallery solid, 208's door off),
  208's wall open with the roof under it and the field below, Teves and the students out through it and off the
  roof, the field full, the rear gate: the board, the dead and the infected gone, the school put away, READY → WON.
- Updated: `coop_school` (501 → stage 11; doors already met), `coop_integration` (on through the escape to WON),
  `coop_jumps --walk` (the new jumps; complete at the rear gate brings up the board).

- **Moonlight**: in co-op the moon (and the sky fill) light only render layer 2; the street and school meshes are
  on 1|8 and are lit by their own lamps. The field root, the lean-to, the street beyond the gate, the fire escape's
  steel and the five survivors now carry layer 2, so the field is moonlit and readable. Behind the building: two
  floodlights on the generator over the field (one failing), field lamp poles (two lit), a caged bulb over the rear
  gate (the way out, from across the field), a failing sodium lamp at the fifth floor's fire door.

## Results
- Build: `builds/windows/Interior.exe` + `Interior.pck` **0.52.0** (tools/export_windows.py, re-baked), zip
  `Sleep-0.52.0-windows.zip` (1593 MB). Boots to the menu's first frame in 17.7 s. The school builds in ~290-310 ms.
- EXE capture `Interior.exe -- --capture-review --capture-views=coop_escape --capture-path=<dir>`: work/v52/exe/
  (20 views, sheets exe_sheet0.jpg / exe_sheet1.jpg). Project capture of the same: work/v52/project2/.
- Tests (headless, one at a time): coop_escape 38/38 (the last four runs), coop_school 44/44, coop_integration 39/39,
  coop_jumps --walk 86/86 and --direct 23/23, coop_chapters 26/26. coop_squad_integration 26/27 in two runs, a
  different single check each time (a ragdoll falling straight down, then a pistol round missing the chest) on Store
  Road at stage 4: the known aim sway, nothing this change touches.
- Also fixed on the way: an infected knocked off its way in the mechanical room walked at the welded door; the
  duct's mouth was too narrow for a body to get in reliably (it passed in 0.51 by luck of timing).
- Not measured: frame times in the field and on the fire escape's upper landings (the field is only drawn from where
  it can be seen). Not tested: real two-PC play.

## Screenshots sent
| file | what |
|---|---|
| work/v52/survivors/survivors_sheet.jpg | the five survivors (Blender previews) |
| work/v52/project/sheet0.jpg | project renders: 501, the room, the horde passing and standing, the fire door (the black fire-escape frames were fixed after) |
| work/v52/exe/exe_sheet0.jpg | from the 0.52 EXE: 501, the dark room, the horde, the fire door, the fire escape, the collapse |
| work/v52/exe/exe_sheet1.jpg | from the 0.52 EXE: 208, the breach, the roof, the back of the school, the field, the court, the rear gate, the city, the board |

## Open
- Students are invulnerable and ignored by the infected (see above): owner's call.
- Teves and the students are text only (no voice), like Jonna and Rommel.
- Davao City itself (the next level) is not built: READY on the board ends the run with Match Results.
- Real two-PC play not tested (doors, the horde, the blast are host flags; the survivors ride the snapshot).
