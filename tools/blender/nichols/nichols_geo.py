"""The Nichols house (0.21): a derelict Second Empire mansion south-west of the town, built piece by piece.

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P tools/blender/nichols/build_nichols.py

Writes game/assets/models/nichols/house/*.glb and layout.json:
- house_ext.glb    the outside: clapboard walls, stone plinth, porch, bracketed cornices, slate mansard with dormers,
                   the tower with its bell-cast cap and iron cresting, chimneys, shutters, window hoods.
- house_int.glb    the inside: papered walls with wainscot, mouldings, floors, ceilings (one fallen in), the imperial
                   staircase with its galleries, fireplaces, door casings.
- house_glass.glb  window glass (cast no shadow, so moonlight reaches the floors through it).
- house_cloth.glb  drapes and lace (alpha), dust sheets over the furniture shapes.
- leaf_front.glb / leaf_door.glb   door leaves; Godot hinges them (hinge on the origin, leaf along -X).
- layout.json      collision boxes (Godot space, house-local), door hinges, windows, rooms, light spots.

House space (Blender, Z up): X east, Y from the front facade (Y=0) toward the back (Y=20), Z=0 the ground-floor
boards. The front faces -Y, which glTF exports as Godot +Z (north, toward the town): Godot = (x, z, -y).
Material names are keys nichols_property.gd binds to PBR sets; UVs are world metres (planar per face).
"""
import json
import math
import os
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "game", "assets", "models", "nichols", "house")
R = random.Random(1906)

# ------------------------------------------------------------------------------------------------ dimensions
W = 13.0          # half width (outer wall faces at x = +-13)
D = 20.0          # depth (front outer face y = 0, back outer face y = 20)
T = .3            # exterior wall thickness
P = .16           # partition thickness
C0 = 4.0          # ground ceiling
F1 = 4.4          # upper floor boards
C1 = 8.0          # upper ceiling
TOP = 8.4         # wall plate / main cornice
PLINTH = -1.2     # ground level below the house
TY = -.6          # tower front outer face
TX = 3.0          # tower half width
TB = 5.4          # tower back (above the roof)
TT = 13.6         # tower wall top
MAN0 = 8.75       # mansard foot
MAN1 = 12.0       # mansard curb
INSET = 1.3
LANDING = 2.2
MOON = Vector((-.539, -.770, .342))  # toward the moon, Blender space (Godot (-.539, .342, .770))


def godot(v):
    return [round(v[0], 4), round(v[2], 4), round(-v[1], 4)]


# ------------------------------------------------------------------------------------------------ mesh builder
class Mesh:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.mats = []
        self.uvs = {}

    def mi(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)


MESHES = {k: Mesh(k) for k in ("ext", "int", "glass", "cloth", "void")}
LAYOUT = {"boxes": [], "doors": [], "windows": [], "rooms": [], "lights": [], "spots": {}, "ramps": []}
TRIS = {"faces": 0}


def newell(pts):
    n = Vector((0, 0, 0))
    for i, a in enumerate(pts):
        b = pts[(i + 1) % len(pts)]
        n.x += (a.y - b.y) * (a.z + b.z)
        n.y += (a.z - b.z) * (a.x + b.x)
        n.z += (a.x - b.x) * (a.y + b.y)
    return n


def face(mesh, pts, mat, expect=None, uvs=None, smooth=False):
    """One polygon. `expect` (a direction) fixes the winding so the face looks that way."""
    pts = [Vector(p) for p in pts]
    n = newell(pts)
    if n.length < 1e-9:
        return None
    if expect is not None and n.dot(Vector(expect)) < 0:
        pts.reverse()
        if uvs is not None:
            uvs = list(reversed(uvs))
        n = -n
    m = MESHES[mesh]
    verts = [m.bm.verts.new(p) for p in pts]
    try:
        f = m.bm.faces.new(verts)
    except ValueError:
        return None
    f.material_index = m.mi(mat)
    f.smooth = smooth
    n.normalize()
    if uvs is None:
        t = Vector((-n.y, n.x, 0))
        if t.length < 1e-3:
            t = Vector((1, 0, 0))
        t.normalize()
        b = n.cross(t)
        uvs = [(p.dot(t), p.dot(b)) for p in pts]
    for loop, uv in zip(f.loops, uvs):
        loop[m.uv].uv = uv
    TRIS["faces"] += 1
    return f


