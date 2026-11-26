"""Cloth for the Nichols house: tattered drapes and torn lace at the windows (house_cloth.glb), and dust sheets
thrown over furniture (sheet_*.glb, placed by nichols_property.gd). All double-sided in Godot."""
from nichols_geo import *  # noqa: F401,F403
from nichols_geo import MESHES, LAYOUT, R, godot, face, box, beam, cyl, lathe, Mesh
import nichols_plan as PL


def grid_face(mesh, pts, mat, nu, nv, skip=None):
    """pts[v][u] grid -> quads with explicit metre UVs (u across, v down)."""
    for j in range(nv - 1):
        for i in range(nu - 1):
            if skip and skip(i, j):
                continue
            q = [pts[j][i], pts[j][i + 1], pts[j + 1][i + 1], pts[j + 1][i]]
            uvs = [(i * .08, -j * .1), ((i + 1) * .08, -j * .1), ((i + 1) * .08, -(j + 1) * .1), (i * .08, -(j + 1) * .1)]
            n = (Vector(q[1]) - Vector(q[0])).cross(Vector(q[3]) - Vector(q[0]))
            face(mesh, q, mat, n if n.length > 1e-9 else None, uvs=uvs, smooth=True)


def drapes(wall, op, state):
    s0, s1 = op["s0"], op["s1"]
    inward = -wall.na
    up = Vector((0, 0, 1))
    head = op["zt"] + ((s1 - s0) / 2 if op["arch"] else 0)
    rod_z = head + .22
    floor = wall.z0 if wall.z0 > 1 else 0.0
    floor = F1 if wall.z0 >= F1 - .01 else 0.0
    face_o = -wall.t / 2

    def P(s, z, off):
        return wall.P(s, face_o, z) + inward * off

    # Rod with finials.
    a, b = P(s0 - .38, rod_z, .12), P(s1 + .38, rod_z, .12)
    cyl("cloth", a, b, .014, "brass", seg=8)
    for e in (a, b):
        lathe("cloth", e - up * .04, [(.0, 0), (.03, .02), (.04, .05), (.02, .08), (0, .09)], "brass", seg=8)
    kind = state.get("curtain")
    if kind == "drape":
        for side in (-1, 1):
            fallen = R.random() < .2
            width = R.uniform(.42, .6)
            nu, nv = 12, 20
            phase = R.uniform(0, 6)
            pts = []
            torn = [R.uniform(0, .55) if R.random() < .5 else R.uniform(0, .12) for _ in range(nu)]
            for j in range(nv):
                t = j / (nv - 1)
                row = []
                for i in range(nu):
                    u = i / (nu - 1)
                    edge_s = s0 - .3 + u * width if side < 0 else s1 + .3 - u * width
                    top = rod_z - .03 - (u * .5 if fallen else 0) * (1 if side < 0 else 1)
                    z = top - t * (top - floor + .12)
                    pool = max(0.0, floor + .02 - z)
                    z = max(z, floor + .015)
                    fold = .055 * math.sin(u * math.tau * 3.2 + phase) * (.6 + .4 * t)
                    off = .12 + fold + pool * .9 + t * t * .05
                    if z <= floor + .02 + torn[i] * 0 and t > .9:
                        pass
                    row.append(P(edge_s, z, off))
                pts.append(row)
            cut = {(i, j) for i in range(nu - 1) for j in range(nv - 1) if (nv - 1 - j) * (1.0 / (nv - 1)) * 3.0 < torn[i]}
            grid_face("cloth", pts, "drape", nu, nv, skip=lambda i, j: (i, j) in cut)
    elif kind == "lace":
        nu, nv = 14, 18
        bottom = op["zb"] + .04
        billow = .1 + state.get("raised", 0.0) * .35
        holes = set()
        for k in range(R.randint(1, 4)):
            ci, cj = R.randint(1, nu - 3), R.randint(2, nv - 3)
            for di in range(R.randint(1, 3)):
                for dj in range(R.randint(1, 4)):
                    holes.add((ci + di, cj + dj))
        drop_right = R.random() < .35
        pts = []
        for j in range(nv):
            t = j / (nv - 1)
            row = []
            for i in range(nu):
                u = i / (nu - 1)
                s = s0 - .12 + u * (s1 - s0 + .24)
                top = rod_z - .02 - (u * .35 if drop_right else 0)
                z = top - t * (top - bottom)
                off = .1 + billow * math.sin(t * math.pi) * (.7 + .3 * math.sin(u * 9 + j)) + .012 * math.sin(u * 40)
                row.append(P(s, z, off))
            pts.append(row)
        grid_face("cloth", pts, "lace", nu, nv, skip=lambda i, j: (i, j) in holes or (j > nv - 4 and R.random() < .3))


