# Location register

Every position is world `(X,Y,Z)` in metres. A reference point is not necessarily a safe teleport target. Positions on doors usually mean hinges; positions on objects mean node origins. Runtime values are a startup snapshot, not an immutable authored placement.

## Home

| ID / name | World position | Meaning / source |
| --- | --- | --- |
| H01 Player spawn | (0.62, 0.1, 1.3) | Player feet spawn; room floor near Y=0. `game/scripts/interior.gd:93` |
| H02 Navy entry door hinge | (2.43, 0, 2.634) | Leaf spans X=1.39..2.43; inner face Z=2.6335. Swings inward toward -Z. `game/scripts/hinged_door.gd:1` |
| H03 Studio sliding door | (-3.23, 0, 2.84) | Door node origin, not doorway midpoint. Opening X=-3.25..-1.24, Z near 2.9, height 2.4. `game/scripts/sliding_door.gd:1` |
| H04 Locked closet door | (3.25, 0, 0.9) | Locked prop door on east wall; no documented playable room beyond it. `game/scripts/locked_room_door.gd:1` |
| H05 Kitchen entrance | (-3.3, 0, 1.95) | West-side opening; kitchen bounds X=-5.65..-3.3, Z=-2.7..2.7. `game/scripts/room_surroundings.gd:20` |
| H10 Fabric sofa | (-2.08, 0, 0.45) | Physical furniture assembly. `game/scripts/physics_object.gd:1` |
| H11 Leather sofa | (0.2, 0, 2.21) | Physical furniture along north/rear wall. `game/scripts/physics_object.gd:1` |
| H12 Marble table | (-0.65, 0, 0.15) | Physical table; tray, plant and tissue box rest above it. `game/scripts/physics_object.gd:1` |
| H13 Television | (-0.55, 1.77, -2.6) | TV-wall anchor; power, channels, inspect interaction and mystery lock. `game/scripts/physics_object.gd:1` |
| H14 TV console | (-0.55, 0.095, -2.42) | Console below television. `game/scripts/physics_object.gd:1` |
| H15 Digital clock | (-0.55, 0.67, -2.34) | One of the note-bearing props; clock has abnormal time display. `game/scripts/physics_object.gd:1` |
| H16 Table plant | (-0.53, 0.891, 0.14) | One of the note-bearing props. `game/scripts/physics_object.gd:1` |
| H17 Cabinet photo | (-1.13, 0.845, -2.289) | One of the note-bearing props. `game/scripts/physics_object.gd:1` |
| H18 Hamster enclosure stand | (-2.598, 0.003, -1.103) | Three-level habitat; movable assembly with attached animal systems. `game/scripts/physics_object.gd:1` |
| H19 Small aquarium | (-2.36, 0.139, -1.11) | Lower shelf aquarium. `game/scripts/physics_object.gd:1` |
| H20 Computer desk | (2.17, -0.025, -2.15) | Desk in the southeast/TV-wall corner. `game/scripts/physics_object.gd:1` |
| H21 Baby crib | (2.05, -0.006, -0.99) | Physical crib assembly. `game/scripts/physics_object.gd:1` |
| H22 Standing fan | (1.03, 0, -1.35) | Physical standing fan. `game/scripts/physics_object.gd:1` |
| H23 White display rack | (1.161, 0.005, -2.37) | Named furniture, beside the TV area. `game/scripts/physics_object.gd:1` |
| H24 Black storage rack | (3.048, 0.027, -2.457) | Named furniture, at east end of TV wall. `game/scripts/physics_object.gd:1` |
| H30 Studio interior centre | (-3.45, 0, 5.1) | 4.4 by 4.4 m; X=-5.65..-1.25, Z=2.9..7.3; ceiling Y=2.9. `game/scripts/studio_builder.gd:14` |
| H31 Studio production desk | (-2.6, 0, 6.745) | Desk base reference; desk top Y=.692. `game/scripts/studio_builder.gd:23` |
| H40 Balcony centre | (3.275, 0, 3.725) | Floor bounds X=.95..5.6, Z=2.9..4.55; outer parapet Z=4.75. `game/scripts/balcony_builder.gd:19` |
| H41 Stair upper end | (5.6, 0, 3.38) | 16 risers, rise .18125 m each; treads .27 m. Descends east to Y=-2.9. `game/scripts/balcony_builder.gd:26` |
| H42 Courtyard | (11.1, -2.9, 4.1) | Courtyard reference; X=9.65..12.6, Z=2.9..5.3. `game/scripts/balcony_builder.gd:30` |

