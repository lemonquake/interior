# Post-Heavy-Arm Map System Design (`0.63+`)

> Architectural, spatial, traversal, aesthetic, and automated verification standard for every level built after **Heavy-arm** (`PILCST Rear Gate` at street-local `z = 600.0`).
>
> **Masterplan & Section Blueprints (District 01 — Outer Street: Buhangin Crossing):**
> - [Masterplan Top-Down Blueprint (`outer_street_masterplan.png`)](file:///a:/3rd%20Harmonik/interior/docs/map-system/outer_street_masterplan.png)
> - [Vertical Cross-Section & Tier Elevation (`outer_street_elevation_section.png`)](file:///a:/3rd%20Harmonik/interior/docs/map-system/outer_street_elevation_section.png)

---

## 1. Purpose, Scope, and Post-Heavy-Arm Trigger

Before Heavy-arm falls at **PILCST Rear Gate** (`z = 600.0`), *Sleep* takes place inside bounded interiors and enclosed alleys with relatively linear staging. From Heavy-arm onward, players step out through the unchained school gate into semi-open urban Davao night districts (`Outer Street` and subsequent chapters). Without strict structural contracts, open multi-level environments break down in four predictable ways:

1. **Floating seams, leaky geometry, and trapped landings** — mismatched slab thicknesses, missing stair cutouts, or barriers lower than player air-mantle height (`~1.87 m`) allowing soft-locks or out-of-bounds falls.
2. **Linear corridor boredom** — wide streets walled off into a single forced tube with ornamental side scenery players cannot enter.
3. **Visual emptiness and flat "box world" monotony** — bare asphalt planes between setpieces, inconsistent lighting layers (moonlight leaking underground), and dead corners lacking story props.
4. **Silent AI/Co-op breakage** — stairs too steep for `InteriorZombieNav`, narrow catwalks where survivor bots wedge players, or abrupt unbuffered transitions between loaded chapter geometry.

This specification establishes a **mandatory engine & design system** enforced in runtime code via [`SleepMapBuilder`](file:///a:/3rd%20Harmonik/interior/game/scripts/map_system/map_builder.gd) and verified automatically by [`SleepMapValidator`](file:///a:/3rd%20Harmonik/interior/game/scripts/map_system/map_validator.gd) across **7 automated audit gates**.

---

## 2. Coordinate, Rendering, and Physics Contracts

### 2.1 Origin & Macro Axes
All outdoor chapter geometry builds in **Street-local coordinates** parented relative to `Street.ORIGIN` (`Vector3(-86.0, 1.05, 71.5)`):
- **`+Z` (North):** Forward campaign progression from PILCST Front (`z = 500`) -> Rear Field (`z = 534..600`) -> **Outer Street (`z = 600..772`)**.
- **`+X` (East):** Transverse district span (`X = 0..108 m` for Outer Street), running from the West Hillside Shophouses (`X = 0`) across Buhangin Crossing (`X = 24..64`), under the Highway Viaduct (`X = 68..88`), down to the Curving Davao River Embankment (`X = 92..108`).
- **`Y` (Elevation):** Relative to `y = 0.0` Street Datum (`PILCST` ground floor / crosswalk asphalt).

### 2.2 Render Layers (Lighting Segregation)
Because the night sky directional moonlight illuminates outdoor spaces across large draw distances, every generated mesh and light MUST obey strict layer isolation:

| Context | `GeometryInstance3D.layers` | Effect |
| :--- | :--- | :--- |
| **Outdoor / Open-Air** | `1 \| 2 \| 8` (`11`) | Layer `1`: primary camera/flashlights, Layer `2`: moonlight & sky fill, Layer `8`: `Decal.cull_mask` blood/oil/tire traces. |
| **Subterranean / Indoor** (`indoor = true`) | `1 \| 8` (`9`) | Excludes Layer `2` so moonlight **never** bleeds through concrete roofs into underground underpasses or submerged storm culverts. |
| **Transparent / Glazing** (`glass*`) | `1 \| 2 \| 8`, `cast_shadow = OFF` | Preserves interior moonlight visibility through broken overpass glazing without shadow acne. |

### 2.3 Physics Layers & Player/AI Envelope (`player.gd`, `body.gd`, `zombie_nav.gd`)
All level dimensions are derived directly from measured actor physics constants in `game/scripts/`:
- **Physics Layers:** `1` = Players/Actors, `2` = Static Level Colliders (`BoxShape3D` / `StaticBody3D`), `4` = Dynamic Objects/Vehicles/Doors, `64` = Shot Proxy (`InteriorModelKit.SHOT_LAYER`).
- **Movement (`player.gd`):** `WALK_SPEED = 2.45 m/s`, `RUN_SPEED = 4.70 m/s`, `CROUCH_SPEED = 1.20 m/s`, `STANDING_HEIGHT = 1.70 m`, `CROUCH_HEIGHT = 1.00 m`, `LIP_HEIGHT = 0.16 m`.
- **Jump & Mantle Envelope:** `GRAVITY = 14.0 m/s^2`, `JUMP_SPEED = 4.80 m/s` (`~0.82 m` apex), `MANTLE_LOW = 0.42 m`, `MANTLE_HIGH = 1.30 m`, `MANTLE_AIR = 1.05 m` -> **Maximum upward climb reach = ~1.87 m**.
- **Fall Envelope (`body.gd`):** Impact stagger at `speed > 6.0 m/s` (`drop > ~1.3 m`); story fall damage at `speed > 8.4 m/s` (`drop > ~2.52 m`).
- **Infected & Bot Navigation (`zombie_nav.gd`):** `CELL = 0.6 m`, `STEP = 0.32 m`, walkable surface `normal.y > 0.64` (`<= ~50 deg`), `MASK = 2`.

**Non-negotiable design consequences:**
1. Every walkable curb or ramp join step MUST be `<= 0.16 m` (`LIP_HEIGHT`).
2. Standard **LINK** stairs/ramps MUST have slope **`<= 28 deg`** (`rise/run <= 0.53`), width **`>= 2.4 m`** (or `>= 2.2 m` inside utility culverts with passing pockets), and minimum vertical clearance **`>= 2.6 m`**.
3. Any barrier, retaining wall, overpass parapet, or boundary ledge protecting a drop `>= 1.8 m` MUST carry a solid collider rising **`>= 2.2 m`** (`2.4 m` standard) above the walkable deck so players cannot air-mantle out of bounds.
4. Any intentional drop-down (`one_way_drop`, e.g., PILCST Room 208 lean-to chute or `SC_COURTYARD` timber ramp) MUST drop `<= 2.3 m` onto an unobstructed landing pad free of overhead snags or side traps.

---

## 3. Zero-Gap Spatial Manifold Grammar (`DECK / LINK / SHELL / PROP`)

Every district is composed from four deterministic architectural primitives registered in `SleepMapBuilder`:

1. **DECK (`add_deck`):**
   - Structural walkable plateau defined by axis-aligned footprint `[x0, x1, z0, z1]`, top `top_y`, slab thickness `>= 0.40 m`, PBR material ID, `indoor` flag, and optional rectangular cutouts (`holes = [[hx0, hx1, hz0, hz1], ...]`) for descending stairs and storm sumps.
   - **Auto-Skirts:** Exterior vertical edges generate solid downward skirts to `skirt_bottom_y` (default `-1.2 m` or `-8.0 m` at river seawalls) so **zero horizontal air gaps** are ever visible beneath elevated slabs.
   - **Auto-Guardrails:** Edges marked in `edges = ["W", "E", "N", "S"]` can automatically emit visible parapets PLUS `2.2 m` (`>= 2.2 m`) invisible upper containment colliders (`wall` vs `rail_2m2`).
2. **LINK (`add_stair` / `add_ramp`):**
   - Connects two named Decks `(from_deck, to_deck)` across an exact `(a -> b)` world polyline with calculated `rise`, `run`, `slope_deg`, and continuous sloped collision ramp (`BoxShape3D` under smooth tread overlay so `player.gd` and `zombie_nav.gd` climb effortlessly without step-catching).
   - Automatically registers undirected (or gated `flag_req`) graph edges for multi-tier navigation (`steer()`) and reachability validation.
3. **SHELL (`add_building`, `add_tunnel`, `add_overpass_span`, `add_viaduct_run`):**
   - Multi-story shophouses with ground awnings & recessed shopfronts, enclosed subterranean concourses with ceiling headers (preventing skylight leaks), tubular glazed steel overpass walkways (`arch ribs + mullion frames + intact/shattered glass`), and monolithic cylindrical highway piers + hammerhead caps + overhead deck beams.
4. **SEAM & TRANSITION BUFFER (`z = 600.0`):**
   - While inside PILCST (`stage < 16`), `school.gd` draws a lightweight `_rear_stub` outside the Rear Gate (`z = 600..616`) for horizon framing.
   - The instant survivors clear Heavy-arm (`stage 15 -> 16`, `start_outer_street()`), `school.drop_rear_stub()` frees the temporary street and `school.seal_rear_gate()` slams & chains the Rear Gate shut behind the squad (`flags.outer_sealed_behind = true`) as `outer_street.gd` takes over the full manifold seamlessly from `z = 600.0` northward. Zero overlap, zero double meshes, zero missing floor collider at the threshold.

---

## 4. Canonical 5-Tier Vertical Architecture

Every post-Heavy-Arm district spans up to **five vertical strata** visible simultaneously from arrival:

| Tier ID | Elevation (`Y`) | Structural Role | Outer Street Examples |
| :--- | :--- | :--- | :--- |
| **`TIER_SKY`** | `+11.5 m .. +26.0 m` | Heavy elevated city infrastructure anchoring silhouettes against the night moon and distant haze. | 7 cylindrical Highway Viaduct piers (`r = 1.1 m`), hammerhead crossheads, `y = +11.5` overhead highway deck, gantry frames, sagging utility lines. |
| **`TIER_ELEVATED`** | `+4.2 m .. +6.0 m` | Upper pedestrian crossings, hillside terraces, sniper/lookout vantage points, bypass routes over street blockades. | Covered Glass & Steel Pedestrian Overpass (`y = +5.6`), Hillside Mahjong & Sari-Sari Terrace (`y = +4.2`), Yellow-Rail Grand Stair landing, 2F shophouse balconies. |
| **`TIER_STREET`** | `0.0 m` | Main civic avenue, vehicle blockades, commercial plazas, primary landmarks & sightline hubs. | Buhangin Crossing Avenue, Zebra Crosswalk, Median Vending Machine Plaza, Blue-White Tarped Scaffolding Courtyard, Quarantine Barricade (`z = 677.5`), North Evacuation Gate (`z = 740`). |
| **`TIER_EMBANK`** | `-1.2 m` | Peripheral bypass lanes, coastal/riverbank roads, low cover flanked by natural water drops. | Curving River Embankment Road (`x = 92..106`), Stalled City Transit Bus, Concrete Seawall Parapet, Black Davao River (`y = -7.5 m`), distant steel arch bridge. |
| **`TIER_UNDERGROUND`** | `-3.8 m` | Claustrophobic, moonlight-sealed infrastructure forcing flashlight commitment (`layers = 1 \| 8`). | Sunken Subway Pedestrian Underpass (wet ceramic concourse, shuttered kiosks, payphones, body sheets + wake candles), Flooded Viaduct Storm Culvert, Breaker B Substation Vault. |

---

## 5. Braided Non-Linear Topology (Anti-Corridor Law)

Linear shooters fail horror pacing because players never choose risk, commit resources blindly, or learn a space. Every Post-Heavy-Arm map enforces **Braided Hub Topology**:

1. **The 5-Second Arrival Vista (`Zone 0`):** Stepping into the Arrival Plaza (`z = 600..626`) MUST frame **all active spatial tiers and at least three distinct routes** in one screen glance—assisted by atmospheric contrast lights, vehicle wreck choreography, and cable traces.
2. **Three Simultaneous Exploration Wings:** Before unlocking the district finale gate, players may freely explore and clear three interconnected arms in any order:
   - **West Wing (`Hillside Terrace`):** Yellow-Rail Grand Stairs (`L_STAIR_W`) ascending to the Mahjong Sari-Sari Corner, Hillside Shophouses, **Breaker A**, and Stepped Hillside Descent Alley (`L_ALLEY_N`).
   - **Center Spine & Overpass (`Crossing -> Skyline Overpass`):** Vending Plaza & Subway mouth, Construction Scaffolding Courtyard, Glass Pedestrian Overpass climbing over the Quarantine Barricade (`L_OVERPASS_W -> Overpass -> L_OVERPASS_NE / L_OVERPASS_SE`).
   - **East & Underground (`Subway + Storm Culvert + River Embankment`):** Subway stairs descending (`L_SUB_S`) beneath the blocked avenue through the Flooded Storm Culvert to **Breaker B**, unlocking the culvert stair (`L_CULV_E`) out onto the Stalled Bus Embankment Road (`y = -1.2`) and Service Road under the Highway Viaduct.
3. **At Least 3 Player-Triggered Loop-Closing Shortcuts:**
   - Exploring dead-end flanks or upper catwalks reveals barred doors, hanging plank ramps, and jammed vehicle gates (**`SC_COURTYARD`**, **`SC_OVERPASS`**, **`SC_VIADUCT`**) plus utility unlocks (**Breaker B** energizing **`L_CULV_E`**).
   - Triggering a shortcut permanently weaves back-routes across the map so later horde pressure (`stage 17` convergence) turns the district into an intense multi-level kiting playground rather than a bottleneck.
4. **Dual-Objective Power & Evacuation Gate Finale:**
   - Gated progress requires flipping both **`Breaker A`** (West Hillside Substation) and **`Breaker B`** (East Subterranean Culvert Vault).
   - Activating both energizes the dual **Amber + Cyan beacons** on the Evacuation Gate gantry (`z = 740`), sliding the heavy blast doors open (`14 s`) while triggering the convergence assault across all three north lanes (`Hillside Alley`, `Overpass North Stair`, `Viaduct / Embankment North Ramp`).

---

## 6. Six-Layer Sleep Horror & Uncanny Aesthetic Stack

1. **Brutalist Tropical Infrastructure:** Rain-stained concrete retaining walls, ribbed steel overpass trusses, cylindrical viaduct columns, open storm drains, corrugated shanty eaves.
2. **Weathered PBR Materiality:** Anchored to `game/assets/outdoor/textures/` (`asphalt_02`, `concrete_pavement`, `concrete_floor_02`, `concrete_wall_008`, `concrete_block_wall`, `red_brick`, `corrugated_iron`, `rusty_metal_02`, `mossy_cobblestone`, `mud`, `sparse_grass`) + reflective puddles and matte tire rubber.
3. **Curated Environmental Props:** Authentic Jeepneys, Tricycles, Tuk-tuks, Food Carts with faded striped umbrellas, Plastic Monobloc Chairs, Mahjong Table & tiles, Vending Machine bank, Payphones, Oil Drums, Construction Tarps (blue/white vertical stripes), Trashbags, Concrete Jersey Barriers, Stalled City Bus with interior seats.
4. **Uncanny Light & Color Contrasts:**
   - **Warm Domestic Illusion:** Tungsten sari-sari stall (`#ffd08a`) and glowing sari-sari sign beside dark shuttered balconies with hanging silhouettes of laundry.
   - **Cold Civic Isolation:** Cyan glowing vending bank (`#80e8ff`) humming beside abandoned wet subway stairs.
   - **Sodium Warning & Fire Dread:** Amber streetlamps with failing fluorescent stutter (`mode = 2`), red warning taillights on the silent stalled embankment bus, distant arterial haze/smoke over the river horizon (`#ff5a24`).
5. **Diegetic Cable & Sign Wayfinding:** No floating glowing UI markers needed to read progression—thick grounded **Amber (West)** and **Cyan (East/Down)** high-voltage cables run directly from the crashed barangay power truck at `z = 612` all the way to Breakers A & B and converge back up the Evacuation Gate gantry (`z = 740`).
6. **Horror Trace Choreography (`HorrorLiquid`):** Arterial drag marks from a fallen bag into the South Subway entrance, crimson splatter across shattered overpass glass panels, wake candle rings around tarped bodies along the underground concourse, dark trails beneath the stalled bus doors.

---

## 7. Anti-Emptiness Per-12m-Cell Budget

Open-air streets fail when broad slabs stretch `15-30 m` with zero visual rhythm. `SleepMapValidator` divides every navigable region into **`12 m x 12 m` cells**. Each active navigable cell MUST contain at least:
- **`>= 1` structural landmark/cover element OR `>= 3` props/micro-details** (curbs, puddles, tires, crates, bollards, weeds, decals, lights, chairs, barriers), AND
- Continuous lighting motivation (local fixture glow, spill from signage, moonlit open asphalt, or deliberate flashlight-only dark horror zone paired with proximate threshold light within `<= 16 m`).

---

## 8. The 7 Automated Verification Gates (`SleepMapValidator`)

Every district built on `SleepMapBuilder` MUST pass all 7 automated audit gates before export:

| Gate | Method | Pass Criteria |
| :--- | :--- | :--- |
| **1. Floor Manifold** | `audit_floors()` | Every walkable deck slab thickness `>= 0.35 m`, skirts drop past terrain datum, zero un-holed overlapping floor collider conflicts at stairwell openings. |
| **2. Edge Containment** | `audit_edges()` | Every perimeter or cliff segment bordering `drop >= 1.8 m` has `>= 2.2 m` vertical containment (unless registered `one_way_drop` with verified landing pad). |
| **3. Link Slope & Headroom** | `audit_links_and_headroom()` | Every stair/ramp link checks slope `<= 28.5 deg`, width `>= 2.2 m` (`>= 2.4 m` main thoroughfares), overhead clearance `>= 2.55 m` via live Jolt Physics shape/ray sweeps. |
| **4. Prop Grounding & Ghosts** | `audit_grounding()` | Placed props rest within `0.15 m` of a Layer-2 floor collider; major structural obstacles (`> 0.45 x 0.25 m`) have valid physics shapes (`0` ghost blockers). |
| **5. Multi-Tier Reachability** | `audit_reachability()` | Multi-tier graph + nav check verifies pathing from Arrival (`z=604`) to Breaker A, Breaker B, Sari-Sari Terrace, Overpass, Flooded Culvert, Embankment Bus, all 3 shortcuts, and (`post-breakers`) to Extraction (`z > 748`). |
| **6. Anti-Emptiness Density** | `audit_density()` | Zero navigable `12 m x 12 m` cells fall below minimum prop/landmark/detail density bounds. |
| **7. Lighting & Layer Hygiene** | `audit_lighting_and_layers()` | 100% outdoor geometry carries Layer `2` (`layers & 2 != 0`); 100% underground geometry omits Layer `2` (`layers & 2 == 0`); active wing zones contain motivated light sources. |

---

## 9. District 01 Blueprint Spec — `Outer Street: Buhangin Crossing`

### 9.1 Bounds, Stages & Flags
- **Local Span:** `X in [0.0, 108.0]`, `Z in [600.0, 772.0]`.
- **Stage Flow (`mission.gd`):**
  - `Stage 16` (**Restore power to the Evacuation Gate**): Players clear PILCST Gate, enter Arrival Vista (`z = 600..628`), freely explore West Hillside, Overpass, Subway/Culvert, and River Embankment to flip **`Breaker A`** (`flags.outer_breaker_a = true`) and **`Breaker B`** (`flags.outer_breaker_b = true`).
  - `Stage 17` (**Reach the North Evacuation Gate!**): Both breakers energized; Evacuation Gate slides open over `~14 s` as warning sirens wail and convergence horde rushes down the three North lanes.
  - `Stage 18` (**Extraction / `WON`**): Surviving players cross `z > 748.0` onto the North Viaduct Bridgehead (`INTERIOR_COOP_OUTER won`). `Stage 19 = FAILED`.

### 9.2 Reference Motif Integration Matrix
Every primary visual landmark draws directly from District 01 location studies:

| Motif | Zone & Tier | Exact Gameplay Role |
| :--- | :--- | :--- |
| **Towering Viaduct Piers & Hammerhead Highway** | Zone 5 (`X=68..88`, `Z=604..740`, `Y=0 / +11.5`) | 7 `r = 1.1 m` concrete piers + overhead deck anchor sightlines across the entire level; forms the shadowed Eastern Service Road & Viaduct Gatehouse. |
| **Yellow-Rail Hillside Grand Stairs** | Zone 2 (`X=25.5->15.5`, `Z=640`, `Y=0->+4.2`) | Unmistakable 3 safety-yellow tubular handrails + blue wheel ramp + red-striped transformer pole + overturned green delivery trolley; ascends directly to West Terrace. |
| **Warm Sari-Sari Corner & Mahjong Table** | Zone 2 (`X=4..16`, `Z=662..680`, `Y=+4.2`) | Glowing open shop counter, overarching tree, 2F hanging laundry balcony, square green mahjong table with plastic stools & crackling transistor radio -> shelters players & hides Breaker A overlook. |
| **Stepped Hillside Descent Alley** | Zone 2 (`X=14->22`, `Z=702->713`, `Y=+4.2->0`) | Terraced retaining stairs lined with neighbor roofs & warm alley bulbs overlooking the North Crossing Plaza -> fast northern drop flanking the Quarantine Barricade. |
| **Enclosed Glass-Roofed Pedestrian Overpass** | Zone 3 (`X=21..68`, `Z=668.5..673.5`, `Y=+5.6`) | Diagonal tubular steel ribs + tinted canopy glass (several shattered panels with glass on tread) bypassing the sealed street Quarantine Barricade below, with West (`L_OVERPASS_W`), SE Shortcut (`SC_OVERPASS`), and North Descent (`L_OVERPASS_NE`) stairs. |
| **Subway Kiosk, Vending Plaza & Tarped Scaffolding** | Zone 1 (`X=28..64`, `Z=628..677`, `Y=0`) | Three glowing vending machines on raised concrete island (`SC` hub), South Subway Entrance with fresh blood drag trail leading underground, Blue-White vertically tarped corner building with `SC_COURTYARD` construction walkway drop-bridge. |
| **Subterranean Underpass & Flooded Storm Culvert** | Zone 4 (`X=30..82`, `Z=642..706`, `Y=-3.8`, `indoor=true`) | Moonlight-sealed concourse: shuttered metal shops, payphone alcoves, white body sheets with wake candles, flooded ankle-deep tunnel winding past concrete viaduct footings to **Breaker B Vault (`X=72, Z=686`)**, unlocking `L_CULV_E`. |
| **Curving River Embankment Road & Stalled Transit Bus** | Zone 6 (`X=92..106`, `Z=654..728`, `Y=-1.2`) | Asphalt riverside curve overlooking Davao River (`y = -7.5`), steel arch bridge silhouette (`z = 805`), orange arson skyline glow, stalled green-and-cream city bus with red brake glow & huddled horror sleepers inside. |
| **North Convergence Plaza & Viaduct Evacuation Gate** | Zones 7–8 (`Z=679..768`, `Y=0`) | Tri-lane horde intersection culminating in twin powered blast doors (`X=46..58, Z=740`), Dual Amber/Cyan Breaker Stacks, Overhead Light Gantry, and the North Bridgehead Extraction (`z > 748`). |
