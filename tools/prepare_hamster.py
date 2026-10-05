"""Reproducibly skin and animate a licensed downloaded hamster, then export GLB.

Run in Blender 5.2: blender --background --python tools/prepare_hamster.py
The original source is preserved. No external or paid generation is used.
"""
import bpy
import math
import json
import hashlib
import urllib.request
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / 'game/assets/hamsters'
EVIDENCE = ROOT / 'work/lemondev/2026-10-05/hamsters'
DOWNLOADS = EVIDENCE / 'downloads'
ASSETS.mkdir(parents=True, exist_ok=True)
EVIDENCE.mkdir(parents=True, exist_ok=True)
DOWNLOADS.mkdir(parents=True, exist_ok=True)
SOURCE_URL='https://huggingface.co/datasets/allenai/objaverse/resolve/main/glbs/000-087/c6a24007915a4aa9ae47fd912191c7b4.glb'
SOURCE_SHA256='64556f56d059caae20ea3c4a9a3bdf081c99417b9ccb0153bb1aebff5c844b67'
source_file=DOWNLOADS/'asia_matusik_hamster.glb'
if not source_file.exists():urllib.request.urlretrieve(SOURCE_URL,source_file)
if hashlib.sha256(source_file.read_bytes()).hexdigest()!=SOURCE_SHA256:
    raise RuntimeError('Downloaded hamster source differs from the reviewed CC-BY-4.0 source.')

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def import_source(filename, x):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(DOWNLOADS / filename))
    objects = list(set(bpy.data.objects) - before)
    meshes = [o for o in objects if o.type == 'MESH']
    for o in meshes:
        matrix = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = matrix
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        o.select_set(False)
    for o in objects:
        if o.type != 'MESH':
            bpy.data.objects.remove(o, do_unlink=True)
    for o in meshes:
        lo = Vector((min(v.co.x for v in o.data.vertices),min(v.co.y for v in o.data.vertices),min(v.co.z for v in o.data.vertices)))
        hi = Vector((max(v.co.x for v in o.data.vertices),max(v.co.y for v in o.data.vertices),max(v.co.z for v in o.data.vertices)))
        print('SOURCE_BOUNDS', filename, tuple(lo), tuple(hi))
        size = hi - lo
        factor = 0.13 / max(size.x,size.y,size.z)
        for v in o.data.vertices:
            v.co = (v.co - Vector(((lo.x+hi.x)*.5,(lo.y+hi.y)*.5,lo.z))) * factor
        o.location.x = x
        mat = bpy.data.materials.new(filename)
        mat.diffuse_color = (.68,.49,.28,1)
        o.data.materials.clear()
        o.data.materials.append(mat)
        for p in o.data.polygons:p.use_smooth = True
    return meshes

mesh=import_source('asia_matusik_hamster.glb',0)[0]
mesh.name='HamsterCoat'
adj={v.index:set() for v in mesh.data.vertices}
for edge in mesh.data.edges:
    a,b=edge.vertices;adj[a].add(b);adj[b].add(a)
seen=set();features={}
for vertex in mesh.data.vertices:
    if vertex.index in seen:continue
    stack=[vertex.index];seen.add(vertex.index);component=[]
    while stack:
        index=stack.pop();component.append(index)
        for neighbour in adj[index]:
            if neighbour not in seen:seen.add(neighbour);stack.append(neighbour)
    center=sum((mesh.data.vertices[i].co for i in component),Vector())/len(component)
    feature='coat'
    if len(component) in (48,64) and center.y<-.05:feature='eye'
    elif len(component) in (71,42) and center.z>.05:
        feature='ear'
        # Soften pointed tips of the original downloaded ears into rounded lobes.
        for index in component:
            p=mesh.data.vertices[index].co
            if p.z>.060:p.z=.060+(p.z-.060)*.40
    elif center.z<.003:feature='paw'
    for index in component:features[index]=feature
# The source contains mirrored and overlapping UV islands across head/eyes.
# Repack islands before coat baking to prevent black-eye paint leaking onto fur.
bpy.context.view_layer.objects.active=mesh;mesh.select_set(True)
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(60),island_margin=.007)
bpy.ops.object.mode_set(mode='OBJECT');mesh.select_set(False)
# Original anatomy stays intact; coat is baked into the repacked source UVs.
material=bpy.data.materials.new('Golden hamster coat')
material.use_nodes=True
nodes=material.node_tree.nodes;links=material.node_tree.links
nodes.clear()
output=nodes.new('ShaderNodeOutputMaterial')
emission=nodes.new('ShaderNodeEmission')
color_attribute=nodes.new('ShaderNodeVertexColor');color_attribute.layer_name='Coat'
links.new(color_attribute.outputs['Color'],emission.inputs['Color'])
links.new(emission.outputs[0],output.inputs[0])
mesh.data.materials.clear();mesh.data.materials.append(material)
for old_color in list(mesh.data.color_attributes):
    mesh.data.color_attributes.remove(old_color)
