# 0.41 — Store Road and Mabini Mart rebuilt; tables you drag, infected that shove and climb them; hints; co-op gore

Owner's request (2026-11-18): polish and add big improvements to the multiplayer map (the structures, roads and paths
to the convenience store) and thoroughly improve the store, from the references in `work/Reference` (three store
images, six night-street photos). Hints now and then at the bottom centre (light and sound draw them, etc.), plain,
not AI-sounding. Tables outside the store that can be dragged to block the entrance, with a hint. Infected that push
things, vault tables and stumble realistically. More ragdoll polish and destroyable bodies. Build the game.

References were used for mood only (memory: original twist, Davao setting): shutters, sodium lamps, wet concrete,
manholes, wires and poles from the street photos; aisles, a wall of drink fridges, a window bar with stools under
yellow pendants, the counter by the door and a stockroom behind from the store images.

## The map (scripts/coop/street.gd, rewritten)
- **Market lane** (z 1-17 past the gate): two-storey shophouse blocks with roll-up shutters and painted signboards
  (BIGASAN NI ALING NENA, LECHON MANOK, KARINDERYA, E-LOAD DITO, TAILORING, WATER REFILLING STATION), grilled upper
  windows, air-con units, downpipes; a holed canopy of old roofing on steel beams, hanging bulbs (one failing), wires
  across; a food cart and a tricycle make a chicane; gutters, grates, a manhole, puddles, rubbish, BAWAL UMIHI DITO.
  One stall is half open with a strip light still on inside. A body in the lane, spatter round it.
- **Purok 4 road** (z 17-49): concrete panels with joints and patches, raised footpaths, curbs and grates; four
  concrete poles with crossarms, a transformer, sagging wires pole to pole and down to the houses, sodium lamps on arms
  (each run: one dead, one flickering, chosen by the run seed). The four enterable houses are now two-storey (planks
  over concrete), low front walls, grilled windows, house numbers, a dim bulb inside some. Between them: a sari-sari
  store with its grille and snack strips, a fenced vacant lot with the soldiers' truck, a waiting shed, a dark side
  alley, a vulcanizing shop. A dead jeepney across one lane; a tricycle on its side; laundry on a line; a drag trail
  of blood from the jeepney door to a body in the gutter.
- **The checkpoint** (z 46-50): sandbag walls across the road with a gap, cones, a pushed-aside CHECKPOINT barrier,
  brass all over, a helmet, a radio still hissing, the body of whoever held it.
- **Forecourt** (z 50-56.5): parking lines, bollards (entrance left open), the MABINI MART / BUKAS 24 ORAS pylon
  (one panel failing), an ice chest, a gas-cylinder cage, stacked monobloc chairs, **five tables** (two long folding,
  two round steel, one red plastic). Fences close the gaps either side of the store: the service alley behind is
  shut off from the street.
- **Mabini Mart**: lit fascia band and canopy tubes; posters and a half-down shutter on the glass; the sliding doors
  stuck open, one burst (glass on the floor). Inside: coloured wall bands with category panels, three gondolas with
  end caps (one tipped over in an aisle), freezer chests and wall shelving on the left, a window bar with stools under
  yellow pendants, the checkout (register, cigarette rack, food warmer), a wall of four lit drink fridges (one
  hanging open, bottles out), hanging aisle boards, tube troffers (some dead, a few flickering, one sparking), a dome
  mirror and a camera. The soldiers' sandbag horseshoe facing the door, brass, a wet-floor stand, red baskets; their
  crates on a pallet by the right wall with the rifles, ammo cans and **two shotguns** (new pickup). A blood trail
  from the sandbags through the aisle into the **stockroom** (racks, boxes, one bulb, a body) whose **steel back door**
  opens on the service alley. A staff room behind a shut door. Fridge hum and tube hum.

## The mission (scripts/coop/mission.gd)
- **Noticing** (host, 5x a second): not every infected is hunting. On Store Road each run puts 5-9 of them about
  (wandering a spot, asleep, or eating one of the dead), plus the house sleepers. They notice: the flashlight beam on
  them (16-24 m) or the lamp in the dark (6-11 m), a survivor in front of them close up, movement noise (running
  ~11 m, walking ~4.5 m, sneaking/crouched ~1.6 m; less through walls), and **gunfire** (32 m pistol/shotgun, 42 m
  rifle, through walls at reduced range). A turned one screams, and the ones near it turn too.
