"""Export only after explicit Form approval, with measured collider metadata."""
import bpy,json,hashlib,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
root=Path(__file__).resolve().parent.parent;p=root/'room';out=root/'game/assets';out.mkdir(exist_ok=True)
review=json.loads((p/'milestone-reviews.json').read_text());assert review['function']['status']=='approved' and review['form']['status']=='approved','Function and Form approvals are required'
bpy.ops.wm.open_mainfile(filepath=str(p/'living_room.blend'))
layout=json.loads((p/'room-layout.json').read_text())
def godot(v):return [v[0],v[2],-v[1]]
def box(center,size):return dict(center=godot(center),size=[size[0],size[2],size[1]])
def cylinder(a,b,radius):
    a,b=Vector(a),Vector(b);return dict(kind='cylinder',center=godot((a+b)*.5),axis=godot((b-a).normalized()),radius=radius,height=(b-a).length)
def collider(o):
    pts=[Vector(c) for c in o.bound_box];lo=Vector([min(v[k] for v in pts) for k in range(3)]);hi=Vector([max(v[k] for v in pts) for k in range(3)])
    return box((lo+hi)*.5,hi-lo)
compound={
 'fabric_sofa':[box((0,0,.33),(1.95,.84,.49)),box((0,.36,.73),(1.86,.2,.68)),box((-.96,0,.53),(.23,.92,.67)),box((.96,0,.53),(.23,.92,.67))]+[cylinder((x,y,0),(x,y,.14),.045) for x in (-.79,.79) for y in (-.30,.30)],
 'marble_table':[box((0,0,.8),(1.65,1.32,.07)),box((0,0,.06),(.75,.65,.12)),box((0,0,.42),(.49,.46,.65))],
 'computer_desk':[box((0,0,z),(1.1,.49,.035)) for z in (.06,.72,1.38)]+[box((x,y,.7375),(.036,.036,1.425)) for x in (-.53,.53) for y in (-.22,.22)],
 'high_chair':[box((0,0,.63),(.45,.45,.07)),box((0,.23,.85),(.46,.055,.41)),box((0,-.23,.81),(.56,.34,.055))]+[cylinder((x*1.3,y*1.3,.06),(x,y,.94),.027) for x in (-.23,.23) for y in (-.23,.23)],
 'baby_crib':[box((0,0,.66),(.93,.57,.10))]+[box((0,y,.78),(1.02,.052,.29)) for y in (-.33,.33)]+[box((x,0,.78),(.052,.65,.29)) for x in (-.5,.5)]+[cylinder((x,y-.0145,.05),(x,y+.0145,.05),.044) for x in (-.46,.46) for y in (-.30,.30)]+[cylinder((x,y,.06),(x*.8,y*.8,.83),.018) for x in (-.46,.46) for y in (-.30,.30)],
 'wall_shelf':[box((0,0,.02),(.59,.24,.04)),box((0,-.11,.12),(.58,.018,.018)),box((0,.144,-.06),(.05,.105,.14))]+[box((x,-.11,.11),(.025,.025,.20)) for x in (-.29,.29)],
 'potted_plant':[box((0,0,.08),(.20,.20,.16))],
 'red_flowers':[box((0,0,.085),(.18,.18,.17))],
 'purple_flowers':[box((0,0,.085),(.18,.18,.17))],
 'yellow_flowers':[box((0,0,.085),(.18,.18,.17))],
 'pet_enclosure':[box((0,0,z),(.65,.49,.03)) for z in (.035,.48,.94,1.4)]+[box((x,y,.735),(.046,.046,1.42)) for x in (-.30,.30) for y in (-.22,.22)]+[box((0,y,z),(.58,.012,.42)) for z in (.70,1.16,1.61) for y in (-.21,.21)]+[box((x,0,z),(.012,.42,.42)) for z in (.70,1.16,1.61) for x in (-.29,.29)]+[box((0,0,z+.21),(.58,.42,.012)) for z in (.70,1.16,1.61)],
}
compound['leather_sofa']=compound['fabric_sofa']
mass={'fabric_sofa':45,'leather_sofa':50,'marble_table':40,'tv_console':35,'standing_fan':4,'computer_desk':16,'high_chair':6,'baby_crib':8,'pet_enclosure':12,'television':8,'bass_guitar':3,'photo_frame':.35,'digital_clock':.5,'wall_shelf':1.4,'fish_bowl':2.5,'potted_plant':.7,'computer_tower':6,'monitor':2}
actors=[];dynamic_names=set()
for i in layout['instances']:
    o=bpy.data.objects[i['meshObject']];asset=i['assetId'];dynamic_names.add(o.name)
    actor=dict(nodeName=o.name,assetId=asset,label=asset.replace('_',' ').capitalize(),mass=mass.get(asset,.5),anchored=asset in ['photo_frame','wall_shelf','television'],colliders=compound.get(asset,[collider(o)]))
    if asset=='television':actor['console']=True
    if asset=='digital_clock':actor.update(clueDigit='5',clueText='The first digit is the hour: 5.')
    if asset=='potted_plant' and i['location'][1]<0:actor.update(clueDigit='0',clueText='Under the table plant: the middle digit is 0.')
    if asset=='photo_frame' and i['location'][0]<0 and i['location'][2]<1.5:actor.update(clueDigit='8',clueText='Behind the small frame: the last digit is 8.')
    actors.append(actor)