colors=mesh.data.color_attributes.new(name='Coat',type='FLOAT_COLOR',domain='CORNER')
mesh.data.color_attributes.active_color_index=0
mesh.data.color_attributes.render_color_index=0
for loop in mesh.data.loops:
    p=mesh.data.vertices[loop.vertex_index].co
    # Cream underside, darker dorsal guard hairs and warm cheeks.
    belly=max(0,min(1,(.025-p.z)/.022))
    fleck=(math.sin(p.x*3400+math.sin(p.y*780)*2)+math.sin(p.z*2800-p.y*960))*.028
    gold=(.52+fleck,.285+fleck*.7,.102+fleck*.45)
    cream=(.89,.80,.62)
    color=tuple(gold[i]*(1-belly)+cream[i]*belly for i in range(3))
    # Nose and the modeled eyes: preserve the source geometry and paint regions.
    if p.y<-.061 and .013<p.z<.03:color=(.30,.105,.105)
    if features[loop.vertex_index]=='eye':color=(.007,.005,.004)
    if features[loop.vertex_index]=='ear':color=(.47,.21,.17)
    if features[loop.vertex_index]=='paw':color=(.59,.36,.29)
    colors.data[loop.index].color=(*color,1)
texture=bpy.data.images.new('HamsterCoat512',width=512,height=512)
texnode=nodes.new('ShaderNodeTexImage');texnode.image=texture
nodes.active=texnode
bpy.context.view_layer.objects.active=mesh
mesh.select_set(True)
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=1
# Preserve crisp feature colors in vertex attributes. This mesh has hundreds
# of small disconnected feature islands; a low-resolution color bake alone
# would smear black eyes into nearby islands. Texture supplies fine fur breakup.
coat_pixels=[]
for iy in range(512):
    for ix in range(512):
        fleck=.95+.025*math.sin(ix*.79+iy*2.1)+.012*math.sin(ix*1.77-iy*.38)
        coat_pixels.extend((fleck,fleck,fleck,1))
texture.pixels=coat_pixels
texture.filepath_raw=str(ASSETS/'hamster_coat.png');texture.file_format='PNG';texture.save()
nodes.clear()
output=nodes.new('ShaderNodeOutputMaterial')
bsdf=nodes.new('ShaderNodeBsdfPrincipled');bsdf.inputs['Roughness'].default_value=.88
texnode=nodes.new('ShaderNodeTexImage');texnode.image=texture
color_attribute=nodes.new('ShaderNodeVertexColor');color_attribute.layer_name='Coat'
mix=nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1
links.new(texnode.outputs['Color'],mix.inputs[1]);links.new(color_attribute.outputs['Color'],mix.inputs[2])
links.new(mix.outputs[0],bsdf.inputs['Base Color']);links.new(bsdf.outputs[0],output.inputs[0])
# A small tangent-space fur texture follows the repacked UVs. Short anisotropic
# strokes are deliberately subtle; giant noisy normals make a tiny pet look wet.
fur=bpy.data.images.new('ShortFurNormal',width=256,height=256)
pixels=[]
for iy in range(256):
    for ix in range(256):
        grain=math.sin(ix*.38+iy*2.9+math.sin(ix*.13)*2.3)
        cross=math.sin(ix*1.71+iy*.77)
        pixels.extend((.5+grain*.085,.5+cross*.040,.99,1))
fur.pixels=pixels
fur.colorspace_settings.name='Non-Color'
fur.filepath_raw=str(ASSETS/'hamster_fur_normal.png');fur.file_format='PNG';fur.save()
normal_tex=nodes.new('ShaderNodeTexImage');normal_tex.image=fur
normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.3
links.new(normal_tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],bsdf.inputs['Normal'])
mesh.select_set(False)

