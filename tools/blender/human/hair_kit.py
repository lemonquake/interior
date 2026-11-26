"""Layered 3D strand-lock hair generator and procedural strand-texture baker for Interior characters.

Shared by both player survivors (build_survivors.py) and infected zombies (build_zombies.py).
Provides 17 sculpted strand-layered hairstyles (+ 'bald'), each fitted precisely to the character's
shaped skull via BVHTree so locks follow head/neck/shoulder contours cleanly with zero clipping.

Every lock carries root-to-tip V and cross-strand U coordinates mapped onto a procedural 512x512
hair fiber albedo + normal map (clean & silky for survivors; optionally matted, grimy, and
blood-flecked for zombies).
"""
import math
import os
import random

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

STYLES = [
    "buzz_fade",
    "textured_crop",
    "side_part",
    "slick_back",
    "textured_spiky",
    "undercut_quiff",
    "curtain_part",
    "wavy_shag",
    "curly_afro",
    "chin_bob",
    "long_straight",
    "long_disheveled",
    "high_bun",
    "ponytail",
    "twin_pigtails",
    "thinning_receding",
    "patchy_rotted",
]

ALIASES = {
    "crop": "textured_crop",
    "spiky": "textured_spiky",
    "slick": "slick_back",
    "sidepart": "side_part",
    "bowl": "curtain_part",
    "curly": "curly_afro",
    "long": "long_straight",
    "bob": "chin_bob",
    "bun": "high_bun",
}

LONG_STYLES = {"long_straight", "long_disheveled", "ponytail", "twin_pigtails", "wavy_shag"}


def canonical_style(name):
    if not name or name == "bald":
        return "bald"
    return ALIASES.get(name, name)


# ---------------------------------------------------------------- procedural hair strand textures

def _smooth(a, b, x):
    t = np.clip((x - a) / max(b - a, 1e-6), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _vnoise2d(u, v, fu, fv, seed):
    qu = u * fu
    qv = v * fv
    iu = np.floor(qu).astype(np.int64)
    iv = np.floor(qv).astype(np.int64)
    tu = (qu - iu).astype(np.float32)
    tv = (qv - iv).astype(np.float32)
    tu = tu * tu * (3.0 - 2.0 * tu)
    tv = tv * tv * (3.0 - 2.0 * tv)

    def h(x, y):
        n = x * 374761393 + y * 668265263 + seed * 1442695
        n = (n ^ (n >> 13)) * 1274126177
        return ((n ^ (n >> 16)) & 0xFFFF).astype(np.float32) / 65535.0

    c00 = h(iu, iv)
    c10 = h(iu + 1, iv)
    c01 = h(iu, iv + 1)
    c11 = h(iu + 1, iv + 1)
    return (c00 * (1 - tu) + c10 * tu) * (1 - tv) + (c01 * (1 - tu) + c11 * tu) * tv


def make_hair_textures(name, base_color, work_dir, seed=1, grey_mix=0.0, zombie_grime=0.0, size=512):
    """Bakes a strand-aligned hair albedo JPG and normal JPG; returns (albedo_img, normal_img)."""
    os.makedirs(work_dir, exist_ok=True)
    y = np.linspace(0.0, 1.0, size, dtype=np.float32)  # v: 0 = root, 1 = tip
    x = np.linspace(0.0, 1.0, size, dtype=np.float32)  # u: across lock
    u, v = np.meshgrid(x, y)

    # Fine longitudinal hair fibers along V.
    wav = 0.008 * np.sin(v * math.tau * 2.0 + seed) + 0.004 * np.sin(v * math.tau * 5.0 + u * 6.0)
    us = (u + wav) % 1.0
    s1 = _vnoise2d(us, v, 112.0, 4.0, seed + 1)
    s2 = _vnoise2d(us, v, 240.0, 7.0, seed + 7)
    s3 = _vnoise2d(us, v, 44.0, 2.5, seed + 13)
    strands = 0.44 * s1 + 0.36 * s2 + 0.20 * s3

    tile_u = (u * 4.0) % 1.0
    edge_ao = 0.78 + 0.22 * np.sin(tile_u * math.pi) ** 0.55

    # Root-to-tip tonal depth: deeper at scalp, rich mid-shaft, softly weathered tips.
    root_ao = 0.58 + 0.42 * _smooth(0.0, 0.20, v)
    tip_lift = 1.0 + 0.14 * _smooth(0.70, 1.0, v)

    base = np.asarray(base_color, np.float32)
    base = np.maximum(base, np.array((0.026, 0.023, 0.021), np.float32))
    hi = np.clip(base * np.array((1.85, 1.72, 1.56), np.float32) + 0.032, 0.0, 1.0)
    lo = base * 0.46
    t = np.clip((strands - 0.18) / 0.66, 0.0, 1.0)
    rgb = lo[None, None, :] * (1.0 - t[..., None]) + hi[None, None, :] * t[..., None]

    if grey_mix > 0.01:
        g_mask = _smooth(1.0 - grey_mix * 0.95, 1.0 - grey_mix * 0.32, _vnoise2d(us, v, 76.0, 2.0, seed + 29))
        grey_col = np.array((0.66, 0.65, 0.63), np.float32) * (0.76 + 0.34 * strands[..., None])
        rgb = rgb * (1.0 - g_mask[..., None]) + grey_col * g_mask[..., None]

    rgb *= (root_ao * edge_ao * tip_lift)[..., None]

    if zombie_grime > 0.01:
        clump = _smooth(0.45, 0.78, _vnoise2d(u, v, 10.0, 6.0, seed + 41)) * zombie_grime
        dirt = np.array((0.14, 0.11, 0.08), np.float32)
        rgb = rgb * (1.0 - clump[..., None] * 0.55) + dirt[None, None, :] * (clump[..., None] * 0.55)
        blood_m = _smooth(0.56, 0.80, _vnoise2d(u, v, 9.0, 7.0, seed + 53)) * _smooth(0.32, 0.92, v) * zombie_grime
        blood_col = np.array((0.22, 0.022, 0.018), np.float32)
        rgb = rgb * (1.0 - blood_m[..., None] * 0.78) + blood_col[None, None, :] * (blood_m[..., None] * 0.78)

    # Strand normal map: sharp fine fiber ridges + gentle lock curvature.
    height = strands * 0.72 + 0.28 * np.sin(tile_u * math.pi)
    gy, gx = np.gradient(height)
    nx = -gx * 4.2
    ny = gy * 1.2
    nz = np.ones_like(height)
    inv = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)
    nrgb = np.stack([(nx * inv) * 0.5 + 0.5, (-ny * inv) * 0.5 + 0.5, (nz * inv) * 0.5 + 0.5], axis=-1)

    def _save(img_name, arr, colorspace):
        img = bpy.data.images.new(img_name, size, size, alpha=False)
        rgba = np.ones((size, size, 4), np.float32)
        rgba[..., :3] = np.clip(arr, 0.0, 1.0)
        img.pixels.foreach_set(rgba.ravel())
        img.filepath_raw = os.path.join(work_dir, img_name + ".jpg")
        img.file_format = "JPEG"
        img.save()
        img.pack()
        img.colorspace_settings.name = colorspace
        return img

    alb = _save(name + "_hair", rgb, "sRGB")
    nrm = _save(name + "_hair_nrm", nrgb, "Non-Color")
    return alb, nrm


