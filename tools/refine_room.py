"""Support/UV corrections and independently movable loose components."""
import bpy,bmesh,json,math
from pathlib import Path
from mathutils import Vector,Matrix
root=Path(__file__).resolve().parent.parent;p=root/'room'
bpy.ops.wm.open_mainfile(filepath=str(p/'living_room.blend'))
scene=bpy.context.scene; layout=json.loads((p/'room-layout.json').read_text())
def bounds(o):
    v=[o.matrix_world@Vector(c) for c in o.bound_box]
    return Vector([min(x[k] for x in v) for k in range(3)]),Vector([max(x[k] for x in v) for k in range(3)])
def bottom(o,height):
    lo,hi=bounds(o);o.location.z+=height-lo.z;bpy.context.view_layer.update()
table=next(bpy.data.objects[i['meshObject']] for i in layout['instances'] if i['assetId']=='marble_table')
tray=next(bpy.data.objects[i['meshObject']] for i in layout['instances'] if i['assetId']=='woven_tray')
bottom(tray,bounds(table)[1].z+.001)
for i in layout['instances']:
    o=bpy.data.objects[i['meshObject']]
    if i['assetId'] in ['potted_plant','tissue_box'] and i['location'][1]<0:bottom(o,bounds(tray)[1].z+.001)
    if i['assetId']=='fish_bowl':bottom(o,.496)
    if i['assetId']=='storage_bin':bottom(o,.08)
floor=bpy.data.objects['Floor'];floor.scale=(6.8/6.6,5.6/5.4,1);floor.location.z=-.095
ceiling=bpy.data.objects['Ceiling'];ceiling.scale.z=1.05

def full_uv(o):
    if not o.data.uv_layers:o.data.uv_layers.new()
    uv=o.data.uv_layers.active.data
    verts=o.data.vertices
    for poly in o.data.polygons:
        mat=o.data.materials[poly.material_index]
        name=mat.name if mat else ''
        if not any(s in name.lower() for s in ['marble','oak','photo insert','floor tiles']):continue
        n=poly.normal; axis=max(range(3),key=lambda j:abs(n[j])); axes=[j for j in range(3) if j!=axis]
        if 'photo insert' in name.lower():axes=[0,2]
        # Use the extents of this face material for joined assemblies.
        valid=[v.co for f in o.data.polygons if f.material_index==poly.material_index for v in [verts[j] for j in f.vertices]]
        lows=[min(v[j] for v in valid) for j in axes];highs=[max(v[j] for v in valid) for j in axes]
        for li in poly.loop_indices:
            c=verts[o.data.loops[li].vertex_index].co
            a=(c[axes[0]]-lows[0])/max(highs[0]-lows[0],.00001);b=(c[axes[1]]-lows[1])/max(highs[1]-lows[1],.00001)
            uv[li].uv=(b,a) if 'oak' in name.lower() else (a,b)
seen=set()
for o in scene.objects:
    if o.type=='MESH' and o.data.name not in seen:
        full_uv(o);seen.add(o.data.name)

