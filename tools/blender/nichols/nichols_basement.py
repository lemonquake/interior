"""The Nichols basement (0.22): a cellar door under the grand stair's landing, a stair shaft through the closet behind
the foyer, a 1906 fieldstone cellar under the rear hall and library, and, through a hole broken in its east wall, an
old wartime tunnel under the house (Davao still has the tunnels of the Japanese occupation). The owner's 3rd reference
set its mood (pipes along the walls, vents, chains from the ceiling, a dark door at the end); the owner asked for our
own take on it, so it is a barrel-vaulted concrete tunnel shored with timber where the cellar broke into it, with a
row of dog cages where the reference had lockers, and its rusted iron door chained shut with one new padlock.

House space as in nichols_geo (Blender: X east, Y depth from the front facade, Z up from the ground-floor boards).
Everything below the boards goes into MESHES["base"] (house_base.glb, its own visual layer in Godot: no moonlight
reaches it). The cellar door is a separate leaf (house_leaf_cellar.glb). LAYOUT["basement"] carries the door hinge,
the light switch, the bulbs, the blood trail, rooms and spots for nichols_property.gd.
"""
import math

from mathutils import Matrix, Vector

from nichols_geo import MESHES, LAYOUT, R, Mesh, godot, face, box, beam, cyl, lathe, collide, ramp, P

# ------------------------------------------------------------------------------------------------ dimensions
BF = -2.7          # cellar floor
CF = -3.6          # corridor floor
SY0, SY1 = 9.4, 11.0              # stair shaft between the foyer back wall and the hall north wall (partition centres)
SI0, SI1 = SY0 + P / 2, SY1 - P / 2   # shaft inner faces
SX0, SX1 = -4 + P / 2, 4 - P / 2  # shaft ends (parlour and dining walls)
TOP_X = 1.0        # top of the cellar stair (the landing behind the door runs from here to SX1)
RISERS = 14
RISE = -BF / RISERS
TREAD = .29
FOOT_X = TOP_X - (RISERS - 1) * TREAD   # where the last tread meets the shaft floor
DOOR_X, DOOR_W, DOOR_H = 1.95, .8, 1.78
# Cellar (inner faces) and its joists.
CX0, CX1, CY0, CY1 = -12.2, -.3, SY1 + P / 2, 19.2
JOIST_B = -.28     # underside of the ground-floor joists
GIRDER_Y = 15.1
# The hole in the east wall, the steps down and the corridor.
HOLE_Y0, HOLE_Y1, HOLE_TOP = 16.3, 17.4, -.8
EAST_T = .45       # east wall thickness (x -.3 .. .15)
PX1 = 1.5          # the passage's steps end where the corridor begins
KX0, KX1, KY0, KY1 = PX1, 12.3, 15.4, 18.2
K_WALL, K_RIDGE = -1.2, -.45   # wall tops and the crown of the vault
KY_MID = (KY0 + KY1) / 2
STEPS = 5                          # drops from the cellar floor to the corridor's
STEP_RISE = (BF - CF) / STEPS
STEP_RUN = (PX1 - (CX1 + EAST_T)) / (STEPS - 1)

B = "base"
UP = Vector((0, 0, 1))


def rect(mesh, x0, y0, x1, y1, z, mat, up=True):
    face(mesh, [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)], mat, (0, 0, 1 if up else -1))


def vrect(mesh, a, b, z0, z1, mat, n):
    """Vertical rectangle from a to b (xy points) between heights z0 and z1, facing n."""
    face(mesh, [(a[0], a[1], z0), (b[0], b[1], z0), (b[0], b[1], z1), (a[0], a[1], z1)], mat, n)


def wall(a, b, z0, z1, mat, n, holes=(), thick=.3, surface="stone", label="cellar wall", mesh=B, colliders=True):
    """A one-sided wall face from a to b facing n, with rectangular holes [(s0, s1, zb, zt)] (s along a->b), the
    holes' reveals `thick` deep, and colliders for the solid parts."""
    a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
    d = (b - a)
    L = d.length
    d.normalize()
    nv = Vector(n)
    cuts_s = sorted({0.0, L} | {h[0] for h in holes} | {h[1] for h in holes})
    cuts_z = sorted({z0, z1} | {h[2] for h in holes} | {h[3] for h in holes})
    rot = Matrix((d, UP.cross(d), UP)).transposed()   # right-handed; the box is symmetric across the face
    for i in range(len(cuts_s) - 1):
        s0, s1 = cuts_s[i], cuts_s[i + 1]
        for k in range(len(cuts_z) - 1):
            za, zb = cuts_z[k], cuts_z[k + 1]
            sm, zm = (s0 + s1) / 2, (za + zb) / 2
            if any(h[0] <= sm <= h[1] and h[2] <= zm <= h[3] for h in holes):
                continue
            vrect(mesh, a + d * s0, a + d * s1, za, zb, mat, n)
            if colliders:
                c = a + d * sm - nv * (thick / 2)
                collide((c.x, c.y, zm), (s1 - s0, thick, zb - za), surface, rot, label)
    for s0, s1, zb, zt in holes:
        p0, p1 = a + d * s0, a + d * s1
        back = -nv * thick
        vrect(mesh, p0, p0 + back, zb, zt, mat, d)
        vrect(mesh, p1, p1 + back, zb, zt, mat, -d)
        if zt < z1 - 1e-3:
            face(mesh, [(p0.x, p0.y, zt), (p1.x, p1.y, zt), ((p1 + back).x, (p1 + back).y, zt), ((p0 + back).x, (p0 + back).y, zt)], mat, (0, 0, -1))
        if zb > z0 + 1e-3:
            face(mesh, [(p0.x, p0.y, zb), (p1.x, p1.y, zb), ((p1 + back).x, (p1 + back).y, zb), ((p0 + back).x, (p0 + back).y, zb)], mat, (0, 0, 1))


def cuboid(c, size, mat, rot=None, surface=None, label="", mesh=B, skip=()):
    box(mesh, c, size, mat, rot, skip=skip)
    if surface:
        collide(c, size, surface, rot, label)


# ------------------------------------------------------------------------------------------------ the cellar door
def cellar_leaf():
    """Ledged and braced plank door, hinge at the origin, leaf along -X: three straps of iron, a thumb latch."""
    m = "leaf_cellar"
    MESHES[m] = Mesh(m)
    w, h, t = DOOR_W - .02, DOOR_H - .01, .04
    x = -w / 2
    n = 6
    for i in range(n):
        bw = w / n
        cx = -bw * (i + .5)
        jitter = R.uniform(-.01, .01)
        box(m, (cx, 0, h / 2 + jitter), (bw - .006, t, h - abs(jitter) * 2), "cellar door")
    for z in (.22, h / 2, h - .22):
        box(m, (x, -t / 2 - .012, z), (w - .06, .024, .13), "cellar door")
    # Diagonal braces between the ledges (on the shaft side).
    for z0, z1 in ((.3, h / 2 - .06), (h / 2 + .06, h - .3)):
        a = Vector((-.05, -t / 2 - .012, z0))
        b = Vector((-w + .05, -t / 2 - .012, z1))
        beam(m, a, b, .11, .022, "cellar door", up=(0, 1, 0))
    for z in (.22, h - .22):
        for y in (t / 2 + .004, -t / 2 - .026):
            box(m, (-.22, y, z), (.44, .006, .045), "iron")
            cyl(m, (-.42, y, z), (-.42, y + (.008 if y > 0 else -.008), z), .02, "iron", seg=8)
    # Thumb latch and a ring pull.
    box(m, (-w + .1, t / 2 + .02, 1.02), (.03, .03, .16), "iron")
    lathe(m, (-w + .1, t / 2 + .035, .94), [(.045, 0), (.05, .006), (.045, .012), (.038, .012), (.042, .006), (.038, 0)], "iron", seg=10,
          rot=Matrix.Rotation(math.pi / 2, 3, "X"))
    box(m, (-w + .1, -t / 2 - .02, 1.02), (.03, .03, .1), "iron")


def door_and_shaft_layout():
    hinge = Vector((DOOR_X + DOOR_W / 2, SY0, 0))
    latch = Vector((DOOR_X - DOOR_W / 2, SY0, 0))
    return {"hinge": godot(hinge), "latch": godot(latch), "swing": godot(Vector((0, 1, 0))), "height": DOOR_H - .01,
            "width": DOOR_W - .02, "angle": 48, "label": "Cellar door"}


