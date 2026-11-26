"""The Nichols house outside: stone plinth, corner boards and belt course, the bracketed main cornice, the bell-cast slate
mansard with dormers, curb and iron cresting, the tower (belfry storey, cornice, bell-cast cap, oculi, cresting,
finial), brick chimneys, gutters, the front porch (columns, one snapped; balustrade; lattice skirt; steps with urns;
a porch swing hanging from one chain), the entrance fanlight, the boarded back door and the door leaves."""
from nichols_geo import *  # noqa: F401,F403
from nichols_geo import MESHES, LAYOUT, R, godot, face, box, beam, cyl, lathe, run, vrun, collide, ramp, Wall, Side
import nichols_plan as PL

OUTLINE = [(-W, 0), (-TX, 0), (-TX, TY), (TX, TY), (TX, 0), (W, 0), (W, D), (-W, D)]  # clockwise from above? (y down the page)


def segments(points, closed=True):
    """Consecutive (a, b, outward normal) for a footprint polygon in the house plane."""
    out = []
    n = len(points)
    for i in range(n if closed else n - 1):
        a = Vector((*points[i], 0))
        b = Vector((*points[(i + 1) % n], 0))
        d = (b - a).normalized()
        nrm = Vector((d.y, -d.x, 0))
        out.append((a, b, nrm))
    return out


def main_segments():
    segs = segments(OUTLINE)
    # Make every normal point away from the house centre.
    fixed = []
    for a, b, n in segs:
        mid = (a + b) / 2
        probe = mid + n * .01
        inside = -W < probe.x < W and 0 < probe.y < D or (-TX < probe.x < TX and TY < probe.y < 0)
        fixed.append((a, b, -n if inside else n))
    return fixed


# ------------------------------------------------------------------------------------------------ walls dressing
def plinth():
    up = Vector((0, 0, 1))
    for a, b, n in main_segments():
        d = (b - a).normalized()
        L = (b - a).length
        mid = (a + b) / 2 + n * .035
        rot = Matrix((d, n, up)).transposed()
        box("ext", mid + up * ((PLINTH + .05) / 2), (L + .14, .37, .05 - PLINTH), "stone", rot, skip="yz")
        run("ext", a + n * .07 + up * .05, b + n * .07 + up * .05, n, [(0, 0), (.05, 0), (.05, .04), (.02, .1), (0, .12)], "trim ext", ext=.07)
        # Crawl-space vents.
        s = 1.6
        while s < L - 1.0:
            box("ext", a + d * s + n * .075 + up * (PLINTH + .55), (.42, .02, .2), "void", rot)
            for k in range(5):
                box("ext", a + d * (s - .16 + k * .08) + n * .085 + up * (PLINTH + .55), (.015, .02, .2), "iron", rot)
            s += R.uniform(2.6, 3.6)


def corner_boards():
    up = Vector((0, 0, 1))
    for x, y, top in ((-W, 0, TOP), (W, 0, TOP), (-W, D, TOP), (W, D, TOP), (-TX, TY, TT), (TX, TY, TT), (-TX, 0, TOP), (TX, 0, TOP)):
        box("ext", (x + (.04 if x < 0 else -.04) * 0, y, top / 2 + .06), (.26, .26, top - .12), "trim ext", skip="zZ")
    for a, b, n in main_segments():
        if a.y < 0 or b.y < 0:
            continue
        run("ext", a + n * .0 + up * C0, b + up * C0, n, [(0, 0), (.045, 0), (.045, .38), (.08, .4), (.08, .44), (0, .46)], "trim ext", ext=.1)


def bracket(p, d, n, depth=.5, h=.46, w=.11, mat="trim ext"):
    """A scroll console under a cornice: profile in (out, up) extruded across its width."""
    prof = [(0, -h), (0, 0), (depth, 0), (depth, -.06), (depth - .06, -.1), (depth * .7, -.14), (depth * .45, -.22), (depth * .25, -.32),
            (.12, -.4), (.06, -h + .02)]
    p = Vector(p)
    up = Vector((0, 0, 1))
    a = [p - d * w / 2 + n * o + up * z for o, z in prof]
    b = [p + d * w / 2 + n * o + up * z for o, z in prof]
    face("ext", a, mat, -d)
    face("ext", b, mat, d)
    for i in range(len(prof)):
        j = (i + 1) % len(prof)
        do, dz = prof[j][0] - prof[i][0], prof[j][1] - prof[i][1]
        face("ext", [a[i], b[i], b[j], a[j]], mat, up * do - n * dz if (do or dz) else n)


def cornice(segs, z, depth=.55, spacing=.9):
    up = Vector((0, 0, 1))
    for a, b, n in segs:
        d = (b - a).normalized()
        L = (b - a).length
        rot = Matrix((d, n, up)).transposed()
        box("ext", (a + b) / 2 + n * .02 + up * (z - .24), (L + .04, .04, .48), "trim ext", rot, skip="zZ")
        box("ext", (a + b) / 2 + n * depth / 2 + up * (z + .09), (L + depth * 2, depth, .18), "trim ext", rot)
        run("ext", a + n * depth + up * (z + .18), b + n * depth + up * (z + .18), n,
            [(0, 0), (.06, 0), (.08, .04), (.12, .09), (.14, .15), (0, .15)], "trim ext", ext=depth + .14)
        s = .45
        while s < L - .2:
            bracket(a + d * s + up * z, d, n, depth - .05)
            s += spacing
        # Gutter along the cornice top and its brackets.
        cyl("ext", a + n * (depth + .1) + up * (z + .3) - d * .3, b + n * (depth + .1) + up * (z + .3) + d * .3, .07, "iron", seg=8)