for detail in layout.get('details',[]):
    if not detail['movable']:continue
    o=bpy.data.objects[detail['meshObject']];dynamic_names.add(o.name)
    shapes=[collider(o)]
    if o.name=='White display rack':
        shapes=[box((x,y,.72),(.025,.025,1.44)) for x in (-.28,.28) for y in (-.19,.19)]+[box((0,0,z),(.60,.43,.025)) for z in (.07,.45,.85,1.28)]
    if o.name=='Black storage rack':
        shapes=[box((0,0,z),(.69,.47,.025)) for z in (.10,.605,1.105)]+[box((x,y,.56),(.025,.025,1.12)) for x in (-.33,.33) for y in (-.225,.225)]
    label='Cushion' if o.name.startswith('Loose cushion') else 'Pink toy' if o.name.startswith('Pink toy') else 'Keyboard' if o.name.startswith('Keyboard') else detail['id']
    actors.append(dict(nodeName=o.name,assetId='loose_component',label=label,mass=detail['massKg'],anchored=False,colliders=shapes))
static=[]
for name in ['Floor','Back wall','Left wall','Right wall','Rear wall','Ceiling','Raised TV cabinet base']:
    o=bpy.data.objects[name]
    pts=[o.matrix_world@Vector(c) for c in o.bound_box];lo=Vector([min(v[k] for v in pts) for k in range(3)]);hi=Vector([max(v[k] for v in pts) for k in range(3)])
    static.append(dict(id=name,center=godot((lo+hi)*.5),size=[hi.x-lo.x,hi.z-lo.z,hi.y-lo.y]))
# Combine immutable visual architecture into one mesh: fewer draw calls on GLES.
# The canonical .blend remains untouched, and collisions still use the measured shell.
floor=bpy.data.objects['Floor']
bpy.context.view_layer.objects.active=floor
subdivide=floor.modifiers.new('Static light receiver grid','SUBSURF');subdivide.subdivision_type='SIMPLE';subdivide.levels=4
bpy.ops.object.modifier_apply(modifier=subdivide.name)
static_visual=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name not in dynamic_names and not any(c.name=='Prop mesh library' for c in o.users_collection)]
bpy.ops.object.select_all(action='DESELECT')
for o in static_visual:o.hide_set(False);o.select_set(True)
bpy.context.view_layer.objects.active=static_visual[0]
bpy.ops.object.join();architecture=bpy.context.object;architecture.name='Room architecture'
# Bake static receiver illumination from the fixture manifest. Furnishings are
# deliberately excluded as static shadow casters because the player moves them.
vertices=[architecture.matrix_world@v.co for v in architecture.data.vertices]
polygons=[list(f.vertices) for f in architecture.data.polygons]
tree=BVHTree.FromPolygons(vertices,polygons)
color=architecture.data.color_attributes.new(name='RoomLight',type='BYTE_COLOR',domain='CORNER')
normal_matrix=architecture.matrix_world.to_3x3().inverted().transposed()
for poly in architecture.data.polygons:
    normal=(normal_matrix@poly.normal).normalized()
    for li in poly.loop_indices:
        position=vertices[architecture.data.loops[li].vertex_index]+normal*.008
        illumination=.54
        for fixture in layout['fixtures']:
            difference=Vector(fixture['location'])-position;distance=difference.length
            direction=difference.normalized();cosine=max(0,normal.dot(direction))
            hit=tree.ray_cast(position,direction,max(0,distance-.03))
            if hit[0] is None:
                illumination+=cosine*(fixture['watts']/300)*.35/(1+distance*.18)
        factor=min(.98,max(.42,illumination))
        color.data[li].color=(factor,factor,factor,1)
bpy.ops.object.select_all(action='DESELECT')
selected=[]
for o in bpy.context.scene.objects:
    if o.type!='MESH' or any(c.name=='Prop mesh library' for c in o.users_collection):continue
    o.hide_set(False);o.select_set(True);selected.append(o)
filepath=out/'living_room.glb'
bpy.ops.export_scene.gltf(filepath=str(filepath),export_format='GLB',use_selection=True,export_yup=True,export_extras=True,export_cameras=False,export_lights=False,export_vertex_color='NAME',export_vertex_color_name='RoomLight')
manifest=dict(roomId='interior-living-room',coordinateSystem='Godot Y up, TV wall at negative Z',actors=actors,staticColliders=static,fixtures=[dict(id=f['id'],location=godot(f['location']),watts=f['watts'],size=f['size']) for f in layout['fixtures']],spawn=[.62,.10,1.30],sourceSha256=hashlib.sha256((p/'living_room.blend').read_bytes()).hexdigest(),glbSha256=hashlib.sha256(filepath.read_bytes()).hexdigest(),textureTier='1K primary surfaces; 512 textile; 192x256 portraits',geometryTriangles=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in selected))
manifest['staticLighting']=dict(method='RoomLight vertex-color bake',fixtureManifest='room-layout.json fixtures',staticCastersOnly=True,receiverVertices=len(vertices),dynamicLights='Same fixture positions; restrained additive fill')
(out/'room_manifest.json').write_text(json.dumps(manifest,indent=2));(p/'runtime/export-manifest.json').write_text(json.dumps(manifest,indent=2))
print('ROOM_EXPORT',len(actors),'actors',manifest['geometryTriangles'],'triangles',filepath.stat().st_size,'bytes')
