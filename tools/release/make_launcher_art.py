"""Launcher icon and background, and the website's images (launcher/windows/Assets, launcher/shared, website/assets).

    python -I tools/release/make_launcher_art.py

The icon is game/assets/icon.svg drawn again at each size (it is three shapes). The pictures are captures of the game
from work/ (picked in SHOTS below): cropped to 16:9 from the top, where the debug captures carry objective text.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / "work"
SITE = ROOT / "website" / "assets"

# name on the site -> (capture, fraction of the height cut from the top, brightness)
SHOTS = {
    "hero-mart": ("v42/exe/coop_map_store.png", .07, 1.15),
    "squad-barricade": ("v42/exe/coop_barricade.png", .06, 1.1),
    "squad-store": ("v42/exe/coop_map_inside.png", .06, 1.1),
    "squad-street": ("v42/exe/coop_squad.png", .06, 1.15),
    "squad-down": ("v43/coop_down/down_04_side.png", .06, 1.15),
    "squad-markers": ("v58/markers/01_red_tag_down_marker_shine.png", .05, 1.1),
    "squad-grenade": ("v58/markers/02_grenade_in_flight.png", .05, 1.1),
    "lobby": ("v54/lobby/lobby_room.png", 0, 1.0),
    "gore-stump": ("v43/gore/gore-08-the-stump.png", .1, 1.05),
    "gore-leg": ("v43/gore/gore-11-leg-off-2.png", .1, 1.15),
    "gore-arm": ("v43/gore/gore-06-arm-off-3.png", .1, 1.15),
    "gore-shove": ("v42/exe/coop_gore_head.png", .06, 1.1),
    "zombie-close": ("v40/screens2/coop_rifle_hip.png", .14, 1.15),
    "squad-fight": ("v40/screens2/coop_squad_fighting.png", .14, 1.15),
    "heavyarm-charge": ("v54/cap3/heavy_charge.png", .1, 1.2),
    "heavyarm-roar": ("v54/cap3/heavy_roar_up.png", .1, 1.2),
    "night-road": ("v59/hut/27-road-moon-only.png", .1, 1.25),
    "night-street": ("v59/hut/26-street-b-moon-only.png", .1, 1.25),
    "hooded-man": ("v59/exe_capture/hut-6-hooded-man.png", .07, 1.2),
    "canal": ("v60/exe/canal-2-catwalk.png", .03, 1.15),
    "school-lobby": ("v57/exe/school/school_lobby.png", .05, 1.05),
    "school-door": ("v57/exe/school/school_door_burst_lit.png", .05, 1.1),
    "school-hall": ("v57/exe/school/school_story.png", .05, 1.15),
    "rice-fields": ("v59/hut/24-sirens.png", .1, 1.3),
    "house": ("v58/exe_capture/balcony-3-aquarium-wall.png", .05, 1.0),
}
# The infected are built from one body: outfit, hair, wounds and missing parts are chosen per person.
FACES = ["bumbero", "guro", "madre", "atleta", "dalaga", "estudyante", "janitor_s1", "karpintero", "lola", "biker",
         "doktor", "kusinero"]


def icon(size: int) -> Image.Image:
    s = 4 * size / 512  # drawn 4x, then reduced: smooth edges
    im = Image.new("RGBA", (4 * size, 4 * size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, 512 * s - 1, 512 * s - 1], radius=92 * s, fill="#241a12")

    def poly(points, colour, width):
        pts = [(x * s, y * s) for x, y in points]
        d.line(pts, fill=colour, width=max(1, int(width * s)), joint="curve")

    # the door frame: M92 392 V120 H420 V392, M92 120 l84 57 h244, M176 177 v215
    poly([(92, 392), (92, 120), (420, 120), (420, 392)], "#b48b5c", 18)
    poly([(92, 120), (176, 177), (420, 177)], "#b48b5c", 18)
    poly([(176, 177), (176, 392)], "#b48b5c", 18)
    # the bed: M250 221 h86 m-43 0 v120 m-43 0 h86
    for seg in ([(250, 221), (336, 221)], [(293, 221), (293, 341)], [(250, 341), (336, 341)]):
        poly(seg, "#f3e6ce", 24)
        for x, y in seg:
            r = 12 * s
            d.ellipse([x * s - r, y * s - r, x * s + r, y * s + r], fill="#f3e6ce")
    return im.resize((size, size), Image.LANCZOS)


def shot(src: Path, top: float, bright: float, width: int) -> Image.Image:
    im = Image.open(src).convert("RGB")
    w, h = im.size
    y0 = int(h * top)
    ch = min(h - y0, int(w * 9 / 16))
    im = im.crop((0, y0, w, y0 + ch))
    if bright != 1.0:
        im = ImageEnhance.Brightness(im).enhance(bright)
    if im.width > width:
        im = im.resize((width, int(im.height * width / im.width)), Image.LANCZOS)
    return im


def clean_mart() -> Image.Image:
    name, _top, bright = SHOTS["hero-mart"]
    im = Image.open(WORK / name).convert("RGB")
    w, h = im.size
    im = im.crop((int(w * .24), int(h * .07), w, int(h * .07) + int(w * .76 * 9 / 16)))
    im = im.crop((0, 0, im.width, min(im.height, int(h * .80))))
    return ImageEnhance.Brightness(im).enhance(bright).resize((1920, int(1920 * im.height / im.width)), Image.LANCZOS)


def main() -> None:
    assets = ROOT / "launcher" / "windows" / "Assets"
    assets.mkdir(parents=True, exist_ok=True)
    big = icon(256)
    big.save(assets / "app.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    big.save(assets / "icon_256.png")
    shared = ROOT / "launcher" / "shared"
    shared.mkdir(parents=True, exist_ok=True)
    # The mart at night without the capture's HUD (squad chat on the left, ammunition at the bottom right).
    clean = clean_mart()
    clean.save(shared / "background.jpg", quality=88)

    out = SITE / "shots"
    out.mkdir(parents=True, exist_ok=True)
    clean_mart().save(out / "hero-clean.jpg", quality=84, optimize=True, progressive=True)
    for key, (name, top, bright) in SHOTS.items():
        shot(WORK / name, top, bright, 1600).save(out / (key + ".jpg"), quality=82, optimize=True, progressive=True)
        shot(WORK / name, top, bright, 640).save(out / (key + "-s.jpg"), quality=78, optimize=True, progressive=True)
    faces = SITE / "infected"
    faces.mkdir(parents=True, exist_ok=True)
    for f in FACES:
        im = Image.open(WORK / "v44" / "zombies" / (f + "_q.png")).convert("RGB")
        im.thumbnail((360, 640), Image.LANCZOS)
        im.save(faces / (f + ".jpg"), quality=82, optimize=True)
    icon(512).save(SITE / "icon-512.png")
    icon(64).save(SITE / "favicon-64.png")
    icon(180).save(SITE / "apple-touch-icon.png")
    print("art written: %s, %s, %d shots, %d faces" % (assets / "app.ico", shared / "background.jpg", len(SHOTS), len(FACES)))


if __name__ == "__main__":
    main()
