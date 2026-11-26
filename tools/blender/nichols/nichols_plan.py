"""The Nichols house plan: walls with their openings, windows, floors and ceilings, the imperial staircase,
galleries, fireplaces and the columned parlour opening (see nichols_geo for the builder)."""
from nichols_geo import *  # noqa: F401,F403
from nichols_geo import MESHES, LAYOUT, R, godot, face, box, beam, cyl, lathe, run, vrun, collide, ramp, Wall, Side
import nichols_basement as BS

# ------------------------------------------------------------------------------------------------ windows
WINDOWS = []


def frame_of(wall, op):
    """Bottom centre of an opening on the wall centreline, the wall direction and its outward normal (side A)."""
    sc = (op["s0"] + op["s1"]) / 2
    return wall.P(sc, 0, op["zb"]), wall.d, wall.na


def sash_window(wall, op, state):
    """Frame, two sashes with a muntin, glass (panes broken or gone), set 9 cm back from the outer face."""
    o0, dx, out = frame_of(wall, op)
    w = op["s1"] - op["s0"]
    arch = op["arch"]
    h = op["zt"] - op["zb"]
    r = w / 2
    plane = o0 + out * (wall.t / 2 - .09)
    up = Vector((0, 0, 1))
    rot = Matrix((dx, out, up)).transposed()

    def at(x, z, y=0.0):
        return plane + dx * x + up * z + out * y

    box("ext", at(-w / 2 + .04, h / 2), (.08, .1, h), "sash", rot)
    box("ext", at(w / 2 - .04, h / 2), (.08, .1, h), "sash", rot)
    box("ext", at(0, .03), (w, .12, .06), "sash", rot)
    if not arch:
        box("ext", at(0, h - .04), (w, .1, .08), "sash", rot)
    else:
        n = 12
        for i in range(n):
            a0, a1 = math.pi * i / n, math.pi * (i + 1) / n
            beam("ext", at(math.cos(a0) * (r - .04), h + math.sin(a0) * (r - .04)), at(math.cos(a1) * (r - .04), h + math.sin(a1) * (r - .04)),
                 .08, .1, "sash", up=out)
    raised = state.get("raised", 0.0) * (h / 2 - .1)
    mid = h / 2
    for k, (z0, z1) in enumerate(((.06 + raised, mid + raised), (mid, h - (0 if arch else .08)))):
        y = .025 if k == 0 else -.025
        for xx in (-w / 2 + .1, w / 2 - .1):
            box("ext", at(xx, (z0 + z1) / 2, y), (.05, .045, z1 - z0), "sash", rot)
        box("ext", at(0, z0 + .03, y), (w - .16, .045, .06), "sash", rot)
        box("ext", at(0, z1 - .025, y), (w - .16, .045, .05), "sash", rot)
        box("ext", at(0, (z0 + z1) / 2, y), (.022, .03, z1 - z0 - .08), "sash", rot)
        for side in (-1, 1):
            x0, x1 = (-w / 2 + .125, -.011) if side < 0 else (.011, w / 2 - .125)
            if R.random() < state.get("broken", 0.0):
                # A broken pane: a jagged shard still caught in a corner.
                corner = x0 if R.random() < .5 else x1
                other = x1 if corner == x0 else x0
                zz = z0 + .06 if R.random() < .6 else z1 - .05
                zo = z1 - .05 if zz < (z0 + z1) / 2 else z0 + .06
                pts = [at(corner, zz, y), at(corner + (other - corner) * R.uniform(.3, .8), zz, y), at(corner, zz + (zo - zz) * R.uniform(.25, .6), y)]
                face("glass", pts, "glass", out)
                face("glass", pts, "glass", -out)
                continue
            q = [at(x0, z0 + .06, y), at(x1, z0 + .06, y), at(x1, z1 - .05, y), at(x0, z1 - .05, y)]
            mat = "glass" if R.random() > .3 else "glass grime"
            face("glass", q, mat, out)
            face("glass", q, mat, -out)
    if arch:
        n = 12
        fan = [at(math.cos(math.pi * i / n) * (r - .08), h + math.sin(math.pi * i / n) * (r - .08), -.025) for i in range(n + 1)]
        if R.random() > state.get("broken", 0.0) * .5:
            face("glass", fan, "glass", out)
            face("glass", fan, "glass", -out)
        for i in range(0, n + 1, 3):
            a = math.pi * i / n
            beam("ext", at(0, h, -.025), at(math.cos(a) * (r - .06), h + math.sin(a) * (r - .06), -.025), .022, .03, "sash", up=out)


