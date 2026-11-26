# 0.53 handoff — Heavy-arm at PILCST's rear gate, names at any distance, loading at the chapter boards

Owner's request (2026-11-22): at the school, once the squad is out in the field with the survivors, someone sits at the
exit gate as if waiting: a mutant, "Heavy-arm", one giant mutated arm (download a model, modify it, mutate the other
arm too, the best animations). The squad reacts in the dialogue box, confused and shocked, that it might have mutated.
Attacks that need a 2-3 s charge-up: a charge, a throw of projectiles, a roar that calls zombies from afar to hit the
squad from behind (with an indicator). Hard to kill, but big damage from explosions: let him charge into explosive
barrels. A boss health bar. In multiplayer, never hide teammates' names, however far, and show the distance. Killed, he
drops a shining, sparkling key to the gate (shut by default), and the gate opens with it. Every time a scoreboard
(chapter board) shows, load and unload, and show a loading screen so the players know the next level is ready.

## Heavy-arm (the model)

- Base: **"Boss Zombie Sculpted" by shaz13** (Sketchfab fa85d0ef26bd4dba9445ff5dd3baa1bd, CC BY 4.0), from the
  Objaverse mirror (`tools/assets/fetch_heavyarm.py`). A 1.56 M-vertex untextured sculpt of a muscled, bald infected man.
  Credited in `game/licenses/THIRD_PARTY_MODELS.md`.
- `tools/blender/human/build_heavyarm.py -- model clips preview export` (Blender 5.2, ~10 min on the CPU):
  decimated to 26 k vertices (52 k triangles), unwrapped, the sculpt's detail baked to a 2048 normal map, occlusion
  baked from the low mesh; skinned to the town skeleton by copying the base body's weights in the sculpt's own pose
  (arms 63 degrees down, legs 9 out), then turned into the T pose; **mutated**: the right arm swollen (up to 3x a man's
  girth at the forearm, a club of a hand) and lengthened (upper arm 1.12x, forearm 1.34x, its bones too), raw and
  striated, bone spurs along the forearm, over the shoulder and out of the knuckles; the **left arm** gone wrong another
  way (tumours, necrotic black skin, five bone blades out of the forearm toward the elbow); a hump over the right
  shoulder; the whole 1.25x (2.25 m); painted by a baked procedural shader (dead grey skin, bruising, veins, torn dark
  shorts, old blood). Out: `game/assets/characters/zombies/heavyarm.glb` (6.4 MB).
- He was **Mang Dado, the guard who kept that gate**: the game hangs a guard's lanyard on his chest with the ID card and
  the gate's key on its ring (heavyarm_body.gd `_lanyard`). That is why he sits there, and why the key is his.
- **Clips**: everything the town's infected have (his skeleton is the town skeleton; `Skeleton3D.motion_scale` 1.25
  carries the hips at his size; the town clips move only root and hips by position) plus ten new ones
  (`tools/blender/human/heavyarm_clips.py` -> `heavyarm_anims.glb`): heavy_sit (against the gate, knees up, the fist on
  the ground, head hung, a twitch), heavy_rise (pushing up off the ground with the heavy arm), heavy_idle, heavy_walk
  (the hurt walk slowed, leaning to the heavy side), heavy_wind (the charge wind-up: crouched, fist cocked back,
  trembling), heavy_charge (the run leant in, the arm forward like a ram), heavy_dig (the throw wind-up: tearing a slab
  out of the ground), heavy_throw (overhead and over, let go at 0.52 s), heavy_inhale (the roar wind-up), heavy_daze.
  From the library: boss_roar, boss_slam and boss_sweep (melee), stagger_heavy; death is the ragdoll.

## The fight (`scripts/coop/heavyarm.gd`, host; every peer draws it from `mission.flags.boss`)