def downpipes():
    up = Vector((0, 0, 1))
    for x, y, nx, ny, loose in ((-W, .3, -1, 0, False), (W, .3, 1, 0, True), (-W, D - .3, -1, 0, False), (W, D - .3, 1, 0, False)):
        base = Vector((x + nx * .7, y + ny * .7, 0))
        top = base + up * (TOP + .3)
        pts = [top, top - up * .25 - Vector((nx, ny, 0)) * .55]
        if loose:
            # Torn away from its straps: it leans off the wall and stops short of the ground.
            cyl("ext", top, top + Vector((nx * .5, 0, -2.5)), .05, "iron", seg=8)
            cyl("ext", top + Vector((nx * .5, 0, -2.5)), top + Vector((nx * 1.6, -.4, -7.4)), .05, "iron", seg=8)
            continue
        cyl("ext", pts[1], Vector((pts[1].x, pts[1].y, PLINTH + .3)), .05, "iron", seg=8)
        cyl("ext", Vector((pts[1].x, pts[1].y, PLINTH + .3)), Vector((pts[1].x + nx * .3, pts[1].y, PLINTH + .05)), .05, "iron", seg=8)
        z = 1.0
        while z < TOP:
            box("ext", Vector((pts[1].x - nx * .06, pts[1].y, z)), (.14, .03, .03), "iron")
            z += 2.0


# ------------------------------------------------------------------------------------------------ mansard
BELL = [(MAN0, 0.0), (9.2, .38), (10.6, .95), (MAN1, INSET)]  # (z, inset) concave bell-cast profile


def inset_at(z):
    for (z0, i0), (z1, i1) in zip(BELL, BELL[1:]):
        if z <= z1:
            return i0 + (i1 - i0) * (z - z0) / (z1 - z0)
    return INSET


def ring(x0, y0, x1, y1, i, z):
    return [Vector((x0 + i, y0 + i, z)), Vector((x1 - i, y0 + i, z)), Vector((x1 - i, y1 - i, z)), Vector((x0 + i, y1 - i, z))]


def mansard():
    x0, y0, x1, y1 = -W + .02, .02, W - .02, D - .02
    rings = [ring(x0, y0, x1, y1, i, z) for z, i in BELL]
    centre = Vector((0, D / 2, 9.0))
    for k in range(len(rings) - 1):
        for e in range(4):
            a, b = rings[k][e], rings[k][(e + 1) % 4]
            c, d = rings[k + 1][(e + 1) % 4], rings[k + 1][e]
            n = newell([a, b, c, d])
            mid = (a + b + c + d) / 4
            face("ext", [a, b, c, d], "slate", mid - Vector((0, D / 2, mid.z)))
    # Curb moulding and the shallow tin deck.
    top = rings[-1]
    for e in range(4):
        a, b = top[e], top[(e + 1) % 4]
        d = (b - a).normalized()
        n = Vector((d.y, -d.x, 0))
        if n.dot((a + b) / 2 - Vector((0, D / 2, (a + b).z / 2))) < 0:
            n = -n
        run("ext", a + up_v(-.02), b + up_v(-.02), n, [(0, -.1), (.08, -.08), (.12, -.02), (.12, .06), (0, .08)], "trim ext", ext=.12)
    ridge = MAN1 + .7
    tx0, ty0, tx1, ty1 = top[0].x, top[0].y, top[2].x, top[2].y
    half = (ty1 - ty0) / 2
    rx0, rx1 = tx0 + half, tx1 - half
    ym = (ty0 + ty1) / 2
    for pts, n in (([top[0], top[1], Vector((rx1, ym, ridge)), Vector((rx0, ym, ridge))], (0, -1, 1)),
                   ([top[2], top[3], Vector((rx0, ym, ridge)), Vector((rx1, ym, ridge))], (0, 1, 1)),
                   ([top[3], top[0], Vector((rx0, ym, ridge))], (-1, 0, 1)), ([top[1], top[2], Vector((rx1, ym, ridge))], (1, 0, 1))):
        face("ext", pts, "roof metal", n)
    cresting([(top[e], top[(e + 1) % 4]) for e in range(4)], MAN1 + .08, .55)
    # Missing slates: a torn patch on the east front slope shows battens over darkness.
    patch(Vector((8.6, 0, 9.9)), 2.2, 1.3)
    patch(Vector((-9.0, D, 10.3)), 1.4, .9, back=True)


def up_v(z):
    return Vector((0, 0, z))


def newell(pts):
    import nichols_geo
    return nichols_geo.newell([Vector(p) for p in pts])