def window_dressing(wall, op, kind):
    """Outside: casing, sill on brackets, hood (segmental pediment on the ground floor) or an arched hood
    with a keystone, louvred shutters (open, missing, hanging off one hinge, half shut)."""
    o0, dx, out = frame_of(wall, op)
    w = op["s1"] - op["s0"]
    h = op["zt"] - op["zb"]
    face0 = o0 + out * wall.t / 2
    up = Vector((0, 0, 1))
    rot = Matrix((dx, out, up)).transposed()

    def at(x, z, y=0.0):
        return face0 + dx * x + up * z + out * y

    extra = w / 2 if op["arch"] else .05
    for xx in (-w / 2 - .07, w / 2 + .07):
        box("ext", at(xx, (h + extra) / 2, .02), (.14, .04, h + extra), "trim ext", rot)
    if op["zb"] > .05:
        box("ext", at(0, -.04, .06), (w + .34, .12, .07), "trim ext", rot)
        for xx in (-w / 2 - .05, w / 2 + .05):
            box("ext", at(xx, -.17, .04), (.07, .08, .2), "trim ext", rot)
    if op["arch"]:
        r = w / 2
        n = 14
        prev = None
        ctr = at(0, h, .045)
        for i in range(n + 1):
            a = math.pi * i / n
            p_in = at(math.cos(a) * (r + .02), h + math.sin(a) * (r + .02), .045)
            p_out = at(math.cos(a) * (r + .2), h + math.sin(a) * (r + .2), .045)
            if prev:
                face("ext", [prev[0], p_in, p_out, prev[1]], "trim ext", out)
                face("ext", [prev[1], p_out, p_out - out * .045, prev[1] - out * .045], "trim ext", (p_out + prev[1]) / 2 - ctr)
                face("ext", [prev[0], p_in, p_in - out * .045, prev[0] - out * .045], "trim ext", ctr - (p_in + prev[0]) / 2)
            prev = (p_in, p_out)
        box("ext", at(0, h + r + .05, .07), (.22, .1, .34), "trim ext", rot)
    else:
        box("ext", at(0, h + .17, .025), (w + .3, .05, .26), "trim ext", rot)
        run("ext", at(-w / 2 - .22, h + .3), at(w / 2 + .22, h + .3), out,
            [(0, 0), (.06, 0), (.08, .03), (.16, .06), (.16, .12), (0, .12)], "trim ext")
        for xx in (-w / 2 - .12, w / 2 + .12):
            box("ext", at(xx, h + .2, .06), (.07, .1, .2), "trim ext", rot)
        if kind.get("pediment"):
            n = 10
            span = w / 2 + .25
            rise = .3
            pts = [at(-span + 2 * span * i / n, h + .42 + rise * math.sin(math.pi * i / n), .02) for i in range(n + 1)]
            face("ext", pts, "trim ext", out)
            for i in range(n):
                beam("ext", pts[i] + out * .05, pts[i + 1] + out * .05, .12, .07, "trim ext", up=out)
    state = kind.get("shutter", "open")
    if state == "none":
        return
    for side in (-1, 1):
        st = state if state != "hang" or side == 1 else "open"
        if st == "missing" or (st == "closed_half" and side < 0):
            continue
        sw = w / 2 + .02
        sh = h + (w / 2 if op["arch"] else 0) - .05
        if st == "closed_half":
            centre = at(side * (w / 2 - sw / 2 + .02), sh / 2 + .02, .09)
            m = Matrix.Rotation(math.radians(side * 8), 3, up) @ rot
        elif st == "hang":
            # Torn off its upper hinge: tipped over the lower one, swinging off the wall.
            hinge = at(side * (w / 2 + .17), .05, .05)
            m = Matrix.Rotation(math.radians(-side * 24), 3, out) @ Matrix.Rotation(math.radians(side * 18), 3, up) @ rot
            centre = hinge + m @ Vector((side * sw / 2, 0, sh / 2))
        else:
            centre = at(side * (w / 2 + .17 + sw / 2), sh / 2 + .02, .05)
            m = rot
        louvered_shutter(centre, m, sw, sh)


def louvered_shutter(c, rot, w, h):
    ax, az = rot @ Vector((1, 0, 0)), rot @ Vector((0, 0, 1))
    c = Vector(c)
    for xx in (-w / 2 + .03, w / 2 - .03):
        box("ext", c + ax * xx, (.06, .035, h), "shutter", rot)
    for zz in (-h / 2 + .04, 0, h / 2 - .04):
        box("ext", c + az * zz, (w - .1, .035, .08), "shutter", rot)
    z = -h / 2 + .1
    tilt = rot @ Matrix.Rotation(math.radians(38), 3, Vector((1, 0, 0)))
    while z < h / 2 - .1:
        if abs(z) > .06 and R.random() > .06:
            box("ext", c + az * z, (w - .1, .006, .055), "shutter", tilt)
        z += .05


def boards_over(wall, op):
    o0, dx, out = frame_of(wall, op)
    w = op["s1"] - op["s0"]
    h = op["zt"] - op["zb"] + ((w / 2) if op["arch"] else 0)
    face0 = o0 + out * (wall.t / 2 + .03)
    up = Vector((0, 0, 1))
    z = .15
    while z < h - .1:
        tilt = R.uniform(-.12, .12)
        beam("ext", face0 + dx * (-w / 2 - .12) + up * (z + tilt), face0 + dx * (w / 2 + .12) + up * (z - tilt), R.uniform(.16, .22), .025, "board", up=out)
        z += R.uniform(.22, .42)


def exterior_window(wall, op, kind):
    state = dict(kind)
    state.setdefault("broken", .15)
    WINDOWS.append((wall, op, state))
    LAYOUT["windows"].append({
        "center": godot(wall.P((op["s0"] + op["s1"]) / 2, 0, (op["zb"] + op["zt"]) / 2)),
        "bottom": godot(wall.P((op["s0"] + op["s1"]) / 2, wall.t / 2, op["zb"])),
        "inner": godot(wall.P((op["s0"] + op["s1"]) / 2, -wall.t / 2, op["zb"])),
        "normal": godot(wall.na), "along": godot(wall.d), "width": round(op["s1"] - op["s0"], 3),
        "height": round(op["zt"] - op["zb"] + ((op["s1"] - op["s0"]) / 2 if op["arch"] else 0), 3),
        "moonlit": wall.na.dot(Vector((MOON.x, MOON.y, 0)).normalized()) > .2,
        "boarded": bool(kind.get("boarded")), "blind": bool(kind.get("blind")), "room": kind.get("room", ""),
        "arch": op["arch"], "curtain": kind.get("curtain", ""), "raised": kind.get("raised", 0.0),
    })


def dress_windows():
    for wall, op, state in WINDOWS:
        if state.get("blind"):
            # Sealed upstairs rooms: the window shows a black room behind dirty glass.
            box("void", wall.P((op["s0"] + op["s1"]) / 2, -.12, (op["zb"] + op["zt"]) / 2), (op["s1"] - op["s0"], .02, op["zt"] - op["zb"]), "void",
                Matrix((wall.d, wall.na, Vector((0, 0, 1)))).transposed())
        sash_window(wall, op, dict(state, broken=.5) if state.get("boarded") else state)
        if state.get("boarded"):
            boards_over(wall, op)
        window_dressing(wall, op, state)


