# 0.44 handoff: the floodwall gate rebuilt, Jonna's back office, the backstreets to Nichols Elementary School

Owner's request (2026-11-19, via @lemondev): the bridge and gate leading to the convenience store "so horribly
designed that it needs a total remake": design an actual way to the gate, creative and full of intent, with mess and
blood "like some guards were killed there". Then continue the mission: after the final wave in the store, someone
in the back office (a very nice office, mess and blood, a wounded NPC) opens the door behind you and calls you in;
dialogue about the outbreak; the NPC is Jonna, severely wounded; she says there are survivors, someone radioed
that Nichols Elementary School 500 m ahead is safe, the roads are crowded so walk the backstreets. Build the
backstreets in the style of `work/Reference/Streets Stage` (school later).

Note: an earlier session on 2026-11-19 (09:38-10:24) left co-op customizer / hair / survivor / zombie work in
`work/v44/{customizer,hair,survivors,zombies}` without a handoff; this run did not touch that work. (`zombie_anims.glb`
is unchanged; the new clip lives in `zombie_extra_anims.glb`, see Results.)

## 1. The way up to the gate (`game/scripts/coop/approach.gd`, new)

What was there: a 12 m plank ramp standing alone in the dirt yard between two loose tin sheets, ending at a plain bar
gate in mid-air (`work/v44/before*/`).

Now Purok 4 sits on a real concrete floodwall (34 m, footing, expansion joints, moss line, weep holes and their
stains, a parapet with barbed wire on bent-iron arms). The barangay's concrete ramp climbs the wall's face from the
yard's east end to a landing in front of the night gate (pillars painted barangay blue, a sodium lamp on the right
pillar and a smashed one on the left, a steel arch with "PUROK 4 • MABINI", a green sliding leaf with barbed strands,
a chain and padlock that go once Dodong's keys open it). The curfew tarpaulin ("CURFEW 10:00 PM – 4:00 AM") explains
why the gate was locked; Dodong was the tanod with the keys.

