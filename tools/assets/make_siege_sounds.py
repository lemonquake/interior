"""Synthesised sounds for the walled town (0.23), written to game/assets/audio/siege/:

    python tools/assets/make_siege_sounds.py

- bang_a .. bang_d   something on the far side of the sheet-iron wall hitting it: a body thump, the corrugated sheet
                     booming and ringing, its nails rattling in the rails; two to five blows, irregular;
- scrape             something dragged slowly along the outside of the sheets (nails, fingernails, a rake: unclear);
- groan_a .. groan_c a voice beyond the wall, low and wet, through the sheets and the distance (formant synthesis);
- rattle             a loose top sheet lifting and clacking on its one nail in the wind (seamless loop);
- sting              the low swell under the hooded man's cutscene.
All original (numpy), so no credit is owed. Helpers come from make_basement_sounds.py.
"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_basement_sounds as snd  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
snd.OUT = os.path.join(ROOT, 'game', 'assets', 'audio', 'siege')
SR = snd.SR
bp, lp, hp, t_, write = snd.bp, snd.lp, snd.hp, snd.t_, snd.write
RNG = np.random.default_rng(2323)


def sheet_ring(t, strength, seed):
    """A corrugated sheet struck flat: a dense cluster of inharmonic panel modes, the low ones decaying slowest."""
    rng = np.random.default_rng(seed)
    out = np.zeros_like(t)
    for _ in range(46):
        f = rng.uniform(70, 2600) ** 1.0
        decay = rng.uniform(.12, .9) * (300 / (f + 200)) ** .4
        amp = rng.uniform(.3, 1) * (180 / (f + 90)) ** .55
        out += amp * np.exp(-t / decay) * np.sin(2 * np.pi * f * t * (1 + .003 * np.sin(2 * np.pi * 3 * t)) + rng.uniform(0, 6.28))
    return out * strength


def blow(sec, seed, strength=1.0):
    rng = np.random.default_rng(seed)
    t = t_(sec)
    thump = np.exp(-t / .05) * np.sin(2 * np.pi * (55 + 30 * np.exp(-t / .02)) * t) * 1.6
    crack = hp(RNG.normal(0, 1, t.size) * np.exp(-t / .012), 900) * .6
    ring = sheet_ring(t, .55, seed)
    # Nails and the rail: a few short ticks right after the blow.
    ticks = np.zeros_like(t)
    for _ in range(rng.integers(3, 9)):
        at = rng.uniform(.01, .25)
        n = int(at * SR)
        k = np.exp(-np.arange(t.size - n) / SR / .004)
        ticks[n:] += k * rng.normal(0, 1, t.size - n) * rng.uniform(.2, .5)
    return (thump + crack + ring + hp(ticks, 2500)) * strength


def bang(name, seed, blows):
    rng = np.random.default_rng(seed)
    total = 4.2
    x = np.zeros(int(total * SR))
    at = rng.uniform(.05, .2)
    for i in range(blows):
        b = blow(1.6, seed * 10 + i, rng.uniform(.55, 1.0))
        n = int(at * SR)
        m = min(b.size, x.size - n)
        x[n:n + m] += b[:m]
        at += rng.uniform(.35, .9) if rng.random() < .7 else rng.uniform(1.0, 1.5)
        if at > total - 1.2:
            break
    # Heard through the sheets from the other side: the top is dulled.
    x = lp(x, 3200) * .8 + lp(x, 600) * .4
    write(name, x, peak=.92)


def scrape():
    t = t_(4.2)
    env = np.clip(np.sin(np.pi * t / t[-1]), 0, 1) ** .6
    rough = RNG.normal(0, 1, t.size)
    # Stick-slip: the scraper catches on each corrugation as it moves along.
    speed = .35 + .25 * np.sin(2 * np.pi * .3 * t)
    pos = np.cumsum(speed) / SR
    catch = (np.sin(2 * np.pi * pos / .076) > .6).astype(float)
    catch = lp(catch, 400)
    grit = bp(rough, 1800, 5200) * (.3 + .7 * catch)
    body = bp(rough, 300, 900) * catch * .6
    ring = sheet_ring(t, .08, 9) * catch
    write('scrape', (grit + body + ring) * env, peak=.8)


def glottal(f0, t):
    """A rough voice source: a pulse train at f0(t) with jitter and shimmer."""
    phase = np.cumsum(f0 * (1 + .03 * RNG.normal(0, 1, t.size))) / SR
    saw = 2 * (phase % 1.0) - 1
    pulses = np.maximum(0, np.sin(2 * np.pi * phase)) ** 3
    return pulses * 1.4 + saw * .25


def formant(x, freqs, bws, gains):
    out = np.zeros_like(x)
    for f, bw, g in zip(freqs, bws, gains):
        out += bp(x, max(40, f - bw / 2), f + bw / 2, order=2) * g
    return out


def groan(name, seed, sec, f_start, f_end, vowel):
    rng = np.random.default_rng(seed)
    t = t_(sec)
    f0 = np.interp(t, [0, sec * .3, sec * .7, sec], [f_start, f_start * 1.08, f_end * 1.02, f_end])
    f0 = f0 * (1 + .04 * np.sin(2 * np.pi * rng.uniform(3, 6) * t))
    src = glottal(f0, t)
    # Vocal fry and a wet, gargling throat: amplitude chopped at a slow irregular rate.
    fry = .55 + .45 * (lp(rng.normal(0, 1, t.size), 25) > 0)
    src = src * fry
    shapes = {"o": ([420, 820, 2500], [140, 180, 260], [1.0, .5, .15]),
              "u": ([330, 760, 2350], [120, 160, 240], [1.0, .35, .1]),
              "a": ([640, 1100, 2550], [170, 200, 280], [1.0, .6, .2])}
    voice = formant(src, *shapes[vowel])
    breath = bp(rng.normal(0, 1, t.size), 500, 2500) * .15
    env = np.interp(t, [0, .25, sec * .55, sec - .6, sec], [0, 1, .9, .55, 0])
    x = (voice + breath) * env
    # Far away and behind sheet iron: dull, a little reverberant.
    x = lp(x, 1400)
    tail = np.zeros_like(x)
    for d, g in ((.09, .35), (.17, .22), (.31, .14), (.52, .08)):
        n = int(d * SR)
        tail[n:] += x[:-n] * g
    write(name, x + lp(tail, 900), peak=.8)


def rattle():
    t = t_(14.0)
    x = np.zeros_like(t)
    at = .3
    while at < 13.2:
        n = int(at * SR)
        k = blow(.6, int(at * 100), RNG.uniform(.08, .25))
        k = hp(k, 250)
        m = min(k.size, x.size - n)
        x[n:n + m] += k[:m]
        at += RNG.choice([.12, .18, .25, .9, 1.6, 2.4])
    wind = bp(RNG.normal(0, 1, t.size), 200, 1200) * (.03 + .03 * np.sin(2 * np.pi * t / 7))
    write('rattle', x + wind, peak=.6, loop=True)


def sting():
    """Under the hooded man's cutscene (8.6 s): a low cluster swelling in, a thin high tone bending against it, a
    thud at the moment he lets go of the gate (3.7 s), then the swell drains away."""
    t = t_(9.0)
    swell = np.interp(t, [0, 2.4, 3.7, 6.5, 9.0], [0, .55, 1.0, .5, 0]) ** 1.3
    low = np.zeros_like(t)
    for f, g in ((41.2, 1.0), (43.65, .8), (61.7, .5), (82.4, .35)):
        low += np.sin(2 * np.pi * f * t + np.sin(2 * np.pi * .13 * t) * 2) * g
    low = lp(low * (1 + .3 * np.sin(2 * np.pi * .7 * t)), 260)
    bend = 1720 * (1 + .012 * np.clip(t - 2.6, 0, None))
    high = np.sin(2 * np.pi * np.cumsum(bend) / SR) * .07 + np.sin(2 * np.pi * 1693 * t) * .06
    air = bp(RNG.normal(0, 1, t.size), 900, 4000) * .05
    hit = np.zeros_like(t)
    n = int(3.7 * SR)
    k = t[: t.size - n]
    hit[n:] = np.exp(-k / .35) * np.sin(2 * np.pi * 48 * k) * 1.4
    write('sting', (low * .9 + high + air) * swell + lp(hit, 300), peak=.85)


def main():
    os.makedirs(snd.OUT, exist_ok=True)
    sting()
    bang('bang_a', 3, 3)
    bang('bang_b', 5, 5)
    bang('bang_c', 7, 2)
    bang('bang_d', 11, 4)
    scrape()
    groan('groan_a', 31, 3.4, 92, 74, "o")
    groan('groan_b', 37, 2.6, 118, 86, "u")
    groan('groan_c', 41, 4.0, 80, 70, "a")
    rattle()


if __name__ == '__main__':
    main()