# ------------------------------------------------------------------------------------------------ plan
GW = dict(w=1.1, sill=.7, head=3.3)
UW = dict(w=1.0, sill=F1 + .6, head=F1 + 2.85)
WALLS = []


def room_side(mat, ceiling=C0, wainscot=1.0, base=True):
    return Side("int", mat, base=base, crown=ceiling, wainscot=wainscot, reveal="plaster")


def ext_wall(p0, p1, mats_lo, mats_hi, lo_ops, hi_ops, label):
    lo = Wall(p0, p1, 0, F1, T, Side("ext", "siding"), room_side(mats_lo), "plaster", label)
    hi = Wall(p0, p1, F1, TOP, T, Side("ext", "siding"), Side("int", mats_hi, base=True, crown=C1, rail=.95), "plaster", label)
    for wall, ops, dflt in ((lo, lo_ops, GW), (hi, hi_ops, UW)):
        for at, spec in ops:
            op = wall.opening(at, spec.get("w", dflt["w"]), spec.get("sill", dflt["sill"]), spec.get("head", dflt["head"]),
                              spec.get("arch", False), spec.get("kind", "window"), reveal=spec.get("reveal", "plaster"))
            if op["kind"] == "window":
                exterior_window(wall, op, spec)
            elif op["kind"] == "door":
                LAYOUT.setdefault("entries", []).append({"label": label, "hinge_l": godot(wall.P(op["s0"], 0, 0)),
                                                         "hinge_r": godot(wall.P(op["s1"], 0, 0)), "out": godot(wall.na),
                                                         "spring": op["zt"], "width": round(op["s1"] - op["s0"], 3), "kind": spec.get("entry", "front")})
    WALLS.extend([lo, hi])


def part(p0, p1, z0, z1, mat_a, mat_b, ops=(), label="partition", crown=(None, None), wains=(1.0, 1.0), base=(True, True)):
    a = Side("int", mat_a, base=base[0], crown=crown[0], wainscot=wains[0]) if mat_a else None
    b = Side("int", mat_b, base=base[1], crown=crown[1], wainscot=wains[1]) if mat_b else None
    wl = Wall(p0, p1, z0, z1, P, a, b, "plaster", label)
    for at, spec in ops:
        op = wl.opening(at, spec["w"], spec.get("sill", z0), spec["head"], spec.get("arch", False), spec.get("kind", "door"),
                        reveal=spec.get("reveal", "trim"))
        door = spec.get("door")
        if door:
            hinge_s = op["s0"] if door.get("hinge", "s0") == "s0" else op["s1"]
            latch_s = op["s1"] if hinge_s == op["s0"] else op["s0"]
            swing = wl.na if door.get("swing", "A") == "A" else -wl.na
            LAYOUT["doors"].append({"hinge": godot(wl.P(hinge_s, 0, z0)), "latch": godot(wl.P(latch_s, 0, z0)), "swing": godot(swing),
                                    "height": round(spec["head"] - z0 - .01, 3), "width": round(op["s1"] - op["s0"] - .02, 3),
                                    "state": door.get("state", "closed"), "angle": door.get("angle", 0), "label": door.get("label", label)})
    WALLS.append(wl)
    return wl