| State | What happens |
|---|---|
| sit | spawned at the blast (stage 14), sat against the shut gate. A person within 15 m, or 27 m with a line of sight: |
| talk | the squad's lines in the dialogue box: "Wait. There's someone by the gate...", "That's no survivor. Look at its arm...", Ma'am Teves: "Diyos ko... Mang Dado?... He locked it every night at nine.", "...It's changed into something.", "...the gate's key is on his lanyard". Anyone within 8.5 m, or a round in him, cuts it short |
| rise, roar | heavy_rise, then boss_roar; the boss bar comes up (top centre, "HEAVY-ARM", red with a pale trail) |
| fight | the heavy walk at the nearest (1.75 m/s, 2.3 below 40%); within 3 m a sweep or a slam (28 / 34, thrown) |
| charge | 2.5 s wind-up, a red lane on the ground (follows the target, holds still for the last second); then 10.5 m/s along it: anyone in it 42 and thrown; infected in it killed; a drum in it goes up on him; a wall or the field's edge stops him dazed |
| throw | 2.5 s tearing up a slab, three red rings where it and two chunks will land (follow, then hold for the last half second); the slabs arc over (seen by everyone), each hurts and throws whoever is under it (up to 46 / 26), kills infected, sets off drums |
| roar | 2.4 s breathing in, then the roar: 5-11 runners come from 30 m behind the squad (away from him); an arrow at the screen's edge points at them ("They're coming from behind!") for 10 s |
| daze | after a drum or a big grenade: stagger then heavy_daze (3.2 s); rounds do 1.8x |
| dead | ragdoll; the key drops beside him, turning, shining (gold light, star sparkles); Ma'am Teves: "Take it, open the gate!" |

- Health 2400 (+800 per extra person, +300 per squad AI, Hard x1.25, Easy x0.8). Rounds: x0.42 head, x0.2 trunk,
  x0.04-0.06 the heavy arm (heavyarm_body.gd ARMOUR). A grenade x1.35; a drum going up beside him up to 560.