def make_hair_material(mat_name, tex_prefix, base_color, work_dir, seed=1, grey_mix=0.0, zombie_grime=0.0):
    alb, nrm = make_hair_textures(tex_prefix, base_color, work_dir, seed=seed, grey_mix=grey_mix,
                                  zombie_grime=zombie_grime)
    m = bpy.data.materials.new(mat_name)
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.50 + 0.24 * min(zombie_grime, 1.0)
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.36 if zombie_grime < 0.2 else 0.22
    if "Sheen Weight" in bsdf.inputs:
        bsdf.inputs["Sheen Weight"].default_value = 0.25 if zombie_grime < 0.2 else 0.06

    tex_a = nt.nodes.new("ShaderNodeTexImage")
    tex_a.image = alb
    nt.links.new(tex_a.outputs["Color"], bsdf.inputs["Base Color"])

    tex_n = nt.nodes.new("ShaderNodeTexImage")
    tex_n.image = nrm
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nmap.inputs["Strength"].default_value = 0.78
    nt.links.new(tex_n.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])

    m.use_backface_culling = False
    return m


# ---------------------------------------------------------------- head measurement & BVH

def measure_head(ref):
    co = np.array([v.co[:] for v in ref.data.vertices], np.float32)
    head = co[(co[:, 2] > 1.56) & (np.abs(co[:, 0]) < 0.14)]
    crown_z = float(head[:, 2].max())
    upper = head[head[:, 2] > crown_z - 0.14]
    cy = float((upper[:, 1].min() + upper[:, 1].max()) * 0.5)
    cz = crown_z - 0.105
    rx = float(np.abs(upper[:, 0]).max())
    return {
        "center": Vector((0.0, cy, cz)),
        "crown_z": crown_z,
        "rx": rx,
        "ymin": float(head[:, 1].min()),
        "ymax": float(head[:, 1].max()),
    }


def _region_bvh(ref, z_min=1.22, x_max=0.32):
    bm = bmesh.new()
    bm.from_mesh(ref.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < z_min or abs(v.co.x) > x_max], context="VERTS")
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    return tree


def _skull_point(tree, center, direction, offset):
    """Projects a ray onto the skull along `direction` and offsets outward by `offset`."""
    d = direction.normalized()
    hit = tree.ray_cast(center + d * 0.32, -d, 0.34)
    if hit[0] is not None:
        n = hit[1].normalized() if hit[1].length > 1e-5 else d
        return hit[0] + n * offset, n
    loc, n, _i, _dist = tree.find_nearest(center + d * 0.11)
    if loc is not None:
        n = n.normalized() if n.length > 1e-5 else d
        return loc + n * offset, n
    return center + d * (0.10 + offset), d


def _push_outside(tree, pt, min_gap):
    loc, n, _i, dist = tree.find_nearest(pt)
    if loc is None:
        return pt, Vector((0, 0, 1))
    delta = pt - loc
    if delta.dot(n) < 0.0:
        return loc + n * min_gap, n
    if dist < min_gap:
        out = delta.normalized() if delta.length > 1e-5 else n
        return loc + out * min_gap, out
    return pt, (delta.normalized() if delta.length > 1e-5 else n)


# ---------------------------------------------------------------- lock & cap geometry builders

def _add_lock(bm, uv_layer, pts, normals, width, thick, u_tile=0, taper_root=0.68, arch=0.85, root_tuck=0.0):
    """Adds a 5-wide sculpted arched hair lock along `pts` with root->tip V and tiled U."""
    m = len(pts)
    if m < 2:
        return
    u0 = (u_tile % 4) * 0.25 + 0.015
    u1 = u0 + 0.22
    rings = []
    profile = [(-1.0, 0.0), (-0.48, 0.72 * arch), (0.0, 1.0 * arch), (0.48, 0.72 * arch), (1.0, 0.0)]
    u_fracs = [0.0, 0.25, 0.5, 0.75, 1.0]

    for i in range(m):
        s = i / (m - 1)
        p = pts[i].copy()
        n = normals[i].normalized() if normals[i].length > 1e-5 else Vector((0, 0, 1))
        if root_tuck != 0.0 and i == 0:
            p -= n * root_tuck
        if i == 0:
            t = (pts[1] - pts[0])
        elif i == m - 1:
            t = (pts[-1] - pts[-2])
        else:
            t = (pts[i + 1] - pts[i - 1])
        t = t.normalized() if t.length > 1e-6 else Vector((0, 0, -1))
        b = t.cross(n)
        if b.length < 1e-5:
            b = t.cross(Vector((1, 0, 0)))
            if b.length < 1e-5:
                b = Vector((0, 1, 0))
        b.normalize()
        n = b.cross(t).normalized()

        if s < 0.16:
            w_env = taper_root + (1.0 - taper_root) * (s / 0.16)
        else:
            w_env = math.pow(max(0.0, 1.0 - (s - 0.16) / 0.84), 0.75)
        w = max(0.001, width * (0.05 + 0.95 * w_env))
        th = max(0.0005, thick * (0.14 + 0.86 * (1.0 - 0.68 * s)))

        if i == m - 1:
            tip_v = bm.verts.new(p + n * (th * 0.2))
            rings.append([tip_v])
        else:
            ring = []
            for sf, hf in profile:
                ring.append(bm.verts.new(p + b * (sf * w) + n * (hf * th)))
            rings.append(ring)

    for i in range(m - 1):
        v0 = i / (m - 1)
        v1 = (i + 1) / (m - 1)
        r0 = rings[i]
        r1 = rings[i + 1]
        if len(r1) == 1:
            tip = r1[0]
            for k in range(len(r0) - 1):
                try:
                    f = bm.faces.new((r0[k], r0[k + 1], tip))
                    f.smooth = True
                    f.loops[0][uv_layer].uv = (u0 + (u1 - u0) * u_fracs[k], v0)
                    f.loops[1][uv_layer].uv = (u0 + (u1 - u0) * u_fracs[k + 1], v0)
                    f.loops[2][uv_layer].uv = ((u0 + u1) * 0.5, 1.0)
                except ValueError:
                    pass
        else:
            for k in range(len(r0) - 1):
                try:
                    f = bm.faces.new((r0[k], r0[k + 1], r1[k + 1], r1[k]))
                    f.smooth = True
                    f.loops[0][uv_layer].uv = (u0 + (u1 - u0) * u_fracs[k], v0)
                    f.loops[1][uv_layer].uv = (u0 + (u1 - u0) * u_fracs[k + 1], v0)
                    f.loops[2][uv_layer].uv = (u0 + (u1 - u0) * u_fracs[k + 1], v1)
                    f.loops[3][uv_layer].uv = (u0 + (u1 - u0) * u_fracs[k], v1)
                except ValueError:
                    pass


def _hairline_z(az, hinfo, hairline_shift=0.0, nape_drop=0.0):
    """Natural human hairline elevation vs azimuth `az` (0 = forehead center, +-pi = nape)."""
    c = math.cos(az)
    a = abs(az)
    crown = hinfo["crown_z"]
    # Higher natural forehead line with gentle temple recess, sideburn dip, ear arch, and low nape.
    forehead = crown - 0.074 + hairline_shift
    temple_recess = 0.011 * math.exp(-((a - 0.68) / 0.25) ** 2)
    sideburn_dip = -0.032 * math.exp(-((a - 1.18) / 0.18) ** 2)
    ear_arch = 0.022 * math.exp(-((a - 1.58) / 0.22) ** 2)
    back_drop = (0.125 + nape_drop) * max(0.0, -c) ** 1.28
    return forehead + temple_recess + sideburn_dip + ear_arch - back_drop


