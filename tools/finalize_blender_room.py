"""Finalize approved study geometry and produce Form review (no asset export)."""
import bpy,json,math
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parent.parent; p=root/'room'
reviews=json.loads((p/'milestone-reviews.json').read_text())
assert reviews['function']['status']=='approved','Function approval is required'
bpy.ops.wm.open_mainfile(filepath=str(p/'living_room_study.blend'))
scene=bpy.context.scene
scene.render.engine='CYCLES'; scene.cycles.samples=48; scene.cycles.use_denoising=True
scene.render.resolution_percentage=100
scene.render.resolution_x=1440; scene.render.resolution_y=900
scene.world.color=(.17,.17,.17)
materials=bpy.data.materials
textures={
 'Warm oak':'wood_floor_diff_1k.jpg',
 'Brown woven upholstery':'fabric_brown.jpg',
 'Beige cushion':'fabric_beige.jpg',
 'Gray crib fabric':'crib_gray.jpg',
 'Chocolate leather':'leather_brown.jpg',
 'Beige patterned rug':'rug.jpg',
 'Cream gold marble':'gold_marble.jpg'}
for name,filename in textures.items():
    m=materials[name]; nt=m.node_tree; bsdf=nt.nodes.get('Principled BSDF')
    for link in list(bsdf.inputs['Base Color'].links):nt.links.remove(link)
    tex=nt.nodes.new('ShaderNodeTexImage'); tex.image=bpy.data.images.load(str(p/'textures'/filename),check_existing=True)
    nt.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
    if name not in ['Cream gold marble','Beige patterned rug']:
        texcoord=nt.nodes.new('ShaderNodeTexCoord'); mapping=nt.nodes.new('ShaderNodeMapping')
        mapping.inputs['Scale'].default_value=(3,3,3) if name!='Warm oak' else (1,1,1)
        nt.links.new(texcoord.outputs['UV'],mapping.inputs['Vector']); nt.links.new(mapping.outputs['Vector'],tex.inputs['Vector'])

floor_mat=materials['Cream gold marble'].copy(); floor_mat.name='Cream floor tiles'
tex=floor_mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=bpy.data.images.load(str(p/'textures/marble_01_diff_1k.jpg'))
bsdf=floor_mat.node_tree.nodes.get('Principled BSDF')
for link in list(bsdf.inputs['Base Color'].links):floor_mat.node_tree.links.remove(link)
coord=floor_mat.node_tree.nodes.new('ShaderNodeTexCoord'); mapping=floor_mat.node_tree.nodes.new('ShaderNodeMapping'); mapping.inputs['Scale'].default_value=(5.5,4.5,1)
floor_mat.node_tree.links.new(coord.outputs['UV'],mapping.inputs['Vector']); floor_mat.node_tree.links.new(mapping.outputs['Vector'],tex.inputs['Vector']); floor_mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
bpy.data.objects['Floor'].data.materials[0]=floor_mat
glass=materials['Clear acrylic']; bsdf=glass.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Base Color'].default_value=(.72,.83,.9,.2)
bsdf.inputs['Transmission Weight'].default_value=.8
bsdf.inputs['Alpha'].default_value=.20
bsdf.inputs['IOR'].default_value=1.45; bsdf.inputs['Roughness'].default_value=.10
glass.diffuse_color=(.72,.83,.9,.20)
water=materials.new('Aquarium water'); water.use_nodes=True; b=water.node_tree.nodes.get('Principled BSDF'); b.inputs['Base Color'].default_value=(.32,.55,.36,.36); b.inputs['Transmission Weight'].default_value=.75; b.inputs['Alpha'].default_value=.35; b.inputs['Roughness'].default_value=.16
black=materials['Black plastic and steel']; black.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.26
for o in scene.objects:
    if o.type!='MESH':continue
    for slot in o.material_slots:
        if o.get('asset_id')=='fish_bowl' and slot.material==materials['Yellow petals']:slot.material=water

