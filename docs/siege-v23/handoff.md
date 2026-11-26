# The town under siege: Windows 0.23.0

Updated 2026-10-24. Asked for (via `@lemondev`):

- research zombie and horror games, then a strict QA and "horrorfication" of everything except the player's house;
- check the most important areas are reachable, with hints that lead to them;
- streets as an abandoned mess: lots of blood splattered on the walls, drag trails of bodies into dark corners;
- a path to the slums that is impossible to miss;
- play as the player, find the vast empty spaces and block them with sloppy rusty roof-sheet walls (yero), as if the
  village were holding out behind them;
- the hooded man's first sighting as a film: a cut to behind him at the gate staring up at the house, a pan to his
  side as he notices and backs off, then he walks (not runs) to his place;
- the moment the player opens the gate, he is at the end of the road to the rice fields; the road is walled off, but
  next to him is a broken hole the player can only get through crouching; the player sees him crouch through and run
  for his bahay kubo (to teach the player);
- the way to the Nichols property gets a secret entrance (details to be discussed later);
- no half-measures; screenshots during the work; the EXE rebuilt.

State: **IMPLEMENTED: UNVERIFIED** for the lemondev benchmark gate (no independent blind critic was run; see
"Verification"). Every automated test listed below ran on this revision; results are quoted as they came out.

## Research (what was used, and how)

