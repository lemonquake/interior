# Canal warren and physical chairs — Windows 0.18.0

Updated 2026-10-08. The owner asked for three things:

- proper collision on the monobloc chair in their canal-lane screenshot, and on every other chair in the neighbourhood;
- finer detail in the squatter area;
- a significant expansion: a much more hidden part of the settlement, where interconnected wooden houses form a long tunnel along a canal. It should have very few light sources, interactive locked doors and objects, and be as dirty and chaotic as a real Philippine squatter area.

## Physical chairs

- Every monobloc chair is now an `InteriorObject` (Jolt rigid body): the front-yard chairs, the food-stall chairs, the canal lane and the warren. That is 22 chairs in the packed build.
  - Each has a compound collider fitted to the model: the seat, a tilted back, two arm rests and four legs.
  - You can't walk through a chair any more. Walking into one shoves it or tips it over. Hold E to grab and carry it. Impacts make sounds.
  - `scripts/loose_props.gd` (`InteriorLooseProps.convert_chairs`) converts the placed chairs at runtime, from `neighborhood._install_interactions`, so the bakes don't change.
- **Engine fix in `physics_object.gd`.** `InteriorObject` treated any body more than 40 m from the room, or below y −4, as lost and snapped it home every frame. Outdoor props would have been pinned in place. Bodies with the new `outdoor = true` flag only recover after a fall out of the world (y < −14).
- The tipped chair by the corner food cart used to lie across street A's clear walking line (z 18.4). Now that it is solid, it rests by the far kerb instead.

## Finer detail in the canal lane

Washing hangs on lines between the house rows. Pails, basins, crates and bottles are loose rigid bodies along the lane edges. All of this comes from a separate random stream (`_lane_details`), so the 0.17 layout did not move.

## The warren (`scripts/canal_warren.gd`)

**How to get in.** It is hidden behind the far bank's fence.
- Cross the plank footbridge and walk north along the far-bank path.
- At z ≈ 8, steps of boards and tyres are trodden into the bank, and a trail of litter leads between the far-bank houses.
- A pried-open corrugated sheet in the fence swings in. A second sheet near the road bridge (z 54.7) lets you out.

**Layout.**
- **The estero.** A black drainage canal about 3 m wide, with bottles, foam, rubbish rafts and old stilts in the water. Its banks are shored with block, cement, planks and sandbags, and it runs into grated culverts at both ends.
- **The shanties.** Two rows of the 0.17 Blender kit houses (31 houses) face each other across the estero. Their upper storeys lean out over it.
- **The tunnel roof.** Patched tin, plywood and tarp sheets on joists, weighed down with tyres, close the gap above the boardwalks. Cables, bags and rags hang from it.
- **The route.**
  - An alley from the fence leads to the east boardwalk, heading south.
  - A caved-in stretch has a waist-high collider, so you must crouch. The first time you reach it, a line says so.
  - A plank bridge crosses to the west boardwalk, heading north.
  - The west boardwalk passes through three rooms, each entered and left through a hinged plank door:
    - **Family room:** a dying fluorescent tube with a wall switch, a battery radio that plays AM static with a far-off voice, a banig under a mosquito net, a TV, a cabinet, washing and a calendar.
    - **Altar room:** a red-draped shelf with a Santo Niño picture and figure, plastic flowers, rosaries and one votive candle. It also holds a locked door to the back room and a rotten mattress.
    - **Sari-sari store:** a counter and wire grille with a padlocked buying window. Knocking gets "Pabili po! ...No one." Behind the grille are shelves, strips of sachets, an ice cooler and a gasera (kerosene lamp).
  - Between the rooms is an open, moonlit courtyard (looban). It has a hand pump you can work, washing lines, sabong rooster cages, a gutted tricycle, drums, a basketball ring and heaps of rubbish.
  - A second bridge, an alley and the exit sheet take you out.
