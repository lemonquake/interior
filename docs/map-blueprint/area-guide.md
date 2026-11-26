# Area guide and route constraints

This is a description of the current working source and a fresh startup instance on 2026-11-10. It includes story and hidden-route spoilers. The game's displayed title is **Sleep**; the repository and executable retain **Interior**. Historical handoffs describe older layouts. Prefer this snapshot's coordinates and the current scripts if they disagree.

## Home: living room, kitchen and studio

The game starts in the family living room at H01. The TV wall is south, at negative Z. The studio and balcony lie north of the living room at positive Z. The kitchen is west, outside the original imported room's west wall. The navy door is in the north wall near its east end. The studio slider is in the north wall near its west end. The locked closet is in the east wall and should not be interpreted as another existing playable room.

The fabric sofa occupies the west side, the leather sofa the north side, the marble table the middle, and the TV console the south wall. The computer desk, crib, high chair, guitar and storage/display furniture occupy the east/southeast part. The hamster stand and aquariums sit toward the southwest. Individual props, photographs, cups, cushions, fruit, bottles and small decor are listed with real node paths in scene-nodes.csv and runtime-scene.json. That inventory also includes attached fish, hamster skeletons, habitat tubes and rendering details; the location register only labels the useful editing anchors.

The clock H15, plant H16 and cabinet photo H17 are mystery-note props. The TV H13 has on/off, channels and inspect behavior. Those systems live in interior.gd, television.gd and the corresponding prop scripts; moving a visual mesh alone does not move its independent collision or interaction automatically.

The acoustic-lined studio is a separate root scene. It has a production desk, two monitors, a guitar wall, drum kit and keyboard station. Its floor shares Y=0 with the living room. Its door is a sliding leaf, not a swinging exterior door. The south edge of the studio coincides with the north wall of the living room; there is no teleport transition.

## Balcony, stairs, courtyard and lane

Opening H02 leads directly to the balcony. The balcony contains the aquarium, shoe storage, railing and translucent floral screen. Walk east to the stair; descend 16 risers along the yellow house wall to the courtyard at Y=-2.9. The courtyard gate T01 is at the east fence, X=12.6. The gate starts latched. E releases the latch; walking into it, or holding E while moving, provides the actual push/pull.

Outside it, T02 is the audit start point. Walk east through the lane to T03 on street B at approximately (21.4,-2.9,6), then north to T04 at the A/B corner. Street A is centred at Z=18. The real-player test route is included in routes.json; do not walk directly north through the neighboring lot. This is the connection between the personal house and the larger town. The balcony and courtyard are at different heights; a plan view by itself conceals that 2.9 m change.

## Town streets, neighboring lots and three exits

The four source roads form a street loop: A at Z=18, B at X=21, C at Z=49 and D at X=-19. B is the street associated with the Malasugue Street sign. Each authored road corridor is 6 m wide, including a 4 m asphalt carriageway and two 1 m sidewalks. Source street extents run well beyond the current enclosed playable block; geometry outside the wall should not be called an open route.

Neighborhood lots are deterministically generated with seed 20261005. Rows run along four sides of the block plus additional east, west and background rows. Some lots are vacant. House storeys and frontage vary by row. A rendered house shell is not an implemented interior: ordinary neighboring doors are knock/response interactions with locked façades. The fresh runtime reports 36 physical double gates and 21 usable house doors, plus 21 associated objects. These gates include background lot placements beyond the enclosed core; not every gate in the scene is reachable.

The sheet-iron perimeter lies at west X=-23.85, east X=25.8, north Z=54.8 and south Z=-18.55. Another run at Z=8.95 extends east from the west wall to X=-7.6. Its sheets, braces, poles, wire and debris are physical geometry. The current wall builder reports 597 sheets, 94 posts and 31 route pallets. These counts are builder metadata and do not all correspond one-to-one with scene nodes because geometry is batched.

There are three intended ways through the perimeter. T08 is the open passage west along street A; pallets, cable bulbs and orange arrows guide it. T09 is a low torn opening north along street B; hold C to pass its .95 m width and 1.3 m height. T10 is the concealed south route to Nichols: enter from the open east end behind leaned sheets, crouch along the inside wall and out underneath. Its west end is blocked by tyres. Do not remove the leaned sheets or enlarge the hole while doing an unrelated street edit: their shape is the hidden-route design.

The horror dressing is built separately under Town siege/Town horror. It includes the abandoned evacuation camp in vacant lots across A, a checkpoint near the west passage, covered bodies, candles, burnt tyres, belongings, drag trails, wall marks and fiesta bunting. These are not additional map branches. Street litter, weathering and decals have separate runtime builders. Many are visual-only, while some props are movable; use collision records to distinguish them.

## Canal settlement: upper lane, ravine and crossings