def patch(c, w, h, back=False):
    """A hole in the slates on the front (or back) slope at height c.z, x = c.x."""
    z0, z1 = c.z - h / 2, c.z + h / 2
    sy = 1 if back else -1
    yb = (D if back else 0) - sy * 0

    def on_slope(x, z, lift):
        i = inset_at(z)
        y = (D - .02 - i) if back else (.02 + i)
        k = (inset_at(z + .05) - inset_at(z - .05)) / .1
        n = Vector((0, sy, k)).normalized()
        return Vector((x, y, z)) + n * lift

    pts = [on_slope(c.x - w / 2, z0, .012), on_slope(c.x + w / 2, z0, .012), on_slope(c.x + w / 2 * .7, z1, .012), on_slope(c.x - w / 2 * .85, z1, .012)]
    face("ext", pts, "void", Vector((0, sy, .3)))
    z = z0 + .08
    while z < z1 - .05:
        f = (z - z0) / h
        xa = c.x - w / 2 * (1 - .15 * f)
        xb = c.x + w / 2 * (1 - .3 * f)
        beam("ext", on_slope(xa, z, .03), on_slope(xb, z, .03), .045, .02, "joist", up=(0, sy, .3))
        z += .17
    # Loose slates around the hole edge.
    for i in range(9):
        x = c.x + R.uniform(-w / 2, w / 2)
        z = z1 + R.uniform(-.1, .15)
        p = on_slope(x, z, .03)
        box("ext", p, (.22, .006, .3), "slate", Matrix.Rotation(R.uniform(-.5, .5), 3, Vector((0, sy, .4)).normalized()) @ Matrix.Rotation(math.radians(70) * -sy, 3, "X"))


def cresting(edges, z, h):
    """Wrought-iron cresting: rails with spear-point pickets and scroll rings."""
    for a, b in edges:
        a = Vector((a.x, a.y, z))
        b = Vector((b.x, b.y, z))
        L = (b - a).length
        d = (b - a).normalized()
        cyl("ext", a, b, .012, "iron", seg=5, caps=False)
        cyl("ext", a + up_v(h * .6), b + up_v(h * .6), .01, "iron", seg=5, caps=False)
        n = int(L / .24)
        for k in range(n + 1):
            p = a + d * (L * k / max(n, 1))
            if R.random() < .07:
                continue
            tall = h * (1.0 if k % 3 == 0 else .75)
            cyl("ext", p, p + up_v(tall), .008, "iron", seg=4, caps=False)
            lathe("ext", p + up_v(tall), [(.022, 0), (.0, .07)], "iron", seg=4)
            if k % 3 == 1:
                ringc = p + d * .12 + up_v(h * .32)
                for i in range(8):
                    a0, a1 = math.tau * i / 8, math.tau * (i + 1) / 8
                    cyl("ext", ringc + d * math.cos(a0) * .08 + up_v(math.sin(a0) * .08), ringc + d * math.cos(a1) * .08 + up_v(math.sin(a1) * .08), .006, "iron", seg=3, caps=False)


def dormers():
    sides = [  # (fixed axis, value, along positions, outward normal)
        ("y", 0.02, [-10.5, -6.5, 6.5, 10.5], Vector((0, -1, 0))),
        ("y", D - .02, [-10.5, -6.5, 0, 6.5, 10.5], Vector((0, 1, 0))),
        ("x", -W + .02, [2.9, 8.6, 12.2, 15.6, 18.2], Vector((-1, 0, 0))),
        ("x", W - .02, [2.9, 8.6, 12.2, 15.6, 18.2], Vector((1, 0, 0))),
    ]
    for axis, value, places, out in sides:
        for k, s in enumerate(places):
            if axis == "x" and value < 0 and 4.2 < s < 6.8:
                continue
            dormer(axis, value, s, out, k)


def dormer(axis, value, s, out, k):
    up = Vector((0, 0, 1))
    along = Vector((1, 0, 0)) if axis == "y" else Vector((0, 1, 0))
    if along.cross(up).dot(out) > 0:
        along = -along  # keep wall side A outward
    q = .28
    zb = MAN0 + .02
    while inset_at(zb) < q:
        zb += .02
    zt = 11.15
    w = 1.5
    base = Vector((s, value, 0)) if axis == "y" else Vector((value, s, 0))
    fpt = base - out * q
    # Front: a small wall with an arched window opening.
    p0 = fpt - along * w / 2
    p1 = fpt + along * w / 2
    wall = Wall((p0.x, p0.y), (p1.x, p1.y), zb, zt, .12, Side("ext", "trim ext"), None, "plaster", "Dormer", collide_=False)
    if wall.na.dot(out) < 0:
        wall = Wall((p1.x, p1.y), (p0.x, p0.y), zb, zt, .12, Side("ext", "trim ext"), None, "plaster", "Dormer", collide_=False)
    op = wall.opening(w / 2, .78, zb + .32, zb + 1.25, True, "window", reveal="trim ext")
    wall.build()
    box("void", fpt - out * .3 + up * (zb + 1.0), (.95 if axis == "y" else .5, .95 if axis == "x" else .5, 1.9), "void")
    state = {"broken": .5 if k % 2 else .2}
    PL.sash_window(wall, op, state)
    if k % 3 == 2:
        PL.boards_over(wall, op)
    # Cheeks follow the slope back from the front face.
    top_i = inset_at(zt)
    for sd in (-1, 1):
        e = fpt + along * sd * w / 2
        prof = [e + up * zb]
        for z, i in BELL:
            if zb < z < zt:
                prof.append(e - out * (i - q) + up * z)
        prof.append(e - out * (top_i - q) + up * zt)
        prof.append(e + up * zt)
        face("ext", prof, "slate", along * sd)
    # Segmental roof over the front, running back into the slope.
    n = 8
    arc = []
    for i in range(n + 1):
        t = i / n
        arc.append(along * (-(w / 2 + .12) + (w + .24) * t) + up * (zt + .32 * math.sin(math.pi * t)))
    back = top_i - q + .25
    for i in range(n):
        a, b = arc[i], arc[i + 1]
        pts = [fpt + out * .14 + a, fpt + out * .14 + b, fpt - out * back + b, fpt - out * back + a]
        face("ext", pts, "slate", up + along * (-(b - a).dot(up) * 3 * (1 if i < n / 2 else -1)) * 0 + up)
    face("ext", [fpt + out * .14 + p for p in arc], "trim ext", out)
    for i in range(n):
        beam("ext", fpt + out * .17 + arc[i], fpt + out * .17 + arc[i + 1], .1, .08, "trim ext", up=out)
    # Pilasters either side of the window.
    for sd in (-1, 1):
        box("ext", fpt + out * .02 + along * sd * (w / 2 - .1) + up * ((zb + zt) / 2), (.16 if axis == "y" else .06, .06 if axis == "y" else .16, zt - zb), "trim ext")