armature=bpy.data.armatures.new('HamsterSkeleton')
rig=bpy.data.objects.new('HamsterRig',armature)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
bones={
 'root':((0,0,.014),(0,0,.030),None),
 'body':((0,.015,.027),(0,-.020,.030),'root'),
 'head':((0,-.021,.030),(0,-.059,.029),'body'),
 'ear_L':((-.016,-.025,.053),(-.016,-.025,.063),'head'),
 'ear_R':((.016,-.025,.053),(.016,-.025,.063),'head'),
 'front_L':((-.017,-.028,.025),(-.020,-.034,.004),'body'),
 'front_R':((.017,-.028,.025),(.020,-.034,.004),'body'),
 'hind_L':((-.018,.033,.028),(-.020,.040,.004),'body'),
 'hind_R':((.018,.033,.028),(.020,.040,.004),'body'),
}
for name,(head,tail,parent) in bones.items():
    bone=armature.edit_bones.new(name);bone.head=head;bone.tail=tail
    if parent:bone.parent=armature.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
groups={name:mesh.vertex_groups.new(name=name) for name in bones}
for v in mesh.data.vertices:
    p=v.co;weights={'body':1.0}
    h=max(0,min(.98,(-p.y-.010)/.024)) if p.z>.016 else 0
    weights={'body':1-h,'head':h}
    if p.z<.025 and abs(p.x)>.010:
        leg=('front_' if p.y<-.007 else 'hind_')+('L' if p.x<0 else 'R')
        amount=max(0,min(.98,(.026-p.z)/.023))*max(0,min(1,(abs(p.x)-.009)/.009))
        weights={key:w*(1-amount) for key,w in weights.items()};weights[leg]=amount
    if p.z>.052 and p.y<-.010:
        ear='ear_L' if p.x<0 else 'ear_R'
        amount=max(0,min(.95,(p.z-.052)/.010))
        weights={key:w*(1-amount) for key,w in weights.items()};weights[ear]=amount
    for name,weight in weights.items():
        if weight>.0001:groups[name].add([v.index],weight,'REPLACE')
modifier=mesh.modifiers.new('Hamster skin','ARMATURE');modifier.object=rig
mesh.parent=rig
# Six fine tapered whisker ribbons are skinned to the head. They are 19 mm long
# at source scale and narrower than 0.3 mm, with no loose rigid-body geometry.
whisker_vertices=[];whisker_faces=[]
for side in [-1,1]:
    for index in [-1,0,1]:
        root=Vector((side*.007,-.059,.029+index*.0014))
        tip=Vector((side*.025,-.061+index*.003,.029+index*.0028))
        base=len(whisker_vertices)
        whisker_vertices.extend([tuple(root+Vector((0,0,.00012))),tuple(root-Vector((0,0,.00012))),tuple(tip)])
        whisker_faces.append((base,base+1,base+2))