- **H01** → `Player` — `N-64aee8c6cbd0`
- **H02** → `LivingRoom/ReferenceRoomSurroundings/EntryDoor` — `N-f9c52706b3be`
- **H03** → `Studio/StudioDoor` — `N-2977ce2c29d7`
- **H04** → `LivingRoom/LockedClosetDoor` — `N-9691d997a52a`
- **H10** → `LivingRoom/fabric_sofa_0` — `N-6410e49d7988`
- **H11** → `LivingRoom/leather_sofa_1` — `N-89150fd94736`
- **H12** → `LivingRoom/marble_table_2` — `N-506b0123be4a`
- **H13** → `LivingRoom/television_4` — `N-551641f53bbd`
- **H14** → `LivingRoom/tv_console_3` — `N-763cdb46b37e`
- **H15** → `LivingRoom/digital_clock_17` — `N-e15aa5c4d120`
- **H16** → `LivingRoom/potted_plant_15` — `N-1ee87a65b507`
- **H17** → `LivingRoom/photo_frame_19` — `N-25f7979b30e4`
- **H18** → `LivingRoom/pet_enclosure_11` — `N-04781ecd8878`
- **H19** → `LivingRoom/SmallAquarium` — `N-8373b594a964`
- **H20** → `LivingRoom/computer_desk_6` — `N-da2ed1c48832`
- **H21** → `LivingRoom/baby_crib_9` — `N-89bd879358e5`
- **H22** → `LivingRoom/standing_fan_5` — `N-58cb842ff7f7`
- **H23** → `LivingRoom/White display rack` — `N-822c7fb9f4ff`
- **H24** → `LivingRoom/Black storage rack` — `N-36cfdba6b322`

## Studio

| ID / name | World position | Meaning / source |
| --- | --- | --- |
| H32 Studio couch | (-4.62, 0, 3.37) | Runtime model origin. See parent collision body and siblings for the complete assembly.  |
| H33 Drum kit | (-4.73, 0, 6.4) | Runtime model origin. See parent collision body and siblings for the complete assembly.  |
| H34 Two-tier synthesizers | (-1.68, 0.815, 4.55) | Runtime model origin. See parent collision body and siblings for the complete assembly.  |
| H35 Acoustic guitar A | (-5.585, 1.42, 3.78) | Runtime model origin. See parent collision body and siblings for the complete assembly.  |
| H36 Bass on stand | (-3.95, 0, 5.35) | Runtime model origin. See parent collision body and siblings for the complete assembly.  |
| H37 Gaming chair | (-2.65, 0, 5.795) | Runtime model origin. See parent collision body and siblings for the complete assembly.  |
| H38 Microphone stand | (-2.5, 0, 4.3) | Runtime model origin. See parent collision body and siblings for the complete assembly.  |

- **H32** → `Studio/Couch/sofa_02` — `N-561db5597cc2`
- **H33** → `Studio/Drum kit/drum_kit` — `N-f434d1417a4f`
- **H34** → `Studio/Synth 61-key/synth_b` — `N-86b19f571c97`
- **H35** → `Studio/Guitar acoustic_a/guitar_acoustic_a` — `N-86d92b9f4cc9`
- **H36** → `Studio/Bass on stand/bass_precision` — `N-bca5bb34f84b`
- **H37** → `Studio/Gaming chair/gaming_chair` — `N-4411e4648883`
- **H38** → `Studio/Mic boom stand/mic_boom_stand` — `N-f8f10015843c`

## Town

