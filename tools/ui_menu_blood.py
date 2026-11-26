"""Interior 0.31: the blood on the main screen, from the game's own realistic liquid graphics
(game/assets/horror_textures/liquid: splatter with drips, drag smear, pool; see licenses/HORROR_TEXTURES.md).

    python -I tools/ui_menu_blood.py [preview]

Writes game/assets/ui/menu_blood.png (1600 x 900, RGBA): a spatter with runs in the upper right, a smaller one low on
the right, a long drag along the bottom and a shorter one down the right edge, a pool running off the corner. Dried
and dark, thin enough to be drawn over the menu's street; the left third, where the title and the menu are, is clean.
(It replaces the drawn version tools/ui_assets.py makes; run this after that one.)
"""
import os
import sys

from PIL import Image, ImageEnhance

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SRC = os.path.join(ROOT, "game", "assets", "horror_textures", "liquid")
OUT = os.path.join(ROOT, "game", "assets", "ui", "menu_blood.png")
SIZE = (1600, 900)


def piece(name, width, turn=0.0, flip=False, strength=1.0, dark=0.6):
    im = Image.open(os.path.join(SRC, name)).convert("RGBA")
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    im = im.resize((width, int(im.height * width / im.width)), Image.LANCZOS)
    if turn:
        im = im.rotate(turn, resample=Image.BICUBIC, expand=True)
    r, g, b, a = im.split()
    rgb = ImageEnhance.Brightness(Image.merge("RGB", (r, g, b))).enhance(dark)
    rgb = ImageEnhance.Color(rgb).enhance(0.85)
    a = a.point(lambda v: int(v * strength))
    return Image.merge("RGBA", (*rgb.split(), a))


def stretch(im, sx, sy):
    return im.resize((int(im.width * sx), int(im.height * sy)), Image.LANCZOS)


def main():
    sheet = Image.new("RGBA", SIZE, (0, 0, 0, 0))

    def put(im, x, y):
        layer = Image.new("RGBA", SIZE, (0, 0, 0, 0))
        layer.paste(im, (int(x), int(y)))
        sheet.alpha_composite(layer)

    # The spatter in the upper right, its runs going down.
    put(piece("splatter.png", 660, turn=8, strength=0.74), 960, -150)
    # A smaller one low on the right, thrown the other way.
    put(piece("splatter.png", 380, turn=150, flip=True, strength=0.55), 1210, 470)
    # Something was dragged along the bottom, from the right toward the middle...
    put(stretch(piece("drag_smear.png", 760, turn=3, flip=True, strength=0.6), 1.5, 0.62), 470, 590)
    # ...and down the right edge.
    put(stretch(piece("drag_smear.png", 420, turn=-86, strength=0.42), 0.7, 1.15), 1310, 170)
    # A pool, most of it off the corner.
    put(piece("pool.png", 520, turn=20, strength=0.62, dark=0.5), 1290, 690)
    # The left of the screen stays clean: fade everything out toward it.
    alpha = sheet.getchannel("A")
    ramp = Image.new("L", SIZE)
    px = ramp.load()
    for x in range(SIZE[0]):
        t = min(1.0, max(0.0, (x - 430.0) / 330.0))
        v = int(255 * t * t * (3.0 - 2.0 * t))
        for y in range(SIZE[1]):
            px[x, y] = v
    from PIL import ImageChops
    sheet.putalpha(ImageChops.multiply(alpha, ramp))
    sheet.save(OUT)
    print("menu_blood", sheet.size, os.path.getsize(OUT) // 1024, "KB")
    if "preview" in sys.argv:
        work = os.path.join(ROOT, "work", "v31", "ui")
        os.makedirs(work, exist_ok=True)
        back = Image.new("RGBA", SIZE, (34, 40, 50, 255))
        back.alpha_composite(sheet)
        back.convert("RGB").save(os.path.join(work, "menu_blood.jpg"), quality=86)


if __name__ == "__main__":
    main()