# ------------------------------------------------------------------------------------------------ tower
def tower():
    up = Vector((0, 0, 1))
    tw = Wall  # noqa
    specs = [((TX, TY + T / 2), (-TX, TY + T / 2), [(-.75, TY), (.75, TY)]),
             ((-TX + T / 2, TY), (-TX + T / 2, TB), [(-TX, 1.6), (-TX, 3.3)]),
             ((TX - T / 2, TB), (TX - T / 2, TY), [(TX, 3.3), (TX, 1.6)]),
             ((-TX, TB - T / 2), (TX, TB - T / 2), [])]
    for p0, p1, wins in specs:
        wl = Wall(p0, p1, TOP, TT, T, Side("ext", "siding"), Side("int", "plaster dark"), "plaster", "Tower", collide_=False)
        for at in wins:
            op = wl.opening(at, .82, 9.7, 11.6, True, "window")
            PL.WINDOWS.append((wl, op, {"broken": .4, "shutter": "none"}))
        wl.build()
    for wl, op, st in PL.WINDOWS[-6:]:
        box("void", wl.P((op["s0"] + op["s1"]) / 2, -.35, 10.7), (.9, .05, 2.4), "void", Matrix((wl.d, wl.na, up)).transposed())
        PL.sash_window(wl, op, st)
        PL.window_dressing(wl, op, st)
    # Belt at the main cornice line and the tower's own bracketed cornice.
    tsegs = [(Vector((-TX, TB, 0)), Vector((-TX, TY, 0)), Vector((-1, 0, 0))), (Vector((-TX, TY, 0)), Vector((TX, TY, 0)), Vector((0, -1, 0))),
             (Vector((TX, TY, 0)), Vector((TX, TB, 0)), Vector((1, 0, 0)))]
    for a, b, n in tsegs:
        run("ext", a + up * TOP, b + up * TOP, n, [(0, -.3), (.06, -.3), (.06, 0), (.18, .04), (.18, .14), (0, .16)], "trim ext", ext=.18)
    cornice(tsegs + [(Vector((TX, TB, 0)), Vector((-TX, TB, 0)), Vector((0, 1, 0)))], TT, depth=.45, spacing=.75)
    for x, y in ((-TX, TY), (TX, TY), (-TX, TB), (TX, TB)):
        box("ext", (x, y, (TOP + TT) / 2), (.26, .26, TT - TOP), "trim ext", skip="zZ")
    # Bell-cast cap.
    z0 = TT + .3
    prof = [(z0, -.05), (z0 + .35, .3), (z0 + 1.4, .62), (z0 + 2.8, .9), (z0 + 3.7, 1.05)]
    rings = [ring(-TX, TY, TX, TB, i, z) for z, i in prof]
    c = Vector((0, (TY + TB) / 2, 0))
    for k in range(len(rings) - 1):
        for e in range(4):
            a, b = rings[k][e], rings[k][(e + 1) % 4]
            cc, d = rings[k + 1][(e + 1) % 4], rings[k + 1][e]
            mid = (a + b + cc + d) / 4
            face("ext", [a, b, cc, d], "slate", mid - Vector((c.x, c.y, mid.z)))
    top = rings[-1]
    face("ext", top, "roof metal", (0, 0, 1))
    for e in range(4):
        a, b = top[e], top[(e + 1) % 4]
        d = (b - a).normalized()
        n = Vector((d.y, -d.x, 0))
        if n.dot((a + b) / 2 - Vector((c.x, c.y, a.z))) < 0:
            n = -n
        run("ext", a, b, n, [(0, -.12), (.1, -.1), (.14, -.03), (.14, .05), (0, .07)], "trim ext", ext=.14)
    cresting([(top[e], top[(e + 1) % 4]) for e in range(4)], top[0].z + .07, .7)
    # Finial: a turned iron spire.
    lathe("ext", (0, (TY + TB) / 2, top[0].z), [(.14, 0), (.12, .1), (.06, .18), (.09, .3), (.05, .42), (.03, .7), (.06, .78), (.02, .9), (.012, 1.6), (0, 1.75)], "iron", seg=10)
    # Oculus dormers on three faces of the cap.
    zc = z0 + 1.5
    for p, n in ((Vector((0, TY - .02, 0)), Vector((0, -1, 0))), (Vector((-TX - .02, (TY + TB) / 2, 0)), Vector((-1, 0, 0))), (Vector((TX + .02, (TY + TB) / 2, 0)), Vector((1, 0, 0)))):
        q = p - n * (inset_cap(zc, prof) - .1) + up * zc
        ax = up.cross(n).normalized()
        rot = Matrix((ax, n.cross(ax), n)).transposed()
        lathe("ext", q, [(.42, 0), (.42, .12), (.3, .14), (.3, .0)], "trim ext", seg=20, rot=rot)
        box("ext", q - n * .04, (.6 if abs(n.y) > .5 else .02, .02 if abs(n.y) > .5 else .6, .6), "void")
    LAYOUT["spots"]["tower_top"] = godot(Vector((0, (TY + TB) / 2, top[0].z + 1.75)))