def quad_strip(mesh, ring_a, ring_b, mat, closed=False, smooth=True, expect_center=None, outward=True):
    n = len(ring_a)
    rng = range(n if closed else n - 1)
    for i in rng:
        j = (i + 1) % n
        pts = [ring_a[i], ring_a[j], ring_b[j], ring_b[i]]
        exp = None
        if expect_center is not None:
            c = sum((Vector(p) for p in pts), Vector()) / 4
            exp = (c - Vector(expect_center)) * (1 if outward else -1)
        face(mesh, pts, mat, exp, smooth=smooth)


def box(mesh, c, size, mat, rot=None, skip=(), mats=None):
    """Oriented box. skip: subset of 'xX yY zZ' face ids (lower = negative side). mats overrides per face id."""
    c = Vector(c)
    rot = rot or Matrix.Identity(3)
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    ax = [rot @ Vector((1, 0, 0)), rot @ Vector((0, 1, 0)), rot @ Vector((0, 0, 1))]
    h = [hx, hy, hz]
    for k, (i, sgn) in {"x": (0, -1), "X": (0, 1), "y": (1, -1), "Y": (1, 1), "z": (2, -1), "Z": (2, 1)}.items():
        if k in skip:
            continue
        n = ax[i] * sgn
        j, l = [a for a in range(3) if a != i]
        ctr = c + n * h[i]
        pts = [ctr + ax[j] * h[j] * sj + ax[l] * h[l] * sl for sj, sl in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        face(mesh, pts, (mats or {}).get(k, mat), n)


def beam(mesh, a, b, w, h, mat, up=(0, 0, 1)):
    a, b = Vector(a), Vector(b)
    d = b - a
    if d.length < 1e-4:
        return
    z = d.normalized()
    upv = Vector(up)
    if abs(z.dot(upv)) > .95:
        upv = Vector((1, 0, 0))
    x = upv.cross(z).normalized()
    y = z.cross(x)
    box(mesh, (a + b) / 2, (w, h, d.length), mat, Matrix((x, y, z)).transposed())


def cyl(mesh, a, b, r, mat, seg=10, r2=None, caps=True):
    a, b = Vector(a), Vector(b)
    d = b - a
    if d.length < 1e-4:
        return
    z = d.normalized()
    up = Vector((0, 0, 1)) if abs(z.z) < .95 else Vector((1, 0, 0))
    x = up.cross(z).normalized()
    y = z.cross(x)
    r2 = r if r2 is None else r2
    ra = [a + (x * math.cos(t) + y * math.sin(t)) * r for t in (math.tau * i / seg for i in range(seg))]
    rb = [b + (x * math.cos(t) + y * math.sin(t)) * r2 for t in (math.tau * i / seg for i in range(seg))]
    circ = math.tau * max(r, r2)
    for i in range(seg):
        j = (i + 1) % seg
        u0, u1 = circ * i / seg, circ * (i + 1) / seg
        mid = (ra[i] + ra[j] + rb[i] + rb[j]) / 4
        face(mesh, [ra[i], ra[j], rb[j], rb[i]], mat, mid - (a + b) / 2 - z * (mid - a).dot(z) * 0,
             uvs=[(u0, 0), (u1, 0), (u1, d.length), (u0, d.length)], smooth=True)
    if caps:
        face(mesh, ra, mat, -z)
        face(mesh, rb, mat, z)


def lathe(mesh, c, profile, mat, seg=16, rot=None, smooth=True):
    """Surface of revolution about local Z through c; profile = [(radius, height)] bottom to top."""
    c = Vector(c)
    rot = rot or Matrix.Identity(3)
    rings = []
    for r, h in profile:
        rings.append([c + rot @ Vector((math.cos(math.tau * i / seg) * r, math.sin(math.tau * i / seg) * r, h)) for i in range(seg)])
    axis = rot @ Vector((0, 0, 1))
    for k in range(len(rings) - 1):
        for i in range(seg):
            j = (i + 1) % seg
            pts = [rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]]
            mid = sum(pts, Vector()) / 4
            out = mid - c - axis * (mid - c).dot(axis)
            if out.length < 1e-6:
                continue
            face(mesh, pts, mat, out, smooth=smooth)
    if profile[0][0] > 1e-4:
        face(mesh, rings[0], mat, -axis)
    if profile[-1][0] > 1e-4:
        face(mesh, rings[-1], mat, axis)


