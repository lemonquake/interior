# 0.56 handoff: PILCST frame rate, floating clutter, ghost blockers

Owner's request (2026-11-22): scan the whole school for out-of-place objects that do nothing, blockers without
collision, doors without physics, floating chairs; fix the horrendous FPS without cutting ragdolls/physics.

## Frame rate (tests/school_perf.gd, rendered, uncapped, host + 4 squad AI, quality 2)

| view | 0.55 fps | 0.56 fps |
|---|---|---|
| ground floor lobby | 90 | 115 |
| 2F corridor, 34 infected | 41 | 67 |
| 3F corridor, 32 infected | 31 | 71 |
| 5F corridor, 38 infected | 65 | 73 |
| 20 students charging | 31 | 52 |
| after 4 waves, 16 bodies, blood everywhere | 5.8 | 50 |

Where it went (measured, `-- --coop-timing` and the `--split` mode of school_perf):
- **Infected path search** (`zombie_nav.gd _search`): A* over GDScript dictionaries, ~830 cells a search, 4-16 ms each,
  60% failing (the corridor desk walls force a detour through rooms). Rewritten on flat packed arrays with generation
  stamps (nothing cleared between searches) and the ground it reads memoised per search. Same cells, same order, same
  path: checked identical on 160 pairs before the old version was removed (fp addition order matters for ties).
  A goal beyond REACH cells now tries the waypoint leg first (the same answer, without a doomed search).
- **Stair router** (`school.gd steer/on_chain`): routes were rebuilt as fresh arrays for every infected every tick;
  now cached (`_route_c`, box test per route). 2.5 ms -> 0.6 ms a tick.
- **Waypoint graph growth**: ~0.55 ms a node, 8000 points in the college: it ate 2.5-4 ms of every tick for 20 s after
  any arrival. Now every other tick at 700 us.
- **Stalled infected** cast 6 rays + 3 shape queries every tick looking for a vault: now every 0.25 s.
- **Blood spot decals** fade by size (6-24 m) instead of all at 26 m.
- Nothing about ragdolls, corpses (still InteriorZombies.MAX_CORPSES live ragdolls), hit boxes or gore was touched.

Still costly (not done): ~100 us of AI per hunting infected per tick (move_and_slide ~50 us of it), ~80 us/frame to
animate each infected body, and the physics-tick spiral when a frame passes 16.7 ms. 51+ hunting infected (above
SCHOOL_CEILING 34, only the stress test gets there) still drop to ~31 fps.

## Props (tests/school_props_audit.gd, `school.gd auditing`)

The builder can record every box/cylinder/chair it lays down with the line that laid it; the audit reports FLOAT
(nothing under it) and GHOST (knee-high+, standing, no collider). Run: `godot --headless --path game --script
res://tests/school_props_audit.gd -- --report`. Expect false hits from stair treads, ground slabs, wall-bracket TVs,
bed tops on thin legs.

Fixed in 0.56:
- **The owner's screenshot**: a steel bar across every fire-escape doorway at push-bar height (also where the door is
  gone or hangs open). Now jambs + head. The 3F fire door hanging open is solid.
- **Corridor desk walls** (`_hall_block`) and **stair barricades** (`_barricade`): were clouds of desks/chairs/cabinets
  at random heights and angles. New `_pile` stacks desks, upside-down desks, desks on those, boards on edge across both
  faces, chairs on top; `_desk` is a desk with legs. Colliders unchanged.
- **501's barricade**: desk tops on edge and laid across, stacked (it floated). **Mechanical-room door**: boards on edge
  against it and laid over them, a desk, all solid (they floated).
- **Chairs**: on their side only on the plain side (the writing arm went 22 cm into the floor); no more upside-down
  chairs standing on the top of their backs; chairs stacked under the pulled ceiling tile sit on each other.
- **Cafeteria**: benches have legs and colliders; trays lie on the rotated table tops.
- **Kitchen**: the knocked-over gas tank lies on the floor (it hung 23 cm up); tanks and rice sacks are solid.
- **Biology lab**: an open specimen shelf (back, sides, boards) instead of jars sunk in a solid block.
- Solid now: clinic curtains, faculty water dispenser, the president's chair, the music room's drum kit.

## Not done (next task)

- **Doors**: the open/ajar classroom leaves (`_room`, `bx(... leaf, false, b)`) are still frozen geometry with no
  collision. They must become real hinged physics doors (push, close, drag with E) synced host -> clients.
- **Chairs**: 1095 chairs have no collision at all (MultiMesh only). They should become physics props (host simulates,
  clients follow, MultiMesh instances updated from the bodies).
- The audit's remaining GHOST rows are exactly those two.

## Tests run

coop_school 44/44, coop_escape 38/38, school_props_audit (report above), school_perf. EXE 0.56.0 exported
(tools/export_windows.py) and its `--capture-views=coop_school` frames checked (work/v56/exe).

## Screenshots sent

| file | what |
|---|---|
| work/v56/desk_walls_before_after.jpg | 4F and 2F desk walls, 0.55 vs 0.56 |
| work/v56/exe_school_0.56.jpg | EXE capture: desk wall, stair barricade, fire-escape doorway, 501 |
