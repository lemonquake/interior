"""Pack the Poly Haven sky HDRI into an 8-bit backdrop panorama for the neighbourhood sky dome.

    blender -b --factory-startup -P tools/assets/make_sky.py

Values are Reinhard-compressed (v = x / (1 + x)) before sRGB encoding; scripts/sky_dome.gdshader
inverts that, so the dome keeps the HDR's bright horizon glow under the AgX tonemapper.
Prints the sun's azimuth/elevation so the DirectionalLight can match it.
"""
import bpy, os, math
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, '.local', 'downloads', 'polyhaven', 'hdri', 'kloofendal_28d_misty_puresky_4k.hdr')
DST = os.path.join(ROOT, 'game', 'assets', 'outdoor', 'sky', 'misty_afternoon_sky.png')

image = bpy.data.images.load(SRC)
w, h = image.size
px = np.array(image.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1, :, :3]  # top row first
lum = px @ np.array([.2126, .7152, .0722], dtype=np.float32)
y, x = np.unravel_index(np.argmax(lum), lum.shape)
u, v = (x + .5) / w, (y + .5) / h
print('SKY_SUN u=%.4f v=%.4f azimuth_deg=%.1f elevation_deg=%.1f peak=%.1f' % (u, v, u * 360.0, 90.0 - v * 180.0, lum.max()))
# Paint the HDRI's sun out (the dome draws its own sun where the game's DirectionalLight is,
# at a 3 pm elevation): blend pixels near the sun toward the mean of a ring around it.
az = (np.arange(w) + .5) / w * 2 * math.pi
el = math.pi / 2 - (np.arange(h) + .5) / h * math.pi
sun_az, sun_el = u * 2 * math.pi, math.pi / 2 - v * math.pi
cos_angle = (np.sin(el)[:, None] * math.sin(sun_el) + np.cos(el)[:, None] * math.cos(sun_el) * np.cos(az[None, :] - sun_az))
angle = np.degrees(np.arccos(np.clip(cos_angle, -1, 1)))
ring = (angle > 14) & (angle < 18)
fill = px[ring].mean(axis=0)
weight = np.clip((16 - angle) / 10, 0, 1)[..., None] ** .7
px = px * (1 - weight) + fill * weight
horizon = px[int(h * (90 - 3) / 180)].mean(axis=0)
print('SKY_HORIZON %.3f %.3f %.3f  ring %.3f %.3f %.3f' % (*horizon, *fill))
# Clamp the sun disc so it does not dominate the compression, then Reinhard + sRGB.
px = np.minimum(px, 24.0)
v8 = px / (1.0 + px)
srgb = np.where(v8 <= .0031308, v8 * 12.92, 1.055 * np.power(v8, 1 / 2.4) - .055)
out = bpy.data.images.new('sky', w, h, alpha=False)
rgba = np.concatenate([srgb, np.ones((h, w, 1), np.float32)], axis=2)[::-1]
out.pixels[:] = rgba.ravel()
os.makedirs(os.path.dirname(DST), exist_ok=True)
out.filepath_raw = DST
out.file_format = 'PNG'
out.save()
print('SKY_WRITTEN', DST, w, h)