def inset_cap(z, prof):
    for (z0, i0), (z1, i1) in zip(prof, prof[1:]):
        if z <= z1:
            return i0 + (i1 - i0) * (z - z0) / (z1 - z0)
    return prof[-1][1]


# ------------------------------------------------------------------------------------------------ chimneys
def chimney(x0, y0, x1, y1, z_top):
    c = Vector(((x0 + x1) / 2, (y0 + y1) / 2, 0))
    box("ext", (c.x, c.y, (TOP + z_top) / 2), (x1 - x0, y1 - y0, z_top - TOP), "brick")
    for z, g in ((z_top - .55, .08), (z_top - .4, .14), (z_top - .25, .18)):
        box("ext", (c.x, c.y, z), (x1 - x0 + g * 2, y1 - y0 + g * 2, .15), "brick")
    box("ext", (c.x, c.y, z_top - .12), (x1 - x0 + .3, y1 - y0 + .3, .1), "stone")
    for k in (-1, 1):
        p = (c.x + k * (x1 - x0) * .22, c.y, z_top - .07)
        lathe("ext", p, [(.13, 0), (.13, .08), (.1, .12), (.11, .45), (.15, .52), (.13, .58), (.1, .58), (.1, .3)], "clay", seg=10)


# ------------------------------------------------------------------------------------------------ porch
COLS = [-12.75, -9.6, -6.45, -3.55, 3.55, 6.45, 9.6, 12.75]
PY = -3.4          # porch front edge
PZ = -.06          # porch boards
PROOF = 3.55       # porch beam soffit at the front