From T08 continue west to C01. This is the newer river-aligned settlement, replacing the older version-0.16 grid. Its horizontal placement uses river coordinates: X = rx(Z) + U, where rx(Z) = -66 + 2.4 sin((Z-4)*.052). U is metres east/west of the river centre, not world X. The settlement spans Z=-16..70. The east retaining edge is U=5.6. Its bank floor and house floors are Y=-2.1, the metal catwalk is Y=-4.4, water Y=-6, and bed Y=-6.55. The far-bank footpath starts at Y=-5.45.

The lane between upper house rows lies approximately U=12.9..16.9. The trench stair at Z=22.2 connects its upper level (U=10.3) to the catwalk foot (U=4.9); the sloped walking collider is 1.4 m wide, with 15 visible concrete steps. The catwalk itself spans U=3.72..5.58 along the east retaining wall. At Z=50 it climbs northward to the bridge-level landing, reaching Y=-2.1 around Z=55.4.

Two crossings link the banks. The southern plank footbridge at Z=-9 descends from the catwalk at U=3.72, Y=-4.4 to far-bank U=-6.7, Y=-5.45. The northern concrete road bridge at Z=60.2 spans U=-15..8 and is 4.4 m wide along Z. The far-bank footpath rises smoothly from Y=-5.45 at Z=44 to Y=-2.1 at Z=57, making a loop with the northern bridge and east-bank access.

The current settlement metadata reports 30 houses: 11 river-side, 14 lane-side, five far-bank; 72 storeys in total. House floors and walls are not all full interiors. Its 725 collider count includes objects it builds for the warren too, because both use shared Canal surfaces. Its eight counted bulbs supersede older handoff statements about five lights; actual runtime lights and their scripts are in the inventory.

## Hidden warren behind the far-bank fence

The warren is farther west than the main river, behind a fence at river U=-28.5. Its entry is at Z=8, exit at Z=54.7. From the plank footbridge's west end head north along the far bank, climb the trodden slope at Z=8, and continue through the pried tin sheet. The approach point used by world_audit.gd is X=-86, not the actual fence opening near X=-94; the two labels intentionally represent different points.

A second black drainage channel runs through the warren. Its river-space centre offset is ec(Z) = -41 + 1.1 sin((Z+10)*.09). Therefore world X = rx(Z) + ec(Z) + D, where D is eastward offset from this smaller channel. Do not omit rx(Z), and do not treat ec(Z) as world X. Decks are Y=-2.05, room/ground datum -2.1, water -3.55 and bed -4.1. Roof underside is normally Y=.22. The collapsed section has a lower underside around -.83.

The entry access joins the east boardwalk south segment (Z=-11.9..9.2). Travel south, crouch beneath the collapse at Z=-2.2..-.3, and cross W03 at Z=-11 to the west boardwalk. Head north through the family room (Z=1..6), altar room (18..23), moonlit courtyard (28..34) and store rear room (40..45). Cross W08 at Z=52.6 to the short east north segment (51.6..55.8), then follow the access alley out at Z=54.7. The western deck spans -11.9..53.5 and detours through these rooms; a direct straight line through the water is not the route.

House fronts are D=±2.45; the walks project toward the water to D=±.85. A normal boardwalk is therefore about 1.6 m wide. The rooms extend west to D=-6.5. Each plank crossing spans 4.9 m nominally and is 1 m wide. Barricades close the unused boardwalk ends, and culverts/headwalls close the drainage channel's ends at Z=-15.6 and 58.6. The long tunnel-like roof has slits and a deliberately open courtyard; it is not an underground tunnel.

The runtime warren metadata reports 31 houses, eight door objects, 14 locked interactions, 39 loose props, four lights and 17 usables. The six numbered room doors and the two tin access doors have separate nodes. The usable radio, switch and pump are W12–W14. Knocking at locked doors invokes the town's encounter controller. Plastic chairs, pails, basins, bottles, pots and crates can be loose physics objects.

## Nichols grounds and house

After the concealed south crawl T10, follow the dirt-path control polyline in routes.json to N01. The surrounding source region X=-46..26, Z=-130..-18 is larger than the fenced estate X=-40..14, Z=-124..-60. The open gate is centred at (-12,-2.9,-60). The drive, dry fountain, dead trees and statuary lead to the porch. The house facade datum is (-12,-1.7,-82); the house extends south to approximately Z=-102. A tower rises well above the occupied storeys, with its top spot at Y=17.65. That tower spot is a model reference and does not establish an accessible upper tower route.

The ground floor contains the central tall foyer, west parlour, east dining room, a narrow closet volume behind the stair, cross hall, southwest library, south-central pantry and southeast kitchen. The grand stair rises from the foyer through a half landing at world Y=.5 to the upper floor at Y=2.7. Upstairs, front corridors and a bridge cross the north side of the foyer, with narrow galleries along its edges, west master bedroom and east nursery. The rear upstairs is a sealed volume. Consult room-dimensions.md for every world rectangle and initial door state. Layout volumes describe detection and surfaces, not an accessibility guarantee.

The mansion is added at runtime, not stored in main.tscn as a separate fixed scene. Its Blender house assets, layout boxes and script-built collisions must agree. Some visual geometry is batched. The grounds use moon/sky lighting; the interior uses visual layer 1024, with selected architecture on a separate shadow layer. The dark appearance is intentional and is not evidence that geometry is missing.

