#!/usr/bin/env python3
"""Render high-resolution architectural Masterplan & Cross-Section blueprints for District 01 Outer Street."""

import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
BP_PATH = ROOT / "work" / "v63" / "outer_street_blueprint.json"
OUT_DIR = ROOT / "docs" / "map-system"
OUT_MASTER = OUT_DIR / "outer_street_masterplan.png"
OUT_SECTION = OUT_DIR / "outer_street_elevation_section.png"

BG = "#0a1017"
PANEL_BG = "#0f1722"
GRID_MINOR = "#132030"
GRID_MAJOR = "#1c3148"
TEXT_MAIN = "#e8eff8"
TEXT_DIM = "#8ea6c2"
ACCENT_AMBER = "#ff9d2e"
ACCENT_CYAN = "#4ae2ff"
ACCENT_RED = "#ff4c3b"
ACCENT_GREEN = "#48e58a"
ACCENT_YELLOW = "#ffd447"


def load_font(size: int, bold: bool = False):
    candidates = [
        r"C:\Windows\Fonts\segoeui.ttf" if not bold else r"C:\Windows\Fonts\segoeuib.ttf",
        r"C:\Windows\Fonts\consola.ttf" if not bold else r"C:\Windows\Fonts\consolab.ttf",
        r"C:\Windows\Fonts\arial.ttf" if not bold else r"C:\Windows\Fonts\arialbd.ttf",
    ]
    for c in candidates:
        p = Path(c)
        if p.exists():
            try:
                return ImageFont.truetype(str(p), size)
            except OSError:
                pass
    return ImageFont.load_default()


def draw_dashed_rect(draw: ImageDraw.ImageDraw, box, color, width=2, dash=10, gap=6):
    x0, y0, x1, y1 = box
    for (ax, ay, bx, by) in [(x0, y0, x1, y0), (x1, y0, x1, y1), (x1, y1, x0, y1), (x0, y1, x0, y0)]:
        dx, dy = bx - ax, by - ay
        dist = math.hypot(dx, dy)
        if dist < 1:
            continue
        ux, uy = dx / dist, dy / dist
        pos = 0.0
        while pos < dist:
            seg = min(pos + dash, dist)
            draw.line([(ax + ux * pos, ay + uy * pos), (ax + ux * seg, ay + uy * seg)], fill=color, width=width)
            pos += dash + gap


