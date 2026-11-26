"""0.48: turn the downloaded gun models (tools/assets/fetch_guns.py) into game/assets/models/guns/<id>.glb.

    blender -b -P tools/blender/story/process_guns.py -- preview <out_dir> [ids...]
    blender -b -P tools/blender/story/process_guns.py -- export [ids...]

Each model is joined into one mesh, turned to the stock weapons' frame, scaled to its real length and given the
sockets scripts/gun.gd reads (grip_r, grip_l, muzzle, eject, rear_sight, front_sight, butt, mag, bolt_handle):
  long guns (rifles, shotguns, sniper rifles), like ar15.glb: the bore along Blender +Y (Godot -Z), the bore line at
    z = 0, and the origin a little ahead of the pistol grip;
  pistols, like glock17.glb: the muzzle toward Blender -Y (Godot +Z), the sight line at z = .0731, the back of the
    slide at Godot z = -.1096.
The orientation comes from the shape (longest side = the bore, second = up; the thin end is the muzzle; the barrel sits
above the middle), with SPEC overriding what the eye had to correct. `preview` renders a side view with a ruler in
tenths of the length, muzzle to butt, which is where SPEC's `grip` and `guard` fractions are read from.
"""
import bpy, bmesh, json, math, os, sys
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
RAW = os.path.join(ROOT, '.local', 'downloads', 'guns', 'raw')
OUT = os.path.join(ROOT, 'game', 'assets', 'models', 'guns')

# kind, real length (m), grip = the pistol grip's distance from the muzzle as a fraction of the length,
# guard = where the support hand holds (fraction from the muzzle), flip / up overrides when the shape misleads.
SPEC = {
    "beretta_hi91": {"kind": "pistol", "length": .217},
    "eruption_ad15": {"kind": "pistol", "length": .270},
    "sauer_p9": {"kind": "pistol", "length": .180},
    "magnum_vex": {"kind": "pistol", "length": .290},
    "gtk44": {"kind": "long", "length": .880, "grip": .62, "guard": .40},
    "kestrel_k74": {"kind": "long", "length": .943, "grip": .62, "guard": .40},
    "viper_v9": {"kind": "long", "length": .620, "grip": .55, "guard": .25},
    "hornet_mp9": {"kind": "long", "length": .680, "grip": .55, "guard": .25},
    "bastion_s17": {"kind": "long", "length": .960, "grip": .58, "guard": .35},
    "garrison_m1": {"kind": "long", "length": 1.10, "grip": .66, "guard": .40},
    "corsair_m4": {"kind": "long", "length": .840, "grip": .60, "guard": .35},
    "sentry_sk45": {"kind": "long", "length": 1.02, "grip": .66, "guard": .40},
    "auger_a3": {"kind": "long", "length": .790, "grip": .45, "guard": .25},
    "talon_p90": {"kind": "long", "length": .505, "grip": .45, "guard": .2},
    "longreach_m40": {"kind": "long", "length": 1.20, "grip": .66, "guard": .42},
    "drakon_svd": {"kind": "long", "length": 1.22, "grip": .63, "guard": .40},
    "titan_b50": {"kind": "long", "length": 1.14, "grip": .66, "guard": .45},
    "gausser_db": {"kind": "long", "length": .78, "grip": .86, "guard": .5},
    "spartan_s12": {"kind": "long", "length": 1.04, "grip": .64, "guard": .40},
    "tempest_a14": {"kind": "long", "length": 1.01, "grip": .63, "guard": .40},
    "ironside_m37": {"kind": "long", "length": 1.00, "grip": .66, "guard": .42},
}
OVERRIDES_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'gun_overrides.json')

def args():
    a = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    return a

def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def load(gid):
    clear()
    bpy.ops.import_scene.gltf(filepath=os.path.join(RAW, gid + '.glb'))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    # Bake every transform (and armature pose) into the meshes, then join them.
    for o in meshes:
        for m in list(o.modifiers):
            if m.type == 'ARMATURE':
                bpy.context.view_layer.objects.active = o
                try:
                    bpy.ops.object.modifier_apply(modifier=m.name)
                except Exception:
                    o.modifiers.remove(m)
    for o in meshes:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    for o in list(bpy.context.scene.objects):
        if o.type != 'MESH':
            bpy.data.objects.remove(o, do_unlink=True)
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:
        if o.data.shape_keys:
            o.shape_key_clear()
        o.data = o.data.copy()
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = gid
    return ob