def porch():
    up = Vector((0, 0, 1))
    # Boards, with a few gaps that show darkness underneath.
    x = -W
    while x < W - .01:
        bw = min(.14, W - x)
        if not (R.random() < .025 and abs(x) > 3):
            for y0, y1 in ((PY, TY if abs(x + bw / 2) < TX else 0),):
                box("ext", (x + bw / 2, (y0 + y1) / 2, PZ - .02), (bw - .006, y1 - y0, .04), "porch floor", skip="z")
        x += .14
    face("ext", [(-W, PY, PZ - .045), (W, PY, PZ - .045), (W, 0, PZ - .045), (-W, 0, PZ - .045)], "void", (0, 0, 1))
    box("ext", (0, PY - .02, PZ - .12), (2 * W + .1, .05, .2), "trim ext")
    collide((0, PY / 2, PZ - .2), (2 * W, -PY, .4), "wood", label="Porch floor")
    # Lattice skirt and piers.
    for x in COLS:
        box("ext", (x, PY + .2, (PLINTH + PZ) / 2), (.42, .42, PZ - PLINTH - .1), "stone")
    xs = [-W] + COLS + [W]
    for a, b in zip(xs, xs[1:]):
        if b - a > .6:
            lattice(Vector((a + .22, PY + .18, 0)), Vector((b - .22, PY + .18, 0)), PLINTH + .05, PZ - .14, broken=R.random() < .25)
    for sx in (-1, 1):
        lattice(Vector((sx * (W - .05), PY + .4, 0)), Vector((sx * (W - .05), -.2, 0)), PLINTH + .05, PZ - .14)
    # Columns (one snapped, its top lying across the boards).
    for k, x in enumerate(COLS):
        p = Vector((x, PY + .25, PZ))
        box("ext", p + up * .12, (.36, .36, .24), "trim ext")
        if k == 5:
            lathe("ext", p + up * .24, [(.15, 0), (.15, .05), (.13, .1), (.12, .14), (.115, 1.1), (.0, 1.25)], "trim ext", seg=14)
            # The broken shaft on the boards and a splintered stub.
            q = Matrix.Rotation(math.radians(84), 3, Vector((.3, 1, 0)).normalized())
            lathe("ext", p + Vector((.55, -.35, .13)), [(.11, 0), (.1, 1.6), (.13, 1.7), (.16, 1.78), (.18, 1.86), (0, 1.86)], "trim ext", seg=14, rot=q)
            continue
        lathe("ext", p + up * .24, [(.17, 0), (.17, .05), (.14, .08), (.13, .14), (.12, 1.4), (.105, 2.7), (.13, 2.8), (.15, 2.88), (.15, 2.92), (0, 2.92)],
              "trim ext", seg=16)
        box("ext", p + up * (PROOF - .4), (.34, .34, .06), "trim ext")
        collide(p + up * 1.6, (.3, .3, 3.2), "wood", label="Porch column")
    # Beam, frieze and brackets.
    rot = Matrix.Identity(3)
    box("ext", (0, PY + .25, PROOF - .2), (2 * W + .3, .3, .36), "trim ext")
    run("ext", (-W - .15, PY + .1, PROOF - .02), (W + .15, PY + .1, PROOF - .02), (0, -1, 0), [(0, 0), (.06, 0), (.08, .04), (.1, .1), (0, .12)], "trim ext", ext=.1)
    for k, x in enumerate(COLS):
        if k == 5:
            continue
        for sx in (-1, 1):
            if abs(x + sx * .3) > W:
                continue
            bracket(Vector((x + sx * .17, PY + .25, PROOF - .38)), Vector((0, 1, 0)), Vector((sx, 0, 0)), .45, .4, .08)
    # Roof: tin above, beadboard (haint blue) below.
    a, b = Vector((-W - .2, PY - .1, PROOF + .02)), Vector((W + .2, PY - .1, PROOF + .02))
    c, d = Vector((W + .2, 0, C0 - .1)), Vector((-W - .2, 0, C0 - .1))
    face("ext", [a, b, c + up * .12, d + up * .12], "roof metal", (0, -.3, 1))
    face("ext", [a - up * .01, b - up * .01, c - up * .01, d - up * .01], "porch ceiling", (0, .2, -1))
    for sx in (-1, 1):
        face("ext", [Vector((sx * (W + .2), PY - .1, PROOF - .01)), Vector((sx * (W + .2), 0, C0 - .11)), Vector((sx * (W + .2), 0, C0 + .02)),
                     Vector((sx * (W + .2), PY - .1, PROOF + .12))], "trim ext", (sx, 0, 0))
    run("ext", Vector((-W, 0, C0 - .12)), Vector((W, 0, C0 - .12)), (0, -1, 0), [(0, -.08), (.06, -.06), (.06, 0), (0, 0)], "trim ext")
    # Balustrade (outside): between the columns except at the steps; one bay smashed.
    for a_, b_ in zip(COLS, COLS[1:]):
        if a_ < 0 < b_:
            for x0, x1 in ((a_, -2.25), (2.25, b_)):
                porch_rail(Vector((x0 + .18, PY + .25, PZ)), Vector((x1 - (.18 if x1 == b_ else 0), PY + .25, PZ)), broken=False)
            continue
        porch_rail(Vector((a_ + .18, PY + .25, PZ)), Vector((b_ - .18, PY + .25, PZ)), broken=(a_ == 6.45))
    for sx in (-1, 1):
        porch_rail(Vector((sx * 12.75, PY + .45, PZ)), Vector((sx * 12.75, -.25, PZ)))
    # Steps with stone cheek walls and urns.
    n = 6
    rise = (PZ - PLINTH) / n
    tread = .33
    for i in range(n):
        y = PY - i * tread
        z = PZ - i * rise
        box("ext", (0, y - tread / 2, z - rise / 2), (4.4, tread + .03, rise), "step", skip="z")
    for sx in (-1, 1):
        x = sx * 2.42
        prof = [Vector((x, PY + .2, PLINTH)), Vector((x, PY - n * tread - .2, PLINTH)), Vector((x, PY - n * tread - .2, PLINTH + .55)), Vector((x, PY + .2, PZ + .55))]
        for off in (-.17, .17):
            face("ext", [p + Vector((off, 0, 0)) for p in prof], "stone", (1 if off > 0 else -1, 0, 0))
        face("ext", [prof[2] + Vector((-.17, 0, 0)), prof[2] + Vector((.17, 0, 0)), prof[3] + Vector((.17, 0, 0)), prof[3] + Vector((-.17, 0, 0))], "stone", (0, -.3, 1))
        face("ext", [prof[1] + Vector((-.17, 0, 0)), prof[1] + Vector((.17, 0, 0)), prof[2] + Vector((.17, 0, 0)), prof[2] + Vector((-.17, 0, 0))], "stone", (0, -1, 0))
        ped = Vector((x, PY - n * tread, PLINTH + .55))
        box("ext", ped + up * .35, (.5, .5, .7), "stone")
        urn = [(.12, 0), (.16, .05), (.1, .12), (.12, .18), (.26, .32), (.3, .44), (.27, .52), (.3, .56), (.24, .58), (.0, .58)]
        if sx < 0:
            lathe("ext", ped + up * .7, urn, "stone", seg=16)
        else:
            # Knocked off its pedestal: lying in the weeds.
            lathe("ext", ped + Vector((.75, -.5, -.25)), urn, "stone", seg=16, rot=Matrix.Rotation(math.radians(100), 3, Vector((.4, 1, 0)).normalized()))
        collide((x, PY - n * tread / 2, PLINTH + .7), (.38, n * tread + .4, 1.4), "stone", label="Step cheek")
    # The ramp ends flush with (a hair above) the boards: a lip at the top of a slope reads as a wall.
    ramp(Vector((0, PY - n * tread - .1, PLINTH)), Vector((0, PY + .02, PZ + .012)), 4.4, "wood", "Porch steps")
    LAYOUT["spots"]["porch_steps"] = godot(Vector((0, PY - n * tread - 1.0, PLINTH)))
    porch_swing()


def porch_rail(a, b, broken=False):
    up = Vector((0, 0, 1))
    d = (b - a)
    L = d.length
    n = int(L / .14)
    for i in range(1, n):
        p = a + d * (i / n)
        if broken and R.random() < .55:
            continue
        if R.random() < .04:
            continue
        lathe("ext", p + up * .1, [(.03, 0), (.03, .05), (.022, .09), (.035, .22), (.04, .32), (.026, .48), (.018, .62), (.026, .7), (.026, .76)], "trim ext", seg=6)
    beam("ext", a + up * .06, b + up * .06, .1, .08, "trim ext")
    if broken:
        mid = a + d * .45
        beam("ext", a + up * .9, mid + up * .86 + Vector((0, -.05, 0)), .1, .07, "trim ext")
        beam("ext", b + up * .9, b + d.normalized() * -.8 + up * .25 + Vector((0, -.15, 0)), .1, .07, "trim ext")
    else:
        beam("ext", a + up * .9, b + up * .9, .12, .07, "trim ext")
        collide((a + b) / 2 + up * .5, (abs(d.x) + .1, abs(d.y) + .1, 1.0), "wood", label="Porch rail")


