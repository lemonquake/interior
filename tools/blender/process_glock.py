"""The animated Glock 17 for the 0.10 hut drawer.

    blender -b --factory-startup -P tools/blender/process_glock.py [-- render]

Source: "[ FREE ] Rigged Semi-Auto Pistol G17" by nixo_design (CC BY 4.0, Sketchfab
0c7e4441d9a1432f9abb61911c95a8a2, via the Objaverse mirror: tools/assets/fetch_fields.py -> glock_g17_rigged).
Its parts are separate objects (frame, grip, slide, trigger, trigger safety, slide lock, magazine, a round) driven by
one 16-frame object animation: the trigger pulls, the slide cycles and the round is thrown out.

Keeps the parts and the animation (renamed "fire"), decimates the 100k-polygon grip and slide shells to a game
budget, scales the gun to 186 mm and centres it, and writes game/assets/models/story/glock17.glb.
`render` also writes a contact sheet of the animation to work/v10/glock/.
"""
import bpy, os, sys, math
from mathutils import Vector, Matrix

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, '.local', 'downloads', 'objaverse', 'glock_g17_rigged.glb')
DST = os.path.join(ROOT, 'game', 'assets', 'models', 'story', 'glock17.glb')
LENGTH = .2193         # gives a Glock 17's real 204 mm from tang to muzzle (0.31: it was 173 mm at .186)
PART_BUDGET = int(os.environ.get('GLOCK_BUDGET', '14000'))    # polygons per heavy shell

def world_bounds(objs):
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi

# The source's materials are flat light grey: paint it as a real Glock 17 - black polymer frame and grip,
# dark nitrided steel slide and small parts, a brass case and copper bullet for the ejected round.
FINISH = {
    'base_color_14': ((.022, .022, .024, 1), 0.0, .82),  # polymer frame / grip shells
    'BASE_COLOR': ((.03, .03, .032, 1), .12, .6),       # slide, trigger, magazine, small parts
    'metal': ((.07, .07, .075, 1), .85, .32),           # barrel, slide lock, guide rod
    'material': ((.05, .05, .05, 1), .6, .4),
    'Material.003': ((.78, .58, .26, 1), 1.0, .3),      # case
    'Material.004': ((.72, .42, .26, 1), 1.0, .35),     # bullet
}

def paint():
    for mat in bpy.data.materials:
        spec = FINISH.get(mat.name)
        if spec is None or not mat.use_nodes:
            continue
        bsdf = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
        if bsdf is None:
            continue
        for link in list(bsdf.inputs['Base Color'].links):
            mat.node_tree.links.remove(link)
        bsdf.inputs['Base Color'].default_value = spec[0]
        bsdf.inputs['Metallic'].default_value = spec[1]
        bsdf.inputs['Roughness'].default_value = spec[2]

def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    scene = bpy.context.scene
    scene.frame_set(0)
    meshes = [o for o in scene.objects if o.type == 'MESH']
    before = sum(len(o.data.polygons) for o in meshes)
    for o in meshes:
        n = len(o.data.polygons)
        if n > PART_BUDGET * 1.3:
            bpy.context.view_layer.objects.active = o
            mod = o.modifiers.new('thin', 'DECIMATE')
            mod.ratio = PART_BUDGET / n
            mod.use_collapse_triangulate = True
            with bpy.context.temp_override(object=o, active_object=o):
                bpy.ops.object.modifier_apply(modifier=mod.name)
            # The source's custom split normals don't survive the collapse (blotchy shading): rebuild them
            # from the new faces, smooth below 35 degrees, sharp creases above.
            with bpy.context.temp_override(object=o, active_object=o, selected_editable_objects=[o]):
                bpy.ops.mesh.customdata_custom_splitnormals_clear()
                bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    after = sum(len(o.data.polygons) for o in meshes)
    paint()
    # Scale and centre through the top empty, so the animated parts keep their relative motion.
    top = next(o for o in scene.objects if o.parent is None and o.type == 'EMPTY')
    lo, hi = world_bounds([o for o in meshes if 'Cylinder.004' not in (o.parent.name if o.parent else '')])
    size = hi - lo
    scale = LENGTH / max(size)
    centre = (lo + hi) / 2
    wrapper = bpy.data.objects.new('Glock17', None)
    scene.collection.objects.link(wrapper)
    top.parent = wrapper
    wrapper.matrix_world = Matrix.Scale(scale, 4) @ Matrix.Translation(-centre)
    bpy.context.view_layer.update()
    for action in bpy.data.actions:
        action.name = 'fire'
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=DST, export_format='GLB', export_yup=True, export_animations=True,
                              export_cameras=False, export_lights=False, use_selection=False)
    lo2, hi2 = world_bounds(meshes)
    print(f'GLOCK {before} -> {after} polygons, size {(hi2 - lo2).x:.3f} x {(hi2 - lo2).y:.3f} x {(hi2 - lo2).z:.3f} m, '
          f'{os.path.getsize(DST) // 1024} KB, frames {scene.frame_start}-{scene.frame_end}')
    if 'render' in argv:
        render(meshes)

def render(meshes):
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x, scene.render.resolution_y = 640, 400
    world = bpy.data.worlds.new('w')
    scene.world = world
    world.color = (.25, .25, .27)
    for rot, energy in (((.9, .2, .6), 6.0), ((-.6, -.3, 2.6), 3.0), ((1.4, 0, -1.6), 4.0)):
        sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
        sun.data.energy = energy
        scene.collection.objects.link(sun)
        sun.rotation_euler = rot
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    scene.collection.objects.link(cam)
    scene.camera = cam
    lo, hi = world_bounds(meshes)
    c = (lo + hi) / 2
    out = os.path.join(ROOT, 'work', 'v10', 'glock')
    os.makedirs(out, exist_ok=True)
    frames = [int(f) for f in os.environ.get('GLOCK_FRAMES', '0,3,5,8,11,16').split(',')]
    tag = os.environ.get('GLOCK_TAG', '')
    for side, offset in (('side', Vector((.30, 0, .02))), ('three', Vector((.2, .16, .1)))):
        cam.location = c + offset
        cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
        for f in frames:
            scene.frame_set(f)
            scene.render.filepath = os.path.join(out, f'anim{tag}_{side}_{f:02d}.png')
            bpy.ops.render.render(write_still=True)

main()
