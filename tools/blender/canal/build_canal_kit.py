"""Custom models for the abandoned canal settlement (0.17): stilt shanties and garbage.

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P tools/blender/canal/build_canal_kit.py

Writes GLBs to game/assets/models/canal/kit/ plus kit.json (per-house dimensions and collision boxes in
Godot coordinates). Every house is modelled piece by piece: salvaged plank, plywood and corrugated sheet
skins over a timber frame, hollow-block bases, broken jalousies, boarded and gaping openings, lean-to
roofs weighed down with tyres and rocks, timber stilts standing in the river, rotten floor joists that
are visible from the catwalk below, PVC drains, and old spray paint. The settlement is abandoned:
nothing is lit, sheets are missing, boards are gone, tarps are torn.

House space (Blender, Z up): +X points out over the river (rear), Y runs along the bank, Z=0 is the
top of the bank. The catwalk runs at Z=-2.3 between X=0.6 and X=1.9, so stilts stand at X<0.5 or
X>2.0 and nothing hangs lower than Z=-0.2 above it. glTF export maps (x, y, z) to Godot (x, z, -y).
Material names match keys that canal_settlement.gd binds to the project's photographic PBR sets;
UVs are in metres (planar per face), "decal ..." faces carry 0..1 UVs.
"""
import json
import math
import os
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "game", "assets", "models", "canal", "kit")
TAGS = os.path.join(ROOT, "game", "assets", "outdoor", "canal", "tags")
CATWALK = (0.6, 1.9)
CATWALK_Z = -2.3
BED_Z = -4.55

PAINTS = ["paint 0", "paint 1", "paint 2", "paint 3", "paint 4", "paint 5"]
DECALS = sorted(f[:-4] for f in os.listdir(TAGS) if f.endswith(".png")) if os.path.isdir(TAGS) else []


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)


def material(name):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    return mat


class Builder:
    """Accumulates one mesh with per-face materials; planar metre UVs unless a face is explicit."""

    def __init__(self, seed):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.mats = []
        self.explicit = {}
        self.r = random.Random(seed)

    def mi(self, name):
        if name not in self.mats:
            self.mats.append(name)
        return self.mats.index(name)

    def face(self, pts, mat, uvs=None, smooth=False):
        verts = [self.bm.verts.new(Vector(p)) for p in pts]
        try:
            f = self.bm.faces.new(verts)
        except ValueError:
            return None
        f.material_index = self.mi(mat)
        f.smooth = smooth
        if uvs is not None:
            self.explicit[f] = uvs
        return f

    def plate(self, pts, mat, uvs=None):
        self.face(pts, mat, uvs)
        self.face(list(reversed(pts)), mat, list(reversed(uvs)) if uvs else None)

    def box(self, c, size, mat, rot=None):
        c = Vector(c)
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        rot = rot or Matrix.Identity(3)
        corners = [c + rot @ Vector((sx * hx, sy * hy, sz * hz)) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
        idx = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        for q in idx:
            self.face([corners[i] for i in q], mat)

    def beam(self, a, b, w, h, mat, roll=0.0):
        """Rectangular timber between two points."""
        a, b = Vector(a), Vector(b)
        d = b - a
        length = d.length
        if length < 1e-4:
            return
        z = d.normalized()
        up = Vector((0, 0, 1)) if abs(z.z) < .95 else Vector((1, 0, 0))
        x = up.cross(z).normalized()
        y = z.cross(x)
        rot = Matrix((x, y, z)).transposed() @ Matrix.Rotation(roll, 3, "Z")
        self.box((a + b) / 2, (w, h, length), mat, rot)

    def cyl(self, a, b, r, mat, seg=8, caps=True, r2=None):
        a, b = Vector(a), Vector(b)
        d = b - a
        if d.length < 1e-4:
            return
        z = d.normalized()
        up = Vector((0, 0, 1)) if abs(z.z) < .95 else Vector((1, 0, 0))
        x = up.cross(z).normalized()
        y = z.cross(x)
        r2 = r if r2 is None else r2
        ring_a = [a + (x * math.cos(t) + y * math.sin(t)) * r for t in (math.tau * i / seg for i in range(seg))]
        ring_b = [b + (x * math.cos(t) + y * math.sin(t)) * r2 for t in (math.tau * i / seg for i in range(seg))]
        circ = math.tau * r
        for i in range(seg):
            j = (i + 1) % seg
            u0, u1 = circ * i / seg, circ * (i + 1) / seg
            self.face([ring_a[i], ring_a[j], ring_b[j], ring_b[i]], mat, [(u0, 0), (u1, 0), (u1, d.length), (u0, d.length)], True)
        if caps:
            self.face(list(reversed(ring_a)), mat)
            self.face(ring_b, mat)

    def blob(self, c, size, mat, subdiv=2, rough=.18, squash=1.0, folds=0.0):
        """Lumpy closed shape (bags, rocks, sacks)."""
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=subdiv, radius=1.0)
        idx = self.mi(mat)
        ox, oy, oz = (self.r.uniform(0, 50) for _ in range(3))
        mapping = {}
        for v in tmp.verts:
            n = v.co.normalized()
            bump = 1 + rough * (math.sin(n.x * 5.1 + ox) * math.sin(n.y * 4.3 + oy) * math.sin(n.z * 6.2 + oz) * 1.6
                                + self.r.uniform(-.5, .5))
            if folds:
                # Crumpled plastic: sharp creases rather than smooth lumps.
                bump -= folds * abs(math.sin(n.x * 14 + ox) * math.sin(n.y * 12 + oy + n.z * 9))
            p = Vector((n.x * size[0] / 2 * bump, n.y * size[1] / 2 * bump, n.z * size[2] / 2 * bump))
            if p.z < 0:
                p.z *= squash
            mapping[v] = self.bm.verts.new(Vector(c) + p)
        for f in tmp.faces:
            nf = self.bm.faces.new([mapping[v] for v in f.verts])
            nf.material_index = idx
            nf.smooth = True
        tmp.free()

    def finish(self, name):
        bm = self.bm
        bm.normal_update()
        for f in bm.faces:
            if f in self.explicit:
                for loop, uv in zip(f.loops, self.explicit[f]):
                    loop[self.uv].uv = uv
                continue
            n = f.normal
            mat = self.mats[f.material_index]
            ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
            for loop in f.loops:
                co = loop.vert.co
                if az >= ax and az >= ay:
                    uv = (co.y, co.x) if mat in ("roof", "tin") else (co.x, co.y)
                elif ax >= ay:
                    uv = (co.y if n.x > 0 else -co.y, -co.z)
                else:
                    uv = (-co.x if n.y > 0 else co.x, -co.z)
                loop[self.uv].uv = uv
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        for m in self.mats:
            mesh.materials.append(material(m))
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def export(objs, filename):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, filename), export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_materials="EXPORT",
                              export_texcoords=True, export_normals=True)