def plan():
    hx = TX - T / 2
    # ---- exterior (A faces out: every exterior wall runs clockwise seen from above)
    ext_wall((-hx, T / 2), (-W, T / 2), "wp parlour", "wp corridor",
             [((-6.5, 0), dict(pediment=True, room="parlour", curtain="drape", broken=.6, raised=.55)),
              ((-10.5, 0), dict(pediment=True, room="parlour", curtain="drape"))],
             [((-6.5, 0), dict(room="corridor_w", curtain="lace", shutter="hang")), ((-10.5, 0), dict(room="corridor_w", curtain="lace", broken=.35))],
             "North wall west")
    ext_wall((W, T / 2), (hx, T / 2), "wp dining", "wp corridor",
             [((10.5, 0), dict(pediment=True, room="dining", boarded=True)), ((6.5, 0), dict(pediment=True, room="dining", curtain="drape", broken=.3))],
             [((10.5, 0), dict(room="corridor_e", curtain="lace", shutter="missing")), ((6.5, 0), dict(room="corridor_e", curtain="lace", broken=.5, raised=.6))],
             "North wall east")
    ext_wall((TX, TY + T / 2), (-TX, TY + T / 2), "wp hall", "wp hall",
             [((0, TY), dict(w=1.9, sill=0, head=2.85, arch=True, kind="door", reveal="trim"))],
             [((0, TY), dict(w=1.5, sill=F1 + .7, head=F1 + 2.5, arch=True, room="bridge", curtain="lace", shutter="none", broken=.25))],
             "Tower front")
    ext_wall((-hx, TY), (-hx, T), "wp hall", "wp hall", [], [], "Tower west")
    ext_wall((hx, T), (hx, TY), "wp hall", "wp hall", [], [], "Tower east")
    ext_wall((-W + T / 2, 0), (-W + T / 2, D), [(11, "wp parlour"), (13.4, "wp hall"), (D, "wainscot")],
             [(2.4, "wp corridor"), (11, "wp bedroom"), (D, "plaster dark")],
             [((-W, 2.8), dict(pediment=True, room="parlour", curtain="drape", raised=.45, broken=.5)),
              ((-W, 8.3), dict(pediment=True, room="parlour", curtain="drape")),
              ((-W, 12.2), dict(room="hall", curtain="lace", broken=.4)),
              ((-W, 15.6), dict(room="library", curtain="drape")), ((-W, 18.2), dict(room="library", boarded=True))],
             [((-W, 1.25), dict(w=.9, room="corridor_w", curtain="lace", broken=.3)),
              ((-W, 3.3), dict(room="master", curtain="drape")), ((-W, 8.6), dict(room="master", curtain="lace", broken=.6, raised=.5)),
              ((-W, 12.2), dict(room="sealed", blind=True)), ((-W, 15.6), dict(room="sealed", blind=True, shutter="closed_half")),
              ((-W, 18.2), dict(room="sealed", blind=True, boarded=True))], "West wall")
    ext_wall((W - T / 2, D), (W - T / 2, 0), [(D - 13.4, "plaster"), (D - 11, "wp hall"), (D, "wp dining")],
             [(D - 11, "plaster dark"), (D - 2.4, "wp nursery"), (D, "wp corridor")],
             [((W, 18.2), dict(room="kitchen", shutter="hang", broken=.4)), ((W, 15.6), dict(room="kitchen", broken=.5)),
              ((W, 12.2), dict(room="hall", broken=.3)),
              ((W, 8.2), dict(pediment=True, room="dining", curtain="drape")), ((W, 2.8), dict(pediment=True, room="dining", curtain="drape", broken=.4))],
             [((W, 18.2), dict(room="sealed", blind=True)), ((W, 15.6), dict(room="sealed", blind=True)),
              ((W, 12.2), dict(room="sealed", blind=True, shutter="missing")),
              ((W, 8.6), dict(room="nursery", curtain="lace")), ((W, 3.3), dict(room="nursery", curtain="lace", broken=.4)),
              ((W, 1.25), dict(w=.9, room="corridor_e", curtain="lace"))], "East wall")
    ext_wall((-W, D - T / 2), (W, D - T / 2), [(W - 4, "wainscot"), (W + 4, "plaster"), (2 * W, "plaster")], "plaster dark",
             [((10.6, D), dict(w=1.0, sill=0, head=2.5, kind="door", entry="back", reveal="trim")), ((6.5, D), dict(room="kitchen", broken=.6, sill=1.15)),
              ((0, D), dict(w=.8, room="pantry", broken=.3)), ((-6.5, D), dict(room="library", curtain="drape")),
              ((-10.5, D), dict(room="library", boarded=True))],
             [((10.5, D), dict(room="sealed", blind=True)), ((6.5, D), dict(room="sealed", blind=True, shutter="missing")),
              ((0, D), dict(room="sealed", blind=True)), ((-6.5, D), dict(room="sealed", blind=True, boarded=True)),
              ((-10.5, D), dict(room="sealed", blind=True))], "South wall")

    # ---- partitions, ground floor
    # 0.22: the closet behind the foyer is the cellar stair's shaft; its four walls get plain plaster on that side.
    part((-4, T), (-4, 11), 0, F1, "wp parlour", [(9.4 - T, "wp hall"), (11 - T, "plaster dark")], [((-4, 2.15), dict(w=3.1, head=3.15, kind="open"))],
         "Parlour wall", crown=(C0, None))
    part((4, 11), (4, T), 0, F1, "wp dining", [(1.6, "plaster dark"), (11 - T, "wp hall")], [((4, 2.1), dict(w=1.9, head=2.9, kind="pocket"))],
         "Dining wall", crown=(C0, None))
    # The cellar door: low, under the grand stair's landing, at the end of the east nook.
    part((4, 9.4), (-4, 9.4), 0, C1 + .4, "wp hall", "plaster dark",
         [((BS.DOOR_X, 9.4), dict(w=BS.DOOR_W, head=BS.DOOR_H, reveal="trim"))], "Foyer back wall", crown=(C1, None), wains=(1.0, False))
    part((-W + T, 11), (-4, 11), 0, F1, "wp hall", "wp parlour",
         [((-7.0, 11), dict(w=1.0, head=2.5, door=dict(hinge="s0", swing="A", state="ajar", angle=38, label="Parlour door")))],
         "Hall north wall west", crown=(C0, C0))
    part((-4, 11), (4, 11), 0, F1, "wp hall", "plaster dark", [], "Hall north wall middle", crown=(C0, None), wains=(1.0, False))
    part((4, 11), (W - T, 11), 0, F1, "wp hall", "wp dining",
         [((7.0, 11), dict(w=1.0, head=2.5, door=dict(hinge="s1", swing="A", state="open", angle=95, label="Dining door")))],
         "Hall north wall east", crown=(C0, C0))
    part((W - T, 13.4), (4, 13.4), 0, F1, "wp hall", "plaster",
         [((8.5, 13.4), dict(w=1.0, head=2.5, door=dict(hinge="s0", swing="B", state="ajar", angle=50, label="Kitchen door")))],
         "Hall south wall east", crown=(C0, C0), wains=(1.0, .9))
    part((4, 13.4), (-4, 13.4), 0, F1, "wp hall", "plaster",
         [((0, 13.4), dict(w=.9, head=2.4, door=dict(hinge="s1", swing="B", state="locked", label="Pantry door")))],
         "Hall south wall middle", crown=(C0, C0), wains=(1.0, .9))
    part((-4, 13.4), (-W + T, 13.4), 0, F1, "wp hall", "wainscot",
         [((-8.5, 13.4), dict(w=1.0, head=2.5, door=dict(hinge="s1", swing="B", state="closed", label="Library door")))],
         "Hall south wall west", crown=(C0, C0))
    part((-4, 13.4), (-4, D - T), 0, F1, "wainscot", "plaster", [], "Library wall", crown=(C0, C0), wains=(1.0, .9))
    part((4, D - T), (4, 13.4), 0, F1, "plaster", "plaster",
         [((4, 16.6), dict(w=.9, head=2.4, door=dict(hinge="s0", swing="B", state="closed", label="Pantry side door")))],
         "Kitchen wall", crown=(C0, C0), wains=(.9, .9))
    # ---- partitions, upper floor
    part((-4, 2.4), (-W + T, 2.4), F1, C1 + .4, "wp corridor", "wp bedroom",
         [((-8.5, 2.4), dict(w=1.0, sill=F1, head=F1 + 2.5, door=dict(hinge="s0", swing="B", state="ajar", angle=30, label="Bedroom door")))],
         "Master wall", crown=(C1, C1), wains=(False, False))
    part((W - T, 2.4), (4, 2.4), F1, C1 + .4, "wp corridor", "wp nursery",
         [((8.5, 2.4), dict(w=1.0, sill=F1, head=F1 + 2.5, door=dict(hinge="s1", swing="B", state="closed", label="Nursery door")))],
         "Nursery wall", crown=(C1, C1), wains=(False, False))
    part((-4, 2.4), (-4, 11), F1, C1 + .4, "wp bedroom", "wp hall", [], "Master east wall", crown=(C1, C1), wains=(False, False), base=(True, False))
    part((4, 11), (4, 2.4), F1, C1 + .4, "wp nursery", "wp hall", [], "Nursery west wall", crown=(C1, C1), wains=(False, False), base=(True, False))
    part((-W + T, 11), (-4, 11), F1, C1 + .4, None, "wp bedroom", [], "Master back wall", crown=(None, C1), wains=(False, False))
    part((4, 11), (W - T, 11), F1, C1 + .4, None, "wp nursery", [], "Nursery back wall", crown=(None, C1), wains=(False, False))
    part((-4, 11), (4, 11), F1, C1 + .4, None, "plaster dark", [], "Sealed wall", wains=(False, False))
    for wl in WALLS:
        wl.build()
    dress_windows()


