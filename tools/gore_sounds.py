"""Interior 0.31: the sounds of a body coming apart.

    python tools/gore_sounds.py

Writes game/assets/audio/zombies/: flesh_4..6 (heavier hits), sploosh_1..3 (a wet hit that carries on),
tear_1..3 (flesh torn), bone_1..3 (a crack), gib_1..2 (pieces landing), thud_1..3 (a body meets the ground),
pellets_1..2 (a load of shot going in together), leap_1 (the leaper's snarl is the voices' own).

These are synthesised here (no recordings), like the voices in tools/zombie_assets.py. The owner asked for
ElevenLabs sound effects; that connector was not available in the session that made these. Every file is a slot:
drop a generated .ogg over any of them (same name) and the game plays it.
"""
import os
import sys

import numpy as np
from scipy import signal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zombie_assets as za  # noqa: E402

SR = za.SR


def pad(n):
    return np.zeros(int(n * SR))


def put(y, x, at, gain=1.0):
    a = int(at * SR)
    x = x[:max(0, len(y) - a)]
    y[a:a + len(x)] += x * gain


def lowpass(x, f, order=2):
    return signal.lfilter(*signal.butter(order, f / (SR / 2)), x)


def highpass(x, f, order=2):
    return signal.lfilter(*signal.butter(order, f / (SR / 2), "high"), x)


def band(x, lo, hi):
    return signal.lfilter(*signal.butter(2, [lo / (SR / 2), hi / (SR / 2)], "band"), x)


def slap(rng, dur=0.02, bright=3500.0):
    n = int(dur * SR)
    return lowpass(rng.standard_normal(n), bright) * np.linspace(1, 0, n) ** 2


def squelch(rng, dur, lo=260.0, hi=2400.0, rate=26.0, fall=1.0):
    """Wet matter moving: band noise through a filter that keeps jumping, chopped into soft irregular gulps."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    noise = rng.standard_normal(n)
    hop = int(SR / rate)
    for a in range(0, n, hop):
        f = np.exp(rng.uniform(np.log(lo), np.log(hi))) * (1.0 - 0.5 * fall * a / n)
        seg = noise[a:a + hop * 2]
        b, c = signal.iirpeak(min(f, SR * 0.45) / (SR / 2), rng.uniform(2.0, 6.0))
        g = signal.lfilter(b, c, seg) * np.hanning(len(seg)) * rng.uniform(0.3, 1.0)
        out[a:a + len(g)] += g
    return out * np.exp(-t * (3.0 / dur))


def bubble(rng, dur, count):
    """Thick liquid: short sine blips that rise as they close."""
    n = int(dur * SR)
    out = np.zeros(n)
    for _ in range(count):
        length = rng.uniform(0.012, 0.035)
        m = int(length * SR)
        f = rng.uniform(180.0, 620.0) * np.linspace(1.0, rng.uniform(1.4, 2.2), m)
        blip = np.sin(np.cumsum(f) / SR * 2 * np.pi) * np.hanning(m) * rng.uniform(0.3, 1.0)
        at = int(rng.uniform(0, max(1, n - m)) * (rng.uniform(0, 1) ** 0.6))
        out[at:at + m] += blip[:len(out[at:at + m])]
    return out


def crack(rng, dur=0.05, f=2200.0):
    """Something hard giving way: a click, and what it rings at."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = rng.standard_normal(n) * np.exp(-t * 220.0)
    for k in range(3):
        fr = f * rng.uniform(0.6, 1.7)
        y += 0.5 * np.sin(2 * np.pi * fr * t + rng.uniform(0, 6)) * np.exp(-t * rng.uniform(90.0, 180.0))
    return highpass(y, 500.0)