# ------------------------------------------------------------------------------------------------ stair shaft
def shaft():
    # Landing behind the door: boards on joists, an oak nosing over the first step.
    rect("int", TOP_X, SI0, SX1, SI1, 0, "floor b")
    box(B, ((TOP_X + SX1) / 2, (SI0 + SI1) / 2, -.12), (SX1 - TOP_X, SI1 - SI0, .22), "joist", skip="Z")
    collide(((TOP_X + SX1) / 2, (SY0 + SY1) / 2, -.2), (SX1 - TOP_X, SY1 - SY0, .4), "wood", label="Cellar landing")
    box("int", (TOP_X + .02, (SI0 + SI1) / 2, -.02), (.06, SI1 - SI0, .045), "tread")
    for x in (TOP_X + .4, (TOP_X + SX1) / 2 + .3, SX1 - .15):
        cuboid((x, SI0 + .1, BF / 2 - .12), (.12, .12, -BF - .24), "post", label="Landing post")
        cuboid((x, SI1 - .1, BF / 2 - .12), (.12, .12, -BF - .24), "post", label="Landing post")
    # The stair: open risers on two stringers, treads worn hollow in the middle.
    y0, y1 = SI0 + .02, SI1 - .02
    for k in range(RISERS - 1):
        z = -(k + 1) * RISE
        xa = TOP_X - (k + 1) * TREAD
        xb = xa + TREAD + .03
        sag = R.uniform(-.008, .004)
        box(B, ((xa + xb) / 2, (y0 + y1) / 2, z - .02 + sag), (xb - xa, y1 - y0 - .1, .04), "stair")
        # Riser cleats under each tread.
        for y in (y0 + .1, y1 - .1):
            box(B, ((xa + xb) / 2, y, z - .07), (xb - xa - .04, .05, .06), "stair")
    for y in (y0 + .03, y1 - .03):
        a = Vector((TOP_X + .05, y, .0))
        b = Vector((FOOT_X - .1, y, BF + .04))
        beam(B, a + Vector((0, 0, -.17)), b + Vector((0, 0, -.17)), .05, .3, "stair", up=(0, 1, 0))
    ramp(Vector((FOOT_X - .16, (SY0 + SY1) / 2, BF)), Vector((TOP_X, (SY0 + SY1) / 2, 0.0)), SI1 - SI0, "wood", "Cellar stair")
    # Handrails: a round rail on iron brackets along both walls.
    for y, side in ((SI0 + .07, 1), (SI1 - .07, -1)):
        a = Vector((TOP_X + .3, y, .9))
        b = Vector((FOOT_X - .2, y, BF + .9))
        cyl(B, a, b, .025, "rail wood", seg=8)
        for t in (.08, .5, .92):
            p = a.lerp(b, t)
            cyl(B, p - Vector((0, 0, .02)), p - Vector((0, 0, .1)), .008, "iron", seg=5)
            cyl(B, p - Vector((0, 0, .1)), Vector((p.x, y - side * .07, p.z - .1)), .008, "iron", seg=5)
    # Shaft floor and the walls below the boards: old brick under flaking whitewash.
    rect(B, SX0, SI0, SX1, SI1, BF, "cellar floor")
    collide((0, (SY0 + SY1) / 2, BF - .2), (SX1 - SX0, SY1 - SY0, .4), "concrete", label="Shaft floor")
    wall((SX0, SI0), (SX1, SI0), BF, 0, "cellar plaster", (0, 1, 0), surface="concrete", label="Shaft wall")
    wall((SX1, SI1), (SX0, SI1), BF, 0, "cellar plaster", (0, -1, 0), surface="concrete", label="Shaft wall",
         holes=[(SX1 - (-2.85), SX1 - (-3.85), BF, -.62)], thick=P)
    wall((SX0, SI1), (SX0, SI0), BF, 0, "cellar plaster", (1, 0, 0), surface="concrete", label="Shaft wall")
    wall((SX1, SI0), (SX1, SI1), BF, 0, "cellar plaster", (-1, 0, 0), surface="concrete", label="Shaft wall")
    # The opening at the foot: a rough timber lintel.
    box(B, (-3.35, SI1 - .02, -.55), (1.2, .2, .14), "post")
    # Above the boards the shaft is the old closet: the stair's open side gets a skirting board.
    beam("int", (TOP_X, SI0 + .01, .06), (SX0, SI0 + .01, .06), .02, .12, "trim", up=(0, 1, 0))


# ------------------------------------------------------------------------------------------------ cellar
def cellar():
    rect(B, CX0, CY0, CX1, CY1, BF, "cellar floor")
    collide(((CX0 + CX1) / 2, (CY0 + CY1) / 2, BF - .2), (CX1 - CX0, CY1 - CY0, .4), "concrete", label="Cellar floor")
    # A floor drain by the butcher's block, its grate rusted.
    drain = Vector((-6.2, 17.6, BF))
    box(B, drain + Vector((0, 0, .002)), (.36, .36, .004), "iron dark")
    for k in range(5):
        box(B, drain + Vector((-.14 + k * .07, 0, .006)), (.02, .32, .006), "iron")
    # Walls: fieldstone, the north one shared with the shaft round its opening.
    wall((CX0, CY0), (CX0, CY1), BF, 0, "cellar stone", (1, 0, 0), thick=.45)
    wall((CX0, CY1), (CX1, CY1), BF, 0, "cellar stone", (0, -1, 0), thick=.45)
    wall((CX1, CY1), (CX1, CY0), BF, 0, "cellar stone", (-1, 0, 0), thick=EAST_T,
         holes=[(CY1 - HOLE_Y1, CY1 - HOLE_Y0, BF, HOLE_TOP)])
    wall((CX1, CY0), (SX0, CY0), BF, 0, "cellar plaster", (0, 1, 0), thick=P,
         holes=[((CX1) - (-2.85), (CX1) - (-3.85), BF, -.62)])
    wall((SX0, CY0), (CX0, CY0), BF, 0, "cellar stone", (0, 1, 0), thick=.45)
    # A plinth of mortar along the foot of the stone walls, the stone darker where it is damp.
    for a, b, n in (((CX0, CY0), (CX0, CY1), (1, 0, 0)), ((CX0, CY1), (CX1, CY1), (0, -1, 0))):
        pa, pb = Vector((a[0], a[1], BF)), Vector((b[0], b[1], BF))
        nv = Vector(n)
        beam(B, pa + nv * .04 + UP * .06, pb + nv * .04 + UP * .06, .1, .12, "cellar plaster", up=n)
    # The hole: stones broken out round it and lying on the floor.
    for i in range(26):
        y = R.uniform(HOLE_Y0 - .25, HOLE_Y1 + .25)
        z = R.uniform(BF, HOLE_TOP + .2)
        if HOLE_Y0 + .05 < y < HOLE_Y1 - .05 and z < HOLE_TOP - .05:
            continue
        s = R.uniform(.1, .26)
        rot = Matrix.Rotation(R.uniform(-.4, .4), 3, "X") @ Matrix.Rotation(R.uniform(-.5, .5), 3, "Z")
        box(B, (CX1 + R.uniform(-.06, .02), y, z), (s * .8, s, s * .6), "cellar stone", rot)
    for i in range(18):
        s = R.uniform(.06, .22)
        p = Vector((CX1 - R.uniform(.1, 1.3), R.uniform(HOLE_Y0 - .6, HOLE_Y1 + .6), BF + s * .25))
        box(B, p, (s, s * .8, s * .5), "cellar stone", Matrix.Rotation(R.uniform(0, 3), 3, "Z") @ Matrix.Rotation(R.uniform(-.3, .3), 3, "X"))
    # Ceiling: the underside of the ground-floor boards on joists, a girder on four posts.
    rect(B, CX0, CY0, CX1, CY1, -.035, "subfloor", up=False)
    x = CX0 + .2
    while x < CX1:
        box(B, (x, (CY0 + CY1) / 2, (JOIST_B - .035) / 2), (.07, CY1 - CY0, -JOIST_B - .035), "joist", skip="Z")
        x += .41
    box(B, ((CX0 + CX1) / 2, GIRDER_Y, JOIST_B - .14), (CX1 - CX0, .24, .28), "post", skip="Z")
    for px in (-9.4, -6.2, -3.0):
        cuboid((px, GIRDER_Y, (BF + JOIST_B - .28) / 2), (.18, .18, JOIST_B - .28 - BF), "post", surface="wood", label="Cellar post")
        box(B, (px, GIRDER_Y, BF + .04), (.3, .3, .08), "cellar plaster")
    # Bridging between joists and an old knob-and-tube run along the girder.
    for x in [CX0 + .4 + k * 1.64 for k in range(7)]:
        cyl(B, (x, GIRDER_Y - .6, JOIST_B - .03), (x + .5, GIRDER_Y - .6, JOIST_B - .03), .006, "cord", seg=5)
    # Coal bin in the north-west corner: slatted boards, coal heaped inside.
    bx0, bx1, by0, by1 = CX0, CX0 + 2.1, CY0, CY0 + 1.6
    for z in (BF + .1, BF + .32, BF + .54, BF + .76):
        box(B, ((bx0 + bx1) / 2, by1, z), (bx1 - bx0, .03, .18), "board")
        box(B, (bx1, (by0 + by1) / 2, z), (.03, by1 - by0, .18), "board")
    for p in ((bx1, by1), (bx1, by0 + .05), (bx0 + .05, by1)):
        box(B, (p[0], p[1], BF + .45), (.08, .08, .9), "post")
    collide(((bx0 + bx1) / 2, (by0 + by1) / 2, BF + .45), (bx1 - bx0, by1 - by0, .9), "wood", label="Coal bin")
    for i in range(70):
        s = R.uniform(.05, .13)
        p = Vector((R.uniform(bx0 + .1, bx1 - .1), R.uniform(by0 + .1, by1 - .1), 0))
        h = .55 * max(0, 1 - ((p.x - bx0) / (bx1 - bx0) * .8 + (p.y - by0) / (by1 - by0) * .6)) + .05
        box(B, (p.x, p.y, BF + R.uniform(0, h)), (s, s * .8, s * .7), "coal", Matrix.Rotation(R.uniform(0, 3), 3, "Z") @ Matrix.Rotation(R.uniform(-1, 1), 3, "X"))
    workbench()
    preserve_shelves()
    butcher_corner()
    moved_shelf()