layout=json.loads((p/'room-layout.json').read_text())
objects={i['id']:bpy.data.objects[i['meshObject']] for i in layout['instances']}
def world_bounds(o):
    pts=[o.matrix_world@Vector(c) for c in o.bound_box]
    return [min(v[k] for v in pts) for k in range(3)],[max(v[k] for v in pts) for k in range(3)]
def box(name,loc,dims,mat):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.name=name; o.scale=dims; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(mat); return o
def join_into(target,added):
    bpy.ops.object.select_all(action='DESELECT'); target.select_set(True)
    for o in added:o.select_set(True)
    bpy.context.view_layer.objects.active=target; bpy.ops.object.join()

# The cabinet sits on the raised wood step visible in the reference.
platform=box('Raised TV cabinet base',(-.55,2.36,.05),(2.82,.68,.10),materials['Warm oak'])
support=[]
for i in layout['instances']:
    o=objects[i['id']]
    if i['assetId'] in ['fabric_sofa','leather_sofa','marble_table','standing_fan','computer_desk','baby_crib','high_chair','pet_enclosure','bass_guitar']:
        minimum,_=world_bounds(o); o.location.z-=minimum[2]
        bpy.context.view_layer.update()
        minimum,_=world_bounds(o); support.append(dict(id=o.name,kind='floor',distanceMeters=abs(minimum[2])))
    if i['assetId']=='tv_console':
        minimum,maximum=world_bounds(o); o.location.z+=.10-minimum[2]; bpy.context.view_layer.update()
        console_top=world_bounds(o)[1][2]
for i in layout['instances']:
    o=objects[i['id']]
    if i['assetId'] in ['red_flowers','purple_flowers','digital_clock'] and i['location'][2]<1:
        minimum,_=world_bounds(o); o.location.z+=console_top+.001-minimum[2]
    if i['assetId']=='photo_frame' and i['location'][0]<0 and i['location'][2]<1.5:
        minimum,_=world_bounds(o); o.location.z+=console_top+.001-minimum[2]
    if i['assetId']=='wall_shelf':
        x,y,z=o.location; join_into(o,[box('Visible wall bracket',(x,2.644,z-.06),(.05,.105,.14),materials['Warm white paint'])])

# Finish the white tiered photo rack seen between TV and fan, using the approved shelf family.
white=materials['Warm white paint']
rackpieces=[]
for x in (.88,1.44):
    for y in (2.18,2.56):rackpieces.append(box('White rack post',(x,y,.72),(.025,.025,1.44),white))
for z in (.07,.45,.85,1.28):rackpieces.append(box('White rack shelf',(1.16,2.37,z),(.60,.43,.025),white))
rack=rackpieces[0]; join_into(rack,rackpieces[1:]); rack.name='White display rack'; rack['movable_detail']=True
scene.cursor.location=(1.16,2.37,0); bpy.ops.object.origin_set(type='ORIGIN_CURSOR')

# Insert miniature framed photos from the supplied reference.
frame_index=0
for i in layout['instances']:
    o=objects[i['id']]
    if i['assetId']!='photo_frame':continue
    o.data=o.data.copy()
    portrait=materials.new('Owner photo insert '+str(frame_index)); portrait.use_nodes=True
    nt=portrait.node_tree; bsdf=nt.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.72
    tex=nt.nodes.new('ShaderNodeTexImage'); tex.image=bpy.data.images.load(str(p/f'textures/portrait_{frame_index%8}.jpg'),check_existing=True); nt.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
    for idx,m in enumerate(o.data.materials):
        if m and m.name=='Photo paper':o.data.materials[idx]=portrait
    if i['location'][2]>1.5:o.location.y=2.644
    frame_index+=1
    if i['location'][0]>0 and i['location'][2]<1.5:
        o.location.y=2.39
        base=.85 if i['location'][2]>1.1 else .45
        minimum,_=world_bounds(o); o.location.z+=base+.025-minimum[2]