The story left in place: a squad held the foot of the ramp. Razor wire (MultiMesh coils on pickets) runs across the
yard to funnel the settlement past their sandbag horseshoe; one stretch is trampled flat where the infected came
through (blood, a drag trail back toward the warren, a scrap of uniform in the coil). Behind the sandbags: the
kicked-over folding table, the log book face down, the field radio with its handset on its cord (red light), a
helmet, an ammo can, sardines and crackers, ~190 casings, a hand-lettered "CHECKPOINT • HUMINTO • STOP" carton.
Their generator still runs (hum) and feeds a tripod floodlight knocked onto its side, still burning, raking the
landing and the wall. Bracket sodium lamps on the wall (one failing) and a wooden power pole with a sodium lamp over
the trampled wire light the climb. The dead (`APPROACH.DEAD`, posed ragdolls like the store's): a soldier slumped
behind the bags, one who crawled up the ramp (drag smears up the slope, deeper decals so they follow it), a guard
under the one bent railing bay he went over, a tanod dead against the locked gate, an infected at the breach.

Layout gotcha: the settlement's far-bank fence runs north from the warren's exit (x -7.3 street-local) all the way
to the wall at x -8..-9.8, so everything is east of it; the first draft put the ramp in the sealed pocket behind it.
The old map-seal fence at world z 71.2 now sits inside the floodwall.

Lights: the balcony masks the outdoor layer off every light once after load; lights with meta `outdoor` are now
skipped (`balcony.gd`), and the street's `light()` sets it, so the yard ground is lit.

## 2. Jonna and the back office (`game/scripts/coop/back_office.gd`, new; `mission.gd`)

The staff room behind the drink fridges (x 1..8.4, z 69.6..73.4) is the office now. Door shut through the fight
(`Street.office_door`, flag `office` swings it in with a lock sound). Inside, every detail has a reason: the
two-drawer cabinet she braced the door with, pulled back, and its scrape marks; the steel desk with the CCTV quad
view still on (UPS light), keyboard, papers, the emptied cash box and coins, mug, calculator, the warm desk lamp;
the handheld radio in its charger, its channel light blinking ("CH 7 • BRGY": how she heard about the school); the
cork shift board, the NOBYEMBRE 2026 calendar, the Davao business permit, a stopped clock; the corner shelf with the
Santo Niño, the lucky cat and its red bulb; lockers (one open, a spare red polo); the open, empty safe; a water
dispenser; a stand fan; a tall cabinet with a drawer out and files on the floor; one live tube. Her corner: the
tipped first-aid box, gauze, bloody towels, water and crackers, her camp lantern, blood drops from the door, the
smear down the wall where she slid, the pool.

Jonna (`assets/characters/survivors/jonna.glb`, `tools/blender/human/build_jonna.py`): the mart's shift supervisor,
built like the five survivors (clean skin, ponytail), red staff polo soaked on the left side, black work trousers,
a bloody gauze wrap round her head. New clip `sit_hurt` (`tools/blender/human/crawl_clips.py`, in
`zombie_anims.glb`, loops): sat against the wall, both arms holding her side, breathing hard, lifting her head now
and then. The body that lay across the doorway (STORE_DEAD[7]) moved 1.3 m.

Mission flow (stages renumbered past the store; `Mission.OVER/WON` = 9, `FAILED` = 10; every "mission over" check
uses them now):
- 6 "Someone is calling from the back office.": 4 s after the last wave the door opens, Jonna in the doorway:
  "Pssst! Hoy! Here, the office! Quick, before more of them come!". E: Speak to Jonna.
- 7 "Listen to Jonna.": she limps back to the wall and sits; 13 lines (`Mission.TALK`, the speaker's survivor name
  for the team's lines), each held for its length; E: Go on skips ahead. Content: Bankerohan market, the barangay
  bell, the soldiers, the front glass, not a bite, the radio, the teacher, Nichols Elementary 500 m north, the main
  road finished, out the back through the backstreets, she stays.
- 8 "Out the back door and through the service gate...": she hands over the service gate key; E opens the
  stockroom's back door (quietly, `backdoor_open`) and unlocks the steel service gate in the alley's far wall
  (`Street.ALLEY_GATE`, slides aside). 10-16 infected wait (asleep / wandering) along the backstreets
  (`BACKSTREETS.SPOTS`), plus a small pursuit.
- 9: reaching the school's back gate ends the mission ("Nichols Elementary School reached" on the results).
- Jonna's position, facing, clip and visibility travel in the host's state (index 13).
- Debug menu "skip" covers the new stages.

## 3. The backstreets (`game/scripts/coop/backstreets.gd`, new)

~500 m on foot from the service gate (street-local z 80) to the school's back gate (z 500), at street level. The lanes
are rectangles on a 1 m grid (`CORRIDORS`); the facades come from their outline, so every turn closes itself, and
buildings (3-6 storeys) stand outward of it. Six stretches, each after one reference photo:

| Stretch | After | What is there |
|---|---|---|
| Service lane | the New York alley | brick backs, fire escapes with drop ladders, dumpsters, sodium wall-arm lamps, a shutter half down with drag marks under it |
| Tile street | the Japanese street | tiled/plaster walls, painted edge lines, manholes, a side street blocked toward the main road (fire-glow, smoke, rattle) |
| Cinema arcade | the covered market | truss roof with plastic panels, teal tubes on chains, light-box signs, bicycles, the Avenida Cinema marquee |
| Parol lane | the Macau lane | narrow, Christmas lights across, a parol star on a balcony (November in Davao), a teal "MOBILE REPAIR" sign, graffiti at the dogleg |
| Pole street | the Tokyo corner | wider, balconies, utility poles with lamps, tower blocks with lit windows, a jeepney wedged across the road out |
| Brick alley | the winter alley (wet, not snowy) | brick and board siding, a row of wooden poles and lamps going away, bins, the school's cream-and-green back wall |

Every stretch: wet asphalt (low roughness), patches, manholes, puddles, wires strung across, AC units, pipes, meters,
lit windows behind curtains, Filipino shop signs (PAWNSHOP, BOTIKA NG BAYAN, LECHON MANOK, WATER REFILLING...),
trash bags, crates, drums, tricycles. The main road shows only past barriers at the side streets' ends (four fire
glows with smoke, a siren, crowd groans). Nichols Elementary School: back wall, green gate, "NICHOLS ELEMENTARY
SCHOOL / DEPARTMENT OF EDUCATION • DAVAO CITY DIVISION", a light on inside, a bedsheet "MAY TAO DITO / SURVIVORS
INSIDE". The school itself is for later.

Performance: each stretch has its own merged meshes (one per material) and collision body, culled at 150 m; labels
at 60 m; ~45 lights with distance fade (48 m), about a third shadowed. The backstreets add ~140 ms to the street's
~1 s build.

Deviation from "100% 1:1 copy": the references are Japanese, American and Macanese; the lanes copy their
architecture, props, lighting and wet-street look, but signs and details are Davao's (Filipino shop names, a parol,
a jeepney, tricycles, DepEd school), and the winter alley is wet instead of snowy. Lighting colour comes from the
lamps themselves; the one shared night grade is not switched by position (0.39 rule).