def workbench():
    """Against the south wall: a heavy bench, a pegboard of tools above it (outlines painted where tools are missing)."""
    x0, x1 = -4.6, -2.0
    y = CY1 - .38
    top = BF + .88
    box(B, ((x0 + x1) / 2, y, top - .03), (x1 - x0, .7, .06), "bench top")
    for xx in (x0 + .06, x1 - .06):
        for yy in (y - .3, y + .3):
            box(B, (xx, yy, (BF + top - .06) / 2), (.08, .08, top - .06 - BF), "post")
    box(B, ((x0 + x1) / 2, y, BF + .2), (x1 - x0 - .1, .62, .03), "board")
    collide(((x0 + x1) / 2, y, (BF + top) / 2), (x1 - x0, .7, top - BF), "wood", label="Workbench")
    board_y = CY1 - .02
    box(B, ((x0 + x1) / 2, board_y, top + .75), (x1 - x0 - .1, .02, 1.2), "pegboard")
    for i in range(9):
        cx = x0 + .25 + i * .27
        cz = top + .4 + R.uniform(0, .6)
        # Pale outlines where tools used to hang: some of them are gone.
        box(B, (cx, board_y - .012, cz), (.05, .002, R.uniform(.25, .45)), "outline")
        cyl(B, (cx, board_y - .01, cz + .25), (cx, board_y - .06, cz + .27), .005, "iron", seg=4)


def preserve_shelves():
    """Along the west wall: deep plank shelves of preserve jars, dusty, some gone dark and cloudy."""
    x = CX0 + .25
    for y0, y1 in ((13.0, 15.0), (15.9, 18.3)):
        for z in (BF + .35, BF + .85, BF + 1.35, BF + 1.85):
            box(B, (x, (y0 + y1) / 2, z), (.42, y1 - y0, .03), "board")
            yy = y0 + .08
            while yy < y1 - .08:
                if R.random() < .82:
                    r = R.uniform(.045, .07)
                    h = R.uniform(.14, .24)
                    c = Vector((x + R.uniform(-.1, .1), yy, z + .015))
                    lathe(B, c, [(r * .9, 0), (r, .01), (r, h * .78), (r * .7, h * .88), (r * .72, h), (0, h)], "jar", seg=10)
                    lathe(B, c + Vector((0, 0, .004)), [(r * .93, 0), (r * .93, h * R.uniform(.3, .75)), (0, h * .5)], R.choice(("jar dark", "jar red", "jar murk")), seg=8)
                    lathe(B, c + Vector((0, 0, h - .004)), [(r * .76, 0), (r * .76, .022), (0, .022)], "lid", seg=10)
                yy += R.uniform(.13, .19)
        for yy in (y0 + .03, y1 - .03):
            box(B, (x, yy, BF + 1.0), (.42, .05, 2.0), "board")
        collide((x, (y0 + y1) / 2, BF + 1.0), (.44, y1 - y0, 2.0), "wood", label="Preserve shelves")


def butcher_corner():
    """South-west: the drain, a chopping block, a rail of meat hooks between two joists, a tarp over something."""
    # Chopping block (a section of trunk) by the drain.
    c = Vector((-6.9, 17.9, BF))
    lathe(B, c, [(.3, 0), (.31, .05), (.29, .72), (.27, .76), (0, .77)], "block wood", seg=16)
    lathe(B, c + Vector((0, 0, .765)), [(.26, 0), (.24, .006), (0, .008)], "block top", seg=16)
    collide((c.x, c.y, BF + .38), (.56, .56, .76), "wood", label="Chopping block")
    # Hook rail: a pipe under the joists with S-hooks and two chains.
    a = Vector((-8.6, 18.4, JOIST_B - .12))
    b = Vector((-5.2, 18.4, JOIST_B - .12))
    cyl(B, a, b, .025, "pipe", seg=8)
    for p in (a, b):
        cyl(B, p, p + Vector((0, 0, .1)), .012, "iron", seg=5)
    for k in range(6):
        p = a.lerp(b, (k + .5) / 6)
        drop = R.uniform(.15, .45) if k % 2 == 0 else 0.0
        if drop:
            chain(B, p, p - Vector((0, 0, drop)))
        s_hook(B, p - Vector((0, 0, drop + .03)), 1 if k % 2 else -1)
    # A heavy tarp over something on the floor, tied with cord, dark at the bottom edge.
    tarp(Vector((-8.4, 17.3, BF)), 1.35, .75, .42)
    # A galvanised tub and two buckets under the drain's end of the bench.
    lathe(B, Vector((-5.6, 18.55, BF)), [(.3, 0), (.38, .38), (.4, .4), (.38, .4), (.36, .39), (.27, .02), (0, .02)], "tub", seg=18)
    collide((-5.6, 18.55, BF + .2), (.76, .76, .4), "metal", label="Tub")


def chain(mesh, a, b, link=.055, r=.006):
    a, b = Vector(a), Vector(b)
    d = b - a
    n = max(1, int(d.length / (link * .8)))
    z = d.normalized()
    for i in range(n):
        c = a + d * ((i + .5) / n)
        x = Vector((1, 0, 0)) if i % 2 else Vector((0, 1, 0))
        y = z.cross(x).normalized()
        rot = Matrix((x, y, z)).transposed()
        pts = [c + rot @ Vector((math.cos(t) * link * .32, 0, math.sin(t) * link * .5)) for t in (math.tau * k / 8 for k in range(9))]
        for k in range(8):
            cyl(mesh, pts[k], pts[k + 1], r, "chain", seg=4, caps=False)


def s_hook(mesh, top, side=1, size=.11, r=.007):
    """A butcher's S-hook hanging from `top`."""
    top = Vector(top)
    pts = []
    for k in range(9):
        t = math.pi * k / 8
        pts.append(top + Vector((side * math.sin(t) * size * .25, 0, -size * .25 + math.cos(t) * size * .25)))
    for k in range(13):
        t = math.pi * k / 12
        pts.append(top + Vector((-side * math.sin(t) * size * .35, 0, -size * .5 - size * .35 + math.cos(t) * size * .35)))
    pts.append(pts[-1] + Vector((side * .03, 0, .05)))
    for k in range(len(pts) - 1):
        cyl(mesh, pts[k], pts[k + 1], r, "chain", seg=5, caps=False)


def tarp(c, lx, ly, h):
    """A tarp thrown over a lump: a heightfield draped from the floor up over a rounded shape."""
    nx, ny = 14, 9
    pts = {}
    for i in range(nx + 1):
        for j in range(ny + 1):
            u, v = i / nx * 2 - 1, j / ny * 2 - 1
            x = c.x + u * (lx / 2 + .25)
            y = c.y + v * (ly / 2 + .22)
            core = max(0.0, 1 - (u * u * .8 + v * v))
            z = c.z + .01 + h * (core ** .6) * (1 + .12 * math.sin(u * 7) * math.cos(v * 5)) + R.uniform(0, .015)
            pts[i, j] = Vector((x, y, z))
    for i in range(nx):
        for j in range(ny):
            q = [pts[i, j], pts[i + 1, j], pts[i + 1, j + 1], pts[i, j + 1]]
            face(B, q, "tarp", (0, 0, 1), smooth=True)
    collide((c.x, c.y, c.z + h * .45), (lx * .8, ly * .7, h * .9), "carpet", label="Tarp")
    for u in (-.25, .3):
        x = c.x + u * lx
        cyl(B, (x, c.y - ly / 2 - .1, c.z + .05), (x, c.y, c.z + h + .01), .008, "cord", seg=4)
        cyl(B, (x, c.y, c.z + h + .01), (x, c.y + ly / 2 + .1, c.z + .05), .008, "cord", seg=4)