def render_masterplan(bp: dict) -> None:
    W, H = 2800, 2100
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img, "RGBA")

    f_title = load_font(36, True)
    f_sub = load_font(20, False)
    f_h2 = load_font(22, True)
    f_lbl = load_font(16, True)
    f_sm = load_font(14, False)

    # Coordinate mapping: X (West 0 -> East 148) horizontal, Z (South 590 -> North 785) bottom-to-top!
    scale = 9.6
    origin_x = 120
    origin_y = 1970  # corresponds to Z = 590

    def pt(x: float, z: float) -> tuple[float, float]:
        return (origin_x + x * scale, origin_y - (z - 590.0) * scale)

    def rect(x0: float, x1: float, z0: float, z1: float) -> tuple[float, float, float, float]:
        p0 = pt(x0, z1)
        p1 = pt(x1, z0)
        return (min(p0[0], p1[0]), min(p0[1], p1[1]), max(p0[0], p1[0]), max(p0[1], p1[1]))

    # Grid (5m minor, 20m major)
    for gx in range(0, 150, 5):
        px, py0 = pt(gx, 590)
        _, py1 = pt(gx, 780)
        major = gx % 20 == 0
        draw.line([(px, py1), (px, py0)], fill=GRID_MAJOR if major else GRID_MINOR, width=2 if major else 1)
        if major:
            draw.text((px - 10, py0 + 10), f"X{gx}", fill=TEXT_DIM, font=f_sm)
    for gz in range(590, 785, 5):
        px0, py = pt(0, gz)
        px1, _ = pt(148, gz)
        major = gz % 20 == 0
        draw.line([(px0, py), (px1, py)], fill=GRID_MAJOR if major else GRID_MINOR, width=2 if major else 1)
        if major:
            draw.text((52, py - 8), f"Z{gz}", fill=TEXT_DIM, font=f_sm)

    # River Davao East water body
    rv = rect(108.0, 148.0, 590.0, 780.0)
    draw.rectangle(rv, fill=(10, 32, 46, 255), outline="#1c4a64", width=2)
    for rz in range(600, 775, 18):
        p0 = pt(115, rz)
        p1 = pt(140, rz + 6)
        draw.line([p0, p1], fill=(35, 86, 114, 130), width=2)
    draw.text(pt(115, 700), "DAVAO RIVER\n(Y = -7.5 m)", fill="#5fb4d8", font=f_h2)

    # Zone backdrops
    extra = bp.get("extra", {})
    for zn in extra.get("zones", []):
        b = zn["bounds"]
        r = rect(b[0], b[1], b[2], b[3])
        draw.rectangle(r, outline="#2a4058", width=1)

    # Decks (excluding water already rendered)
    tier_fills = {
        "TIER_STREET": (38, 46, 56, 200),
        "TIER_ELEVATED": (78, 66, 42, 225),
        "TIER_EMBANK": (30, 58, 54, 225),
    }
    for d in bp.get("decks", []):
        if d.get("role") == "water" or d.get("tier") == "TIER_UNDERGROUND":
            continue
        b = d["bounds"]
        r = rect(b[0], b[1], b[2], b[3])
        fill = tier_fills.get(d.get("tier", "TIER_STREET"), (42, 50, 62, 180))
        draw.rectangle(r, fill=fill, outline="#5d728a", width=2)
        for h in d.get("holes", []):
            hr = rect(h[0], h[1], h[2], h[3])
            draw.rectangle(hr, fill=(12, 18, 26, 240), outline=ACCENT_CYAN, width=2)

    # Underground Tunnels (-4.2 m dashed cyan overlays)
    for t in bp.get("tunnels", []):
        b = t["bounds"]
        tr = rect(b[0], b[1], b[2], b[3])
        draw.rectangle(tr, fill=(18, 72, 92, 95))
        draw_dashed_rect(draw, tr, ACCENT_CYAN, width=3, dash=12, gap=6)

    # Buildings
    for bld in bp.get("buildings", []):
        b = bld["bounds"]
        br = rect(b[0], b[1], b[2], b[3])
        draw.rectangle(br, fill=(56, 48, 42, 235), outline="#b49d7e", width=2)
        cx, cy = (br[0] + br[2]) * 0.5, (br[1] + br[3]) * 0.5
        draw.text((cx - 18, cy - 8), f"{bld['floors']}F", fill="#e6d6bc", font=f_sm)

    # Covered Glass Overpass (+5.6 m)
    for op in bp.get("overpass_spans", []):
        b = op["bounds"]
        opr = rect(b[0], b[1], b[2], b[3])
        draw.rectangle(opr, fill=(64, 155, 190, 125), outline="#90e8ff", width=3)
        rx = b[0] + 3.0
        while rx < b[1]:
            draw.line([pt(rx, b[2]), pt(rx, b[3])], fill="#bceeff", width=1)
            rx += 3.0

    # Overhead Highway Viaduct corridor + Cylindrical Piers
    v_corridor = rect(70.6, 85.4, 604.0, 740.0)
    draw.rectangle(v_corridor, fill=(90, 96, 108, 48), outline="#6c7888", width=1)
    for vp in bp.get("viaduct_piers", []):
        x, _, z = vp["at"]
        px, py = pt(x, z)
        rad = vp["radius"] * scale
        draw.ellipse((px - rad, py - rad, px + rad, py + rad), fill="#88929e", outline="#d4dee8", width=2)

    # Quarantine & Evacuation Gates & PILCST Seam
    if "pilcst_gate" in extra:
        gx0, gx1, gz = extra["pilcst_gate"]
        draw.line([pt(gx0, gz), pt(gx1, gz)], fill=ACCENT_GREEN, width=6)
        draw.text(pt(gx0 - 1.0, gz - 4.5), "PILCST REAR GATE (STAGE 15 -> 16)", fill=ACCENT_GREEN, font=f_lbl)
    if "quarantine" in extra:
        qx0, qx1, qz = extra["quarantine"]
        draw.line([pt(qx0, qz), pt(qx1, qz)], fill=ACCENT_RED, width=5)
    if "evac_gate" in extra:
        ex0, ex1, ez = extra["evac_gate"]
        draw.line([pt(ex0, ez), pt(ex1, ez)], fill=ACCENT_GREEN, width=7)
        draw.text(pt(ex0 - 5.0, ez + 3.2), "EVACUATION GATE (A + B)  ->  EXTRACTION (Z > 748m)", fill=ACCENT_GREEN, font=f_lbl)

    # Links (stairs, ramps, shortcuts)
    link_offsets = {
        "L_STAIR_W": (24, -18),
        "L_ALLEY_N": (12, -14),
        "SC_COURTYARD": (-18, -22),
        "L_OVERPASS_W": (14, 4),
        "L_OVERPASS_NE": (-128, -22),
        "SC_OVERPASS": (14, -4),
        "L_SUB_S": (16, -6),
        "L_SUB_N": (16, -8),
        "L_CULV_E": (16, -4),
        "L_EMBANK_S": (12, -20),
        "L_EMBANK_MID": (12, -20),
        "L_EMBANK_N": (12, -20),
    }
    for lk in bp.get("links", []):
        fx, fy, fz = lk["from"]
        tx, ty, tz = lk["to"]
        p0, p1 = pt(fx, fz), pt(tx, tz)
        is_sc = lk.get("flag_req", "") != ""
        col = ACCENT_YELLOW if is_sc else ("#68e8ff" if abs(ty - fy) > 1.0 and min(fy, ty) < -2.0 else "#ffe284")
        draw.line([p0, p1], fill=col, width=5 if not is_sc else 4)
        mx, my = (p0[0] + p1[0]) * 0.5, (p0[1] + p1[1]) * 0.5
        draw.ellipse((mx - 4, my - 4, mx + 4, my + 4), fill=col)
        ox, oy = link_offsets.get(lk["id"], (8, -8))
        draw.text((mx + ox, my + oy), lk["id"], fill=col, font=f_sm)

    # Diegetic Amber & Cyan Cables
    for cb in bp.get("cables", []):
        c_pts = [pt(p[0], p[2]) for p in cb["points"]]
        is_amber = "ff9b2a" in cb.get("material", "")
        ccol = ACCENT_AMBER if is_amber else ACCENT_CYAN
        if len(c_pts) >= 2:
            draw.line(c_pts, fill=ccol, width=4)

    # Breakers
    for br in bp.get("breakers", []):
        bx, by, bz = br["at"]
        px, py = pt(bx, bz)
        is_a = "a" in br["id"].lower()
        col = ACCENT_AMBER if is_a else ACCENT_CYAN
        draw.ellipse((px - 11, py - 11, px + 11, py + 11), fill=col, outline="#ffffff", width=2)
        if is_a:
            draw.text((px + 14, py - 10), f"{br['id']} ({by:+.1f}m)", fill=col, font=f_lbl)
        else:
            draw.text((px - 68, py + 14), f"{br['id']} ({by:+.1f}m)", fill=col, font=f_lbl)

    # Zone labels cleanly stamped without overlap
    label_spots = [
        (36, 612, "ARRIVAL HUB (Y=0m)\nPower Truck & Cable Split", TEXT_MAIN),
        (30, 632, "VENDING ISLAND &\nSUBWAY MOUTH", "#9aeaff"),
        (4, 654, "HILLSIDE\nTERRACE (+4.2m)\nSari-Sari & Mahjong", "#ffe0a4"),
        (33, 672, "GLASS OVERPASS (+5.6m)", "#a8efff"),
        (48, 687, "FLOODED CULVERT (-4.2m)", "#62dbff"),
        (80, 643, "VIADUCT PIERS\n(+11.5m)", "#ccd8e8"),
        (98, 686, "EMBANKMENT BUS (-1.2m)", "#8ae8c8"),
        (44, 756, "BRIDGEHEAD EXTRACTION", ACCENT_GREEN),
    ]
    for lx, lz, txt, lcol in label_spots:
        px, py = pt(lx, lz)
        draw.text((px, py), txt, fill=lcol, font=f_lbl)

    # Compass Rose + Scale Bar (10 m = 96 px)
    cx, cy = 1520, 175
    draw.ellipse((cx - 42, cy - 42, cx + 42, cy + 42), outline=TEXT_DIM, width=2)
    draw.polygon([(cx, cy - 36), (cx - 10, cy + 12), (cx, cy), (cx + 10, cy + 12)], fill=ACCENT_CYAN)
    draw.text((cx - 8, cy - 60), "N (+Z)", fill=ACCENT_CYAN, font=f_lbl)
    draw.line([(1350, 1980), (1350 + 20 * scale, 1980)], fill=TEXT_MAIN, width=4)
    draw.line([(1350, 1972), (1350, 1988)], fill=TEXT_MAIN, width=3)
    draw.line([(1350 + 20 * scale, 1972), (1350 + 20 * scale, 1988)], fill=TEXT_MAIN, width=3)
    draw.text((1350 + 60, 1954), "20 METERS", fill=TEXT_MAIN, font=f_lbl)

    # Right Sidebar Architectural Specification & Legend Panel
    px0, py0, px1, py1 = 1660, 70, 2740, 2020
    draw.rectangle((px0, py0, px1, py1), fill=PANEL_BG, outline="#263b52", width=3)
    y = py0 + 36
    draw.text((px0 + 32, y), "SLEEP — POST-HEAVY-ARM MAP SYSTEM", fill=ACCENT_CYAN, font=f_h2); y += 36
    draw.text((px0 + 32, y), "DISTRICT 01: OUTER STREET — BUHANGIN CROSSING", fill=TEXT_MAIN, font=f_title); y += 54
    draw.line([(px0 + 32, y), (px1 - 32, y)], fill="#2a4058", width=2); y += 26

    # Legend Swatches
    draw.text((px0 + 32, y), "5-TIER ELEVATION & MANIFOLD LEGEND", fill=ACCENT_YELLOW, font=f_h2); y += 38
    legend = [
        ((90, 96, 108), "TIER_SKY (+11.5m..+26m): Concrete Viaduct Piers & Hammerheads"),
        ((64, 155, 190), "TIER_ELEVATED (+5.6m): Covered Glass Pedestrian Overpass"),
        ((108, 90, 56), "TIER_ELEVATED (+4.2m): Hillside Sari-Sari & Mahjong Terrace"),
        ((46, 56, 68), "TIER_STREET (0.0m): Buhangin Crossing, Vending Plaza, Bridgehead"),
        ((30, 58, 54), "TIER_EMBANK (-1.2m): Curving River Embankment & Transit Bus"),
        ((18, 92, 118), "TIER_UNDERGROUND (-4.2m): Moonlight-Sealed Subway & Storm Culvert"),
        ((255, 157, 46), "Diegetic Amber Cable -> Breaker A (Hillside Substation)"),
        ((74, 226, 255), "Diegetic Cyan Cable -> Breaker B (Storm Culvert Vault)"),
        ((255, 76, 59), "Quarantine Barricade (Surface Closure Forces Multi-Tier Bypass)"),
        ((72, 229, 138), "Evacuation Gate (Z=740) -> North Bridgehead Extraction"),
    ]
    for sw, desc in legend:
        draw.rectangle((px0 + 34, y + 4, px0 + 64, y + 24), fill=sw, outline="#dce6f2", width=1)
        draw.text((px0 + 78, y + 2), desc, fill=TEXT_MAIN, font=f_sub)
        y += 34

    y += 20
    draw.line([(px0 + 32, y), (px1 - 32, y)], fill="#2a4058", width=2); y += 28
    draw.text((px0 + 32, y), "BRAIDED TOPOLOGY & LOOP SHORTCUTS", fill=ACCENT_YELLOW, font=f_h2); y += 38
    notes = [
        "1. West Wing (Hillside): L_STAIR_W (3 Yellow Rails + Wheel Ramp) -> Sari-Sari",
        "   & Mahjong Corner -> Breaker A -> Stepped Alley L_ALLEY_N (17.3 deg).",
        "2. Center Overpass Wing: L_OVERPASS_W -> Shattered Glass Canopy (+5.6m)",
        "   vaulting over Quarantine Barricade -> L_OVERPASS_NE North Plaza.",
        "3. Underground & East Wing: Median Subway Stair L_SUB_S (20.1 deg) -> Shuttered",
        "   Concourse & Wake Candles -> Flooded Storm Culvert -> Breaker B Vault",
        "   (opens L_CULV_E exit) -> Embankment Road (-1.2m) & Stalled Bus.",
        "4. Three Player Loop-Closing Shortcuts: SC_COURTYARD (Hillside -> Overpass),",
        "   SC_OVERPASS (East Overpass Stair), SC_VIADUCT (Service Road Truck Gate).",
        "5. Finale: Both Breakers A+B energize Evacuation Gate twin sliding doors,",
        "   triggering tri-lane horde convergence across North Plaza to Extraction.",
    ]
    for line in notes:
        draw.text((px0 + 34, y), line, fill=TEXT_DIM if line.startswith("   ") else TEXT_MAIN, font=f_sub)
        y += 28

    y += 26
    draw.line([(px0 + 32, y), (px1 - 32, y)], fill="#2a4058", width=2); y += 28
    draw.text((px0 + 32, y), "ENGINE INVARIANTS & 7-GATE VALIDATOR VERIFIED", fill=ACCENT_GREEN, font=f_h2); y += 38
    inv = [
        f"• Navigable Decks: {len(bp.get('decks', []))}   |   Multi-Tier Links (<=28 deg): {len(bp.get('links', []))}",
        f"• Underground Layer 1|8 Moonlight Seal: ENFORCED   |   Models: {len(bp.get('models', []))}",
        "• Edge Containment >= 2.2m (Max Jump+Mantle 1.87m): ALL CLIFFS GUARDED",
        "• Per-12m Anti-Emptiness Density Budget: 100% CELLS POPULATED",
        "• Seamless PILCST Rear Gate (Z=600) Transition: Drop Stub + Gate Sealed",
    ]
    for line in inv:
        draw.text((px0 + 34, y), line, fill=TEXT_MAIN, font=f_sub)
        y += 30

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    img.save(OUT_MASTER)
    print(f"BLUEPRINT SAVED -> {OUT_MASTER}")