def to_godot_box(lo, hi):
    c = [(lo[i] + hi[i]) / 2 for i in range(3)]
    s = [abs(hi[i] - lo[i]) for i in range(3)]
    return {"center": [round(c[0], 3), round(c[2], 3), round(-c[1], 3)], "size": [round(s[0], 3), round(s[2], 3), round(s[1], 3)]}


# ------------------------------------------------------------------------------------------- house parts

class House:
    def __init__(self, seed, spec):
        self.b = Builder(seed)
        self.r = self.b.r
        self.spec = spec
        self.colliders = []
        self.doors = []

    # A wall is described in its own frame: origin o, along unit a (horizontal), outward normal n.
    def wall(self, o, a, n, length, height, skin, openings, base=0.0, base_mat="block", paint=None, inner=True):
        b, r = self.b, self.r
        o, a, n = Vector(o), Vector(a), Vector(n)
        up = Vector((0, 0, 1))
        seams = set()
        t = r.uniform(.8, 1.8)
        while t < length - .4:
            seams.add(round(t, 3))
            t += r.uniform(.9, 2.2)
        cuts = sorted({0.0, length} | seams | {max(0, min(length, v)) for op in openings for v in (op[0], op[1])})
        patch_skin = {}
        for sa, sb in zip(cuts, cuts[1:]):
            key = max([c for c in [0.0] + sorted(seams) if c <= sa + 1e-4])
            if key not in patch_skin:
                patch_skin[key] = skin if r.random() > .38 or skin in ("block", "cement") else r.choice(["planks", "ply", "tin", "tin", "planks"])
            col_skin = patch_skin[key]
            if sb - sa < .01:
                continue
            mid = (sa + sb) / 2
            blocked = sorted((op[2], op[3]) for op in openings if op[0] <= mid <= op[1])
            spans, z = [], 0.0
            for z0, z1 in blocked:
                if z0 > z:
                    spans.append((z, z0))
                z = max(z, z1)
            if z < height:
                spans.append((z, height))
            for z0, z1 in spans:
                if base > 0 and z0 < base:
                    self.solid(o, a, n, sa, sb, z0, min(z1, base), base_mat, .14)
                    z0 = base
                if z1 - z0 > .01:
                    self.skin(o, a, n, sa, sb, z0, z1, col_skin, paint)
        # Timber frame: corner studs and plates show at gaps and missing boards.
        for s in (0.02, length - .02):
            b.box(o + a * s - n * .06 + up * height / 2, self.frame_size(a, n, .08, .08, height), "wood")
        b.box(o + a * length / 2 - n * .06 + up * (height - .05), self.frame_size(a, n, length, .08, .1), "wood")

    def frame_size(self, a, n, along, across, h):
        # Box sizes are axis aligned in house space; walls run along X or Y only.
        if abs(a.x) > .5:
            return (along, across, h)
        return (across, along, h)

    def solid(self, o, a, n, sa, sb, z0, z1, mat, t):
        up = Vector((0, 0, 1))
        c = o + a * ((sa + sb) / 2) + up * ((z0 + z1) / 2) - n * (t / 2 - .02)
        self.b.box(c, self.frame_size(a, n, sb - sa, t, z1 - z0), mat)

    def skin(self, o, a, n, sa, sb, z0, z1, skin, paint):
        b, r = self.b, self.r
        up = Vector((0, 0, 1))
        if skin in ("block", "cement"):
            mat = paint if (paint and skin == "cement") else ("block" if skin == "block" else "cement")
            self.solid(o, a, n, sa, sb, z0, z1, mat, .13)
            return
        if skin == "planks":
            w = .2
            s = math.floor(sa / w) * w
            mat = paint if paint and r.random() < .4 else r.choice(["wood", "wood grey"])
            while s < sb - .005:
                s0, s1 = max(s, sa), min(s + w, sb)
                s += w
                roll = r.random()
                if roll < .07 and z1 - z0 > 1.2:
                    continue  # board gone
                top = z1 if roll > .12 else z0 + (z1 - z0) * r.uniform(.4, .85)  # snapped board
                jit = r.uniform(-.012, .012)
                c = o + a * ((s0 + s1) / 2) + up * ((z0 + top) / 2) + n * (.012 + jit)
                bm = mat if r.random() > .15 else r.choice(["wood", "wood grey"])
                b.box(c, self.frame_size(a, n, (s1 - s0) - .012, .022, top - z0), bm,
                      Matrix.Rotation(r.uniform(-.012, .012), 3, n))
            for h in (z0 + .25, z1 - .2):  # horizontal nailers
                if z0 + .1 < h < z1 - .05:
                    b.box(o + a * ((sa + sb) / 2) + up * h - n * .02, self.frame_size(a, n, sb - sa, .04, .07), "wood")
            return
        if skin == "ply":
            # Painted plywood sheets with battens over the joints; some peeled back to the grey wood.
            panel = 1.22
            s = math.floor(sa / panel) * panel
            while s < sb - .005:
                s0, s1 = max(s, sa), min(s + panel, sb)
                s += panel
                mat = paint if r.random() > .2 else "wood grey"
                if r.random() < .06 and z1 - z0 > 1.5:
                    continue
                c = o + a * ((s0 + s1) / 2) + up * ((z0 + z1) / 2) + n * .01
                b.box(c, self.frame_size(a, n, s1 - s0, .018, z1 - z0), mat, Matrix.Rotation(r.uniform(-.01, .01), 3, n))
                b.box(o + a * s1 + up * ((z0 + z1) / 2) + n * .024, self.frame_size(a, n, .05, .02, z1 - z0), "wood grey")
            return
        if skin == "tin":
            sheet = r.uniform(.72, .86)
            s = sa
            while s < sb - .005:
                s1 = min(s + sheet, sb)
                mat = "roof" if r.random() < .5 else "tin"
                if r.random() < .05 and z1 - z0 > 1.4:
                    s = s1
                    continue
                lift = r.uniform(.0, .03)
                c = o + a * ((s + s1) / 2) + up * ((z0 + z1) / 2 + lift) + n * (.01 + r.uniform(0, .02))
                rot = Matrix.Rotation(r.uniform(-.025, .025), 3, n) @ Matrix.Rotation(r.uniform(-.03, .03), 3, up)
                b.box(c, self.frame_size(a, n, (s1 - s) + .06, .012, z1 - z0 - lift), mat, rot)
                s = s1
            return
        raise ValueError(skin)

    def window(self, o, a, n, s, z, w, h, kind):
        """Frame and infill for an opening centred at s (bottom z) in a wall frame."""
        b, r = self.b, self.r
        o, a, n = Vector(o), Vector(a), Vector(n)
        up = Vector((0, 0, 1))
        c = o + a * s + up * (z + h / 2)
        for dz in (-h / 2 - .03, h / 2 + .03):
            b.box(c + up * dz + n * .03, self.frame_size(a, n, w + .14, .06, .06), "wood")
        for ds in (-w / 2 - .035, w / 2 + .035):
            b.box(c + a * ds + n * .03, self.frame_size(a, n, .06, .06, h + .12), "wood")
        if kind == "jalousie":
            for i in range(int(h / .11)):
                if r.random() < .35:
                    continue  # broken or missing slat
                zz = z + .06 + i * .11
                tilt = Matrix.Rotation(r.uniform(.5, 1.1) * (1 if abs(a.x) > .5 else -1), 3, a)
                mat = "glass" if r.random() < .8 else "rust"
                ww = w if r.random() > .2 else w * r.uniform(.3, .7)
                b.box(o + a * (s - (w - ww) / 2) + up * zz + n * .01, self.frame_size(a, n, ww, .004, .1), mat, tilt)
            for ds in (-w / 2 + .02, w / 2 - .02):
                b.box(c + a * ds + n * .015, self.frame_size(a, n, .03, .04, h), "rust")
        elif kind == "grille":
            for i in range(int(w / .12) + 1):
                p = c + a * (-w / 2 + i * w / max(1, int(w / .12)))
                bend = up * 0 + n * (.02 + (r.uniform(0, .08) if r.random() < .15 else 0))
                b.cyl(p + n * .05 - up * h / 2, p + bend + n * .05 + up * h / 2, .007, "rust", 5, False)
            for dz in (-h / 4, h / 4):
                b.box(c + up * dz + n * .055, self.frame_size(a, n, w, .012, .025), "rust")
        elif kind == "boarded":
            for i in range(r.randint(2, 4)):
                ang = r.uniform(-.5, .5)
                b.box(c + n * (.05 + i * .02) + up * r.uniform(-h * .3, h * .3),
                      self.frame_size(a, n, w * 1.25, .022, .14), r.choice(["wood", "wood grey"]), Matrix.Rotation(ang, 3, n))
        elif kind == "shutter":
            # A plywood shutter hanging from one hinge, swung out and dropped.
            hinge = c + a * (-w / 2) + n * .04 + up * (h / 2)
            ang = r.uniform(.4, 1.3)
            rot = Matrix.Rotation(-ang if abs(a.x) > .5 else ang, 3, up) @ Matrix.Rotation(r.uniform(-.25, .25), 3, n)
            off = rot @ (a * (w / 2) - up * (h / 2))
            b.box(hinge + off, self.frame_size(a, n, w, .02, h), r.choice(PAINTS + ["wood grey"]), rot)
        elif kind == "curtain":
            # Rotten cloth caught in the frame, torn into strips.
            strips = r.randint(3, 6)
            for i in range(strips):
                s0 = -w / 2 + i * w / strips
                length = h * r.uniform(.35, .95)
                top = c + up * (h / 2) + n * .025
                p0, p1 = top + a * s0, top + a * (s0 + w / strips * .92)
                sway = n * r.uniform(-.03, .05)
                b.plate([p0, p1, p1 - up * length + sway, p0 - up * length * r.uniform(.8, 1.1) + sway],
                        "cloth %d" % r.randint(0, 3))

    def door(self, o, a, n, s, w, h, kind):
        b, r = self.b, self.r
        o, a, n = Vector(o), Vector(a), Vector(n)
        up = Vector((0, 0, 1))
        c = o + a * s + up * (h / 2)
        for ds in (-w / 2 - .04, w / 2 + .04):
            b.box(c + a * ds + n * .03, self.frame_size(a, n, .07, .08, h + .05), "wood")
        b.box(c + up * (h / 2 + .04) + n * .03, self.frame_size(a, n, w + .16, .08, .08), "wood")
        if kind == "planks":
            hinge = c + a * (-w / 2)
            ang = r.uniform(0, .5)
            rot = Matrix.Rotation(ang if n.x * a.y - n.y * a.x > 0 else -ang, 3, up)
            for i in range(int(w / .16)):
                if r.random() < .08:
                    continue
                p = hinge + rot @ (a * (.08 + i * .16)) - n * .02
                b.box(p, self.frame_size(a, n, .15, .03, h - .04), r.choice(["wood", "wood grey"]), rot)
            for dz in (-.7, .7):
                b.box(hinge + rot @ (a * (w / 2)) + up * dz - n * .045, self.frame_size(a, n, w * .95, .025, .1), "wood", rot)
        elif kind == "metal":
            b.box(c + n * .01 + up * .02, self.frame_size(a, n, w, .02, h - .04), r.choice(["rust", "shutter"]),
                  Matrix.Rotation(r.uniform(-.03, .03), 3, n))
        elif kind == "boarded":
            for i in range(4):
                b.box(c + n * (.05 + i * .015) + up * (-h * .35 + i * h * .23),
                      self.frame_size(a, n, w * 1.3, .022, .16), r.choice(["wood", "wood grey"]),
                      Matrix.Rotation(r.uniform(-.35, .35), 3, n))
        # "open": nothing, the dark interior shows.

    def decal(self, o, a, n, s, z, w, name):
        """Spray paint on a wall face: a quad 4 cm proud of the frame plane."""
        o, a, n = Vector(o), Vector(a), Vector(n)
        up = Vector((0, 0, 1))
        h = w * (.5 if name.startswith(("throw", "sign", "census")) else 1.0)
        c = o + a * s + up * z + n * .05
        p0, p1 = c - a * w / 2 - up * h / 2, c + a * w / 2 - up * h / 2
        self.b.face([p0, p1, p1 + up * h, p0 + up * h], "decal " + name, [(0, 0), (1, 0), (1, 1), (0, 1)])

    def roof(self, x0, x1, y0, y1, z_low, z_high, toward_x, decay):
        """Lean-to roof of overlapping corrugated sheets on purlins; sheets run down the slope."""
        b, r = self.b, self.r
        run = x1 - x0
        slope = (z_high - z_low) / run
        # Height at x: highest at the far side from toward_x.
        def zat(x):
            t = (x - x0) / run
            return z_high - (z_high - z_low) * (t if toward_x > 0 else 1 - t)
        ang = math.atan(slope) * (-1 if toward_x > 0 else 1)
        rot = Matrix.Rotation(-ang, 3, "Y")
        for i in range(4):
            x = x0 + .15 + i * (run - .3) / 3
            b.box((x, (y0 + y1) / 2, zat(x) - .08), (.06, y1 - y0 + .1, .08), "wood")
        y = y0 - .12
        while y < y1 + .1:
            w = r.uniform(.72, .9)
            if r.random() < decay * .35:
                y += w * r.uniform(.6, 1.0)
                continue  # sheet blown off: open to the dark interior
            lift = r.uniform(0, .04)
            sag = Matrix.Rotation(r.uniform(-.03, .03), 3, "X")
            cx = (x0 + x1) / 2 + r.uniform(-.08, .08)
            b.box((cx, y + w / 2, zat(cx) + .01 + lift), (run / math.cos(ang) + .5, w + .07, .012),
                  "roof" if r.random() < .75 else "tin", rot @ sag)
            y += w * r.uniform(.82, .95)
        # Weights against typhoon winds: old tyres, rocks and loose timber.
        for _ in range(r.randint(1, 4)):
            x, yy = r.uniform(x0 + .3, x1 - .3), r.uniform(y0 + .3, y1 - .3)
            z = zat(x) + .05
            k = r.random()
            if k < .45:
                self.tyre((x, yy, z + .06), .3, rot)
            elif k < .75:
                b.blob((x, yy, z + .08), (.25, .22, .16), "rock", 1, .25)
            else:
                b.beam((x - .9, yy, z + .05), (x + .9, yy + r.uniform(-.4, .4), z + .05), .08, .04, "wood")

    def tyre(self, c, radius, rot=None):
        rot = rot or Matrix.Identity(3)
        seg = 14
        c = Vector(c)
        tube = radius * .32
        for i in range(seg):
            t0, t1 = math.tau * i / seg, math.tau * (i + 1) / seg
            for j in range(6):
                p0, p1 = math.tau * j / 6, math.tau * (j + 1) / 6
                def pt(t, p):
                    rr = radius + math.cos(p) * tube
                    return c + rot @ Vector((math.cos(t) * rr, math.sin(t) * rr, math.sin(p) * tube * .7))
                self.b.face([pt(t0, p0), pt(t1, p0), pt(t1, p1), pt(t0, p1)], "rubber", None, True)

    def awning(self, o, a, n, s, z, w):
        """A sheet of tin on two timber brackets, sloping out and sagging."""
        b, r = self.b, self.r
        o, a, n = Vector(o), Vector(a), Vector(n)
        up = Vector((0, 0, 1))
        depth = r.uniform(.45, .75)
        c = o + a * s + up * z
        drop = r.uniform(.12, .25)
        p0, p1 = c - a * w / 2 + n * .04, c + a * w / 2 + n * .04
        q0 = p0 + n * depth - up * drop + up * r.uniform(-.05, .05)
        q1 = p1 + n * depth - up * drop + up * r.uniform(-.05, .05)
        mat = "roof" if r.random() < .6 else "tin"
        b.face([p0, p1, q1, q0], mat)
        b.face([p0, q0, q1, p1], mat)
        for e in (p0 + a * .1, p1 - a * .1):
            b.beam(e - up * .45, e + n * (depth * .8) - up * (drop * .8), .04, .04, "wood")

    def interior(self, x0, x1, y0, y1, z0, z1):
        """Black void behind every opening and gap."""
        self.b.box(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0 - .16, y1 - y0 - .16, z1 - z0 - .06), "inside")

    def joists(self, x0, x1, y0, y1, z, decay):
        """Floor of a cantilevered storey: rotten planks on joists, seen from the catwalk below."""
        b, r = self.b, self.r
        y = y0 + .1
        while y < y1:
            if r.random() > .06:
                b.box(((x0 + x1) / 2, y, z - .16), (x1 - x0, .06, .14), "wood", Matrix.Rotation(r.uniform(-.01, .01), 3, "X"))
            y += .45
        x = x0
        while x < x1 - .01:
            w = min(.2, x1 - x)
            if r.random() > decay * .12:
                b.box((x + w / 2, (y0 + y1) / 2, z - .04), (w - .01, y1 - y0, .035), r.choice(["wood", "wood grey"]))
            else:
                b.box((x + w / 2, y0 + (y1 - y0) * .3, z - .06), (w - .01, (y1 - y0) * .55, .035), "wood",
                      Matrix.Rotation(r.uniform(-.2, .2), 3, "X"))  # broken board hanging
            x += w
        b.box(((x0 + x1) / 2, y0 + .02, z - .12), (x1 - x0, .05, .2), "wood")
        b.box(((x0 + x1) / 2, y1 - .02, z - .12), (x1 - x0, .05, .2), "wood")

    def stilt(self, x, y, top, bottom, lean=.0):
        b, r = self.b, self.r
        if r.random() < .25:
            b.cyl((x + lean, y, bottom), (x, y, top), .045, "rust", 7)
        else:
            b.beam((x + lean, y + r.uniform(-.05, .05), bottom), (x, y, top), .1, .1, "wood", r.uniform(-.1, .1))
        self.colliders.append(to_godot_box((x - .06, y - .06, bottom), (x + .06, y + .06, top)))

    def pipe(self, pts, r_=.04, mat="pvc"):
        for p0, p1 in zip(pts, pts[1:]):
            self.b.cyl(p0, p1, r_, mat, 8, False)
        for p in pts[1:-1]:
            self.b.cyl(Vector(p) - Vector((0, 0, .05)), Vector(p) + Vector((0, 0, .05)), r_ * 1.25, mat, 8)

    def drum(self, c):
        b = self.b
        c = Vector(c)
        b.cyl(c, c + Vector((0, 0, .88)), .29, "plastic blue", 14)
        for h in (.3, .6):
            b.cyl(c + Vector((0, 0, h - .015)), c + Vector((0, 0, h + .015)), .3, "plastic blue", 14)

    def dish(self, c, facing):
        b, r = self.b, self.r
        c = Vector(c)
        b.cyl(c, c + Vector((0, 0, .5)), .02, "rust", 6)
        rot = Matrix.Rotation(facing, 3, "Z") @ Matrix.Rotation(r.uniform(.9, 1.6), 3, "Y")
        seg, rad = 12, .3
        centre = c + Vector((0, 0, .55))
        for i in range(seg):
            t0, t1 = math.tau * i / seg, math.tau * (i + 1) / seg
            q = [centre, centre + rot @ Vector((math.cos(t0) * rad, math.sin(t0) * rad, .08)),
                 centre + rot @ Vector((math.cos(t1) * rad, math.sin(t1) * rad, .08))]
            b.plate(q + [q[0]] if False else q, "tin")
        b.cyl(centre, centre + rot @ Vector((0, 0, .35)), .01, "rust", 4)

    def rags(self, a, c, count):
        """A sagging line with a few rotten rags left behind."""
        b, r = self.b, self.r
        a, c = Vector(a), Vector(c)
        prev = a
        n = 10
        for i in range(1, n + 1):
            t = i / n
            p = a.lerp(c, t) - Vector((0, 0, math.sin(t * math.pi) * .18))
            b.cyl(prev, p, .006, "wire", 4, False)
            prev = p
        side = (c - a).normalized()
        for i in range(count):
            t = r.uniform(.15, .85)
            p = a.lerp(c, t) - Vector((0, 0, math.sin(t * math.pi) * .18))
            w, h = r.uniform(.25, .5), r.uniform(.3, .7)
            twist = Vector((r.uniform(-.06, .06), r.uniform(-.06, .06), 0))
            b.plate([p, p + side * w, p + side * w - Vector((0, 0, h * r.uniform(.7, 1))) + twist,
                     p - Vector((0, 0, h)) + twist], "cloth %d" % r.randint(0, 3))

    def tarp(self, o, a, n, s0, s1, z_top, drop, mat):
        """Torn tarp nailed over a wall: jagged lower edge, slightly proud and wavy."""
        b, r = self.b, self.r
        o, a, n = Vector(o), Vector(a), Vector(n)
        up = Vector((0, 0, 1))
        steps = 8
        for i in range(steps):
            t0, t1 = s0 + (s1 - s0) * i / steps, s0 + (s1 - s0) * (i + 1) / steps
            d0 = drop * r.uniform(.45, 1.0)
            d1 = drop * r.uniform(.45, 1.0)
            bulge = n * (.06 + r.uniform(0, .05))
            q = [o + a * t0 + up * z_top + n * .06, o + a * t1 + up * z_top + n * .06,
                 o + a * t1 + up * (z_top - d1) + bulge, o + a * t0 + up * (z_top - d0) + bulge]
            b.plate(q, mat)