def moved_shelf():
    """The tall shelf that hid the hole, dragged a metre along the wall and left skewed."""
    c = Vector((CX1 - .55, HOLE_Y1 + 1.0, BF))
    rot = Matrix.Rotation(math.radians(-14), 3, "Z")
    w, d, h = 1.5, .45, 2.1

    def at(x, y, z):
        return c + rot @ Vector((x, y, z))
    for z in (.06, .55, 1.05, 1.55, 2.05):
        box(B, at(0, 0, z), (d, w, .04), "board", rot)
    for y in (-w / 2 + .02, w / 2 - .02):
        box(B, at(0, y, h / 2), (d, .04, h), "board", rot)
    box(B, at(d / 2 - .01, 0, h / 2), (.015, w, h), "board", rot)
    collide(at(0, 0, h / 2), (d, w, h), "wood", rot, "Moved shelf")
    # A few things left on it: jars, a tin, rags.
    for z in (.57, 1.07, 1.57):
        for k in range(3):
            if R.random() < .6:
                p = at(R.uniform(-.1, .1), R.uniform(-.6, .6), z + .02)
                lathe(B, p, [(.05, 0), (.055, .01), (.055, .17), (.04, .19), (0, .19)], "jar", seg=10)
                lathe(B, p + Vector((0, 0, .004)), [(.05, 0), (.05, .09), (0, .06)], "jar murk", seg=8)


# ------------------------------------------------------------------------------------------------ passage and corridor
def passage():
    x0 = CX1 + EAST_T
    # Concrete steps down from the hole, a little narrower than it.
    for k in range(STEPS - 1):
        top = BF - (k + 1) * STEP_RISE
        xa = x0 + k * STEP_RUN
        box(B, (xa + STEP_RUN / 2, (HOLE_Y0 + HOLE_Y1) / 2, (top + CF) / 2), (STEP_RUN, HOLE_Y1 - HOLE_Y0, top - CF), "step concrete")
        # A worn nosing of darker concrete.
        box(B, (xa + .03, (HOLE_Y0 + HOLE_Y1) / 2, top - .02), (.06, HOLE_Y1 - HOLE_Y0 - .02, .045), "corridor floor")
    rect(B, CX1, HOLE_Y0, x0, HOLE_Y1, BF, "cellar floor")
    ramp(Vector((x0 - .02, (HOLE_Y0 + HOLE_Y1) / 2, BF)), Vector((PX1 + .12, (HOLE_Y0 + HOLE_Y1) / 2, CF)), HOLE_Y1 - HOLE_Y0, "concrete", "Corridor steps")
    collide(((CX1 + x0) / 2, (HOLE_Y0 + HOLE_Y1) / 2, BF - .2), (x0 - CX1, HOLE_Y1 - HOLE_Y0, .4), "concrete", label="Hole sill")
    # Side walls and ceiling stop where the corridor wall's own reveal begins (.3 m before the corridor).
    for a, b_, n in (((x0, HOLE_Y0), (PX1 - .3, HOLE_Y0), (0, 1, 0)), ((PX1 - .3, HOLE_Y1), (x0, HOLE_Y1), (0, -1, 0))):
        wall(a, b_, CF, HOLE_TOP, "corridor wall", n, thick=.3, surface="concrete", label="Passage wall")
    face(B, [(x0, HOLE_Y0, HOLE_TOP), (PX1 - .3, HOLE_Y0, HOLE_TOP), (PX1 - .3, HOLE_Y1, HOLE_TOP), (x0, HOLE_Y1, HOLE_TOP)], "corridor ceiling", (0, 0, -1))
    collide(((x0 + PX1) / 2, (HOLE_Y0 + HOLE_Y1) / 2, HOLE_TOP + .2), (PX1 - x0, HOLE_Y1 - HOLE_Y0, .4), "concrete", label="Passage ceiling")


def corridor():
    rect(B, KX0, KY0, KX1, KY1, CF, "corridor floor")
    collide(((KX0 + KX1) / 2, KY_MID, CF - .2), (KX1 - KX0, KY1 - KY0, .4), "concrete", label="Corridor floor")
    wall((KX0, KY0), (KX1, KY0), CF, K_WALL, "corridor wall", (0, 1, 0), surface="concrete", label="Corridor wall")
    wall((KX1, KY1), (KX0, KY1), CF, K_WALL, "corridor wall", (0, -1, 0), surface="concrete", label="Corridor wall")
    wall((KX0, KY1), (KX0, KY0), CF, K_WALL, "corridor wall", (1, 0, 0), surface="concrete", label="Corridor wall",
         holes=[(KY1 - HOLE_Y1, KY1 - HOLE_Y0, CF, HOLE_TOP)])
    # The end wall with the steel door's opening.
    door_y0, door_y1, door_top = KY_MID - .52, KY_MID + .52, CF + 2.12
    wall((KX1, KY0), (KX1, KY1), CF, K_WALL, "corridor wall", (-1, 0, 0), surface="concrete", label="Corridor end wall",
         holes=[(door_y0 - KY0, door_y1 - KY0, CF, door_top)])
    # A barrel vault: end walls filled up to it, the vault in strips, a rib every 1.2 m.
    arch = [(KY0 + (KY1 - KY0) * (1 - math.cos(math.pi * k / 16)) / 2, K_WALL + (K_RIDGE - K_WALL) * math.sin(math.pi * k / 16)) for k in range(17)]
    for x, n in ((KX0, (1, 0, 0)), (KX1, (-1, 0, 0))):
        face(B, [(x, y, z) for y, z in arch], "corridor wall", n)
    for k in range(16):
        (ya, za), (yb, zb) = arch[k], arch[k + 1]
        inward = Vector((0, KY_MID - (ya + yb) / 2, -.35))
        face(B, [(KX0, ya, za), (KX1, ya, za), (KX1, yb, zb), (KX0, yb, zb)], "corridor ceiling", inward)
    collide(((KX0 + KX1) / 2, KY_MID, K_RIDGE + .2), (KX1 - KX0, KY1 - KY0, .4), "concrete", label="Corridor ceiling")
    x = KX0 + .6
    while x < KX1 - .3:
        for k in range(16):
            (ya, za), (yb, zb) = arch[k], arch[k + 1]
            inward = Vector((0, KY_MID - (ya + yb) / 2, -.35)).normalized()
            beam(B, Vector((x, ya, za)) + inward * .04, Vector((x, yb, zb)) + inward * .04, .16, .07, "corridor ceiling", up=(1, 0, 0))
        x += 1.2
    # Where the cellar broke through, the old tunnel mouth is propped with timber.
    for y in (HOLE_Y0 - .12, HOLE_Y1 + .12):
        box(B, (KX0 + .12, y, (CF + HOLE_TOP) / 2), (.16, .16, HOLE_TOP - CF), "post")
    box(B, (KX0 + .12, (HOLE_Y0 + HOLE_Y1) / 2, HOLE_TOP + .08), (.18, HOLE_Y1 - HOLE_Y0 + .5, .16), "post")
    # Skirting of grime: a darker band where water stood.
    for y, n in ((KY0 + .002, (0, 1, 0)), (KY1 - .002, (0, -1, 0))):
        vrect(B, (KX0, y), (KX1, y), CF, CF + .16, "wet band", n)
    pipes()
    vents()
    cages(8.5, KY0 + .02)
    steel_door(door_y0, door_y1, door_top)
    sink(Vector((8.35, KY1 - .26, CF)), -1)
    # Chains and meat hooks hanging from the ridge.
    for x, length, hook in ((3.6, 1.0, True), (5.9, 1.45, True), (7.4, .6, False), (10.6, .9, True)):
        y = KY_MID + R.uniform(-.25, .25)
        top = Vector((x, y, K_RIDGE))
        cyl(B, top, top + Vector((0, 0, .04)), .03, "iron", seg=6)
        chain(B, top, top - Vector((0, 0, length)))
        if hook:
            s_hook(B, top - Vector((0, 0, length + .03)), 1 if R.random() < .5 else -1, size=.16, r=.009)
    # Drain channel down the middle, a grate every few metres.
    for x in (4.0, 7.5, 11.0):
        box(B, (x, KY_MID, CF + .002), (.5, .3, .004), "iron dark")
        for k in range(6):
            box(B, (x - .2 + k * .08, KY_MID, CF + .006), (.025, .27, .006), "iron")