def lattice(a, b, z0, z1, broken=False):
    """Diagonal lattice slats between a and b (vertical plane), z0..z1."""
    d = (b - a)
    L = d.length
    dn = d.normalized()
    n = Vector((dn.y, -dn.x, 0))
    sp = .16
    for sign in (1, -1):
        k = -int((z1 - z0) / sp) - 1
        while k * sp < L + (z1 - z0):
            s0 = k * sp
            # Line s = s0 + sign*(z - z0) clipped to [0, L] x [z0, z1].
            pts = []
            for z in (z0, z1):
                s = s0 + (z - z0) if sign > 0 else s0 + (z1 - z)
                pts.append((s, z))
            (sa, za), (sb, zb) = pts
            if sb != sa:
                def clip(s1, z1_, s2, z2_):
                    if s1 < 0:
                        t = (0 - s1) / (s2 - s1)
                        return 0, z1_ + (z2_ - z1_) * t
                    if s1 > L:
                        t = (L - s1) / (s2 - s1)
                        return L, z1_ + (z2_ - z1_) * t
                    return s1, z1_
                if not ((sa < 0 and sb < 0) or (sa > L and sb > L)):
                    sa2, za2 = clip(sa, za, sb, zb)
                    sb2, zb2 = clip(sb, zb, sa, za)
                    if not (broken and .3 < (sa2 + sb2) / 2 / L < .55 and (za2 + zb2) / 2 < (z0 + z1) / 2 + .2):
                        beam("ext", a + dn * sa2 + Vector((0, 0, za2)) + n * (.01 * sign), a + dn * sb2 + Vector((0, 0, zb2)) + n * (.01 * sign), .045, .012, "lattice", up=n)
            k += 1
    box("ext", (a + b) / 2 - n * .1 + Vector((0, 0, (z0 + z1) / 2)), (abs(d.x) + .02, abs(d.y) + .02, z1 - z0), "void")


def porch_swing():
    up = Vector((0, 0, 1))
    c = Vector((-8.2, -1.6, PZ + .55))
    rot = Matrix.Rotation(math.radians(-14), 3, Vector((1, 0, 0))) @ Matrix.Rotation(math.radians(9), 3, Vector((0, 1, 0)))
    for i in range(6):
        box("ext", c + rot @ Vector((0, -.2 + i * .08, 0)), (1.6, .07, .03), "porch floor", rot)
    for i in range(5):
        box("ext", c + rot @ Vector((0, .25, .1 + i * .1)), (1.6, .03, .07), "porch floor", rot)
    for sx in (-1, 1):
        box("ext", c + rot @ Vector((sx * .78, .05, .15)), (.05, .5, .3), "porch floor", rot)
    hook_l = Vector((c.x - .78, c.y, C0 - .3))
    hook_r = Vector((c.x + .78, c.y, C0 - .3))
    chain(hook_r, c + rot @ Vector((.78, .05, .3)))
    chain(hook_l, hook_l - up * 1.1 + Vector((.05, .1, 0)))  # snapped chain


def chain(a, b):
    a, b = Vector(a), Vector(b)
    L = (b - a).length
    n = int(L / .06)
    for i in range(n):
        p = a + (b - a) * (i + .5) / n
        box("ext", p, (.012 if i % 2 else .03, .03 if i % 2 else .012, .055), "iron")


# ------------------------------------------------------------------------------------------------ entrance and back door
def entrance():
    """Threshold, transom bar and the fixed fanlight in the entrance arch (the leaves are separate)."""
    w = 1.9
    zs = 2.85
    y = TY + T / 2
    box("ext", (0, y, zs + .04), (w, .2, .08), "door wood")
    r = w / 2
    n = 14
    for k in range(n):
        a0, a1 = math.pi * k / n, math.pi * (k + 1) / n
        beam("ext", (math.cos(a0) * (r - .05), y, zs + .08 + math.sin(a0) * (r - .05)), (math.cos(a1) * (r - .05), y, zs + .08 + math.sin(a1) * (r - .05)), .1, .14, "door wood", up=(0, -1, 0))
    fan = [Vector((math.cos(math.pi * k / n) * (r - .1), y, zs + .08 + math.sin(math.pi * k / n) * (r - .1))) for k in range(n + 1)]
    face("glass", fan, "glass", (0, -1, 0))
    face("glass", fan, "glass", (0, 1, 0))
    for k in range(1, 6):
        a = math.pi * k / 6
        beam("ext", (0, y - .02, zs + .08), (math.cos(a) * (r - .08), y - .02, zs + .08 + math.sin(a) * (r - .08)), .025, .03, "iron", up=(0, -1, 0))
    lathe("ext", (0, y - .03, zs + .08), [(.25, 0), (.25, .02), (0, .02)], "iron", seg=12, rot=Matrix.Rotation(math.pi / 2, 3, "X"))
    box("ext", (0, TY - .05, .02), (w + .2, .3, .04), "stone")
    ramp(Vector((0, TY - .45, PZ)), Vector((0, TY + .12, .005)), w - .1, "wood", "Threshold")
    LAYOUT["spots"]["front_door"] = godot(Vector((0, TY - 1.2, 0)))
    LAYOUT["front_door"] = {"hinge_l": godot(Vector((-w / 2 + .02, y, 0))), "hinge_r": godot(Vector((w / 2 - .02, y, 0))),
                            "height": zs - .02, "leaf": round(w / 2 - .03, 3), "out": godot(Vector((0, -1, 0)))}
    # The back (kitchen) door is shut and boarded from outside.
    bx = 10.6
    box("ext", (bx, D - T / 2, 1.24), (.98, .05, 2.46), "door wood")
    for z in (.5, 1.2, 1.9):
        beam("ext", (bx - .7, D + .04, z + R.uniform(-.1, .1)), (bx + .7, D + .04, z + R.uniform(-.1, .1)), .2, .03, "board", up=(0, 1, 0))
    for sx in (-1, 1):
        box("ext", (bx + sx * .44, D, .15), (.1, .3, .3), "stone")
    collide((bx, D - T / 2, 1.25), (1.0, .2, 2.5), "wood", label="Back door")


