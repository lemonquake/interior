"""Build the Nichols house (0.21). See nichols_geo.py for the coordinate conventions.

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P tools/blender/nichols/build_nichols.py [-- --preview <dir>]
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nichols_geo as G  # noqa: E402
import nichols_plan as PL  # noqa: E402
import nichols_exterior as EX  # noqa: E402
import nichols_cloth as CL  # noqa: E402
import nichols_basement as BS  # noqa: E402

PREVIEW_COLORS = {
    "siding": (.55, .53, .5), "trim ext": (.75, .74, .7), "sash": (.2, .2, .2), "shutter": (.15, .2, .18), "board": (.35, .28, .2),
    "glass": (.1, .14, .16), "glass grime": (.12, .13, .12), "void": (.01, .01, .01), "slate": (.2, .21, .23), "stone": (.45, .43, .4),
    "marble": (.8, .8, .78), "floor": (.35, .24, .16), "floor b": (.3, .22, .15), "tile": (.6, .58, .55), "ceiling": (.75, .73, .7),
    "trim": (.28, .18, .12), "wainscot": (.25, .14, .1), "carpet": (.15, .2, .12), "tread": (.3, .2, .12), "riser": (.32, .22, .14),
    "plaster": (.7, .68, .62), "plaster dark": (.3, .3, .3), "wp hall": (.32, .42, .5), "wp parlour": (.25, .42, .4), "wp dining": (.45, .15, .15),
    "wp corridor": (.3, .38, .5), "drape": (.3, .08, .08), "lace": (.8, .8, .75), "sheet": (.75, .73, .68), "brass": (.5, .4, .2), "wp bedroom": (.55, .4, .42), "wp nursery": (.6, .58, .45), "soot": (.03, .03, .03), "marble fire": (.85, .84, .8),
    # 0.22 basement
    "cellar floor": (.3, .27, .24), "cellar stone": (.5, .45, .38), "cellar plaster": (.6, .58, .52), "subfloor": (.28, .2, .14),
    "joist": (.36, .28, .2), "post": (.3, .22, .15), "stair": (.4, .3, .2), "rail wood": (.3, .2, .12), "iron": (.12, .12, .12),
    "iron dark": (.05, .05, .05), "cord": (.05, .05, .05), "coal": (.04, .04, .04), "bench top": (.38, .28, .18), "pegboard": (.45, .36, .25),
    "outline": (.7, .66, .58), "jar": (.55, .62, .6), "jar dark": (.12, .1, .06), "jar red": (.35, .08, .06), "jar murk": (.3, .3, .12),
    "lid": (.4, .35, .2), "block wood": (.35, .25, .16), "block top": (.28, .12, .1), "pipe": (.4, .25, .15), "chain": (.2, .18, .16),
    "tarp": (.18, .22, .25), "tub": (.5, .52, .52), "step concrete": (.45, .44, .42), "corridor wall": (.62, .6, .56),
    "corridor floor": (.25, .24, .22), "corridor ceiling": (.55, .54, .5), "wet band": (.2, .19, .17), "conduit": (.8, .65, .1),
    "vent": (.25, .23, .2), "locker": (.2, .32, .22), "rag": (.4, .35, .3), "door frame": (.5, .5, .48), "steel door": (.06, .06, .06),
    "enamel": (.8, .8, .76), "enamel stain": (.5, .4, .3), "valve": (.5, .1, .08), "cellar door": (.32, .24, .16),
    "cage iron": (.22, .2, .18), "collar": (.35, .1, .08), "padlock": (.75, .74, .7),
    "cab paint": (.55, .6, .5), "stove enamel": (.8, .78, .7), "fridge enamel": (.82, .8, .72), "fridge liner": (.85, .85, .8),
    "cable": (.02, .02, .02), "strip": (.75, .74, .7), "strip lamp": (1, .5, .1),
    "wire": (.6, .6, .6), "meat": (.4, .06, .05), "plate": (.85, .84, .8), "bottle glass": (.2, .3, .2), "chrome": (.8, .8, .8),
}


def export(preview_dir=None):
    os.makedirs(G.OUT, exist_ok=True)
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    objects = {}
    for key, m in G.MESHES.items():
        if not m.bm.faces:
            continue
        if key.startswith("sheet") or key == "cloth":
            bmesh.ops.remove_doubles(m.bm, verts=m.bm.verts[:], dist=.0005)
        bmesh.ops.triangulate(m.bm, faces=m.bm.faces[:])
        me = bpy.data.meshes.new("house_" + key)
        m.bm.to_mesh(me)
        for name in m.mats:
            mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
            mat.diffuse_color = (*PREVIEW_COLORS.get(name, (.5, .5, .5)), 1)
            me.materials.append(mat)
        obj = bpy.data.objects.new("house_" + key, me)
        bpy.context.scene.collection.objects.link(obj)
        objects[key] = obj
    for key, obj in objects.items():
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.gltf(filepath=os.path.join(G.OUT, "house_" + key + ".glb"), export_format="GLB", use_selection=True,
                                  export_materials="EXPORT", export_yup=True, export_apply=True, export_animations=False)
        print("EXPORTED", key, len(obj.data.polygons), "tris", len(G.MESHES[key].mats), "materials")
    with open(os.path.join(G.OUT, "layout.json"), "w") as f:
        json.dump(G.LAYOUT, f, indent=0)
    print("LAYOUT", {k: len(v) for k, v in G.LAYOUT.items() if isinstance(v, (list, dict))})
    if preview_dir:
        preview(objects, preview_dir)


def preview(objects, out):
    """Workbench renders: a cutaway of the ground floor, the upper floor and an exterior three-quarter view."""
    os.makedirs(out, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 1600, 900
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam

    def shot(name, loc, target, lens=24, clip=None):
        cam.location = Vector(loc)
        d = Vector(target) - cam.location
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        cam_data.lens = lens
        cam_data.clip_start = clip if clip else .1
        cam_data.clip_end = 400
        scene.render.filepath = os.path.join(out, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("PREVIEW", scene.render.filepath)

    shot("ext-front", (-24, -30, 9), (0, 8, 6), 28)
    shot("ext-back", (26, 42, 12), (0, 10, 5), 28)
    # Cutaways: the camera above looks down with its near clip slicing off the floor above.
    shot("plan-ground", (0, 10, 30), (0, 10, 0), 18, clip=26.4)
    shot("plan-upper", (0, 10, 30), (0, 10, 4.4), 18, clip=22.4)
    shot("foyer", (0, -.2, 1.6), (0, 9, 2.2), 16)
    # 0.22 basement: a cutaway below the boards, then views inside.
    shot("plan-basement", (-1, 15, 30), (-1, 15, -3), 18, clip=30.1)
    shot("nook-door", (2.0, 4.6, 1.55), (1.95, 9.4, .9), 22)
    shot("shaft", (2.3, 10.2, 1.55), (-3.0, 10.2, -2.2), 18)
    shot("cellar", (-3.3, 11.6, -1.1), (-8.5, 17.5, -2.3), 18)
    shot("cellar-hole", (-4.0, 14.2, -1.1), (0, 16.9, -1.9), 20)
    shot("corridor", (1.9, 16.8, -2.0), (12.3, 16.8, -2.5), 20)
    shot("kitchen", (5.0, 14.2, 1.6), (9.5, 19.6, .7), 18)
    for key in list(objects):
        objects[key].hide_render = not key.startswith("sheet")
    for k, key in enumerate(sorted(o for o in objects if o.startswith("sheet"))):
        objects[key].location = (k * 3.0, 0, 0)
    shot("sheets", (7.5, -9, 4), (7.5, 0, .5), 30)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    preview_dir = argv[argv.index("--preview") + 1] if "--preview" in argv else None
    PL.plan()
    PL.floors()
    PL.staircase()
    G.LAYOUT["spots"]["mantel_parlour"] = G.godot(PL.fireplace(-G.W + G.T, 4.7, 6.3, 0, G.C0))
    G.LAYOUT["spots"]["mantel_master"] = G.godot(PL.fireplace(-G.W + G.T, 4.7, 6.3, G.F1, G.C1))
    PL.columned_opening()
    PL.pocket_door()
    EX.build()
    CL.curtains()
    CL.sheets()
    BS.build()
    print("FACES", G.TRIS["faces"])
    export(preview_dir)


main()