def pipes():
    """Two big rusted mains along the walls at hip height on brackets, a riser into the ceiling on each side, a
    thinner pipe and a yellow conduit higher up (as in the reference)."""
    for y, side in ((KY0 + .27, 1), (KY1 - .27, -1)):
        z = CF + 1.02
        end = 8.25 if side > 0 else KX1 - .05
        a, b = Vector((KX0 + .05, y, z)), Vector((end, y, z))
        cyl(B, a, b, .17, "pipe", seg=16)
        collide(((a.x + b.x) / 2, y, z), (b.x - a.x, .36, .36), "metal", label="Pipe")
        x = KX0 + .8
        while x < end - .3:
            cyl(B, (x - .04, y, z), (x + .04, y, z), .205, "pipe", seg=16)
            for k in range(8):
                t = math.tau * k / 8
                bolt = Vector((x, y + math.cos(t) * .19, z + math.sin(t) * .19))
                cyl(B, bolt - Vector((.055, 0, 0)), bolt + Vector((.055, 0, 0)), .012, "iron", seg=5)
            x += 2.6
        x = KX0 + 1.9
        while x < end - .3:
            # Bracket: a strap round the pipe and a leg into the wall.
            ring = [Vector((x, y + math.cos(t) * .185, z + math.sin(t) * .185)) for t in (math.pi * k / 8 for k in range(9))]
            for k in range(8):
                cyl(B, ring[k], ring[k + 1], .012, "iron", seg=4, caps=False)
            box(B, (x, y - side * .2, z), (.05, .14, .05), "iron")
            box(B, (x, y - side * .2, z - .2), (.05, .05, .4), "iron")
            box(B, (x, y - side * .26, z - .4), (.12, .02, .12), "iron")
            x += 2.6
        riser_x = end if side > 0 else 5.3
        if side > 0:
            # The north main turns up into the ceiling short of the lockers.
            lathe(B, (end, y, z - .17), [(.19, 0), (.19, .34), (0, .34)], "pipe", seg=16)
        cyl(B, (riser_x, y, z + .1), (riser_x, y, K_WALL - .05), .12, "pipe", seg=12)
        lathe(B, (riser_x, y, z), [(.19, 0), (.19, .12), (.15, .2), (.13, .26), (0, .26)], "pipe", seg=12)
        cyl(B, (riser_x, y, K_WALL - .05), (riser_x, y + side * .55, K_WALL + .32), .12, "pipe", seg=12)
        # Valve wheel on the riser.
        vz = z + .6
        lathe(B, (riser_x, y + side * .14, vz), [(.12, -.01), (.125, 0), (.12, .01)], "valve", seg=14, rot=Matrix.Rotation(math.pi / 2, 3, "X"))
        cyl(B, (riser_x, y, vz), (riser_x, y + side * .14, vz), .02, "iron", seg=6)
    # Thin pipe and conduit.
    cyl(B, (KX0 + .05, KY1 - .12, K_WALL - .32), (KX1 - .05, KY1 - .12, K_WALL - .32), .045, "pipe", seg=10)
    cyl(B, (KX0 + .05, KY0 + .03, CF + 1.72), (KX1 - .05, KY0 + .03, CF + 1.72), .012, "conduit", seg=6)
    cyl(B, (KX0 + .05, KY1 - .03, CF + 1.62), (KX1 - .05, KY1 - .03, CF + 1.62), .012, "conduit", seg=6)
    # The conduit drops to a junction box by the door and to each lamp.
    box(B, (KX1 - .45, KY0 + .05, CF + 1.72), (.18, .07, .24), "iron dark")


def vents():
    """Louvred grilles high on both walls, flush with the concrete, dark behind the slats."""
    for x in (3.2, 6.6, 10.0):
        for y, n in ((KY0, 1), (KY1, -1)):
            zc = K_WALL - .3
            w, h = .78, .34
            box(B, (x, y + n * .003, zc), (w, .004, h), "iron dark")
            for xx in (x - w / 2, x + w / 2):
                box(B, (xx, y + n * .02, zc), (.04, .04, h + .04), "door frame")
            for zz in (zc - h / 2, zc + h / 2):
                box(B, (x, y + n * .02, zz), (w + .04, .04, .04), "door frame")
            for xx in (x - w / 6, x + w / 6):
                box(B, (xx, y + n * .03, zc), (.015, .02, h), "door frame")
            for k in range(8):
                zz = zc - h / 2 + .04 + k * .038
                if not (x == 6.6 and n < 0 and k in (2, 3)):   # two slats broken out of one grille
                    box(B, (x, y + n * .024, zz), (w - .03, .003, .022), "door frame", Matrix.Rotation(math.radians(40 * n), 3, "X"))


def cage(c, w, d, h, door_open=0.0, bars=.055):
    """A welded dog cage: angle-iron frame, round bars, a sheet tray, a hinged front door (`door_open` degrees)."""
    x0, x1, y0, y1, z0, z1 = c.x - w / 2, c.x + w / 2, c.y, c.y + d, c.z, c.z + h
    for a, b in (((x0, y0, z0), (x1, y0, z0)), ((x0, y1, z0), (x1, y1, z0)), ((x0, y0, z1), (x1, y0, z1)), ((x0, y1, z1), (x1, y1, z1)),
                 ((x0, y0, z0), (x0, y1, z0)), ((x1, y0, z0), (x1, y1, z0)), ((x0, y0, z1), (x0, y1, z1)), ((x1, y0, z1), (x1, y1, z1)),
                 ((x0, y0, z0), (x0, y0, z1)), ((x1, y0, z0), (x1, y0, z1)), ((x0, y1, z0), (x0, y1, z1)), ((x1, y1, z0), (x1, y1, z1))):
        beam(B, a, b, .022, .022, "cage iron")
    box(B, (c.x, (y0 + y1) / 2, z0 + .012), (w - .03, d - .03, .012), "iron dark")
    # Back, top and sides.
    x = x0 + bars
    while x < x1 - bars / 2:
        cyl(B, (x, y0 + .01, z0), (x, y0 + .01, z1), .005, "cage iron", seg=4, caps=False)
        cyl(B, (x, y0, z1 - .005), (x, y1, z1 - .005), .005, "cage iron", seg=4, caps=False)
        x += bars
    for xs in (x0, x1):
        y = y0 + bars
        while y < y1 - bars / 2:
            cyl(B, (xs, y, z0), (xs, y, z1), .005, "cage iron", seg=4, caps=False)
            y += bars
    # The door: its own frame and bars, swung open about its left edge.
    hinge = Vector((x0 + .03, y1, 0))
    rot = Matrix.Rotation(math.radians(door_open), 3, "Z")
    dw = w - .06

    def at(u, z):
        return hinge + rot @ Vector((u, 0, 0)) + Vector((0, 0, z))
    for a, b in ((at(0, z0 + .03), at(dw, z0 + .03)), (at(0, z1 - .03), at(dw, z1 - .03)), (at(0, z0 + .03), at(0, z1 - .03)), (at(dw, z0 + .03), at(dw, z1 - .03))):
        beam(B, a, b, .018, .018, "cage iron")
    u = bars
    while u < dw - bars / 2:
        cyl(B, at(u, z0 + .03), at(u, z1 - .03), .005, "cage iron", seg=4, caps=False)
        u += bars
    collide((c.x, (y0 + y1) / 2, (z0 + z1) / 2), (w, d, h), "metal", label="Dog cage")


def cages(x0, y_wall):
    """A row of dog cages along the north wall, two high: whoever drags animals down here keeps some alive first.
    Two doors hang open; a collar lies in an empty cage; dented bowls."""
    w, d, h = .92, .66, .66
    for i, row, door in ((0, 0, 0.0), (1, 0, 70.0), (2, 0, 0.0), (0, 1, 0.0), (1, 1, 0.0), (2, 1, 105.0)):
        cage(Vector((x0 + w / 2 + i * (w + .04), y_wall, CF + row * (h + .03))), w, d, h, door)
    for x, y in ((x0 + .3, y_wall + .45), (x0 + 1.55, y_wall + .2), (x0 + 2.4, y_wall + .5)):
        lathe(B, (x, y, CF + .025), [(.07, 0), (.1, .06), (.11, .065), (.1, .066), (.07, .01), (0, .01)], "tub", seg=14)
    lathe(B, (x0 + .5 * w + .1, y_wall + .3, CF + .03), [(.09, 0), (.095, .012), (.09, .024), (.084, .024), (.088, .012), (.084, 0)], "collar", seg=18)
    box(B, (x0 + .5 * w + .19, y_wall + .3, CF + .04), (.03, .015, .03), "iron")


