"""Create source-backed map documentation from map_blueprint_export.gd's snapshot.
Run from the repository root: python tools/make_map_blueprint.py
This script writes documentation only. Requires matplotlib and Pillow.
"""
from pathlib import Path
import collections, csv, hashlib, html, json, math, re, shutil, subprocess, textwrap, zipfile
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Polygon, Ellipse
from matplotlib.collections import PatchCollection
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/map-blueprint'
OUT.mkdir(parents=True, exist_ok=True)
SNAPSHOT = json.loads((OUT / 'runtime-scene.json').read_text(encoding='utf-8'))
NODES = SNAPSHOT['nodes']
BY_PATH = {n['path']: n for n in NODES}
LAYOUT = json.loads((ROOT / 'game/assets/models/nichols/house/layout.json').read_text())
MANIFEST = json.loads((ROOT / 'game/assets/room_manifest.json').read_text())
FIELDS = BY_PATH['Fields']['metadata']
ROAD = FIELDS['road_samples']
TOWN = 'Balcony/Neighbourhood'
CANAL = TOWN + '/Canal settlement'
WARREN = CANAL + '/Canal warren'
NICHOLS = TOWN + '/Nichols property'
HUT = 'Fields/HutHouse'
POIS = []

def source(file, needle):
    path = ROOT / file
    lines = path.read_text(encoding='utf-8-sig').splitlines()
    line = next((i+1 for i,s in enumerate(lines) if needle in s), 1)
    return {'file':file, 'line':line}

def poi(id, name, p, area, detail, path='', file='', needle=''):
    row = dict(id=id, name=name, position=[round(float(x),4) for x in p], area=area,
               detail=detail, evidence='source coordinate', node_path=path)
    if path in BY_PATH:
        row.update(node_id=BY_PATH[path]['id'], evidence='runtime transform')
    if file:
        row['source'] = source('game/scripts/'+file if '/' not in file else file, needle)
    POIS.append(row)
    return row

def np(id, name, path, area, detail):
    node = BY_PATH[path]
    return poi(id,name,node['position'],area,detail,path,node.get('script','').replace('res://','game/'), '')

def rx(z): return -66 + 2.4*math.sin((z-4)*.052)
def ec(z): return -41 + 1.1*math.sin((z+10)*.09)
def cp(u,y,z): return [rx(z)+u,y,z]
def wp(d,y,z): return cp(ec(z)+d,y,z)
def nw(p): return [p[0]-12,p[1]-1.7,p[2]-82]

poi('H01','Player spawn',MANIFEST['spawn'],'Home','Player feet spawn; room floor near Y=0.', 'Player','game/scripts/interior.gd','player.position =')
np('H02','Navy entry door hinge','LivingRoom/ReferenceRoomSurroundings/EntryDoor','Home','Leaf spans X=1.39..2.43; inner face Z=2.6335. Swings inward toward -Z.')
np('H03','Studio sliding door','Studio/StudioDoor','Home','Door node origin, not doorway midpoint. Opening X=-3.25..-1.24, Z near 2.9, height 2.4.')
np('H04','Locked closet door','LivingRoom/LockedClosetDoor','Home','Locked prop door on east wall; no documented playable room beyond it.')
poi('H05','Kitchen entrance',[-3.3,0,1.95],'Home','West-side opening; kitchen bounds X=-5.65..-3.3, Z=-2.7..2.7.',file='room_surroundings.gd',needle='kitchen_bounds')
for id,name,path,detail in [
 ('H10','Fabric sofa','fabric_sofa_0','Physical furniture assembly.'),
 ('H11','Leather sofa','leather_sofa_1','Physical furniture along north/rear wall.'),
 ('H12','Marble table','marble_table_2','Physical table; tray, plant and tissue box rest above it.'),
 ('H13','Television','television_4','TV-wall anchor; power, channels, inspect interaction and mystery lock.'),
 ('H14','TV console','tv_console_3','Console below television.'),
 ('H15','Digital clock','digital_clock_17','One of the note-bearing props; clock has abnormal time display.'),
 ('H16','Table plant','potted_plant_15','One of the note-bearing props.'),
 ('H17','Cabinet photo','photo_frame_19','One of the note-bearing props.'),
 ('H18','Hamster enclosure stand','pet_enclosure_11','Three-level habitat; movable assembly with attached animal systems.'),
 ('H19','Small aquarium','SmallAquarium','Lower shelf aquarium.'),
 ('H20','Computer desk','computer_desk_6','Desk in the southeast/TV-wall corner.'),
 ('H21','Baby crib','baby_crib_9','Physical crib assembly.'),
 ('H22','Standing fan','standing_fan_5','Physical standing fan.'),
 ('H23','White display rack','White display rack','Named furniture, beside the TV area.'),
 ('H24','Black storage rack','Black storage rack','Named furniture, at east end of TV wall.')]:
    np(id,name,'LivingRoom/'+path,'Home',detail)
poi('H30','Studio interior centre',[-3.45,0,5.1],'Home','4.4 by 4.4 m; X=-5.65..-1.25, Z=2.9..7.3; ceiling Y=2.9.',file='studio_builder.gd',needle='const SX0')
poi('H31','Studio production desk',[-2.6,0,6.745],'Home','Desk base reference; desk top Y=.692.',file='studio_builder.gd',needle='const DESK :=')
for id,name,path in [('H32','Studio couch','Studio/Couch/sofa_02'),('H33','Drum kit','Studio/Drum kit/drum_kit'),('H34','Two-tier synthesizers','Studio/Synth 61-key/synth_b'),('H35','Acoustic guitar A','Studio/Guitar acoustic_a/guitar_acoustic_a'),('H36','Bass on stand','Studio/Bass on stand/bass_precision'),('H37','Gaming chair','Studio/Gaming chair/gaming_chair'),('H38','Microphone stand','Studio/Mic boom stand/mic_boom_stand')]:
    np(id,name,path,'Studio','Runtime model origin. See parent collision body and siblings for the complete assembly.')
poi('H40','Balcony centre',[3.275,0,3.725],'Home','Floor bounds X=.95..5.6, Z=2.9..4.55; outer parapet Z=4.75.',file='balcony_builder.gd',needle='const X0')
poi('H41','Stair upper end',[5.6,0,3.38],'Home','16 risers, rise .18125 m each; treads .27 m. Descends east to Y=-2.9.',file='balcony_builder.gd',needle='const RISERS')
poi('H42','Courtyard',[11.1,-2.9,4.1],'Home','Courtyard reference; X=9.65..12.6, Z=2.9..5.3.',file='balcony_builder.gd',needle='const YARD_X')
gate_hinges=[BY_PATH['Balcony/CourtyardGate/'+leaf]['position'] for leaf in ['GateLeafNorth','GateLeafSouth']]
gate_centre=[sum(p[k] for p in gate_hinges)/2 for k in range(3)]
gate_ref=poi('T01','Courtyard gate opening',gate_centre,'Town','Opening midpoint derived from leaf hinges. CourtyardGate root itself is at (0,0,0). Tap E unlatches; push or hold E and move to swing leaves.','Balcony/CourtyardGate')
gate_ref['evidence']='derived from runtime hinge transforms'
poi('T02','Lane outside courtyard gate',[14,-2.9,4.6],'Town','Reachability audit origin; head east through lane to street B, then north to street A.',file='game/tests/world_audit.gd',needle='courtyard gate (outside)')
poi('T03','Courtyard lane / street B',[21.4,-2.9,6],'Town','Actual player-route test point at the lane mouth on Malasugue Street. Head north to A/B corner T04.',file='game/tests/street_integration.gd',needle='var route :=')
poi('T13','Bent Malasugue Street sign base',[18.5,-2.78,7.35],'Town','Source base of snapped street-sign pole beside the lane mouth.',file='street_dressing.gd',needle='var base := Vector3(18.5')
poi('T14','Whisper source behind east gate',[23.4,-1.45,10.5],'Town','Positional psst sound; approach trigger X=18..24, Z=5.5..16.5.',file='neighborhood_encounters.gd',needle='const PSST_SOURCE')
for id,name,p in [('T04','Street A / B corner',[21,-2.9,18]),('T05','Street A / D corner',[-19,-2.9,18]),('T06','Street B / C corner',[21,-2.9,49]),('T07','Street C / D corner',[-19,-2.9,49])]:
    poi(id,name,p,'Town','Intersection centre; street corridor width 6 m, including 1 m sidewalks each side.',file='neighborhood_builder.gd',needle='const STREETS')