# ------------------------------------------------------------------------------------------------ floors and ceilings
ROOMS = [
    # name, rects [(x0, y0, x1, y1)], floor z, ceiling z, floor material, footstep surface
    ("foyer", [(-4, T, 4, 9.4), (-TX + T, TY + T, TX - T, T)], 0.0, C1, "marble", "tile"),
    ("parlour", [(-W + T, T, -4, 11)], 0.0, C0, "floor", "wood"),
    ("dining", [(4, T, W - T, 11)], 0.0, C0, "floor", "wood"),
    ("closet", [(-4, 9.4, 4, 11)], 0.0, C0, "floor", "wood"),
    ("hall", [(-W + T, 11, W - T, 13.4)], 0.0, C0, "floor b", "wood"),
    ("library", [(-W + T, 13.4, -4, D - T)], 0.0, C0, "floor", "wood"),
    ("pantry", [(-4, 13.4, 4, D - T)], 0.0, C0, "tile", "tile"),
    ("kitchen", [(4, 13.4, W - T, D - T)], 0.0, C0, "tile", "tile"),
    ("corridor_w", [(-W + T, T, -4, 2.4)], F1, C1, "floor b", "wood"),
    ("corridor_e", [(4, T, W - T, 2.4)], F1, C1, "floor b", "wood"),
    ("bridge", [(-4, T, 4, 2.4), (-TX + T, TY + T, TX - T, T)], F1, C1, "floor b", "wood"),
    ("gallery_w", [(-4, 2.4, -2.6, 3.7)], F1, C1, "floor b", "wood"),
    ("gallery_e", [(2.6, 2.4, 4, 3.7)], F1, C1, "floor b", "wood"),
    ("master", [(-W + T, 2.4, -4, 11)], F1, C1, "floor", "wood"),
    ("nursery", [(4, 2.4, W - T, 11)], F1, C1, "floor", "wood"),
    ("sealed", [(-W + T, 11, W - T, D - T), (-4, 9.4, 4, 11)], F1, C1, "floor b", "wood"),
]
PARLOUR_HOLE = (-9.6, 5.9, -7.1, 8.1)


def rect_face(mesh, x0, y0, x1, y1, z, mat, up=True):
    face(mesh, [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)], mat, (0, 0, 1 if up else -1))


def floors():
    for name, rects, fz, cz, fmat, surface in ROOMS:
        for x0, y0, x1, y1 in rects:
            if name != "closet":
                rect_face("int", x0, y0, x1, y1, fz, fmat)
                collide(((x0 + x1) / 2, (y0 + y1) / 2, fz - .2), (x1 - x0, y1 - y0, .4), surface, label=name + " floor")
            if name == "closet":
                # The stair shaft: nichols_basement.shaft() lays the landing behind the cellar door.
                rect_face("int", x0, y0, x1, y1, cz, "ceiling", up=False)
                continue
            if name == "foyer" and (y0, y1) == (T, 9.4):
                rect_face("int", x0, y0, x1, y1, C1, "ceiling", up=False)
                continue
            if name == "parlour":
                hx0, hy0, hx1, hy1 = PARLOUR_HOLE
                for r in ((x0, y0, x1, hy0), (x0, hy1, x1, y1), (x0, hy0, hx0, hy1), (hx1, hy0, x1, hy1)):
                    rect_face("int", *r, cz, "ceiling", up=False)
                fallen_ceiling(PARLOUR_HOLE, cz)
                continue
            if name in ("bridge", "gallery_w", "gallery_e"):
                continue
            rect_face("int", x0, y0, x1, y1, cz, "ceiling", up=False)
        LAYOUT["rooms"].append({"name": name, "floor": fz, "ceiling": cz, "surface": surface,
                                "rects": [[godot(Vector((a, b, fz))), godot(Vector((c, d, cz)))] for a, b, c, d in rects]})
    # Undersides of the bridge and the side galleries over the foyer, their slab edges, and the foyer's high ceiling.
    for x0, y0, x1, y1 in ((-4, T, 4, 2.4), (-TX + T, TY + T, TX - T, T), (-4, 2.4, -2.6, 3.7), (2.6, 2.4, 4, 3.7)):
        rect_face("int", x0, y0, x1, y1, C0, "ceiling", up=False)
    for a, b, n in (((-2.6, 2.4), (2.6, 2.4), (0, 1, 0)), ((-2.6, 2.4), (-2.6, 3.7), (1, 0, 0)), ((2.6, 2.4), (2.6, 3.7), (-1, 0, 0)),
                    ((-4, 3.7), (-2.6, 3.7), (0, 1, 0)), ((2.6, 3.7), (4, 3.7), (0, 1, 0))):
        face("int", [(a[0], a[1], C0), (b[0], b[1], C0), (b[0], b[1], F1), (a[0], a[1], F1)], "trim", n)
    rect_face("int", -4, TY + T, 4, T, C1, "ceiling", up=False)
    # Ceiling medallion for the chandelier.
    lathe("int", (0, 5.6, C1), [(.62, 0), (.6, -.02), (.5, -.045), (.36, -.06), (.2, -.09), (.08, -.1), (0, -.1)], "trim", seg=28)
    LAYOUT["spots"]["chandelier_foyer"] = godot(Vector((0, 5.6, C1 - .1)))
    LAYOUT["spots"]["chandelier_dining"] = godot(Vector((8.4, 5.6, C0)))
    LAYOUT["spots"]["chandelier_parlour"] = godot(Vector((-8.4, 3.6, C0)))
    lathe("int", (8.4, 5.6, C0), [(.45, 0), (.42, -.03), (.25, -.06), (.08, -.08), (0, -.08)], "trim", seg=24)
    lathe("int", (-8.4, 3.6, C0), [(.45, 0), (.42, -.03), (.25, -.06), (.08, -.08), (0, -.08)], "trim", seg=24)


