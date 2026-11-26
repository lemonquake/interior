"""0.54: the art and sounds of Heavy-arm's tells (Mang Dado's old night round).

  python -I tools/ui/heavyarm_tells.py

Writes game/assets/coop/heavyarm/*.png and game/assets/audio/heavyarm/*.wav:
  torch_cookie.png   the light a cheap guard's flashlight throws: a dark dot where the bulb's own shadow falls, the
                     hot ring of the reflector, a few faint facet rings, then a weak spill (SpotLight3D projector).
  torch_lane.png     that light lying long on the ground down the charge's lane (the pool at a grazing angle).
  anino.png          the slab's shadow where it will land: a blot the slab's shape, a soft penumbra (albedo + alpha).
  anino_rim.png      the moonlit edge round it and the grit lifting on it (emission).
  beam_dust.png      motes in the beam (tileable).
  whistle_call.wav   the guard's pea whistle, blown through what is left of his mouth: short, short, long.
  whistle_inhale.wav the breath in through the whistle before it (the pea rattling).
  torch_click.wav    the flashlight's slide switch.
"""
import math
import os
import wave

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ART = os.path.join(ROOT, "game", "assets", "coop", "heavyarm")
SND = os.path.join(ROOT, "game", "assets", "audio", "heavyarm")
rng = np.random.default_rng(54)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def fbm(h, w, octaves=5, seed=0, tile=True):
    g = np.random.default_rng(seed)
    out = np.zeros((h, w))
    amp = 1.0
    total = 0.0
    for o in range(octaves):
        n = 2 ** (o + 2)
        grid = g.random((n, n))
        img = Image.fromarray((grid * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        out += np.asarray(img, dtype=np.float64) / 255.0 * amp
        total += amp
        amp *= .55
    return out / total


def reflector(r, ang):
    """A cheap flashlight's beam across its radius r (0 centre, 1 edge)."""
    hole = 1.0 - .55 * np.exp(-(r / .055) ** 2)
    core = np.exp(-(r / .26) ** 2.6)
    rim = .55 * np.exp(-((r - .285) / .028) ** 2)
    facets = sum(.07 * np.exp(-((r - c) / .02) ** 2) for c in (.39, .47, .58, .7))
    spill = .13 * smooth(1.0, .55, r)
    streak = 1.0 + .06 * np.sin(ang * 23.0) * smooth(.2, .6, r) + .04 * np.sin(ang * 61.0 + 1.3)
    v = (core * hole + rim * smooth(.42, .3, r) + facets + spill) * streak
    return np.clip(v, 0.0, None) * (r < 1.0)


def save_gray(arr, name):
    a = np.clip(arr, 0, 1)
    Image.fromarray((a * 255 + .5).astype(np.uint8), "L").convert("RGB").save(os.path.join(ART, name))


def cookie():
    n = 512
    y, x = np.mgrid[0:n, 0:n]
    u = (x - n / 2 + .5) / (n / 2)
    v = (y - n / 2 + .5) / (n / 2)
    r = np.sqrt(u * u + v * v)
    ang = np.arctan2(v, u)
    img = reflector(r, ang)
    img = img / img.max()
    save_gray(img, "torch_cookie.png")


def lane():
    w, h = 256, 1024
    y, x = np.mgrid[0:h, 0:w]
    u = (x - w / 2 + .5) / (w / 2)          # across, -1..1
    v = 1.0 - (y + .5) / h                  # 0 at his feet (bottom), 1 at the far end (top)
    # The pool's outline: long, its far end rounder, narrow where it leaves him.
    half = .32 + .68 * smooth(0.0, .55, v)
    edge = smooth(1.0, .5, np.abs(u) / half) * smooth(0.0, .08, v) * smooth(1.0, .86, v)
    # The hot ring and the facets where the beam's middle lies (near the far end), drawn out along the ground.
    cx, cy = 0.0, .78
    du = u / .95
    dv = (v - cy) / .42
    r = np.sqrt(du * du + dv * dv)
    ang = np.arctan2(dv, du)
    hot = reflector(np.clip(r, 0, .999), ang)
    spill = .45 + .45 * v ** 1.3
    grain = .82 + .18 * fbm(h, w, 6, 3)
    img = (spill * edge + hot * .6 * edge) * grain
    img = img / img.max()
    rgb = np.stack([img * 1.0, img * .86, img * .62], -1)
    out = np.dstack([rgb, img])
    Image.fromarray((np.clip(out, 0, 1) * 255 + .5).astype(np.uint8), "RGBA").save(os.path.join(ART, "torch_lane.png"))


def anino():
    n = 512
    # The blot: a slab's outline (a rounded, chipped quadrilateral), blurred into a shadow.
    big = Image.new("L", (n, n), 0)
    pts = []
    corners = [(-.6, -.42), (.55, -.5), (.63, .37), (-.5, .5)]
    from PIL import ImageDraw
    d = ImageDraw.Draw(big)
    for i in range(4):
        a = corners[i]
        b = corners[(i + 1) % 4]
        for t in np.linspace(0, 1, 18, endpoint=False):
            jx = rng.normal(0, .012)
            jy = rng.normal(0, .012)
            pts.append(((a[0] + (b[0] - a[0]) * t + jx) * n * .5 + n / 2, (a[1] + (b[1] - a[1]) * t + jy) * n * .5 + n / 2))
    d.polygon(pts, fill=255)
    blot = np.asarray(big.filter(ImageFilter.GaussianBlur(14)), dtype=np.float64) / 255.0
    y, x = np.mgrid[0:n, 0:n]
    u = (x - n / 2 + .5) / (n / 2)
    v = (y - n / 2 + .5) / (n / 2)
    r = np.sqrt(u * u + v * v)
    penumbra = .62 * smooth(.95, .5, r)
    mottle = .85 + .15 * fbm(n, n, 5, 7)
    a = np.clip(np.maximum(blot * .97, penumbra) * mottle, 0, 1) * (r < 1)
    out = np.dstack([np.zeros((n, n, 3)) + .01, a])
    Image.fromarray((out * 255 + .5).astype(np.uint8), "RGBA").save(os.path.join(ART, "anino.png"))
    # The rim: thin, broken in places, cold; grit specks on and inside it.
    ang = np.arctan2(v, u)
    broken = .55 + .45 * smooth(.25, .7, fbm(n, n, 4, 11))
    ring = .7 * np.exp(-((r - .93) / .013) ** 2) * broken
    halo = .1 * np.exp(-((r - .93) / .06) ** 2)
    specks = (rng.random((n, n)) > .9965).astype(np.float64)
    specks = np.asarray(Image.fromarray((specks * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(.8)), dtype=np.float64) / 255.0 * 3.0
    specks *= smooth(.55, .9, r) * smooth(1.0, .95, r)
    # Inside the rim the ground takes a little cold light (moonlight caught in the lifted grit), all but where the
    # slab's own shadow lies: so the shadow reads as a shape even on ground that is already dark.
    fill = .32 * smooth(.95, .6, r) * (.75 + .25 * mottle) * (1.0 - np.clip(blot * 1.15, 0, 1))
    e = np.clip(ring + halo + specks + fill, 0, 1.4) / 1.4
    rgb = np.stack([e * .78, e * .86, e * 1.0], -1)
    Image.fromarray((np.clip(rgb, 0, 1) * 255 + .5).astype(np.uint8), "RGB").save(os.path.join(ART, "anino_rim.png"))


def dust():
    n = 256
    # Periodic noise from random phases (1/f), so it tiles without a seam.
    fy = np.fft.fftfreq(n)[:, None]
    fx = np.fft.fftfreq(n)[None, :]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    spec = (rng.normal(size=(n, n)) + 1j * rng.normal(size=(n, n))) / f ** 1.8
    spec[0, 0] = 0
    cloud = np.real(np.fft.ifft2(spec))
    cloud = (cloud - cloud.min()) / (cloud.max() - cloud.min())
    specks = (rng.random((n, n)) > .9985).astype(np.float64)
    blur = np.real(np.fft.ifft2(np.fft.fft2(specks) * np.exp(-(fx * fx + fy * fy) * (n * .9) ** 2 * .5 / (n * n) * 40)))
    img = np.clip(.15 + .75 * cloud ** 1.4 + blur * 6.0, 0, 1)
    save_gray(img, "beam_dust.png")


def menu_pool():
    """The menus' cursor: the same flashlight's pool, softer (no dark dot at its heart), drawn small."""
    n = 256
    y, x = np.mgrid[0:n, 0:n]
    u = (x - n / 2 + .5) / (n / 2)
    v = (y - n / 2 + .5) / (n / 2)
    r = np.sqrt(u * u + v * v)
    e = np.exp(-(r / .42) ** 2.2) * .85 + .12 * np.exp(-((r - .62) / .05) ** 2) + .07 * np.exp(-((r - .78) / .04) ** 2)
    e *= smooth(1.0, .9, r)
    save_gray(e / e.max(), "menu_pool.png")


def glare():
    """What the body camera's lens does with his flashlight pointed into it: a hot core, a long flat streak, a ghost
    ring (the lens' own reflections)."""
    w, h = 512, 256
    y, x = np.mgrid[0:h, 0:w]
    u = (x - w / 2 + .5) / (h / 2)
    v = (y - h / 2 + .5) / (h / 2)
    r = np.sqrt(u * u + v * v)
    core = np.exp(-(r / .16) ** 2) + .45 * np.exp(-(r / .45) ** 2)
    streak = np.exp(-(v / .035) ** 2) * np.exp(-(np.abs(u) / 1.3) ** 1.5) * .7
    ring = .08 * np.exp(-((r - .72) / .05) ** 2)
    e = np.clip(core + streak + ring, 0, 1.3) / 1.3
    rgb = np.stack([e, e * .86, e * .66], -1)
    out = np.dstack([rgb, e])
    Image.fromarray((np.clip(out, 0, 1) * 255 + .5).astype(np.uint8), "RGBA").save(os.path.join(ART, "glare.png"))


# ------------------------------------------------------------------ sound

SR = 44100


def write_wav(name, sig):
    sig = sig / max(1e-6, np.max(np.abs(sig))) * .89
    data = (sig * 32767).astype(np.int16)
    with wave.open(os.path.join(SND, name), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(data.tobytes())


def bandpass(sig, lo, hi):
    spec = np.fft.rfft(sig)
    freqs = np.fft.rfftfreq(len(sig), 1 / SR)
    gain = smooth(lo * .7, lo, freqs) * smooth(hi * 1.3, hi, freqs)
    return np.fft.irfft(spec * gain, len(sig))


def room(sig, seconds=.7, wet=.28):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = rng.normal(0, 1, n) * np.exp(-t * 7.0)
    ir = bandpass(ir, 300, 6000)
    ir[0] = 0
    w = np.convolve(sig, ir)[: len(sig) + n]
    dry = np.concatenate([sig, np.zeros(n)])[: len(w)]
    return dry + w / np.max(np.abs(w)) * np.max(np.abs(sig)) * wet


def blast(seconds, f0=2950.0, drop=.0):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    env = smooth(0, .03, t) * smooth(seconds, seconds - .07, t)
    env *= 1.0 + .25 * np.sin(2 * np.pi * 3.1 * t + rng.random() * 6)
    # The pea: its spin warbles the pitch and chops the tone.
    pea = 31.0 + 6.0 * np.sin(2 * np.pi * .9 * t)
    phase_pea = 2 * np.pi * np.cumsum(pea) / SR
    freq = f0 * (1.0 - drop * smooth(seconds * .55, seconds, t)) + 210.0 * np.sin(phase_pea) + rng.normal(0, 18, n).cumsum() * .002
    tone = np.sin(2 * np.pi * np.cumsum(freq) / SR)
    tone += .22 * np.sin(2 * 2 * np.pi * np.cumsum(freq) / SR)
    chop = .62 + .38 * (.5 + .5 * np.sin(phase_pea + .6)) ** 1.5
    air = bandpass(rng.normal(0, 1, n), f0 * .8, f0 * 1.25) * .6 + bandpass(rng.normal(0, 1, n), 900, 9000) * .12
    # Through a ruined mouth: a wet rasp under it, in time with the pea.
    rasp = bandpass(rng.normal(0, 1, n) * (.5 + .5 * np.sign(np.sin(phase_pea * .5))), 90, 700) * .35
    return (tone * chop * .9 + air * chop + rasp) * env


def whistle_call():
    parts = [blast(.32, 2980), np.zeros(int(.13 * SR)), blast(.3, 2940), np.zeros(int(.16 * SR)), blast(1.45, 2900, .07)]
    write_wav("whistle_call.wav", room(np.concatenate(parts)))


def whistle_inhale():
    seconds = 2.2
    n = int(seconds * SR)
    t = np.arange(n) / SR
    env = smooth(0, 1.8, t) ** 1.3 * smooth(seconds, seconds - .12, t)
    breath = bandpass(rng.normal(0, 1, n), 700, 5200)
    rattle = np.zeros(n)
    i = int(.15 * SR)
    while i < n:
        k = rng.integers(60, 240)
        rattle[i:i + 40] += np.hanning(40) * rng.uniform(.4, 1.0)
        i += int(SR / rng.uniform(18, 34))
    rattle = bandpass(rattle, 1800, 4200) * 3.0
    gurgle = bandpass(rng.normal(0, 1, n) * (np.sin(2 * np.pi * 7 * t) > .3), 120, 600) * .5
    write_wav("whistle_inhale.wav", room((breath * .7 + rattle * smooth(.4, 1.6, t) + gurgle) * env, .5, .2))


def torch_click():
    n = int(.12 * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for at, amp in ((.004, 1.0), (.021, .55)):
        k = int(at * SR)
        m = int(.006 * SR)
        burst = rng.normal(0, 1, m) * np.exp(-np.arange(m) / (m * .18))
        sig[k:k + m] += burst * amp
    body = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * d) for f, d in ((3100, 260), (5600, 380), (1700, 200)))
    sig = bandpass(sig, 1200, 11000) + np.convolve(sig, body[:400] * .02)[:n]
    write_wav("torch_click.wav", sig)


if __name__ == "__main__":
    os.makedirs(ART, exist_ok=True)
    os.makedirs(SND, exist_ok=True)
    cookie()
    lane()
    anino()
    dust()
    menu_pool()
    glare()
    whistle_call()
    whistle_inhale()
    torch_click()
    for d in (ART, SND):
        for f in sorted(os.listdir(d)):
            if not f.endswith(".import"):
                print(os.path.join(d, f), os.path.getsize(os.path.join(d, f)))
