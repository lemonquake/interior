# 0.59 handoff: story pickups shine, slower infected attacks, Heavy-arm -30 %, PILCST sweep fixes

Owner's request (2026-11-23):
- "add it to the single-player story's pickups too" (the 0.58 white shine)
- "nerf the zombies attack speed by 50%, nerf Heavy-arm health by 30%"
- "Do another deep check and fix some glitches/bugs and stuff out of place etc etc in School building up to the field"
- mid-run: "remove that 'Mang Dado, Bantay, Rear Gate' that's so fucking korny"
- mid-run: the blackboard in 501 said "WE ARE IN 501 PLEASE" while they are in 501.

## Shine on the story's pickups (scripts/pickup_shine.gd)

- `Shine.apply(node, twinkle, twinkle_at, size)`: new `size` (twinkle width, metres; co-op stays .42) and the twinkle
  now draws on the item's own render layers (the hut's meshes are on the outdoor layer).
- Hut key (hut_house.gd `_key_on_top`): the shine overlay only; it keeps its own gold sparkles from 0.10.
- The Glock and the flashlight in the drawer: shine + a small twinkle once the drawer has slid open (shut, the
  twinkle would show through the drawer front).
- The ammunition box: shines from the moment the stranger lifts it out of the mud into his hand (stranger.gd
  `_take_box`), not while it is buried.

## Infected attack speed halved

- Story zombies (scripts/zombie.gd): after a swing a zombie rests as long as the swing took (`_swing_rest`) before
  the next; between swings it stands facing you instead of walking into you. The legless crawlers' bite 1.2-1.7 s ->
  2.4-3.4 s. Leaps unchanged.
- Co-op infected (scripts/coop/figure.gd `chase`): `attack_wait` 1.65 s -> 3.3 s.
- Heavy-arm's own blows are unchanged (he is a boss, and his health was the ask).

## Heavy-arm (scripts/coop/heavyarm.gd)

- `HEALTH_SCALE := .7`: 1680 alone on Normal (was 2400); with squad AI and on Easy/Hard scaled the same.
- The caption under his bar ("Mang Dado · bantay, rear gate") is gone. Ma'am Teves still says his name in her line
  when she sees him (heavyarm.gd TALK line 1, interior.gd debug copy): ask the owner.

## PILCST sweep (back gate -> rear gate)

New tools: `tests/school_route_sweep.gd` (every co-op jump from "school" to "pilcstout", four looks on one sheet, and
checks: player on a floor, infected inside geometry or over nothing, survivors within 0.8 m of the player) and
`tests/school_chairs_settle.gd` (wakes every physics chair: fails on a 25 cm drop or an 80 cm throw).

Fixed:
- **Chairs** (70 of 1445 fell or burst out when woken, by a round, a blast or a push):
  - corridor desk walls (`_hall_block`): chairs crowning the pile stood inside its ceiling-high collider; no crown now;
  - stair barricades (`_barricade`): the collider was 1.7 m, the pile's top 1.52 m, so the chairs on it were 18 cm
    inside; collider now 1.52 m. The spill chairs on the flights stood inside the spill colliders and 9 cm over the
    flight's slope; they now stand on the slope below the spill, tilted with it;
  - chairs stacked under the pulled ceiling tile overlapped (seat into the back and the writing arm of the one
    below) and the class's own chairs stood inside the desk under the stack; each is set back and aside on the one
    under it and the room's chairs there are cleared;
  - room 208's 22 "thrown" chairs hung in the air at any angle; now on the floor, on their sides and backs, in two
    spaced rows, clear of the desk lying on its back.
  - Result: 0 of ~1400 fall; a few on the stairs ease a few centimetres.
- **Lean-to**: the burnt LPG cylinders had no colliders (walked through from the field); solid now.
- **Survivors standing inside the squad**: after a stop they ended 0.2-0.8 m from the player (the camera inside a
  student's head). escape.gd `_crowd`: they keep 1.1 m off the squad (strongly) and 0.75 m off each other.
- **Room 501's blackboard**: blank (it said "WE ARE IN 501 / PLEASE"). The random "ROOM IS NOT SAFE / WE WENT UP"
  board is never on the fifth floor.
- **Log spam**: the classroom door hinges set limit bias/relaxation, which Jolt ignores (two warnings per door).

Looked at and left (not faults): the plain cream whiteboards (read as untextured at a grazing angle), the infected
spawning just inside the field walls (no player within 16 m), the hanging grilles at 208's breach (not solid; the
way out is the middle of the opening).

## Invented text still in the area (ask the owner which to cut)

Teves's "Mang Dado" line; signs "AKYAT ... (gapang, low) - B.", "<- 509 / gapang lang", "CHAINED / wag buksan /
- 12-B", "DO NOT OPEN / THEY'RE IN THE / HALL - Kuya Boy", "TULONG / 5TH FLOOR / MAY BUHAY PA", "MAY TAO DITO /
SURVIVORS INSIDE", "PILCST INTRAMURALS 2026" + "Galing ng Agham, Lakas ng Kabataan • Nov. 14-21", "PILCST FOUNDATION
WEEK 2026" + "17 years of science for every barangay • Nov. 14-21", "GULAYAN SA PAARALAN / STEM 11-A", the
canteen menu, the classroom boards (BOARDS), the founder plaque and memorandum.

## On-screen text added

None. Removed: "Mang Dado · bantay, rear gate", "WE ARE IN 501 / PLEASE".

## Tests

hut_story_integration 75/75; coop_school 44/44; coop_escape 38/38 (twice; the shot and crouch checks made
independent of where the random horde stands); coop_heavyarm 48/48 (hp 1890 with one squad AI); coop_integration
ok; coop_kits_modes 35/35 (one rerun: a rifle round count was off by 3 once); coop_markers_review 0 failed;
school_chairs_settle ok; zombies_integration 109/109 (one rerun: the head hit-box check on a fresh spawn failed
once); fair_world 53/53; body_integration 36/37 (the shove reach check, failing since 0.57).
Co-op tests run side by side with `SLEEP_COOP_PORT=<port>`.

## Screenshots sent

| file | shows |
|---|---|
| work/v59/hut/11-drawer-open-glock.png | the Glock and flashlight shining in the open drawer (project) |
| work/v59/exe_capture/hut-4-drawer-open.png | the same from the exported EXE (`-- --capture-review --capture-views=hut`, capture path without spaces) |

EXE: builds/windows/Interior.exe 0.59.0 (109 MB) + Interior.pck (1494 MB), Sleep-0.59.0-windows.zip; boots in 18 s.

Sweep sheets (not sent): work/v59/sweep/*.jpg, work/v59/sweep_probe/*.jpg.

## Open

- The invented signs and lines above.
- Students are still invulnerable and ignored by the infected (0.52's question).
- Not tested on two real PCs; no co-op capture mode in the EXE (the sweep is rendered from the project).