poi('T08','Open west passage',[-23.85,-2.9,18],'Town','West wall opening Z=15.15..20.85; leads to canal settlement.',file='town_siege.gd',needle='const PASSAGE_Z')
poi('T09','North wall crouch hole',[21.32,-2.9,54.8],'Town','Width .95 m; height 1.3 m. Standing player cannot pass; hold C. Leads to field road.',file='town_siege.gd',needle='const HOLE_X')
poi('T10','Hidden south crawl',[19.35,-2.9,-18.55],'Town','Width .9 m. Enter from east end behind leaned sheets, crouch along wall, crawl south to Nichols path.',file='town_siege.gd',needle='const SECRET_X')
poi('T11','Hooded man waiting point',[21.32,-2.9,53.35],'Town','Scripted actor waits here after courtyard gate opens.',file='town_siege.gd',needle='const STRANGER_WAIT')
poi('T12','Hooded man beyond hole',[21.32,-2.9,56.6],'Town','Actor can stand again here before fleeing along field road.',file='town_siege.gd',needle='const STRANGER_OUT')
poi('C01','Settlement approach',[-30,-2.9,18.4],'Canal','Approach from west end of street A. Ramp joins settlement bank at Y=-2.1.',file='game/tests/world_audit.gd',needle='canal settlement (street A mouth)')
poi('C02','Upper east-bank lane',cp(14.5,-2.1,22.2),'Canal','Lane between house rows; river coordinates approximately U=12.9..16.9.',file='canal_settlement.gd',needle='const LANE_U')
poi('C03','Trench stair top',cp(10.3,-2.1,22.2),'Canal','1.4 m wide walking ramp with 15 visible steps, down 2.3 m to catwalk.',file='canal_settlement.gd',needle='var top := at(10.3')
poi('C04','Trench stair foot',cp(4.9,-4.4,22.2),'Canal','East retaining-wall catwalk at Y=-4.4.',file='canal_settlement.gd',needle='var bottom := at(4.9')
poi('C05','Plank footbridge east end',cp(3.72,-4.4,-9),'Canal','Footbridge width 1.15 m; spans to far bank U=-6.7 at Y=-5.45.',file='canal_settlement.gd',needle='func _footbridge')
poi('C06','Plank footbridge west end',cp(-6.7,-5.45,-9),'Canal','From here head north on far-bank path to the warren approach.',file='canal_settlement.gd',needle='func _footbridge')
poi('C07','Warren approach stair bottom',cp(-7.3,-5.45,8),'Canal','Bank steps climb west over U=-7.3..-13.6; then continue to fence opening.',file='canal_settlement.gd',needle='absf(z - WARREN.ENTRY_Z)')
poi('C08','Concrete road bridge',cp(-3.5,-2.1,60.2),'Canal','Deck spans U=-15..8, Z=58..62.4 (23 by 4.4 m).',file='canal_settlement.gd',needle='func _road_bridge')
poi('C09','Catwalk north stair start',cp(4.65,-4.4,50),'Canal','Climbs to Y=-2.1 at Z=55.4; landing connects to road bridge.',file='canal_settlement.gd',needle='var s0 :=')
poi('C10','Far-bank path north climb',cp(-7,-5.45,44),'Canal','Path height smoothly rises from -5.45 at Z=44 to -2.1 at Z=57.',file='canal_settlement.gd',needle='static func path_y')
poi('W01','Warren fence entrance',cp(-28.5,-2.1,8),'Warren','Pried tin sheet near actual door W10; continue west through access alley to east boardwalk.',file='canal_warren.gd',needle='const ENTRY_Z')
poi('W02','Collapsed roof',wp(1.65,-2.05,-1.25),'Warren','Crouch section Z=-2.2..-.3 on east boardwalk. Roof low point Y=-.83; deck Y=-2.05.',file='canal_warren.gd',needle='const SAG')
poi('W03','South plank crossing',wp(0,-2.05,-11),'Warren','Cross east to west boardwalk here; bridge 4.9 by 1 m nominal.',file='canal_warren.gd',needle='const B1_Z')
poi('W04','Family room',wp(-3.7,-2.05,3.5),'Warren','Through-room on west side, Z=1..6; radio, light switch, sleeping area and old TV.',file='canal_warren.gd',needle='const ROOMS')
poi('W05','Altar room',wp(-3.7,-2.05,20.5),'Warren','Through-room on west side, Z=18..23; one votive candle.',file='canal_warren.gd',needle='const ROOMS')
poi('W06','Moonlit courtyard',wp(-4.2,-2.05,31),'Warren','Open courtyard Z=28..34; pump, cages, clotheslines and gutted tricycle.',file='canal_warren.gd',needle='const YARD')
poi('W07','Store rear room',wp(-3.7,-2.05,42.5),'Warren','Through-room Z=40..45 behind padlocked sari-sari store; kerosene lamp.',file='canal_warren.gd',needle='const ROOMS')
poi('W08','North plank crossing',wp(0,-2.05,52.6),'Warren','Cross west to short north segment of east boardwalk.',file='canal_warren.gd',needle='const B2_Z')
poi('W09','Warren fence exit',cp(-28.5,-2.1,54.7),'Warren','Second pried sheet near road bridge. Actual gate origin is W11.',file='canal_warren.gd',needle='const EXIT_Z')
for id,name,node,detail in [('W10','Entrance tin door','Warren door 06','Door hinge origin, beside W01.'),('W11','Exit tin door','Warren door 07','Door hinge origin, beside W09.'),('W12','Radio','Warren radio','Usable radio in family room.'),('W13','Family-room light switch','Warren switch','Usable tube-light switch.'),('W14','Courtyard hand pump','Warren pump','Usable pump in courtyard.')]:
    np(id,name,WARREN+'/'+node,'Warren',detail)
poi('N01','Nichols outer gate',[-12,-2.9,-60],'Nichols','Open wrought-iron gate; estate X=-40..14, Z=-124..-60.',file='nichols_property.gd',needle='const GATE :=')
poi('N02','Nichols facade origin',[-12,-1.7,-82],'Nichols','Origin of house-local Godot coordinates. Ground floor Y=-1.7; upstairs Y=2.7.',file='nichols_property.gd',needle='const HOUSE_POS')
for id,key in [('N03','porch_steps'),('N04','front_door'),('N05','stair_foot'),('N06','landing'),('N07','bridge'),('N08','mantel_parlour'),('N09','tower_top')]:
    poi(id,key.replace('_',' ').title(),nw(LAYOUT['spots'][key]),'Nichols','Translated from house layout.json spots.' ,file='game/assets/models/nichols/house/layout.json',needle='"'+key+'"')
for i,room in enumerate(LAYOUT['rooms'],1):
    a,b=room['rects'][0]
    p=nw([(a[0]+b[0])/2,room['floor'],(a[2]+b[2])/2])
    r=poi(f'NR{i:02}',room['name'].replace('_',' ').title(),p,'Nichols rooms','Room volume; see room-register.json for all rectangles, world bounds, floor and ceiling.',file='game/assets/models/nichols/house/layout.json',needle='"name": "'+room['name']+'"')
    r['room_name']=room['name']
for id,key in [('B01','nook'),('B02','landing'),('B03','shaft_foot'),('B04','cellar'),('B05','hole'),('B06','corridor'),('B07','steel_door'),('B08','cages'),('B09','tarp'),('B10','workbench'),('B11','hooks'),('B12','drain')]:
    poi(id,key.replace('_',' ').title(),nw(LAYOUT['basement']['spots'][key]),'Basement','House-local vector translated by (-12,-1.7,-82).',file='game/assets/models/nichols/house/layout.json',needle='"'+key+'"')
poi('B13','Cellar door hinge',nw(LAYOUT['basement']['door']['hinge']),'Basement','Under grand-stair landing; .78 m wide, 1.77 m high, initially 48 degrees ajar.',file='game/assets/models/nichols/house/layout.json',needle='"label": "Cellar door"')
poi('B14','Cellar light switch',nw(LAYOUT['basement']['switch']['pos']),'Basement','Turns on basement bulbs. Starts off.',file='nichols_basement.gd',needle='func _switch')
poi('B15','Chained iron door',nw(LAYOUT['basement']['secret_door']['pos']),'Basement','Terminal locked barrier; new padlock, no traversable continuation documented.',file='nichols_basement.gd',needle='func _locked_door')
poi('F01','Field-road start',[21,-2.9,54.5],'Fields','First stored road sample; begins under the north-wall exit.',file='fields_builder.gd',needle='const ROAD_POINTS')
poi('F02','Hut yard reference',FIELDS['hut'],'Fields','Metadata yard reference. Hut model origin is .15 m lower; finished hut floor is Y=-2.63.')
np('F03','Bahay kubo model','Fields/Models/BahayKubo','Fields','Runtime orientation faces the road; hut dimensions use local frame in hut_house.gd.')
np('F04','Scarecrow','Fields/Models/Scarecrow','Fields','Scarecrow islet reached from road by a dike; actor points toward viewer while unseen.')
np('F05','Buried ammunition box','Fields/AmmoBox','Fields','Initially hidden near scarecrow; scripted dig and handover sequence.')
poi('F06','Pond centre',[FIELDS['pond'][0],-3.32,FIELDS['pond'][1]],'Fields','Ellipse radii 15 m by 12.5 m. Water Y=-3.32.')
np('F07','Jetty collider centre','Fields/FieldsColliders/Jetty','Fields','Deck walking top near Y=-2.96; node origin is collider centre at Y=-3.06.')
poi('F08','Road dead end',FIELDS['road_end'],'Fields','Road ends at fallen tree and SIRADO barrier; no road beyond this point.')
poi('F09','Giant tree',FIELDS['giant_tree'],'Fields','Scenery knoll beyond the road barrier; do not infer a connected playable route.')
for id,name,path,detail in [('K01','Hut root',HUT,'Local origin at model base, Y=-3.05; local floor .42 -> world Y=-2.63.'),('K02','Brass key',HUT+'/Key','Take key before opening top dresser drawer.'),('K03','Dresser drawer',HUT+'/Dresser/TopDrawer','Drawer node; travel .3 m in hut local frame.'),('K04','Glock',HUT+'/Dresser/TopDrawer/Glock','Inside dresser drawer; scripted pickup.'),('K05','Flashlight',HUT+'/Dresser/TopDrawer/Flashlight','Inside dresser drawer; scripted pickup.')]:
    np(id,name,path,'Hut',detail)
P = {p['id']:p for p in POIS}