def curtains():
    for wall, op, state in PL.WINDOWS:
        if state.get("curtain") and state.get("room") not in ("sealed", None):
            drapes(wall, op, state)


# ------------------------------------------------------------------------------------------------ dust sheets
SHEETS = {
    # name: (width, depth, height, back height (for chairs/sofas), seed)
    "sheet_sofa": (2.0, .9, .55, .95, 1),
    "sheet_armchair": (.9, .9, .5, 1.05, 2),
    "sheet_piano": (1.55, .65, 1.25, None, 3),
    "sheet_table": (1.5, 1.0, .78, None, 4),
    "sheet_tall": (1.2, .6, 2.1, None, 5),
    "sheet_bed": (1.6, 2.1, .65, 1.4, 6),
}


def height_at(x, y, w, d, h, back):
    """Top surface of the hidden shape (a seat with an optional backrest along +y)."""
    if back is not None and y > d / 2 - .22:
        return back
    if back is not None:
        # Arms either side for chairs and sofas.
        if abs(x) > w / 2 - .14:
            return h + .18
    return h


def sheet(name, w, d, h, back, seed):
    rnd = random.Random(seed)
    m = Mesh(name)
    MESHES[name] = m
    top = max(h, back or 0)
    span = top + .14
    hw, hd = w / 2 + span, d / 2 + span
    nu, nv = 44, 44
    pts = []
    for j in range(nv):
        row = []
        for i in range(nu):
            px = -hw + 2 * hw * i / (nu - 1)
            py = -hd + 2 * hd * j / (nv - 1)
            ex = max(abs(px) - w / 2, 0)
            ey = max(abs(py) - d / 2, 0)
            e = max(ex, ey)
            if e <= 0:
                z = height_at(px, py, w, d, h, back) + .01 + .015 * math.sin(px * 7 + seed) * math.sin(py * 5)
                pos = Vector((px, py, z))
            else:
                # Hanging down the sides, flaring out, then lying on the floor in folds.
                cx = max(-w / 2, min(w / 2, px))
                cy = max(-d / 2, min(d / 2, py))
                edge = Vector((cx, cy, 0))
                out = Vector((px - cx, py - cy, 0)).normalized()
                edge_top = height_at(cx * .98, cy * .98, w, d, h, back)
                along = (px if ex < ey else py)
                fold = .05 * math.sin(along * 9 + seed * 2) + .03 * math.sin(along * 23)
                z = edge_top - e
                spread = .015 + e * .12 + fold * min(1, e * 3)
                if z < .012:
                    spread += (.012 - z) * .85
                    z = .012 + abs(fold) * .1
                pos = edge + out * spread + Vector((0, 0, z))
            row.append(pos)
        pts.append(row)
    # Ragged hem: drop the outermost ring where it would lie far out on the floor, irregularly.
    keep = lambda i, j: (abs(i - (nu - 1) / 2) / ((nu - 1) / 2) > .955 or abs(j - (nv - 1) / 2) / ((nv - 1) / 2) > .955) and rnd.random() < .3
    for jj in range(nv - 1):
        for ii in range(nu - 1):
            if keep(ii, jj):
                continue
            q = [pts[jj][ii], pts[jj][ii + 1], pts[jj + 1][ii + 1], pts[jj + 1][ii]]
            uvs = [(ii * .06, jj * .06), ((ii + 1) * .06, jj * .06), ((ii + 1) * .06, (jj + 1) * .06), (ii * .06, (jj + 1) * .06)]
            face(name, q, "sheet", None, uvs=uvs, smooth=True)


def sheets():
    for name, (w, d, h, back, seed) in SHEETS.items():
        sheet(name, w, d, h, back, seed)