def _add_scalp_cap(bm, uv_layer, tree, hinfo, offset=0.0045, hairline_shift=0.0, nape_drop=0.0,
                   recede=0.0, patchy_seed=None):
    """Builds a smooth fitted scalp under-cap whose hairline tucks seamlessly into the skull (no ledge!)."""
    center = hinfo["center"]
    n_az = 40
    n_r = 10
    grid = []
    for ri in range(n_r):
        t = ri / (n_r - 1)
        row = []
        for ai in range(n_az):
            az = -math.pi + (ai / n_az) * math.tau
            z_edge = _hairline_z(az, hinfo, hairline_shift=hairline_shift, nape_drop=nape_drop)
            if recede > 0.0:
                front_w = max(0.0, math.cos(az)) ** 1.4
                z_edge += recede * front_w
            el_edge = math.atan2(z_edge - center.z, 0.105)
            el = math.pi * 0.495 * (1.0 - t) + el_edge * t
            d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
            # Smoothly taper offset right at the very edge so it hugs the skin cleanly without z-clipping or forming a ledge.
            if t < 0.84:
                off = offset
            else:
                e = (t - 0.84) / 0.16
                off = offset * (1.0 - e * e) + 0.0006 * (e * e)
            pt, _n = _skull_point(tree, center, d, off)
            row.append((bm.verts.new(pt), t, az))
        grid.append(row)

    for ri in range(n_r - 1):
        for ai in range(n_az):
            an = (ai + 1) % n_az
            if patchy_seed is not None:
                az = -math.pi + (ai / n_az) * math.tau
                h_val = math.sin(az * 3.1 + patchy_seed) * math.cos(ri * 0.85 + patchy_seed * 0.7)
                if h_val > 0.20:
                    continue
            v00, t0, _ = grid[ri][ai]
            v01, _, _ = grid[ri][an]
            v11, t1, _ = grid[ri + 1][an]
            v10, _, _ = grid[ri + 1][ai]
            u0 = (ai / n_az) * 4.0
            u1 = ((ai + 1) / n_az) * 4.0
            try:
                f = bm.faces.new((v00, v10, v11, v01))
                f.smooth = True
                f.loops[0][uv_layer].uv = (u0, t0)
                f.loops[1][uv_layer].uv = (u0, t1)
                f.loops[2][uv_layer].uv = (u1, t1)
                f.loops[3][uv_layer].uv = (u1, t0)
            except ValueError:
                pass


def _grow_surface_lock(tree, center, az0, el0, d_az, d_el, length_steps, base_off, tip_off,
                       wave_amp=0.0, wave_freq=2.0, phase=0.0, lift_mid=0.0):
    pts, norms = [], []
    for i in range(length_steps):
        s = i / (length_steps - 1)
        az = az0 + d_az * s + wave_amp * math.sin(s * math.pi * wave_freq + phase) * 0.55
        el = el0 + d_el * s
        d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
        off = base_off * (1.0 - s) + tip_off * s + lift_mid * math.sin(s * math.pi)
        pt, n = _skull_point(tree, center, d, off)
        pts.append(pt)
        norms.append(n)
    return pts, norms


def _grow_hanging_lock(tree, body_tree, start_pt, start_n, flow_dir, length, steps,
                       wave_amp=0.006, wave_freq=2.0, phase=0.0, curl_in=0.0, min_gap=0.009,
                       gravity=0.90, splay=0.04):
    pts = [start_pt.copy()]
    norms = [start_n.normalized()]
    cur = start_pt.copy()
    vel = flow_dir.normalized()
    step_len = length / (steps - 1)
    side = vel.cross(start_n)
    if side.length < 1e-4:
        side = Vector((1, 0, 0))
    side.normalize()

    for i in range(1, steps):
        s = i / (steps - 1)
        down = Vector((splay * start_n.x, splay * start_n.y, -1.0)).normalized()
        dir_now = vel.lerp(down, min(1.0, s * 1.55 * gravity)).normalized()
        w = wave_amp * math.sin(s * math.pi * wave_freq + phase) * min(1.0, s * 2.0)
        nxt = cur + dir_now * step_len + side * (w * 0.30) + start_n * (curl_in * s * s)
        nxt, out_n = _push_outside(body_tree, nxt, min_gap + 0.0025 * s)
        pts.append(nxt)
        norms.append(out_n.lerp(start_n, 0.35).normalized())
        cur = nxt
    return pts, norms


# ---------------------------------------------------------------- 17 distinct sculpted hairstyles

def _build_buzz_fade(bm, uv, tree, body_tree, hinfo, rng):
    """Crisp modern military/barber buzz fade: tight close-cropped crown with tapered faded sides."""
    _add_scalp_cap(bm, uv, tree, hinfo, offset=0.0052, hairline_shift=0.004)
    c = hinfo["center"]
    for i in range(72):
        az = rng.uniform(-math.pi, math.pi)
        el = rng.uniform(0.32, 1.44)
        front = max(0.0, math.cos(az))
        d_el = -rng.uniform(0.20, 0.34)
        d_az = rng.uniform(-0.08, 0.08)
        pts, norms = _grow_surface_lock(tree, c, az, el, d_az, d_el, 5, 0.0048, 0.0066 + 0.0015 * front,
                                        lift_mid=0.001)
        _add_lock(bm, uv, pts, norms, rng.uniform(0.015, 0.022), 0.0022, i, taper_root=0.78, arch=0.4)


def _build_textured_crop(bm, uv, tree, body_tree, hinfo, rng):
    """Modern Filipino short messy crop: sleek faded sides, layered choppy forward-swept fringe."""
    _add_scalp_cap(bm, uv, tree, hinfo, offset=0.005, hairline_shift=0.003)
    c = hinfo["center"]
    # Sleek tapered sides & back.
    for i in range(40):
        az = rng.uniform(-math.pi, math.pi)
        if abs(az) < 0.72:
            continue
        el = rng.uniform(0.18, 0.85)
        pts, norms = _grow_surface_lock(tree, c, az, el, rng.uniform(-0.10, 0.10), -rng.uniform(0.30, 0.45),
                                        5, 0.004, 0.0065, lift_mid=0.0015)
        _add_lock(bm, uv, pts, norms, rng.uniform(0.015, 0.022), 0.0035, i, arch=0.55, root_tuck=0.002)
    # Layered longer forward-swept crown locks.
    for i in range(56):
        az = rng.uniform(-math.pi, math.pi)
        el = rng.uniform(0.65, 1.48)
        front = max(0.0, math.cos(az))
        d_el = -rng.uniform(0.38, 0.62) - 0.16 * front
        d_az = -math.sin(az) * 0.22 * front + rng.uniform(-0.12, 0.12)
        pts, norms = _grow_surface_lock(tree, c, az, el, d_az, d_el, 6, 0.0055, 0.010 + 0.005 * front,
                                        wave_amp=0.035, phase=rng.uniform(0, 6.28), lift_mid=0.004)
        _add_lock(bm, uv, pts, norms, rng.uniform(0.015, 0.022), 0.0048, i, arch=0.72, root_tuck=0.002)
    # Choppy feathered forehead bangs overlapping the hairline smoothly.
    for i in range(22):
        az = -0.84 + (i / 21.0) * 1.68 + rng.uniform(-0.03, 0.03)
        el = rng.uniform(0.58, 0.92)
        pts, norms = _grow_surface_lock(tree, c, az, el, rng.uniform(-0.08, 0.08), -rng.uniform(0.38, 0.54),
                                        6, 0.008, 0.012, lift_mid=0.0045)
        _add_lock(bm, uv, pts, norms, rng.uniform(0.012, 0.018), 0.0045, i + 2, arch=0.7)


