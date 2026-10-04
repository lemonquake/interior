"""Run with Blender --background --python tools/build_room_study.py.

Builds actual procedural prop meshes for the Function review. It deliberately
does not export game assets or claim human approval. Blender coordinates: Z up.
"""
import bpy, math, json, shutil, random
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parent.parent
PKG = ROOT / 'room'
random.seed(28)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.render.engine = 'CYCLES'
scene.cycles.samples = 16
scene.cycles.use_denoising = True
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.world.color = (.35, .35, .35)
scene.view_settings.view_transform = 'AgX'

def material(name, color, rough=.6, metallic=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metallic
    return m

mats = {
 'wood': material('Warm oak', (.48,.25,.105), .42),
 'darkwood': material('Dark stained table wood', (.11,.042,.018), .34),
 'black': material('Black plastic and steel', (.016,.02,.022), .43),
 'cream': material('Ivory plastic', (.79,.74,.64), .45),
 'white': material('Warm white paint', (.87,.85,.79), .53),
 'brown': material('Brown woven upholstery', (.19,.092,.048), .85),
 'leather': material('Chocolate leather', (.065,.025,.018), .46),
 'pillow': material('Beige cushion', (.65,.53,.39), .95),
 'gray': material('Gray crib fabric', (.36,.38,.39), .9),
 'green': material('Plant foliage', (.055,.23,.026), .69),
 'red': material('Red petals', (.56,.015,.025), .57),
 'yellow': material('Yellow petals', (.9,.43,.006), .63),
 'purple': material('Purple petals', (.32,.035,.43), .68),
 'pink': material('Pink soft toy', (.79,.23,.42), .86),
 'glass': material('Clear acrylic', (.42,.61,.69), .18),
 'rug': material('Beige patterned rug', (.42,.37,.31), 1),
 'marble': material('Cream gold marble', (.86,.8,.67), .24),
 'paper': material('Photo paper', (.65,.42,.39), .8),
}
# Authored procedural material detail, with no private-photo editing.
for key, scale, strength in [('brown',160,.18),('pillow',110,.09),('rug',35,.22),('wood',5,.08)]:
    m=mats[key]; nt=m.node_tree; p=nt.nodes.get('Principled BSDF')
    noise=nt.nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value=scale
    bump=nt.nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=strength
    nt.links.new(noise.outputs['Fac'],bump.inputs['Height']); nt.links.new(bump.outputs['Normal'],p.inputs['Normal'])
nt=mats['marble'].node_tree; p=nt.nodes.get('Principled BSDF')
noise=nt.nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value=2.7; noise.inputs['Detail'].default_value=5
wave=nt.nodes.new('ShaderNodeTexWave'); wave.wave_type='BANDS'; wave.bands_direction='DIAGONAL'; wave.inputs['Scale'].default_value=3; wave.inputs['Distortion'].default_value=8
tex=nt.nodes.new('ShaderNodeTexCoord'); nt.links.new(tex.outputs['Generated'],wave.inputs['Vector'])
ramp=nt.nodes.new('ShaderNodeValToRGB'); ramp.color_ramp.elements[0].position=.32; ramp.color_ramp.elements[0].color=(.15,.105,.058,1); ramp.color_ramp.elements[1].position=.46; ramp.color_ramp.elements[1].color=(.87,.82,.72,1)
nt.links.new(wave.outputs['Color'],ramp.inputs[0]); nt.links.new(ramp.outputs[0],p.inputs['Base Color'])

current=[]
def finish(o,name,mat):
    o.name=name; o.data.materials.append(mats[mat]); current.append(o); return o
def box(name,loc,size,mat,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Rounded edge','BEVEL'); mod.width=bevel; mod.segments=3
        bpy.ops.object.modifier_apply(modifier=mod.name)
        o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return finish(o,name,mat)
def cyl(name,loc,r,depth,mat,rot=None,vertices=20):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=loc)
    o=bpy.context.object
    if rot:o.rotation_euler=rot
    return finish(o,name,mat)
def sphere(name,loc,size,mat,segments=16,rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=loc)
    o=bpy.context.object; o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for poly in o.data.polygons:poly.use_smooth=True
    return finish(o,name,mat)
def rod(name,a,b,r,mat,vertices=10):
    a,b=Vector(a),Vector(b); o=cyl(name,(a+b)*.5,r,(b-a).length,mat,vertices=vertices)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler(); return o
def ring(name,loc,major,minor,mat,rot=(0,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=6,location=loc,major_radius=major,minor_radius=minor,rotation=rot)
    return finish(bpy.context.object,name,mat)
def mesh_group(name,fn):
    global current
    current=[]; fn()
    bpy.ops.object.select_all(action='DESELECT')
    for o in current:o.select_set(True)
    bpy.context.view_layer.objects.active=current[0]
    bpy.ops.object.join(); o=bpy.context.object; o.name=name
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    scene.cursor.location=(0,0,0); bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    o['asset_id']=name; o['author']='Aljay Leodones / procedural Blender source'
    o['review_stage']='Function study'; return o

def sofa(leather=False):
    mat='leather' if leather else 'brown'
    box('Base',(0,0,.25),(1.95,.84,.32),mat,.065)
    for x in (-.57,0,.57):box('Seat cushion',(x,-.075,.49),(.57,.65,.21),mat,.075)
    box('Back',(0,.36,.73),(1.86,.2,.68),mat,.085)
    for x in (-.96,.96):box('Arm',(x,0,.53),(.23,.92,.67),mat,.08)
    for x in (-.79,.79):
        for y in (-.30,.30):cyl('Foot',(x,y,.07),.045,.14,'darkwood')
    for x in (-.51,.51):
        o=box('Loose cushion',(x,.13,.74),(.57,.16,.48),'pillow',.09); o.rotation_euler.x=math.radians(-12)
def table():
    box('Marble top',(0,0,.8),(1.65,1.32,.07),'marble',.022)
    box('Bottom plinth',(0,0,.06),(.75,.65,.12),'darkwood',.023)
    box('Pedestal',(0,0,.42),(.49,.46,.65),'darkwood',.02)
    for y in (-.25,.25):
        rod('Diagonal trim',(-.23,y,.14),(.23,y,.72),.018,'wood')
        rod('Diagonal trim',(.23,y,.14),(-.23,y,.72),.018,'wood')
def console():
    box('Oak case',(0,0,.29),(2.7,.47,.57),'wood',.012)
    for x in (-.97,.97):box('Door',(x,-.246,.30),(.73,.025,.46),'white',.006); sphere('Knob',(x,-.28,.30),(.017,.017,.017),'cream')
    box('Middle drawer',(0,-.246,.18),(1.1,.025,.24),'white',.006)
    box('Black open shelf',(0,-.247,.40),(1.09,.026,.17),'black')
    for x in (-.31,.27):box('Books',(x,-.21,.37),(.33,.20,.032),'cream')
def television():
    box('TV housing',(0,0,0),(1.48,.074,.865),'black',.016)
    box('Dark glossy screen',(0,-.041,0),(1.437,.009,.807),'black',.004)
def fan():
    cyl('Base',(0,0,.025),.23,.05,'black',vertices=32)
    cyl('Stand',(0,0,.60),.025,1.16,'black')
    center=(0,-.025,1.3)
    for i in range(6):ring('Guard ring',(0,-.10,1.3),.045+i*.045,.004,'black',(math.pi/2,0,0))
    ring('Outer guard',center,.30,.012,'black',(math.pi/2,0,0))
    for i in range(24):
        t=2*math.pi*i/24; rod('Guard spoke',(0,-.105,1.3),(.3*math.cos(t),-.085,1.3+.3*math.sin(t)),.003,'black',6)
    cyl('Motor',(0,.03,1.3),.073,.12,'black',(math.pi/2,0,0))
    for i in range(3):
        t=i*2*math.pi/3; o=sphere('Blade',(.13*math.cos(t),-.035,1.3+.13*math.sin(t)),(.13,.015,.067),'gray'); o.rotation_euler.y=-t
    cyl('Front badge',(0,-.12,1.3),.055,.013,'black',(math.pi/2,0,0))
def plant():
    bpy.ops.mesh.primitive_cone_add(vertices=24,radius1=.078,radius2=.105,depth=.16,location=(0,0,.08)); finish(bpy.context.object,'Ribbed white pot','white')
    cyl('Soil',(0,0,.16),.092,.012,'darkwood')
    for i in range(12):
        t=i*2.399; h=.25+(i%4)*.05; x=.11*math.cos(t); y=.11*math.sin(t)
        rod('Stem',(0,0,.14),(x,y,h),.003,'green',6)
        o=sphere('Leaf',(x,y,h),(.07,.027,.01),'green'); o.rotation_euler=(.4,t,.4)
def flowers(color='red'):
    bpy.ops.mesh.primitive_cone_add(vertices=24,radius1=.065,radius2=.09,depth=.17,location=(0,0,.085)); finish(bpy.context.object,'Vase','white')
    for i in range(9):
        t=i*2.399; x=.095*math.cos(t); y=.095*math.sin(t); h=.30+(i%3)*.028
        rod('Flower stem',(0,0,.15),(x,y,h),.003,'green',6)
        sphere('Leaf',(x*.7,y*.7,h*.72),(.06,.025,.016),'green',8,4)
        for j in range(5):
            a=j*math.tau/5; sphere('Petal',(x+.022*math.cos(a),y+.022*math.sin(a),h),(.023,.021,.014),color,8,4)
        sphere('Center',(x,y,h+.009),(.009,.009,.009),'yellow',8,4)
def frame():
    box('Frame',(0,0,0),(.28,.035,.35),'darkwood',.005)
    box('Mat',(0,-.021,0),(.248,.008,.317),'cream')
    box('Photo',(0,-.027,0),(.195,.006,.264),'paper')
def shelf():
    box('Shelf',(0,0,.02),(.59,.24,.04),'white',.009)
    for x in (-.29,.29):
        rod('Corner upright',(x,-.11,.02),(x,-.11,.20),.012,'white')
        sphere('Finial',(x,-.11,.21),(.018,.018,.022),'white')
    rod('Front rail',(-.29,-.11,.12),(.29,-.11,.12),.009,'white')
def clock():
    box('Clock body',(0,0,.10),(.39,.08,.20),'black',.012)
    # Mesh digits; the mystery uses the visible time in the supplied photo.
    curve=bpy.data.curves.new('Clock digits','FONT'); curve.body='5:08'; curve.size=.13; curve.align_x='CENTER'; curve.extrude=.001
    o=bpy.data.objects.new('5:08',curve); bpy.context.collection.objects.link(o); o.location=(0,-.045,.062); o.rotation_euler=(math.pi/2,0,0)
    o.data.materials.append(mats['purple']); bpy.context.view_layer.objects.active=o; o.select_set(True); bpy.ops.object.convert(target='MESH'); current.append(bpy.context.object)
def desk():
    for z in (.06,.72,1.38):box('Desk shelf',(0,0,z),(1.1,.49,.035),'black',.012)
    for x in (-.53,.53):
        for y in (-.22,.22):rod('Steel upright',(x,y,.025),(x,y,1.45),.018,'black')
    box('Keyboard',(0,-.11,.75),(.43,.14,.022),'black',.005)
    cyl('Mouse pad',(.37,-.11,.75),.07,.012,'gray')
def monitor():
    box('Screen',(0,0,.25),(.61,.035,.36),'black',.009)
    rod('Stand',(0,.03,.04),(0,.03,.22),.023,'black')
    box('Foot',(0,0,.015),(.22,.16,.03),'black',.006)
def tower():
    box('Computer tower',(0,0,.23),(.22,.39,.46),'black',.012)
    box('Transparent side',(-.116,0,.23),(.009,.35,.41),'glass')
    for z in (.13,.32):ring('Cooling fan',(-.123,.015,z),.067,.012,'gray',(0,math.pi/2,0))
    box('Rear sockets',(0,.201,.29),(.15,.012,.24),'cream')
def crib():
    for x in (-.46,.46):
        for y in (-.30,.30):
            rod('Leg',(x,y,.06),(x*.8,y*.8,.83),.018,'cream')
            cyl('Caster',(x,y,.05),.044,.029,'black',(math.pi/2,0,0),16)
    box('Lower basket',(0,0,.30),(.85,.54,.17),'gray',.06)
    box('Crib mattress',(0,0,.66),(.93,.57,.10),'white',.055)
    for y in (-.33,.33):box('Fabric side',(0,y,.78),(1.02,.052,.29),'gray',.055)
    for x in (-.5,.5):box('Fabric end',(x,0,.78),(.052,.65,.29),'gray',.045)
    for y in (-.345,.345):rod('Strap',(0,y,.61),(0,y,.91),.022,'cream')
    sphere('Toy',(0,0,.77),(.11,.065,.058),'pink')
def highchair():
    for x in (-.23,.23):
        for y in (-.23,.23):rod('Leg',(x*1.3,y*1.3,.06),(x,y,.94),.027,'white')
    box('Seat',(0,0,.63),(.45,.45,.07),'cream',.045)
    box('Rattan back',(0,.23,.85),(.46,.055,.41),'wood',.055)
    for x in range(-5,6):
        for z in range(6):cyl('Rattan holes',(x*.035,.197,.72+z*.05),.007,.003,'darkwood',(math.pi/2,0,0),6)
    box('Tray',(0,-.23,.81),(.56,.34,.055),'white',.065)
    box('Footrest',(0,-.26,.40),(.39,.11,.038),'white',.012)
def cage():
    for z in (.035,.48,.94,1.4):box('Shelf',(0,0,z),(.65,.49,.03),'black')
    for x in (-.30,.30):
        for y in (-.22,.22):rod('Shelf post',(x,y,.025),(x,y,1.46),.023,'black')
    for z in (.70,1.16,1.61):
        box('Enclosure',(0,0,z),(.58,.42,.42),'glass',.008)
        box('Bedding',(0,0,z-.18),(.55,.40,.046),'wood')
        ring('Exercise wheel',(0,-.05,z),.12,.022,'gray',(math.pi/2,0,0))
        for x in (-.24,.24):box('Corner rail',(x,-.21,z),(.022,.018,.41),'white')
    for z in (.93,1.39):
        cyl('Tube',(.38,0,z),.065,.21,'cream',(0,math.pi/2,0)); ring('Tube ring',(.43,0,z),.069,.009,'cream',(0,math.pi/2,0))
    cyl('Water bottle',(-.17,-.25,1.66),.043,.23,'glass'); cyl('Blue bottle cap',(-.17,-.25,1.79),.05,.02,'gray')
def fishbowl():
    sphere('Round bowl',(0,0,.145),(.19,.19,.16),'glass')
    ring('Glass rim',(0,0,.255),.125,.008,'glass')
    sphere('Water',(0,0,.12),(.177,.177,.125),'yellow')
    for i in range(5):rod('Water plant',(.07*math.cos(i),.07*math.sin(i),.02),(.09*math.cos(i),.07*math.sin(i),.2),.008,'green')
def guitar():
    sphere('Bass lower body',(0,0,.28),(.17,.06,.24),'black')
    sphere('Bass upper body',(.05,0,.43),(.125,.052,.14),'black')
    box('Maple neck',(0,0,.78),(.046,.027,.69),'wood',.006)
    box('Headstock',(0,0,1.16),(.065,.035,.16),'wood',.008)
    for x in (-.012,-.004,.004,.012):rod('String',(x,-.066,.15),(x,-.019,1.22),.001,'cream',4)
    for z in (.28,.36):box('Pickup',(0,-.063,z),(.07,.012,.027),'gray')
    for z in (1.12,1.16,1.20):sphere('Tuning peg',(.053,0,z),(.017,.017,.017),'cream')
def tissue():
    box('Tissue holder',(0,0,.05),(.24,.15,.1),'wood',.008)
    box('Tissue',(0,0,.12),(.09,.025,.07),'white',.007)
def tray():cyl('Woven round tray',(0,0,.022),.26,.044,'wood',vertices=40); ring('Tray rim',(0,0,.048),.25,.012,'wood')
def storage():box('Storage bin',(0,0,.105),(.38,.31,.21),'gray',.013); box('Handle',(0,-.16,.145),(.12,.009,.025),'black')

definitions = [
 ('fabric_sofa',sofa,(2.18,.96,1.08),'floor',3600,'Brown fabric sofa'),
 ('leather_sofa',lambda:sofa(True),(2.18,.96,1.08),'floor',3600,'Dark leather sofa'),
 ('marble_table',table,(1.65,1.32,.84),'floor',1500,'Marble top pedestal table'),
 ('tv_console',console,(2.7,.5,.58),'floor',1800,'Oak and white TV cabinet'),
 ('television',television,(1.48,.083,.865),'wall',400,'Wall mounted television'),
 ('standing_fan',fan,(.60,.55,1.60),'floor',5000,'Black pedestal fan'),
 ('potted_plant',plant,(.36,.36,.43),'freestanding',3800,'Small leafy plant in white pot'),
 ('red_flowers',flowers,(.30,.30,.37),'freestanding',4200,'Red flowers in white vase'),
 ('purple_flowers',lambda:flowers('purple'),(.30,.30,.37),'freestanding',4200,'Purple flowers in white pot'),
 ('yellow_flowers',lambda:flowers('yellow'),(.30,.30,.37),'freestanding',4200,'Yellow flowers in white pot'),
 ('photo_frame',frame,(.28,.04,.35),'wall',450,'Framed family photograph'),
 ('wall_shelf',shelf,(.61,.25,.24),'wall',1100,'Small white shelf with rail'),
 ('digital_clock',clock,(.39,.09,.20),'freestanding',1500,'Digital clock showing 5:08'),
 ('computer_desk',desk,(1.14,.53,1.45),'floor',1600,'Black metal computer shelving desk'),
 ('monitor',monitor,(.61,.16,.43),'freestanding',800,'Computer monitor'),
 ('computer_tower',tower,(.25,.41,.47),'freestanding',1300,'Computer tower with exposed cooling fans'),
 ('baby_crib',crib,(1.07,.70,.97),'floor',3400,'Gray bedside crib with straps and casters'),
 ('high_chair',highchair,(.65,.72,1.07),'floor',3500,'White and rattan high chair'),
 ('pet_enclosure',cage,(.83,.52,1.87),'floor',6200,'Three level acrylic pet enclosure on black rack'),
 ('fish_bowl',fishbowl,(.40,.40,.32),'freestanding',2000,'Round fish bowl with plants'),
 ('bass_guitar',guitar,(.40,.14,1.26),'freestanding',1700,'Black bass guitar with maple neck'),
 ('tissue_box',tissue,(.24,.15,.16),'freestanding',400,'Wood tissue holder'),
 ('woven_tray',tray,(.54,.54,.07),'freestanding',1200,'Round woven tray'),
 ('storage_bin',storage,(.38,.33,.22),'freestanding',400,'Gray desk storage bin'),
]
library={name:mesh_group(name,fn) for name,fn,*_ in definitions}
# In a separate collection, preserve the same actual geometry used in the plans.
lib_collection=bpy.data.collections.new('Prop mesh library'); scene.collection.children.link(lib_collection)
for o in library.values():
    for c in list(o.users_collection):c.objects.unlink(o)
    lib_collection.objects.link(o); o.hide_render=True; o.hide_set(True)

instances=[]
def place(asset,x,y,z,angle=0,id=None,scale=1):
    source=library[asset]; o=source.copy(); o.data=source.data; scene.collection.objects.link(o)
    o.hide_render=False; o.hide_set(False); o.name=id or asset+'_'+str(len(instances)); o.location=(x,y,z); o.rotation_euler.z=math.radians(angle); o.scale=(scale,)*3
    instances.append(dict(id=o.name,assetId=asset,location=[x,y,z],rotationDegrees=[0,0,angle],scale=[scale]*3,meshObject=o.name))
    return o

place('fabric_sofa',-2.08,-.45,0,-90)
place('leather_sofa',.20,-2.21,0,180)
place('marble_table',-.65,-.15,0)
place('tv_console',-.55,2.42,.1)
place('television',-.55,2.60,1.77)
place('standing_fan',1.03,1.35,0)
place('computer_desk',2.17,2.15,0)
place('monitor',2.17,2.20,.74)
place('computer_tower',2.09,2.20,1.40)
place('baby_crib',2.05,.99,0)
place('high_chair',2.89,.77,0)
place('pet_enclosure',-2.97,1.11,0)
place('fish_bowl',-2.97,1.1,.49)
place('bass_guitar',2.98,1.94,0,-18)
place('woven_tray',-.65,-.14,.843)
place('potted_plant',-.53,-.14,.89)
place('tissue_box',-.81,-.21,.89)
place('digital_clock',-.55,2.34,.69)
place('red_flowers',-1.58,2.34,.69)
place('photo_frame',-1.13,2.29,.93)
place('purple_flowers',.45,2.32,.69)
for x,z,flower in [(-2.15,2.35,'yellow_flowers'),(-2.10,1.72,'potted_plant'),(1.21,2.26,'yellow_flowers'),(1.24,1.71,'purple_flowers')]:
    place('wall_shelf',x,2.50,z); place(flower,x,2.5,z+.043)
for x,z in [(1.96,2.46),(2.42,2.49),(2.82,2.16),(-1.12,2.64),(.35,2.65)]:place('photo_frame',x,2.61,z)
for x,z in [(1.11,1.34),(1.13,.87)]:place('photo_frame',x,2.40,z)
for x in (2.58,2.76):place('storage_bin',x,2.36,.12)
for x in (2.70,3.05):place('potted_plant',x,2.43,1.14,scale=.7)

shell=[]
current=[]
shell.append(box('Floor',(0,0,-.10),(6.6,5.4,.20),'marble'))
shell.append(box('Back wall',(0,2.8,1.45),(6.8,.20,2.9),'wood'))
shell.append(box('Left wall',(-3.4,0,1.45),(.20,5.8,2.9),'white'))
shell.append(box('Right wall',(3.4,0,1.45),(.20,5.8,2.9),'white'))
shell.append(box('Rear wall',(0,-2.8,1.45),(6.8,.20,2.9),'white'))
shell.append(box('Ceiling',(0,0,3.0),(6.8,5.8,.20),'white'))
details=[]
details.append(box('TV marble wall panel',(-.55,2.678,1.45),(2.65,.033,2.9),'marble'))
for i in range(85):
    x=-3.27+i*.0775
    if -1.89<x<.79:continue
    details.append(box('Oak vertical slat',(x,2.663,1.45),(.043,.036,2.9),'wood',.003))
details.append(box('Rug',(-.55,-.65,.005),(3.05,2.65,.01),'rug',.015))
for x in range(7):
    for y in range(6):
        if x<6:details.append(box('Tile joint',(-3.0+x,0,.002),(.003,5.4,.002),'cream'))
        if y<5:details.append(box('Tile joint',(0,-2.5+y,.002),(6.6,.003,.002),'cream'))

# Shared, explicit fixture manifest; no unexplained floating ceiling ornaments.
fixtures=[dict(id='ceiling-center',type='area',location=[0,0,2.88],watts=300,size=4),dict(id='ceiling-tv',type='area',location=[-.5,1.8,2.85],watts=180,size=2)]
for f in fixtures:
    data=bpy.data.lights.new(f['id'],'AREA'); data.energy=f['watts']; data.shape='DISK'; data.size=f['size']
    o=bpy.data.objects.new(f['id'],data); scene.collection.objects.link(o); o.location=f['location']
    details.append(box(f['id']+' fixture',(f['location'][0],f['location'][1],2.897),(.55,.55,.012),'white',.015))

camera_data=bpy.data.cameras.new('Review camera'); cam=bpy.data.objects.new('Review camera',camera_data); scene.collection.objects.link(cam); scene.camera=cam
def aim(loc,target,ortho=None):
    cam.location=loc; cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    camera_data.type='ORTHO' if ortho else 'PERSP'
    if ortho:camera_data.ortho_scale=ortho
    else:camera_data.lens=22
def render(path,w=1200,h=800):
    scene.render.resolution_x=w; scene.render.resolution_y=h; scene.render.filepath=str(PKG/path); bpy.ops.render.render(write_still=True)

# Layout preview; explicitly a Function study, not final Form evidence.
shell[4].hide_render=True; shell[5].hide_render=True
aim((2.2,-3.55,1.80),(-.45,1.6,1.20))
render('renders/layout-study.png',1440,900)
for o in shell:o.hide_render=True
# Grayscale engineering projections of evaluated actual meshes.
clay=material('Engineering gray',(.43,.43,.43),1)
scene.view_layers[0].material_override=clay
scene.world.color=(1,1,1); scene.render.film_transparent=True
aim((0,0,12),(0,0,0),7.35)
for o in details:
    if 'fixture' in o.name:o.hide_render=True
render('plans/lower-room.png',1400,1200)
for i in instances:bpy.data.objects[i['meshObject']].hide_render=True
for o in details:o.hide_render=True
for o in details:
    if 'fixture' in o.name:o.hide_render=False
render('plans/reflected-ceiling.png',1400,1200)
for o in details:o.hide_render=True
for i in instances:
    o=bpy.data.objects[i['meshObject']]; o.hide_render=False
    if i['location'][1]<2.0:o.hide_render=True
for o in details:
    if 'slat' in o.name or 'wall panel' in o.name:o.hide_render=False
aim((0,-12,1.45),(0,2.7,1.45),7.35)
render('plans/tv-wall-elevation.png',1400,650)
for i in instances:bpy.data.objects[i['meshObject']].hide_render=True
for o in details:o.hide_render=True
scene.render.film_transparent=False; scene.view_layers[0].material_override=None; scene.world.color=(.6,.6,.6)
for name,_,dims,*_ in definitions:
    o=library[name]; o.hide_set(False); o.hide_render=False
    half=max(dims); aim((half*1.9,-half*2.4,half*1.55),(0,0,dims[2]*.42),half*1.55)
    render('images/'+name+'.png',420,420)
    o.hide_render=True; o.hide_set(True)

# Restore the authored layout study for review in Blender.
for o in shell:o.hide_render=False
for o in details:o.hide_render=False
for i in instances:bpy.data.objects[i['meshObject']].hide_render=False
aim((2.2,-3.55,1.80),(-.45,1.6,1.20)); camera_data.type='PERSP'
scene.render.film_transparent=False
scene.world.color=(.35,.35,.35)
scene.render.resolution_x=1440; scene.render.resolution_y=900
scene['review_status']='Function pending human approval'
bpy.ops.wm.save_as_mainfile(filepath=str(PKG/'living_room_study.blend'))

def write(name,d): (PKG/name).write_text(json.dumps(d,indent=2),encoding='utf-8')
counts={name:sum(i['assetId']==name for i in instances) for name in library}
assetdocs=[]
for name,_,dims,face,polys,description in definitions:
    assetdocs.append(dict(id=name,function='Living room furnishing and physics interaction',description=description,**{'class':'hero' if name=='television' else 'reusable'},dimensionsMeters=list(dims),attachmentFace=face,semanticFront='negative-y',intendedInstances=counts[name],targetPolycount=polys,rejectionCriteria=['Unsupported floating parts','Silhouette differs from photo','Surface intersects movement aisle','Excessive triangle count'],image=dict(source='images/'+name+'.png',generator='Blender 5.2.1 procedural mesh studio render',prompt=description+'; isolated complete mesh, neutral three quarter studio view, all supports visible',approved=False,approvedBy=None),sourceMethod='procedural-blender',attempts=[]))
write('props.json',dict(schema='game-room.prop-manifest.v1',roomId='interior-living-room',generation=dict(provider='procedural-blender',apiModel=None,pricingSource=None,pricingVerifiedAt=None,creditsPerTexturedTask=0,hardCreditCeiling=0,maxChargedAttemptsPerAsset=2,reason='Free custom mesh workflow explicitly requested; Meshy is unused.'),assets=assetdocs))
write('room-layout.json',dict(schema='game-room.layout.v1',roomId='interior-living-room',units='meters',coordinateSystem='Blender Z up; +Y faces TV wall',surfaces=[dict(id=o.name,location=list(o.location),dimensions=list(o.dimensions),thicknessMeters=.2) for o in shell],instances=instances,fixtures=fixtures,circulation=dict(playerRadiusMeters=.24,playerHeightMeters=1.70,spawn=[.45,-1.3,0],mainAisle='Right of table, between sofa and crib',minClearWidthMeters=.65),estimated=True))
write('room-brief.json',dict(schema='game-room.room-brief.v1',roomId='interior-living-room',family='gameplay-room',purpose='Recreate the photographed living room as a physics mystery game',runtimeSurface='Godot 4.7.2 Windows x86_64 / Android arm64 Compatibility',boundsMeters=[6.6,5.4,2.9],measurementStatus='Estimated dimensions approved by owner; unseen rear walls and ceiling inferred',hero=dict(id='television',role='Primary visual focus and final mystery console',reservedBoundsMeters=[1.7,.35,1.0]),symmetry=dict(mode='none',order=1,appliesTo=[],exceptions=['Asymmetric existing home layout reproduced from reference']),productionCamera=dict(viewport=[1440,900],verticalFovDegrees=75,location=[2.2,-3.55,1.8],target=[-.45,1.6,1.2]),environment=dict(type='none'),performanceBudget=dict(maxSceneTriangles=160000,maxVLowBytes=12000000,maxHighTextureBytes=64000000,targetFpsDesktop=[60,120],targetFpsMobile=60,lowMobileRenderHeight=540,maxAwakeRigidBodies=16,lighting='Static base illumination; dynamic shadows off on low'),creditBudget=dict(maximumCredits=0),artifacts=dict(floorPlan='plans/lower-room.png',reflectedCeilingPlan='plans/reflected-ceiling.png',planMetadata='plan-metadata.json',visualTarget='images/reference.png',openingContactSheet='masks/openings-contact.png',wallElevations=['plans/tv-wall-elevation.png'])))
write('plan-metadata.json',dict(schema='game-room.plan-metadata.v1',roomId='interior-living-room',style='monochrome-engineering',projectionSource='actual-meshes',layers=['lower-room','reflected-ceiling'],semanticLabelsOutsideImage=True,aiInspirationIncluded=False,coverage=['room-outline','cutouts','openings','exterior-apron','main-sign','ingress-props','floor-markers','barriers','columns','circulation','placed-features'],features=instances,notApplicable=dict(cutouts='None visible',openings='None visible',exteriorApron='Not shown; closed room initial spawn',mainSign='Existing home has none',ingressProps='Not shown',floorMarkers='No artificial floor markers',columns='None visible'),roomOutline=[[-3.3,-2.7],[3.3,-2.7],[3.3,2.7],[-3.3,2.7]],ceiling='Inferred plain white 2.9 m ceiling with two flush light fixtures; not evidenced by photo'))
write('openings.json',dict(schema='game-room.opening-schedule.v1',roomId='interior-living-room',openings=[],primaryArrival=dict(openingId=None,exception='Single photographed room: no doorway visible. Player starts inside; do not invent visible architecture. Rear-wall survey pending.')))
write('milestone-reviews.json',dict(schema='game-room.milestone-reviews.v1',roomId='interior-living-room',function=dict(status='pending',approvedBy=None,approvedAt=None,evidence=['renders/layout-study.png','plans/lower-room.png','plans/reflected-ceiling.png','plans/tv-wall-elevation.png','images/prop-contact-sheet.jpg'],strangestElement='Pet enclosure tubes: model includes visible supports and full acrylic enclosure; unseen connections remain estimates.'),form=dict(status='pending',approvedBy=None,approvedAt=None,evidence=[]),runtime=dict(status='pending',approvedBy=None,approvedAt=None,evidence=[])))
write('final-report.json',dict(schema='game-room.room-final-report.v1',roomId='interior-living-room',gates=dict(function=False,form=False,runtime=False),formChecks={},runtimeChecks={},reviewRenders={},limitations=['Single photograph; estimated dimensions','No final Form construction or runtime room exports before required human reviews','Upstream validator hardcodes paid Meshy assets; procedural adaptation recorded separately']))
write('mesh-statistics.json',dict(assets={name:dict(vertices=len(o.data.vertices),triangles=sum(len(p.vertices)-2 for p in o.data.polygons)) for name,o in library.items()},instanceCount=len(instances)))
print('FUNCTION_STUDY_WRITTEN',str(PKG))