| ID / name | World position | Meaning / source |
| --- | --- | --- |
| T01 Courtyard gate opening | (12.6, -2.9, 4.12) | Opening midpoint derived from leaf hinges. CourtyardGate root itself is at (0,0,0). Tap E unlatches; push or hold E and move to swing leaves.  |
| T02 Lane outside courtyard gate | (14, -2.9, 4.6) | Reachability audit origin; head east through lane to street B, then north to street A. `game/tests/world_audit.gd:18` |
| T03 Courtyard lane / street B | (21.4, -2.9, 6) | Actual player-route test point at the lane mouth on Malasugue Street. Head north to A/B corner T04. `game/tests/street_integration.gd:99` |
| T13 Bent Malasugue Street sign base | (18.5, -2.78, 7.35) | Source base of snapped street-sign pole beside the lane mouth. `game/scripts/street_dressing.gd:127` |
| T14 Whisper source behind east gate | (23.4, -1.45, 10.5) | Positional psst sound; approach trigger X=18..24, Z=5.5..16.5. `game/scripts/neighborhood_encounters.gd:9` |
| T04 Street A / B corner | (21, -2.9, 18) | Intersection centre; street corridor width 6 m, including 1 m sidewalks each side. `game/scripts/neighborhood_builder.gd:17` |
| T05 Street A / D corner | (-19, -2.9, 18) | Intersection centre; street corridor width 6 m, including 1 m sidewalks each side. `game/scripts/neighborhood_builder.gd:17` |
| T06 Street B / C corner | (21, -2.9, 49) | Intersection centre; street corridor width 6 m, including 1 m sidewalks each side. `game/scripts/neighborhood_builder.gd:17` |
| T07 Street C / D corner | (-19, -2.9, 49) | Intersection centre; street corridor width 6 m, including 1 m sidewalks each side. `game/scripts/neighborhood_builder.gd:17` |
| T08 Open west passage | (-23.85, -2.9, 18) | West wall opening Z=15.15..20.85; leads to canal settlement. `game/scripts/town_siege.gd:38` |
| T09 North wall crouch hole | (21.32, -2.9, 54.8) | Width .95 m; height 1.3 m. Standing player cannot pass; hold C. Leads to field road. `game/scripts/town_siege.gd:28` |
| T10 Hidden south crawl | (19.35, -2.9, -18.55) | Width .9 m. Enter from east end behind leaned sheets, crouch along wall, crawl south to Nichols path. `game/scripts/town_siege.gd:40` |
| T11 Hooded man waiting point | (21.32, -2.9, 53.35) | Scripted actor waits here after courtyard gate opens. `game/scripts/town_siege.gd:32` |
| T12 Hooded man beyond hole | (21.32, -2.9, 56.6) | Actor can stand again here before fleeing along field road. `game/scripts/town_siege.gd:33` |

- **T01** → `Balcony/CourtyardGate` — `N-7b231b8eadf8`

## Canal

| ID / name | World position | Meaning / source |
| --- | --- | --- |
| C01 Settlement approach | (-30, -2.9, 18.4) | Approach from west end of street A. Ramp joins settlement bank at Y=-2.1. `game/tests/world_audit.gd:21` |
| C02 Upper east-bank lane | (-49.553, -2.1, 22.2) | Lane between house rows; river coordinates approximately U=12.9..16.9. `game/scripts/canal_settlement.gd:26` |
| C03 Trench stair top | (-53.753, -2.1, 22.2) | 1.4 m wide walking ramp with 15 visible steps, down 2.3 m to catwalk. `game/scripts/canal_settlement.gd:596` |
| C04 Trench stair foot | (-59.153, -4.4, 22.2) | East retaining-wall catwalk at Y=-4.4. `game/scripts/canal_settlement.gd:597` |
| C05 Plank footbridge east end | (-63.782, -4.4, -9) | Footbridge width 1.15 m; spans to far bank U=-6.7 at Y=-5.45. `game/scripts/canal_settlement.gd:637` |
| C06 Plank footbridge west end | (-74.202, -5.45, -9) | From here head north on far-bank path to the warren approach. `game/scripts/canal_settlement.gd:637` |
| C07 Warren approach stair bottom | (-72.804, -5.45, 8) | Bank steps climb west over U=-7.3..-13.6; then continue to fence opening. `game/scripts/canal_settlement.gd:83` |
| C08 Concrete road bridge | (-68.978, -2.1, 60.2) | Deck spans U=-15..8, Z=58..62.4 (23 by 4.4 m). `game/scripts/canal_settlement.gd:663` |
| C09 Catwalk north stair start | (-59.715, -4.4, 50) | Climbs to Y=-2.1 at Z=55.4; landing connects to road bridge. `game/scripts/canal_settlement.gd:617` |
| C10 Far-bank path north climb | (-70.904, -5.45, 44) | Path height smoothly rises from -5.45 at Z=44 to -2.1 at Z=57. `game/scripts/canal_settlement.gd:67` |


## Warren