def _build_side_part(bm, uv, tree, body_tree, hinfo, rng):
    """Classic neat swept side-part: crisp left parting, smooth layered sweep across crown & clean sides."""
    _add_scalp_cap(bm, uv, tree, hinfo, offset=0.005, hairline_shift=0.003)
    c = hinfo["center"]
    part_az = 0.56
    # Main layered locks sweeping cleanly from the left part across the top to the right temple & back.
    for i in range(52):
        layer = i % 2
        az0 = part_az - rng.uniform(0.0, 0.18)
        el0 = rng.uniform(0.42, 1.38)
        d_az = -rng.uniform(0.75, 1.45)
        d_el = -rng.uniform(0.24, 0.52)
        off0 = 0.0055 + 0.0025 * layer
        off1 = 0.010 + 0.0035 * layer
        pts, norms = _grow_surface_lock(tree, c, az0, el0, d_az, d_el, 7, off0, off1,
                                        wave_amp=0.025, phase=i * 0.4, lift_mid=0.007 + 0.004 * layer)
        _add_lock(bm, uv, pts, norms, rng.uniform(0.015, 0.022), 0.0048, i, arch=0.65, root_tuck=0.002)
    # Smooth combed-down left side below the part + neat tapered back.
    for i in range(44):
        if i < 18:
            az0 = rng.uniform(part_az + 0.06, 1.75)
            el0 = rng.uniform(0.28, 1.05)
            d_az = rng.uniform(0.25, 0.55)
            d_el = -rng.uniform(0.32, 0.50)
        else:
            az0 = rng.uniform(1.55, math.pi * 2.0 - 1.15)
            if az0 > math.pi:
                az0 -= math.tau
            el0 = rng.uniform(0.20, 1.18)
            d_az = rng.uniform(-0.14, 0.14)
            d_el = -rng.uniform(0.35, 0.58)
        pts, norms = _grow_surface_lock(tree, c, az0, el0, d_az, d_el, 5, 0.0045, 0.0075, lift_mid=0.002)
        _add_lock(bm, uv, pts, norms, rng.uniform(0.015, 0.021), 0.0038, i, arch=0.55, root_tuck=0.002)


def _build_slick_back(bm, uv, tree, body_tree, hinfo, rng):
    """Combed-back slick-back / pompadour with feathered hairline sweep and sleek tapered sides."""
    _add_scalp_cap(bm, uv, tree, hinfo, offset=0.0055, hairline_shift=0.005)
    c = hinfo["center"]
    for i in range(44):
        frac = (i / 43.0) * 2.0 - 1.0
        layer = i % 2
        pts, norms = [], []
        for k in range(8):
            s = k / 7.0
            pitch = 0.44 + rng.uniform(-0.03, 0.03) * (1.0 - s) + s * 2.22
            x_s = frac * 0.78 * (1.0 - 0.18 * s)
            d = Vector((x_s, -math.cos(pitch), math.sin(pitch))).normalized()
            lift = 0.015 * math.sin(min(1.0, s * 1.2) * math.pi) * (1.0 - 0.30 * abs(frac))
            off = (0.003 if k == 0 else 0.0068) + lift + layer * 0.003
            pt, n = _skull_point(tree, c, d, off)
            pts.append(pt)
            norms.append(n)
        _add_lock(bm, uv, pts, norms, rng.uniform(0.014, 0.020), 0.0046, i, taper_root=0.74, arch=0.65)
    for i in range(36):
        side = 1.0 if i % 2 == 0 else -1.0
        az0 = side * rng.uniform(0.72, 1.80)
        el0 = rng.uniform(0.08, 0.75)
        pts, norms = _grow_surface_lock(tree, c, az0, el0, side * rng.uniform(0.60, 1.10), -rng.uniform(0.18, 0.36),
                                        6, 0.0048, 0.0075, lift_mid=0.002)
        _add_lock(bm, uv, pts, norms, rng.uniform(0.014, 0.020), 0.0036, i, arch=0.55)


def _build_textured_spiky(bm, uv, tree, body_tree, hinfo, rng):
    """Natural tousled faux-hawk / spiky: sleek faded sides with crisp layered upward-swept crown locks."""
    _add_scalp_cap(bm, uv, tree, hinfo, offset=0.0055, hairline_shift=0.004)
    c = hinfo["center"]
    for i in range(44):
        az = rng.uniform(-math.pi, math.pi)
        el = rng.uniform(0.16, 0.72)
        pts, norms = _grow_surface_lock(tree, c, az, el, rng.uniform(-0.10, 0.10), -rng.uniform(0.24, 0.38),
                                        5, 0.005, 0.0072, lift_mid=0.0018)
        _add_lock(bm, uv, pts, norms, rng.uniform(0.015, 0.021), 0.0034, i, arch=0.55)
    # Cohesive forward-tilted hairline spikes along the front brow.
    for i in range(16):
        az = -0.82 + (i / 15.0) * 1.64 + rng.uniform(-0.04, 0.04)
        el = rng.uniform(0.46, 0.68)
        d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el))).normalized()
        root, n = _skull_point(tree, c, d, 0.005)
        grow_dir = n.lerp(Vector((-d.x * 0.15, -0.55, 0.78)).normalized(), 0.55).normalized()
        length = rng.uniform(0.026, 0.042)
        pts = [root + grow_dir * (length * (k / 4.0)) for k in range(5)]
        _add_lock(bm, uv, pts, [n] * 5, rng.uniform(0.011, 0.016), 0.0045, i, taper_root=0.82, arch=0.75)
    for i in range(58):
        az = rng.uniform(-math.pi, math.pi)
        el = rng.uniform(0.58, 1.48)
        d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el))).normalized()
        root, n = _skull_point(tree, c, d, 0.0048)
        crest = Vector((-d.x * 0.25 + rng.uniform(-0.14, 0.14), -0.45 + rng.uniform(-0.15, 0.25), 0.85)).normalized()
        grow_dir = n.lerp(crest, 0.62).normalized()
        length = rng.uniform(0.036, 0.062) * (1.0 - 0.35 * abs(d.x))
        pts, norms = [], []
        bend = Vector((rng.uniform(-0.18, 0.18), -0.35, -0.15)).normalized()
        for k in range(6):
            s = k / 5.0
            p = root + grow_dir * (length * s) + bend * (length * 0.18 * s * s)
            pts.append(p)
            norms.append(n)
        _add_lock(bm, uv, pts, norms, rng.uniform(0.010, 0.016), rng.uniform(0.004, 0.006), i,
                  taper_root=0.78, arch=0.85)


def _build_undercut_quiff(bm, uv, tree, body_tree, hinfo, rng):
    """High-contrast faded undercut sides with fuller lifted wavy quiff sweeping up & back."""
    _add_scalp_cap(bm, uv, tree, hinfo, offset=0.005, hairline_shift=0.005)
    c = hinfo["center"]
    for i in range(36):
        # Faded short tufts only on sides & back (never across the bare forehead!).
        az = rng.uniform(1.05, math.pi * 2.0 - 1.05)
        if az > math.pi:
            az -= math.tau
        el = rng.uniform(0.14, 0.56)
        pts, norms = _grow_surface_lock(tree, c, az, el, rng.uniform(-0.08, 0.08), -0.22, 4, 0.0045, 0.006)
        _add_lock(bm, uv, pts, norms, 0.015, 0.0024, i, arch=0.45)
    for i in range(56):
        frac = (i / 55.0) * 2.0 - 1.0
        layer = i % 3
        pts, norms = [], []
        for k in range(8):
            s = k / 7.0
            pitch = 0.72 + s * 1.88
            x_s = frac * 0.60 + 0.14 * math.sin(s * math.pi) + rng.uniform(-0.02, 0.02)
            d = Vector((x_s, -math.cos(pitch), math.sin(pitch))).normalized()
            quiff_lift = 0.019 * math.sin(min(1.0, s * 1.32) * math.pi) * (1.0 - 0.30 * abs(frac))
            off = (0.005 if k == 0 else 0.0075) + quiff_lift + layer * 0.0030
            pt, n = _skull_point(tree, c, d, off)
            pts.append(pt)
            norms.append(n)
        _add_lock(bm, uv, pts, norms, rng.uniform(0.014, 0.021), 0.0050, i, arch=0.78)


