# 0.68 handoff: the hospital after the bridge (Davao Central Laboratory), Doctor Berido, Doctor Lucky

Owner's ask (2026-11-26): after the bridge, Ma'am Teves and the students removed, a loading over the leaderboard, the squad
teleported outside a hospital: ambulances, mayhem, every path blocked but the entrance; doctors, nurses and police outside
who talk about the survivors and the roof, and stay there. Inside styled exactly on work/Reference/Davao Central Laboratory,
creepy: mess, dead and flickering lights, sparking electricity; blocked pathways; the stairs to the second floor; Doctor
Berido hidden somewhere on it; the cafeteria's ladder into the vents to a room with a hidden entrance and stairs to the
third floor; a peaceful third floor where the squad finds five things for him; the electric door to the secret lab; its
scientists and doctors turned; his story; the boss Doctor Lucky, the Morboid (fast, big claws, unhinged jaw, leaps, climbs
and sticks to walls); at least 10 new zombie costumes; build, update, publish, push everything to main.

## What was built

| Area | What | Files |
|---|---|---|
| Flow | Across the bridge (`_win_outer_street`) the run no longer ends: `flags.bridge_out` + the chapter board. Teves and the students are freed on every peer. The board loads "Davao Central Laboratory": Outer Street put away and let go of, the hospital built, its people loaded, its floors premapped for the nav, warm-up. READY: everyone stood outside the hospital (stage 18 `HOSPITAL`). The flare on the roof wins (stage 19 `WON`; 20 `FAILED`). | coop/mission.gd, coop/session.gd |
| The street outside | Two ambulances (back doors open, light bars turning, lit inside), two police cars, a triage left on the pavement (body bags, gurneys, blood), barricades, burning wrecks, a pole down with its cable sparking, lamps dying. Both ends of the street are buried (a jackknifed truck and cars west, a burning pile-up east), the row across is shut, the hospital's grounds fenced: the only way is the entrance under the EMERGENCY canopy. Six living people stay by the ambulances (two doctors, two nurses, two officers). | coop/hospital_world.gd `street_outside`, `facade`; coop/hospital.gd `after_build` |
| Ground floor | The lobby from the references: white terrazzo with grey and blue chips and a blue sweep, a ring of blue in the floor, the blue ring in the two-storey ceiling, white block walls over a greige wainscot, blue door frames, the glass front in blue mullions, reception, the waiting rows. The grand stair's middle flight came down; the west corridor is barricaded to the ceiling with beds; the way north caved in. East hall with blue lockers and blue soffit beams (blocked at its end), the ER's curtained bays (in through its side door), out its back to the back corridor (the morgue's drawers), west to the stairwell. | hospital_world.gd `ground_floor` |
| Seals (NOW standard) | Everyone inside: the lockdown shutter comes down inside the whole glass front and the street (and the people outside) is put away. Everyone up on the second floor out of the stairwell: its fire door slams and the ground floor is put away, except the lobby, which the balcony looks into. Everyone on the third floor: the second floor and the lobby go too. Roots are hidden, stopped and their meshes let go of a little each frame; the dead and (host) the infected there are freed. | hospital.gd `host_tick`, `sync`, `_put_away`, `_view` |
| Second floor | The corridor of the black clinic reference: ducts overhead, curtains, gurneys; the balcony over the lobby (glass rail, blue band); the nurses' station; the cafeteria and its kitchen; ward A, ward B, the operating theatre, the scrub room. Doctor Berido is crouched in the sterile supply room behind the theatre: its door is blocked by fallen shelving, the only way in is crouched through a broken partition (1.05 m) from the theatre. Finding him brings infected down the corridor from both ends. | hospital_world.gd `second_floor`; hospital.gd `_doctor`, `_berido_wave` |
| The vents | The kitchen's ladder up through a hatch into a 1.1 m duct (the player is put in a crouch at the top: player.gd ladder step-off), north over the stairwell, east to a grille that drops into the sealed records room. Squad AI and the doctor are brought through to the records room when the first player drops in. | hospital_world.gd `_ducts`; player.gd `_ladder`; hospital.gd `_records` |
| Hidden stair | The bookcase in the records room (E) slides aside: a stair that was never on the plans, up into the third floor's records annex. | hospital_world.gd, hospital.gd |
| Third floor | Quiet: no infected. White panels, light strips, glass-fronted rooms (refs). Five things: the keycard (by a dead scientist in the corridor), the logbook (the director's desk), the override key (security's key cabinet), the fuse (the electrical room's fuse box, sparking), the battery pack (the server room). E takes one; E at the doctor hands over what the squad carries. All five: he works the door's panel for 6 s, it turns green and the two leaves slide apart. | hospital_world.gd `third_floor`; hospital.gd `ITEMS`, `interact` |
| The laboratory | Two storeys: six glowing tanks on a plinth with a brain turning in each, seven pods along the north wall, hex ceiling lights, benches, hazard bands, a yellow-railed catwalk at 12 m with a stair, the ladder to the roof hatch. When the door opens 12-18 of its staff come at the squad. Cleared: the doctor sits by the tanks and tells what was done here (six lines). Then the red pod breaks. | hospital_world.gd `laboratory`; hospital.gd `_lab_wave`, `STORY` |
| Doctor Lucky | Model: build_lucky.py on the game's downloaded base body (lab coat torn, arms 40 % longer, jaw unhinged to the sternum with needle teeth and a gullet, three bone claws per hand, spine spurs, 1.12x). Ten clips (lucky_clips.py). Fight: 6 m/s sprint, two-claw swipe, a leap of 10-20 m onto where his target stood (the tell: his claws scrape sparks off the floor), onto a wall above the catwalk where he clings and crawls spread like a spider, then drops onto someone; twice a scream that breaks the pods. Health 2200 + 700 a player (+250 a bot), head x1.6. His health bar is a heart monitor's trace that runs as far as his life and flatlines when he dies. | coop/lucky.gd, coop/lucky_body.gd |
| The roof | The pad on the laboratory's roof; E at the flare: it goes up red and the run is won. | hospital_world.gd `roof`; hospital.gd `_flare_tick` |
| New infected (12) | lab_surgeon_m, lab_surgeon_f, lab_scientist_m, lab_scientist_f, lab_hazmat, lab_cleanroom, lab_paramedic, lab_guard, lab_patient_f, lab_burned, lab_head_nurse, lab_morgue (INFECTED 75..86, `LAB_FIRST`). | tools/blender/human/build_zombies.py |
| Living people (7) | hosp_berido, hosp_doctor_m, hosp_doctor_f, hosp_nurse_f, hosp_nurse_m, hosp_police_1, hosp_police_2. | tools/blender/human/build_hospital_people.py |
| Textures | terrazzo, lab tile, hazard band. | tools/hospital_textures.py -> game/assets/hospital |
| Debug | Jumps hospital, hosplobby, hospstairs, hosp2f, berido, kitchen, records, hosp3f, labdoor, lab, lucky, hosproof (Missions tab section "Davao Central Laboratory"). | mission.gd `JUMPS`, `_settle`; debug_menu.gd |
| Fix | A sliced unload left over from an earlier chapter kept walking the scene after the hospital was built and switched it off (process disabled = its colliders gone: the player fell through its floors). Nodes with meta `never_prune` are skipped by `_prune` / `_prune_one`; the hospital, its people, its dead and its infected carry it. | mission.gd |

Blender MCP was not connected in this session: every model was built with Blender 5.2 from the command line (the same way
as Heavy-arm), scripts in tools/blender/human.

## Text on screen added in 0.68 (all of it, verbatim)

- Loading/board: chapter title "Davao Central Laboratory"; steps "Putting Outer Street away", "Letting go of Outer Street",
  "Building the hospital", "Loading the hospital's people"; board lines "Outer Street", "Across the long bridge. Next: Davao
  Central Laboratory."
- Sign: "EMERGENCY" (over the entrance).
- Objectives: see `STEPS` in scripts/coop/hospital.gd (16 lines) and the items line "Find what Doctor Berido needs to open
  the laboratory's door: the keycard, the logbook, the override key, the fuse, the battery pack (%d of 5)." (+ " Bring what
  you have to him."), "The flare is up."; mission OBJECTIVES "Get to the hospital's roof.", "The flare is up over the hospital.";
  END_TITLE "The flare is up over the hospital".
- Prompts: "E • Speak to the doctors", "E • Go on", "E • Speak to Doctor Berido", "E • Pull the bookcase", "E • Take the
  <keycard|logbook|override key|fuse|battery pack>", "E • Give Doctor Berido what you found", "E • Fire the flare".
- Dialogue: `OUTSIDE_TALK` (6 lines: Doctor / Officer / Nurse), `BERIDO_TALK` (5), `STORY` (6), `GIVE_LINES` (5) in hospital.gd;
  one-off lines "Officer: The shutters are coming down behind you! Go!", "Doctor Berido: The bookcase against the far wall.
  Pull it.", "This stair was never on any floor plan.", "Nobody was supposed to come up here. This whole floor belongs to the
  laboratory.", "That's everything. Stand back. I don't know what's still alive behind it.", "It's over... The roof. The ladder
  is up on the catwalk. Go, signal them."; boss name "Doctor Lucky, the Morboid".
- Names above heads: "Doctor Berido" only (the people outside have none).