| ID / name | World position | Meaning / source |
| --- | --- | --- |
| W01 Warren fence entrance | (-94.004, -2.1, 8) | Pried tin sheet near actual door W10; continue west through access alley to east boardwalk. `game/scripts/canal_warren.gd:32` |
| W02 Collapsed roof | (-105.218, -2.05, -1.25) | Crouch section Z=-2.2..-.3 on east boardwalk. Roof low point Y=-.83; deck Y=-2.05. `game/scripts/canal_warren.gd:44` |
| W03 South plank crossing | (-108.787, -2.05, -11) | Cross east to west boardwalk here; bridge 4.9 by 1 m nominal. `game/scripts/canal_warren.gd:34` |
| W04 Family room | (-109.731, -2.05, 3.5) | Through-room on west side, Z=1..6; radio, light switch, sleeping area and old TV. `game/scripts/canal_warren.gd:41` |
| W05 Altar room | (-108.459, -2.05, 20.5) | Through-room on west side, Z=18..23; one votive candle. `game/scripts/canal_warren.gd:41` |
| W06 Moonlit courtyard | (-109.407, -2.05, 31) | Open courtyard Z=28..34; pump, cages, clotheslines and gutted tricycle. `game/scripts/canal_warren.gd:43` |
| W07 Store rear room | (-109.62, -2.05, 42.5) | Through-room Z=40..45 behind padlocked sari-sari store; kerosene lamp. `game/scripts/canal_warren.gd:41` |
| W08 North plank crossing | (-106.281, -2.05, 52.6) | Cross west to short north segment of east boardwalk. `game/scripts/canal_warren.gd:35` |
| W09 Warren fence exit | (-93.338, -2.1, 54.7) | Second pried sheet near road bridge. Actual gate origin is W11. `game/scripts/canal_warren.gd:33` |
| W10 Entrance tin door | (-93.946, -2.08, 8.48) | Door hinge origin, beside W01. `game/scripts/warren_door.gd:1` |
| W11 Exit tin door | (-93.391, -2.08, 55.18) | Door hinge origin, beside W09. `game/scripts/warren_door.gd:1` |
| W12 Radio | (-109.246, -1.67, 4.7) | Usable radio in family room. `game/scripts/warren_usable.gd:1` |
| W13 Family-room light switch | (-108.791, -0.75, 1.07) | Usable tube-light switch. `game/scripts/warren_usable.gd:1` |
| W14 Courtyard hand pump | (-109.407, -2.02, 31) | Usable pump in courtyard. `game/scripts/warren_usable.gd:1` |

- **W10** → `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren door 06` — `N-b720d5194ecc`
- **W11** → `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren door 07` — `N-bbc8240b2b32`
- **W12** → `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren radio` — `N-2f4bf0d35c9a`
- **W13** → `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren switch` — `N-ddb6fdc56c03`
- **W14** → `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren pump` — `N-27cb53f6c916`

## Nichols

| ID / name | World position | Meaning / source |
| --- | --- | --- |
| N01 Nichols outer gate | (-12, -2.9, -60) | Open wrought-iron gate; estate X=-40..14, Z=-124..-60. `game/scripts/nichols_property.gd:14` |
| N02 Nichols facade origin | (-12, -1.7, -82) | Origin of house-local Godot coordinates. Ground floor Y=-1.7; upstairs Y=2.7. `game/scripts/nichols_property.gd:13` |
| N03 Porch Steps | (-12, -2.9, -75.62) | Translated from house layout.json spots. `game/assets/models/nichols/house/layout.json:13070` |
| N04 Front Door | (-12, -1.7, -80.2) | Translated from house layout.json spots. `game/assets/models/nichols/house/layout.json:13075` |
| N05 Stair Foot | (-12, -1.7, -85.3) | Translated from house layout.json spots. `game/assets/models/nichols/house/layout.json:13040` |
| N06 Landing | (-12, 0.5, -90.4) | Translated from house layout.json spots. `game/assets/models/nichols/house/layout.json:13045` |
| N07 Bridge | (-12, 2.7, -83.2) | Translated from house layout.json spots. `game/assets/models/nichols/house/layout.json:11538` |
| N08 Mantel Parlour | (-24.05, -0.36, -87.5) | Translated from house layout.json spots. `game/assets/models/nichols/house/layout.json:13055` |
| N09 Tower Top | (-12, 17.65, -84.4) | Translated from house layout.json spots. `game/assets/models/nichols/house/layout.json:13065` |


## Nichols rooms