def _build_curtain_part(bm, uv, tree, body_tree, hinfo, rng):
    """Center-parted curtain hair framing both temples and cheekbones smoothly."""
    _add_scalp_cap(bm, uv, tree, hinfo, offset=0.0055, hairline_shift=0.002)
    c = hinfo["center"]
    for i in range(86):
        side = 1.0 if i % 2 == 0 else -1.0
        if i < 44:
            # Sweep smoothly out from center part around temples & cheekbones (hugging the face, not jutting out!).
            az0 = side * rng.uniform(0.04, 0.42)
            el0 = rng.uniform(0.58, 1.40)
            root, n = _skull_point(tree, c, Vector((math.sin(az0) * math.cos(el0), -math.cos(az0) * math.cos(el0),
                                                    math.sin(el0))), 0.007)
            flow = Vector((side * 0.86, 0.08 + rng.uniform(-0.12, 0.18), -0.45)).normalized()
            length = rng.uniform(0.11, 0.16)
            pts, norms = _grow_hanging_lock(tree, body_tree, root, n, flow, length, 8,
                                            wave_amp=0.005, wave_freq=1.6, phase=rng.uniform(0, 6.28),
                                            curl_in=-0.006, min_gap=0.0085, gravity=0.82, splay=0.03)
            _add_lock(bm, uv, pts, norms, rng.uniform(0.015, 0.022), 0.0055, i, arch=0.72, root_tuck=0.002)
        else:
            az0 = side * rng.uniform(0.82, math.pi)
            el0 = rng.uniform(0.32, 1.35)
            pts, norms = _grow_surface_lock(tree, c, az0, el0, side * rng.uniform(-0.12, 0.12), -rng.uniform(0.48, 0.76),
                                            6, 0.006, 0.011, wave_amp=0.035, lift_mid=0.004)
            _add_lock(bm, uv, pts, norms, rng.uniform(0.016, 0.024), 0.0055, i, arch=0.68, root_tuck=0.002)


def _build_wavy_shag(bm, uv, tree, body_tree, hinfo, rng):
    """Tousled medium-length wavy shag falling softly over ears, brow, and collar."""
    _add_scalp_cap(bm, uv, tree, hinfo, offset=0.006, nape_drop=0.02)
    c = hinfo["center"]
    for i in range(96):
        az = -math.pi + (i / 96.0) * math.tau + rng.uniform(-0.05, 0.05)
        el = rng.uniform(0.46, 1.46)
        d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el))).normalized()
        root, n = _skull_point(tree, c, d, rng.uniform(0.006, 0.011))
        front = max(0.0, math.cos(az))
        if front > 0.72:
            # Feathered wavy brow fringe hugging forehead instead of spiking forward.
            pts, norms = _grow_surface_lock(tree, c, az, el, rng.uniform(-0.22, 0.22), -rng.uniform(0.45, 0.65),
                                            6, 0.008, 0.013, wave_amp=0.05, lift_mid=0.004)
            _add_lock(bm, uv, pts, norms, rng.uniform(0.013, 0.020), 0.0052, i, arch=0.7)
            continue
        length = rng.uniform(0.14, 0.22)
        side_s = 1.0 if az >= 0 else -1.0
        flow = Vector((math.sin(az) * 0.42 + side_s * 0.12, -math.cos(az) * 0.22 + 0.12, -0.78)).normalized()
        pts, norms = _grow_hanging_lock(tree, body_tree, root, n, flow, length, 8,
                                        wave_amp=rng.uniform(0.008, 0.014), wave_freq=rng.uniform(2.0, 3.0),
                                        phase=rng.uniform(0, 6.28), min_gap=0.0095, gravity=0.88, splay=0.05)
        _add_lock(bm, uv, pts, norms, rng.uniform(0.015, 0.022), 0.0056, i, arch=0.72, root_tuck=0.002)


def _build_curly_afro(bm, uv, tree, body_tree, hinfo, rng):
    """Natural coiled curly hair built from layered intertwined S-spiral ribbon locks."""
    _add_scalp_cap(bm, uv, tree, hinfo, offset=0.010, hairline_shift=-0.002)
    c = hinfo["center"]
    for i in range(122):
        az = rng.uniform(-math.pi, math.pi)
        z_min_el = math.atan2(_hairline_z(az, hinfo) - c.z + 0.008, 0.105)
        el = rng.uniform(max(-0.12, z_min_el), 1.48)
        d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el))).normalized()
        root, n = _skull_point(tree, c, d, 0.006)
        t1 = n.cross(Vector((0, 0, 1)))
        if t1.length < 1e-4:
            t1 = Vector((1, 0, 0))
        t1.normalize()
        t2 = n.cross(t1).normalized()
        coil_r = rng.uniform(0.0075, 0.014)
        coil_h = rng.uniform(0.026, 0.048) * (0.76 + 0.34 * max(0.0, d.z))
        turns = rng.uniform(1.15, 1.85)
        ph = rng.uniform(0, math.tau)
        sign = 1.0 if i % 2 == 0 else -1.0
        pts, norms = [], []
        for k in range(7):
            s = k / 6.0
            ang = ph + sign * s * math.tau * turns
            rad = coil_r * (0.4 + 0.6 * math.sin(s * math.pi))
            p = root + n * (coil_h * s) + (t1 * math.cos(ang) + t2 * math.sin(ang)) * rad
            p.z -= 0.009 * s * s
            pts.append(p)
            norms.append((n * 0.7 + (t1 * math.cos(ang) + t2 * math.sin(ang)) * 0.3).normalized())
        _add_lock(bm, uv, pts, norms, rng.uniform(0.012, 0.018), 0.0055, i, taper_root=0.75, arch=0.95)


def _build_chin_bob(bm, uv, tree, body_tree, hinfo, rng):
    """Layered chin-length bob framing cheeks & jawline cleanly with soft feathered bangs."""
    _add_scalp_cap(bm, uv, tree, hinfo, offset=0.006, nape_drop=0.015)
    c = hinfo["center"]
    for i in range(92):
        az = -math.pi + (i / 92.0) * math.tau + rng.uniform(-0.03, 0.03)
        front = max(0.0, math.cos(az))
        if front > 0.76:
            el0 = rng.uniform(0.60, 1.08)
            pts, norms = _grow_surface_lock(tree, c, az, el0, rng.uniform(-0.12, 0.12), -rng.uniform(0.42, 0.60),
                                            6, 0.007, 0.012, lift_mid=0.004)
            _add_lock(bm, uv, pts, norms, rng.uniform(0.014, 0.020), 0.005, i, arch=0.7, root_tuck=0.002)
            continue
        for layer in (0, 1):
            el0 = rng.uniform(0.85, 1.44) if layer == 0 else rng.uniform(0.45, 0.90)
            d = Vector((math.sin(az) * math.cos(el0), -math.cos(az) * math.cos(el0), math.sin(el0))).normalized()
            root, n = _skull_point(tree, c, d, 0.0065 + layer * 0.0045)
            flow = Vector((math.sin(az) * 0.34, -math.cos(az) * 0.22, -0.86)).normalized()
            length = rng.uniform(0.18, 0.22) if layer == 0 else rng.uniform(0.13, 0.17)
            pts, norms = _grow_hanging_lock(tree, body_tree, root, n, flow, length, 8,
                                            wave_amp=0.004, wave_freq=1.5, phase=rng.uniform(0, 6.28),
                                            curl_in=-0.010, min_gap=0.0095 + layer * 0.0035, gravity=0.92, splay=0.04)
            _add_lock(bm, uv, pts, norms, rng.uniform(0.017, 0.024), 0.0055, i + layer, arch=0.72)


