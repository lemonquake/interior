"""Interior 0.11: the buried 9x19 mm ammo box (a weathered generic cardboard box of 60, in a crumpled clear bag).

  blender -b --factory-startup --python tools/blender/story/ammo_box.py -- [preview]
      -> game/assets/models/story/ammo_box.glb (+ work/v11/box/ammo_box.png with `preview`)
  python tools/blender/story/ammo_box.py
      -> game/assets/models/story/ammo_box_label.png only (the label, made with PIL; Blender runs this itself)

No real brand: an olive tuck box with an off-white panel, "9x19 mm", "60", a cartridge silhouette, scuffs and a
water stain (it was buried in a wet paddy). Size 120 x 75 x 40 mm (X x Y x Z in Blender; glTF/Godot: X 120, Y 40 up,
Z 75), origin at its centre. A bevelled base and a lid (the seam is the lid's lower edge), one corner crushed.
The bag is a slightly larger noisy shell, alpha blended, glossy.
"""
import math
import os
import random
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT_GLB = os.path.join(ROOT, "game", "assets", "models", "story", "ammo_box.glb")
LABEL = os.path.join(ROOT, "game", "assets", "models", "story", "ammo_box_label.png")
WORK = os.path.join(ROOT, "work", "v11", "box")
SIZE = (0.120, 0.075, 0.040)
LID_Z = -0.006              # the lid covers the box from here up; its lower edge is the seam
# Atlas regions (pixels, 1024 x 1024, origin top-left): which face of the box shows which part of the label.
PX = 6                      # pixels per mm on the big faces
REGIONS = {"top": (0, 0, 720, 450), "front": (0, 450, 720, 690), "back": (0, 690, 720, 930),
           "left": (720, 0, 960, 450), "right": (720, 450, 960, 900), "bottom": (0, 930, 720, 1024)}


# ---------------------------------------------------------------- label (PIL)