def steel_door(y0, y1, top):
    """A black steel door in a heavier frame, rivets round the edge, a slot hatch at eye height (shut)."""
    x = KX1 - .02
    rot = Matrix((Vector((0, 1, 0)), Vector((-1, 0, 0)), UP)).transposed()
    for y in (y0 - .06, y1 + .06):
        box(B, (x - .02, y, (CF + top + .06) / 2), (.1, .12, top + .06 - CF), "door frame")
    box(B, (x - .02, (y0 + y1) / 2, top + .03), (.1, y1 - y0 + .24, .12), "door frame")
    yc = (y0 + y1) / 2
    box(B, (x + .02, yc, (CF + top) / 2), (.05, y1 - y0, top - CF), "steel door")
    for k in range(10):
        for y in (y0 + .06, y1 - .06):
            z = CF + .12 + k * (top - CF - .24) / 9
            lathe(B, (x - .006, y, z), [(.012, 0), (.01, .006), (0, .008)], "steel door", seg=6, rot=Matrix.Rotation(-math.pi / 2, 3, "Y"))
    for z in (CF + .45, top - .45):
        box(B, (x - .006, yc, z), (.012, y1 - y0 - .1, .07), "steel door")
    box(B, (x - .012, yc, CF + 1.55), (.02, .32, .1), "door frame")
    box(B, (x - .03, y0 + .14, CF + 1.0), (.04, .04, .2), "iron")
    box(B, (x - .06, y0 + .14, CF + 1.0), (.04, .14, .03), "iron")
    collide((x + .02, yc, (CF + top) / 2), (.08, y1 - y0, top - CF), "metal", label="Steel door")
    # Chained shut through a staple on the frame and the door's handle; the padlock is the only new thing down here.
    staple = Vector((x - .07, y0 - .1, CF + 1.0))
    handle = Vector((x - .07, y0 + .14, CF + 1.0))
    box(B, staple, (.05, .03, .12), "iron")
    chain(B, staple + Vector((0, 0, .02)), handle + Vector((-.03, 0, -.06)), link=.06, r=.007)
    chain(B, handle + Vector((-.03, 0, -.06)), handle + Vector((-.05, .05, -.32)), link=.06, r=.007)
    lock = handle + Vector((-.06, .06, -.43))
    box(B, lock, (.03, .065, .075), "padlock")
    ring = [lock + Vector((0, math.cos(t) * .022, .04 + math.sin(t) * .03)) for t in (math.pi * k / 8 for k in range(9))]
    for k in range(8):
        cyl(B, ring[k], ring[k + 1], .004, "padlock", seg=5, caps=False)


def sink(c, fy):
    """A small enamel wall sink on a pipe leg near the end (left in the reference), its basin stained, under the main."""
    w, d = .55, .42
    z = CF + .74
    yc = c.y + fy * (d / 2 - .02)
    box(B, (c.x, yc, z), (w, d, .16), "enamel", skip="Z")
    box(B, (c.x, yc, z + .07), (w - .08, d - .08, .02), "enamel stain")
    cyl(B, (c.x, c.y + fy * .18, z - .08), (c.x, c.y + fy * .18, CF), .03, "pipe", seg=8)
    cyl(B, (c.x, c.y - fy * .02, z + .1), (c.x, c.y - fy * .02, z + .3), .015, "iron", seg=6)
    cyl(B, (c.x, c.y - fy * .02, z + .3), (c.x, c.y + fy * .12, z + .3), .015, "iron", seg=6)
    collide((c.x, yc, z), (w, d, .2), "metal", label="Sink")



# ------------------------------------------------------------------------------------------------ kitchen
KI = "int"


def kitchen():
    """The kitchen (x 4..12.7, y 13.4..19.7): someone has been using it. An enamel farmhouse sink with drainboards on a
    painted cabinet under the (raised) south window, an enamel range beside it, a rounded refrigerator against the east
    wall left open with its light on, open shelves of jars and a utensil rail on the west wall, a scarred work table.
    The owner's 4th reference set the mood; the dressing is ours."""
    # Sink cabinet with sliding doors, the enamel top with a deep basin between two ribbed drainboards, a backsplash.
    x0, x1, y0, y1 = 5.5, 7.5, 19.04, 19.7
    top = .9
    box(KI, ((x0 + x1) / 2, (y0 + y1) / 2, (top - .1) / 2 + .05), (x1 - x0, y1 - y0, top - .1 - .05), "cab paint")
    box(KI, ((x0 + x1) / 2, y0 + .04, .03), (x1 - x0 - .04, .02, .06), "soot")
    for k, xx in enumerate((x0 + .5, x0 + 1.0, x0 + 1.5)):
        box(KI, (xx, y0 - .012, .45), (.48, .02, .68), "cab paint")
        box(KI, (xx + (.16 if k % 2 == 0 else -.16), y0 - .025, .5), (.03, .01, .1), "iron dark")
    basin_x0, basin_x1, basin_y0, basin_y1 = 6.1, 6.9, 19.12, 19.6
    bz = top - .24
    for a, b in ((x0, basin_x0), (basin_x1, x1)):
        box(KI, ((a + b) / 2, (y0 + y1) / 2, top - .05), (b - a, y1 - y0 + .04, .1), "enamel")
        for k in range(int((b - a) / .06)):
            box(KI, (a + .05 + k * .06, (y0 + y1) / 2, top + .001), (.012, y1 - y0 - .12, .004), "enamel stain")
    box(KI, ((basin_x0 + basin_x1) / 2, (y0 + basin_y0) / 2 - .02, top - .05), (basin_x1 - basin_x0, basin_y0 - y0 + .04, .1), "enamel")
    box(KI, ((basin_x0 + basin_x1) / 2, (basin_y1 + y1) / 2, top - .05), (basin_x1 - basin_x0, y1 - basin_y1, .1), "enamel")
    for pts, n in (([(basin_x0, basin_y0, bz), (basin_x1, basin_y0, bz), (basin_x1, basin_y0, top), (basin_x0, basin_y0, top)], (0, 1, 0)),
                   ([(basin_x0, basin_y1, bz), (basin_x1, basin_y1, bz), (basin_x1, basin_y1, top), (basin_x0, basin_y1, top)], (0, -1, 0)),
                   ([(basin_x0, basin_y0, bz), (basin_x0, basin_y1, bz), (basin_x0, basin_y1, top), (basin_x0, basin_y0, top)], (1, 0, 0)),
                   ([(basin_x1, basin_y0, bz), (basin_x1, basin_y1, bz), (basin_x1, basin_y1, top), (basin_x1, basin_y0, top)], (-1, 0, 0)),
                   ([(basin_x0, basin_y0, bz), (basin_x1, basin_y0, bz), (basin_x1, basin_y1, bz), (basin_x0, basin_y1, bz)], (0, 0, 1))):
        face(KI, pts, "enamel stain" if n == (0, 0, 1) else "enamel", n)
    lathe(KI, ((basin_x0 + basin_x1) / 2, (basin_y0 + basin_y1) / 2, bz + .002), [(.04, 0), (.035, .004), (0, .004)], "iron dark", seg=12)
    box(KI, ((x0 + x1) / 2, y1 - .03, top + .14), (x1 - x0, .06, .28), "enamel")
    collide(((x0 + x1) / 2, (y0 + y1) / 2, top / 2), (x1 - x0, y1 - y0, top), "wood", label="Sink cabinet")
    # Wall faucets: two cross-head taps on a bridge pipe from the backsplash.
    for xx in (6.3, 6.7):
        cyl(KI, (xx, y1 - .06, top + .18), (xx, y1 - .2, top + .18), .012, "iron", seg=8)
        cyl(KI, (xx, y1 - .2, top + .18), (xx, y1 - .24, top + .1), .012, "iron", seg=8)
        cyl(KI, (xx, y1 - .12, top + .2), (xx, y1 - .12, top + .27), .006, "iron", seg=6)
        box(KI, (xx, y1 - .12, top + .27), (.07, .012, .012), "iron")
    # Plates stacked on the drainboards, a few cups.
    for cx, cy, n in ((5.85, 19.36, 6), (7.15, 19.4, 4), (7.25, 19.28, 3)):
        for k in range(n):
            c = Vector((cx + R.uniform(-.01, .01), cy + R.uniform(-.01, .01), top + .002 + k * .018))
            lathe(KI, c, [(.07, 0), (.11, .012), (.125, .016), (.115, .018), (.1, .008), (0, .006)], "plate", seg=20)
    for cx, cy in ((7.0, 19.15), (5.65, 19.2)):
        lathe(KI, (cx, cy, top + .002), [(.03, 0), (.04, .07), (.035, .07), (.025, .005), (0, .005)], "plate", seg=12)
    # The range: cream enamel on legs, a black top with four burners, an oven door, a backguard with a shelf.
    sx0, sx1 = 7.75, 8.55
    box(KI, ((sx0 + sx1) / 2, 19.35, .52), (sx1 - sx0, .66, .76), "stove enamel")
    for xx in (sx0 + .04, sx1 - .04):
        for yy in (19.06, 19.64):
            box(KI, (xx, yy, .07), (.04, .04, .14), "iron dark")
    box(KI, ((sx0 + sx1) / 2, 19.35, .915), (sx1 - sx0 + .02, .68, .03), "soot")
    for bx in (sx0 + .2, sx1 - .2):
        for by in (19.18, 19.5):
            lathe(KI, (bx, by, .93), [(.09, 0), (.095, .008), (.07, .012), (.06, .006), (0, .006)], "iron dark", seg=14)
    box(KI, ((sx0 + sx1) / 2, 19.0, .48), (sx1 - sx0 - .1, .02, .46), "stove enamel")
    cyl(KI, (sx0 + .1, 18.96, .7), (sx1 - .1, 18.96, .7), .012, "iron", seg=8)
    for k in range(4):
        lathe(KI, (sx0 + .12 + k * .19, 18.99, .82), [(.018, 0), (.02, .02), (0, .03)], "soot", seg=8, rot=Matrix.Rotation(math.pi / 2, 3, "X"))
    box(KI, ((sx0 + sx1) / 2, 19.66, 1.2), (sx1 - sx0, .06, .55), "stove enamel")
    box(KI, ((sx0 + sx1) / 2, 19.56, 1.42), (sx1 - sx0, .16, .02), "stove enamel")
    collide(((sx0 + sx1) / 2, 19.35, .47), (sx1 - sx0, .7, .94), "metal", label="Range")
    fridge()
    jumper()
    shelves_west()
    work_table()