| ID / name | World position | Meaning / source |
| --- | --- | --- |
| NR01 Foyer | (-12, -1.7, -86.85) | Room volume; see room-register.json for all rectangles, world bounds, floor and ceiling. `game/assets/models/nichols/house/layout.json:12662` |
| NR02 Parlour | (-20.35, -1.7, -87.65) | Room volume; see room-register.json for all rectangles, world bounds, floor and ceiling. `game/assets/models/nichols/house/layout.json:12694` |
| NR03 Dining | (-3.65, -1.7, -87.65) | Room volume; see room-register.json for all rectangles, world bounds, floor and ceiling. `game/assets/models/nichols/house/layout.json:12714` |
| NR04 Closet | (-12, -1.7, -92.2) | Room volume; see room-register.json for all rectangles, world bounds, floor and ceiling. `game/assets/models/nichols/house/layout.json:12734` |
| NR05 Hall | (-12, -1.7, -94.2) | Room volume; see room-register.json for all rectangles, world bounds, floor and ceiling. `game/assets/models/nichols/house/layout.json:12754` |
| NR06 Library | (-20.35, -1.7, -98.55) | Room volume; see room-register.json for all rectangles, world bounds, floor and ceiling. `game/assets/models/nichols/house/layout.json:12774` |
| NR07 Pantry | (-12, -1.7, -98.55) | Room volume; see room-register.json for all rectangles, world bounds, floor and ceiling. `game/assets/models/nichols/house/layout.json:12794` |
| NR08 Kitchen | (-3.65, -1.7, -98.55) | Room volume; see room-register.json for all rectangles, world bounds, floor and ceiling. `game/assets/models/nichols/house/layout.json:12814` |
| NR09 Corridor W | (-20.35, 2.7, -83.35) | Room volume; see room-register.json for all rectangles, world bounds, floor and ceiling. `game/assets/models/nichols/house/layout.json:12834` |
| NR10 Corridor E | (-3.65, 2.7, -83.35) | Room volume; see room-register.json for all rectangles, world bounds, floor and ceiling. `game/assets/models/nichols/house/layout.json:12854` |
| NR11 Bridge | (-12, 2.7, -83.35) | Room volume; see room-register.json for all rectangles, world bounds, floor and ceiling. `game/assets/models/nichols/house/layout.json:12874` |
| NR12 Gallery W | (-15.3, 2.7, -85.05) | Room volume; see room-register.json for all rectangles, world bounds, floor and ceiling. `game/assets/models/nichols/house/layout.json:12906` |
| NR13 Gallery E | (-8.7, 2.7, -85.05) | Room volume; see room-register.json for all rectangles, world bounds, floor and ceiling. `game/assets/models/nichols/house/layout.json:12926` |
| NR14 Master | (-20.35, 2.7, -88.7) | Room volume; see room-register.json for all rectangles, world bounds, floor and ceiling. `game/assets/models/nichols/house/layout.json:12946` |
| NR15 Nursery | (-3.65, 2.7, -88.7) | Room volume; see room-register.json for all rectangles, world bounds, floor and ceiling. `game/assets/models/nichols/house/layout.json:12966` |
| NR16 Sealed | (-12, 2.7, -97.35) | Room volume; see room-register.json for all rectangles, world bounds, floor and ceiling. `game/assets/models/nichols/house/layout.json:12986` |


## Basement

| ID / name | World position | Meaning / source |
| --- | --- | --- |
| B01 Nook | (-10.05, -1.7, -89.6) | House-local vector translated by (-12,-1.7,-82). `game/assets/models/nichols/house/layout.json:13488` |
| B02 Landing | (-9.8, -1.7, -92.2) | House-local vector translated by (-12,-1.7,-82). `game/assets/models/nichols/house/layout.json:13045` |
| B03 Shaft Foot | (-15.35, -4.4, -92.2) | House-local vector translated by (-12,-1.7,-82). `game/assets/models/nichols/house/layout.json:13498` |
| B04 Cellar | (-18, -4.4, -96) | House-local vector translated by (-12,-1.7,-82). `game/assets/models/nichols/house/layout.json:13229` |
| B05 Hole | (-12.9, -4.4, -98.85) | House-local vector translated by (-12,-1.7,-82). `game/assets/models/nichols/house/layout.json:13513` |
| B06 Corridor | (-9.7, -5.3, -98.8) | House-local vector translated by (-12,-1.7,-82). `game/assets/models/nichols/house/layout.json:13280` |
| B07 Steel Door | (-0.7, -5.3, -98.8) | House-local vector translated by (-12,-1.7,-82). `game/assets/models/nichols/house/layout.json:13523` |
| B08 Cages | (-2.1, -5.3, -98.3) | House-local vector translated by (-12,-1.7,-82). `game/assets/models/nichols/house/layout.json:13528` |
| B09 Tarp | (-20.4, -4.4, -99.3) | House-local vector translated by (-12,-1.7,-82). `game/assets/models/nichols/house/layout.json:13533` |
| B10 Workbench | (-15.3, -3.52, -100.82) | House-local vector translated by (-12,-1.7,-82). `game/assets/models/nichols/house/layout.json:13538` |
| B11 Hooks | (-18.9, -2.1, -100.4) | House-local vector translated by (-12,-1.7,-82). `game/assets/models/nichols/house/layout.json:13543` |
| B12 Drain | (-18.2, -4.4, -99.6) | House-local vector translated by (-12,-1.7,-82). `game/assets/models/nichols/house/layout.json:13508` |
| B13 Cellar door hinge | (-9.65, -1.7, -91.4) | Under grand-stair landing; .78 m wide, 1.77 m high, initially 48 degrees ajar. `game/assets/models/nichols/house/layout.json:13165` |
| B14 Cellar light switch | (-9.412, -0.38, -91.12) | Turns on basement bulbs. Starts off. `game/scripts/nichols_basement.gd:140` |
| B15 Chained iron door | (0.24, -5.3, -98.8) | Terminal locked barrier; new padlock, no traversable continuation documented. `game/scripts/nichols_basement.gd:590` |