## Tests and review

- `tests/coop_backstreets_integration.gd` (new): ramp to the landing, through the gate, the yard path from the
  warren exit to the ramp open, office door shut/open/clear, floor under every backstreet cell, every stretch
  walked, infected path round the first corner. 9/9.
- `tests/coop_integration.gd`: now plays on past the store (Jonna opens, 15 lines shown, she sits, infected in the
  backstreets, back door, service gate, school reached, results). 34/34; network host 38/38 + client 4/4 (the host's
  "client flashlight state received" now waits up to 5 s: both processes run uncapped and the old 45-frame wait
  lost the race).
- `tests/coop_street_review.gd`: the ramp walk follows the new ramp. Passes.
- `tests/coop_approach_review.gd` (new): photographs (`-- --set=<dir> [--views=a,b] [--bright]`) -> work/v44/<dir>/.
- Full suite and EXE results: see the end of this file.

Blind review (lemondev): see the end of this file.

## Results (final revision)

- Build: `builds/windows/Interior.exe` + `Interior.pck` 0.44.0 (+ `Sleep-0.44.0-windows.zip`), boots to the menu
  in ~15 s. `Interior.exe -- --capture-review --capture-views=coop_route --capture-path=<dir>` (new) photographs
  the ramp, the gate, Jonna's door, her office and five backstreet stretches from the EXE: work/v44/exe_route/.
- Full suite (`INTERIOR_MUTE=1 python -I tools/run_tests.py`): every test passes except `upgrade_integration`
  (restart one node off, known since 0.43) and `balcony_integration` "Max throw at the railing stays on the
  balcony" (the thrown distance changes run to run; solo balcony code this run did not touch; not investigated).
  The runner shows "NO REPORT" for 14 tests whose verdict line has another format; all 14 logs end with zero
  failures. `zombies_integration` 109/109.
- Clip library: rebuilding `zombie_anims.glb` with today's build script changed existing clips (zombies test
  failed 3 forearm checks). The 0.43 library is back as it was; `sit_hurt` comes from
  `zombies/zombie_extra_anims.glb` (`zombie.gd EXTRA_CLIPS`). Rebuild the library only after checking that test.
- lemondev blind review (fresh critic, anonymous A/B, render vs the owner's reference photo, two pairs: service
  lane vs the New York alley, cinema arcade vs the covered market): pass 1 the photos won both; gap "no lamp pools on
  the street and walls, flat wet ground". Fix: downward pool lamps, less mirror-like asphalt, darker wall papers,
  every arcade tube lit, darker manholes. Pass 2: the photos won both again, same gap (lamp pools and wet response
  versus photography). Status: STOPPED — PLATEAU on the visual benchmark (two consecutive rejections, same gap);
  the renders are clearly closer after pass 2 (work/v44/pass3/) but a real photograph still wins. Packets and
  private mappings: work/v44/critic*/, critic*_mapping_PRIVATE.txt.

## Screenshots sent

| When | File | What |
|---|---|---|
| mid-run | work/v44/approach5/sheet.jpg | the new ramp, gate, checkpoint, floodlight, the dead |
| mid-run | work/v44/tune1/sheet.jpg | Jonna's office, first backstreet stretches |
| end | work/v44/exe_route/exe_route_sheet.jpg | the whole route from the 0.44 EXE |

## Open

- Squad bot pathing through the backstreets is untested in a real match (the AI follows players; the nav check
  covers infected pathing only).
- Jonna's lines and the squad's replies are text only (no voice), like Dodong's.
- The school is a wall and a gate; the next run builds it.