- **Locked doors.** 14 doors are padlocked and chained: 12 on house fronts along the walks, plus the altar room's back door and the store window. They use the town's knock gesture, with warren lines ("Tao po? ...Nobody.", "It smells like something died behind this door."…).
- **Light.** There are only four lamps: the tube, the candle, the gasera and one failing bulb in the south tunnel.
  - Without help the tunnels rendered pure black.
  - Holes in the roofs now let faint blue moonlight pools through. These are 13 dim, shadowless omni lights with no visible emitter.
  - A thin haze (FogVolume, desktop volumetric tiers) makes them read.
  - The WorldEnvironment is unchanged.
- **Sound.** Generated hinge creaks, a tube hum, radio static, drips into the estero, and the pump using the existing water impact sound.
- **Filth.** About 85 rubbish pieces, 72+ graffiti and census decals, 39 loose physical props (pails, basins, bottles, pots, crates, chairs), litter on every board, and barricades of junk at every boardwalk end.

## Engine and settlement changes

- `canal_settlement.gd`:
  - `ground()` defers west of u −28.4 to the warren (`canal_warren.ground`), and cuts the step notch into the far bank.
  - The terrain grid now starts at u −55.
  - HOLE starts at x −123.5, so the town slab no longer fills the estero.
  - Two fence panels are skipped for the sheets, and plants keep off the gate paths.
- `neighborhood.gd`: chair conversion, impact sounds for loose props, the warren door controller and the tipped-chair move.
- `neighborhood_encounters.gd`: knocks also work in the canal and warren area, and doors can carry their own `lines` meta.
- New scripts: `canal_warren.gd`, `loose_props.gd`, `warren_door.gd` (hinged; joins "usables" and not "interior_doors", so it never reveals the balcony), `warren_usable.gd`.
- `interior.gd`: `-- --capture-review --capture-views=warren`.

## Verification

- **New: `tests/warren_integration.gd` 87/87.** A real player walks the whole route: path → bank steps → fence sheet → alley → east tunnel → crouch under the cave-in (standing is blocked) → bridge → all six room doors → courtyard → store → second bridge → exit sheet → far bank. It also checks:
  - house, door, prop and lamp counts, and 22 chairs, all with the fitted 8-shape collider;
  - deck heights, the estero bed, that the rail holds, and wood footsteps;
  - that walking into a chair shoves it and never passes through;
  - a knock with its remark, the radio on/off, the switch killing the tube, and the pump stroke.
- **Regressions, all passing:**
  - canal 57/57
  - street 27/27
  - neighbourhood interactions 29/29
  - knock retry 37/37
  - neighbourhood decay 32/32
  - balcony 62/62
  - stranger 26/26
  - hut story (pass)
  - gun (pass)
  - fields 25/25
  - room 142/142
  - physics 25/25
  - night revision (pass)
- **Rendered review:** `tests/warren_review.gd` (add `--work-light` for geometry checks), Forward+ High at 1600×900. Every view held 60 FPS. Draw calls were 300–1,850 and primitives 1.7–14 M; the canal-lane view is the heaviest.
- **Exported EXE:** `builds/windows/Interior.exe` 0.18.0, 669,869,648 bytes, SHA-256 `069CCA44C1E5BFF15546B4B771180BF2AE2505E183D5E0D340EF5AEA84F83316`. Its own capture (`warren-*.png` here) reports 31 houses, 14 locked doors, 8 hinged doors, 4 lamps and 22 chairs, with no script errors.

## Screenshots sent

| File | View |
| --- | --- |
| `work/warren18/progress-1-warren.jpg` | Mid-run sheet: alley, west tunnel, family room, altar, courtyard, store (editor render, brightened 2×) |
| `work/warren18/exe-warren-sheet.jpg` | The EXE's own capture: `warren-1-gate` … `warren-7-west-tunnel` (brightened 2×) |

## Known gaps

- The Android APK was not rebuilt. Compatibility has no volumetric haze.
- A stray `A:\3rd\` folder holds a duplicate copy of the 7 EXE captures. The space in the project path split the capture argument, and the session's tooling blocks deleting it. It is safe to delete.
- Hanging quads (paper, scum) are single-sided, so some show only from one side.
- The kit's house doors are visual only. The locked doors are new slabs set into their frames.