def _build_long_straight(bm, uv, tree, body_tree, hinfo, rng):
    """Multi-tier cascading straight long hair with clean center/off-center part and shoulder drape."""
    _add_scalp_cap(bm, uv, tree, hinfo, offset=0.006, nape_drop=0.02)
    c = hinfo["center"]
    for i in range(108):
        az = -math.pi + (i / 108.0) * math.tau + rng.uniform(-0.03, 0.03)
        front = max(0.0, math.cos(az))
        if front > 0.84:
            side = 1.0 if az >= -0.08 else -1.0
            el0 = rng.uniform(0.68, 1.28)
            root, n = _skull_point(tree, c, Vector((math.sin(az) * math.cos(el0), -math.cos(az) * math.cos(el0),
                                                    math.sin(el0))), 0.007)
            # Sweep smoothly out to the side behind cheeks instead of protruding forward!
            flow = Vector((side * 0.82, 0.12, -0.56)).normalized()
            pts, norms = _grow_hanging_lock(tree, body_tree, root, n, flow, rng.uniform(0.24, 0.34), 9,
                                            wave_amp=0.005, wave_freq=1.5, phase=rng.uniform(0, 6.28),
                                            min_gap=0.010, gravity=0.88, splay=0.04)
            _add_lock(bm, uv, pts, norms, rng.uniform(0.016, 0.022), 0.0055, i, arch=0.7, root_tuck=0.002)
            continue
        layer = i % 2
        el0 = rng.uniform(0.75, 1.44) if layer == 0 else rng.uniform(0.28, 0.82)
        d = Vector((math.sin(az) * math.cos(el0), -math.cos(az) * math.cos(el0), math.sin(el0))).normalized()
        root, n = _skull_point(tree, c, d, 0.0065 + layer * 0.005)
        back_w = max(0.0, -math.cos(az))
        length = rng.uniform(0.32, 0.44) if back_w > 0.20 else rng.uniform(0.26, 0.35)
        flow = Vector((math.sin(az) * 0.32, -math.cos(az) * 0.14 + 0.18 * back_w, -0.88)).normalized()
        pts, norms = _grow_hanging_lock(tree, body_tree, root, n, flow, length, 10,
                                        wave_amp=0.006, wave_freq=2.0, phase=rng.uniform(0, 6.28),
                                        min_gap=0.0105 + layer * 0.0035, gravity=0.94, splay=0.05)
        _add_lock(bm, uv, pts, norms, rng.uniform(0.019, 0.027), 0.0058, i, arch=0.72)


def _build_long_disheveled(bm, uv, tree, body_tree, hinfo, rng):
    """Creepy horror matted wild long hair: tangled curtains draping over one side while one eerie eye peeks out."""
    _add_scalp_cap(bm, uv, tree, hinfo, offset=0.0065, nape_drop=0.02)
    c = hinfo["center"]
    for i in range(106):
        az = -math.pi + (i / 106.0) * math.tau + rng.uniform(-0.07, 0.07)
        el0 = rng.uniform(0.36, 1.46)
        d = Vector((math.sin(az) * math.cos(el0), -math.cos(az) * math.cos(el0), math.sin(el0))).normalized()
        root, n = _skull_point(tree, c, d, rng.uniform(0.006, 0.013))
        front = max(0.0, math.cos(az))
        if front > 0.72 and az > -0.05:
            # Sweep aside on the left half of the face so one dead zombie eye stares right out!
            length = rng.uniform(0.22, 0.32)
            flow = Vector((0.74, -0.05, -0.66)).normalized()
        elif front > 0.65:
            # Creepy ragged locks hanging straight down across the right eye & cheek!
            length = rng.uniform(0.26, 0.38)
            flow = Vector((-0.26 + rng.uniform(-0.14, 0.14), -0.32, -0.88)).normalized()
        else:
            length = rng.uniform(0.32, 0.48)
            flow = Vector((math.sin(az) * 0.36 + rng.uniform(-0.16, 0.16),
                           -math.cos(az) * 0.18 + rng.uniform(-0.10, 0.16),
                           -0.84)).normalized()
        pts, norms = _grow_hanging_lock(tree, body_tree, root, n, flow, length, 10,
                                        wave_amp=rng.uniform(0.012, 0.022), wave_freq=rng.uniform(2.2, 3.8),
                                        phase=rng.uniform(0, 6.28), min_gap=0.0095, gravity=0.90, splay=0.06)
        _add_lock(bm, uv, pts, norms, rng.uniform(0.012, 0.022), rng.uniform(0.0045, 0.0065), i, arch=0.75)


def _build_high_bun(bm, uv, tree, body_tree, hinfo, rng):
    """Sleek pulled-back hair gathered into a sculpted twisted bun with wispy temple strands."""
    _add_scalp_cap(bm, uv, tree, hinfo, offset=0.0052, hairline_shift=0.004)
    c = hinfo["center"]
    bun_c = Vector((0.0, hinfo["ymax"] + 0.022, hinfo["crown_z"] - 0.064))
    # Smooth sleek combed-back strands converging cleanly toward the bun (no weave bumps!).
    for i in range(48):
        az = -math.pi + (i / 48.0) * math.tau
        el_edge = math.atan2(_hairline_z(az, hinfo, hairline_shift=0.004) - c.z, 0.105)
        d0 = Vector((math.sin(az) * math.cos(el_edge), -math.cos(az) * math.cos(el_edge), math.sin(el_edge)))
        start_p, _ = _skull_point(tree, c, d0, 0.001)
        pts, norms = [], []
        for k in range(7):
            s = k / 6.0
            p, n = _push_outside(tree, start_p.lerp(bun_c, s), 0.0045 + 0.002 * math.sin(s * math.pi))
            pts.append(p)
            norms.append(n)
        _add_lock(bm, uv, pts, norms, 0.016, 0.0032, i, taper_root=0.7, arch=0.5)
    # Sculpted coiled bun.
    for i in range(30):
        r0 = rng.uniform(0.024, 0.044)
        lat0 = rng.uniform(-0.85, 0.85)
        ph0 = rng.uniform(0, math.tau)
        pts, norms = [], []
        for k in range(7):
            s = k / 6.0
            ang = ph0 + s * math.pi * 1.5
            lat = lat0 + (s - 0.5) * 0.60
            rad = r0 * (0.85 + 0.22 * math.sin(s * math.pi))
            local = Vector((math.cos(ang) * math.cos(lat), math.sin(lat) * 0.72, math.sin(ang) * math.cos(lat)))
            pts.append(bun_c + local * rad)
            norms.append(local.normalized())
        _add_lock(bm, uv, pts, norms, rng.uniform(0.013, 0.020), 0.006, i, taper_root=0.8, arch=0.8)
    # Delicate temple wisps.
    for i in range(10):
        side = 1.0 if i % 2 == 0 else -1.0
        az = side * rng.uniform(0.85, 1.35)
        d = Vector((math.sin(az) * 0.94, -math.cos(az) * 0.94, 0.22)).normalized()
        root, n = _skull_point(tree, c, d, 0.005)
        pts, norms = _grow_hanging_lock(tree, body_tree, root, n, Vector((side * 0.16, -0.15, -0.96)),
                                        rng.uniform(0.065, 0.11), 6, wave_amp=0.006, min_gap=0.007, splay=0.02)
        _add_lock(bm, uv, pts, norms, 0.0075, 0.0032, i, arch=0.6)


