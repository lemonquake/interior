"""Contact sheet for the Blender preview tiles (plain Python with PIL, not Blender).

  python tools/blender/contact_sheet.py <list.txt> <out.jpg> [columns] [tile_width]

list.txt: one "path<TAB>label" per line (the builders write it next to their tiles).
"""
import sys

from PIL import Image, ImageDraw


def main():
    src, out = sys.argv[1], sys.argv[2]
    cols = int(sys.argv[3]) if len(sys.argv) > 3 else 5
    tw = int(sys.argv[4]) if len(sys.argv) > 4 else 300
    rows = [ln.rstrip("\n").split("\t") for ln in open(src, encoding="utf-8") if ln.strip()]
    ims = []
    for path, label in rows:
        im = Image.open(path).convert("RGB")
        im = im.resize((tw, int(im.height * tw / im.width)), Image.LANCZOS)
        ims.append((im, label))
    th = max(im.height for im, _ in ims)
    n_rows = (len(ims) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * tw, n_rows * (th + 18)), (24, 24, 26))
    d = ImageDraw.Draw(sheet)
    for k, (im, label) in enumerate(ims):
        x, y = (k % cols) * tw, (k // cols) * (th + 18)
        sheet.paste(im, (x, y + 18))
        d.text((x + 4, y + 3), label, fill=(225, 225, 220))
    sheet.save(out, quality=88)
    print("SHEET", out, sheet.size)


if __name__ == "__main__":
    main()