- **Run up the road**: the pack from behind now starts 7 s after the gate opens (the gate's noise) instead of at once.
- **Last stand**: the front wave as before, then 14 s before the (random, 24-42 s) breach a second group comes down
  the service alley and hammers the back door (banging, dents) until it gives (~15-20 blows). A table pushed against
  the door inside cuts each blow to 28%.
- **Tables**: hold E near one to drag it (host physics, everyone sees it), let go of E to leave it; you move slower
  while dragging and do not bump the table you pull. The squad AI does not drag.
- **Squad AI** leaves an unaware infected alone unless it is within 7 m (a shot wakes the street).
- Objective 5 now reads "Hold Mabini Mart. Drag the tables into the doorway."

## The infected (scripts/coop/figure.gd)
- Collide with loose things (layer 4). Lean on a table in the way: one alone moves it slowly, a crowd fast; now and
  then one throws itself at it (wall_impact clip, a hard shove, growl). After their patience runs out (climbers ~0.7 s,
  pushers up to 3.6 s) a braced table is **vaulted** if there is ground to land on beyond it (launch clip, arc over
  the top); two tables one behind the other leave nowhere to land, so they have to shove. Also vault sandbags and
  other low static things when stalled. Landings go wrong often: a stagger, or flat down and up again.
- **Trip over the dead** (bodies and the street's victims): a stagger or a fall. Walk with a lurch from side to side.
  Feet that walk into a body move it (every peer).
- Can't reach you across a table (the bite needs a clear line at hip height).
- Unaware behaviour: idle, wander (idle_look pauses), feed (devour) over a body.

## Ragdolls and gore (co-op now matches solo)
- Parts come off in co-op: the host keeps what each part has taken (`tear`, the gun's own `sever` value) and tells
  everyone (`session.cut_all`): head (whole, or bursting under a close shotgun load), arms at shoulder/elbow/wrist,
  legs at hip/knee/ankle, a chest that comes apart, a belly that lets the legs go; pieces torn out first at 40% and
  74%. Losing the head, chest, belly or a leg finishes it; with an arm gone it keeps coming but hits softer.
- The dead come apart too: rounds into corpses are reported to the host (`corpse_hit_report`) and torn the same way.
  The street's own dead (4 per run, local to each peer) tear locally.
- Death: a head shot drops it where it stands (legs out from under it), anything else goes with the rounds; one to
  three twitches after; bodies rest on tables and sandbags (mask 2|4); severed parts too.

## Hints (scripts/coop/session.gd)
Bottom centre, 15 px, fading in and out, one every 24-38 s, each once. Start: flashlight, running/sneaking,
gunfire, head shots, H heals, bodies trip them (+ the ~ squad menu if there are AI). On the road: the tables, where
the guns are. In the store: climb vs two deep, enough of them slide a table. On the first blow at the back door: the
back door and bracing it. Text is in `HINTS`.

## Other
- `run_seed` sent with `begin`: every peer builds the same street; the host's director uses it too.
- Blood on the street is the project's liquid decals (`stain`, `drag_trail`) painting only the street meshes
  (layer bit 8), not people walking over it.
- player.gd: `release_hook` (called when E comes up).
- EXE capture `--capture-views=coop` adds coop_map_lane/road/checkpoint/store/inside, coop_barricade (5 infected at
  two tables in the door), coop_gore_head, coop_gore_down; prints INTERIOR_COOP_MAP.

## Tests
- `tests/coop_street_review.gd` (rewritten, 16 checks + 14 photos to tmp/coop_*.jpg): floodwall ramp, chase, shot,
  climbs a braced table, two deep get shoved (not climbed), host drags a table 3.4 m and lets go, back door gives
  (18-19 blows), head off a living one, arm off a corpse, the street's dead tear, dark+still survivor not noticed at
  10 m, beam noticed, gunshot wakes, hint shown. **Pass.**
- `tests/coop_integration.gd` 25/25 (table check now take/let go; final-wave loop longer for the back group);
  loopback host 29/29 + client 4/4.
- `tests/coop_squad_integration.gd` 27/27 (the squad holds fire while the player's own rounds are measured; they
  were finishing the target first).
- `tests/debug_menu_integration.gd` 38/39: "Brightness × 2 (9.1)" failed, a solo-world lighting reading; the co-op
  street is not built there. Not investigated.

## Screenshots sent (work/v41/screens/)
map_lane_mid, map_road, map_front, map_inside, map_counter (during the run); from the EXE (work/v41/exe/): coop_barricade, coop_gore_head, coop_map_road, coop_map_lane, coop_map_store. Build: builds/windows/Interior.exe 0.41.0, its capture printed head_off true, doorway table shoved 1.84 m.

## Open
- Clients can't shove a table by walking into it (only the host's physics moves them; dragging works for everyone).
- Co-op infected still don't crawl without legs (a lost leg finishes them).
- The street's victims are local to each peer (their tears are not shared).