def build_house(index, spec):
    """spec: width, depth, storeys, row ('river' or 'back'), seed."""
    h = House(spec["seed"], spec)
    r, b = h.r, h.b
    W, D, row = spec["width"], spec["depth"], spec["row"]
    river = row == "river"
    decay = r.uniform(.4, 1.0)
    y0, y1 = -W / 2, W / 2
    X, Y = Vector((1, 0, 0)), Vector((0, 1, 0))
    z = 0.0
    x_back = -D
    # Ground-storey overhang toward +X: none, bracketed, or out over the catwalk on stilts in the river.
    if river:
        o_prev = r.choice([0.0, 0.0, .4, 2.2, 2.2])
    else:
        o_prev = 0.0
    storeys = spec["storeys"]
    front_paint = r.choice(PAINTS)
    for k in range(storeys):
        start_verts = len(b.bm.verts)
        hgt = r.uniform(2.45, 2.8) if k == 0 else r.uniform(2.15, 2.45)
        if k == 0:
            xa, xb = x_back, o_prev
        else:
            set_back = r.uniform(0, 1.6) if r.random() < .5 else 0
            out = (r.uniform(.6, 1.6) if r.random() < .55 else r.uniform(0, .4)) if river else r.uniform(0, .7)
            xa, xb = x_back + set_back, max(.0, min(2.35, o_prev + out)) if river else min(.8, o_prev + out)
            if k == storeys - 1 and river and r.random() < .4:
                xb = min(xb, o_prev)  # top storey stays over the one below
        ya, yb = y0, y1
        skin = r.choice(["planks", "ply", "tin", "planks", "tin"]) if k > 0 else r.choice(["planks", "ply", "tin", "cement", "block"])
        paint = r.choice(PAINTS)
        base = r.uniform(.35, .95) if (k == 0 and skin not in ("block", "cement")) else 0.0
        h.interior(xa, xb, ya, yb, z, z + hgt)
        # Floor of this storey where it hangs beyond the bank (visible from below).
        if k == 0 and xb > .05:
            h.joists(0.0, xb, ya, yb, z, decay)
        elif k > 0 and xb > o_prev + .05:
            h.joists(o_prev, xb, ya, yb, z, decay)
            # Knee braces from the storey below.
            for yy in (ya + .1, (ya + yb) / 2, yb - .1):
                b.beam((o_prev, yy, z - 1.1), (xb - .05, yy, z - .12), .07, .07, "wood")
        # Rear (+X) wall: windows and sometimes a door to a balcony.
        n_win = max(1, int((yb - ya) / 1.6))
        rear_open = []
        for i in range(n_win):
            s = (i + .5) * (yb - ya) / n_win
            w = r.uniform(.6, 1.0)
            rear_open.append((s - w / 2, s + w / 2, 1.0, 1.0 + r.uniform(.7, .95)))
        if not river and k == 0:
            # Lane houses: the door is on the +X face, which is turned toward the lane.
            ds = r.uniform(.8, (yb - ya) - .8)
            rear_open = [op for op in rear_open if op[1] < ds - .55 or op[0] > ds + .55]
            rear_open.append((ds - .45, ds + .45, 0, 2.0))
        h.wall((xb, ya, z), Y, X, yb - ya, hgt, skin, rear_open, base if (k == 0 and xb < .05) else 0, paint=paint)
        for op in rear_open:
            if op[2] == 0:
                kind = r.choice(["planks", "metal", "boarded", "open", "planks"])
                h.door((xb, ya, z), Y, X, (op[0] + op[1]) / 2, op[1] - op[0], op[3], kind)
                h.doors.append({"kind": kind, "s": (op[0] + op[1]) / 2, "side": "+x"})
                continue
            h.window((xb, ya, z), Y, X, (op[0] + op[1]) / 2, op[2], op[1] - op[0], op[3] - op[2],
                     r.choice(["jalousie", "grille", "boarded", "shutter", "curtain", "open", "jalousie"]))
        # Front (-X) wall: the lane side of river houses, the blind back of lane houses.
        front_open = []
        door_s = None
        if k == 0 and river:
            door_s = r.uniform(.8, W - .8)
            front_open.append((door_s - .45, door_s + .45, 0, 2.0))
            ws = r.uniform(.6, W - .6)
            if abs(ws - door_s) > 1.1:
                front_open.append((ws - .4, ws + .4, 1.05, 1.85))
        elif river and r.random() < .7:
            ws = r.uniform(.6, W - .6)
            front_open.append((ws - .45, ws + .45, 1.0, 1.85))
        # Front wall is built with its outward normal -X, running from y1 to y0.
        h.wall((xa, yb, z), -Y, -X, yb - ya, hgt, skin, front_open, base, paint=front_paint if k == 0 else paint)
        for op in front_open:
            s = (op[0] + op[1]) / 2
            if op[2] == 0:
                kind = r.choice(["planks", "planks", "metal", "boarded", "open"])
                h.door((xa, yb, z), -Y, -X, s, op[1] - op[0], op[3], kind)
                h.doors.append({"kind": kind, "s": s})
            else:
                h.window((xa, yb, z), -Y, -X, s, op[2], op[1] - op[0], op[3] - op[2],
                         r.choice(["jalousie", "grille", "boarded", "curtain", "open"]))
        # Side walls (mostly blind, shared with neighbours).
        for side, yy, nn in ((-1, ya, -Y), (1, yb, Y)):
            ops = []
            if r.random() < .35 and xb - xa > 2:
                s = r.uniform(.8, xb - xa - .8)
                ops.append((s - .35, s + .35, 1.1, 1.8))
            if side < 0:
                h.wall((xa, yy, z), X, nn, xb - xa, hgt, skin, ops, base, paint=paint)
                for op in ops:
                    h.window((xa, yy, z), X, nn, (op[0] + op[1]) / 2, op[2], .7, .7, r.choice(["boarded", "open", "grille"]))
            else:
                h.wall((xb, yy, z), -X, nn, xb - xa, hgt, skin, ops, base, paint=paint)
                for op in ops:
                    h.window((xb, yy, z), -X, nn, (op[0] + op[1]) / 2, op[2], .7, .7, r.choice(["boarded", "open", "grille"]))
        # Vandalism and relocation marks.
        if DECALS:
            census = [d for d in DECALS if d.startswith("census")]
            tags = [d for d in DECALS if not d.startswith("census") and not d.startswith("sign")]
            if k == 0 and not river:
                h.decal((xb, ya, z), Y, X, r.uniform(.6, W - .6), r.uniform(1.3, 2.1), r.uniform(.7, 1.0), r.choice(census))
            if k == 0 and river:
                h.decal((xa, yb, z), -Y, -X, r.uniform(.6, W - .6), r.uniform(1.3, 2.1), r.uniform(.7, 1.0), r.choice(census))
            for _ in range(r.randint(0, 2)):
                if k == 0:
                    h.decal((xa, yb, z), -Y, -X, r.uniform(.6, W - .6), r.uniform(.5, 1.6), r.uniform(.6, 1.5), r.choice(tags))
                if r.random() < .6:
                    h.decal((xb, ya, z), Y, X, r.uniform(.5, W - .5), r.uniform(.4, 1.8), r.uniform(.6, 1.4), r.choice(tags))
        # Torn tarp patches.
        if r.random() < .3:
            s0 = r.uniform(0, W * .5)
            h.tarp((xb, ya, z), Y, X, s0, min(W, s0 + r.uniform(1, 2.2)), hgt - .1, r.uniform(.8, 1.8),
                   r.choice(["tarp blue", "tarp orange", "tarp blue"]))
        # Stilts in the river under any cantilever that reaches past the catwalk.
        if river and k == 0 and xb > 2.0:
            for yy in [ya + .12 + i * (yb - ya - .24) / max(1, int((yb - ya) / 1.5)) for i in range(int((yb - ya) / 1.5) + 1)]:
                h.stilt(xb - .12, yy, z - .2, BED_Z, r.uniform(-.12, .12))
            for yy in (ya + .12,):
                # X bracing in the plane of the outer stilts (outside the catwalk railing).
                b.beam((xb - .12, ya + .12, -1.0), (xb - .12, yb - .12, -3.6), .05, .05, "wood")
                b.beam((xb - .12, yb - .12, -1.0), (xb - .12, ya + .12, -3.6), .05, .05, "wood")
            h.colliders.append(to_godot_box((0.0, ya, -.32), (xb, yb, z + hgt)))
        elif river and k == 0 and xb > .05:
            for yy in (ya + .2, yb - .2):
                b.beam((xb - .05, yy, -.15), (.02, yy, -.9), .08, .08, "wood")
        if k == 0:
            h.colliders.append(to_godot_box((xa, ya, 0), (min(xb, 0.0) if river else xb, yb, hgt)))
        # Balcony on the river face of an upper storey.
        if river and k > 0 and xb < 1.7 and r.random() < .45:
            depth = r.uniform(.6, 2.3 - xb)
            b.box((xb + depth / 2, (ya + yb) / 2, z - .04), (depth, yb - ya - .3, .06), r.choice(["wood", "wood grey"]))
            for yy in (ya + .2, yb - .2):
                b.beam((xb, yy, z - 1.0), (xb + depth - .05, yy, z - .08), .06, .06, "wood")
            rail_x = xb + depth - .03
            posts = int((yb - ya) / .9) + 1
            for i in range(posts):
                yy = ya + .2 + i * (yb - ya - .4) / max(1, posts - 1)
                if r.random() < .12:
                    continue
                b.beam((rail_x, yy, z), (rail_x + r.uniform(-.04, .04), yy, z + 1.0), .05, .05, "wood")
            b.beam((rail_x, ya + .2, z + .98), (rail_x, yb - .2 - (r.uniform(0, 1) if r.random() < .3 else 0), z + 1.0 - r.uniform(0, .15)), .06, .04, "wood")
            if r.random() < .5:
                h.drum((xb + depth * .5, ya + .6, z))
            if r.random() < .55:
                h.rags((rail_x, ya + .25, z + 1.85), (rail_x, yb - .25, z + 1.8), r.randint(1, 3))
        if k > 0:
            b.bm.verts.ensure_lookup_table()
            pivot = Vector(((xa + xb) / 2, (ya + yb) / 2, z))
            lean = Matrix.Rotation(r.uniform(-.025, .025), 3, "X") @ Matrix.Rotation(r.uniform(-.018, .018), 3, "Y") @ Matrix.Rotation(r.uniform(-.03, .03), 3, "Z")
            for v in b.bm.verts[start_verts:]:
                v.co = pivot + lean @ (v.co - pivot)
        # Tin awnings on brackets over some openings.
        for op in rear_open:
            if op[2] > 0 and r.random() < .45:
                h.awning((xb, ya, z), Y, X, (op[0] + op[1]) / 2, op[3] + .12, op[1] - op[0] + .4)
        for op in front_open:
            if r.random() < .5:
                h.awning((xa, yb, z), -Y, -X, (op[0] + op[1]) / 2, op[3] + .12, op[1] - op[0] + .5)
        o_prev = xb
        x_back = xa
        z += hgt
        top = (xa, xb, ya, yb, z)
    # Roof over the top storey: lean-to toward the river or the lane.
    xa, xb, ya, yb, z = top
    toward = 1 if r.random() < .6 else -1
    h.roof(xa - r.uniform(.45, .8), xb + r.uniform(.5, .9), ya - r.uniform(.2, .45), yb + r.uniform(.2, .45), z + .05, z + .05 + r.uniform(.35, .7), toward, decay)
    if r.random() < .25:
        h.dish((xa + .5, ya + .5, z + .3), r.uniform(0, math.tau))
    if r.random() < .3:
        h.drum((xa + .6, yb - .6, z + .2))
    # Drain pipes: from the roof edge down the bank between the wall and the catwalk, outfall above water.
    if river:
        for _ in range(r.randint(1, 2)):
            yy = r.uniform(ya + .3, yb - .3)
            if xb > 2.0:
                pts = [(xb + .05, yy, z), (xb + .05, yy, -.3), (xb + .1, yy, -3.7)]
            else:
                pts = [(max(xb, 0) + .06, yy, z), (.3, yy, -.4), (.3, yy, -2.6), (.45, yy, -3.2)]
            h.pipe(pts, r.uniform(.03, .05), r.choice(["pvc", "pvc", "pvc grey"]))
    # Front steps and a meter box on the lane side.
    if river:
        b.box((-D - .3, (y0 + y1) / 2, .07), (.55, min(1.3, W - .4), .14), r.choice(["cement", "wood"]))
        b.box((-D - .06, y0 + .35, 1.6), (.08, .2, .28), "rust")
    else:
        b.box((.3, 0, .07), (.55, min(1.3, W - .4), .14), "cement")
    obj = b.finish("house_%02d" % index)
    return obj, h