STREETS = [dict(id='S-A',name='Street A',axis='x',centre=18,start=-70,end=80,width=6),dict(id='S-B',name='Street B / Malasugue Street',axis='z',centre=21,start=-40,end=54.5,width=6),dict(id='S-C',name='Street C',axis='x',centre=49,start=-70,end=80,width=6),dict(id='S-D',name='Street D',axis='z',centre=-19,start=-40,end=66,width=6)]
N_PATH = [[20.6,-24],[20.2,-33],[17,-40.5],[10,-47],[1,-52.5],[-6.5,-57],[-12,-59.6]]
ROUTES = [
 dict(id='R01',name='Home to street',points=['H01','H02','H40','H41','H42','T01','T02','T03'],conditions='Open navy door; descend stairs; unlatch courtyard gate and physically open it.'),
 dict(id='R02',name='Street to canal',points=['T03','T04','T05','T08','C01','C02','C03','C04'],conditions='North along street B to street A; then follow pallet path west. Upper lane is 0.8 m above street level; descend trench stair.'),
 dict(id='R03',name='Canal to warren',points=['C04','C05','C06','C07','W01','W02','W03','W04','W05','W06','W07','W08','W09','C08'],conditions='South along low catwalk to footbridge, north on far bank, climb to tin gate; crouch under collapsed roof. Lines join landmarks schematically; follow actual boardwalks and access alleys.'),
 dict(id='R04',name='Street to fields',points=['T04','T06','T11','T09','T12','F01','F02'],conditions='Crouch through north wall opening, then follow road samples; branch onto hut footpath. POI sequence is not a straight-line route.'),
 dict(id='R05',name='Street to Nichols',points=['T04','T10','N01','N03','N04','N05'],conditions='South on street B; approach leaned sheets from east, crouch under south wall; use N_PATH spline/control polyline toward gate.'),
 dict(id='R06',name='Nichols to cellar and tunnel',points=['N04','N05','B01','B13','B02','B03','B04','B05','B06','B15'],conditions='Follow blood trail around stairs, through cellar door, down shaft, through broken cellar wall. Chained terminal door remains locked.'),
 dict(id='R07',name='Field branches',points=['F02','F04','F06','F07','F08'],conditions='Return to road between branches; use hut route_in and crow_route from runtime. Road edges have invisible collision; paddy extent is scenery, not a free-roam plane.')]