def fallen_ceiling(hole, cz):
    """The parlour ceiling has come down: joists and the floorboards above show, laths hang into the room."""
    x0, y0, x1, y1 = hole
    rect_face("int", x0 - .2, y0 - .2, x1 + .2, y1 + .2, cz + .3, "floor b", up=False)
    x = x0 - .15
    while x < x1 + .15:
        box("int", (x, (y0 + y1) / 2, cz + .17), (.06, y1 - y0 + .4, .24), "joist")
        x += .41
    for a, b, n in (((x0, y0), (x1, y0), (0, 1, 0)), ((x1, y0), (x1, y1), (-1, 0, 0)), ((x1, y1), (x0, y1), (0, -1, 0)), ((x0, y1), (x0, y0), (1, 0, 0))):
        face("int", [(a[0], a[1], cz), (b[0], b[1], cz), (b[0], b[1], cz + .3), (a[0], a[1], cz + .3)], "plaster", n)
        # Ragged plaster lip.
        d = Vector((b[0] - a[0], b[1] - a[1], 0))
        L = d.length
        d.normalize()
        s = 0
        while s < L - .1:
            w = R.uniform(.1, .35)
            p = Vector((a[0], a[1], cz)) + d * (s + w / 2) + Vector(n) * R.uniform(.02, .14)
            box("int", p - Vector((0, 0, .012)), (w, .14, .025), "plaster", Matrix.Rotation(math.atan2(d.y, d.x), 3, "Z"))
            s += w + R.uniform(0, .2)
    for i in range(16):
        # Laths dangling from the edges.
        edge = R.random()
        px = x0 + (x1 - x0) * R.random()
        py = y0 if edge < .5 else y1
        top = Vector((px, py, cz + .02))
        bottom = top + Vector((R.uniform(-.25, .25), R.uniform(-.3, .3) * (1 if edge < .5 else -1) + (.35 if edge < .5 else -.35), -R.uniform(.4, 1.3)))
        beam("int", top, bottom, .035, .008, "lath")
    LAYOUT["spots"]["parlour_rubble"] = godot(Vector(((x0 + x1) / 2, (y0 + y1) / 2, 0)))


# ------------------------------------------------------------------------------------------------ staircase
RISE = LANDING / 12


def flight(x0, x1, y_bot, y_top, z_bot, n, carpet=True, label="stair"):
    """n risers from (y_bot, z_bot) to (y_top, z_bot + n*RISE); y_top may be less than y_bot."""
    sy = 1 if y_top > y_bot else -1
    t = abs(y_top - y_bot) / (n - 1)
    nose = .035
    for i in range(n):
        y = y_bot + sy * i * t
        za, zb = z_bot + i * RISE, z_bot + (i + 1) * RISE
        face("int", [(x0, y, za), (x1, y, za), (x1, y, zb), (x0, y, zb)], "riser", (0, -sy, 0))
        if i < n - 1:
            box("int", ((x0 + x1) / 2, y + sy * (t / 2 - nose / 2), zb - .02), (x1 - x0 + .03, t + nose, .04), "tread")
            run("int", (x0 - .015, y - sy * nose, zb - .04), (x1 + .015, y - sy * nose, zb - .04), (0, -sy, 0),
                [(0, 0), (.012, .005), (.016, .02), (.01, .036), (0, .04)], "tread", caps=True)
            if carpet:
                cx = (x0 + x1) / 2
                cw = min(1.5, (x1 - x0) * .72)
                face("int", [(cx - cw / 2, y + sy * .002, zb + .002), (cx + cw / 2, y + sy * .002, zb + .002),
                             (cx + cw / 2, y + sy * (t - .002), zb + .002), (cx - cw / 2, y + sy * (t - .002), zb + .002)], "carpet", (0, 0, 1))
                face("int", [(cx - cw / 2, y - sy * .004, za + .02), (cx + cw / 2, y - sy * .004, za + .02),
                             (cx + cw / 2, y - sy * .004, zb), (cx - cw / 2, y - sy * .004, zb)], "carpet", (0, -sy, 0))
                cyl("int", (cx - cw / 2 - .04, y + sy * .03, zb + .012), (cx + cw / 2 + .04, y + sy * .03, zb + .012), .007, "brass", seg=6)
    a = Vector(((x0 + x1) / 2, y_bot - sy * .15, z_bot))
    b = Vector(((x0 + x1) / 2, y_top, z_bot + n * RISE))
    ramp(a, b, x1 - x0, "wood", label)
    return t


def stringer_z(y, y_bot, y_top, z_bot, n):
    t = abs(y_top - y_bot) / (n - 1)
    k = (y - y_bot) / (y_top - y_bot)
    return z_bot + RISE + k * (n - 1) * RISE


