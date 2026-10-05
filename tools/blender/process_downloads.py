"""Turn the downloaded Poly Haven / Sketchfab models into game-ready GLBs.

    blender -b --factory-startup -P tools/blender/process_downloads.py [-- name ...]

Reads .local/downloads/{polyhaven,objaverse}/ (see tools/assets/fetch_*.py) and writes
game/assets/models/<group>/<name>.glb. Every model is joined into one object, scaled to a
real-world size (longest dimension in metres), re-pivoted to its bottom centre (trees keep
their authored trunk origin) and, where needed, thinned: leaf cards are removed island by
island and the survivors enlarged so the canopy keeps its volume; bark is decimated.
Godot generates distance LODs on import.
"""
import bpy, bmesh, os, sys, math, random
from mathutils import Vector, Matrix

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PH = os.path.join(ROOT, '.local', 'downloads', 'polyhaven', 'models')
OBJ = os.path.join(ROOT, '.local', 'downloads', 'objaverse')
OUT = os.path.join(ROOT, 'game', 'assets', 'models')

def ph(name): return os.path.join(PH, name, name + '.gltf')
def ob(name): return os.path.join(OBJ, name + '.glb')

# size: longest dimension in metres (None keeps the authored scale).
# leaves / other: triangle budgets for the leaf-card and the remaining (bark) materials.
ASSETS = {
    # Studio instruments and gear (Sketchfab, CC-BY).
    'guitar_ibanez': dict(src=ob('guitar_ibanez'), group='studio', size=.99),
    'guitar_sg': dict(src=ob('guitar_sg'), group='studio', size=.99),
    'guitar_lespaul': dict(src=ob('guitar_lespaul'), group='studio', size=1.0),
    'guitar_acoustic_a': dict(src=ob('guitar_acoustic_a'), group='studio', size=1.02, other=60000),
    'guitar_acoustic_b': dict(src=ob('guitar_acoustic_b'), group='studio', size=1.02),
    'bass_precision': dict(src=ob('bass_precision'), group='studio', size=None),
    'drum_kit': dict(src=ob('drum_kit'), group='studio', size=1.75),
    'synth_wood': dict(src=ob('synth_wood'), group='studio', size=.78),
    'synth_b': dict(src=ob('synth_b'), group='studio', size=1.02),
    'midi_controller': dict(src=ob('midi_controller'), group='studio', size=.78),
    'amp_marshall': dict(src=ob('amp_marshall'), group='studio', size=.41),
    'amp_orange': dict(src=ob('amp_orange'), group='studio', size=.42),
    'audio_interface': dict(src=ob('audio_interface'), group='studio', size=.18, other=20000),
    'studio_monitor_krk': dict(src=ob('studio_monitor_krk'), group='studio', size=.29, other=40000),
    'mic_boom_stand': dict(src=ob('mic_boom_stand'), group='studio', size=None),
    'headphones_sony': dict(src=ob('headphones_sony'), group='studio', size=None),
    'gaming_chair': dict(src=ob('gaming_chair'), group='studio', size=1.3),
    'guitar_stand': dict(src=ob('guitar_stand'), group='studio', size=.75),
    # The desk set is split into desk, monitor, PC tower, keyboard and mouse (object names).
    'gaming_desk': dict(src=ob('monitor_curved_pc'), group='studio', size=None, keep=['Object_2', 'Object_3', 'Object_4']),
    'gaming_monitor': dict(src=ob('monitor_curved_pc'), group='studio', size=None, keep=['Object_5', 'Object_6']),
    'gaming_pc': dict(src=ob('monitor_curved_pc'), group='studio', size=None, keep=['Object_9', 'Object_10', 'Object_11', 'Object_17', 'Object_18', 'Object_21']),
    'gaming_keyboard': dict(src=ob('monitor_curved_pc'), group='studio', size=None, keep=['Object_13', 'Object_15', 'Object_16', 'Object_19', 'Object_20']),
    'gaming_mouse': dict(src=ob('monitor_curved_pc'), group='studio', size=None, keep=['Object_7', 'Object_8', 'Object_12', 'Object_14']),
    # Trees and planting (Poly Haven CC0 and Sketchfab CC-BY).
    'palm_coconut_a': dict(src=ob('palm_coconut_a'), group='nature', size=None, tree=True),
    'palm_coconut_b': dict(src=ob('palm_coconut_b'), group='nature', size=16.0, tree=True),
    'banana_small': dict(src=ob('banana_small'), group='nature', size=3.0, tree=True),
    'banana_plant': dict(src=ob('banana_plant'), group='nature', size=3.2, tree=True, leaves=20000),
    'island_tree_01': dict(src=ph('island_tree_01'), group='nature', size=None, tree=True, leaves=120000, other=25000),
    'island_tree_02': dict(src=ph('island_tree_02'), group='nature', size=None, tree=True, leaves=100000, other=20000),
    'tree_small_02': dict(src=ph('tree_small_02'), group='nature', size=None, tree=True, leaves=120000, other=25000),
    'jacaranda_tree': dict(src=ph('jacaranda_tree'), group='nature', size=None, tree=True, leaves=200000, other=40000),
    'searsia_lucida': dict(src=ph('searsia_lucida'), group='nature', size=None, tree=True, keep=['searsia_lucida_a_LOD0'], leaves=20000, other=8000),
    'shrub_02': dict(src=ph('shrub_02'), group='nature', size=None, tree=True),
    # Street and house details (Poly Haven CC0).
    'exterior_aircon_unit': dict(src=ph('exterior_aircon_unit'), group='street', size=None, other=6000),
    'power_box_01': dict(src=ph('power_box_01'), group='street', size=None, other=6000),
    'street_lamp_01': dict(src=ph('street_lamp_01'), group='street', size=None, other=10000),
    'plastic_monobloc_chair_01': dict(src=ph('plastic_monobloc_chair_01'), group='street', size=None),
    'security_light': dict(src=ph('security_light'), group='street', size=None),
    # Davao street scene (Sketchfab CC-BY). yaw turns the model so its front faces glTF +Z.
    'tricycle_a': dict(src=ob('tricycle_a'), group='street', size=2.4, lit=True),
    # Same mesh as tricycle_a with a blue sidecar and a lighter roof, for variety.
    'tricycle_b': dict(src=ob('tricycle_a'), group='street', size=2.4, lit=True, tint={'09___Default': (.03, .16, .5, 1), '02___Default': (.62, .1, .08, 1)}),
        'trisikad': dict(src=ob('trisikad'), group='street', size=2.4, other=60000, yaw=-90),
    'tuktuk': dict(src=ob('tuktuk'), group='street', size=2.6, other=60000, yaw=90),
    'jeepney': dict(src=ob('jeepney'), group='street', size=6.8),
    'food_cart_a': dict(src=ob('food_cart_a'), group='street', size=2.3, yaw=-90),
    'food_cart_b': dict(src=ob('food_cart_b'), group='street', size=2.2),
    'food_stall_c': dict(src=ob('food_stall_c'), group='street', size=2.6, other=60000, yaw=-90),
    'oil_drum': dict(src=ob('oil_drum'), group='street', size=.89),
    # Interior decor (Poly Haven CC0).
    'potted_plant_01': dict(src=ph('potted_plant_01'), group='decor', size=None, leaves=30000, other=30000),
    'potted_plant_02': dict(src=ph('potted_plant_02'), group='decor', size=None, other=40000),
    'potted_plant_04': dict(src=ph('potted_plant_04'), group='decor', size=None),
    'sofa_02': dict(src=ph('sofa_02'), group='decor', size=None),
    'modern_ceiling_lamp_01': dict(src=ph('modern_ceiling_lamp_01'), group='decor', size=None),
    'steel_frame_shelves_01': dict(src=ph('steel_frame_shelves_01'), group='decor', size=1.8),
    'ceramic_vase_01': dict(src=ph('ceramic_vase_01'), group='decor', size=None),
    'ceramic_vase_03': dict(src=ph('ceramic_vase_03'), group='decor', size=None),
    'book_encyclopedia_set_01': dict(src=ph('book_encyclopedia_set_01'), group='decor', size=None, other=20000),
    'throw_pillows_01': dict(src=ph('throw_pillows_01'), group='decor', size=None),
    'side_table_01': dict(src=ph('side_table_01'), group='decor', size=None),
    'desk_lamp_arm_01': dict(src=ph('desk_lamp_arm_01'), group='decor', size=None, other=12000),
    'boombox': dict(src=ph('boombox'), group='decor', size=None),
    'cassette_player': dict(src=ph('cassette_player'), group='decor', size=None),
    'alarm_clock_01': dict(src=ph('alarm_clock_01'), group='decor', size=None),
    'wicker_basket_01': dict(src=ph('wicker_basket_01'), group='decor', size=None, other=12000),
    'brass_vase_01': dict(src=ph('brass_vase_01'), group='decor', size=None, other=12000),
    'fancy_picture_frame_01': dict(src=ph('fancy_picture_frame_01'), group='decor', size=None),
}