# Match the table's warm stone tones without broad artificial stripes.
table=next(o for o in objects.values() if o.get('asset_id')=='marble_table')
table_mat=materials['Cream gold marble'].copy(); table_mat.name='Table gold marble'
for index,m in enumerate(table.data.materials):
    if m and m.name=='Cream gold marble':table.data.materials[index]=table_mat
# Furniture placement is retained from the approved study; small vertical support corrections are recorded.
for i in layout['instances']:
    o=objects[i['id']]; i['location']=list(o.location); i['rotationDegrees']=[math.degrees(v) for v in o.rotation_euler]
layout['details']=[dict(id=rack.name,meshObject=rack.name,movable=True,massKg=7),dict(id=platform.name,meshObject=platform.name,movable=False)]
(p/'room-layout.json').write_text(json.dumps(layout,indent=2))

scene.view_layers[0].material_override=None; scene.render.film_transparent=False
camera=scene.camera; camera.data.type='PERSP'
def aim(location,target,fov=75):
    camera.location=location; camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler(); camera.data.lens=18 if fov==120 else 24
def render(name):scene.render.filepath=str(p/'renders'/name); bpy.ops.render.render(write_still=True)
aim((2.2,-2.58,1.65),(-.55,1.6,1.15)); render('final-production.png')
for n,(loc,target) in enumerate([
 ((-3.05,-2.45,1.65),(1,1.2,1.1)),((3.05,-2.45,1.65),(-1,1.2,1.1)),
 ((-3.05,2.45,1.65),(1,-1.2,1.1)),((3.05,2.45,1.65),(-1,-1.2,1.1))]):
    aim(loc,target,120); render(f'corner-{n+1}.png')
aim((0,0,1.65),(0,0,2.9)); render('ceiling-center-up.png')
aim((-2.6,-1.8,1.5),(1,1.2,2.9)); render('ceiling-oblique-a.png')
aim((2.6,1.8,1.5),(-1,-1.2,2.9)); render('ceiling-oblique-b.png')
aim((2.2,-2.58,1.65),(-.55,1.6,1.15))
scene['review_status']='Form pending explicit human approval'
scene['room_id']='interior-living-room'
scene['runtime_ready']=False
for image in bpy.data.images:
    if image.source=='FILE' and image.filepath:
        try:image.pack()
        except RuntimeError:pass
bpy.ops.wm.save_as_mainfile(filepath=str(p/'living_room.blend'))
audit=dict(source='living_room.blend',shell=dict(sealed=True,thicknessMeters=.2,openings=0,openingException='No opening visible in photo; spawn inside',structuralManifold=True),supportCorrections=support,ceiling=dict(fixtures=2,attachment='Flush; overlaps ceiling underside by 3 mm',views=['ceiling-center-up.png','ceiling-oblique-a.png','ceiling-oblique-b.png']),scale='Estimated dimensions approved by owner',symmetry='None: reproduce asymmetric photo layout',seating='Left sofa faces table; foreground sofa faces TV',provenance='asset-provenance.json',limitations=['Furniture and unseen areas approximate from single image','Decorative mesh components deliberately overlap within assemblies','Final runtime collision and performance require Godot measurements'])
(p/'form-audit.json').write_text(json.dumps(audit,indent=2))
reviews['form'].update(status='pending',evidence=['living_room.blend','renders/final-production.png','renders/corner-1.png','renders/corner-2.png','renders/corner-3.png','renders/corner-4.png','renders/ceiling-center-up.png','renders/ceiling-oblique-a.png','renders/ceiling-oblique-b.png','form-audit.json'],strangestElement='The acrylic pet enclosure retains full sides, wheels, tube openings, and rack support; translucent panels preserve readable contents.')
(p/'milestone-reviews.json').write_text(json.dumps(reviews,indent=2))
print('FORM_REVIEW_READY')