def fridge():
    """A rounded 1950s refrigerator against the east wall, door hanging open, its bulb still lit: the house has power."""
    x1 = 12.7
    d, w, h = .72, .82, 1.62
    x0 = x1 - d
    yc = 16.9
    y0, y1 = yc - w / 2, yc + w / 2
    # Body: sides, top, back, a rounded crown along the front.
    for y in (y0 + .025, y1 - .025):
        box(KI, ((x0 + x1) / 2, y, h / 2 + .08), (d, .05, h - .16), "fridge enamel")
    box(KI, ((x0 + x1) / 2 + .02, yc, h - .02), (d - .08, w, .1), "fridge enamel")
    cyl(KI, (x0 + .06, y0, h - .07), (x0 + .06, y1, h - .07), .07, "fridge enamel", seg=10)
    box(KI, (x1 - .02, yc, h / 2), (.04, w, h), "fridge enamel")
    box(KI, ((x0 + x1) / 2, yc, .05), (d, w, .1), "soot")
    box(KI, ((x0 + x1) / 2, yc, .16), (d, w - .1, .12), "fridge enamel")
    # Liner, wire shelves, the crisper.
    li = (x0 + .06, x1 - .06, y0 + .055, y1 - .055, .23, h - .1)
    for pts, n in (([(li[1], li[2], li[4]), (li[1], li[3], li[4]), (li[1], li[3], li[5]), (li[1], li[2], li[5])], (-1, 0, 0)),
                   ([(li[0], li[2], li[4]), (li[1], li[2], li[4]), (li[1], li[2], li[5]), (li[0], li[2], li[5])], (0, 1, 0)),
                   ([(li[0], li[3], li[4]), (li[1], li[3], li[4]), (li[1], li[3], li[5]), (li[0], li[3], li[5])], (0, -1, 0)),
                   ([(li[0], li[2], li[5]), (li[1], li[2], li[5]), (li[1], li[3], li[5]), (li[0], li[3], li[5])], (0, 0, -1)),
                   ([(li[0], li[2], li[4]), (li[1], li[2], li[4]), (li[1], li[3], li[4]), (li[0], li[3], li[4])], (0, 0, 1))):
        face(KI, pts, "fridge liner", n)
    for z in (.62, 1.0, 1.32):
        y = li[2] + .01
        while y < li[3]:
            cyl(KI, (li[0], y, z), (li[1], y, z), .003, "wire", seg=4, caps=False)
            y += .035
        cyl(KI, (li[0], li[2], z), (li[0], li[3], z), .005, "wire", seg=4)
    box(KI, ((li[0] + li[1]) / 2, yc, .33), (li[1] - li[0] - .02, w - .14, .18), "fridge liner")
    # What is inside: dark joints of meat on the shelves, a bowl, wrapped parcels gone dark at the bottom.
    for cx, cy, z, sx, sy, sz in ((12.35, 16.75, .63, .16, .12, .08), (12.32, 17.05, .63, .1, .09, .06), (12.3, 16.85, 1.01, .14, .1, .09),
                                  (12.38, 17.08, 1.01, .09, .08, .05), (12.33, 16.7, 1.33, .12, .1, .06)):
        lathe(KI, (cx, cy, z), [(0, 0), (.7, .1), (1, .45), (.85, .85), (.4, 1.0), (0, 1.0)], "meat", seg=12,
              rot=Matrix.Diagonal((sx, sy, sz)))
    lathe(KI, (12.36, 17.12, 1.33), [(.06, 0), (.1, .07), (.095, .07), (.055, .008), (0, .008)], "plate", seg=14)
    box(KI, (12.3, 16.9, .3), (.25, .3, .12), "tarp")
    collide(((x0 + x1) / 2, yc, h / 2), (d, w, h), "metal", label="Refrigerator")
    # The door, hanging open: its outer skin, the inner panel with door shelves, a chrome lever handle.
    hinge = Vector((x0, y0, 0))
    rot = Matrix.Rotation(math.radians(-118), 3, "Z")
    t = .09

    def at(u, v, z):
        return hinge + rot @ Vector((u, v, 0)) + Vector((0, 0, z))
    box(KI, at(-t / 2, w / 2, h / 2 + .04), (t, w, h - .08), "fridge enamel", rot)
    box(KI, at(.01, w / 2, h / 2 + .04), (.02, w - .1, h - .26), "fridge liner", rot)
    for z in (.5, .85, 1.2):
        box(KI, at(.08, w / 2, z), (.12, w - .14, .01), "fridge liner", rot)
        box(KI, at(.13, w / 2, z + .05), (.01, w - .14, .09), "fridge liner", rot)
        for k in range(R.randint(1, 3)):
            lathe(KI, at(.08, .2 + k * .16, z + .005), [(.03, 0), (.03, .16), (.012, .2), (.012, .24), (0, .24)], "bottle glass", seg=8)
    box(KI, at(-t - .03, w - .06, 1.0), (.03, .03, .3), "chrome", rot)
    LAYOUT["basement"]["fridge"] = {"light": godot(Vector((12.32, yc, h - .2))), "hum": godot(Vector((12.4, yc, .4))),
                                    "door_hinge": godot(hinge), "inside": godot(Vector((12.3, yc, .9)))}


def cable(mesh, pts, r=.009, sag=0.0, mat="cable"):
    """A cable through `pts`; `sag` droops each span by that much in the middle."""
    pts = [Vector(p) for p in pts]
    for a, b in zip(pts, pts[1:]):
        n = 6 if sag else 1
        prev = a
        for k in range(1, n + 1):
            t = k / n
            p = a.lerp(b, t) - Vector((0, 0, sag * 4 * t * (1 - t)))
            cyl(mesh, prev, p, r, mat, seg=5, caps=False)
            prev = p


def jumper():
    """Why the refrigerator runs in a house cut off for decades: a new cable, tapped from the lines somewhere out past
    the back wall, comes in through a broken pane of the east window, runs down the wall and along the skirting to a
    cheap power strip on the floor. Outside it droops from the window into the weeds."""
    wx = 12.7
    y_in = 15.22
    top = 2.55
    strip = Vector((12.22, 17.66, .025))
    # Outside: from the weeds up to the pane (house_ext), stapled to the frame.
    out = W_OUT = 13.04
    cable("ext", [(out + 4.5, y_in - 2.0, -1.18), (out + 1.6, y_in - .6, -1.15), (out + .02, y_in - .1, -1.1)], sag=.0)
    cable("ext", [(out + .02, y_in - .1, -1.1), (out + .02, y_in - .1, top - .2), (out - .1, y_in, top)], sag=.0)
    # Inside: down the wall beside the window, along the skirting, staples every half metre.
    # (behind the refrigerator from y 16.5 to 17.3, out to the strip on its south side)
    run_pts = [(wx - .05, y_in, top), (wx - .015, y_in - .05, top - .15), (wx - .015, y_in - .2, .3), (wx - .015, y_in - .12, .13),
               (wx - .015, 15.9, .13), (wx - .015, 17.38, .13), (wx - .12, 17.5, .02), (strip.x + .16, strip.y, .02)]
    cable(KI, run_pts)
    for a, b in zip(run_pts[2:6], run_pts[3:7]):
        a, b = Vector(a), Vector(b)
        for k in range(1, int((b - a).length / .5) + 1):
            p = a.lerp(b, k * .5 / (b - a).length)
            box(KI, p + Vector((.006, 0, 0)), (.008, .022, .022), "chrome")
    # The power strip: four sockets, a lit rocker switch; the fridge's cord plugged into it.
    box(KI, strip + Vector((0, 0, .018)), (.32, .055, .036), "strip")
    for k in range(4):
        box(KI, strip + Vector((-.1 + k * .06, 0, .037)), (.03, .03, .002), "soot")
    box(KI, strip + Vector((.13, 0, .038)), (.022, .03, .006), "strip lamp")
    cable(KI, [strip + Vector((-.1, 0, .04)), strip + Vector((-.14, -.06, .07)), (12.1, 17.4, .03), (12.3, 17.33, .1)], r=.006, sag=.02, mat="cord")
    LAYOUT["basement"]["jumper"] = {"strip": godot(strip + Vector((.13, 0, .045)))}