whisker_data=bpy.data.meshes.new('Fine whiskers');whisker_data.from_pydata(whisker_vertices,[],whisker_faces)
whisker=bpy.data.objects.new('Whiskers',whisker_data);bpy.context.collection.objects.link(whisker)
whisker_material=bpy.data.materials.new('Whisker graphite');whisker_material.diffuse_color=(.075,.059,.040,1);whisker_material.use_nodes=True
whisker_material.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.075,.059,.040,1)
whisker_material.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.8
whisker_data.materials.append(whisker_material)
whisker.vertex_groups.new(name='head').add(list(range(len(whisker_vertices))),1,'REPLACE')
whisker.parent=rig;whisker.modifiers.new('Whisker skin','ARMATURE').object=rig
rig.animation_data_create()
scene.render.fps=30
clips=[('walk',24),('run',16),('idle_sniff',75),('idle_groom',110),('idle_rear',90),('idle_rest',150),('eat',100),('dig',70)]
for clip,frames in clips:
    action=bpy.data.actions.new(clip);rig.animation_data.action=action
    for frame in range(1,frames+2,2):
        phase=(frame-1)/frames*math.tau
        for bone in rig.pose.bones:
            bone.rotation_mode='XYZ';bone.rotation_euler=(0,0,0);bone.location=(0,0,0);bone.scale=(1,1,1)
        body=rig.pose.bones['body'];head=rig.pose.bones['head']
        if clip in ('walk','run'):
            amplitude=.56 if clip=='walk' else .78
            for i,name in enumerate(['front_L','front_R','hind_L','hind_R']):
                rig.pose.bones[name].rotation_euler.x=math.sin(phase+(0 if i in [0,3] else math.pi))*amplitude
            rig.pose.bones['root'].location.y=abs(math.sin(phase))*(.0022 if clip=='walk' else .0035)
            head.rotation_euler.x=math.sin(phase)*.085
            body.rotation_euler.z=math.sin(phase)*.060
        elif clip=='idle_sniff':
            head.rotation_euler.x=math.sin(phase*3)*.18
            head.rotation_euler.z=math.sin(phase)*.28
            for name in ['ear_L','ear_R']:rig.pose.bones[name].rotation_euler.x=math.sin(phase*4)*.28
        elif clip=='idle_groom':
            head.rotation_euler.x=.27+math.sin(phase*5)*.16
            for i,name in enumerate(['front_L','front_R']):
                rig.pose.bones[name].rotation_euler.x=-.42+math.sin(phase*5+i)*.14
                rig.pose.bones[name].rotation_euler.z=(-1 if i==0 else 1)*.055
            body.rotation_euler.x=-.13
        elif clip=='idle_rear':
            arch=max(0,math.sin(phase*.5))
            body.rotation_euler.x=-.84*arch
            head.rotation_euler.x=.24*arch
            for name in ['front_L','front_R']:rig.pose.bones[name].rotation_euler.x=-.08*arch
            rig.pose.bones['root'].location.y=.012*arch
        elif clip=='idle_rest':
            body.scale=(1+math.sin(phase)*.026,1+math.sin(phase)*.018,.88)
            head.rotation_euler.x=.15
            for name in ['front_L','front_R','hind_L','hind_R']:rig.pose.bones[name].rotation_euler.x=-.25
        elif clip=='eat':
            head.rotation_euler.x=.19+math.sin(phase*8)*.065
            for name in ['front_L','front_R']:rig.pose.bones[name].rotation_euler.x=-.42
        elif clip=='dig':
            head.rotation_euler.x=.20
            for i,name in enumerate(['front_L','front_R']):rig.pose.bones[name].rotation_euler.x=math.sin(phase*4+i*math.pi)*.38
        for bone in rig.pose.bones:
            for property in ('location','rotation_euler','scale'):bone.keyframe_insert(property,frame=frame,group=bone.name)
    # A named NLA track gives every clip a stable glTF animation name.
    rig.animation_data.action=None
    track=rig.animation_data.nla_tracks.new();track.name=clip
    strip=track.strips.new(clip,1,action);strip.extrapolation='NOTHING'
    track.mute=True

for pose_bone in rig.pose.bones:
    pose_bone.matrix_basis.identity()
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
mesh.select_set(True);whisker.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
scene.frame_start=1;scene.frame_end=151
bpy.ops.export_scene.gltf(filepath=str(ASSETS/'hamster.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_frame_range=False,export_skins=True,export_vertex_color='NAME',export_vertex_color_name='Coat',export_all_vertex_colors=False)
bpy.ops.wm.save_as_mainfile(filepath=str(EVIDENCE/'hamster-rig.blend'))

bpy.ops.object.camera_add(location=(.15,-.21,.105))
cam=bpy.context.object
cam.rotation_euler=(Vector((0,0,.033))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO';cam.data.ortho_scale=.17
bpy.context.scene.camera=cam
bpy.ops.object.light_add(type='AREA',location=(0,-.1,.4))
bpy.context.object.data.energy=12
bpy.context.object.data.shape='DISK';bpy.context.object.data.size=.4
bpy.context.scene.world.color=(.3,.3,.3)
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1400;scene.render.resolution_y=850;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.render.filepath=str(EVIDENCE/'hamster-preview.png')
bpy.ops.render.render(write_still=True)
report={'source':'Asia Matusik / Hamster','license':'CC-BY-4.0','source_url':'https://sketchfab.com/3d-models/hamster-c6a24007915a4aa9ae47fd912191c7b4','download_url':SOURCE_URL,'source_sha256':SOURCE_SHA256,'output_sha256':hashlib.sha256((ASSETS/'hamster.glb').read_bytes()).hexdigest(),'vertices':len(mesh.data.vertices)+len(whisker_vertices),'triangles':sum(len(p.vertices)-2 for p in mesh.data.polygons)+len(whisker_faces),'bones':list(bones),'animations':[name for name,_ in clips],'texture_resolution':[512,512],'normal_resolution':[256,256],'changes':'Engine scale normalization; rounded original ear tips; repacked non-overlapping UVs and golden coat bake; short-fur normal map; six fine head-skinned whisker ribbons; nine-bone quadruped skin; walk/run and four distinct idle clips plus eat/dig; original downloaded mesh retained.'}
(ASSETS/'provenance.json').write_text(json.dumps(report,indent=2))
(EVIDENCE/'asset-report.json').write_text(json.dumps(report,indent=2))
print('HAMSTER_ASSET',json.dumps(report))
