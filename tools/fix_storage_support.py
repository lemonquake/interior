"""Runtime-discovered support correction within the approved desk furnishing family."""
import bpy,json
from pathlib import Path
root=Path(__file__).resolve().parent.parent;p=root/'room'
bpy.ops.wm.open_mainfile(filepath=str(p/'living_room.blend'))
layout=json.loads((p/'room-layout.json').read_text())
black=bpy.data.materials['Black plastic and steel']
pieces=[]
def box(name,location,size):
    bpy.ops.mesh.primitive_cube_add(size=1,location=location);o=bpy.context.object;o.name=name;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(black);pieces.append(o)
for z in (.10,.605,1.105):box('Storage rack board',(2.95,2.46,z),(.69,.47,.025))
for x in (2.62,3.28):
    for y in (2.235,2.685):box('Storage rack post',(x,y,.56),(.025,.025,1.12))
bpy.ops.object.select_all(action='DESELECT')
for o in pieces:o.select_set(True)
bpy.context.view_layer.objects.active=pieces[0];bpy.ops.object.join();rack=bpy.context.object;rack.name='Black storage rack';rack['movable_detail']=True
bpy.context.scene.cursor.location=(2.95,2.46,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
layout['details'].append(dict(id=rack.name,meshObject=rack.name,movable=True,massKg=5))
bin_number=0
for i in layout['instances']:
    o=bpy.data.objects[i['meshObject']]
    if i['assetId']=='storage_bin':
        o.location=(2.95,2.46,.114 if bin_number==0 else .619);bin_number+=1
        i['location']=list(o.location)
    if i['assetId']=='potted_plant' and i['location'][0]>2.5:
        o.location.z=1.12;i['location']=list(o.location)
layout['runtimeCorrections']=['Added the desk-side black rack visible in the reference to support its two bins and plants; positions corrected within the approved furnishing layout.']
(p/'room-layout.json').write_text(json.dumps(layout,indent=2))
for image in bpy.data.images:
    if image.source=='FILE' and image.filepath:
        try:image.pack()
        except RuntimeError:pass
bpy.ops.wm.save_as_mainfile(filepath=str(p/'living_room.blend'))
print('STORAGE_SUPPORT_CORRECTED')
