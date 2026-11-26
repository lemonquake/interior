"""0.65: the vehicles of Outer Street, rebuilt from real proportions (owner, 2026-11-25: "research about 3D models
of Bus and trains and completely overhaul the models in the game").

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P tools/blender/vehicles/build_vehicles.py [-- --preview]

Writes GLBs to game/assets/models/vehicles/ (and, with --preview, Workbench renders to work/v65/vehicles/).

Reference figures (manufacturer sheets, 12 m low-floor city buses: MAN Lion's City 12, Mercedes Citaro, Caetano
e.City; metro cars: Siemens Inspiro Sofia/Warsaw/Munich data sheets): bus 12.0 x 2.5 x ~3.1 m, wheelbase ~5.9 m,
floor 0.34-0.37 m, door clear width 1.25 m, interior standing height ~2.3 m; metro car 2.65-3.1 m wide, floor
~1.1 m over the rail, double-leaf doors ~1.3-1.4 m, longitudinal benches, open gangways.

Everything is modelled in Godot space (x right, y up, z forward) and turned into Blender's Z-up at the end, so the
numbers here are the numbers outer_world.gd uses. Faces carry material slot NAMES only (paint, glass, seat, ...):
outer_kit.gd binds each name to a project material per vehicle (a palette), so one model serves clean, wrecked
and burnt versions.

Frames:
  bus_*    x 0..2.5 (west side to the doors' side), z 0..12 (rear to front), y 0 the road; floor 0.36.
  metro_*  x 0..2.9 across, z 0..18.6 along, y 0 the car's floor (rail at -1.15).
  sedan, van, pickup, truck: centred on x and z, nose toward +z, y 0 the road.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "game", "assets", "models", "vehicles")
PREVIEW = os.path.join(ROOT, "work", "v65", "vehicles")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

# Godot (x, y, z) -> Blender (x, -z, y); glTF export with +Y up turns it back.
TO_BLENDER = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)


def rot_y(a):
    return Matrix.Rotation(a, 4, "Y")


def rot_x(a):
    return Matrix.Rotation(a, 4, "X")


def rot_z(a):
    return Matrix.Rotation(a, 4, "Z")


class Kit:
    """One mesh, faces tagged by material name, built from bevelled boxes, cylinders, hulls and flat pieces."""

    def __init__(self, seed):
        self.bm = bmesh.new()
        self.mats = []
        self.r = random.Random(seed)

    def mi(self, name):
        if name not in self.mats:
            self.mats.append(name)
        return self.mats.index(name)

    def _merge(self, tmp, mat, smooth=False):
        idx = self.mi(mat)
        vmap = {}
        for v in tmp.verts:
            vmap[v] = self.bm.verts.new(v.co)
        for f in tmp.faces:
            try:
                nf = self.bm.faces.new([vmap[v] for v in f.verts])
            except ValueError:
                continue
            nf.material_index = idx
            nf.smooth = smooth
        tmp.free()

    def box(self, c, size, mat, bevel=0.0, seg=2, rot=None, smooth=None):
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        for v in tmp.verts:
            v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
        if bevel > 0.0:
            w = min(bevel, min(size) * .49)
            bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=w, segments=seg, profile=.5, affect="EDGES", clamp_overlap=True)
        m = Matrix.Translation(Vector(c)) @ (rot if rot is not None else Matrix.Identity(4))
        bmesh.ops.transform(tmp, matrix=m, verts=list(tmp.verts))
        self._merge(tmp, mat, bevel > 0.0 if smooth is None else smooth)

    def span(self, lo, hi, mat, bevel=0.0, seg=2):
        c = [(lo[i] + hi[i]) * .5 for i in range(3)]
        s = [abs(hi[i] - lo[i]) for i in range(3)]
        self.box(c, s, mat, bevel, seg)

    def cyl(self, a, b, r, mat, seg=12, r2=None, bevel=0.0, smooth=True):
        a = Vector(a)
        b = Vector(b)
        d = b - a
        if d.length < 1e-4:
            return
        tmp = bmesh.new()
        bmesh.ops.create_cone(tmp, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=d.length)
        if bevel > 0.0:
            rim = [e for e in tmp.edges if len(e.link_faces) == 2 and abs(e.link_faces[0].normal.dot(e.link_faces[1].normal)) < .5]
            bmesh.ops.bevel(tmp, geom=rim, offset=bevel, segments=2, profile=.5, affect="EDGES", clamp_overlap=True)
        q = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
        bmesh.ops.transform(tmp, matrix=Matrix.Translation((a + b) * .5) @ q, verts=list(tmp.verts))
        self._merge(tmp, mat, smooth)

    def bar(self, a, b, t, mat, t2=None):
        """A square bar from a to b, `t` thick (t2 the other way)."""
        a = Vector(a)
        b = Vector(b)
        d = b - a
        if d.length < 1e-4:
            return
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        for v in tmp.verts:
            v.co = Vector((v.co.x * t, v.co.y * (t if t2 is None else t2), v.co.z * d.length))
        q = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
        bmesh.ops.transform(tmp, matrix=Matrix.Translation((a + b) * .5) @ q, verts=list(tmp.verts))
        self._merge(tmp, mat)

    def hull(self, pts, mat, bevel=0.0, seg=2):
        tmp = bmesh.new()
        vs = [tmp.verts.new(Vector(p)) for p in pts]
        res = bmesh.ops.convex_hull(tmp, input=vs)
        kill = [g for g in res["geom_interior"] + res["geom_unused"] if isinstance(g, bmesh.types.BMVert)]
        if kill:
            bmesh.ops.delete(tmp, geom=kill, context="VERTS")
        bmesh.ops.dissolve_limit(tmp, angle_limit=.02, verts=list(tmp.verts), edges=list(tmp.edges))
        if bevel > 0.0:
            bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bevel, segments=seg, profile=.5, affect="EDGES", clamp_overlap=True)
        bmesh.ops.recalc_face_normals(tmp, faces=list(tmp.faces))
        self._merge(tmp, mat, bevel > 0.0)

    def quad(self, pts, mat, both=True):
        tmp = bmesh.new()
        vs = [tmp.verts.new(Vector(p)) for p in pts]
        tmp.faces.new(vs)
        if both:
            vs2 = [tmp.verts.new(Vector(p)) for p in reversed(pts)]
            tmp.faces.new(vs2)
        self._merge(tmp, mat)

    def ring(self, c, axis, r0, r1, a0, a1, depth, mat, seg=10):
        """Part of a flat ring (a wheel arch's lip) round `c`, in the plane across `axis` ("x" or "z")."""
        c = Vector(c)
        for i in range(seg):
            t0 = a0 + (a1 - a0) * i / seg
            t1 = a0 + (a1 - a0) * (i + 1) / seg
            pts = []
            for (r, t) in ((r0, t0), (r1, t0), (r1, t1), (r0, t1)):
                if axis == "x":
                    pts.append(c + Vector((0, math.sin(t) * r, math.cos(t) * r)))
                else:
                    pts.append(c + Vector((math.cos(t) * r, math.sin(t) * r, 0)))
            off = Vector((depth * .5, 0, 0)) if axis == "x" else Vector((0, 0, depth * .5))
            self.hull([p - off for p in pts] + [p + off for p in pts], mat)

    def wheel(self, c, r, w, side, tyre="rubber", rim="rim", dual=False):
        """A wheel on an axle along x; `side` -1 west face out, +1 east face out."""
        c = Vector(c)
        h = Vector((w * .5, 0, 0))
        self.cyl(c - h, c + h, r, tyre, seg=22, bevel=r * .14)
        out = c + Vector((side * (w * .5 + .004), 0, 0))
        self.cyl(c, out, r * .62, rim, seg=18)
        self.cyl(out - Vector((side * .01, 0, 0)), out + Vector((side * .03, 0, 0)), r * .2, "chrome", seg=12)
        for k in range(8 if r > .4 else 5):
            a = k / (8 if r > .4 else 5) * math.tau
            p = out + Vector((0, math.sin(a) * r * .36, math.cos(a) * r * .36))
            self.cyl(p, p + Vector((side * .025, 0, 0)), r * .035, "chrome", seg=6)
        if dual:
            self.cyl(c - h * 3.1, c - h * 1.05, r, tyre, seg=22, bevel=r * .14)

    def shards(self, lo, hi, plane, mat="glass", n=7):
        """Broken glass left in a frame: jagged teeth along its edges. `plane` "x" (pane across x) or "z"."""
        lo = Vector(lo)
        hi = Vector(hi)
        r = self.r
        for edge in range(4):
            for k in range(r.randint(1, n // 2 + 1)):
                if plane == "x":
                    x = lo.x
                    if edge < 2:
                        y0 = lo.y if edge == 0 else hi.y
                        z = r.uniform(lo.z, hi.z)
                        w = r.uniform(.06, .22)
                        tip = Vector((x, y0 + (1 if edge == 0 else -1) * r.uniform(.08, .35), z + r.uniform(-.1, .1)))
                        self.quad([Vector((x, y0, z - w)), Vector((x, y0, z + w)), tip], mat)
                    else:
                        z0 = lo.z if edge == 2 else hi.z
                        y = r.uniform(lo.y, hi.y)
                        w = r.uniform(.06, .2)
                        tip = Vector((x, y + r.uniform(-.1, .1), z0 + (1 if edge == 2 else -1) * r.uniform(.08, .3)))
                        self.quad([Vector((x, y - w, z0)), Vector((x, y + w, z0)), tip], mat)
                else:
                    z = lo.z
                    if edge < 2:
                        y0 = lo.y if edge == 0 else hi.y
                        x = r.uniform(lo.x, hi.x)
                        w = r.uniform(.06, .22)
                        tip = Vector((x + r.uniform(-.1, .1), y0 + (1 if edge == 0 else -1) * r.uniform(.08, .35), z))
                        self.quad([Vector((x - w, y0, z)), Vector((x + w, y0, z)), tip], mat)
                    else:
                        x0 = lo.x if edge == 2 else hi.x
                        y = r.uniform(lo.y, hi.y)
                        w = r.uniform(.06, .2)
                        tip = Vector((x0 + (1 if edge == 2 else -1) * r.uniform(.08, .3), y + r.uniform(-.1, .1), z))
                        self.quad([Vector((x0, y - w, z)), Vector((x0, y + w, z)), tip], mat)

    def finish(self, name):
        bm = self.bm
        bmesh.ops.transform(bm, matrix=TO_BLENDER, verts=list(bm.verts))
        bm.normal_update()
        uv = bm.loops.layers.uv.new("UVMap")
        for f in bm.faces:
            n = f.normal
            ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
            for loop in f.loops:
                co = loop.vert.co
                if az >= ax and az >= ay:
                    loop[uv].uv = (co.x, co.y)
                elif ax >= ay:
                    loop[uv].uv = (co.y, co.z)
                else:
                    loop[uv].uv = (co.x, co.z)
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        for m in self.mats:
            mat = bpy.data.materials.get(m) or bpy.data.materials.new(m)
            mesh.materials.append(mat)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        try:
            bpy.ops.object.shade_smooth_by_angle(angle=math.radians(38), keep_sharp_edges=True)
        except Exception:
            pass
        return obj


def export(obj, filename):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, filename), export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_materials="EXPORT", export_texcoords=True,
                              export_normals=True)


# ============================================================================================ the city bus

BW = 2.5
BL = 12.0
BF = .36
DOORS = (2.5, 10.8)
AXLES = (4.0, 9.4)


def bus(k, walk):
    """`walk`: both doors (on +x) broken open, the east windows mostly smashed: the one at the pile-up. Otherwise
    shut, a window or two gone: the stalled ones."""
    r = k.r
    W, L, F = BW, BL, BF
    # Chassis, bumpers.
    k.span((.15, .16, .5), (W - .15, .34, L - .5), "dark")
    k.box((W * .5, .42, L + .07), (W + .04, .26, .2), "dark", .05)
    k.box((W * .5, .42, -.07), (W + .04, .26, .2), "dark", .05)
    # Wheels: duals at the back.
    for z in AXLES:
        for side, x in ((-1, .2), (1, W - .2)):
            k.wheel((x, .5, z), .5, .3, side, dual=False)
        # Arch lips and the dark housings behind them.
        for x in (-.005, W + .005):
            k.ring((x, .5, z), "x", .56, .64, -math.pi * .5, math.pi * .5, .05, "dark", 12)
            k.span((x - .02 if x < 1 else x - .5, .3, z - .6), (x + .5 if x < 1 else x + .02, 1.12, z + .6), "dark") if False else None
        k.span((.05, .3, z - .6), (.5, 1.1, z + .6), "dark")
        k.span((W - .5, .3, z - .6), (W - .05, 1.1, z + .6), "dark")
    # Lower body: sides with arch cut-outs (and door gaps on +x).
    def side_lower(x, gaps):
        cuts = sorted([(a - .62, a + .62, 1.12) for a in AXLES] + [(g - .55, g + .55, 9.0) for g in gaps])
        z = .05
        for (a, b, top) in cuts:
            if a > z:
                k.box((x, .73, (z + a) * .5), (.06, .82, a - z), "paint", .015)
            if top < 5.0:
                k.box((x, 1.13, (a + b) * .5), (.06, .04, b - a), "paint", .01)
            z = b
        k.box((x, .73, (z + L - .05) * .5), (.06, .82, L - .05 - z), "paint", .015)
    side_lower(0.0, [])
    side_lower(W, list(DOORS))
    # The livery: a band along the belt and a sweep low on the skirt (no words, no numbers).
    for x, gaps in ((-.006, []), (W + .006, list(DOORS))):
        z = .1
        for g in sorted(gaps) + [99.0]:
            a = min(g - .55, L - .1)
            if a > z:
                k.box((x, 1.02, (z + a) * .5), (.01, .12, a - z), "paint2")
                k.box((x, .48, (z + a) * .5), (.01, .07, a - z), "paint2")
            z = g + .55
    # Belt rail, cant rail, the window band's pillars and glass.
    for x, gaps in ((0.0, []), (W, list(DOORS))):
        z = .05
        for g in sorted(gaps) + [L - .05 + .55]:
            a = g - .55
            if a > z:
                k.box((x, 1.16, (z + a) * .5), (.08, .06, a - z), "trim", .01)
                k.box((x, 2.57, (z + a) * .5), (.07, .1, a - z), "paint", .01)
            z = g + .55
        zz = .35
        panes = []
        while zz < L - .6:
            nxt = min(zz + 1.28, L - .5)
            in_door = any(abs(((zz + nxt) * .5) - d) < 1.0 for d in gaps)
            if not any(abs(zz - d) < .55 for d in gaps):
                k.box((x, 1.86, zz), (.08, 1.36, .1), "paint", .012)
            if not in_door and nxt - zz > .5:
                panes.append((zz + .05, nxt - .05))
            zz = nxt
        k.box((x, 1.86, L - .5), (.08, 1.36, .12), "paint", .012)
        for (a, b) in panes:
            gone = r.random() < (.55 if (walk and x > 1) else .22)
            xo = x + (.005 if x > 1 else -.005)
            # Rubber surround.
            for yy in (1.2, 2.5):
                k.box((xo, yy, (a + b) * .5), (.03, .03, b - a), "dark")
            k.box((xo, 1.86, a), (.03, 1.3, .03), "dark")
            k.box((xo, 1.86, b), (.03, 1.3, .03), "dark")
            k.box((xo, 2.12, (a + b) * .5), (.035, .03, b - a), "dark")
            if gone:
                k.shards((xo, 1.22, a + .02), (xo, 2.48, b - .02), "x", "glass", 6)
            else:
                k.box((xo, 1.86, (a + b) * .5), (.012, 1.26, b - a - .02), "glass")
    # Roof: one bevelled slab, rounded along its edges; the air-conditioner pod, a hatch.
    k.box((W * .5, 2.82, L * .5), (W, .42, L - .02), "paint", .2, 5)
    k.box((W * .5, 3.07, 7.2), (1.5, .26, 2.9), "trim", .08, 3)
    for i in range(7):
        k.box((W * .5, 3.205, 6.0 + i * .4), (1.3, .01, .14), "dark")
    k.box((W * .5, 3.03, 3.0), (.8, .08, .8), "trim", .03)
    # Front: lower panel with lamps, the big windscreen leaning back, the destination box (lit by outer_world.gd).
    k.box((W * .5, .74, L - .02), (W, .86, .1), "paint", .04)
    k.box((W * .5, .93, L + .035), (W - .2, .08, .01), "paint2")
    for x in (.38, W - .38):
        k.box((x, .66, L + .03), (.44, .2, .04), "lamp_front", .02)
        k.box((x + (.3 if x < 1 else -.3), .66, L + .03), (.12, .12, .04), "lamp_amber", .02)
    for i in range(4):
        k.box((W * .5, .5 + i * .05, L + .05), (.9, .02, .02), "dark")
    k.box((W * .5, .62, L + .07), (.5, .14, .01), "trim")
    lean = rot_x(-.09)
    k.box((W * .5, 1.9, L - .03), (W - .16, 1.46, .02), "glass", 0.0, rot=lean)
    for x in (.04, W - .04):
        k.box((x, 1.9, L - .05), (.1, 1.5, .1), "paint", .02, rot=lean)
    k.box((W * .5, 1.15, L - .02), (W, .06, .1), "dark")
    k.box((W * .5, 2.62, L - .1), (W - .08, .06, .14), "dark")
    k.box((W * .5, 2.77, L - .05), (W - .06, .34, .1), "paint", .04)
    k.box((W * .5, 2.77, L - .005), (1.9, .3, .02), "dark")
    # Cracks across the windscreen.
    for i in range(7 if walk else 3):
        a = Vector((W * .5 + r.uniform(-.25, .25), 1.95 + r.uniform(-.15, .15), L + .002))
        b = a + Vector((r.uniform(-1.0, 1.0), r.uniform(-.6, .6), 0))
        k.bar(a, b, .006, "crack")
    for x in (.7, 1.8):
        k.bar((x, 1.25, L + .01), (x - .35, 1.85, L - .05), .025, "dark")
    # Mirrors on their arms, out and forward.
    for side, x in ((-1, 0.0), (1, W)):
        a = Vector((x, 2.45, L - .15))
        b = a + Vector((side * .3, .15, .35))
        c = b + Vector((0, -.45, .05))
        k.cyl(a, b, .025, "dark", 6)
        k.cyl(b, c, .025, "dark", 6)
        k.box((x + side * .32, 1.92, L + .22), (.07, .4, .24), "dark", .02)
    # Rear: the panel, its window, the engine grille, lamps (the hazards blink in outer_world.gd).
    k.box((W * .5, 1.42, .02), (W, 2.2, .1), "paint", .04)
    k.box((W * .5, 2.1, -.035), (W - .4, .72, .01), "glass")
    for i in range(7):
        k.box((W * .5, .58 + i * .07, -.04), (1.7, .03, .02), "dark")
    for x in (.18, W - .18):
        k.box((x, 1.0, -.035), (.2, .4, .03), "lamp_rear", .01)
        k.box((x, 1.35, -.035), (.2, .18, .03), "lamp_amber", .01)
    k.box((W * .5, .3, -.05), (.4, .08, .08), "dark")
    # ------------------------------------------------------------ inside
    k.span((.06, .3, .06), (W - .06, F, L - .06), "floor")
    k.span((.12, F, .12), (W - .12, F + .004, L - .12), "floor")
    for x in (.09, W - .09):
        k.span((x - .02, F, .2), (x + .02, 1.14, L - .4), "interior")
    k.span((.1, 2.6, .1), (W - .1, 2.64, L - .1), "interior")
    k.span((.1, 2.4, .1), (.26, 2.6, L - .1), "interior")
    k.span((W - .26, 2.4, .1), (W - .1, 2.6, L - .1), "interior")
    # Ceiling light housings (the tubes themselves glow from outer_world.gd, under them).
    for (a, b) in ((1.2, 5.6), (5.9, 10.2)):
        k.span((W * .5 - .16, 2.56, a), (W * .5 + .16, 2.6, b), "trim")
    # Wheel housings.
    for z in AXLES:
        k.box((.4, .66, z), (.62, .6, 1.2), "interior", .1)
        k.box((W - .4, .66, z), (.62, .6, 1.2), "interior", .1)
    # Seats: doubles along the west side, singles on the east between the doors, the back bench.
    def seat(x, z, w):
        k.box((x, F + .42, z), (w, .1, .44), "seat", .03)
        k.box((x, F + .78, z - .25), (w, .6, .07), "seat", .025, rot=rot_x(-.12))
        k.box((x, F + .78, z - .29), (w - .02, .58, .02), "trim", .0, rot=rot_x(-.12))
        k.bar((x - w * .5 + .05, F + 1.13, z - .3), (x + w * .5 - .05, F + 1.13, z - .3), .03, "chrome")
        k.span((x - .05, F, z - .05), (x + .05, F + .37, z + .05), "trim")
    z = .9
    while z < 9.9:
        seat(.58, z, .84)
        if (z < DOORS[0] - .7 or z > DOORS[0] + .7) and z < DOORS[1] - .7:
            seat(2.1, z, .5)
        if int((z - .9) / .82) % 2 == 0:
            k.cyl((1.04, F, z - .3), (1.04, 2.4, z - .3), .022, "yellow", 8)
        z += .82
    k.box((W * .5, F + .42, .42), (W - .3, .1, .5), "seat", .03)
    k.box((W * .5, F + .85, .17), (W - .3, .8, .07), "seat", .025)
    # Poles at the doors, the rails along the ceiling, the straps (each at its own angle).
    for d in DOORS:
        for dz in (-.62, .62):
            k.cyl((W - .2, F, d + dz), (W - .2, 2.4, d + dz), .022, "yellow", 8)
        k.cyl((W - .2, 2.0, d - .62), (W - .2, 2.0, d + .62), .018, "yellow", 8)
    for x in (.55, 1.95):
        k.cyl((x, 2.38, .6), (x, 2.38, 10.0), .018, "chrome", 8)
        sz = 1.0
        while sz < 10.0:
            tilt = rot_x(r.uniform(-.3, .3))
            k.box((x, 2.22, sz), (.025, .3, .03), "strap", 0.0, rot=Matrix.Translation((0, 0, 0)) @ tilt)
            k.box((x, 2.05, sz), (.11, .07, .025), "strap", .01)
            sz += .9
    for d in DOORS:
        k.box((W - .2, 1.4, d - .62), (.05, .07, .05), "lamp_rear", .01)
    # The driver's place: seat, wheel, dash and its gauges, the partition, the fare box.
    k.box((.56, F + .45, 10.7), (.6, .12, .55), "dark", .04)
    k.box((.56, F + .9, 10.4), (.6, .8, .1), "dark", .04)
    k.span((.1, F, 11.55), (W - .1, F + 1.0, L - .08), "dark", .04)
    k.span((.15, F + .98, 11.35), (1.1, F + 1.12, 11.9), "trim", .03)
    for i in range(3):
        k.cyl((.35 + i * .25, F + 1.12, 11.6), (.35 + i * .25, F + 1.13, 11.6), .07, "lamp_front", 12)
    wc = Vector((.56, F + 1.05, 11.25))
    for i in range(16):
        a0 = i / 16 * math.tau
        a1 = (i + 1) / 16 * math.tau
        tilt = rot_x(-1.0)
        p0 = wc + (tilt @ Vector((math.cos(a0) * .23, math.sin(a0) * .23, 0)))
        p1 = wc + (tilt @ Vector((math.cos(a1) * .23, math.sin(a1) * .23, 0)))
        k.bar(p0, p1, .03, "dark")
    k.cyl(wc, wc + Vector((0, -.35, .25)), .03, "dark", 8)
    k.span((.1, F, 10.28), (1.06, 2.3, 10.32), "trim")
    k.box((.58, 1.75, 10.3), (.9, .9, .015), "glass")
    k.box((1.75, F + .6, 10.0), (.3, 1.2, .3), "metal", .03)
    k.box((1.75, F + 1.05, 10.16), (.2, .14, .02), "dark")
    # A ceiling panel come down at the back, hanging by one corner, its wires out.
    if walk:
        k.box((W * .5, 2.2, 7.9), (.9, .02, 1.0), "interior", 0.0, rot=Matrix.Translation((0, 0, 0)) @ rot_x(.5) @ rot_z(.25))
        for i in range(4):
            k.bar((1.0 + i * .12, 2.6, 8.3), (1.0 + i * .14 + r.uniform(-.2, .2), 1.95 + r.uniform(-.2, .2), 8.1), .008, "dark")
    # ------------------------------------------------------------ the doors
    def leaf(c, rot, glass_ok):
        k.box(c, (.045, 2.1, .56), "trim", .015, rot=rot)
        for yy in (.55, -.45):
            off = rot @ Vector((0, yy, 0))
            if glass_ok:
                k.box((c[0] + off.x, c[1] + off.y, c[2] + off.z), (.05, .75, .42), "glass", 0.0, rot=rot)
    if walk:
        d = DOORS[0]
        # Rear door: one leaf off and lying on the road outside, the other torn back off its hinge, hanging.
        k.box((W + 1.05, .06, d - .2), (.56, .045, 2.1), "trim", .015, rot=rot_y(.35))
        k.shards((W + .82, .09, d - 1.0), (W + 1.3, .09, d + .6), "z", "glass", 4) if False else None
        for i in range(10):
            p = Vector((W + r.uniform(.2, 1.6), .015, d + r.uniform(-1.2, 1.0)))
            k.quad([p, p + Vector((r.uniform(.04, .12), 0, r.uniform(-.06, .06))), p + Vector((r.uniform(-.05, .05), 0, r.uniform(.05, .14)))], "glass")
        hinge = Vector((W + .03, 1.4, d - .62))
        sw = rot_y(-1.25) @ rot_z(.18)
        k.box(tuple(hinge + sw @ Vector((0, 0, -.3))), (.045, 2.0, .56), "trim", .015, rot=sw)
        k.shards((W + .005, F + .05, d - .52), (W + .005, 2.5, d + .52), "x", "glass", 6)
        # Front door: folded in against its frame, one leaf's glass gone.
        d = DOORS[1]
        for sgn in (-1, 1):
            c = (W - .2, 1.42, d + sgn * .42)
            leaf(c, rot_y(sgn * 1.25), sgn > 0)
        k.shards((W + .005, F + .05, d - .52), (W + .005, 2.5, d + .52), "x", "glass", 4)
    else:
        for d in DOORS:
            for sgn in (-1, 1):
                leaf((W - .01, 1.42, d + sgn * .28), Matrix.Identity(4), True)
            k.box((W + .005, 1.42, d), (.02, 2.1, .02), "dark")
    # Door frames: rubber all round each opening.
    for d in DOORS:
        for dz in (-.56, .56):
            k.box((W - .01, 1.45, d + dz), (.08, 2.2, .05), "dark")
        k.box((W - .01, 2.53, d), (.08, .06, 1.16), "dark")


# ============================================================================================ the metro car

CW = 2.9
CL = 18.6
C_DOORS = (3.5, 9.3, 15.1)


def metro(k, kind):
    """kind "a": the rear car (shut end at z 0, gangway at the front, the west door at 9.3 forced);
    kind "b": the leading car (gangway at z 0, the driver's cab at the front, its evacuation door down)."""
    r = k.r
    W, L = CW, CL
    forced = 9.3 if kind == "a" else -1.0
    # Underframe, bogies, equipment cases.
    k.span((.1, -1.0, 1.4), (W - .1, -.45, L - 1.4), "dark")
    for bz in (2.6, L - 2.6):
        k.span((.55, -.95, bz - 1.25), (W - .55, -.62, bz + 1.25), "dark", .04)
        for wz in (bz - .9, bz + .9):
            for x, side in ((.85, -1), (2.05, 1)):
                k.wheel((x, -.73, wz), .42, .12, side, "metal", "metal")
        k.span((.4, -.8, bz - .2), (W - .4, -.55, bz + .2), "trim")
    for i in range(5):
        z0 = 4.6 + i * 2.0
        k.span((.3, -1.05, z0), (W - .3, -.5, z0 + 1.5), ["dark", "trim"][i % 2], .03)
    # Body sides: skirt, window band (pillars, glass), the band over it; door openings and the doors.
    def side(x, out):
        cuts = [(d - .66, d + .66) for d in C_DOORS]
        z = 0.0
        for (a, b) in cuts + [(L, L)]:
            if a > z:
                k.box((x, .2, (z + a) * .5), (.07, 1.6, a - z), "paint", .02)
                k.box((x + out * .004, .62, (z + a) * .5), (.01, .14, a - z), "paint2")
                k.box((x, 2.38, (z + a) * .5), (.07, .66, a - z), "paint", .02)
                # Windows between doors: two panes with a mullion.
                n = max(1, int((a - z) / 2.4))
                for i in range(n):
                    pa = z + .25 + i * (a - z - .5) / n
                    pb = z + .25 + (i + 1) * (a - z - .5) / n - .12
                    k.box((x, 1.5, pa - .06), (.07, 1.1, .14), "paint", .02)
                    xo = x + out * .01
                    for yy in (.96, 2.04):
                        k.box((xo, yy, (pa + pb) * .5), (.03, .04, pb - pa), "dark")
                    gone = r.random() < .2
                    if gone:
                        k.shards((xo, .98, pa + .02), (xo, 2.02, pb - .02), "x", "glass", 5)
                    else:
                        k.box((xo, 1.5, (pa + pb) * .5), (.012, 1.04, pb - pa), "glass")
                k.box((x, 1.5, a - .1), (.07, 1.1, .2), "paint", .02)
            z = b
        for d in C_DOORS:
            k.box((x, 2.25, d), (.07, .4, 1.32), "paint", .02)
            for dz in (-.66, .66):
                k.box((x + out * .01, 1.0, d + dz), (.05, 2.05, .05), "dark")
            if out < 0 and abs(d - forced) < .1:
                # Forced: one leaf shoved back into its pocket, the other wrenched off its track, hanging out.
                k.box((x + .04, 1.02, d - 1.0), (.04, 2.0, .64), "metal", .01)
                hang = rot_y(.55) @ rot_z(-.14)
                k.box((x - .3, .95, d + .72), (.04, 1.92, .64), "metal", .01, rot=hang)
                k.box((x - .32, 1.35, d + .72), (.045, .8, .5), "dark", .0, rot=hang)
                k.shards((x - .005, .08, d - .6), (x - .005, 2.0, d + .6), "x", "glass", 6)
                for i in range(5):
                    a = Vector((x - .01, r.uniform(.3, 1.7), d + r.uniform(-.6, .6)))
                    k.bar(a, a + Vector((0, r.uniform(-.2, .2), r.uniform(-.4, .4))), .006, "crack")
                continue
            for sgn in (-1, 1):
                c = (x + out * .02, 1.02, d + sgn * .33)
                k.box(c, (.04, 2.04, .64), "metal", .01)
                k.box((c[0] + out * .006, 1.45, c[2]), (.01, .8, .44), "glass")
            k.box((x + out * .03, 1.02, d), (.015, 2.0, .02), "dark")
    side(0.0, -1)
    side(W, 1)
    # Roof: rounded along both sides; vents.
    k.box((W * .5, 2.92, L * .5), (W, .5, L), "paint", .32, 5)
    for i in range(3):
        k.box((W * .5, 3.2, 3.5 + i * 5.8), (1.4, .14, 1.8), "trim", .05, 2)
    # Floor, linings, the ceiling with its light coves (the tubes glow from outer_world.gd).
    k.span((.06, -.08, .06), (W - .06, 0, L - .06), "floor")
    for x in (.08, W - .08):
        k.span((x - .02, 0, .2), (x + .02, .95, L - .2), "interior")
    k.span((.1, 2.62, .1), (W - .1, 2.66, L - .1), "interior")
    for x in (.1, W - .52):
        k.span((x, 2.45, .1), (x + .42, 2.62, L - .1), "interior")
    k.span((W * .5 - .2, 2.6, .5), (W * .5 + .2, 2.62, L - .5), "trim")
    # Benches between the doors, the poles at the doors, rails and straps.
    segs = []
    last = .3
    for d in C_DOORS:
        segs.append((last, d - .8))
        last = d + .8
    segs.append((last, (L - 2.2) if kind == "b" else L - .3))
    for (a, b) in segs:
        if b - a < .4:
            continue
        for x, s in ((.32, 1), (W - .32, -1)):
            k.span((x - .25, .38, a), (x + .25, .46, b), "seat", .03)
            k.span((x - .2, 0, a + .05), (x + .2, .38, b - .05), "trim")
            k.box((x - s * .2, .78, (a + b) * .5), (.07, .6, b - a), "seat", .02)
            for z in range(int((b - a) / .48)):
                k.span((x - .25, .46, a + z * .48 + .46), (x + .25, .52, a + z * .48 + .48), "trim")
    for d in C_DOORS:
        for px in (.75, W - .75):
            k.cyl((px, 0, d), (px, 2.62, d), .022, "chrome", 8)
    for px in (.55, W - .55):
        k.cyl((px, 2.3, .4), (px, 2.3, L - .4), .02, "chrome", 8)
        sz = .8
        while sz < L - .8:
            tilt = rot_x(r.uniform(-.35, .35))
            k.box((px, 2.13, sz), (.025, .3, .03), "strap", 0.0, rot=tilt)
            k.box((px, 1.96, sz), (.11, .07, .025), "strap", .01)
            sz += .75
    # Ad frames over the windows (outer_world.gd puts the pictures in them).
    for i in range(int(L / 2.4)):
        for x in (.1, W - .1):
            k.box((x, 2.3, 1.2 + i * 2.4), (.03, .4, 1.7), "trim", .01)
    # The ends.
    def end_wall(z, out, gangway):
        if gangway:
            k.span((0, 0, z - .06), (W * .5 - .6, 2.9, z + .06), "paint")
            k.span((W * .5 + .6, 0, z - .06), (W, 2.9, z + .06), "paint")
            k.span((W * .5 - .6, 2.08, z - .06), (W * .5 + .6, 2.9, z + .06), "paint")
            for dx in (-.62, .62):
                k.box((W * .5 + dx, 1.04, z), (.06, 2.1, .14), "dark")
            # The bellows: dark folds out to the next car.
            for i in range(5):
                zz = z + out * (.06 + i * .075)
                k.box((W * .5, 1.1, zz), (1.5, 2.3, .04), "dark", .02)
                k.span((W * .5 - .7, 0, zz - .02), (W * .5 - .64, 2.2, zz + .02), "rubber")
                k.span((W * .5 + .64, 0, zz - .02), (W * .5 + .7, 2.2, zz + .02), "rubber")
            for i in range(5):
                zz = z + out * (.06 + i * .075)
                k.span((W * .5 - .64, 2.2, zz - .02), (W * .5 + .64, 2.26, zz + .02), "rubber")
        else:
            k.span((0, -.4, z - .06), (W, 2.9, z + .06), "paint", .02)
            k.box((W * .5, 1.55, z + out * .065), (1.3, .9, .01), "glass")
            for x in (.35, W - .35):
                k.box((x, .3, z + out * .07), (.24, .12, .02), "lamp_rear", .01)
            k.box((W * .5, -.3, z + out * .2), (.5, .3, .4), "dark", .03)
    if kind == "a":
        end_wall(0.0, -1, False)
        end_wall(L, 1, True)
    else:
        end_wall(0.0, -1, True)
        # The cab: partition with its door open, console, seat; the front: windscreen, lamps, evacuation door down.
        pz = L - 2.0
        k.span((0, 0, pz), (1.05, 2.62, pz + .06), "interior")
        k.span((W - 1.05, 0, pz), (W, 2.62, pz + .06), "interior")
        k.span((1.05, 2.05, pz), (W - 1.05, 2.62, pz + .06), "interior")
        k.box((1.45, 1.0, pz + .45), (.05, 1.95, .8), "interior", .01, rot=rot_y(-1.2))
        k.span((.12, 0, L - 1.2), (.95, .92, L - .12), "dark", .04)
        k.box((.55, .98, L - .65), (.7, .06, .4), "trim", .02, rot=rot_x(-.5))
        k.box((.55, .45, L - 1.55), (.48, .1, .48), "dark", .03)
        k.box((.55, .85, L - 1.8), (.48, .7, .08), "dark", .03)
        k.span((0, -.4, L - .1), (W * .5 - .62, 2.9, L), "paint", .02)
        k.span((W * .5 + .62, -.4, L - .1), (W, 2.9, L), "paint", .02)
        k.span((W * .5 - .62, 1.96, L - .1), (W * .5 + .62, 2.9, L), "paint", .02)
        k.span((W * .5 - .62, -.4, L - .1), (W * .5 + .62, -.1, L), "paint")
        k.box((W * .5, 2.4, L + .05), (W - .3, .9, .02), "glass", 0.0, rot=rot_x(-.15))
        k.box((W * .5, 1.6, L + .02), (W - .2, .1, .08), "dark")
        k.box((W * .5, .35, L + .06), (W - .2, .18, .1), "paint2", .02)
        for x in (.45, W - .45):
            k.box((x, .6, L + .03), (.34, .2, .04), "dark", .02)
        k.box((W * .5, -.45, L + .25), (.6, .3, .5), "dark", .03)
        for dx in (-.64, .64):
            k.box((W * .5 + dx, .98, L - .05), (.06, 2.0, .1), "dark")


# ============================================================================================ road vehicles

def car_wheels(k, xs, zs, r, w, tyre="rubber"):
    for z in zs:
        for x in xs:
            side = 1 if x > 0 else -1
            k.wheel((x, r, z), r, w, side, tyre)
            k.ring((x + side * (w * .5 + .01), r, z), "x", r + .03, r + .1, -math.pi * .5, math.pi * .5, .04, "dark", 10)


def greenhouse(k, w, y0, y1, zb, zr0, zr1, zf, inset, wreck, pillars=3):
    """Pillars, roof and glass of a car's cabin: base corners at y0 from zb (back) to zf (front), the roof at y1 from
    zr0 to zr1, narrowed by `inset` at the top. `wreck`: the glass gone (teeth left), so the inside shows."""
    r = k.r
    hw = w * .5
    top = hw - inset
    k.hull([(-top, y1 - .06, zr0), (top, y1 - .06, zr0), (-top, y1 - .06, zr1), (top, y1 - .06, zr1),
            (-top + .04, y1, zr0 + .04), (top - .04, y1, zr0 + .04), (-top + .04, y1, zr1 - .04), (top - .04, y1, zr1 - .04)], "paint", .03)
    for sx in (-1, 1):
        base_b = Vector((sx * (hw - .02), y0, zb))
        base_f = Vector((sx * (hw - .02), y0, zf))
        k.bar(base_f, Vector((sx * top, y1 - .05, zr1)), .07, "paint")
        k.bar(base_b, Vector((sx * top, y1 - .05, zr0)), .1, "paint")
        if pillars >= 3:
            zm = (zr0 + zr1) * .5
            k.bar(Vector((sx * (hw - .03), y0, zm + .1)), Vector((sx * top, y1 - .05, zm)), .07, "paint")
        # Side glass.
        pts = [Vector((sx * (hw - .03), y0 + .02, zb + .12)), Vector((sx * (hw - .03), y0 + .02, zf - .12)),
               Vector((sx * (top + .01), y1 - .08, zr1 - .05)), Vector((sx * (top + .01), y1 - .08, zr0 + .05))]
        if not wreck or r.random() < .3:
            k.quad(pts, "glass")
        else:
            for i in range(4):
                a = pts[i]
                b = pts[(i + 1) % 4]
                m = a.lerp(b, r.uniform(.2, .8))
                k.quad([a.lerp(b, .1), m, m.lerp((pts[0] + pts[2]) * .5, r.uniform(.1, .3))], "glass")
    # Windscreen and back glass.
    for (zbase, ztop, keep) in ((zf, zr1, not wreck), (zb, zr0, not wreck or r.random() < .5)):
        pts = [Vector((-hw + .06, y0 + .02, zbase)), Vector((hw - .06, y0 + .02, zbase)), Vector((top - .03, y1 - .07, ztop)), Vector((-top + .03, y1 - .07, ztop))]
        if keep:
            k.quad(pts, "glass")
        else:
            for i in range(5):
                a = pts[0].lerp(pts[1], r.random())
                k.quad([a, a + Vector((r.uniform(.05, .2), 0, 0)), a.lerp(pts[2], r.uniform(.1, .3))], "glass")
    if wreck:
        for i in range(5):
            a = Vector((r.uniform(-hw, hw), y0 + .01, r.uniform(zb, zf)))
            k.bar(a, a + Vector((r.uniform(-.3, .3), 0, r.uniform(-.3, .3))), .004, "crack")


def cabin_inside(k, w, y_floor, zb, zf, rows=2):
    hw = w * .5
    k.span((-hw + .08, y_floor, zb + .1), (hw - .08, y_floor + .05, zf), "interior")
    for i in range(rows):
        z = zf - .55 - i * .85
        for x in ((-.38, .38) if i == 0 else (0.0,)):
            ww = .5 if i == 0 else w - .3
            k.box((x, y_floor + .3, z), (ww, .14, .5), "seat", .04)
            k.box((x, y_floor + .62, z - .27), (ww, .6, .1), "seat", .04, rot=rot_x(-.2))
    k.span((-hw + .1, y_floor + .4, zf - .4), (hw - .1, y_floor + .58, zf - .08), "dark", .03)
    wc = Vector((-.38, y_floor + .62, zf - .5))
    k.cyl(wc + Vector((0, 0, -.02)), wc + Vector((0, 0, .02)), .18, "dark", 14)


def sedan(k, wreck, taxi=False):
    r = k.r
    w, l = 1.76, 4.5
    hw = w * .5
    # Lower body: one hull, the nose and tail drawn in.
    k.hull([(-hw, .32, -2.1), (hw, .32, -2.1), (-hw, .32, 2.05), (hw, .32, 2.05),
            (-hw + .05, .92, -2.2), (hw - .05, .92, -2.2), (-hw + .02, .9, 1.4), (hw - .02, .9, 1.4),
            (-hw + .08, .78, 2.22), (hw - .08, .78, 2.22), (-hw + .1, .4, 2.25), (hw - .1, .4, 2.25),
            (-hw + .06, .42, -2.25), (hw - .06, .42, -2.25), (-hw + .02, .98, -1.4), (hw - .02, .98, -1.4)], "paint", .05, 3)
    # Hood, crumpled up on a wreck.
    if wreck:
        k.box((0, 1.0, 1.75), (w - .25, .04, 1.0), "paint", .01, rot=Matrix.Translation((0, 0, 0)) @ rot_x(-.45) @ rot_z(.08))
        k.box((0, .82, 1.7), (w - .3, .2, .7), "dark", .02)
    greenhouse(k, w, .94, 1.44, -1.55, -1.0, .45, 1.05, .14, wreck)
    cabin_inside(k, w, .38, -1.4, 1.0)
    car_wheels(k, (-.77, .77), (-1.38, 1.32), .31, .2)
    for sx in (-1, 1):
        k.box((sx * (hw - .18), .76, 2.2), (.36, .14, .1), "lamp_front", .03)
        k.box((sx * (hw - .16), .8, -2.22), (.32, .14, .06), "lamp_rear", .02)
        k.box((sx * (hw + .06), 1.05, 1.0), (.1, .09, .15), "dark", .02)
        for z in (-.3, .55):
            k.box((sx * (hw + .002), .8, z), (.01, .03, .12), "trim")
        k.box((sx * (hw + .003), .62, -.05), (.005, .5, .01), "dark")
    k.box((0, .45, 2.27), (w - .1, .14, .08), "trim", .03)
    k.box((0, .45, -2.27), (w - .1, .14, .08), "trim", .03)
    k.box((0, .64, 2.26), (.7, .14, .02), "dark")
    if taxi:
        k.box((0, 1.52, -.25), (.62, .16, .26), "paint2", .03)
    if wreck:
        # The driver's door hanging open.
        hinge = Vector((-hw, .65, .9))
        rot = rot_y(-.95)
        k.box(tuple(hinge + rot @ Vector((0, 0, -.5))), (.06, .62, 1.0), "paint", .02, rot=rot)
        k.box(tuple(hinge + rot @ Vector((.035, .05, -.5))), (.012, .5, .9), "interior", .0, rot=rot)


def van(k, wreck):
    """A cab-over van (the FB type): flat nose, sliding door on the right."""
    w, l = 1.7, 4.6
    hw = w * .5
    k.hull([(-hw, .3, -2.25), (hw, .3, -2.25), (-hw, .3, 2.2), (hw, .3, 2.2),
            (-hw, 1.15, -2.3), (hw, 1.15, -2.3), (-hw, 1.15, 2.28), (hw, 1.15, 2.28)], "paint", .05, 3)
    k.hull([(-hw, 1.15, -2.3), (hw, 1.15, -2.3), (-hw, 1.15, 2.28), (hw, 1.15, 2.28),
            (-hw + .06, 1.95, -2.25), (hw - .06, 1.95, -2.25), (-hw + .06, 1.95, 1.95), (hw - .06, 1.95, 1.95)], "paint", .06, 3)
    for sx in (-1, 1):
        k.box((sx * (hw + .004), 1.0, 0), (.01, .1, 4.4), "paint2")
        for (a, b) in ((-2.1, -1.0), (-.9, .4), (.6, 1.9)):
            if wreck and sx > 0 and a == -.9:
                continue
            k.box((sx * (hw + .003), 1.52, (a + b) * .5), (.012, .6, b - a), "glass" if not (wreck and k.r.random() < .5) else "dark")
    k.box((0, 1.55, 2.29), (w - .16, .7, .02), "glass", 0.0, rot=rot_x(-.12))
    car_wheels(k, (-.72, .72), (-1.4, 1.35), .3, .19)
    for sx in (-1, 1):
        k.box((sx * (hw - .2), .7, 2.3), (.3, .16, .04), "lamp_front", .02)
        k.box((sx * (hw - .1), .85, -2.31), (.16, .3, .04), "lamp_rear", .01)
    k.box((0, .42, 2.32), (w, .16, .08), "trim", .03)
    k.box((0, .42, -2.32), (w, .16, .08), "trim", .03)
    cabin_inside(k, w, .42, -2.0, 1.7, 3)
    if wreck:
        # The sliding door off its track, leaning against the side; the inside dark.
        k.box((hw + .35, .95, -.25), (.05, 1.4, 1.2), "paint", .02, rot=rot_z(-.25) @ rot_y(.1))
        k.span((hw - .02, .42, -.85), (hw, 1.9, .35), "dark")


def pickup(k, wreck):
    w = 1.8
    hw = w * .5
    k.hull([(-hw, .38, -2.6), (hw, .38, -2.6), (-hw, .38, 2.5), (hw, .38, 2.5),
            (-hw, 1.0, -2.6), (hw, 1.0, -2.6), (-hw + .05, 1.02, 1.5), (hw - .05, 1.02, 1.5),
            (-hw + .1, .9, 2.6), (hw - .1, .9, 2.6), (-hw + .1, .45, 2.62), (hw - .1, .45, 2.62)], "paint", .05, 3)
    greenhouse(k, w, 1.0, 1.78, -.2, -.05, .5, 1.25, .1, wreck, 2)
    cabin_inside(k, w, .5, -.15, 1.25, 1)
    # The bed: floor and sides (open).
    k.span((-hw + .05, 1.0, -2.55), (hw - .05, 1.04, -.3), "dark")
    for sx in (-1, 1):
        k.span((sx * hw - .04, 1.0, -2.6), (sx * hw + .04, 1.45, -.25), "paint", .02)
    k.span((-hw, 1.0, -2.65), (hw, 1.45, -2.57), "paint", .02)
    car_wheels(k, (-.8, .8), (-1.75, 1.6), .38, .24)
    for sx in (-1, 1):
        k.box((sx * (hw - .2), .85, 2.6), (.34, .16, .06), "lamp_front", .02)
        k.box((sx * (hw - .05), 1.15, -2.62), (.08, .3, .04), "lamp_rear", .01)
    k.box((0, .5, 2.66), (w, .18, .1), "chrome", .03)
    if wreck:
        k.box((-.2, 1.2, -1.4), (.8, .3, .6), "rust", .03, rot=rot_y(.4))
        k.box((.4, 1.15, -2.0), (.5, .2, .5), "trim", .02, rot=rot_y(-.3))


def truck(k, wreck):
    """A light truck: cab-over front and a box body behind (its back doors open on a wreck)."""
    w = 2.0
    hw = w * .5
    k.hull([(-hw, .45, 2.0), (hw, .45, 2.0), (-hw, .45, 3.65), (hw, .45, 3.65),
            (-hw + .04, 2.35, 2.0), (hw - .04, 2.35, 2.0), (-hw + .08, 2.3, 3.45), (hw - .08, 2.3, 3.45),
            (-hw, 1.2, 3.7), (hw, 1.2, 3.7)], "paint", .07, 3)
    k.box((0, 1.75, 3.62), (w - .2, .9, .02), "glass", 0.0, rot=rot_x(-.12))
    for sx in (-1, 1):
        k.box((sx * (hw + .004), 1.75, 2.75), (.012, .7, 1.0), "glass")
        k.box((sx * (hw - .25), .85, 3.7), (.36, .2, .05), "lamp_front", .02)
    cabin_inside(k, w, .95, 2.1, 3.3, 1)
    k.span((-.9, .55, -3.6), (.9, .9, 2.0), "dark")
    bw = 2.3
    k.span((-bw * .5, .95, -3.7), (bw * .5, 3.25, 1.9), "metal", .03)
    for i in range(14):
        z = -3.6 + i * .4
        for sx in (-1, 1):
            k.box((sx * (bw * .5 + .01), 2.1, z), (.02, 2.3, .05), "trim")
    k.span((-bw * .5 - .02, 3.22, -3.72), (bw * .5 + .02, 3.28, 1.92), "trim")
    if wreck:
        k.span((-bw * .5 + .05, .99, -3.65), (bw * .5 - .05, 1.0, 1.85), "dark")
        for sx in (-1, 1):
            hinge = Vector((sx * bw * .5, 2.1, -3.72))
            rot = rot_y(sx * 1.9)
            k.box(tuple(hinge + rot @ Vector((-sx * .57, 0, 0))), (1.14, 2.2, .05), "metal", .02, rot=rot)
        k.span((-bw * .5 + .05, 1.0, -3.68), (bw * .5 - .05, 3.2, -3.62), "dark") if False else None
    else:
        k.span((-bw * .5, .95, -3.76), (bw * .5, 3.25, -3.7), "metal")
        k.box((0, 2.1, -3.77), (.02, 2.2, .02), "dark")
    car_wheels(k, (-.85, .85), (-2.2, 2.75), .42, .26)
    for sx in (-1, 1):
        k.box((sx * (bw * .5 - .2), .8, -3.78), (.3, .14, .04), "lamp_rear", .01)


# ============================================================================================ main

def preview(obj, name):
    os.makedirs(PREVIEW, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x = 960
    scene.render.resolution_y = 600
    for m in bpy.data.materials:
        m.diffuse_color = {"paint": (.85, .83, .78, 1), "paint2": (.1, .45, .44, 1), "glass": (.2, .3, .36, 1),
                           "dark": (.05, .05, .05, 1), "rubber": (.04, .04, .04, 1), "seat": (.17, .29, .47, 1),
                           "interior": (.78, .76, .7, 1), "floor": (.17, .18, .17, 1), "trim": (.25, .26, .26, 1),
                           "chrome": (.72, .74, .74, 1), "rim": (.5, .52, .52, 1), "yellow": (.85, .66, .08, 1),
                           "lamp_front": (.9, .88, .8, 1), "lamp_rear": (.5, .08, .06, 1), "lamp_amber": (.8, .48, .1, 1),
                           "metal": (.62, .64, .64, 1), "strap": (.82, .8, .74, 1), "crack": (.9, .92, .92, 1),
                           "rust": (.45, .25, .15, 1)}.get(m.name, (.6, .6, .6, 1))
    bb = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    c = (lo + hi) * .5
    size = (hi - lo).length
    for i, (ax, ay, az) in enumerate(((1.0, -1.0, .55), (-1.0, 1.2, .5))):
        cam_data = bpy.data.cameras.new("cam")
        cam_data.lens = 40
        cam = bpy.data.objects.new("cam", cam_data)
        bpy.context.scene.collection.objects.link(cam)
        d = Vector((ax, ay, az)).normalized()
        cam.location = c + d * size * 1.05
        cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.camera = cam
        scene.render.filepath = os.path.join(PREVIEW, "%s_%d.png" % (name, i))
        bpy.ops.render.render(write_still=True)
        bpy.data.objects.remove(cam, do_unlink=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    builds = [
        ("bus_walk", lambda k: bus(k, True), 11),
        ("bus_shut", lambda k: bus(k, False), 12),
        ("metro_a", lambda k: metro(k, "a"), 21),
        ("metro_b", lambda k: metro(k, "b"), 22),
        ("sedan", lambda k: sedan(k, False), 31),
        ("sedan_wreck", lambda k: sedan(k, True), 32),
        ("taxi_wreck", lambda k: sedan(k, True, True), 33),
        ("van", lambda k: van(k, False), 41),
        ("van_wreck", lambda k: van(k, True), 42),
        ("pickup_wreck", lambda k: pickup(k, True), 51),
        ("truck", lambda k: truck(k, False), 61),
        ("truck_wreck", lambda k: truck(k, True), 62),
    ]
    only = [a for a in ARGS if not a.startswith("--")]
    for name, fn, seed in builds:
        if only and name not in only:
            continue
        clear_scene()
        k = Kit(seed)
        fn(k)
        obj = k.finish(name)
        export(obj, name + ".glb")
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        print("VEHICLE %s: %d tris, materials %s" % (name, tris, ",".join(k.mats)))
        if "--preview" in ARGS:
            preview(obj, name)


main()