def run(mesh, a, b, out, profile, mat, caps=True, ext=0.0):
    """A moulding: `profile` [(out, up)] swept straight from a to b along a face whose outward normal is `out`."""
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    a = a - d * ext
    b = b + d * ext
    out = Vector(out).normalized()
    up = Vector((0, 0, 1))
    ra = [a + out * o + up * h for o, h in profile]
    rb = [b + out * o + up * h for o, h in profile]
    # Profiles run counter-clockwise in the (out, up) plane: a segment (do, dh) faces out*dh - up*do.
    for i in range(len(profile) - 1):
        do = profile[i + 1][0] - profile[i][0]
        dh = profile[i + 1][1] - profile[i][1]
        n = out * dh - up * do
        if n.length < 1e-7:
            continue
        face(mesh, [ra[i], rb[i], rb[i + 1], ra[i + 1]], mat, n)
    if caps and len(profile) > 2:
        face(mesh, ra, mat, -d)
        face(mesh, rb, mat, d)


def vrun(mesh, a, b, side, out, profile, mat):
    """A vertical moulding (casing leg) from a to b; profile [(out, sideways)] runs clockwise in the
    (sideways, out) plane; `side` points away from the opening, `out` away from the wall face."""
    a, b = Vector(a), Vector(b)
    side = Vector(side).normalized()
    out = Vector(out).normalized()
    ra = [a + out * o + side * s for o, s in profile]
    rb = [b + out * o + side * s for o, s in profile]
    for i in range(len(profile) - 1):
        do = profile[i + 1][0] - profile[i][0]
        ds = profile[i + 1][1] - profile[i][1]
        n = out * ds - side * do
        if n.length < 1e-7:
            continue
        face(mesh, [ra[i], rb[i], rb[i + 1], ra[i + 1]], mat, n)
    up = (b - a).normalized()
    face(mesh, rb, mat, up)


def collide(c, size, surface="wood", rot=None, label=""):
    """Godot-space collision box (house-local)."""
    rot = rot or Matrix.Identity(3)
    cols = [godot(rot @ Vector((1, 0, 0))), godot(rot @ Vector((0, 1, 0))), godot(rot @ Vector((0, 0, 1)))]
    LAYOUT["boxes"].append({"c": godot(Vector(c)), "s": [round(s, 4) for s in size], "b": cols, "surface": surface, "label": label})