def flip_back_house(obj):
    """Lane-side houses are authored like river houses; their door side must face +X (the lane)."""
    pass


# ------------------------------------------------------------------------------------------- garbage

TRASH_PLASTIC = ["plastic black", "plastic white", "plastic red", "plastic green", "plastic blue", "plastic yellow"]


def trash_item(b, c, scale=1.0):
    r = b.r
    c = Vector(c)
    k = r.random()
    if k < .32:  # plastic bag, knotted
        s = Vector((r.uniform(.25, .45), r.uniform(.22, .4), r.uniform(.16, .3))) * scale
        bag = r.choice(TRASH_PLASTIC)
        b.blob(c + Vector((0, 0, s.z * .4)), s, bag, 3, .25, .5, .35)
        b.blob(c + Vector((0, 0, s.z * 1.25)), (s.x * .22, s.y * .22, s.z * .35), bag, 1, .4)  # knot
    elif k < .42:  # woven sack
        s = Vector((r.uniform(.45, .7), r.uniform(.3, .4), r.uniform(.18, .28))) * scale
        b.blob(c + Vector((0, 0, s.z * .4)), s, "sack", 2, .12, .4)
    elif k < .55:  # PET bottle on its side
        ang = r.uniform(0, math.tau)
        d = Vector((math.cos(ang), math.sin(ang), 0))
        length = r.uniform(.2, .32) * scale
        b.cyl(c + Vector((0, 0, .04)), c + d * length + Vector((0, 0, .04)), .04 * scale, r.choice(["pet", "pet", "glass green"]), 8)
        b.cyl(c + d * length + Vector((0, 0, .04)), c + d * (length + .05) + Vector((0, 0, .04)), .014 * scale, "plastic white", 6)
    elif k < .62:  # styrofoam
        b.box(c + Vector((0, 0, .05)), (r.uniform(.2, .5) * scale, r.uniform(.15, .35) * scale, r.uniform(.04, .12)), "foam",
              Matrix.Rotation(r.uniform(0, math.tau), 3, "Z") @ Matrix.Rotation(r.uniform(-.3, .3), 3, "X"))
    elif k < .7:  # crushed can
        b.cyl(c + Vector((0, 0, .03)), c + Vector((r.uniform(-.1, .1), r.uniform(-.1, .1), .04)), .03, "can", 7)
    elif k < .8:  # wet cardboard
        b.box(c + Vector((0, 0, .01)), (r.uniform(.3, .6), r.uniform(.25, .5), .012), "cardboard",
              Matrix.Rotation(r.uniform(0, math.tau), 3, "Z") @ Matrix.Rotation(r.uniform(-.15, .15), 3, "Y"))
    elif k < .86:  # slipper
        b.blob(c + Vector((0, 0, .012)), (.26 * scale, .1 * scale, .025), r.choice(["plastic blue", "plastic red", "rubber"]), 1, .1)
    elif k < .93:  # sachet / wrapper litter
        for _ in range(4):
            p = c + Vector((r.uniform(-.2, .2), r.uniform(-.2, .2), .006))
            ang = r.uniform(0, math.tau)
            dx, dy = math.cos(ang) * .06, math.sin(ang) * .06
            b.plate([p + Vector((-dx, -dy, 0)), p + Vector((dy, -dx, 0)), p + Vector((dx, dy, .004)), p + Vector((-dy, dx, 0))],
                    r.choice(TRASH_PLASTIC + ["foil"]))
    else:  # broken plank
        ang = r.uniform(0, math.tau)
        d = Vector((math.cos(ang), math.sin(ang), 0))
        b.beam(c + Vector((0, 0, .03)), c + d * r.uniform(.5, 1.2) + Vector((0, 0, .05)), .1, .025, r.choice(["wood", "wood grey"]))