def cull_islands(ob):
    """Deletes loose parts that float clear of the weapon (a spare clip, a shell, a muzzle flash card)."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    seen = set()
    islands = []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack = [v]; group = []
        seen.add(v.index)
        while stack:
            x = stack.pop(); group.append(x)
            for e in x.link_edges:
                o = e.other_vert(x)
                if o.index not in seen:
                    seen.add(o.index); stack.append(o)
        lo = Vector([min(g.co[i] for g in group) for i in range(3)])
        hi = Vector([max(g.co[i] for g in group) for i in range(3)])
        islands.append((group, lo, hi))
    islands.sort(key=lambda t: -(t[2] - t[1]).length)
    keep_lo, keep_hi = islands[0][1].copy(), islands[0][2].copy()
    pad = (keep_hi - keep_lo).length * .01
    changed = True
    kept = {0}
    while changed:
        changed = False
        for k, (group, lo, hi) in enumerate(islands):
            if k in kept:
                continue
            if all(lo[i] <= keep_hi[i] + pad and hi[i] >= keep_lo[i] - pad for i in range(3)):
                kept.add(k); changed = True
                for i in range(3):
                    keep_lo[i] = min(keep_lo[i], lo[i]); keep_hi[i] = max(keep_hi[i], hi[i])
    # Only what lies outside the weapon's own box goes.
    gone = [v for k, (group, lo, hi) in enumerate(islands) if k not in kept for v in group]
    bmesh.ops.delete(bm, geom=gone, context='VERTS')
    bm.to_mesh(ob.data); bm.free(); ob.data.update()
    return len(islands) - len(kept)

def verts(ob):
    return [v.co.copy() for v in ob.data.vertices]

def axis_extent(vs, ax):
    vals = [v[ax] for v in vs]
    return min(vals), max(vals)

def orient(ob, gid, spec, over):
    vs = verts(ob)
    ext = [axis_extent(vs, a) for a in range(3)]
    size = [e[1] - e[0] for e in ext]
    order = sorted(range(3), key=lambda a: -size[a])
    L, U = order[0], order[1]
    if 'axes' in over:
        L, U = over['axes']
    lo, hi = ext[L]
    span = hi - lo
    ulo, uhi = ext[U]
    # Which end is the muzzle: the thinner one (pistols: the end without the grip).
    frac = .25 if spec['kind'] == 'pistol' else .1
    def height(a, b):
        sel = [v[U] for v in vs if a <= v[L] <= b]
        return (max(sel) - min(sel)) if sel else 0.0
    muzzle_high = height(hi - span * frac, hi) < height(lo, lo + span * frac)
    if 'muzzle_high' in over:
        muzzle_high = over['muzzle_high']
    # Which way is up: the barrel is above the middle.
    m0, m1 = (hi - span * .06, hi) if muzzle_high else (lo, lo + span * .06)
    front = [v[U] for v in vs if m0 <= v[L] <= m1]
    bore_u = sum(front) / max(1, len(front))
    up_positive = bore_u > (ulo + uhi) / 2
    if 'up_positive' in over:
        up_positive = over['up_positive']
    # Build the rotation: forward (muzzle) -> +Y for long guns, -Y for pistols; up -> +Z.
    fwd = Vector((0, 0, 0)); fwd[L] = 1 if muzzle_high else -1
    up = Vector((0, 0, 0)); up[U] = 1 if up_positive else -1
    side = fwd.cross(up)
    want_fwd = Vector((0, 1, 0)) if spec['kind'] == 'long' else Vector((0, -1, 0))
    want_up = Vector((0, 0, 1))
    want_side = want_fwd.cross(want_up)
    src = Matrix((fwd, up, side)).transposed()
    dst = Matrix((want_fwd, want_up, want_side)).transposed()
    rot = dst @ src.inverted()
    ob.data.transform(rot.to_4x4())
    ob.data.update()
    vs = verts(ob)
    ys = [v.y for v in vs]
    s = spec['length'] / (max(ys) - min(ys))
    ob.data.transform(Matrix.Scale(s, 4))
    ob.data.update()
    return {"L": L, "U": U, "muzzle_high": muzzle_high, "up_positive": up_positive, "scale": s}

def place(ob, gid, spec, over=None):
    """Moves the mesh into the weapon frame; returns the sockets in Blender space."""
    vs = verts(ob)
    ys = [v.y for v in vs]
    ymin, ymax = min(ys), max(ys)
    length = ymax - ymin
    sockets = {}
    if spec['kind'] == 'long':
        # Muzzle at +Y. The bore: the middle of the last 3 cm.
        tip = [v for v in vs if v.y >= ymax - .03]
        bx = sum(v.x for v in tip) / len(tip)
        bz = (min(v.z for v in tip) + max(v.z for v in tip)) / 2
        grip_y = ymax - spec['grip'] * length
        # The origin a little ahead of the pistol grip (ar15.glb: grip_r at z +.027 Godot = y -.027 here).
        shift = Vector((-bx, -(grip_y + .027), -bz))
        ob.data.transform(Matrix.Translation(shift))
        ob.data.update()
        vs = verts(ob)
        ymin, ymax = min(v.y for v in vs), max(v.y for v in vs)
        guard_y = ymax - spec['guard'] * length
        # The pistol grip's lowest point near grip_y, the guard's underside near guard_y.
        near_grip = [v.z for v in vs if abs(v.y - -.027) < .03]
        near_guard = [v.z for v in vs if abs(v.y - guard_y) < .03]
        grip_low = min(near_grip) if near_grip else -.12
        guard_low = min(near_guard) if near_guard else -.04
        # The sight line: the top of the receiver (or the optic) round the grip, parallel to the bore.
        near_top = [v.z for v in vs if -.12 < v.y < .25]
        top = max(near_top) if near_top else .06
        sight = max(.025, min(top - .008, .12))
        if over and 'sight_z' in over:
            # The eye over the top of an optic that cannot be seen through (or a rail too low to be the sight line).
            sight = float(over['sight_z'])
        # The hands sit as far under the sight line as they do on ar15.glb (the right fist 18 cm, the support hand
        # 9 cm): gun.gd lowers the weapon until the hands are under the frame's edge, so hands set higher on one
        # model than on the AR would take that model out of the picture at the hip.
        sockets = {
            "grip_r": (0, -.027, sight - .18),
            "grip_l": (0, guard_y, sight - .09),
            "muzzle": (0, ymax + .002, 0),
            "eject": (.025, .1, .006),
            "rear_sight": (0, .02, sight),
            "front_sight": (0, min(ymax - .05, .5), sight),
            "butt": (0, ymin, -.04),
            "mag": (0, .12, -.09),
            "bolt_handle": (.055, .0, -.035),
        }
        # Godot-space convenience
    else:
        # Muzzle at -Y. Sight line (the top of the slide over the back half) at .0731; back of the slide at -.1096 Godot
        # (= +.1096 here).
        back = [v for v in vs if v.y >= ymax - length * .35]
        top = max(v.z for v in back)
        xs = [v.x for v in vs if v.y <= ymin + .02]
        bx = (min(xs) + max(xs)) / 2 if xs else 0.0
        shift = Vector((-bx, .1096 - ymax, .0731 - top + .004))
        ob.data.transform(Matrix.Translation(shift))
        ob.data.update()
        vs = verts(ob)
        ymin = min(v.y for v in vs)
        tip = [v for v in vs if v.y <= ymin + .01]
        bz = (min(v.z for v in tip) + max(v.z for v in tip)) / 2 if tip else .05
        sockets = {"muzzle": (0, ymin - .002, bz), "rear_sight": (0, .0625, .0731), "front_sight": (0, ymin + .012, .0731)}
    return sockets

def cut_below(ob, z):
    """Deletes loose parts lying wholly below z (a spare magazine on the ground beside the pistol)."""
    bm = bmesh.new(); bm.from_mesh(ob.data)
    seen = set(); gone = []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack = [v]; group = []; seen.add(v.index)
        while stack:
            x = stack.pop(); group.append(x)
            for e in x.link_edges:
                o = e.other_vert(x)
                if o.index not in seen:
                    seen.add(o.index); stack.append(o)
        if max(g.co.z for g in group) < z:
            gone += group
    bmesh.ops.delete(bm, geom=gone, context='VERTS')
    bm.to_mesh(ob.data); bm.free(); ob.data.update()
    return len(gone)

def downsize_images(limit):
    for img in bpy.data.images:
        if img.size[0] > limit or img.size[1] > limit:
            k = limit / max(img.size[0], img.size[1])
            img.scale(max(1, int(img.size[0] * k)), max(1, int(img.size[1] * k)))
            img.pack()

def add_sockets(ob, sockets):
    for name, p in sockets.items():
        e = bpy.data.objects.new(name, None)
        bpy.context.scene.collection.objects.link(e)
        e.location = Vector(p)

def preview(ob, gid, spec, out_dir):
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE_NEXT'
    scene.render.resolution_x, scene.render.resolution_y = 900, 420
    world = bpy.data.worlds.new('w'); scene.world = world
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs[0].default_value = (.55, .55, .58, 1)
    world.node_tree.nodes['Background'].inputs[1].default_value = 1.2
    vs = verts(ob)
    ys = [v.y for v in vs]; zs = [v.z for v in vs]
    cy, cz = (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2
    length = max(ys) - min(ys)
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    scene.collection.objects.link(cam); scene.camera = cam
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = max(length, (max(zs) - min(zs)) * 2.3) * 1.15
    cam.location = (2.0, cy, cz); cam.rotation_euler = (math.pi / 2, 0, math.pi / 2)
    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
    scene.collection.objects.link(sun); sun.rotation_euler = (.6, .2, 1.2); sun.data.energy = 3
    # Ruler: a tick every tenth of the length from the muzzle.
    mat = bpy.data.materials.new('tick'); mat.diffuse_color = (1, 0, 0, 1)
    muzzle_y = max(ys) if spec['kind'] == 'long' else min(ys)
    sign = -1 if spec['kind'] == 'long' else 1
    for i in range(11):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(.2, muzzle_y + sign * length * i / 10, min(zs) - .01))
        t = bpy.context.active_object; t.scale = (.001, .002, .02 if i % 5 else .04); t.data.materials.append(mat)
    for name in ('grip_r', 'grip_l', 'muzzle', 'rear_sight', 'front_sight'):
        e = bpy.data.objects.get(name)
        if e:
            bpy.ops.mesh.primitive_uv_sphere_add(radius=length * .012, location=e.location + Vector((.15, 0, 0)))
            bpy.context.active_object.data.materials.append(mat)
    scene.render.filepath = os.path.join(out_dir, gid + '.png')
    bpy.ops.render.render(write_still=True)

def main():
    a = args()
    mode = a[0]
    out_dir = os.path.abspath(a[1]) if mode == 'preview' else OUT
    ids = a[2:] if mode == 'preview' else a[1:]
    overrides = json.load(open(OVERRIDES_FILE)) if os.path.exists(OVERRIDES_FILE) else {}
    os.makedirs(out_dir, exist_ok=True)
    report = {}
    for gid, spec in SPEC.items():
        if ids and gid not in ids:
            continue
        ob = load(gid)
        culled = cull_islands(ob) if overrides.get(gid, {}).get('cull') else 0
        drop = overrides.get(gid, {}).get('drop_materials', [])
        if drop:
            bm = bmesh.new(); bm.from_mesh(ob.data)
            names = [m.name if m else '' for m in ob.data.materials]
            gone = [f for f in bm.faces if names[f.material_index] in drop]
            bmesh.ops.delete(bm, geom=gone, context='FACES')
            bm.to_mesh(ob.data); bm.free(); ob.data.update()
        info = orient(ob, gid, spec, overrides.get(gid, {}))
        sockets = place(ob, gid, spec, overrides.get(gid, {}))
        if 'cut_below' in overrides.get(gid, {}):
            info['cut'] = cut_below(ob, overrides[gid]['cut_below'])
        add_sockets(ob, sockets)
        info['faces'] = len(ob.data.polygons)
        info['culled'] = culled
        info['sockets'] = sockets
        report[gid] = info
        print('GUN', gid, json.dumps(info, default=str))
        if mode == 'preview':
            preview(ob, gid, spec, out_dir)
        else:
            downsize_images(1024)
            bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, gid + '.glb'), export_format='GLB', export_yup=True,
                export_apply=True, export_image_format='AUTO', export_animations=False)
    json.dump(report, open(os.path.join(out_dir, 'process_report.json'), 'w'), indent=1, default=str)

main()