def write_json(name, data):
    (OUT/name).write_text(json.dumps(data,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')

ROOMS=[]
for i,room in enumerate(LAYOUT['rooms'],1):
    r=dict(room,id=f'NR{i:02}',world_floor=room['floor']-1.7,world_ceiling=room['ceiling']-1.7)
    r['world_boxes']=[dict(min=[min(nw(a)[k],nw(b)[k]) for k in range(3)],max=[max(nw(a)[k],nw(b)[k]) for k in range(3)]) for a,b in room['rects']]
    ROOMS.append(r)
for i,room in enumerate(LAYOUT['basement']['rooms'],1):
    a,b=nw(room['lo']),nw(room['hi'])
    ROOMS.append(dict(id=f'BR{i:02}',name=room['name'],world_floor=min(a[1],b[1]),world_ceiling=max(a[1],b[1]),world_boxes=[dict(min=[min(a[k],b[k]) for k in range(3)],max=[max(a[k],b[k]) for k in range(3)])]))
write_json('location-register.json',POIS)
write_json('room-register.json',ROOMS)
write_json('routes.json',dict(streets=STREETS,routes=ROUTES,courtyard_to_streets_test_waypoints=[[13.6,-2.9,3.9],[17,-2.9,4.6],[21.4,-2.9,6],[21.4,-2.9,18.6],[10,-2.9,18],[-5,-2.9,18]],nichols_approach_xz=N_PATH,field_road_samples_xz=ROAD,hut_route_in=BY_PATH[HUT]['route_in'],scarecrow_route=BY_PATH[HUT]['crow_route'],basement_blood_trail_world=[nw(p) for p in LAYOUT['basement']['trail']]))
shutil.copy2(ROOT/'game/assets/models/nichols/house/layout.json',OUT/'nichols-layout-source.json')
shutil.copy2(ROOT/'game/assets/room_manifest.json',OUT/'room-manifest-source.json')

with (OUT/'locations.csv').open('w',newline='',encoding='utf-8-sig') as f:
    w=csv.writer(f); w.writerow(['id','name','area','x_m','y_m','z_m','evidence','node_path','node_id','detail'])
    for p in POIS: w.writerow([p['id'],p['name'],p['area'],*p['position'],p['evidence'],p['node_path'],p.get('node_id',''),p['detail']])
with (OUT/'scene-nodes.csv').open('w',newline='',encoding='utf-8-sig') as f:
    w=csv.writer(f);w.writerow(['id','path','type','x','y','z','script','groups','disabled','bounds_min','bounds_max'])
    for n in NODES:
        b=n.get('collision_bounds',n.get('mesh_bounds',{}))
        w.writerow([n['id'],n['path'],n['type'],*n.get('position',['','','']),n.get('script',''),' / '.join(n.get('groups',[])),n.get('disabled',''),b.get('min',''),b.get('max','')])
INTERACTIONS=[n for n in NODES if n.get('script') and any(s in n['script'] for s in ['push_gate.gd','hinged_door.gd','sliding_door.gd','locked_room_door.gd','nichols_door.gd','nichols_locked.gd','neighborhood_usable.gd','warren_door.gd','warren_usable.gd','hut_usable.gd'])]
write_json('interactions.json',INTERACTIONS)
interaction_doc=['# Interactive objects and neighboring buildings\n\nThis is the startup inventory. Coordinates are node origins; a gate root may be an abstract (0,0,0) assembly with displaced leaf children. Use leaf transforms and collision bounds before placing the player. `I` and `HOUSE` IDs below are additional documentation labels, not gameplay keys.\n\n## Doors, gates, switches and other usable nodes\n\n']
for i,n in enumerate(INTERACTIONS,1):
    n['reference_id']=f'I{i:03}'
interaction_doc.append('| Reference | Name / world origin | Script / properties / path |\n| --- | --- | --- |\n')
for n in INTERACTIONS:
    pos='('+', '.join(str(x) for x in n.get('position',[]))+')'
    interaction_doc.append('| '+n['reference_id']+' / '+n['id']+' | '+n['name']+' '+pos+' | `'+n.get('script','')+'` '+json.dumps(n.get('gameplay',{}),ensure_ascii=False)+' — `'+n['path']+'` |\n')
interaction_doc.append('\n## Original neighboring house collision blocks\n\nThese are façade/house-shell collider envelopes from the baked neighborhood. They do not establish implemented interiors. The register includes scenery shells outside the sheet-iron perimeter.\n\n| Reference | Node | World min (X,Y,Z) | World max (X,Y,Z) |\n| --- | --- | --- | --- |\n')
buildings=[n for n in NODES if n['path'].startswith(TOWN+'/NeighbourhoodColliders/House') and 'collision_bounds' in n]
for i,n in enumerate(buildings,1):
    interaction_doc.append('| HOUSE'+f'{i:02}'+' | `'+n['path']+'` | '+str(n['collision_bounds']['min'])+' | '+str(n['collision_bounds']['max'])+' |\n')
(OUT/'interactive-register.md').write_text(''.join(interaction_doc),encoding='utf-8')
write_json('interactions.json',INTERACTIONS)
write_json('neighboring-buildings.json',buildings)

# Maps are engineering diagrams drawn from coordinates and actual collision envelopes.
# They are not screenshots, a mesh export, or a promise of navigation clearance.
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':11,'svg.fonttype':'none'})
INK='#18364b'; BLUE='#45718a'; ORANGE='#b86a22'; WATER='#c7e4ec'; FLOOR='#e9edf0'
VIEWS=[]

def rect(ax,x0,z0,x1,z1,color,edge=None,alpha=1,lw=1,**kw):
    ax.add_patch(Rectangle((x0,z0),x1-x0,z1-z0,facecolor=color,edgecolor=edge or color,alpha=alpha,linewidth=lw,**kw))

def curve(ax,pts,color,lw=2,**kw):
    ax.plot([q[0] for q in pts],[q[1] for q in pts],color=color,lw=lw,**kw)

def band(ax,pts,half,color,alpha=1):
    left=[];right=[]
    for i,q in enumerate(pts):
        a=pts[max(0,i-1)];b=pts[min(len(pts)-1,i+1)]
        dx=b[0]-a[0];dz=b[1]-a[1];l=math.hypot(dx,dz) or 1
        left.append([q[0]-dz/l*half,q[1]+dx/l*half]);right.append([q[0]+dz/l*half,q[1]-dx/l*half])
    ax.add_patch(Polygon(left+right[::-1],facecolor=color,edgecolor='none',alpha=alpha))

def streets(ax):
    for s in STREETS:
        if s['axis']=='x':
            rect(ax,s['start'],s['centre']-3,s['end'],s['centre']+3,'#d9e0e4')
            rect(ax,s['start'],s['centre']-2,s['end'],s['centre']+2,'#b7c2cb')
        else:
            rect(ax,s['centre']-3,s['start'],s['centre']+3,s['end'],'#d9e0e4')
            rect(ax,s['centre']-2,s['start'],s['centre']+2,s['end'],'#b7c2cb')

def town_walls(ax):
    for a,b in [([-23.85,-18.55],[18.9,-18.55]),([19.8,-18.55],[25.8,-18.55]),([25.8,-18.55],[25.8,54.8]),([-23.85,54.8],[20.845,54.8]),([21.795,54.8],[25.8,54.8]),([-23.85,-18.55],[-23.85,15.15]),([-23.85,20.85],[-23.85,54.8]),([-23.85,8.95],[-7.6,8.95])]:
        curve(ax,[a,b],ORANGE,2.2,zorder=7)

def canal_base(ax,warren=True):
    zs=[-16+i*.5 for i in range(173)]
    ax.add_patch(Polygon([[rx(z)-5,z] for z in zs]+[[rx(z)+3.9,z] for z in zs[::-1]],facecolor=WATER,edgecolor='#76b3c4',lw=.6))
    curve(ax,[[rx(z)+4.65,z] for z in zs if z<=50],BLUE,2)
    curve(ax,[[rx(z)-7,z] for z in zs], '#5f8b67',2)
    curve(ax,[[rx(z)+14.5,z] for z in zs], '#b9aa8a',2)
    if warren:
        zz=[-15.6+i*.4 for i in range(186)]
        ax.add_patch(Polygon([[rx(z)+ec(z)-1.25,z] for z in zz]+[[rx(z)+ec(z)+1.25,z] for z in zz[::-1]],facecolor='#98bbc9',edgecolor='none'))
        for d,za,zb in [(1.65,-11.9,9.2),(1.65,51.6,55.8),(-1.65,-11.9,53.5)]:
            band(ax,[[wp(d,0,z)[0],z] for z in [za+i*.25 for i in range(int((zb-za)/.25)+1)]],.8,'#d4b894')
        for z in [-11,52.6]: curve(ax,[[wp(-2.45,0,z)[0],z],[wp(2.45,0,z)[0],z]],'#b99565',3)

def collisions(ax,extent,prefix='',cut_y=None,area_max=800):
    patches=[];colors=[]
    for n in NODES:
        if n.get('disabled') or 'collision_bounds' not in n or not n['path'].startswith(prefix): continue
        b=n['collision_bounds'];lo=b['min'];hi=b['max']
        if hi[0]<extent[0] or lo[0]>extent[1] or hi[2]<extent[2] or lo[2]>extent[3]:continue
        if cut_y is not None and not lo[1]<=cut_y<=hi[1]:continue
        if n['shape']=='ConcavePolygonShape3D': continue
        if (hi[0]-lo[0])*(hi[2]-lo[2])>area_max:continue
        if n['path'].startswith(('Player','@')) or 'ARCH' in n['name']:continue
        points=b['projected_points_xz']
        # Clip envelopes to the requested region (important for mixed-height home inset layers).
        for dim,bound,greater in [(0,extent[0],True),(0,extent[1],False),(1,extent[2],True),(1,extent[3],False)]:
            output=[]
            if not points: break
            previous=points[-1]
            pin=previous[dim]>=bound if greater else previous[dim]<=bound
            for point in points:
                inside=point[dim]>=bound if greater else point[dim]<=bound
                if inside != pin:
                    t=(bound-previous[dim])/(point[dim]-previous[dim])
                    output.append([previous[k]+t*(point[k]-previous[k]) for k in range(2)])
                if inside:output.append(point)
                previous=point;pin=inside
            points=output
        if len(points)<3:continue
        patches.append(Polygon(points,closed=True))
        moving=any(x in n['path'] for x in ['/Gate ','/CourtyardGate/','/EntryDoor/','/StudioDoor/'])
        colors.append('#ce975a' if moving else '#7899ad')
    ax.add_collection(PatchCollection(patches,facecolor=colors,edgecolor='#385c73',lw=.3,alpha=.64,zorder=4))

def home_floor(ax):
    rect(ax,-3.3,-2.7,3.3,2.7,'#ece7df',INK,lw=.8)
    rect(ax,-5.65,-2.7,-3.3,2.7,'#e3e3d9',INK,lw=.8)
    rect(ax,-5.65,2.9,-1.25,7.3,'#dce5ee',INK,lw=.8)
    rect(ax,.95,2.9,5.6,4.55,'#e5e6e3',INK,lw=.8)
    rect(ax,5.6,2.9,9.92,3.85,'#ded6c6',INK,lw=.8)
    rect(ax,9.65,2.9,12.6,5.3,'#ded6c6',INK,lw=.8)
    for i in range(17):curve(ax,[[5.6+i*.27,2.9],[5.6+i*.27,3.85]],'#9e927b',.6)

def room_polygons(ax,level):
    colors=['#dce6ed','#e7e0d2','#dbe8df','#eee3d7']
    for i,r in enumerate(ROOMS):
        if level=='base': take=r['id'].startswith('BR')
        else: take=r['id'].startswith('NR') and abs(r['world_floor']-level)<.1
        if not take:continue
        for b in r['world_boxes']:
            a,c=b['min'],b['max'];rect(ax,a[0],a[2],c[0],c[2],colors[i%4],INK,lw=.7)
    if level=='base':
        trail=[nw(q) for q in LAYOUT['basement']['trail']]
        curve(ax,[[q[0],q[2]] for q in trail],'#a34743',1.5,ls='--',zorder=6)

def plan(name,title,extent,ids,detail,draw=None,prefix=None,cut_y=None,grid=10,ratio=None):
    width=extent[1]-extent[0];height=extent[3]-extent[2]
    aspect=height/width
    fig=plt.figure(figsize=(16,max(10,min(24,12*aspect+1.7))),facecolor='#f6f8fa')
    ax=fig.add_axes([.07,.09,.63,.81]); side=fig.add_axes([.735,.09,.25,.81]);side.axis('off')
    ax.set_facecolor('#f9fbfc');ax.set_xlim(extent[:2]);ax.set_ylim(extent[2:]);ax.set_aspect('equal',adjustable='box')
    if draw:draw(ax)
    if prefix is not None:collisions(ax,extent,prefix,cut_y)
    ax.set_xticks(range(math.ceil(extent[0]/grid)*grid,math.floor(extent[1]/grid)*grid+1,grid))
    ax.set_yticks(range(math.ceil(extent[2]/grid)*grid,math.floor(extent[3]/grid)*grid+1,grid))
    ax.grid(color='#bacbd6',alpha=.45,lw=.6);ax.tick_params(labelsize=9)
    ax.set_xlabel('World X (m) — east →',color=INK);ax.set_ylabel('World Z (m) — north ↑',color=INK)
    fig.canvas.draw()
    renderer=fig.canvas.get_renderer()
    label_boxes=[]
    candidates=[(6,6),(6,-14),(-35,8),(-35,-14),(12,22),(12,-27),(-40,25),(-40,-28),(38,10),(38,-12),(-65,8),(18,40),(18,-42)]
    for j,id in enumerate(ids):
        p=P[id];x,y,z=p['position']
        ax.scatter([x],[z],s=24,facecolor='#fcf6e9',edgecolor='#ad5a17',linewidth=.9,zorder=10)
        # Choose a readable callout position and add a leader when points are close.
        annotation=ax.annotate(id,(x,z),xytext=(6,6),textcoords='offset points',fontsize=9,fontweight='bold',color='#87410b',bbox=dict(boxstyle='round,pad=.14',fc='white',ec='none',alpha=.9),zorder=11,
                               arrowprops=dict(arrowstyle='-',color='#aa754b',lw=.55,shrinkA=2,shrinkB=3))
        best=None
        for offset in candidates:
            annotation.set_position(offset)
            box=annotation.get_window_extent(renderer).expanded(1.06,1.14)
            # Annotation bbox includes its leader, so use just the text patch.
            annotation.update_bbox_position_size(renderer)
            box=annotation.get_bbox_patch().get_window_extent(renderer).expanded(1.08,1.12)
            if not any(box.overlaps(old) for old in label_boxes):best=box;break
        label_boxes.append(best or box)
    fig.text(.07,.955,title,fontsize=22,fontweight='bold',color=INK)
    fig.text(.07,.923,detail,fontsize=10,color='#455d6d')
    side.text(0,1,'Reference points',va='top',fontsize=14,fontweight='bold',color=INK)
    cursor=.956
    line_step=min(.054,.77/max(1,len(ids)))
    for id in ids:
        p=P[id]
        side.text(0,cursor,id+'  '+p['name'],fontsize=10.5,fontweight='bold',va='top',color=INK,wrap=True)
        side.text(0,cursor-line_step*.40,'  X {:.2f}   Y {:.2f}   Z {:.2f}'.format(*p['position']),fontsize=9,va='top',color='#4d6472')
        cursor-=line_step
    side.text(0,.02,'North = +Z. All dimensions in metres.\nPoint positions can be hinges or object origins.\nSee location register for their exact meaning.',fontsize=9,color='#4d6472',va='bottom')
    fig.text(.07,.035,'Sleep • map reference • current working source, 2026-11-10 | Shaded solids are projected collision envelopes; routes and area fills are annotated.',fontsize=9,color='#4d6472')
    fig.savefig(OUT/(name+'.png'),dpi=170)
    fig.savefig(OUT/(name+'.svg'))
    plt.close(fig); VIEWS.append(dict(file=name,title=title,detail=detail,ids=ids))

def draw_world(ax):
    rect(ax,-150,66,180,640,'#e3eff0','#a5c6ca',lw=.7)
    streets(ax);canal_base(ax);town_walls(ax)
    band(ax,ROAD,3.2,'#d6c6a7');curve(ax,ROAD,'#aa8e66',1)
    band(ax,N_PATH,1.8,'#d6c6a7');rect(ax,-40,-124,14,-60,'#e2e8df','#728474')
    home_floor(ax);rect(ax,-25,-102,1,-82,'#a6bbca',INK)
    pond=FIELDS['pond'];ax.add_patch(Ellipse((pond[0],pond[1]),pond[2]*2,pond[3]*2,facecolor='#83b8cc',edgecolor=BLUE))
    for label,x,z in [('Town',-4,35),('Canal',-60,33),('Warren',-110,34),('Rice-field scenery',-65,390),('Nichols',-12,-115)]:ax.text(x,z,label,fontsize=10,color=INK,ha='center')

plan('01-world','01 • Entire world and main connections',[-160,190,-140,660],['H01','T08','T09','T10','N01','W01','F02','F04','F06','F08','F09'],'World extent reference; the field rectangle includes scenery outside the walkable road corridor.',draw_world,grid=50)
def draw_town(ax):
    streets(ax);home_floor(ax);town_walls(ax)
    curve(ax,[[12.6,4.11],[13.6,3.9],[17,4.6],[21.4,6],[21.4,18.6]],'#52836c',2,zorder=6)
    curve(ax,[[16.6,18.15],[-23.2,18.15]],'#c99742',3,zorder=6)
plan('02-town','02 • Street block and its three exits',[-30,38,-25,64],['T01','T02','T03','T04','T05','T06','T07','T08','T09','T10','T11'],'Street level Y=-2.9; collision slice Y=-1.8. Orange lines mark the sheet-iron perimeter.',draw_town,TOWN,-1.8,grid=10)
def draw_home(ax):
    home_floor(ax)
    extent=[-6.5,14,-3.5,8.5]
    collisions(ax,extent,'Studio',.7)
    collisions(ax,[.95,13,2.8,5.5],'Balcony',.7)
    collisions(ax,[9.65,13,2.8,5.5],'Balcony',-1.8)
plan('03-home','03 • Living room, kitchen, studio and balcony',[-6.5,14,-3.5,8.5],['H01','H02','H03','H04','H05','H10','H11','H12','H13','H18','H20','H21','H30','H31','H40','H41','H42','T01'],'Indoor collision slice Y=.70. Stair and courtyard are shown at their own floor elevations.',draw_home,'LivingRoom',.7,grid=2)
plan('04-canal','04 • Canal settlement and both crossings',[-96,-27,-20,74],['C01','C02','C03','C04','C05','C06','C07','C08','C09','C10','W01','W09'],'Upper lane Y=-2.10; catwalk -4.40; far path -5.45; water -6.00. Solids sliced at Y=-1.25.',canal_base,CANAL,-1.25,grid=10)
plan('05-warren','05 • Hidden warren and through-room sequence',[-124,-88,-18,62],['W01','W02','W03','W04','W05','W06','W07','W08','W09','W10','W11','W12','W13','W14'],'Deck Y=-2.05. Solids sliced at Y=-1.20; the collapsed roof requires crouching.',canal_base,CANAL,-1.2,grid=5)
def draw_estate(ax):
    rect(ax,-40,-124,14,-60,'#e6ebe1','#7b8f74');band(ax,N_PATH,1.8,'#d1c4a6');room_polygons(ax,-1.7)
plan('06-nichols-grounds','06 • Nichols approach and grounds',[-48,28,-132,-16],['T10','N01','N02','N03','N04','N08','N09'],'Estate fence X=-40..14, Z=-124..-60; path control polyline from street B shown.',draw_estate,NICHOLS,-1.0,grid=10)
plan('07-nichols-ground','07 • Nichols ground floor',[-27,3,-105,-74],['N03','N04','N05','N06','N08','NR01','NR02','NR03','NR04','NR05','NR06','NR07','NR08','B01','B13','B14'],'Floor Y=-1.70; collision slice Y=-.70. Room IDs correspond to exact world boxes in room-register.json.',lambda ax:room_polygons(ax,-1.7),NICHOLS,-.7,grid=5)
plan('08-nichols-upper','08 • Nichols upper floor',[-27,3,-104,-79],['N07','NR09','NR10','NR11','NR12','NR13','NR14','NR15','NR16'],'Upper floor Y=2.70; collision slice Y=3.70. Sealed rooms are volumes, not confirmed playable rooms.',lambda ax:room_polygons(ax,2.7),NICHOLS,3.7,grid=5)
plan('09-basement','09 • Nichols cellar, stair shaft and tunnel',[-26,3,-104,-88],['B01','B02','B03','B04','B05','B06','B07','B08','B09','B10','B11','B12','B13','B14','B15'],'Cellar floor Y=-4.40; tunnel floor Y=-5.30. Dashed red line is the authored blood-trail sequence.',lambda ax:room_polygons(ax,'base'),None,grid=5)
def draw_fields(ax):
    rect(ax,-4,60,90,555,'#e6eff0');band(ax,ROAD,3.2,'#d3c2a2');curve(ax,ROAD,'#9c835e',1)
    pond=FIELDS['pond'];ax.add_patch(Ellipse((pond[0],pond[1]),pond[2]*2,pond[3]*2,facecolor=WATER,edgecolor=BLUE))
    for points in [BY_PATH[HUT]['route_in'],BY_PATH[HUT]['crow_route']]:curve(ax,[[q[0],q[2]] for q in points],'#618467',2)
    rect(ax,FIELDS['hut'][0]-6.6,FIELDS['hut'][2]-6.6,FIELDS['hut'][0]+6.6,FIELDS['hut'][2]+6.6,'#e5dbbf','#a99a76',alpha=.6)
plan('10-fields','10 • Field road and playable branches',[0,88,48,560],['T09','F01','F02','F03','F04','F05','F06','F07','F08','F09'],'Baked sampled road length: {:.1f} m. Road half-width 2.05 m; walking band half-width 3.20 m.'.format(FIELDS['fields_stats']['road_m']),draw_fields,grid=25)
hutpos=P['K01']['position'];hx,hz=hutpos[0],hutpos[2]
def draw_hut(ax):
    curve(ax,[[q[0],q[2]] for q in BY_PATH[HUT]['route_in']],'#789d78',2)
plan('11-hut','11 • Hut floor, dresser and pickups',[hx-3,hx+3,hz-3,hz+3],['K01','K02','K03','K04','K05'],'Hut floor Y=-2.63; collision slice Y=-1.95. Model and runtime root share a rotated local frame.',draw_hut,HUT,-1.95,grid=1)
AUDIT=json.loads((OUT/'reachability/audit.json').read_text())
def draw_reach(ax):
    image=Image.open(OUT/'reachability/reach.png')
    # Raw audit row 0 is minimum Z. origin='lower' keeps +Z at the top.
    ax.imshow(image,origin='lower',extent=[-130,60,-136,64],interpolation='nearest',alpha=.9)
plan('12-reachability','12 • Current collision-audit reachability',[-130,60,-136,64],['T02','T04','T09','C01','C04','W01','N01','N03'],'0.75 m grid from T02; ignores loose props and movable gates. Blue = crouch-only; warm colors = greater clearance.',draw_reach,grid=20)
plan('13-living-room','13 • Living-room and kitchen detail',[-6.1,4.6,-3.15,3.2],['H01','H02','H04','H05','H10','H11','H12','H13','H14','H15','H16','H17','H18','H19','H20','H21','H22','H23','H24'],'Collision slice Y=.70. Named prop origins include items above or below this cut height.',home_floor,'LivingRoom',.7,grid=1)
plan('14-studio','14 • Studio furniture and instruments',[-5.95,-.95,2.6,7.6],['H03','H30','H31','H32','H33','H34','H35','H36','H37','H38'],'Floor Y=0; collision slice Y=.70. Guitar and elevated-synth references mark their model origins.',home_floor,'Studio',.7,grid=1)
fig,axes=plt.subplots(1,3,figsize=(18,9),facecolor='#f6f8fa')
for ax in axes:
    ax.set_xlim(0,10);ax.set_ylim(-7,5);ax.set_xticks([]);ax.set_ylabel('World Y (m)');ax.grid(axis='y',alpha=.3)
def height(ax,x0,x1,y,label,color=BLUE):
    ax.plot([x0,x1],[y,y],lw=4,color=color)
    ax.text((x0+x1)/2,y+.14,label+'\nY='+str(y),ha='center',va='bottom',fontsize=10)
height(axes[0],.5,5,0,'Room / studio / balcony');height(axes[0],6,9.5,-2.9,'Courtyard / street')
axes[0].plot([5,6],[0,-2.9],color=ORANGE,lw=3);axes[0].set_title('Home → street',fontsize=15)
height(axes[1],.3,3,-2.1,'Upper lane');height(axes[1],3.4,5.7,-4.4,'Catwalk');height(axes[1],6.3,9.5,-5.45,'Far path')
axes[1].axhline(-6,color='#82b1c4',lw=2,ls='--');axes[1].text(.5,-6.4,'River water Y=-6.0',fontsize=10)
axes[1].plot([3,3.4],[-2.1,-4.4],color=ORANGE,lw=2);axes[1].plot([5.7,6.3],[-4.4,-5.45],color=ORANGE,lw=2);axes[1].set_title('Canal levels',fontsize=15)
height(axes[2],.6,4.5,2.7,'Upper floor');height(axes[2],.6,4.5,-1.7,'Ground floor');height(axes[2],4.8,7,-4.4,'Cellar');height(axes[2],7.4,9.5,-5.3,'Tunnel')
axes[2].plot([4.5,4.8],[-1.7,-4.4],color=ORANGE,lw=2);axes[2].plot([7,7.4],[-4.4,-5.3],color=ORANGE,lw=2);axes[2].set_title('Nichols occupied levels',fontsize=15)
fig.suptitle('15 • Vertical connections and floor elevations',fontsize=22,fontweight='bold',color=INK)
fig.text(.08,.045,'Diagram only: horizontal distances are not to scale. Heights use world Y. The far-bank path climbs north to the -2.10 m road bridge.',fontsize=11)
fig.subplots_adjust(top=.87,bottom=.12,wspace=.3)
fig.savefig(OUT/'15-elevations.png',dpi=170);fig.savefig(OUT/'15-elevations.svg');plt.close(fig)
VIEWS.append(dict(file='15-elevations',title='15 • Vertical connections and floor elevations',detail='World heights to scale; horizontal placement is schematic.',ids=[]))
contact=Image.new('RGB',(1500,560*math.ceil(len(VIEWS)/3)),'#dce3e8')
contact_draw=ImageDraw.Draw(contact)
for i,view in enumerate(VIEWS):
    thumb=Image.open(OUT/(view['file']+'.png')).convert('RGB')
    thumb.thumbnail((480,520))
    x=(i%3)*500+(500-thumb.width)//2;y=(i//3)*560
    contact.paste(thumb,(x,y+25))
    contact_draw.text(((i%3)*500+10,y+5),view['file'],fill=INK)
contact.save(OUT/'contact-sheet.png')
write_json('map-index.json',VIEWS)

# An exhaustive source index supplements human-written descriptions.
SOURCES=['interior.gd','room_builder.gd','room_surroundings.gd','room_furnishings.gd','balcony_builder.gd','balcony.gd','studio_builder.gd','studio.gd','neighborhood_builder.gd','neighborhood.gd','neighborhood_interactions.gd','neighborhood_usable.gd','neighborhood_encounters.gd','street_dressing.gd','town_siege.gd','town_horror.gd','canal_settlement.gd','canal_warren.gd','warren_door.gd','warren_usable.gd','nichols_property.gd','nichols_basement.gd','nichols_door.gd','nichols_locked.gd','fields_builder.gd','fields.gd','hut_house.gd','hut_usable.gd','stranger.gd','story.gd','player.gd','debug_menu.gd']
src=['# Source index\n\nGenerated from the current working files. Line numbers are for this snapshot; hashes identify it.\n']
source_data=[]
for name in SOURCES:
    file=ROOT/'game/scripts'/name;raw=file.read_bytes();lines=raw.decode('utf-8-sig').splitlines();h=hashlib.sha256(raw).hexdigest()
    src.append(f'## game/scripts/{name}\n\nSHA-256: `{h}`\n\n')
    declarations=[]
    for i,line in enumerate(lines,1):
        if re.match(r'^(?:static )?func |^const ',line):
            declarations.append({'line':i,'declaration':line})
            src.append(f'- L{i}: `{line.replace("`", "")}`\n')
    source_data.append(dict(file='game/scripts/'+name,sha256=h,declarations=declarations))
(OUT/'source-index.md').write_text(''.join(src),encoding='utf-8')
write_json('source-index.json',source_data)

def fmtpos(p): return '('+', '.join(f'{x:.3f}'.rstrip('0').rstrip('.') for x in p)+')'
def table(headers, rows):
    return '| '+' | '.join(headers)+' |\n| '+' | '.join('---' for _ in headers)+' |\n'+''.join('| '+' | '.join(str(c).replace('|',' / ').replace('\n',' ') for c in row)+' |\n' for row in rows)+'\n'
def srclink(p):
    if 'source' not in p:return ''
    s=p['source'];return f"`{s['file']}:{s['line']}`"

register=['# Location register\n\nEvery position is world `(X,Y,Z)` in metres. A reference point is not necessarily a safe teleport target. Positions on doors usually mean hinges; positions on objects mean node origins. Runtime values are a startup snapshot, not an immutable authored placement.\n\n']
for area in dict.fromkeys(p['area'] for p in POIS):
    register.append('## '+area+'\n\n')
    register.append(table(['ID / name','World position','Meaning / source'],[(p['id']+' '+p['name'],fmtpos(p['position']),p['detail']+' '+srclink(p)) for p in POIS if p['area']==area]))
    for p in POIS:
        if p['area']==area and p['node_path']:register.append(f"- **{p['id']}** → `{p['node_path']}`"+(f" — `{p['node_id']}`" if 'node_id' in p else '')+'\n')
    register.append('\n')
(OUT/'location-register.md').write_text(''.join(register),encoding='utf-8')

roomsdoc=['# Room dimensions and door states\n\nNichols world origin is `(-12,-1.7,-82)`. All vectors in the copied layout JSON are already Godot Y-up vectors; **add the origin without flipping Z again**. Only `nichols_property.gd:local(x,depth,up)` accepts positive depth and converts it to negative Z.\n\n']
roomsdoc.append(table(['Room ID','Room','World floor / ceiling','World X range','World Z range'],[(r['id'],r['name'],f"{r['world_floor']:.2f} / {r['world_ceiling']:.2f}",', '.join(f"{b['min'][0]:.2f}..{b['max'][0]:.2f}" for b in r['world_boxes']),', '.join(f"{b['min'][2]:.2f}..{b['max'][2]:.2f}" for b in r['world_boxes'])) for r in ROOMS]))
roomsdoc.append('## Authored interior door states\n\nThese are initial source states. Opening or moving a leaf changes the runtime geometry. The front double door, cellar door and terminal chained door have separate setup code.\n\n')
roomsdoc.append(table(['Door','World hinge','Width / height','Initial state'],[(d['label'],fmtpos(nw(d['hinge'])),f"{d['width']} / {d['height']}",f"{d['state']}, {d['angle']} degrees") for d in LAYOUT['doors']]))
roomsdoc.append('## House room volumes and access\n\nThe eight ground-floor volumes include a narrow closet volume under/behind the grand stair. Upstairs, the front bridge and narrow galleries overlook the foyer. The `sealed` upstairs volume is intentionally classified separately: its presence in the model does not establish player access. `BR01 shaft` overlaps ground-floor height because it encloses the stair shaft. The cellar and corridor floors differ by .9 m; their connecting broken passage descends between them.\n\n## Exterior and home dimensions\n\n')
roomsdoc.append(table(['Feature','Bounds / dimensions','Vertical reference'],[
('Main living room','Interior approximately X=-3.3..3.3, Z=-2.7..2.7','Floor near 0; ceiling near 2.9'),('Kitchen','X=-5.65..-3.3, Z=-2.7..2.7','Floor 0'),('Studio','X=-5.65..-1.25, Z=2.9..7.3 (4.4 × 4.4)','Floor 0; ceiling 2.9'),('Balcony','X=.95..5.6, Z=2.9..4.55; outer parapet 4.75','Floor 0; ceiling 2.75'),('Stair','16 risers, .18125 m rise, .27 m tread; Z=2.9..3.85','0 down to -2.9'),('Courtyard','X=9.65..12.6, Z=2.9..5.3','Floor -2.9'),('Hut interior in local frame','X=-1.734..1.695, Z=-1.64..1.691','Local floor .42; world floor -2.63'),('Hut doorway','Local +X wall, local Z=-.62...02; top 2.3','Local, rotated with hut'),('Field road','4.1 m road width, approximately 6.4 m walking band','Ground -2.9'),('Concrete canal bridge','23 m across, 4.4 m along Z','Deck -2.1'),('Plank canal bridge','1.15 m wide','East -4.4 to west -5.45'),('Warren crossings','4.9 m nominal span, 1 m wide','Deck -2.05')]))
(OUT/'room-dimensions.md').write_text(''.join(roomsdoc),encoding='utf-8')

area_guide='''# Area guide and route constraints

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
'''
(OUT/'area-guide.md').write_text(area_guide,encoding='utf-8')

root_counts=collections.Counter(n['type'] for n in NODES)
AUDIT_SUMMARY=table(['Checked landmark','Approximate grid route from T02 (m)'],AUDIT['keys'].items())
readme=f'''# Sleep / Interior — full map handoff

Prepared 2026-11-10 from the **current working source**, including uncommitted content. This is a documentation export; no game scene, gameplay script or executable was rebuilt. The export contains {len(NODES):,} runtime nodes, {root_counts['CollisionShape3D']:,} collision shapes and {len(POIS)} named editing references. Story and hidden-route spoilers follow.

## Start here

1. Open **atlas.html** for the image gallery, location lookup and searchable runtime-node inventory. It works offline and contains its data inline.
2. Read **area-guide.md** for the complete area-by-area layout, connections, heights, hidden routes and gameplay meaning.
3. Use **location-register.md / locations.csv / location-register.json** for reference IDs, world coordinates, source locations and actual scene paths.
4. Use **room-dimensions.md / room-register.json** for every Nichols room, cellar/tunnel volume and initial door state.
5. Use **routes.json** for real field-road samples, hut/scarecrow paths, the Nichols approach polyline and authored blood trail. The high-level route graph is descriptive; do not treat point-to-point straight lines as navigation.
6. Use **runtime-scene.json / scene-nodes.csv / interactions.json** for the complete startup hierarchy and editable object references. **interactive-register.md** adds I### references for every usable node and HOUSE## references for the original neighboring shell colliders.

## Map sheets

'''+table(['Sheet','Contents'],[(f"[{v['file']}.png]({v['file']}.png)",v['title']) for v in VIEWS])+'''
Each sheet is supplied as PNG and SVG. SVG preserves text and scales cleanly. Blue-grey solids are collision envelopes, warm brown marks gates/route structures, pale blue is water, and labels match the location register. Plan slice heights are printed on each relevant sheet. The world sheet and field sheet include scenery beyond playable space.

## Coordinate contract

- All handoff coordinates are **Godot world metres**, written **(X, Y, Z)**. X increases east, Y up, Z north by this project's convention. North is up on every sheet.
- Living-room floor is approximately Y=0. Street/courtyard ground is -2.9. Canal upper bank is -2.1, catwalk -4.4, far-bank path -5.45. Nichols boards are -1.7, upstairs 2.7, cellar -4.4 and tunnel -5.3. Hut floor is -2.63.
- `room/room-layout.json` is historical Blender Z-up input. Do not copy its vectors into Godot unchanged. `game/assets/room_manifest.json` is already Godot Y-up but some of its original shell colliders are replaced by room_surroundings.gd. The baked room plus runtime inventory is the current reference.
- The Nichols copied layout is **already house-local Godot Y-up**. World = local vector + (-12,-1.7,-82). Its `local(x, depth, up)` script helper instead accepts positive depth and uses world Z=-82-depth. Do not mix those representations.
- Canal placement uses `X=rx(Z)+U`; warren placement uses `X=rx(Z)+ec(Z)+D`. Their formulas and heights are documented in area-guide.md.
- A node position can be a hinge, model base, light location, collider centre or abstract root. Never assume it is an empty standing position. The reference register explains each point.

## IDs and paths

`H` = home, `T` = town, `C` = canal, `W` = warren, `N` = Nichols grounds/landmarks, `NR` = mansion room, `BR` = basement room volume, `B` = basement landmark, `F` = fields and `K` = hut. These are **documentation IDs introduced by this handoff**. They are not pre-existing gameplay keys and have not been inserted into the game.

Every runtime node also has `N-` followed by the first 12 hexadecimal characters of SHA-256 of its root-relative path. The same named path keeps its hash; renamed or autogenerated `@Node@` paths can change. The path is the actual editing reference. A full path is `/root/Interior/` plus the relative path, except the root record itself. Root nodes, group names, source class names and physics layers are separate namespaces.

## Actual root hierarchy and ownership

```text
Interior                       game/main.tscn; script interior.gd
├─ LivingRoom                  baked scenes/room/living_room.tscn
│  ├─ [original named props]    physical assemblies, decor, animal attachments
│  ├─ ReferenceRoomSurroundings kitchen, revised walls, navy entry door
│  └─ LockedClosetDoor
├─ Balcony                     baked scenes/balcony/balcony.tscn
│  ├─ BalconyStructure / CourtyardGate
│  └─ Neighbourhood            baked original roads, lots, shells, trees
│     ├─ NeighbourhoodColliders
│     ├─ Canal settlement      runtime canal_settlement.gd
│     │  ├─ Canal surfaces     shared collision for canal and warren
│     │  └─ Canal warren       runtime canal_warren.gd
│     ├─ Nichols property      runtime nichols_property.gd
│     │  └─ Nichols basement   runtime nichols_basement.gd
│     ├─ Town siege            runtime town_siege.gd
│     │  └─ Town horror        runtime town_horror.gd
│     └─ Neighborhood interactions (American spelling)
├─ Studio                      baked scenes/studio/studio.tscn
│  └─ StudioDoor
├─ Fields                      baked scenes/fields/fields.tscn
│  ├─ Models/BahayKubo, Scarecrow
│  ├─ FieldsColliders           road/verge/jetty/boundaries
│  ├─ HutHouse                  runtime hut_house.gd
│  └─ AmmoBox
├─ Player                      runtime player.gd
├─ Stranger                    runtime story actor
└─ Story and UI/audio/atmosphere systems
```

Names above describe ownership; runtime-scene.json is the exhaustive hierarchy. The entire world is loaded into the same scene tree. Area visibility changes are not separate map loads. `Balcony` also owns the whole neighborhood, canal, estate and wall, despite its small-sounding root name.

## Routes

'''+table(['Route','Landmark sequence','Conditions'],[(r['id']+' '+r['name'],' → '.join(r['points']),r['conditions']) for r in ROUTES])+'''
## Fresh collision-audit evidence

'''+AUDIT_SUMMARY+f'''
The audit found {AUDIT['summary']['walkable_cells']:,} reachable grid cells, approximately {AUDIT['summary']['walkable_m2']:,} m² and {AUDIT['summary']['crouch_only_cells']} crouch-only cells across its bounded region. These figures are simplified 0.75 m grid measurements; they are not measured floor plans or a full gameplay traversal. The audit does not continue north past Z=64, so it cannot certify the whole rice-field road. It ignores movable props, animatable bodies and openable gates/doors. See area-guide.md and reachability/audit.json for limits and results.

## Editing instructions for another agent

1. Locate the requested reference ID in the register. Resolve its actual node path and owning source. Preserve unrelated working-tree changes.
2. Decide whether the object is baked, runtime generated or attached to a moving parent. Edit the owning data or script, and move collision, visuals, interactions, lights and route anchors together where applicable.
3. Room edits normally target the saved living_room.tscn. `editor/bake_room.gd` regenerates it from the builders and overwrites manual scene edits. Balcony, studio and fields also have bake scripts; do not run a bake casually.
4. Generated canal/warren, Nichols, siege and interaction objects are recreated at runtime. A temporary editor-instance edit will not persist; change their script or asset/layout source.
5. Preserve the three wall exits, all vertical connections, the hut/crow support routes, town ground cutouts around the canal and basement, collision masks, surface metadata and light-layer separation.
6. Run the focused area checks listed in source-ownership.md, then regenerate the documentation snapshot if coordinates changed. The maps are references, not a replacement for collision validation.
7. If the task includes a Windows build, always replace `builds/windows/Interior.exe`, closing that game process if necessary. Do not create an alternate executable name. This documentation task did not change a build.

## Reproduce this handoff

Run from the repository root with the bundled Godot 4.7.2 console executable. An editor import is needed if the project cache is absent. These commands run the source, not the shipped executable.

```powershell
& '.local/tools/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --editor --import --quit
& '.local/tools/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/map_blueprint_export.gd --quit-after 2400
& '.local/tools/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/world_audit.gd -- --no-map --out=res://../docs/map-blueprint/reachability
python tools/make_map_blueprint.py
```

Python dependencies for document generation are matplotlib and Pillow. `source-index.json` contains hashes and declaration line numbers for the owning scripts. `manifest.json` records hashes for the delivered artifacts. The ZIP contains this folder with portable relative links. The generator and runtime-export utility are also included in `reproduce/` for handoff; their maintained versions remain in tools/ and game/tests/.
'''
(OUT/'README.md').write_text(readme,encoding='utf-8')

ownership='''# Source ownership and focused checks

Read README.md first. Source-index.md lists every function/constant declaration and hashes the files used. These paths are relative to the repository root, not to this documentation directory.

'''+table(['Area','Persistent source','Focused checks'],[
('Startup and hierarchy','game/main.tscn; game/scripts/interior.gd','Cold source startup; room_integration.gd'),('Living room + original props','game/scenes/room/living_room.tscn; game/assets/room_manifest.json; game/scripts/room_builder.gd','room_integration.gd, room_furnishings.gd'),('Kitchen / walls / navy door','game/scripts/room_surroundings.gd; room_furnishings.gd; baked living_room.tscn','surroundings_integration.gd, room_furnishings.gd'),('Balcony / stair / courtyard','game/scenes/balcony/balcony.tscn; game/scripts/balcony_builder.gd, balcony.gd','balcony_integration.gd, street_integration.gd'),('Studio','game/scenes/studio/studio.tscn; game/scripts/studio_builder.gd, studio.gd, sliding_door.gd','Surroundings/upgrade tests plus targeted traversal'),('Base town','game/scripts/neighborhood_builder.gd; baked balcony scene; neighborhood.gd','street_integration.gd, neighborhood_decay_integration.gd'),('Gates / knocks / door objects','neighborhood_interactions.gd, neighborhood_usable.gd, push_gate.gd, neighborhood_encounters.gd','neighborhood_interactions.gd'),('Perimeter / exits / route hints','town_siege.gd; town_horror.gd; siege assets','siege_integration.gd, world_audit.gd'),('Canal and crossings','canal_settlement.gd; canal kit assets; canal_bank.gdshader','canal_integration.gd, canal_review.gd'),('Warren','canal_warren.gd, warren_door.gd, warren_usable.gd; shared Canal surfaces','warren_integration.gd, warren_review.gd'),('Nichols grounds and house','nichols_property.gd; assets/models/nichols/house/layout.json; house GLBs; tools/blender/nichols/build_nichols.py','nichols_integration.gd, nichols_review.gd'),('Basement and tunnel','nichols_basement.gd; same layout.json basement section; tools/blender/nichols/nichols_basement.py','basement_integration.gd, basement_review.gd'),('Fields / road / pond','fields_builder.gd; fields.gd; baked scenes/fields/fields.tscn','fields_integration.gd, night_route_audit.gd'),('Hut / dike / pickups','hut_house.gd; hut_usable.gd; story.gd; runtime children of Fields','hut_story_integration.gd, gun_integration.gd'),('Hooded man / progression','stranger.gd, stranger_cutscene.gd, story.gd; hut routes','stranger_integration.gd, siege_integration.gd'),('Loose props / physical chairs','physics_object.gd, prop_colliders.gd, loose_props.gd','physics_integration.gd, prop_spawn_audit.gd'),('Player clearance','player.gd; world_audit.gd query approximations','movement_stress.gd, world_audit.gd'),('Debug navigation','debug_menu.gd','debug_menu_integration.gd')])+'''
All bare GDScript names in the table are under game/scripts, except checks, which are under game/tests. Review/capture scripts may need rendering instead of --headless. This handoff ran a cold runtime export and world_audit.gd; the other listed tests are recommendations for future edits, not newly claimed passes.

## Collision and render layers

From builder code, outdoor static colliders commonly use collision_layer=2 and collision_mask=5. world_audit.gd queries mask 6. Room objects, player and door bodies have their exact current masks in runtime-scene.json. Do not confuse collision bits with visual layers: exterior visuals commonly render on mask 2, room/studio on 1, carried props may render on 3, Nichols interior on 1024, Nichols special shadow geometry on 2048, basement on 4096, and architecture-only beam raycasts on 524288. These are bit-mask values, not array indices.

The player nominal standing/crouching heights are 1.70/1.00 m, eyes 1.58/.88 m; walking speed 2.45 m/s, sprint 4.7, crouch 1.2. Hold/interaction reach is 3 m. A wall opening that admits the audit's reduced query capsule still needs the actual player checked.

## Original source versus current state

The saved scenes are current editable snapshots of older procedural builders. The README explicitly warns that rebaking the room overwrites manual edits. Current runtime code then replaces gate geometry, cuts ground, adds regions and creates gameplay objects. For precise object placement, consult the current baked scene and runtime node basis; consult the builder only to understand how it was authored. The historical room/room-layout.json, older docs, and prior screenshots can be visually useful but are not independent measurements of today's scene.

## Suggested handoff request

> Read docs/map-blueprint/README.md, then area-guide.md and location-register.md. Use the reference IDs to locate the requested part of the existing Sleep/Interior world. Match the current runtime node path and its persistent source. Preserve the coordinate convention (+Z north, Y up), the vertical connections, gated/crouch passages, physics and visibility layers, and unrelated working changes. Before editing a baked scene, check whether a runtime builder owns that geometry. Do not infer playable interiors from house shells or walkable ground from scenery. After the edit, run the focused area test and verify the actual player route. If a build is requested, update builds/windows/Interior.exe.
'''
(OUT/'source-ownership.md').write_text(ownership,encoding='utf-8')
(OUT/'connections.mmd').write_text('''flowchart TD
  Home["H01 Living room"] --> Entry["H02 Navy door"]
  Home --> Studio["H03 Studio slider → H30 Studio"]
  Home --> Kitchen["H05 Kitchen entrance"]
  Entry --> Balcony["H40 Balcony → H41 Stairs → H42 Courtyard"]
  Balcony --> Gate["T01 Courtyard gate: unlatch and push"]
  Gate --> Lane["T02 Lane east → T03 Street B"]
  Lane --> AB["T04 Street A / B"]
  AB --> West["T05 Street A / D → T08 Open west passage"]
  West --> Canal["C02 Upper lane → C03/C04 Trench stair"]
  Canal --> Catwalk["Catwalk Y=-4.40"]
  Catwalk --> SouthBridge["C05/C06 Plank footbridge"]
  SouthBridge --> FarBank["Far-bank path Y=-5.45"]
  FarBank --> Warren["W01 Tin entrance → W02 Crouch collapse"]
  Warren --> WSouth["W03 South crossing"]
  WSouth --> Rooms["W04 Family → W05 Altar → W06 Courtyard → W07 Store"]
  Rooms --> WNorth["W08 North crossing → W09 Exit"]
  WNorth --> RoadBridge["C08 Concrete road bridge Y=-2.10"]
  FarBank --> RoadBridge
  Catwalk --> NorthSteps["C09 North catwalk stairs"]
  NorthSteps --> RoadBridge
  AB --> North["T06 Street B / C → T09 Crouch hole"]
  North --> FieldRoad["F01 Field road"]
  FieldRoad --> Hut["F02/F03 Hut → K02 Key → K03 Drawer"]
  Hut --> Items["K04 Gun / K05 Flashlight"]
  FieldRoad --> Crow["F04 Scarecrow dike / F05 Ammo story"]
  FieldRoad --> Pond["F06 Pond / F07 Jetty"]
  FieldRoad --> End["F08 Road barrier: dead end"]
  AB --> South["T10 Hidden south crawl"]
  South --> Nichols["N01 Gate → N03 Porch → N04 Front entry"]
  Nichols --> Foyer["N05 Grand stair foot / foyer"]
  Foyer --> Upper["N06 Landing → N07 Upper bridge / bedrooms"]
  Foyer --> CellarDoor["B01 Nook → B13 Cellar door / B14 Switch"]
  CellarDoor --> Cellar["B03 Shaft foot → B04 Cellar"]
  Cellar --> Tunnel["B05 Broken wall → B06 Tunnel"]
  Tunnel --> Locked["B15 Chained iron door: locked end"]
''',encoding='utf-8')

# Offline viewer: data is inline, so opening file:// does not depend on fetch/CORS.
gallery=''.join(f'<article id="{v["file"]}"><h2>{html.escape(v["title"])}</h2><p>{html.escape(v["detail"])}</p><a href="{v["file"]}.png" target="_blank"><img src="{v["file"]}.png" loading="lazy" alt="{html.escape(v["title"])}"></a><p><a href="{v["file"]}.svg">Scalable SVG</a> · <a href="{v["file"]}.png">Full-size PNG</a></p></article>' for v in VIEWS)
links=''.join(f'<a href="#{v["file"]}">{html.escape(v["title"])}</a>' for v in VIEWS)
mini_nodes=[{k:n[k] for k in ('id','path','name','type','position','script','gameplay','collision_bounds','mesh_bounds','groups') if k in n} for n in NODES if 'position' in n]
viewer=r'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Sleep — map reference</title><style>
*{box-sizing:border-box}body{margin:0;background:#edf2f5;color:#203b4e;font:16px/1.5 system-ui,sans-serif}header,main{max-width:1600px;margin:auto;padding:24px}header h1{font-size:32px;margin:0 0 8px}nav{display:flex;gap:8px;flex-wrap:wrap;margin:20px 0}a{color:#215e83}nav a{background:white;border:1px solid #cad7df;padding:8px 12px;border-radius:6px;text-decoration:none}article,section{background:#fff;padding:22px;border:1px solid #cfdae1;border-radius:10px;margin:24px 0}h2{font-size:24px;margin-top:0}img{width:100%;height:auto;display:block}input{width:100%;font:inherit;padding:14px;border:1px solid #9eafb9;border-radius:6px}button,select{font:inherit;padding:9px 14px;margin:10px 10px 10px 0}table{border-collapse:collapse;width:100%;font-size:14px}th,td{border-bottom:1px solid #d7e0e5;padding:10px;text-align:left;vertical-align:top;overflow-wrap:anywhere}th{background:#edf2f5;position:sticky;top:0}td:first-child{width:180px;font-weight:600}.table{max-height:650px;overflow:auto}code{font:14px ui-monospace,monospace}.note{max-width:1000px}.small{font-size:14px;color:#567080}.coords{white-space:nowrap}.table td:nth-child(2){min-width:220px}
</style><header><h1>Sleep / Interior — full map reference</h1><p class="note">Current working source • 10 November 2026 • +Z north, +X east, Y up • metres. This package contains map and story spoilers. Reference IDs are documentation labels, paired with real runtime paths.</p><p><a href="README.md">Read the handoff</a> · <a href="area-guide.md">Detailed area guide</a> · <a href="room-dimensions.md">Room dimensions</a> · <a href="source-ownership.md">Source ownership</a> · <a href="locations.csv">Locations CSV</a> · <a href="runtime-scene.json">Full runtime JSON</a></p><nav>LINKS<a href="#lookup">Search locations and objects</a></nav></header><main><section id="lookup"><h2>Find a place or object</h2><p>Search an ID, name, node path, script or coordinate. Results contain object origins, not safe teleport positions. Full collision and transform data is in the runtime JSON.</p><input id="search" placeholder="Try W04, Nichols, TopDrawer, television_4, or 148.6332" aria-label="Search map inventory"><label for="mode">Search in </label><select id="mode"><option value="locations">Named map references</option><option value="nodes">Runtime node inventory</option></select><span id="count" aria-live="polite"></span><div class="table"><table><thead><tr><th>ID / type</th><th>Name / path</th><th>World (X,Y,Z)</th><th>Details / source</th></tr></thead><tbody id="results"></tbody></table></div><p class="small">Shows up to 200 matching entries. Narrow the search to inspect other objects. Autogenerated @Node@ paths are snapshot-specific.</p></section>GALLERY</main><script id="locations-data" type="application/json">POIDATA</script><script id="nodes-data" type="application/json">NODEDATA</script><script>
const locations=JSON.parse(document.getElementById('locations-data').textContent),nodes=JSON.parse(document.getElementById('nodes-data').textContent);const input=document.getElementById('search'),mode=document.getElementById('mode'),body=document.getElementById('results');const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));function render(){const q=input.value.toLowerCase().trim(),data=mode.value==='nodes'?nodes:locations,found=data.filter(n=>!q||JSON.stringify(n).toLowerCase().includes(q));document.getElementById('count').textContent=found.length.toLocaleString()+' results';body.innerHTML=found.slice(0,200).map(n=>{let pos=(n.position||[]).map(x=>Number(x).toFixed(4).replace(/0+$/,'').replace(/\.$/,'')).join(', ');return '<tr><td>'+esc(n.id)+'<br><span class="small">'+esc(n.area||n.type)+'</span></td><td>'+esc(n.name)+'<br><code>'+esc(n.node_path||n.path||'')+'</code></td><td class="coords">('+pos+')</td><td>'+esc(n.detail||n.script||'')+(n.source?'<br><code>'+esc(n.source.file+':'+n.source.line)+'</code>':'')+'</td></tr>'}).join('')};input.addEventListener('input',render);mode.addEventListener('change',render);render();</script></html>'''
viewer=viewer.replace('LINKS',links).replace('GALLERY',gallery).replace('POIDATA',json.dumps(POIS,ensure_ascii=False).replace('</','<\\/')).replace('NODEDATA',json.dumps(mini_nodes,ensure_ascii=False).replace('</','<\\/'))
(OUT/'atlas.html').write_text(viewer,encoding='utf-8')

# Include reproducibility utilities without modifying or rebaking gameplay sources.
(OUT/'reproduce').mkdir(exist_ok=True)
shutil.copy2(ROOT/'game/tests/map_blueprint_export.gd',OUT/'reproduce/map_blueprint_export.gd')
shutil.copy2(Path(__file__),OUT/'reproduce/make_map_blueprint.py')
manifest={'prepared_date':'2026-11-10','provenance':'current working source; dirty-tree changes included; source runtime, not executable inspection','runtime_node_count':len(NODES),'named_references':len(POIS),'map_sheets':len(VIEWS),'source_scripts':source_data,'runtime_export_sha256':hashlib.sha256((OUT/'runtime-scene.json').read_bytes()).hexdigest(),'artifacts':[]}
manifest['git_head']=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
manifest['engine']='Godot 4.7.2 stable'
for p in sorted(OUT.rglob('*')):
    if p.is_file() and p.name not in ['manifest.json','import.log']:
        manifest['artifacts'].append({'path':p.relative_to(OUT).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
write_json('manifest.json',manifest)
zip_path=ROOT/'docs/Sleep-map-blueprint.zip'
with zipfile.ZipFile(zip_path,'w',zipfile.ZIP_DEFLATED) as z:
    for p in OUT.rglob('*'):
        if p.is_file() and p.name!='import.log':z.write(p,Path('map-blueprint')/p.relative_to(OUT))
print(json.dumps({'nodes':len(NODES),'references':len(POIS),'maps':len(VIEWS),'zip_bytes':zip_path.stat().st_size,'out':str(OUT)},indent=2))