def _build_ponytail(bm, uv, tree, body_tree, hinfo, rng):
    """Sleek pulled-back crown flowing into a layered cascading ponytail with delicate face wisps."""
    _add_scalp_cap(bm, uv, tree, hinfo, offset=0.0052, hairline_shift=0.004)
    c = hinfo["center"]
    tie_c = Vector((0.0, hinfo["ymax"] + 0.018, hinfo["crown_z"] - 0.074))
    for i in range(48):
        az = -math.pi + (i / 48.0) * math.tau
        el_edge = math.atan2(_hairline_z(az, hinfo, hairline_shift=0.004) - c.z, 0.105)
        d0 = Vector((math.sin(az) * math.cos(el_edge), -math.cos(az) * math.cos(el_edge), math.sin(el_edge)))
        start_p, _ = _skull_point(tree, c, d0, 0.001)
        pts, norms = [], []
        for k in range(7):
            s = k / 6.0
            p, n = _push_outside(tree, start_p.lerp(tie_c, s), 0.0045 + 0.002 * math.sin(s * math.pi))
            pts.append(p)
            norms.append(n)
        _add_lock(bm, uv, pts, norms, 0.016, 0.0032, i, taper_root=0.7, arch=0.5)
    # Full layered ponytail cascading down back.
    for i in range(34):
        ang = (i / 34.0) * math.tau + rng.uniform(-0.12, 0.12)
        ring_r = rng.uniform(0.005, 0.019)
        start_p = tie_c + Vector((math.cos(ang) * ring_r, 0.009, math.sin(ang) * ring_r))
        out_n = Vector((math.cos(ang), 0.75, math.sin(ang))).normalized()
        flow = Vector((math.cos(ang) * 0.24, 0.52 + rng.uniform(0.0, 0.22), -0.58)).normalized()
        pts, norms = _grow_hanging_lock(tree, body_tree, start_p, out_n, flow, rng.uniform(0.24, 0.34), 9,
                                        wave_amp=0.009, wave_freq=2.2, phase=rng.uniform(0, 6.28),
                                        min_gap=0.012, gravity=0.92, splay=0.08)
        _add_lock(bm, uv, pts, norms, rng.uniform(0.014, 0.022), 0.006, i, arch=0.78)
    # Soft face-framing temple wisps.
    for i in range(10):
        side = 1.0 if i % 2 == 0 else -1.0
        az = side * rng.uniform(0.68, 1.25)
        d = Vector((math.sin(az) * 0.92, -math.cos(az) * 0.92, 0.30)).normalized()
        root, n = _skull_point(tree, c, d, 0.005)
        pts, norms = _grow_hanging_lock(tree, body_tree, root, n, Vector((side * 0.22, -0.14, -0.94)),
                                        rng.uniform(0.09, 0.14), 6, wave_amp=0.005, min_gap=0.0075, splay=0.02)
        _add_lock(bm, uv, pts, norms, 0.008, 0.0034, i, arch=0.6)


def _build_twin_pigtails(bm, uv, tree, body_tree, hinfo, rng):
    """Center-parted crown gathered into twin low hanging tails over the shoulders with wispy bangs."""
    _add_scalp_cap(bm, uv, tree, hinfo, offset=0.0055, hairline_shift=0.003)
    c = hinfo["center"]
    for side in (-1.0, 1.0):
        tie = Vector((side * (hinfo["rx"] + 0.020), 0.018, hinfo["crown_z"] - 0.132))
        for i in range(24):
            az = side * rng.uniform(0.06, math.pi * 0.96)
            el0 = rng.uniform(0.32, 1.38)
            d0 = Vector((math.sin(az) * math.cos(el0), -math.cos(az) * math.cos(el0), math.sin(el0)))
            start_p, _ = _skull_point(tree, c, d0, 0.004)
            pts, norms = [], []
            for k in range(6):
                s = k / 5.0
                p, n = _push_outside(tree, start_p.lerp(tie, s), 0.0055)
                pts.append(p)
                norms.append(n)
            _add_lock(bm, uv, pts, norms, 0.016, 0.0036, i, arch=0.55)
        extra_len = 0.035 if side < 0 else 0.0
        for i in range(20):
            ang = (i / 20.0) * math.tau
            start_p = tie + Vector((math.cos(ang) * 0.013, math.sin(ang) * 0.013, 0.0))
            out_n = Vector((side * 0.7 + math.cos(ang) * 0.3, math.sin(ang) * 0.5, 0.1)).normalized()
            flow = Vector((side * 0.36 + rng.uniform(-0.08, 0.08), -0.14 + rng.uniform(-0.10, 0.10), -0.88)).normalized()
            pts, norms = _grow_hanging_lock(tree, body_tree, start_p, out_n, flow,
                                            rng.uniform(0.20, 0.28) + extra_len, 8,
                                            wave_amp=0.009, wave_freq=2.4, phase=rng.uniform(0, 6.28),
                                            min_gap=0.011, gravity=0.92, splay=0.08)
            _add_lock(bm, uv, pts, norms, rng.uniform(0.013, 0.019), 0.0058, i, arch=0.75)
    for i in range(18):
        az = -0.74 + (i / 17.0) * 1.48
        pts, norms = _grow_surface_lock(tree, c, az, rng.uniform(0.62, 0.94), rng.uniform(-0.10, 0.10),
                                        -rng.uniform(0.38, 0.54), 6, 0.007, 0.011, lift_mid=0.0035)
        _add_lock(bm, uv, pts, norms, 0.012, 0.0042, i, arch=0.65)


def _build_thinning_receding(bm, uv, tree, body_tree, hinfo, rng):
    """Receding elderly/middle-aged hairline with sleek sparse side fringe and wispy comb-over strands."""
    _add_scalp_cap(bm, uv, tree, hinfo, offset=0.0038, hairline_shift=0.024, recede=0.068)
    c = hinfo["center"]
    for i in range(48):
        az = rng.uniform(0.76, math.pi * 2.0 - 0.76)
        if az > math.pi:
            az -= math.tau
        el0 = rng.uniform(0.02, 0.58)
        pts, norms = _grow_surface_lock(tree, c, az, el0, rng.uniform(-0.16, 0.16), -rng.uniform(0.28, 0.44),
                                        5, 0.0038, 0.0072, wave_amp=0.04, lift_mid=0.002)
        _add_lock(bm, uv, pts, norms, rng.uniform(0.011, 0.016), 0.0036, i, arch=0.55, root_tuck=0.002)
    for i in range(16):
        az0 = rng.uniform(0.45, 1.35)
        el0 = rng.uniform(0.55, 1.18)
        pts, norms = _grow_surface_lock(tree, c, az0, el0, -rng.uniform(0.75, 1.40), -rng.uniform(0.08, 0.24),
                                        6, 0.0038, 0.0070, wave_amp=0.05, lift_mid=0.003)
        _add_lock(bm, uv, pts, norms, rng.uniform(0.008, 0.012), 0.003, i, arch=0.55, root_tuck=0.0015)