def balustrade(a, b, mat="baluster", rail_h=.92, spacing=.16, sloped=False, newels=(True, True), collide_=True):
    """Handrail, bottom rail and turned balusters from a to b (points on the floor or the stringer line)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    L = d.length
    n = max(1, int(L / spacing))
    up = Vector((0, 0, 1))
    for i in range(1, n):
        p = a + d * (i / n)
        if R.random() < .05:
            continue  # a baluster kicked out
        h = rail_h - .06
        lathe("int", p, [(.024, 0), (.024, .05), (.018, .07), (.016, .12), (.026, .2), (.03, .26), (.022, .34), (.014, .42),
                         (.014, h - .14), (.022, h - .1), (.022, h - .06), (.016, h - .04), (.016, h)], mat, seg=8)
    beam("int", a + up * rail_h, b + up * rail_h, .075, .07, "rail")
    beam("int", a + up * .03, b + up * .03, .06, .05, "rail")
    for k, end in enumerate((a, b)):
        if newels[k]:
            newel(end, rail_h)
    if collide_:
        c = (a + b) / 2 + up * .55
        z = d.normalized()
        x = up.cross(z).normalized()
        y = z.cross(x)
        collide(c, (.1, 1.1, L), "wood", Matrix((x, y, z)).transposed(), "balustrade")


def newel(p, rail_h):
    p = Vector(p)
    box("int", p + Vector((0, 0, (rail_h + .12) / 2)), (.2, .2, rail_h + .12), "newel")
    for z, s in ((.05, .26), (rail_h + .14, .26), (rail_h + .18, .22)):
        box("int", p + Vector((0, 0, z)), (s, s, .05), "newel")
    lathe("int", p + Vector((0, 0, rail_h + .2)), [(.05, 0), (.08, .04), (.09, .08), (.07, .13), (.02, .16), (0, .16)], "newel", seg=12)


def staircase():
    # Central flight toward the back, half landing across the foyer, two return flights to the side galleries.
    flight(-1.4, 1.4, 4.0, 7.3, 0.0, 12, label="Grand stair")
    for x0, x1 in ((-4 + P / 2, -2.6), (2.6, 4 - P / 2)):
        flight(x0, x1, 7.3, 3.7, LANDING, 12, label="Return flight")
    # Landing: boards, a carpet run along its middle, a plaster soffit, fascia.
    box("int", (0, 8.35, LANDING - .125), (8 - P, 2.1, .25), "tread", skip="z")
    rect_face("int", -4 + P / 2, 7.3, 4 - P / 2, 9.4, LANDING - .25, "ceiling", up=False)
    face("int", [(-1.5, 7.31, LANDING + .003), (1.5, 7.31, LANDING + .003), (1.5, 9.1, LANDING + .003), (-1.5, 9.1, LANDING + .003)], "carpet", (0, 0, 1))
    collide((0, 8.35, LANDING - .125), (8 - P, 2.1, .25), "wood", label="Landing")
    # Stair bases: the central flight is solid underneath, the return flights are closed by panelling.
    for sx in (-1, 1):
        x = 1.4 * sx
        face("int", [(x, 3.95, 0), (x, 7.3, 0), (x, 7.3, LANDING - .25), (x, 3.95, .2)], "panel", (sx, 0, 0))
        beam("int", (x + .02 * sx, 3.9, .32), (x + .02 * sx, 7.3, LANDING + .15), .05, .26, "trim")
        xi = 2.6 * sx
        face("int", [(xi, 3.7, 0), (xi, 9.4, 0), (xi, 9.4, LANDING), (xi, 7.3, LANDING), (xi, 7.3, LANDING + .38), (xi, 3.7, F1 + .38)], "panel", (-sx, 0, 0))
        face("int", [(xi + .001 * sx, 3.7, F1), (xi + .001 * sx, 7.3, LANDING), (xi + .001 * sx, 7.3, LANDING + .38), (xi + .001 * sx, 3.7, F1 + .38)], "panel", (sx, 0, 0))
        beam("int", (xi - .02 * sx, 7.3, LANDING + .15), (xi - .02 * sx, 3.7, F1 + .15), .05, .26, "trim")
        face("int", [(xi, 3.7, 0), (4 * sx - P / 2 * sx, 3.7, 0), (4 * sx - P / 2 * sx, 3.7, C0), (xi, 3.7, C0)], "panel", (0, -1, 0))
        collide(((xi + 4 * sx) / 2, 6.55, 1.0), (1.32, 5.7, 2.0), "wood", label="Stair base")
        # Under-landing nooks between the flights stay open (headroom 1.95 m).
    # Solid under the central flight (stepped boxes kept below the ramp), so nobody slips beneath its high end.
    for k in range(5):
        ya = 4.0 + k * .66
        zt = ya / 1 * 0 + (ya - 3.85) / 3.45 * LANDING - .08
        if zt > .3:
            collide((0, ya + .33, zt / 2), (2.8, .66, zt), "wood", label="Flight base")
    # Balustrades.
    for sx in (-1, 1):
        x = 1.4 * sx
        balustrade((x, 3.95, stringer_z(3.95, 4.0, 7.3, 0, 12)), (x, 7.3, LANDING), sloped=True)
        balustrade((x, 7.3, LANDING), (2.6 * sx, 7.3, LANDING), newels=(False, True))
        xi = 2.6 * sx
        balustrade((xi, 7.3, LANDING), (xi, 3.7, F1), sloped=True, newels=(False, True))
        balustrade((xi, 3.7, F1), (xi, 2.4, F1), newels=(False, True))
    balustrade((-2.6, 2.4, F1), (2.6, 2.4, F1), newels=(False, False))
    LAYOUT["spots"]["stair_foot"] = godot(Vector((0, 3.3, 0)))
    LAYOUT["spots"]["landing"] = godot(Vector((0, 8.4, LANDING)))
    LAYOUT["spots"]["bridge"] = godot(Vector((0, 1.2, F1)))


# ------------------------------------------------------------------------------------------------ fireplaces, columns, pocket door
def fireplace(x_wall, y0, y1, z, z_top, sx=1):
    """Chimney breast on the wall at x_wall (room on the +x side when sx=1) with a marble surround and mantel."""
    xf = x_wall + .55 * sx
    yc = (y0 + y1) / 2
    for y, n in ((y0, (0, -1, 0)), (y1, (0, 1, 0))):
        face("int", [(x_wall, y, z), (xf, y, z), (xf, y, z_top), (x_wall, y, z_top)], "wp parlour" if z < 1 else "wp bedroom", n)
    face("int", [(xf, y0, z), (xf, y1, z), (xf, y1, z_top), (xf, y0, z_top)], "wp parlour" if z < 1 else "wp bedroom", (sx, 0, 0))
    collide(((x_wall + xf) / 2, yc, (z + z_top) / 2), (.55, y1 - y0, z_top - z), "plaster", label="Chimney breast")
    # Firebox: a sooty recess.
    fw, fh = .76, .82
    for pts, n in (([(xf, yc - fw / 2, z), (xf - .4 * sx, yc - fw / 2, z), (xf - .4 * sx, yc - fw / 2, z + fh), (xf, yc - fw / 2, z + fh)], (0, 1, 0)),
                   ([(xf, yc + fw / 2, z), (xf - .4 * sx, yc + fw / 2, z), (xf - .4 * sx, yc + fw / 2, z + fh), (xf, yc + fw / 2, z + fh)], (0, -1, 0)),
                   ([(xf - .4 * sx, yc - fw / 2, z), (xf - .4 * sx, yc + fw / 2, z), (xf - .4 * sx, yc + fw / 2, z + fh), (xf - .4 * sx, yc - fw / 2, z + fh)], (sx, 0, 0)),
                   ([(xf, yc - fw / 2, z + fh), (xf - .4 * sx, yc - fw / 2, z + fh), (xf - .4 * sx, yc + fw / 2, z + fh), (xf, yc + fw / 2, z + fh)], (0, 0, -1)),
                   ([(xf, yc - fw / 2, z + .005), (xf - .4 * sx, yc - fw / 2, z + .005), (xf - .4 * sx, yc + fw / 2, z + .005), (xf, yc + fw / 2, z + .005)], (0, 0, 1))):
        face("int", pts, "soot", n)
    # Marble surround in three pieces round the opening, then the mantel shelf on consoles.
    mx = xf + .03 * sx
    box("int", (mx, yc - fw / 2 - .19, z + .62), (.06, .38, 1.24), "marble fire")
    box("int", (mx, yc + fw / 2 + .19, z + .62), (.06, .38, 1.24), "marble fire")
    box("int", (mx, yc, z + fh + .21), (.06, fw, .42), "marble fire")
    box("int", (xf + .1 * sx, yc, z + 1.28), (.2, fw + 1.0, .06), "marble fire")
    run("int", (xf, yc - fw / 2 - .5, z + 1.31), (xf, yc + fw / 2 + .5, z + 1.31), (sx, 0, 0), [(0, 0), (.24, 0), (.26, .02), (.26, .05), (0, .05)], "marble fire")
    for yy in (yc - fw / 2 - .3, yc + fw / 2 + .3):
        box("int", (xf + .09 * sx, yy, z + 1.12), (.12, .1, .3), "marble fire")
    box("int", (xf + .3 * sx, yc, z + .015), (.6, fw + .9, .03), "marble fire")
    collide((xf + .1 * sx, yc, z + .65), (.2, fw + 1.0, 1.3), "plaster", label="Mantel")
    return Vector((xf + .1 * sx, yc, z + 1.34))


def columned_opening():
    """Parlour <-> foyer: half-wall pedestals at the jambs carrying square panelled columns under an entablature
    (the owner's 3rd reference)."""
    x = -4
    for y0, y1 in ((T + .3, T + .3 + .5), (3.7 - .5, 3.7)):
        yc = (y0 + y1) / 2
        box("int", (x, yc, .5), (.34, y1 - y0, 1.0), "trim")
        box("int", (x, yc, 1.03), (.42, y1 - y0 + .06, .06), "trim")
        box("int", (x, yc, .06), (.4, y1 - y0 + .04, .12), "trim")
        collide((x, yc, .5), (.34, y1 - y0, 1.0), "wood", label="Pedestal")
        # Column: base block, shaft with recessed panels, capital.
        box("int", (x, yc, 1.12), (.32, .32, .12), "trim")
        box("int", (x, yc, 2.0), (.26, .26, 1.66), "trim")
        for sx, sy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            box("int", (x + sx * .132, yc + sy * .132, 2.0), (.01 if sx else .17, .17 if sx else .01, 1.4), "panel")
        for z, s in ((2.86, .32), (2.92, .36)):
            box("int", (x, yc, z), (s, s, .06), "trim")
        collide((x, yc, 2.0), (.3, .3, 2.0), "wood", label="Column")
    # Entablature across the opening (both faces), with dentils.
    box("int", (x, 2.15, 3.05), (.36, 3.15, .2), "trim")
    for sx in (-1, 1):
        run("int", (x + sx * .18, T + .55, 3.15), (x + sx * .18, 3.75, 3.15), (sx, 0, 0), [(0, 0), (.04, 0), (.06, .03), (.06, .08), (0, .08)], "trim")
        y = T + .65
        while y < 3.65:
            box("int", (x + sx * .2, y, 3.1), (.04, .05, .06), "trim")
            y += .1


def pocket_door():
    """Dining room: one pocket door left half drawn across the opening, the other gone."""
    box("int", (4, 1.65, 1.425), (.05, .95, 2.85), "door wood")
    for z in (.25, 1.45, 2.65):
        box("int", (4, 1.65, z), (.07, .95, .08), "door wood")
    for zc, hh in ((.85, 1.0), (2.05, 1.0)):
        box("int", (4, 1.65, zc), (.06, .7, hh), "panel")
    collide((4, 1.65, 1.425), (.06, .95, 2.85), "wood", label="Pocket door")