## Fields

| ID / name | World position | Meaning / source |
| --- | --- | --- |
| F01 Field-road start | (21, -2.9, 54.5) | First stored road sample; begins under the north-wall exit. `game/scripts/fields_builder.gd:29` |
| F02 Hut yard reference | (32.956, -2.9, 148.633) | Metadata yard reference. Hut model origin is .15 m lower; finished hut floor is Y=-2.63.  |
| F03 Bahay kubo model | (32.956, -3.05, 148.633) | Runtime orientation faces the road; hut dimensions use local frame in hut_house.gd.  |
| F04 Scarecrow | (28.946, -3.06, 178.733) | Scarecrow islet reached from road by a dike; actor points toward viewer while unseen.  |
| F05 Buried ammunition box | (29.442, -3.054, 178.497) | Initially hidden near scarecrow; scripted dig and handover sequence.  |
| F06 Pond centre | (28.01, -3.32, 225.552) | Ellipse radii 15 m by 12.5 m. Water Y=-3.32.  |
| F07 Jetty collider centre | (39.503, -3.06, 218.414) | Deck walking top near Y=-2.96; node origin is collider centre at Y=-3.06.  |
| F08 Road dead end | (40, -2.9, 530) | Road ends at fallen tree and SIRADO barrier; no road beyond this point.  |
| F09 Giant tree | (25.09, -2.9, 551.3) | Scenery knoll beyond the road barrier; do not infer a connected playable route.  |

- **F03** → `Fields/Models/BahayKubo` — `N-af30559ac88f`
- **F04** → `Fields/Models/Scarecrow` — `N-b6e8f5f61fce`
- **F05** → `Fields/AmmoBox` — `N-fe33791e5e09`
- **F07** → `Fields/FieldsColliders/Jetty` — `N-73cdd77bdf9a`

## Hut

| ID / name | World position | Meaning / source |
| --- | --- | --- |
| K01 Hut root | (32.956, -3.05, 148.633) | Local origin at model base, Y=-3.05; local floor .42 -> world Y=-2.63. `game/scripts/hut_house.gd:1` |
| K02 Brass key | (34.399, -1.786, 149.04) | Take key before opening top dresser drawer. `game/scripts/hut_usable.gd:1` |
| K03 Dresser drawer | (34.226, -2.048, 148.851) | Drawer node; travel .3 m in hut local frame.  |
| K04 Glock | (34.355, -2.001, 148.823) | Inside dresser drawer; scripted pickup.  |
| K05 Flashlight | (34.418, -2.002, 149.174) | Inside dresser drawer; scripted pickup.  |

- **K01** → `Fields/HutHouse` — `N-0d6f3af61be0`
- **K02** → `Fields/HutHouse/Key` — `N-bd9f3aa639f3`
- **K03** → `Fields/HutHouse/Dresser/TopDrawer` — `N-b5250787bd65`
- **K04** → `Fields/HutHouse/Dresser/TopDrawer/Glock` — `N-bf885f13fec1`
- **K05** → `Fields/HutHouse/Dresser/TopDrawer/Flashlight` — `N-d087d3512159`