def _build_patchy_rotted(bm, uv, tree, body_tree, hinfo, rng):
    """Decaying zombie hair: ragged matted clumps hanging unevenly on sides/back/crown with exposed bald patches."""
    seed = rng.randint(1, 999)
    _add_scalp_cap(bm, uv, tree, hinfo, offset=0.0042, patchy_seed=seed)
    c = hinfo["center"]
    clumps = [(-1.35, 0.45), (1.15, 0.55), (-2.3, 0.62), (2.45, 0.42), (0.65, 1.08), (-0.85, 0.95)]
    idx = 0
    for caz, cel in clumps:
        caz_j = caz + rng.uniform(-0.22, 0.22)
        for _ in range(rng.randint(7, 11)):
            az = caz_j + rng.uniform(-0.28, 0.28)
            el = min(1.42, max(0.12, cel + rng.uniform(-0.20, 0.20)))
            d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el))).normalized()
            root, n = _skull_point(tree, c, d, 0.0045)
            flow = Vector((math.sin(az) * 0.42 + rng.uniform(-0.18, 0.18),
                           -math.cos(az) * 0.12 + 0.14,
                           -0.86)).normalized()
            pts, norms = _grow_hanging_lock(tree, body_tree, root, n, flow, rng.uniform(0.09, 0.19), 7,
                                            wave_amp=0.012, wave_freq=2.6, phase=rng.uniform(0, 6.28),
                                            min_gap=0.008, gravity=0.90, splay=0.06)
            _add_lock(bm, uv, pts, norms, rng.uniform(0.009, 0.015), 0.0046, idx, arch=0.7)
            idx += 1


BUILDERS = {
    "buzz_fade": _build_buzz_fade,
    "textured_crop": _build_textured_crop,
    "side_part": _build_side_part,
    "slick_back": _build_slick_back,
    "textured_spiky": _build_textured_spiky,
    "undercut_quiff": _build_undercut_quiff,
    "curtain_part": _build_curtain_part,
    "wavy_shag": _build_wavy_shag,
    "curly_afro": _build_curly_afro,
    "chin_bob": _build_chin_bob,
    "long_straight": _build_long_straight,
    "long_disheveled": _build_long_disheveled,
    "high_bun": _build_high_bun,
    "ponytail": _build_ponytail,
    "twin_pigtails": _build_twin_pigtails,
    "thinning_receding": _build_thinning_receding,
    "patchy_rotted": _build_patchy_rotted,
}


def build_hair(style, ref, arm, mat, uv_name="UVMap", seed=1, under_hat=False):
    """Builds a fitted layered-strand hair mesh cleanly skinned to `arm` (or None for 'bald')."""
    st = canonical_style(style)
    if st == "bald":
        return None
    if st not in BUILDERS:
        raise ValueError(f"Unknown hair style: {style!r}")

    hinfo = measure_head(ref)
    head_tree = _region_bvh(ref, z_min=1.50, x_max=0.18)
    body_tree = _region_bvh(ref, z_min=1.18, x_max=0.34)

    bm = bmesh.new()
    uv = bm.loops.layers.uv.new(uv_name)
    rng = random.Random(seed * 97 + hash(st) % 997)
    BUILDERS[st](bm, uv, head_tree, body_tree, hinfo, rng)

    if under_hat:
        hat_z = hinfo["crown_z"] - 0.088
        for vert in bm.verts:
            if vert.co.z > hat_z:
                loc, n, _i, _dist = head_tree.find_nearest(vert.co)
                if loc is not None:
                    t = min(1.0, (vert.co.z - hat_z) / 0.04)
                    snug = loc + n * 0.002
                    vert.co = vert.co.lerp(snug, t)

    me = bpy.data.meshes.new("Hair_" + st)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new("Hair_" + st, me)
    bpy.context.scene.collection.objects.link(ob)

    g_head = ob.vertex_groups.new(name="head")
    if st in LONG_STYLES:
        g_neck = ob.vertex_groups.new(name="neck")
        g_chest = ob.vertex_groups.new(name="chest")
        for v in me.vertices:
            z = v.co.z
            if z >= 1.56:
                g_head.add([v.index], 1.0, "REPLACE")
            elif z >= 1.46:
                t = (1.56 - z) / 0.10
                g_head.add([v.index], 1.0 - t * 0.65, "REPLACE")
                g_neck.add([v.index], t * 0.65, "REPLACE")
            else:
                t = min(1.0, (1.46 - z) / 0.14)
                w_head = 0.35 * (1.0 - t)
                w_neck = 0.65 * (1.0 - t) + 0.30 * t
                w_chest = 0.70 * t
                tot = w_head + w_neck + w_chest
                if w_head > 1e-4:
                    g_head.add([v.index], w_head / tot, "REPLACE")
                g_neck.add([v.index], w_neck / tot, "REPLACE")
                g_chest.add([v.index], w_chest / tot, "REPLACE")
    else:
        g_head.add(list(range(len(me.vertices))), 1.0, "REPLACE")

    return ob


def _render_hair_sheet():
    import sys
    here = os.path.dirname(os.path.abspath(__file__))
    if here not in sys.path:
        sys.path.insert(0, here)
    import build_human as bh

    out_dir = os.path.join(bh.ROOT, "work", "v44", "hair")
    os.makedirs(out_dir, exist_ok=True)
    for idx, st in enumerate(STYLES):
        bh.reset()
        bpy.ops.import_scene.gltf(filepath=bh.SRC)
        arm = body = None
        for o in list(bpy.data.objects):
            if o.type == "ARMATURE":
                arm = o
            elif o.type == "MESH" and o.parent is not None:
                body = o
            else:
                bpy.data.objects.remove(o)
        female_styles = {"chin_bob", "long_straight", "long_disheveled", "high_bun", "ponytail", "twin_pigtails"}
        keys = body.data.shape_keys.key_blocks
        basis = np.array([d.co[:] for d in keys[0].data])
        co = basis.copy()
        if st in female_styles:
            co += 1.0 * (np.array([d.co[:] for d in keys["female"].data]) - basis)
        body.shape_key_clear()
        body.data.vertices.foreach_set("co", co.astype(np.float32).ravel())
        body.data.update()
        bh.set_material(body, bh.principled("Skin", (0.7, 0.5, 0.4), 0.62, bh.SKIN_TEX))

        is_zombie = st in {"long_disheveled", "patchy_rotted"}
        grey = 0.75 if st == "thinning_receding" else (0.25 if st == "high_bun" else 0.0)
        col = (0.04, 0.032, 0.028) if st not in {"curtain_part", "wavy_shag"} else (0.08, 0.055, 0.038)
        mat = make_hair_material("Hair_" + st, "prev_" + st, col, out_dir, seed=idx + 1,
                                 grey_mix=grey, zombie_grime=0.55 if is_zombie else 0.0)
        h_ob = build_hair(st, body, arm, mat, uv_name=body.data.uv_layers[0].name, seed=idx + 1)
        if h_ob is not None:
            h_ob.parent = arm
            h_ob.modifiers.new("Armature", "ARMATURE").object = arm

        cam = bh.setup_render((360, 400))
        img_path = os.path.join(out_dir, f"{idx + 1:02d}_{st}.png")
        bh.shoot(cam, img_path, (-0.52, -0.78, 1.72), (0.0, -0.02, 1.62), lens=65)
        print("HAIR_PREVIEW", st, len(h_ob.data.polygons) if h_ob else 0)


if __name__ == "__main__":
    _render_hair_sheet()