def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)

def is_leaf(mat):
    name = (mat.name if mat else '').lower()
    return any(k in name for k in ('lea', 'frond', 'leef', 'twi', 'hair')) or (mat is not None and getattr(mat, 'blend_method', '') == 'BLEND')

def thin_leaves(obj, budget):
    """Delete whole leaf-card islands at random and enlarge the survivors."""
    count = tris(obj)
    if count <= budget:
        return
    keep = budget / count
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    rng = random.Random(7)
    seen = set()
    doomed = []
    survivors = []
    for face in bm.faces:
        if face.index in seen:
            continue
        island = []
        stack = [face]
        seen.add(face.index)
        while stack:
            f = stack.pop()
            island.append(f)
            for edge in f.edges:
                for g in edge.link_faces:
                    if g.index not in seen:
                        seen.add(g.index)
                        stack.append(g)
        (survivors if rng.random() < keep else doomed).append(island)
    grow = min(1.0 / math.sqrt(max(keep, .02)), 3.0)
    for island in survivors:
        verts = {v for f in island for v in f.verts}
        center = sum((v.co for v in verts), Vector()) / len(verts)
        for v in verts:
            v.co = center + (v.co - center) * grow
    bmesh.ops.delete(bm, geom=[f for island in doomed for f in island], context='FACES')
    bmesh.update_edit_mesh(obj.data)
    bpy.ops.object.mode_set(mode='OBJECT')