# ------------------------------------------------------------------------------------------------ leaves (separate GLBs)
def front_leaf():
    """One leaf of the double front door, hinge at the origin, leaf along -X, outside facing -Y (Godot +Z)."""
    m = "leaf"
    MESHES[m] = Mesh(m)
    w, h, t = .92, 2.82, .065
    cx = -w / 2

    def b(c, s, mat):
        box(m, (cx + c[0], c[1], c[2]), s, mat)

    b((-w / 2 + .07, 0, h / 2), (.14, t, h), "door wood")
    b((w / 2 - .07, 0, h / 2), (.14, t, h), "door wood")
    for z, hh in ((.12, .24), (1.0, .18), (1.62, .1), (h - .1, .2)):
        b((0, 0, z), (w - .28, t, hh), "door wood")
    for z0, z1 in ((.24, .91),):
        b((0, 0, (z0 + z1) / 2), (w - .28, t * .6, z1 - z0), "panel")
        for y in (-t / 2 - .006, t / 2 + .006):
            b((0, y, (z0 + z1) / 2), (w - .4, .012, z1 - z0 - .14), "door wood")
    b((0, 0, 1.36), (w - .28, t * .6, .34), "panel")
    # Glazed upper panel with an iron grille.
    z0, z1 = 1.67, h - .2
    for y in (-.004, .004):
        face(m, [(cx - w / 2 + .14, y, z0), (cx + w / 2 - .14, y, z0), (cx + w / 2 - .14, y, z1), (cx - w / 2 + .14, y, z1)], "glass grime", (0, -1 if y < 0 else 1, 0))
    for k in range(1, 4):
        cyl(m, (cx - w / 2 + .14 + (w - .28) * k / 4, -.02, z0), (cx - w / 2 + .14 + (w - .28) * k / 4, -.02, z1), .008, "iron", seg=4)
    for k in range(4):
        zz = z0 + (z1 - z0) * (k + .5) / 4
        for i in range(10):
            a0, a1 = math.tau * i / 10, math.tau * (i + 1) / 10
            cyl(m, (cx + math.cos(a0) * .12, -.02, zz + math.sin(a0) * .12), (cx + math.cos(a1) * .12, -.02, zz + math.sin(a1) * .12), .006, "iron", seg=3, caps=False)
    # Knob, keyhole plate, letter slot.
    for y in (-.05, .05):
        lathe(m, (-w + .08, y, 1.05), [(.012, 0), (.03, .01), (.035, .03), (.0, .05)], "brass", seg=10,
              rot=Matrix.Rotation(math.pi / 2 if y < 0 else -math.pi / 2, 3, "X"))
        box(m, (-w + .08, y * .75, .95), (.05, .006, .16), "brass")
    box(m, (cx, -.036, 1.36), (.3, .01, .06), "brass")


def inner_leaf():
    """Six-panel interior door, hinge at the origin, leaf along -X."""
    m = "leaf_door"
    MESHES[m] = Mesh(m)
    w, h, t = .98, 2.47, .045
    cx = -w / 2
    box(m, (cx, 0, h / 2), (w, t * .7, h), "panel")
    for xx in (-w / 2 + .06, w / 2 - .06):
        box(m, (cx + xx, 0, h / 2), (.12, t, h), "door wood")
    for z, hh in ((.11, .22), (.95, .16), (1.75, .12), (h - .07, .14)):
        box(m, (cx, 0, z), (w - .24, t, hh), "door wood")
    box(m, (cx, 0, h / 2), (.1, t, h - .3), "door wood")
    for z0, z1 in ((.22, .87), (1.03, 1.69), (1.81, h - .14)):
        for xs in (-1, 1):
            for y in (-t / 2 - .004, t / 2 + .004):
                box(m, (cx + xs * (w / 4 - .005), y, (z0 + z1) / 2), (w / 2 - .26, .008, z1 - z0 - .1), "door wood")
    for y in (-.045, .045):
        lathe(m, (-w + .07, y, 1.0), [(.01, 0), (.026, .01), (.03, .025), (0, .045)], "brass", seg=10,
              rot=Matrix.Rotation(math.pi / 2 if y < 0 else -math.pi / 2, 3, "X"))


def build():
    plinth()
    corner_boards()
    cornice([s for s in main_segments() if not (abs(s[0].x) <= TX + .01 and abs(s[1].x) <= TX + .01)], TOP)
    downpipes()
    mansard()
    dormers()
    tower()
    chimney(-12.75, 4.7, -11.65, 6.3, 14.6)
    chimney(11.4, 16.6, 12.6, 17.8, 14.1)
    porch()
    entrance()
    front_leaf()
    inner_leaf()