def ramp(a, b, width, surface="wood", label="stair"):
    """Collision slab whose top face runs from a to b (Blender points)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    z = d.normalized()
    x = Vector((0, 0, 1)).cross(z).normalized()
    y = z.cross(x)
    if y.z < 0:
        x, y = -x, -y
    rot = Matrix((x, y, z)).transposed()
    collide((a + b) / 2 - y * .1, (width, .2, d.length), surface, rot, label)


# ------------------------------------------------------------------------------------------------ walls
class Side:
    """One face of a wall. `mat` is a key, or [(s_upto, key), ...] when the face crosses several rooms."""

    def __init__(self, mesh, mat, base=False, rail=None, crown=None, wainscot=False, reveal="plaster"):
        self.mesh, self.mat, self.base, self.rail, self.crown, self.wainscot = mesh, mat, base, rail, crown, wainscot
        self.reveal = reveal

    def ranges(self, s0, s1):
        if isinstance(self.mat, str):
            return [(s0, s1, self.mat)]
        out, cur = [], s0
        for upto, key in self.mat:
            if upto <= cur:
                continue
            end = min(upto, s1)
            if end > cur:
                out.append((cur, end, key))
            cur = end
            if cur >= s1:
                break
        if cur < s1:
            out.append((cur, s1, self.mat[-1][1]))
        return out

    def at(self, s):
        return self.ranges(s, s + 1e-3)[0][2]


BASE = [(0, 0), (.022, 0), (.022, .19), (.03, .2), (.03, .225), (.018, .235), (.012, .245), (0, .245)]
RAIL = [(0, -.05), (.03, -.045), (.042, -.02), (.044, .008), (.03, .028), (.012, .036), (0, .036)]
CROWN = [(0, -.26), (.018, -.25), (.03, -.2), (.06, -.15), (.11, -.09), (.15, -.05), (.17, -.02), (.18, 0), (0, 0)]
CASING = [(0, -.01), (.018, -.01), (.026, .02), (.03, .06), (.024, .1), (.03, .115), (0, .12)]


class Wall:
    def __init__(self, p0, p1, z0, z1, t, side_a, side_b, surface="plaster", label="wall", collide_=True):
        self.p0 = Vector((p0[0], p0[1], 0))
        self.p1 = Vector((p1[0], p1[1], 0))
        self.L = (self.p1 - self.p0).length
        self.d = (self.p1 - self.p0).normalized()
        self.na = Vector((-self.d.y, self.d.x, 0))
        self.z0, self.z1, self.t = z0, z1, t
        self.A, self.B = side_a, side_b
        self.ops = []
        self.surface = surface
        self.label = label
        self.collide = collide_

    def P(self, s, o, z):
        return self.p0 + self.d * s + self.na * o + Vector((0, 0, z))

    def s_of(self, x, y):
        return (Vector((x, y, 0)) - self.p0).dot(self.d)

    def opening(self, at, w, sill, head, arch=False, kind="window", **kw):
        s = self.s_of(*at) if isinstance(at, tuple) else at
        op = dict(s0=s - w / 2, s1=s + w / 2, zb=sill, zt=head, arch=arch, kind=kind)
        op.update(kw)
        self.ops.append(op)
        return op

    def side_faces(self, s0, s1, za, zb, which, shape=None):
        """Wall face (A side o=+t/2 or B side) for a block or an arch spandrel polygon."""
        side = self.A if which == "A" else self.B
        if side is None:
            return
        o = self.t / 2 if which == "A" else -self.t / 2
        n = self.na if which == "A" else -self.na
        if shape is None:
            for a, b, key in side.ranges(s0, s1):
                face(side.mesh, [self.P(a, o, za), self.P(b, o, za), self.P(b, o, zb), self.P(a, o, zb)], key, n)
        else:
            pts = [self.P(s, o, z) for s, z in shape]
            face(side.mesh, pts, side.at(sum(s for s, _ in shape) / len(shape)), n)

    def block(self, s0, s1, za, zb, ends=(False, False), top=False, bottom=False, reveal=None):
        if s1 - s0 < 1e-4 or zb - za < 1e-4:
            return
        self.side_faces(s0, s1, za, zb, "A")
        self.side_faces(s0, s1, za, zb, "B")
        rev_mesh = "int" if (self.B and self.B.mesh == "int") or (self.A and self.A.mesh == "int") else "ext"
        rmat = reveal or (self.B.reveal if self.B else (self.A.reveal if self.A else "plaster"))
        h = self.t / 2
        if ends[0]:
            face(rev_mesh, [self.P(s0, h, za), self.P(s0, -h, za), self.P(s0, -h, zb), self.P(s0, h, zb)], rmat, -self.d)
        if ends[1]:
            face(rev_mesh, [self.P(s1, h, za), self.P(s1, -h, za), self.P(s1, -h, zb), self.P(s1, h, zb)], rmat, self.d)
        if top:
            face(rev_mesh, [self.P(s0, h, zb), self.P(s1, h, zb), self.P(s1, -h, zb), self.P(s0, -h, zb)], rmat, (0, 0, 1))
        if bottom:
            face(rev_mesh, [self.P(s0, h, za), self.P(s1, h, za), self.P(s1, -h, za), self.P(s0, -h, za)], rmat, (0, 0, -1))
        if self.collide:
            self.box_collider(s0, s1, za, zb)

    def box_collider(self, s0, s1, za, zb, surface=None):
        c = self.P((s0 + s1) / 2, 0, (za + zb) / 2)
        rot = Matrix((self.d, self.na, Vector((0, 0, 1)))).transposed()
        collide(c, (s1 - s0, self.t, zb - za), surface or self.surface, rot, self.label)

    def arch_head(self, op, reveal):
        s0, s1, zs = op["s0"], op["s1"], op["zt"]
        r = (s1 - s0) / 2
        sc = (s0 + s1) / 2
        n = 14
        arc = [(sc + r * math.cos(math.pi * i / n), zs + r * math.sin(math.pi * i / n)) for i in range(n + 1)]
        shape = arc + [(s0, self.z1), (s1, self.z1)]
        self.side_faces(0, 0, 0, 0, "A", shape)
        self.side_faces(0, 0, 0, 0, "B", shape)
        h = self.t / 2
        rev_mesh = "int" if (self.B and self.B.mesh == "int") else "ext"
        for i in range(n):
            a, b = arc[i], arc[i + 1]
            pts = [self.P(a[0], h, a[1]), self.P(b[0], h, b[1]), self.P(b[0], -h, b[1]), self.P(a[0], -h, a[1])]
            mid = (Vector((a[0] + b[0], 0, 0)) / 2)
            ctr = self.P(sc, 0, zs)
            m = sum((Vector(p) for p in pts), Vector()) / 4
            face(rev_mesh, pts, reveal, ctr - m)
        if self.collide:
            self.box_collider(s0, s1, zs, self.z1)

    def build(self):
        ops = sorted(self.ops, key=lambda o: o["s0"])
        cur = 0.0
        for op in ops:
            rev = op.get("reveal") or (self.B.reveal if self.B else "plaster")
            self.block(cur, op["s0"], self.z0, self.z1, ends=(cur > 0, True), reveal=rev)
            if op["zb"] > self.z0 + 1e-3:
                self.block(op["s0"], op["s1"], self.z0, op["zb"], top=True, reveal=rev)
            if op["arch"]:
                self.arch_head(op, rev)
            elif op["zt"] < self.z1 - 1e-3:
                self.block(op["s0"], op["s1"], op["zt"], self.z1, bottom=True, reveal=rev)
            if op["kind"] in ("window", "blind") and self.collide:
                self.box_collider(op["s0"], op["s1"], op["zb"], op["zt"] + (op["s1"] - op["s0"]) / 2 * (1 if op["arch"] else 0), "glass")
            cur = op["s1"]
        self.block(cur, self.L, self.z0, self.z1, ends=(len(ops) > 0, False))
        self.trims(ops)
        return self

    def trims(self, ops):
        for which in ("A", "B"):
            side = self.A if which == "A" else self.B
            if side is None or side.mesh != "int":
                continue
            o = self.t / 2 if which == "A" else -self.t / 2
            n = self.na if which == "A" else -self.na
            # Solid spans along the floor (doors and full-height openings break them).
            spans, cur = [], 0.0
            for op in sorted(ops, key=lambda q: q["s0"]):
                if op["zb"] <= self.z0 + .05:
                    spans.append((cur, op["s0"]))
                    cur = op["s1"]
            spans.append((cur, self.L))
            for s0, s1 in spans:
                if s1 - s0 < .02:
                    continue
                a, b = self.P(s0, o, self.z0), self.P(s1, o, self.z0)
                if side.wainscot:
                    wn = self.P(s0, o, 0)
                    box("int", (a + b) / 2 + n * .012 + Vector((0, 0, side.wainscot / 2)), (s1 - s0, .024, side.wainscot), "wainscot",
                        Matrix((self.d, self.na, Vector((0, 0, 1)))).transposed(), skip="z")
                    run("int", a + n * .024 + Vector((0, 0, side.wainscot)), b + n * .024 + Vector((0, 0, side.wainscot)), n, RAIL, "trim")
                if side.base:
                    off = .024 if side.wainscot else 0
                    run("int", a + n * off, b + n * off, n, BASE, "trim")
            # Chair rail continues over windows only where the sill is higher than it.
            if side.rail and not side.wainscot:
                cur = 0.0
                for op in sorted(ops, key=lambda q: q["s0"]) + [dict(s0=self.L, s1=self.L, zb=0)]:
                    if op["zb"] < self.z0 + side.rail + .05:
                        if op["s0"] - cur > .05:
                            run("int", self.P(cur, o, self.z0 + side.rail), self.P(op["s0"], o, self.z0 + side.rail), n, RAIL, "trim")
                        cur = op["s1"]
            if side.crown:
                run("int", self.P(0, o, side.crown), self.P(self.L, o, side.crown), n, CROWN, "trim", caps=False)
            # Casings round every opening on this side.
            for op in ops:
                self.casing(op, which, side)

    def casing(self, op, which, side):
        if op["kind"] in ("open", "blind"):
            return
        o = self.t / 2 if which == "A" else -self.t / 2
        n = self.na if which == "A" else -self.na
        s0, s1, zb, zt = op["s0"], op["s1"], op["zb"], op["zt"]
        mat = "trim"
        # Legs: from the floor (doors) or the sill, to the head.
        top = zt + ((s1 - s0) / 2 if op["arch"] else 0)
        leg_top = zt if op["arch"] else zt + .12
        for s, dirn in ((s0, -self.d), (s1, self.d)):
            a = self.P(s, o, zb if zb > self.z0 + .05 else self.z0)
            b = self.P(s, o, leg_top)
            vrun(side.mesh, a, b, dirn, n, CASING, mat)
        if op["arch"]:
            r = (s1 - s0) / 2
            sc = (s0 + s1) / 2
            ctr = self.P(sc, o, zt)
            prev = None
            for i in range(13):
                ang = math.pi * i / 12
                p_in = self.P(sc + math.cos(ang) * r, o, zt + math.sin(ang) * r)
                p_out = self.P(sc + math.cos(ang) * (r + .12), o, zt + math.sin(ang) * (r + .12))
                if prev:
                    face(side.mesh, [prev[0] + n * .028, p_in + n * .028, p_out + n * .028, prev[1] + n * .028], mat, n)
                    face(side.mesh, [prev[1], p_out, p_out + n * .028, prev[1] + n * .028], mat, (prev[1] + p_out) / 2 - ctr)
                    face(side.mesh, [prev[0], p_in, p_in + n * .028, prev[0] + n * .028], mat, ctr - (prev[0] + p_in) / 2)
                prev = (p_in, p_out)
            # Keystone.
            k = self.P(sc, o, zt + r)
            box(side.mesh, k + n * .04 + Vector((0, 0, .06)), (.16, .08, .24), mat, Matrix((self.d, n, Vector((0, 0, 1)))).transposed())
        else:
            run(side.mesh, self.P(s0 - .12, o, zt), self.P(s1 + .12, o, zt), n, [(0, 0), (.03, 0), (.03, .11), (.05, .13), (.05, .16), (0, .16)], mat)
        if zb > self.z0 + .05 and op["kind"] == "window":
            # Stool (inside) or sill (outside) with an apron.
            run(side.mesh, self.P(s0 - .1, o, zb), self.P(s1 + .1, o, zb), n, [(0, -.04), (.06, -.04), (.06, 0), (0, 0)], mat)
