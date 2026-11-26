"""Interior 0.28: the infected's voices and the blood set.

    python tools/zombie_assets.py [audio] [blood]

audio  -> game/assets/audio/zombies/*.ogg, synthesised here (no recordings): a rough glottal pulse train through
          drifting vowel formants for groans, growls, screams, snarls and death rattles; thuds and wet noise for
          rounds going into a body; the player's grunt.
blood  -> game/assets/zombies/blood/*.png: the project's own red-liquid graphics (assets/horror_textures/liquid,
          assets/nichols/blood) cut into a set of splats, each with a normal map made from its own thickness, so
          the decals take light like something wet.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter
from scipy import signal

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
AUDIO = os.path.join(ROOT, "game", "assets", "audio", "zombies")
BLOOD = os.path.join(ROOT, "game", "assets", "zombies", "blood")
SR = 44100


# ---------------------------------------------------------------- audio

def env(n, attack, release, rng=None, tremor=0.0):
    t = np.arange(n) / SR
    e = np.clip(t / max(attack, 1e-4), 0, 1) * np.clip((n / SR - t) / max(release, 1e-4), 0, 1)
    e = e ** 1.5
    if tremor > 0.0 and rng is not None:
        wob = signal.lfilter(*signal.butter(2, 9.0 / (SR / 2)), rng.standard_normal(n)) * 60.0
        e *= 1.0 + tremor * np.clip(wob, -1, 1)
    return e


def formants(x, sets, n):
    """Parallel resonators; `sets` is a list of [(freq, q, gain)...] crossfaded over the sound."""
    out = np.zeros(n)
    k = len(sets)
    for i, bank in enumerate(sets):
        w = np.clip(1.0 - np.abs(np.linspace(0, k - 1, n) - i), 0, 1) if k > 1 else np.ones(n)
        y = np.zeros(n)
        for freq, q, gain in bank:
            b, a = signal.iirpeak(freq / (SR / 2), q)
            y += gain * signal.lfilter(b, a, x)
        out += y * w
    return out


def voice(rng, dur, f0, f1, rough, sets, breath=0.25, drive=1.5, attack=0.08, release=0.25, fry=0.4, tremor=0.25):
    n = int(dur * SR)
    t = np.linspace(0, 1, n)
    wander = signal.lfilter(*signal.butter(2, 6.0 / (SR / 2)), rng.standard_normal(n)) * 40.0
    freq = (f0 + (f1 - f0) * t ** 0.8) * (1.0 + 0.06 * np.sin(t * dur * 31.0) * rough + rough * 0.25 * np.clip(wander, -1, 1))
    phase = np.cumsum(freq) / SR
    saw = 2.0 * (phase % 1.0) - 1.0
    pulse = -np.maximum(0.0, 1.0 - (phase % 1.0) * 3.2) ** 2 + 0.35 * saw
    # Vocal fry: every other pulse weaker, some dropped, and breath noise let through with each pulse.
    cycle = np.floor(phase).astype(int)
    strength = 1.0 - fry * (cycle % 2) * 0.8 - fry * (rng.random(cycle.max() + 2)[cycle] < 0.18)
    src = pulse * strength
    noise = rng.standard_normal(n)
    src = src + breath * noise * (0.4 + 0.6 * (1.0 - (phase % 1.0)))
    y = formants(src, sets, n)
    y = np.tanh(y * drive / (np.abs(y).max() + 1e-9) * 2.2)
    y = signal.lfilter(*signal.butter(2, [70.0 / (SR / 2), 6500.0 / (SR / 2)], "band"), y)
    return y * env(n, attack, release, rng, tremor)


UH = [(430, 6, 1.0), (980, 8, 0.55), (2400, 9, 0.22)]
AH = [(720, 5, 1.0), (1150, 7, 0.7), (2600, 9, 0.3)]
OH = [(520, 6, 1.0), (860, 8, 0.6), (2500, 9, 0.2)]
EH = [(600, 5, 1.0), (1750, 8, 0.6), (2700, 9, 0.35)]


def thud(rng, dur, f0, f1):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t * 30.0)
    return np.sin(np.cumsum(f) / SR * 2 * np.pi) * np.exp(-t * 22.0)


def wet(rng, dur, f_hi, f_lo, grains=14.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    out = np.zeros(n)
    for k, f in enumerate(np.geomspace(f_hi, f_lo, 5)):
        b, a = signal.iirpeak(f / (SR / 2), 3.0)
        w = np.clip(1.0 - np.abs(np.linspace(0, 4, n) - k), 0, 1)
        out += signal.lfilter(b, a, noise) * w
    grain = 0.5 + 0.5 * np.sign(np.sin(t * grains * 2 * np.pi + rng.random() * 6) + rng.standard_normal(n) * 0.2)
    grain = signal.lfilter(*signal.butter(1, 300.0 / (SR / 2)), grain)
    return out * grain * np.exp(-t * (3.5 / dur))


def save(name, y, peak=0.85):
    import soundfile as sf
    os.makedirs(AUDIO, exist_ok=True)
    y = np.asarray(y, np.float64)
    y = y / (np.abs(y).max() + 1e-9) * peak
    fade = min(len(y) // 4, int(0.01 * SR))
    y[:fade] *= np.linspace(0, 1, fade)
    y[-fade:] *= np.linspace(1, 0, fade)
    sf.write(os.path.join(AUDIO, name + ".ogg"), y.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    print("audio", name, round(len(y) / SR, 2))


def audio():
    rng = np.random.default_rng(28)
    # Roaming: long low groans.
    save("groan_1", voice(rng, 2.6, 78, 62, 0.5, [UH, OH, UH], breath=0.3, fry=0.6, release=0.9, attack=0.4))
    save("groan_2", voice(rng, 1.9, 92, 70, 0.6, [OH, AH, UH], breath=0.35, fry=0.5, release=0.7, attack=0.25))
    save("groan_3", voice(rng, 3.1, 66, 58, 0.7, [UH, UH, OH], breath=0.45, fry=0.8, release=1.1, attack=0.5))
    save("groan_4", voice(rng, 1.4, 104, 84, 0.5, [EH, UH], breath=0.3, fry=0.45, release=0.5, attack=0.15))
    # Chasing: short hard growls and barks of breath.
    save("growl_1", voice(rng, 0.9, 110, 86, 0.9, [AH, OH], breath=0.5, drive=3.0, fry=0.7, release=0.3, attack=0.04))
    save("growl_2", voice(rng, 1.2, 96, 120, 1.0, [OH, AH, AH], breath=0.55, drive=3.2, fry=0.6, release=0.35, attack=0.05))
    save("growl_3", voice(rng, 0.7, 128, 92, 0.9, [AH, EH], breath=0.5, drive=3.0, fry=0.75, release=0.25, attack=0.03))
    # Seeing someone: a scream.
    save("scream_1", voice(rng, 1.5, 210, 330, 1.3, [AH, EH, AH], breath=0.8, drive=5.0, fry=0.35, release=0.45, attack=0.05, tremor=0.5))
    save("scream_2", voice(rng, 1.2, 260, 240, 1.5, [EH, AH], breath=0.9, drive=5.5, fry=0.45, release=0.4, attack=0.04, tremor=0.6))
    save("scream_3", voice(rng, 1.8, 170, 290, 1.2, [OH, AH, EH], breath=0.75, drive=4.5, fry=0.4, release=0.6, attack=0.08, tremor=0.5))
    # Lunging.
    save("attack_1", voice(rng, 0.5, 150, 100, 1.1, [AH, AH], breath=0.7, drive=4.0, fry=0.5, release=0.2, attack=0.02))
    save("attack_2", voice(rng, 0.6, 130, 170, 1.2, [EH, AH], breath=0.75, drive=4.2, fry=0.5, release=0.22, attack=0.02))
    # Going down.
    save("death_1", voice(rng, 1.6, 120, 55, 0.9, [AH, UH, UH], breath=0.7, drive=2.2, fry=0.9, release=1.0, attack=0.03))
    save("death_2", voice(rng, 1.1, 100, 60, 1.0, [OH, UH], breath=0.8, drive=2.4, fry=0.95, release=0.7, attack=0.03))
    save("hurt_1", voice(rng, 0.35, 135, 105, 0.9, [EH, AH], breath=0.6, drive=3.2, fry=0.6, release=0.15, attack=0.015))
    save("hurt_2", voice(rng, 0.4, 118, 96, 1.0, [AH, UH], breath=0.6, drive=3.2, fry=0.7, release=0.18, attack=0.015))
    # Rounds into a body, and what falls out.
    for k in range(3):
        n = int(0.28 * SR)
        y = np.zeros(n)
        a = thud(rng, 0.16, 150 - 15 * k, 55)
        y[:len(a)] += a * 1.0
        b = wet(rng, 0.26, 2600 - 300 * k, 500, grains=22.0 + 6 * k)
        y[:len(b)] += b * 0.8
        crack = rng.standard_normal(int(0.012 * SR)) * np.linspace(1, 0, int(0.012 * SR))
        y[:len(crack)] += crack * 0.5
        save("flesh_%d" % (k + 1), y)
    for k in range(2):
        save("splat_%d" % (k + 1), wet(rng, 0.42 + 0.1 * k, 1900, 380, grains=9.0 + 5 * k), peak=0.6)
    # The player, hit.
    save("player_hurt_1", voice(rng, 0.32, 150, 112, 0.5, [EH, UH], breath=0.35, drive=2.0, fry=0.2, release=0.14, attack=0.01), peak=0.7)
    save("player_hurt_2", voice(rng, 0.38, 138, 100, 0.5, [AH, UH], breath=0.4, drive=2.0, fry=0.25, release=0.16, attack=0.01), peak=0.7)
    y = thud(rng, 0.2, 120, 45)
    y[:int(0.03 * SR)] += rng.standard_normal(int(0.03 * SR)) * np.linspace(0.7, 0, int(0.03 * SR))
    save("claw_hit", y)


# ---------------------------------------------------------------- blood

def normal_from(alpha, lum, strength):
    """Thickness = soft alpha, a little thicker where the picture is darker; its slope is the normal."""
    h = np.asarray(Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3.5)), np.float32) / 255.0
    h = h * (0.75 + 0.25 * (1.0 - lum))
    gy, gx = np.gradient(h)
    n = np.dstack([-gx * strength, gy * strength, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def write_set(name, img, size, strength=9.0):
    img = img.convert("RGBA").resize((size, size), Image.LANCZOS)
    a = np.asarray(img, np.float32) / 255.0
    # Deeper and more even than the source: arterial red going to near black where it lies thick.
    lum = a[..., :3].mean(axis=2)
    rgb = np.dstack([0.05 + 0.52 * lum ** 0.8 + 0.1, 0.004 + 0.035 * lum, 0.004 + 0.03 * lum])
    alpha = np.clip(a[..., 3] * 1.15, 0, 1)
    out = np.dstack([np.clip(rgb, 0, 1), alpha])
    os.makedirs(BLOOD, exist_ok=True)
    Image.fromarray((out * 255).astype(np.uint8), "RGBA").save(os.path.join(BLOOD, name + "_albedo.png"))
    Image.fromarray(normal_from(alpha, lum, strength), "RGB").save(os.path.join(BLOOD, name + "_normal.png"))
    print("blood", name, size, round(float(alpha.mean()), 3))


def feather(img, box):
    crop = img.crop(box)
    w, h = crop.size
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.minimum(np.minimum(xx, w - 1 - xx) / (w * 0.16), np.minimum(yy, h - 1 - yy) / (h * 0.16))
    arr = np.asarray(crop, np.float32)
    arr[..., 3] *= np.clip(d, 0, 1)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def blood():
    liquid = os.path.join(ROOT, "game", "assets", "horror_textures", "liquid")
    nichols = os.path.join(ROOT, "game", "assets", "nichols", "blood")
    splat = Image.open(os.path.join(liquid, "splatter.png")).convert("RGBA")
    pool = Image.open(os.path.join(liquid, "pool.png")).convert("RGBA")
    drops = Image.open(os.path.join(nichols, "drops_albedo.png")).convert("RGBA")
    w, h = splat.size
    write_set("splat_a", splat, 512)
    write_set("splat_b", splat.transpose(Image.FLIP_LEFT_RIGHT), 512)
    # Parts of the big splat read as smaller, different ones (all keep their drips running down the picture).
    write_set("splat_c", feather(splat, (int(w * 0.02), int(h * 0.02), int(w * 0.62), int(h * 0.62))), 512)
    write_set("splat_d", feather(splat, (int(w * 0.38), int(h * 0.30), int(w * 0.98), int(h * 0.90))), 512)
    write_set("splat_e", feather(splat, (int(w * 0.20), int(h * 0.40), int(w * 0.70), int(h * 0.98))), 512)
    write_set("pool_a", pool, 512, strength=6.0)
    write_set("pool_b", pool.transpose(Image.ROTATE_90).transpose(Image.FLIP_LEFT_RIGHT), 512, strength=6.0)
    write_set("drops_a", drops, 256, strength=12.0)
    write_set("drops_b", drops.transpose(Image.ROTATE_180), 256, strength=12.0)
    # A soft puff for the mist, and a streaked drop for what flies.
    size = 64
    yy, xx = np.mgrid[0:size, 0:size]
    d = np.hypot(xx - size / 2 + 0.5, yy - size / 2 + 0.5) / (size / 2)
    ang = np.arctan2(yy - size / 2, xx - size / 2)
    edge = 0.8 + 0.12 * np.sin(ang * 3 + 1.0) + 0.08 * np.sin(ang * 7)
    v = np.clip(1.0 - d / edge, 0, 1)
    puff = np.dstack([np.ones((size, size, 3)), v * v * (3 - 2 * v)])
    Image.fromarray((puff * 255).astype(np.uint8), "RGBA").save(os.path.join(BLOOD, "mist.png"))
    drop = np.clip(1.0 - np.hypot((xx - size / 2 + 0.5) / (size * 0.16), (yy - size * 0.62) / (size * 0.34)), 0, 1)
    tail = np.clip(1.0 - np.abs(xx - size / 2 + 0.5) / (size * 0.05 + (yy / size) * size * 0.1), 0, 1) * (yy < size * 0.62)
    v = np.clip(drop * 3.0 + tail, 0, 1)
    Image.fromarray((np.dstack([np.ones((size, size, 3)), v]) * 255).astype(np.uint8), "RGBA").save(os.path.join(BLOOD, "droplet.png"))
    print("blood mist, droplet")


if __name__ == "__main__":
    what = sys.argv[1:] or ["audio", "blood"]
    if "audio" in what:
        audio()
    if "blood" in what:
        blood()