Reference reading, used as mood and design rules, not copied (the owner's rule: our own twist, no clichés):

- Valve's *Left 4 Dead Design Theory* notes (via [World of Level Design](https://www.worldofleveldesign.com/categories/left4dead2_mapping/l4d2-visual-gameplay-reference-guide-campaign-design.php)
  and the [Valve wiki](https://developer.valvesoftware.com/wiki/Left_4_Dead_Design_Theory)): players drift toward light and
  away from dark, so the route to the slums is lit (a strung line of bulbs) and the rest stays dark; decals and
  scraps of environmental story let the player piece together what happened.
- [Kotaku on video-game graffiti](https://kotaku.com/cool-it-with-the-dumb-video-game-graffiti-965446561): understated beats
  writing it on the wall. So: no words, only arrows where someone marked the route, and an X on searched doors.
- *The Last of Us Part II* Seattle quarantine zone ([GamingBolt](https://gamingbolt.com/the-last-of-us-part-2-video-details-design-of-jackson-and-seattle)):
  a former safe zone, checkpoints, walls built by people. Our version is a barangay that walled itself in with roofing.
- *Dying Light 2* environment talks ([80.lv](https://80.lv/articles/designing-dying-light-2-s-environments-and-levels/)): the
  streets belong to the infected, people live behind improvised barriers.
- *Days Gone* horde previews ([Gamereactor](https://embed.gamereactor.eu/days-gone-preview/)): improvised wooden and metal
  defences that something outside keeps testing. Here: the knocks on the sheets.
- *Resident Evil 2* (2019) ([Game Developer](https://www.gamedeveloper.com/design/a-design-examination-on-resident-evil-2-remake)):
  "unseen presence" through level design; things half-glimpsed in the dark.
- Silent Hill 2 remake, Haunting Ground ([Automaton](https://automaton-media.com/en/?p=31806), [A.V. Club](https://www.avclub.com/haunting-ground-horror-game)):
  how a camera reveals a stalker. Our cutscene starts behind him, so the player sees what he sees (their own house).
- Filipino horror indies (*Hapunan*, *Dark Twilight*, [NoypiGeeks](https://www.noypigeeks.com/gaming/hapunan-pinoy-horror-game/)): the
  horror is local. So: yero walls, banig mats over the dead, candles, a barangay checkpoint, fiesta banderitas, tsinelas.

No screenshots or footage from those games are stored in the project.

## The QA pass (playing as the player)

`tests/world_audit.gd` floods everywhere the player's capsule can stand (or crouch) from the lane outside the gate, on a
0.75 m grid, and measures how far each spot is from the nearest obstacle. Before 0.23:

- every key area was reachable: the A/B corner 20 m from the gate, the road to the fields 67 m, the canal mouth 71 m,
  the catwalk 107 m, the warren entry 179 m, the Nichols gate 101 m;
- the streets had no open patches over 5 m of clearance, but every street end looked out over empty ground past the
  old police sawhorses (street A and C east, B north and south, D north and south) and the play area was held only by
  invisible walls;
- the biggest open space was the 1,650 m² dead-grass field between street B's south end and the Nichols gate.

The audit also exposed a bug in itself (a capsule resting on the floor clipped the sloped kerb edges and reported
street D as unwalkable); it now lifts the test capsule like the player's own step.

## What changed

### The wall (`scripts/town_siege.gd`, `scripts/siege_sheet.gdshader`)

- **Where.** Four runs just inside the old invisible bounds: north z 54.8, east x 25.8, south z -18.55 (the Nichols
  side), west x -23.85; plus a run across street D's south end (z 8.95) that hid the empty ground behind the houses.
  Where a house stands on a line its own wall closes the gap (none did on this layout). Sheets step out round poles.
- **What it is made of.** About 600 corrugated sheets of real geometry (76 mm pitch), most bays two high, overlapping,
  leaning, the tops torn on some; plywood patches; coco-lumber and bamboo posts; two nailing rails inside; diagonal
  braces; barbed wire with barbs on stakes along the top; tyres, sandbags and hollow blocks at the foot.
- **How it looks.** The shader weathers each sheet from dull galvanised grey through orange bloom to deep brown rust,
  some in faded roofing paint (blue, green, red oxide, chalked white) flaking where the rust came through, nail heads on
  the rail lines with rust run down below each, rain streaks, mud splashed up from the ground.
- **Reinforced where it was hit hardest:** a sofa, drums, a steel shelf and sandbags against the wall at street A's
  east end; crates, a drum and a propane tank at street C's.
- **The vacant lots across street A** got sheets raised behind their low front walls, so the street runs between walls
  of iron; each lot's own gate stays clear.
- **Something is outside.** Every 22-48 s, out of sight and 7-34 m away, something hits the sheets (two to five blows,
  the sheet booming, the nails rattling) or drags slowly along them; every 45-95 s a low voice carries over the wall from 8-20 m beyond it. Loose
  top sheets clack in the wind. All synthesised (`tools/assets/make_siege_sounds.py`).

### The three ways through

- **The slum passage (west end of street A).** A coco-lumber frame with a header, its two gate leaves of sheet iron
  dragged open into the town, a bulb on the header, a torn tarpaulin strip.
- **The survivors' path to it.** 31 pallets laid end to end down street A from the corner of street B to the passage
  (ramped colliders, so they are walked on, not tripped over), bamboo poles carrying a cable with bulbs every other pole
  (one failing), the cable running on into the settlement (that is where the power comes from), orange spray-painted
  arrows on the road at the lane mouth, the A/B corner and street D, and on walls where the route turns.
- **The hole (north end of street B, the old way out to the rice fields).** The sheet over the road was torn up from
  the bottom and bent out; the low rail was smashed through (splintered ends hang); a crosspiece was nailed over the gap
  later. The opening is 0.95 m wide and 1.3 m high: standing (1.7 m) the player is stopped, crouching (1.0 m) they get
  through. A board lies through it in the mud; muddy prints lead to it and away on the other side. Through the gap the
  moonlit road shows. Standing in front of it the HUD says "Hold C • crouch to squeeze through".
- **The secret way to the Nichols property (south end of street B).** Two sheets leaned against the inside of the wall
  look like more patching; behind them the bottom of the wall was pried up. Its west end is stacked with tyres; the
  open east end lets a crouching player in, along the wall and out under it. Nothing points to it. (The owner said the
  Nichols entrance will be discussed later: this is a placeholder that keeps the property reachable.)

### What happened in the streets (`scripts/town_horror.gd`, textures `tools/assets/make_siege_textures.py`)

- **Blood on the walls.** About 30 splatters and smears in all, sampled along every street at chest to head height:
  impact spatter (a lobed core, teardrops thrown one way, runs that dripped before they dried) and bodies slid down
  walls. Smears low on the inside of the wall where it was hit from outside.
- **Drag trails into the dark.** Nine trails: under yard gates into dark yards (street B twice, C, D, the A corner),
  two converging on the north-west corner where something lies under a blue tarp, one through the camp to its back
  corner, one from the checkpoint to where its dead were laid by the wall. Each starts at a pool; drops beside them.
- **The dead, covered.** Eight bodies under sheets, a grey sheet, banig mats and a tarp, draped over the shape of a
  person, blood seeping through at the chest and head, a pool under each; burnt-down candles by two; flies on most.
- **The evacuees' camp** (the middle vacant lot, through its gate): a collapsed tarp shelter on a bamboo ridge, an
  A-frame tent, banig mats with clothes, the cooking fire with the pot still on it, plates and a basin knocked over,
  monobloc chairs, a clothes line, and the drag to the back corner.
- **The barangay checkpoint** at the passage: tarp canopy (one corner torn loose), the table on its side, chairs, the
  logbook's pages blown across the street, the pool, and the tanod's flashlight on the ground, still on, pointing along
  the drag, its batteries browning out.
- **The rest of the mess:** burnt tyres melted to street B (steel belts, ash, a scorch), rubbish bags at corners,
  tsinelas singles and pairs, suitcases, boxes, umbrellas blown over, crows by the bodies and the corner, rats.
- **Fiesta bunting** (banderitas) still strung across streets A, B and C; some strings snapped and lie in the road.
- **Searched doors** marked with a sprayed X.
- The owner's house and courtyard stay clean (checked).

### The hooded man (`scripts/stranger.gd`, `scripts/stranger_cutscene.gd`, `tools/blender/human/build_human.py`)

- **The film (8.6 s).** When the player first sees him (or comes within 5 m) the game cuts:
  - 0.0 s behind him at the gate, low, past his shoulder up at the lit house, a slow push in;
  - 2.6 s the camera swings round to his side; at 2.9 s his head turns toward the player (a `LookAtModifier3D` on the
    head bone; the head's forward axis is found from the rig at runtime);
  - 3.7 s he lets go of the bars (they clank) and backs off (walk_back, slowed);
  - 5.1 s he turns away and walks (1.45 m/s, the walk clip) up the lane; the camera stays and pans after him;
  - 8.6 s cut back to the player.
  Black bars slide in, the HUD hides, the player is held (`InteriorPlayer.cutscene`), a low swell plays under it
  (`sting.ogg`). The pause menu pauses it.
- **After it** he keeps walking to his old spot by pole 9.
- **The gate opens** (the instant a leaf is past 0.15 rad): he is moved to the hole, facing the town.
- **The hole.** Once the player has seen him there for 0.6 s (or comes within 12 m) he turns, crouches through it with
  a new `crouch_walk` clip (the walk IK'd 0.4 m lower, stride x0.72, back bent, head up; baked in Blender), stands on
  the dirt road and runs to the bahay kubo as before. The rest of the story is unchanged.

### Debug menu, captures

- Debug menu (QWERTY), Player tab: "Wall hole", "Slum passage", "Secret crawl", "Hooded man to hole".
- EXE capture: `Interior.exe -- --capture-review --capture-views=siege --capture-path=<dir>`.

## Verification

Evidence in `work/v23/` (gitignored); selected images in this folder.

| Check | Command | Result |
|---|---|---|
| Walled town (new) | `godot --headless --path game --script res://tests/siege_integration.gd --fixed-fps 60` | 35 / 35 passed |
| Hooded man (updated) | `... res://tests/stranger_integration.gd --fixed-fps 60` | 42 / 42 passed |
| Hut story (updated: he goes through the hole) | `... res://tests/hut_story_integration.gd --fixed-fps 60` | 75 / 75 passed |
| Debug menu (new teleports) | `... res://tests/debug_menu_integration.gd` | 39 / 39 passed |
| Nichols (now walks in through the secret crawl) | `... res://tests/nichols_integration.gd` | 50 / 50 passed |
| Fields (road walk starts past the wall) | `... res://tests/fields_integration.gd` | 25 / 25 passed |
| Street, balcony (hooded man switched off: they drive the gate) | `street_integration`, `balcony_integration` | 27 / 27, 63 / 63 passed |
| Canal, warren, basement | `canal_integration`, `warren_integration`, `basement_integration` | 57 / 57, 87 / 87, 57 / 57 passed |
| Gun, touch (`-- --mobile-test`), room, interactions, night | `gun_integration`, `touch_integration`, `room_integration`, `neighborhood_interactions`, `night_revision_integration` | 41, 29, 271, 29, 28 checks, all passed |
| Neighbourhood decay (exit now crouched through the hole) | `neighborhood_decay_integration` | 30 / 32: "Abandoned town details / Derelict facades is visible while outside" fail; they fail the same way with `-- --no-siege` (pre-existing, not caused by 0.23) |

What the walled-town test proves with the real player and physics: standing, a walkability fill reaches the canal (the
passage) but not one cell of the fields or the Nichols side; crouching, it reaches both. The player walking upright at
the hole is stopped at z 54.45 (wall 54.8); crouching, reaches z 57.07 and crouches back in; stands up once clear.
Crouching round the lean-to and under the south wall reaches z -19.71. Straight at the lean-to, the player is stopped.
The passage is walked upright to x -27.9. A knock comes from outside the wall. No decal touches the owner's house.

What the hooded-man test proves: the cutscene starts 14 frames after he is seen from the stair; its camera has the view,
the player is held and the HUD hidden; the pause holds him; the first shot is from behind him; his head turns fully
(influence 1.0); he backs off (walk_back); he walks away at 1.45 m/s (never runs); the view, control and HUD come back;
the player did not move. His routes (lane; dirt road from the hole) are clear of every collider for a 0.25 m capsule;
crouched he fits through the hole, standing he does not. Opening the gate puts him at the hole on the next frame; seen
from up street B he crouches through (crouch_walk), runs down the middle of the road (0.01 m off the centre line) and
disappears into the hut.

Rendering (Forward+, High, 1600 x 900, RTX 4060): `tests/siege_review.gd` 22 views held the 60 FPS cap in every view
(this measures the cap, not headroom); draw calls rose by 70-370 per view over 0.22 on the same cameras.

Not verified:

- **Blind benchmark comparison.** The lemondev gate wants a fresh, context-isolated critic to compare these renders
  against a commercial reference; none was run (this session does not start sub-agents unless asked). The research
  above was used as design guidance only.
- **Android.** The Compatibility renderer has no decals, so the blood, arrows and prints will not show on the APK; the
  APK was not rebuilt (still 0.12).
- **Sound in the room.** The knocks, scrapes, groans and the sting were made and wired in (levels and spectra
  checked numerically); nobody listened to them here.
- **Darkness.** At the game's own night exposure most of this is dark until the flashlight (from the hut drawer) is
  on; the lit route to the passage and the moonlit hole are the deliberate exceptions. Judge with the EXE.

## Next (for the owner)

- The secret way to the Nichols property is a placeholder (a crawl behind leaned sheets at the south end of street B)
  until its design is discussed.
- Possible follow-ups: actual infected (none walk the streets yet: the threat stays outside the wall), the APK, and a
  blind critic pass against a commercial reference for the lemondev benchmark gate.

## The build

`builds/windows/Interior.exe`, 0.23.0, exported 2026-10-24 20:24, 1,368,458,776 bytes,
SHA-256 `40eae9462f051414aca1ca1bec6e7ae3e5715af83b154e876234f0b1d26331e9`. Its own capture
(`-- --capture-review --capture-views=siege`) reports the wall packed (597 sheets, 266 upper, 94 posts, 43 braces,
1,362 barbs, 31 pallets, 4 bulbs, 98 colliders) and saved the frames in `final-3-exe-capture.jpg`, including two frames
of the cutscene. The APK was not rebuilt.

## Screenshots sent

The owner asked for renders during the work. Sent so far:

| When | File |
|---|---|
| Mid-run: walls, path, hole and dressing by flashlight; cutscene frames | `progress-1-walls-torch.jpg`, `progress-2-cutscene.jpg` |
| Final: 22 views by flashlight; the same at night (brightened x2.6 for viewing); the EXE's capture | `final-1-flashlight-views.jpg`, `final-2-night-views-brightened.jpg`, `final-3-exe-capture.jpg` |
| Final close-ups | `siege-2-path-to-passage.png`, `siege-4-hole.png`, `siege-8-cutscene-behind.png`, `siege-9-cutscene-side.png`, `hooded-man-through-the-hole.png`, `covered-body.png` |

## Files

- New: `game/scripts/town_siege.gd`, `town_horror.gd`, `siege_sheet.gdshader`, `stranger_cutscene.gd`;
  `game/assets/siege/*` (decal textures), `game/assets/audio/siege/*` (sounds);
  `game/tests/siege_integration.gd`, `siege_review.gd`, `cutscene_review.gd`, `world_audit.gd`;
  `tools/assets/make_siege_textures.py`, `make_siege_sounds.py`; `tools/contact_sheet_dir.py`.
- Changed: `stranger.gd` (cutscene, hole states), `player.gd` (`cutscene` hold), `interior.gd` (`context_prompt`,
  `--capture-views=siege`), `neighborhood.gd` (builds the siege), `debug_menu.gd` (teleports),
  `tools/blender/human/build_human.py` (crouch_walk) and `game/assets/characters/stranger.glb`,
  `tools/assets/make_basement_sounds.py` (writes Vorbis in blocks), tests `stranger_integration`, `hut_story_integration`,
  `debug_menu_integration`, `street_integration`, `balcony_integration`, `fields_integration`, `nichols_integration`,
  `neighborhood_decay_integration`. `-- --no-siege` leaves the wall out (A/B checks).

## Rebuild

```
python tools/assets/make_siege_textures.py
python tools/assets/make_siege_sounds.py
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/human/build_human.py -- export
.local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path game --export-release "Windows Desktop" <abs>/builds/windows/Interior.exe
```