def build_heap(name, radius, height, items, seed, mound=True):
    b = Builder(seed)
    r = b.r
    if mound:
        # Rotting base layer: black organic muck under the items.
        b.blob((0, 0, -height * .25), (radius * 2, radius * 1.7, height * 1.1), "muck", 3, .22, .1)
    for _ in range(items):
        ang, d = r.uniform(0, math.tau), radius * math.sqrt(r.random())
        x, y = math.cos(ang) * d, math.sin(ang) * d
        z = (height * .5) * (1 - (d / radius) ** 2) if mound else 0
        trash_item(b, (x, y, z - .05), r.uniform(.8, 1.3))
    if mound and r.random() < .7:
        House.tyre(type("T", (), {"b": b})(), (r.uniform(-radius, radius) * .5, r.uniform(-radius, radius) * .5, height * .35), .32,
                   Matrix.Rotation(r.uniform(-.6, .6), 3, "X"))
    return b.finish(name)


def build_floating(name, length, width, seed):
    """Flat raft of floating rubbish caught against the bank or a stilt."""
    b = Builder(seed)
    r = b.r
    for _ in range(int(length * width * 14)):
        x = r.uniform(-length / 2, length / 2)
        y = r.uniform(-width / 2, width / 2) * (1 - abs(x) / length)
        k = r.random()
        if k < .4:
            b.blob((x, y, .0), (r.uniform(.15, .35), r.uniform(.12, .3), .1), r.choice(TRASH_PLASTIC), 1, .2, .2)
        elif k < .65:
            ang = r.uniform(0, math.tau)
            d = Vector((math.cos(ang), math.sin(ang), 0))
            p = Vector((x, y, .01))
            b.cyl(p, p + d * .26, .04, r.choice(["pet", "pet", "glass green"]), 7)
        elif k < .85:
            b.box((x, y, .01), (r.uniform(.15, .4), r.uniform(.1, .3), .05), "foam", Matrix.Rotation(r.uniform(0, 3), 3, "Z"))
        else:
            b.box((x, y, .0), (r.uniform(.2, .5), r.uniform(.2, .4), .01), r.choice(["scum", "cardboard"]), Matrix.Rotation(r.uniform(0, 3), 3, "Z"))
    return b.finish(name)