def make_label():
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
    rnd = random.Random(911)
    W = H = 1024
    olive = (104, 108, 72)
    im = Image.new("RGB", (W, H), olive)
    d = ImageDraw.Draw(im)

    def font(size, bold=True):
        for name in (("arialbd.ttf", "DejaVuSans-Bold.ttf") if bold else ("arial.ttf", "DejaVuSans.ttf")):
            for base in ("C:/Windows/Fonts", "/usr/share/fonts/truetype/dejavu", ""):
                try:
                    return ImageFont.truetype(os.path.join(base, name) if base else name, size)
                except OSError:
                    continue
        return ImageFont.load_default()

    def centred(box, y, text, f, fill):
        x0, _, x1, _ = box
        w = d.textlength(text, font=f)
        d.text(((x0 + x1 - w) / 2, y), text, font=f, fill=fill)

    def cartridge(cx, cy, length, fill):
        """A side-on 9 mm round: case + rounded bullet, pointing right."""
        h = length * 0.33
        case = length * 0.62
        x0 = cx - length / 2
        d.rectangle((x0, cy - h / 2, x0 + case, cy + h / 2), fill=fill)
        d.rectangle((x0, cy - h / 2 - 2, x0 + length * 0.05, cy + h / 2 + 2), fill=fill)       # rim
        d.ellipse((x0 + case - length * 0.12, cy - h / 2 + 1, x0 + length, cy + h / 2 - 1), fill=fill)
        d.rectangle((x0 + case - 2, cy - h / 2 + 1, x0 + case + length * 0.1, cy + h / 2 - 1), fill=fill)

    ink = (34, 33, 28)
    card = (226, 219, 196)
    # Top: the off-white panel with the calibre, count and a round.
    x0, y0, x1, y1 = REGIONS["top"]
    d.rectangle((x0 + 40, y0 + 34, x1 - 40, y1 - 34), fill=card)
    d.rectangle((x0 + 52, y0 + 46, x1 - 52, y1 - 46), outline=ink, width=4)
    centred(REGIONS["top"], y0 + 70, "9\u00d719 mm", font(96), ink)
    centred(REGIONS["top"], y0 + 182, "PISTOL CARTRIDGES", font(38), ink)
    d.rectangle((x0 + 120, y0 + 236, x1 - 120, y0 + 240), fill=ink)
    cartridge(x0 + 250, y0 + 305, 170, ink)
    d.text((x0 + 380, y0 + 246), "60", font=font(100), fill=ink)
    d.text((x0 + 70, y1 - 78), "FULL METAL JACKET  \u2022  124 GR", font=font(26, False), fill=ink)
    # Front / back: calibre band; sides: count.
    for key in ("front", "back"):
        x0, y0, x1, y1 = REGIONS[key]
        d.rectangle((x0, y0 + 70, x1, y1 - 60), fill=card)
        centred(REGIONS[key], y0 + 82, "9\u00d719 mm  \u2022  60 ROUNDS", font(52), ink)
        if key == "back":
            d.text((x0 + 40, y0 + 18), "KEEP DRY  \u2022  LOT 0417-A", font=font(26, False), fill=(200, 196, 170))
    for key in ("left", "right"):
        x0, y0, x1, y1 = REGIONS[key]
        d.rectangle((x0 + 50, y0 + 20, x1 - 50, y1 - 20), fill=card)
        side = Image.new("RGBA", (y1 - y0 - 60, x1 - x0 - 120), (0, 0, 0, 0))
        sd = ImageDraw.Draw(side)
        sd.text((24, 20), "9\u00d719  60", font=font(64), fill=ink)
        side = side.rotate(90, expand=True)
        im.paste(side, (x0 + 60, y0 + 30), side)
    # Wear: card grain, scuffed (lighter) edges, a water stain with a tide line, dirt.
    px = im.load()
    for _ in range(26000):
        x, y = rnd.randrange(W), rnd.randrange(H)
        r, g, b = px[x, y]
        k = rnd.uniform(-7, 5)
        px[x, y] = (max(0, min(255, int(r + k))), max(0, min(255, int(g + k))), max(0, min(255, int(b + k))))
    wear = Image.new("L", (W, H), 0)
    wd = ImageDraw.Draw(wear)
    for x0, y0, x1, y1 in REGIONS.values():
        for _ in range(60):
            side = rnd.randrange(4)
            t = rnd.uniform(0, 1)
            if side < 2:
                x = x0 + t * (x1 - x0)
                y = y0 + (rnd.uniform(0, 10) if side == 0 else (y1 - y0) - rnd.uniform(0, 10))
            else:
                y = y0 + t * (y1 - y0)
                x = x0 + (rnd.uniform(0, 10) if side == 2 else (x1 - x0) - rnd.uniform(0, 10))
            r = rnd.uniform(3, 14)
            wd.ellipse((x - r, y - r * 0.6, x + r, y + r * 0.6), fill=rnd.randrange(90, 200))
    wear = wear.filter(ImageFilter.GaussianBlur(3))
    im = Image.composite(Image.new("RGB", (W, H), (190, 182, 150)), im, wear)
    stain = Image.new("L", (W, H), 0)
    sd = ImageDraw.Draw(stain)
    for cx, cy, rx, ry in ((520, 330, 230, 160), (300, 610, 260, 110), (840, 560, 120, 230)):
        pts = []
        for k in range(48):
            a = k / 48 * math.tau
            f = 1.0 + 0.18 * math.sin(a * 3 + cx) + 0.08 * math.sin(a * 7 + cy)
            pts.append((cx + math.cos(a) * rx * f, cy + math.sin(a) * ry * f))
        sd.polygon(pts, fill=110)
        sd.line(pts + pts[:1], fill=210, width=7)           # the tide line where the water dried
    stain = stain.filter(ImageFilter.GaussianBlur(5))
    im = Image.composite(Image.new("RGB", (W, H), (92, 72, 44)), im, stain.point(lambda v: int(v * 0.55)))
    dirt = Image.effect_noise((W // 8, H // 8), 60).resize((W, H), Image.BICUBIC).point(lambda v: max(0, v - 175) * 2)
    im = Image.composite(Image.new("RGB", (W, H), (60, 50, 36)), im, dirt.filter(ImageFilter.GaussianBlur(4)))
    os.makedirs(os.path.dirname(LABEL), exist_ok=True)
    im.save(LABEL)
    print("LABEL", LABEL)


# ---------------------------------------------------------------- model (Blender)

def build():
    import bmesh
    import bpy
    from mathutils import Vector, noise

    bpy.ops.wm.read_factory_settings(use_empty=True)
    if not os.path.exists(LABEL) or "label" in sys.argv:
        subprocess.run(["python", os.path.abspath(__file__)], check=True)

    def mat_card():
        m = bpy.data.materials.new("Ammo box card")
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Roughness"].default_value = 0.88
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(LABEL)
        m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        return m

    def mat_bag():
        m = bpy.data.materials.new("Plastic bag")
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (0.82, 0.81, 0.76, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.18
        bsdf.inputs["Alpha"].default_value = 0.22
        try:
            m.surface_render_method = "BLENDED"
        except AttributeError:
            m.blend_method = "BLEND"
        m.use_backface_culling = False
        return m

    def block(name, size, centre, cuts):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
        for v in bm.verts:
            v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + Vector(centre)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob

    def apply_all(ob):
        bpy.context.view_layer.objects.active = ob
        for o in bpy.context.scene.objects:
            o.select_set(o == ob)
        for mod in list(ob.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)

    sx, sy, sz = SIZE
    base = block("Box base", (sx - 0.002, sy - 0.002, sz - 0.002), (0, 0, -0.001), 2)
    lid_h = sz / 2 - LID_Z
    lid = block("Box lid", (sx, sy, lid_h), (0, 0, LID_Z + lid_h / 2), 2)
    for ob, w in ((base, 0.0022), (lid, 0.0016)):
        bev = ob.modifiers.new("bevel", "BEVEL")
        bev.width = w
        bev.segments = 2
        bev.limit_method = "ANGLE"
        apply_all(ob)

    # Crushed corner (+X, -Y, top) and a little sag everywhere: wet card.
    corner = Vector((sx / 2, -sy / 2, sz / 2))
    for ob in (base, lid):
        for v in ob.data.vertices:
            c = v.co
            f = max(0.0, 1.0 - (c - corner).length / 0.045) ** 1.6
            push = Vector((-0.55, 0.45, -1.0)).normalized() * 0.013 * f
            sag = 0.0012 * noise.noise(c * 40.0)
            v.co = c + push + Vector((0, 0, sag if c.z > 0.015 else 0.0))

    # UVs: each face's dominant axis picks its atlas region; planar inside it.
    W = 1024.0
    for ob in (base, lid):
        me = ob.data
        uvl = me.uv_layers.new(name="UVMap")
        for p in me.polygons:
            n = p.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            if ax == 2:
                key = "top" if n.z > 0 else "bottom"
            elif ax == 1:
                key = "front" if n.y < 0 else "back"
            else:
                key = "right" if n.x > 0 else "left"
            x0, y0, x1, y1 = REGIONS[key]
            for li in p.loop_indices:
                c = me.vertices[me.loops[li].vertex_index].co
                if key in ("top", "bottom"):
                    a, b = (c.x / sx + 0.5), (0.5 - c.y / sy) if key == "top" else (c.y / sy + 0.5)
                elif key in ("front", "back"):
                    a = (c.x / sx + 0.5) if key == "front" else (0.5 - c.x / sx)
                    b = 0.5 - c.z / sz
                else:
                    a = 0.5 - c.z / sz
                    b = (0.5 - c.y / sy) if key == "right" else (c.y / sy + 0.5)
                a, b = min(max(a, 0.0), 1.0), min(max(b, 0.0), 1.0)
                u = (x0 + a * (x1 - x0)) / W
                v = 1.0 - (y0 + b * (y1 - y0)) / W
                uvl.data[li].uv = (u, v)

    card = mat_card()
    for ob in (base, lid):
        ob.data.materials.append(card)

    # The bag: a slightly larger crumpled shell, gathered and twisted at the +X end.
    bag = block("Bag", (sx + 0.012, sy + 0.012, sz + 0.012), (0.0, 0, 0), 5)
    for v in bag.data.vertices:
        c = v.co.copy()
        n = Vector((c.x / (sx + 0.012), c.y / (sy + 0.012), c.z / (sz + 0.012)))
        crumple = 0.0035 * noise.noise(c * 70.0) + 0.0025 * noise.noise(c * 150.0 + Vector((3, 7, 1)))
        c += n.normalized() * crumple
        if c.x > sx / 2 - 0.004:                         # gather the open end into a twist
            t = min(1.0, (c.x - (sx / 2 - 0.004)) / 0.012)
            c.y *= 1.0 - 0.75 * t
            c.z *= 1.0 - 0.7 * t
            c.x += 0.012 * t
        if c.z < -sz / 2 - 0.002:                       # it rests on the box: hug the bottom
            c.z = -sz / 2 - 0.0025 + 0.001 * noise.noise(c * 90.0)
        v.co = c
    bag.data.materials.append(mat_bag())

    for ob in (base, lid, bag):
        for p in ob.data.polygons:
            p.use_smooth = ob is bag
    for o in bpy.context.scene.objects:
        o.select_set(o in (base, lid))
    bpy.context.view_layer.objects.active = lid
    bpy.ops.object.join()
    box = bpy.context.view_layer.objects.active
    box.name = "AmmoBox"
    box.data.name = "AmmoBox"
    bag.parent = box
    tris = 0
    for ob in (box, bag):
        ob.data.calc_loop_triangles()
        tris += len(ob.data.loop_triangles)
    print("TRIANGLES", tris, "box", len(box.data.loop_triangles), "bag", len(bag.data.loop_triangles))

    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    for o in bpy.context.scene.objects:
        o.select_set(o in (box, bag))
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_animations=False)
    print("EXPORTED", OUT_GLB, os.path.getsize(OUT_GLB))
    if "preview" in sys.argv:
        preview(box, bag)


def preview(box, bag):
    import bpy
    from mathutils import Vector
    os.makedirs(WORK, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = 900, 600
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.3, 0.31, 0.33, 1)
    sc.world = world
    for name, rot, e in (("key", (50, 0, 30), 3.0), ("rim", (65, 0, 190), 2.0)):
        l = bpy.data.lights.new(name, "SUN")
        l.energy = e
        o = bpy.data.objects.new(name, l)
        o.rotation_euler = [math.radians(a) for a in rot]
        sc.collection.objects.link(o)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.lens = 50
    for name, hide, eye in (("ammo_box", False, (0.17, -0.24, 0.17)), ("ammo_box_nobag", True, (0.17, -0.24, 0.17)),
                            ("ammo_box_back", True, (-0.2, 0.22, 0.1))):
        bag.hide_render = hide
        cam.location = eye
        d = (Vector((0.006, 0, 0)) - Vector(eye)).normalized()
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(WORK, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("RENDER", sc.render.filepath)


try:
    import bpy  # noqa: F401
    IN_BLENDER = True
except ImportError:
    IN_BLENDER = False

if __name__ == "__main__":
    if IN_BLENDER:
        build()
    else:
        make_label()
