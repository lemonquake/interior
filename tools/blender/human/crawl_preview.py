"""0.43: side and top renders of the prone clips (crawl_clips.py) to tune them without exporting.

  blender -b --factory-startup --python tools/blender/human/crawl_preview.py   -> work/v43/crawl/<clip>_<view>_<k>.png
"""
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import build_human as bh
import build_zombies as bz
import crawl_clips

OUT = os.path.join(bh.ROOT, "work", "v43", "crawl")


def main():
    bh.reset()
    arm, body = bz.load(bz.CLIPS)
    bh.retarget_run(arm)
    body.shape_key_clear()
    crawl_clips.make_crawl(arm)
    crawl_clips.make_down_idle(arm)
    cam = bh.setup_render((480, 360))
    body.data.materials.clear()
    body.data.materials.append(bh.principled("grey", (0.6, 0.6, 0.62), 0.7))
    # A floor to see where the body lies against it.
    bpy.ops.mesh.primitive_plane_add(size=6.0, location=(0, 0, 0))
    os.makedirs(OUT, exist_ok=True)
    views = {"side": ((2.6, -0.1, 0.35), (0.0, -0.1, 0.15)), "q": ((1.6, -2.2, 1.2), (0.0, -0.1, 0.1)),
             "top": ((0.01, -0.1, 2.9), (0.0, -0.1, 0.0))}
    for name in ("crawl", "down_idle"):
        act = bpy.data.actions[name]
        f0, f1 = act.frame_range
        for k, t in enumerate((0.0, 0.25, 0.5, 0.75)):
            bh.set_action(arm, act, f0 + (f1 - f0) * t)
            for view, (eye, at) in views.items():
                bh.shoot(cam, os.path.join(OUT, "%s_%s_%d.png" % (name, view, k)), eye, at, lens=35)


main()