def decimate(obj, budget):
    count = tris(obj)
    if count <= budget:
        return
    mod = obj.modifiers.new('decimate', 'DECIMATE')
    mod.ratio = budget / count
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)

def split_by_leaf(obj):
    """Returns (leaf_obj, other_obj); either may be None."""
    leaf_slots = [i for i, slot in enumerate(obj.material_slots) if is_leaf(slot.material)]
    if not leaf_slots:
        return None, obj
    if len(leaf_slots) == len(obj.material_slots):
        return obj, None
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='DESELECT')
    for i in leaf_slots:
        obj.active_material_index = i
        bpy.ops.object.material_slot_select()
    bpy.ops.mesh.separate(type='SELECTED')
    bpy.ops.object.mode_set(mode='OBJECT')
    leaf = [o for o in bpy.context.selected_objects if o != obj][0]
    return leaf, obj

def make_lit(tint=None):
    """Unlit emission-only materials (flat colour) become Principled so they react to light.
    tint maps material name -> RGBA base colour override."""
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        nodes = mat.node_tree.nodes
        emission = next((n for n in nodes if n.type == 'EMISSION'), None)
        if emission is None or any(n.type == 'BSDF_PRINCIPLED' for n in nodes):
            continue
        color = tuple((tint or {}).get(mat.name, emission.inputs['Color'].default_value))
        for n in list(nodes):
            if n.type != 'OUTPUT_MATERIAL':
                nodes.remove(n)
        out = next(n for n in nodes if n.type == 'OUTPUT_MATERIAL')
        bsdf = nodes.new('ShaderNodeBsdfPrincipled')
        bsdf.inputs['Base Color'].default_value = color
        bsdf.inputs['Roughness'].default_value = .65
        mat.node_tree.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])

def process(name, cfg):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=cfg['src'])
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    if cfg.get('lit'):
        make_lit(cfg.get('tint'))
    if 'keep' in cfg:
        for o in meshes:
            if o.name.split('.')[0] not in cfg['keep'] and not any(o.name.startswith(k) for k in cfg['keep']):
                bpy.data.objects.remove(o)
        meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    # Bake every transform into the meshes, then drop empties.
    for o in meshes:
        world = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = world
    for o in list(bpy.context.scene.objects):
        if o.type != 'MESH':
            bpy.data.objects.remove(o)
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    before = tris(obj)
    if 'leaves' in cfg or 'other' in cfg:
        leaf, other = split_by_leaf(obj)
        if leaf is not None and 'leaves' in cfg:
            thin_leaves(leaf, cfg['leaves'])
        if other is not None and 'other' in cfg:
            decimate(other, cfg['other'])
        parts = [o for o in (leaf, other) if o is not None]
        bpy.ops.object.select_all(action='DESELECT')
        for o in parts:
            o.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        if len(parts) > 1:
            bpy.ops.object.join()
        obj = bpy.context.view_layer.objects.active
        obj.name = name
    # Optional yaw (degrees, about Blender Z) so the model's front ends up on glTF +Z.
    if cfg.get('yaw'):
        rot = Matrix.Rotation(math.radians(cfg['yaw']), 4, 'Z')
        for v in obj.data.vertices:
            v.co = rot @ v.co
        obj.data.update()
        bpy.context.view_layer.update()
    # Scale to the requested real-world size and pivot on the bottom centre.
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector([min(c[i] for c in corners) for i in range(3)])
    hi = Vector([max(c[i] for c in corners) for i in range(3)])
    scale = cfg['size'] / max(hi - lo) if cfg.get('size') else 1.0
    pivot = Vector((0, 0, lo.z)) if cfg.get('tree') else Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for v in obj.data.vertices:
        v.co = (v.co - pivot) * scale
    obj.data.update()
    for image in bpy.data.images:
        if image.size[0] > 1024 and not image.is_dirty:
            image.scale(1024, max(1, image.size[1] * 1024 // image.size[0]))
    dst = os.path.join(OUT, cfg['group'], name + '.glb')
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_yup=True, export_apply=True,
                              export_animations=False, export_cameras=False, export_lights=False,
                              export_image_format='AUTO', use_selection=False)
    dims = (hi - lo) * scale
    print(f'PROCESSED {name}: {before} -> {tris(obj)} tris, size {dims.x:.2f} x {dims.y:.2f} x {dims.z:.2f} m, {os.path.getsize(dst)//1024} KB')

def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    for name, cfg in ASSETS.items():
        if argv and name not in argv:
            continue
        try:
            process(name, cfg)
        except Exception as error:
            print(f'FAILED {name}: {error}')

main()