def build_rubble(name, seed, size=1.6):
    """Broken hollow blocks and concrete with bent rebar."""
    b = Builder(seed)
    r = b.r
    for _ in range(int(size * 14)):
        ang, d = r.uniform(0, math.tau), size * .5 * math.sqrt(r.random())
        x, y = math.cos(ang) * d, math.sin(ang) * d
        z = (1 - d / (size * .5)) * size * .22
        if r.random() < .55:
            b.box((x, y, z + .06), (.4, .15, .2) if r.random() < .5 else (r.uniform(.15, .3), .15, .2), "block",
                  Matrix.Rotation(r.uniform(0, math.tau), 3, "Z") @ Matrix.Rotation(r.uniform(-.5, .5), 3, "X"))
        else:
            b.blob((x, y, z + .05), (r.uniform(.15, .45), r.uniform(.12, .35), r.uniform(.08, .2)), "cement", 1, .3)
    for _ in range(int(size * 3)):
        p = Vector((r.uniform(-size * .4, size * .4), r.uniform(-size * .4, size * .4), size * .1))
        q = p + Vector((r.uniform(-.4, .4), r.uniform(-.4, .4), r.uniform(.3, .9)))
        m = q + Vector((r.uniform(-.3, .3), r.uniform(-.3, .3), r.uniform(-.2, .1)))
        b.cyl(p, q, .006, "rust", 4, False)
        b.cyl(q, m, .006, "rust", 4, False)
    return b.finish(name)


