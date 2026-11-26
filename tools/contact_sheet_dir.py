"""Contact sheet of the PNG renders in a folder (for the 0.23 review passes).

    python tools/contact_sheet_dir.py <dir> [--suffix=-b.png] [--cols=3] [--width=533] [--out=sheet.jpg] [--gain=1.0]

Tiles every <dir>/*<suffix> in name order with its name on it; --gain brightens (dark night renders).
"""
import glob
import os
import sys

from PIL import Image, ImageDraw


def main():
    args = sys.argv[1:]
    folder = args[0]
    opts = dict(a[2:].split("=", 1) for a in args[1:] if a.startswith("--"))
    suffix = opts.get("suffix", ".png")
    cols = int(opts.get("cols", 3))
    w = int(opts.get("width", 533))
    gain = float(opts.get("gain", 1.0))
    files = sorted(f for f in glob.glob(os.path.join(folder, "*" + suffix)) if suffix != ".png" or not f.endswith("-b.png"))
    if not files:
        print("no files")
        return
    first = Image.open(files[0])
    h = int(w * first.height / first.width)
    rows = (len(files) + cols - 1) // cols
    sheet = Image.new("RGB", (w * cols, h * rows))
    for i, f in enumerate(files):
        im = Image.open(f).convert("RGB").resize((w, h))
        if gain != 1.0:
            im = im.point(lambda v: min(255, int(v * gain)))
        d = ImageDraw.Draw(im)
        label = os.path.basename(f)[: -len(suffix)]
        d.rectangle([0, 0, 7 * len(label) + 8, 16], fill=(0, 0, 0))
        d.text((4, 2), label, fill=(255, 255, 0))
        sheet.paste(im, ((i % cols) * w, (i // cols) * h))
    out = os.path.join(folder, opts.get("out", "sheet.jpg"))
    sheet.save(out, quality=86)
    print(out, len(files))


if __name__ == "__main__":
    main()