def rasp(rng, dur, lo=500.0, hi=3200.0):
    """Tearing: noise let through in an uneven run of little jerks that speeds up and gives."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    rate = 35.0 + 90.0 * (t / dur) ** 1.5
    phase = np.cumsum(rate * (1.0 + 0.5 * lowpass(rng.standard_normal(n), 30.0) * 8.0)) / SR
    gate = np.clip(np.sin(phase * 2 * np.pi) * 3.0, 0, 1) ** 2
    y = band(rng.standard_normal(n), lo, hi) * gate
    return y * np.clip(t / 0.02, 0, 1) * np.exp(-t * (2.2 / dur))


def main():
    rng = np.random.default_rng(31)
    # Heavier rounds going in: more body under them, a longer wet end.
    for k in range(3):
        y = pad(0.42)
        put(y, za.thud(rng, 0.22, 120 - 12 * k, 42), 0.0, 1.2)
        put(y, slap(rng, 0.018, 4200 - 500 * k), 0.0, 0.9)
        put(y, squelch(rng, 0.34, 300, 2800 - 300 * k, rate=30 + 5 * k), 0.008, 0.9)
        put(y, bubble(rng, 0.2, 5), 0.06, 0.25)
        za.save("flesh_%d" % (k + 4), y)
    # Sploosh: the hit, and then the wet carrying on and falling.
    for k in range(3):
        y = pad(0.85 + 0.1 * k)
        put(y, za.thud(rng, 0.2, 100 - 10 * k, 38), 0.0, 1.0)
        put(y, slap(rng, 0.03, 2600), 0.0, 0.7)
        put(y, squelch(rng, 0.6 + 0.1 * k, 180, 2100, rate=20 + 4 * k, fall=1.4), 0.01, 1.0)
        put(y, bubble(rng, 0.5, 12 + 3 * k), 0.05, 0.4)
        put(y, lowpass(za.wet(rng, 0.5, 1500, 300, grains=11.0 + 3 * k), 2500.0), 0.18, 0.5)
        za.save("sploosh_%d" % (k + 1), y, peak=0.8)
    # Tearing.
    for k in range(3):
        y = pad(0.5 + 0.06 * k)
        put(y, rasp(rng, 0.36 + 0.05 * k, 420 + 80 * k, 3000 - 200 * k), 0.0, 1.0)
        put(y, squelch(rng, 0.4, 240, 1800, rate=32), 0.04, 0.6)
        put(y, za.thud(rng, 0.12, 90, 50), 0.3 + 0.04 * k, 0.5)
        za.save("tear_%d" % (k + 1), y, peak=0.8)
    # Bone.
    for k in range(3):
        y = pad(0.3)
        put(y, crack(rng, 0.06, 1900 + 400 * k), 0.0, 1.0)
        put(y, crack(rng, 0.04, 2800 - 300 * k), rng.uniform(0.02, 0.05), 0.6)
        put(y, za.thud(rng, 0.14, 170 - 15 * k, 70), 0.0, 0.7)
        put(y, squelch(rng, 0.2, 300, 1600, rate=34), 0.03, 0.35)
        za.save("bone_%d" % (k + 1), y, peak=0.8)
    # Pieces landing: a handful of small wet falls.
    for k in range(2):
        y = pad(1.1)
        at = 0.0
        for i in range(6 + 2 * k):
            hit = pad(0.16)
            put(hit, za.thud(rng, 0.08, rng.uniform(110, 190), 60), 0.0, rng.uniform(0.5, 1.0))
            put(hit, squelch(rng, 0.14, 300, 2200, rate=36), 0.0, rng.uniform(0.4, 0.9))
            put(y, hit, at, 1.0 - 0.07 * i)
            at += rng.uniform(0.05, 0.19)
        za.save("gib_%d" % (k + 1), y, peak=0.75)
    # A body meets the ground: the weight, the cloth, and a limb a moment after.
    for k in range(3):
        y = pad(0.75)
        put(y, za.thud(rng, 0.3, 95 - 8 * k, 34), 0.0, 1.3)
        put(y, lowpass(rng.standard_normal(int(0.16 * SR)) * np.linspace(1, 0, int(0.16 * SR)) ** 2, 900.0), 0.0, 0.5)
        put(y, band(rng.standard_normal(int(0.3 * SR)), 300.0, 2600.0) * np.hanning(int(0.3 * SR)), 0.02, 0.12)
        put(y, za.thud(rng, 0.18, 120, 48), rng.uniform(0.16, 0.3), 0.55)
        put(y, slap(rng, 0.02, 1800), rng.uniform(0.2, 0.34), 0.3)
        za.save("thud_%d" % (k + 1), y, peak=0.85)
    # A load of shot: seven or eight balls going in inside a twentieth of a second.
    for k in range(2):
        y = pad(0.5)
        for i in range(7 + k):
            at = rng.uniform(0.0, 0.045)
            put(y, za.thud(rng, 0.1, rng.uniform(130, 200), 60), at, rng.uniform(0.6, 1.0))
            put(y, slap(rng, 0.012, rng.uniform(3000, 5200)), at, rng.uniform(0.5, 1.0))
        put(y, squelch(rng, 0.4, 260, 2600, rate=34), 0.02, 1.0)
        put(y, bubble(rng, 0.3, 8), 0.06, 0.3)
        za.save("pellets_%d" % (k + 1), y, peak=0.85)


if __name__ == "__main__":
    main()