def shelves_west():
    """Open shelves on brackets on the west wall, jars and tins; a rail of hanging utensils under them."""
    x = 4.08 + .15
    y0, y1 = 13.75, 15.85
    for z in (1.35, 1.78):
        box(KI, (x, (y0 + y1) / 2, z), (.3, y1 - y0, .03), "board")
        for y in (y0 + .15, (y0 + y1) / 2, y1 - .15):
            box(KI, (4.1, y, z - .1), (.03, .03, .2), "iron")
            beam(KI, (4.1, y, z - .18), (4.33, y, z - .02), .02, .02, "iron", up=(0, 1, 0))
        yy = y0 + .1
        while yy < y1 - .08:
            if R.random() < .7:
                r = R.uniform(.035, .06)
                hh = R.uniform(.1, .22)
                c = Vector((x + R.uniform(-.06, .06), yy, z + .015))
                if R.random() < .5:
                    lathe(KI, c, [(r, 0), (r, hh * .8), (r * .7, hh * .9), (r * .7, hh), (0, hh)], "jar", seg=10)
                    lathe(KI, c + Vector((0, 0, .004)), [(r * .9, 0), (r * .9, hh * R.uniform(.2, .7)), (0, hh * .4)], R.choice(("jar dark", "jar murk")), seg=8)
                else:
                    lathe(KI, c, [(r, 0), (r, hh), (0, hh)], R.choice(("lid", "iron dark")), seg=10)
            yy += R.uniform(.11, .17)
    cyl(KI, (4.12, y0 + .1, 1.08), (4.12, y1 - .1, 1.08), .008, "iron", seg=6)
    for k in range(7):
        y = y0 + .3 + k * .24
        top = Vector((4.13, y, 1.07))
        cyl(KI, top, top - Vector((0, 0, .32 + .06 * (k % 3))), .005, "iron", seg=5)
        if k % 2 == 0:
            lathe(KI, top - Vector((0, 0, .34 + .06 * (k % 3))), [(0, 0), (.04, .01), (.045, .03), (.04, .035)], "iron", seg=10)
        else:
            box(KI, top - Vector((0, 0, .37 + .06 * (k % 3))), (.01, .05, .09), "iron")


def work_table():
    """A heavy work table, its top scored and stained dark: a cutting board, a knife, a bowl."""
    cx, cy = 8.6, 16.4
    w, d, h = 1.7, .85, .84
    box(KI, (cx, cy, h - .04), (w, d, .08), "bench top")
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(KI, (cx + sx * (w / 2 - .08), cy + sy * (d / 2 - .08), (h - .08) / 2), (.07, .07, h - .08), "post")
    box(KI, (cx, cy, .2), (w - .2, d - .2, .025), "board")
    collide((cx, cy, h / 2), (w, d, h), "wood", label="Work table")
    LAYOUT["basement"]["kitchen"] = {"table": godot(Vector((cx, cy, h))), "sink": godot(Vector((6.5, 19.36, .9))),
                                     "range": godot(Vector(((7.75 + 8.55) / 2, 19.35, .93)))}

# ------------------------------------------------------------------------------------------------ layout
def layout():
    lb = LAYOUT.setdefault("basement", {})
    lb["door"] = door_and_shaft_layout()
    lb["switch"] = {"pos": godot(Vector((2.6 - .012, 9.12, 1.32))), "normal": godot(Vector((-1, 0, 0)))}
    # Bulbs: kind (pull = bare bulb in a pull-chain socket on a joist, cord = bare bulb on a long cord, cage = caged
    # lamp), flicker 0 steady .. 1 failing, shadows.
    lb["lights"] = [
        {"pos": godot(Vector((-.6, 10.2, 2.35))), "top": godot(Vector((-.6, 10.2, 4.0))), "kind": "cord", "flicker": .15, "shadow": True, "energy": .55, "room": "shaft"},
        {"pos": godot(Vector((-3.3, 10.2, -.48))), "top": godot(Vector((-3.3, 10.2, -.04))), "kind": "pull", "flicker": .35, "shadow": False, "energy": .4, "room": "shaft"},
        {"pos": godot(Vector((-7.6, 13.2, JOIST_B - .2))), "top": godot(Vector((-7.6, 13.2, JOIST_B))), "kind": "pull", "flicker": .05, "shadow": True, "energy": .7, "room": "cellar"},
        {"pos": godot(Vector((-3.3, 17.2, JOIST_B - .45))), "top": godot(Vector((-3.3, 17.2, JOIST_B))), "kind": "cord", "flicker": .7, "shadow": True, "energy": .6, "room": "cellar"},
        {"pos": godot(Vector((-10.4, 17.0, JOIST_B - .2))), "top": godot(Vector((-10.4, 17.0, JOIST_B))), "kind": "dead", "flicker": 0, "shadow": False, "energy": 0, "room": "cellar"},
        {"pos": godot(Vector((3.0, KY_MID, K_RIDGE - .5))), "top": godot(Vector((3.0, KY_MID, K_RIDGE))), "kind": "cage", "flicker": .2, "shadow": True, "energy": .6, "room": "corridor"},
        {"pos": godot(Vector((7.8, KY_MID, K_RIDGE - .5))), "top": godot(Vector((7.8, KY_MID, K_RIDGE))), "kind": "cage", "flicker": .9, "shadow": True, "energy": .55, "room": "corridor"},
        {"pos": godot(Vector((11.6, KY_MID, K_RIDGE - .35))), "top": godot(Vector((11.6, KY_MID, K_RIDGE))), "kind": "pull", "flicker": .45, "shadow": True, "energy": .45, "room": "corridor"},
    ]
    lb["rooms"] = [
        {"name": "shaft", "lo": godot(Vector((SX0, SI1, BF))), "hi": godot(Vector((SX1, SI0, 4.0)))},
        {"name": "cellar", "lo": godot(Vector((CX0, CY1, BF))), "hi": godot(Vector((CX1, CY0, -.04)))},
        {"name": "passage", "lo": godot(Vector((CX1, HOLE_Y1, CF))), "hi": godot(Vector((PX1, HOLE_Y0, HOLE_TOP)))},
        {"name": "corridor", "lo": godot(Vector((KX0, KY1, CF))), "hi": godot(Vector((KX1, KY0, K_RIDGE)))},
    ]
    # The drag trail, front door to the iron door (points on the surface it crosses).
    # It starts just inside the threshold and keeps to the moonlight that falls through the open front door.
    trail = [(.12, -.35, 0), (.55, 1.0, 0), (1.2, 2.2, 0), (1.8, 3.3, 0), (1.95, 5.4, 0), (1.95, 8.5, 0), (1.95, 9.4, 0),
             (2.05, 10.05, 0), (1.15, 10.2, 0), (FOOT_X, 10.2, BF), (-3.3, 10.25, BF), (-3.35, 11.5, BF), (-3.0, 13.4, BF),
             (-1.9, 15.5, BF), (-.75, 16.85, BF), (CX1 + EAST_T, 16.85, BF), (PX1 + .1, 16.85, CF), (5.5, 16.7, CF), (9.0, 16.9, CF), (KX1 - .1, 16.8, CF)]
    lb["trail"] = [godot(Vector(p)) for p in trail]
    lb["secret_door"] = {"pos": godot(Vector((KX1 - .06, KY_MID, CF))), "normal": godot(Vector((-1, 0, 0))), "width": 1.04, "height": 2.12}
    lb["spots"] = {
        "nook": godot(Vector((1.95, 7.6, 0))), "landing": godot(Vector((2.2, 10.2, 0))), "shaft_foot": godot(Vector((-3.35, 10.2, BF))),
        "cellar": godot(Vector((-6.0, 14.0, BF))), "drain": godot(Vector((-6.2, 17.6, BF))), "hole": godot(Vector((CX1 - .6, 16.85, BF))),
        "corridor": godot(Vector((PX1 + .8, KY_MID, CF))), "steel_door": godot(Vector((KX1 - 1.0, KY_MID, CF))),
        "cages": godot(Vector((9.9, KY0 + .9, CF))),
        "tarp": godot(Vector((-8.4, 17.3, BF))), "workbench": godot(Vector((-3.3, CY1 - .38, BF + .88))),
        "hooks": godot(Vector((-6.9, 18.4, JOIST_B - .12))),
    }
    lb["floors"] = {"cellar": BF, "corridor": CF}


def build():
    MESHES[B] = Mesh(B)
    shaft()
    cellar()
    passage()
    corridor()
    cellar_leaf()
    layout()
    kitchen()