## Cellar and wartime tunnel

The blood trail begins at the porch/front entrance, crosses the foyer, passes the east side of the grand stair and enters the low cellar door under the landing. B13 is its hinge. The switch B14 is beside it. The lights start off. Follow the shaft stair down to the fieldstone cellar at Y=-4.4, then through the broken wall and descending passage into the corridor at Y=-5.3. B15 is the chained terminal iron door; the current implementation does not expose a continuing playable route beyond it.

The cellar includes shelves, workbench/butcher corner, hooks, drain and covered shape; the tunnel contains cages. The copied basement layout records exact spots, door, switch, bulbs, trail and kitchen details above. There are eight authored bulb entries; one is dead. The script gives the basement its own visual layer 4096 so moon and sky fill do not light it. Floor holes require coordinated terrain removal: the house hole is X=-25..1, Z=-102..-82. Restoring an old uncut town ground slab would fill the basement with collision.

## Rice-field road, hut, scarecrow, pond and dead end

Past the north crouch hole the road follows the baked ROAD samples; its actual sampled length is 491.7 m. The controls run from street B through (21,66), (17,110), (12,150), (22,185), (45,215), (62,250), (66,290), (62,340), (60,390), (52,440), (44,490) to (40,530). The first builder control (21,40) only shapes the spline start and is not the first stored sample. Use the actual samples in routes.json for precise placement.

Ground is around Y=-2.9, paddy water -3.32. Asphalt becomes a 4.1 m dirt road with verges; the walkable band is approximately ±3.2 m from its centre. Invisible side walls constrain traversal. Water scenery covers X=-150..180, Z=66..640 with a northwest town notch; it is not all accessible. Decorative paddy dikes and rice should not be interpreted as unrestricted paths.

Near Z=149 the hut branch leaves the road toward the east. The yard metadata reference is (32.9555,-2.9,148.6332); the hut model and runtime root are at Y=-3.05. Its floor is local .42, giving world Y=-2.63. Runtime code rotates its local +X doorway toward the road. The precise approach and local/world basis are in runtime-scene.json. Inside are the mat/pillow, table/stool, shelf/jars, water jar, sacks and dresser. The brass key unlocks its top drawer; gun and flashlight are inside. The drawer moves .3 m in hut local space. Use the saved basis when moving any of those items.

The scarecrow stands at (28.9456,-3.06,178.7335) on an islet. Its dike is approximately 2.1 m wide; islet top radius 2 m. The ammunition box begins hidden nearby. The stranger's story controls the dig and handover. The exported crow_route gives the actual road-to-islet anchors, while route_in gives road-to-hut anchors. Do not place the actor on water between these branches.

The pond centre is (28.0103,225.5523) in XZ, with radii 15 and 12.5 m. The jetty branches from the road over its bank. Its collider-centre reference F07 is not the deck height: the deck is near Y=-2.96. The road then continues north to F08 at (40,-2.9,530), ending at a fallen trunk and SIRADO barrier. The giant tree F09 at (25.09,-2.9,551.3) lies beyond it as scenery. The world does not continue along a supported road to Z=640.

## Actor and progression references

The hooded man starts at the courtyard gate, triggers a staged first-sighting camera sequence, then waits at T11 once the gate opens. He demonstrates the crouch exit T09, stands again at T12 and flees to the hut. Later story states use the hut, scarecrow dike and ammunition handover. Coordinates for an actor's state are not permanent map geometry. Preserve the state machine and its support checks if moving roads, the hut, gate or scarecrow. story.gd, stranger.gd and hut_house.gd own that sequence; stranger_cutscene.gd owns the camera staging.

## What this package verifies

The inventory is from a fresh normal startup, with runtime neighborhood, canal, warren, estate, basement, hut, interaction conversion and siege enabled. It records local/global transforms, basis columns, groups, scripts, collision layers, disabled shapes, gameplay properties, light data and geometric envelopes. It does not serialize full mesh triangles, all animation state, all object properties or a saved playthrough.

The fresh world audit covers X=-130..60, Z=-136..64 at .75 m grid spacing. It uses floor rays, a .45 m step limit and standing/crouching capsule tests; it ignores loose rigid props, animatable bodies and openable gates/doors. Its eight checked landmarks are reachable in that simplified query. It does not verify the full field road, every house interior, every stair, story triggers or player execution of every route. The audit's test capsules are slightly reduced relative to the player's nominal 1.7/1.0 m heights. Thus its area figures and distances are approximate and do not establish exact usable floor area.

Engineering maps show convex projected envelopes at the specified slice height. Triangular terrain is omitted from solid plan shading. Rotated/sloped or concave objects can occupy less than their drawn envelopes; a long batched mesh envelope can cover empty space. Blue shading is therefore a geometric reference, not a navigation mesh. Points identify useful editing anchors; source files and runtime collision must remain the final authority.