def extract(o, predicate, label, mass):
    data=o.data; chosen=[f for f in data.polygons if predicate(f,data)]
    if not chosen:return
    remaining={f.index for f in chosen}; face_map={f.index:f for f in chosen}
    connected={}
    for f in chosen:
        for v in f.vertices:connected.setdefault(v,set()).add(f.index)
    groups=[]
    while remaining:
        todo=[remaining.pop()];g=[]
        while todo:
            fi=todo.pop();g.append(fi)
            for v in face_map[fi].vertices:
                for other in connected[v]&remaining:remaining.remove(other);todo.append(other)
        groups.append(g)
    for n,group in enumerate(groups):
        faces=[data.polygons[j] for j in group]
        ids=sorted({j for f in faces for j in f.vertices}); mapping={j:k for k,j in enumerate(ids)}
        coords=[data.vertices[j].co.copy() for j in ids]
        center=(Vector([min(v[k] for v in coords) for k in range(3)])+Vector([max(v[k] for v in coords) for k in range(3)]))*.5
        mesh=bpy.data.meshes.new(label+' mesh');mesh.from_pydata([v-center for v in coords],[],[[mapping[j] for j in f.vertices] for f in faces]);mesh.update()
        for m in data.materials:mesh.materials.append(m)
        uv=mesh.uv_layers.new().data
        for a,b in zip(mesh.polygons,faces):
            a.material_index=b.material_index;a.use_smooth=b.use_smooth
            if data.uv_layers:
                for ai,bi in zip(a.loop_indices,b.loop_indices):uv[ai].uv=data.uv_layers.active.data[bi].uv
        item=bpy.data.objects.new(label+' '+str(n+1)+' '+o.name,mesh);scene.collection.objects.link(item);item.matrix_world=o.matrix_world@Matrix.Translation(center);item['movable_detail']=True
        layout['details'].append(dict(id=item.name,meshObject=item.name,movable=True,massKg=mass))
    bm=bmesh.new();bm.from_mesh(data);bm.faces.ensure_lookup_table();bmesh.ops.delete(bm,geom=[bm.faces[f.index] for f in chosen],context='FACES');bm.to_mesh(data);bm.free();data.update()
for i in layout['instances']:
    o=bpy.data.objects[i['meshObject']]
    if i['assetId'] in ['fabric_sofa','leather_sofa']:
        o.data=o.data.copy();extract(o,lambda f,d: d.materials[f.material_index].name=='Beige cushion','Loose cushion',.4)
    if i['assetId']=='baby_crib':
        o.data=o.data.copy();extract(o,lambda f,d:d.materials[f.material_index].name=='Pink soft toy','Pink toy',.15)
    if i['assetId']=='computer_desk':
        o.data=o.data.copy();extract(o,lambda f,d:all(abs(d.vertices[j].co.x)<.23 and -.19<d.vertices[j].co.y<-.03 and .737<d.vertices[j].co.z<.763 for j in f.vertices),'Keyboard',.5)
    i['location']=list(o.location)
scene['review_status']='Form pending explicit human approval'
# Use the installed GPU for the review suite; fallback remains supported.
try:
    pref=bpy.context.preferences.addons['cycles'].preferences;pref.compute_device_type='OPTIX';pref.get_devices()
    for device in pref.devices:device.use=device.type=='OPTIX'
    if any(d.use for d in pref.devices):scene.cycles.device='GPU'
except Exception as error:print('GPU unavailable:',error)
scene.cycles.samples=32
camera=scene.camera
def aim(loc,target,wide=False):camera.location=loc;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=10.4 if wide else 24
def render(name):scene.render.filepath=str(p/'renders'/name);bpy.ops.render.render(write_still=True)
aim((2.2,-2.58,1.65),(-.55,1.6,1.15));render('final-production.png')
for n,(loc,target) in enumerate([((-3.05,-2.45,1.65),(1,1.2,1.1)),((3.05,-2.45,1.65),(-1,1.2,1.1)),((-3.05,2.45,1.65),(1,-1.2,1.1)),((3.05,2.45,1.65),(-1,-1.2,1.1))]):aim(loc,target,True);render(f'corner-{n+1}.png')
aim((0,0,1.65),(0,0,2.9));render('ceiling-center-up.png')
aim((-2.6,-1.8,1.5),(1,1.2,2.9));render('ceiling-oblique-a.png')
aim((2.6,1.8,1.5),(-1,-1.2,2.9));render('ceiling-oblique-b.png')
aim((2.2,-2.58,1.65),(-.55,1.6,1.15));scene.cycles.samples=48
(p/'room-layout.json').write_text(json.dumps(layout,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(p/'living_room.blend'))
print('REFINED_FORM_READY',len(layout['details']))