def build_mattress(name, seed):
    b = Builder(seed)
    r = b.r
    # A soaked foam mattress folded over debris.
    segs = 6
    for i in range(segs):
        x0, x1 = -.95 + i * 1.9 / segs, -.95 + (i + 1) * 1.9 / segs
        z0 = .25 * math.sin(i / segs * math.pi) + r.uniform(0, .04)
        z1 = .25 * math.sin((i + 1) / segs * math.pi)
        b.beam((x0, 0, z0 + .07), (x1, 0, z1 + .07), .9, .13, "foam stained")
    return b.finish(name)


def build_cabinet(name, seed):
    """A rotten plywood cabinet lying on its back, door torn off."""
    b = Builder(seed)
    r = b.r
    b.box((0, 0, .02), (1.4, .7, .02), "wood grey")
    for y in (-.34, .34):
        b.box((0, y, .2), (1.4, .02, .38), "wood")
    for x in (-.69, .69, 0):
        b.box((x, 0, .2), (.02, .7, .38), "wood")
    b.box((.9, .5, .01), (.68, .66, .018), "paint 4", Matrix.Rotation(.4, 3, "Z"))
    return b.finish(name)


def main():
    os.makedirs(OUT, exist_ok=True)
    rng = random.Random(1717)
    kit = {"houses": [], "props": []}
    # River row: widths chosen to fill the bank; lane row: smaller, lower huts.
    specs = []
    for i in range(18):
        specs.append({"row": "river", "width": round(rng.choice([3.4, 3.8, 4.2, 4.6, 5.0, 5.6]), 2),
                      "depth": round(rng.uniform(5.2, 6.4), 2), "storeys": rng.choice([2, 2, 3, 3, 3, 4]), "seed": 4000 + i})
    for i in range(14):
        specs.append({"row": "back", "width": round(rng.choice([3.2, 3.6, 4.0, 4.6]), 2),
                      "depth": round(rng.uniform(4.0, 5.2), 2), "storeys": rng.choice([1, 2, 2, 3]), "seed": 5000 + i})
    for i, spec in enumerate(specs):
        clear_scene()
        obj, h = build_house(i, spec)
        filename = "house_%02d.glb" % i
        export([obj], filename)
        kit["houses"].append(dict(spec, file=filename, colliders=h.colliders, doors=h.doors,
                                  triangles=sum(len(p.vertices) - 2 for p in obj.data.polygons)))
        print("house", i, spec["row"], kit["houses"][-1]["triangles"], "tris")
    props = [("heap_large_a", lambda: build_heap("heap_large_a", 1.6, .9, 120, 71)),
             ("heap_large_b", lambda: build_heap("heap_large_b", 1.9, 1.1, 150, 72)),
             ("heap_medium_a", lambda: build_heap("heap_medium_a", 1.0, .55, 55, 73)),
             ("heap_medium_b", lambda: build_heap("heap_medium_b", 1.1, .6, 60, 74)),
             ("heap_small_a", lambda: build_heap("heap_small_a", .55, .3, 22, 75)),
             ("heap_small_b", lambda: build_heap("heap_small_b", .6, .35, 26, 76)),
             ("litter_a", lambda: build_heap("litter_a", 1.4, 0, 40, 77, False)),
             ("litter_b", lambda: build_heap("litter_b", 1.6, 0, 50, 78, False)),
             ("floating_a", lambda: build_floating("floating_a", 3.0, 1.2, 79)),
             ("floating_b", lambda: build_floating("floating_b", 2.0, .9, 80)),
             ("floating_c", lambda: build_floating("floating_c", 4.0, 1.4, 81)),
             ("rubble_a", lambda: build_rubble("rubble_a", 82, 1.6)),
             ("rubble_b", lambda: build_rubble("rubble_b", 83, 2.4)),
             ("mattress", lambda: build_mattress("mattress", 84)),
             ("cabinet", lambda: build_cabinet("cabinet", 85))]
    for name, make in props:
        clear_scene()
        obj = make()
        export([obj], name + ".glb")
        kit["props"].append({"name": name, "file": name + ".glb", "triangles": sum(len(p.vertices) - 2 for p in obj.data.polygons)})
    with open(os.path.join(OUT, "kit.json"), "w") as f:
        json.dump(kit, f, indent=1)
    print("KIT_DONE", len(kit["houses"]), "houses", len(kit["props"]), "props")


main()