- **Fuel drums** (11, `BARRELS`): red 200 L drums of gasolina for the generator and the grass cutters ("GASOLINA /
  PILCST GENSET", "HUWAG MANIGARILYO"), in pairs and alone along the field's far half. A few rounds, a grenade within 3 m,
  a slab or his charge set one off: the grenade's fire, smoke, bang and shake (grenade.gd `detonate`), a burning puddle
  for ~15 s, drums within 2.6 m go up after it, infected within 6 m thrown.
- **The gate** (school.gd): shut, chained and padlocked, solid. E there: "Chained and padlocked. The key is on the
  guard's lanyard." With the key: "E • Unlock the rear gate": the chain off, the leaves swing out onto the street; the
  board comes only once it is open (escape.gd `_field`). While he is up the field's trickle is lighter; nothing comes
  through the shut gate.
- Objective line (mission.objective): "Kill Heavy-arm. Rounds barely hurt him; blasts do. Bait his charge into the
  fuel drums." -> "Take the rear gate's key from Heavy-arm." -> "Unlock the rear gate." -> "Through the rear gate."
- Networking: the boss is enemy kind 900 (mission.make_enemy builds heavyarm_body.gd on every peer from the
  snapshot); his state, lane, rings, slabs, the pack's arrow ride in `flags.boss`; drums in `flags.drums`; key in
  `flags.heavy_key`/`heavy_key_taken`; gate `flags.reargate`. New RPCs (session.gd): `knocked` (a blow throws that
  peer's own player: player.gd `throw_back`), `barrel_report`, `boss_blast_report`.
- Debug: jump `heavyarm`; `boss charge|throw|roar|kill|hp <n>`; `complete` at stage 15 kills him, takes the key and
  opens the gate, then the board.

## Teammates' names at any distance

session.gd `update_avatars`: a teammate's tag is never hidden (no visibility range), drawn at a fixed size through walls,
and reads "Aljay   86 HP   42 m".

## Loading at the chapter boards

While a chapter board is up, each game loads (session.gd `_start_chapter_load`, a step a frame, at most ~12 ms each),
and the board shows it: "Loading: The backstreets • Loading the college's people" with a bar, then "The backstreets:
ready". READY stays "Loading..." until then. The steps are real work:
- the mart's board: the front shut; **let go of the street behind** (mission.free_unloaded: every mesh the soft unload
  hid has its mesh and material dropped, so the GPU's copies go); the backstreets and the college woken; the college's
  people (students, staff, parents, Ma'am Teves and her students, Rommel, Heavy-arm and his clips) loaded from disk;
  then each drawn once in front of the lens behind the board, so their shaders compile there and not in the school.
- PILCST's board: the college put away and let go of, the night's dead freed; Davao City is the next chapter and is not
  built yet (said so on the board).
When everyone is READY the board closes into a loading screen (black, the chapter's name, the bar full, "Ready") that
fades into play (not after PILCST's board: that one ends in Match Results).

## Fixed on the way

- `KEEP_HI` (what stays when the squad leaves the mart behind) ended at z 560, halfway across the school field: the far
  half's separate pieces (the rear gate's lamps, the jeepney and tricycle beyond it, Heavy-arm, the drums) were put away
  in real play. Now z 625.
- `debug_jump` stopped after 12 completes: a jump from the start to stage 13-15 never arrived. Now 20.

## Tests

- `tests/coop_heavyarm.gd` (new, 48 checks; prints INTERIOR_HEAVYARM): sat at the shut gate at his size, his clips,
  hips on the ground, the drums, the gate solid and "gatelocked"; seen -> the talk (Mang Dado) -> up -> the bar and
  objective; rounds barely mark him (chest 10, head 21 of 2700 for a 50 round); a drum beside him (808, its neighbour
  goes up too, dazed); the charge (lane, run, the one in it hurt and thrown); a drum in the lane goes up on him; the
  throw (three rings, three slabs, landed on the one under them); the roar (a pack from behind the squad, the arrow);
  dead (ragdoll, key shining), E takes it, E unlocks, the gate swings open, a teammate's tag at 60 m with the distance,
  the board loads, READY -> WON.
- `tests/coop_escape.gd`: the rear gate step now opens the gate first (fight.debug_finish).

## Results

- Build: `builds/windows/Interior.exe` + `Interior.pck` **0.53.0** (tools/export_windows.py, re-baked), zip
  `Sleep-0.53.0-windows.zip` (1602 MB). Boots to the menu's first frame in 17.5 s.
- EXE capture `Interior.exe -- --capture-review --capture-views=coop_heavyarm --capture-path=<dir>`: work/v53/exe/
  (20 views, sheets exe_sheet0.jpg / exe_sheet1.jpg).
- Tests (headless, one at a time): coop_heavyarm 48/48, coop_escape 38/38, coop_school 44/44, coop_chapters 26/26,
  coop_integration 39/39, coop_jumps --walk 86/86.
- Not measured: frame times during the fight (drum fires are GPU particles, short-lived). Not tested: two real PCs.

## Screenshots sent

| file | what |
|---|---|
| work/v53/heavyarm/model_sheet3.jpg | Heavy-arm in Blender: front, three-quarter, back, the heavy arm close |
| work/v53/exe/exe_sheet0.jpg | from the 0.53 EXE: sat at the shut gate, close, the squad's lines, up roaring with the bar, the heavy walk, the charge's lane, the charge, the throw's rings, the slabs, a drum going up |
| work/v53/exe/exe_sheet1.jpg | from the 0.53 EXE: dazed, the roar's arrow, close, breathing in, dead with the key shining, the gate open, a teammate's name at 44 m, the board loading, the board ready, the loading screen |

## Open
- Students are still invulnerable and ignored by the infected (0.52's open question).
- Davao City is not built; the PILCST board's "next chapter" loads nothing.
- Squad AI are not thrown by his blows (only hurt); people are.
- Not tested on two real PCs.