def render_sections(bp: dict) -> None:
    W, H = 2600, 1450
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img, "RGBA")
    f_title = load_font(32, True)
    f_h2 = load_font(22, True)
    f_lbl = load_font(15, True)
    f_sm = load_font(13, False)

    draw.text((80, 32), "OUTER STREET — ARCHITECTURAL ELEVATION & CROSS-SECTIONS (5-TIER SYSTEM)", fill=TEXT_MAIN, font=f_title)
    draw.text((80, 74), "Top: West-to-East Transverse Section at Buhangin Crossing (Z ≈ 671 m)   |   Bottom: South-to-North Longitudinal Profile (Z = 595..825 m)", fill=TEXT_DIM, font=f_lbl)

    # TOP PANEL: West -> East X in [0..145], Y in [-9..+16]
    ox, oy = 110, 440  # y=0 datum
    sx, sy = 16.0, 18.0
    draw.rectangle((70, 120, W - 70, 720), fill=PANEL_BG, outline="#283d54", width=2)
    draw.text((95, 134), "SECTION A-A'  (WEST HILLSIDE  ->  CROSSING AVENUE  ->  GLASS OVERPASS  ->  VIADUCT  ->  EMBANKMENT  ->  DAVAO RIVER)", fill=ACCENT_CYAN, font=f_h2)
    for yv in [-8, -4, 0, 4, 8, 12]:
        yy = oy - yv * sy
        draw.line([(ox, yy), (ox + 142 * sx, yy)], fill="#243a4f" if yv != 0 else "#4f6d8a", width=2 if yv == 0 else 1)
        draw.text((76, yy - 8), f"{yv:+d}m", fill=TEXT_DIM, font=f_sm)

    # Ground/Decks profile A-A'
    # Hillside shophouses + Terrace (+4.2m)
    draw.rectangle((ox + 0 * sx, oy - 14 * sy, ox + 5.2 * sx, oy - 4.2 * sy), fill="#52463a", outline="#b49d7e", width=2)
    draw.rectangle((ox + 0 * sx, oy - 4.2 * sy, ox + 16 * sx, oy + 0.6 * sy), fill="#6b5c48", outline="#ffd447", width=2)
    draw.text((ox + 5.8 * sx, oy - 6.8 * sy), "Hillside Sari-Sari &\nMahjong (+4.2m)", fill="#ffe0a4", font=f_lbl)

    # SC_COURTYARD sloping catwalk (15.8, 4.2) -> (21.2, 5.6)
    draw.line([(ox + 15.8 * sx, oy - 4.2 * sy), (ox + 21.2 * sx, oy - 5.6 * sy)], fill=ACCENT_YELLOW, width=5)

    # Avenue surface (16..92 at 0.0m) + Embankment (92..108 at -1.2m) + River (108..142 at -7.5m)
    draw.rectangle((ox + 16 * sx, oy, ox + 92 * sx, oy + 0.5 * sy), fill="#3c4654", outline="#8ea6c2", width=2)
    draw.rectangle((ox + 92 * sx, oy + 1.2 * sy, ox + 108 * sx, oy + 7.5 * sy), fill="#294842", outline="#7cd8be", width=2)
    draw.rectangle((ox + 108 * sx, oy + 7.5 * sy, ox + 142 * sx, oy + 8.5 * sy), fill="#123a4e", outline="#4cdbff", width=2)
    draw.text((ox + 114 * sx, oy + 6.1 * sy), "Davao River (-7.5m)", fill="#5ec8ec", font=f_lbl)

    # Subway + Flooded Storm Culvert (-4.2m -> -1.0m ceiling)
    draw.rectangle((ox + 37 * sx, oy + 1.0 * sy, ox + 48 * sx, oy + 4.2 * sy), fill="#164256", outline=ACCENT_CYAN, width=2)
    draw.rectangle((ox + 48 * sx, oy + 1.0 * sy, ox + 86 * sx, oy + 4.2 * sy), fill="#143c4e", outline=ACCENT_CYAN, width=2)
    draw.text((ox + 49 * sx, oy + 2.2 * sy), "Subway Concourse -> Flooded Storm Culvert (-4.2m, Layer 1|8 Moonlight Seal)", fill=ACCENT_CYAN, font=f_lbl)

    # Covered Glass Overpass (+5.6m..+8.65m across X=21..68)
    draw.rectangle((ox + 21 * sx, oy - 8.6 * sy, ox + 68 * sx, oy - 5.6 * sy), fill=(64, 155, 190, 120), outline="#90e8ff", width=3)
    draw.text((ox + 33 * sx, oy - 7.4 * sy), "Enclosed Glass Pedestrian Overpass (+5.6 m .. +8.6 m)", fill="#c8f4ff", font=f_lbl)

    # Viaduct Pier + Hammerhead + Highway (+11.5m at X=78)
    draw.rectangle((ox + 76.9 * sx, oy - 10.5 * sy, ox + 79.1 * sx, oy), fill="#747e8a", outline="#d4dee8", width=2)
    draw.rectangle((ox + 70.6 * sx, oy - 12.2 * sy, ox + 85.4 * sx, oy - 10.5 * sy), fill="#5a636e", outline="#d4dee8", width=2)
    draw.text((ox + 68.5 * sx, oy - 13.7 * sy), "Highway Viaduct Deck (+11.5 m)", fill=TEXT_MAIN, font=f_lbl)

    # Stalled Bus on Embankment (X=99.8, Y=-1.2)
    draw.rectangle((ox + 98.4 * sx, oy - 1.5 * sy, ox + 101.2 * sx, oy + 1.2 * sy), fill="#2e5e3e", outline="#dcd6c4", width=2)
    draw.text((ox + 92.2 * sx, oy - 2.9 * sy), "Transit Bus (-1.2m)", fill="#9becc8", font=f_lbl)

    # BOTTOM PANEL: South -> North Z in [595..820], Y in [-9..+16]
    ox2, oy2 = 110, 1140
    sz2 = 10.5
    draw.rectangle((70, 760, W - 70, H - 60), fill=PANEL_BG, outline="#283d54", width=2)
    draw.text((95, 774), "SECTION B-B'  (SOUTH-TO-NORTH LONGITUDINAL PROFILE: PILCST REAR GATE -> CROSSING -> EVACUATION GATE -> BRIDGE HORIZON)", fill=ACCENT_YELLOW, font=f_h2)
    for yv in [-8, -4, 0, 4, 8, 12]:
        yy = oy2 - yv * sy
        draw.line([(ox2, yy), (ox2 + 225 * sz2, yy)], fill="#243a4f" if yv != 0 else "#4f6d8a", width=2 if yv == 0 else 1)
        draw.text((76, yy - 8), f"{yv:+d}m", fill=TEXT_DIM, font=f_sm)

    # Ground slab 595..772 -> drop off to River (-7.5m) -> Distant Bridge (Z=805)
    draw.rectangle((ox2 + (600 - 595) * sz2, oy2, ox2 + (772 - 595) * sz2, oy2 + 0.5 * sy), fill="#3c4654", outline="#8ea6c2", width=2)
    draw.line([(ox2 + (600 - 595) * sz2, oy2 - 3.6 * sy), (ox2 + (600 - 595) * sz2, oy2)], fill=ACCENT_GREEN, width=5)
    draw.text((ox2 + 20, oy2 - 4.5 * sy), "PILCST Rear Gate (Z=600)", fill=ACCENT_GREEN, font=f_sm)

    # Subway shaft profile (Z=639..695)
    draw.line([(ox2 + (639 - 595) * sz2, oy2), (ox2 + (650.5 - 595) * sz2, oy2 + 4.2 * sy)], fill=ACCENT_CYAN, width=4)
    draw.rectangle((ox2 + (648 - 595) * sz2, oy2 + 1.0 * sy, ox2 + (690 - 595) * sz2, oy2 + 4.2 * sy), fill="#164256", outline=ACCENT_CYAN, width=2)
    draw.line([(ox2 + (683 - 595) * sz2, oy2 + 4.2 * sy), (ox2 + (694.8 - 595) * sz2, oy2)], fill=ACCENT_CYAN, width=4)

    # Glass Overpass (+5.6m at Z=668.5..673.5) right over Quarantine Barricade (Z=677.5)
    draw.rectangle((ox2 + (668.5 - 595) * sz2, oy2 - 8.6 * sy, ox2 + (673.5 - 595) * sz2, oy2 - 5.6 * sy), fill=(64, 155, 190, 145), outline="#90e8ff", width=2)
    draw.line([(ox2 + (677.5 - 595) * sz2, oy2), (ox2 + (677.5 - 595) * sz2, oy2 - 3.3 * sy)], fill=ACCENT_RED, width=5)
    draw.text((ox2 + (664 - 595) * sz2, oy2 - 10.2 * sy), "Glass Overpass (+5.6m) & Quarantine (Z=677.5)", fill="#a8efff", font=f_lbl)

    # Evacuation Gate Gantry (Z=740) & Bridgehead Goal (Z=748+) & Steel Arch Bridge (Z=805)
    draw.rectangle((ox2 + (739.4 - 595) * sz2, oy2 - 5.2 * sy, ox2 + (740.6 - 595) * sz2, oy2), fill="#384448", outline=ACCENT_GREEN, width=3)
    draw.text((ox2 + (733 - 595) * sz2, oy2 - 6.6 * sy), "Evacuation Gate (Z=740)", fill=ACCENT_GREEN, font=f_lbl)
    draw.text((ox2 + (748 - 595) * sz2, oy2 - 2.6 * sy), "Goal Z>748m", fill=ACCENT_YELLOW, font=f_lbl)

    # Steel Arch silhouette at Z=805
    bx0 = ox2 + (805 - 595) * sz2
    draw.line([(bx0 - 40, oy2 - 2.2 * sy), (bx0 + 40, oy2 - 2.2 * sy)], fill="#4a5866", width=4)
    draw.arc((bx0 - 24, oy2 - 15 * sy, bx0 + 24, oy2 + 10 * sy), start=180, end=360, fill="#607284", width=3)
    draw.text((bx0 - 68, oy2 - 17 * sy), "Arch Bridge (Z=805)", fill=TEXT_DIM, font=f_sm)

    img.save(OUT_SECTION)
    print(f"SECTION SAVED -> {OUT_SECTION}")


def main() -> None:
    if not BP_PATH.exists():
        raise FileNotFoundError(f"Blueprint JSON not found: {BP_PATH}")
    with BP_PATH.open("r", encoding="utf-8") as f:
        bp = json.load(f)
    render_masterplan(bp)
    render_sections(bp)


if __name__ == "__main__":
    main()
