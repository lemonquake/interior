"""Synthesised sounds for the Nichols basement (0.22), written to game/assets/audio/nichols/:

    python tools/assets/make_basement_sounds.py

- switch_click.ogg   an old bakelite toggle switch snapping over (two contacts and the body knock);
- bulb_hum.ogg       a bare bulb on 60 Hz mains: the filament sings at 120 Hz and its harmonics (seamless loop);
- arc_buzz.ogg       a failing bulb arcing in its socket: buzz in bursts with crackle;
- flies.ogg          a few flies circling something under a tarp (seamless loop);
- drip.ogg           a drop falling into a puddle in a stone cellar;
- fridge_hum.ogg     an old refrigerator's compressor running, with a loose panel buzzing now and then (seamless loop);
- cellar_tone.ogg    the room tone underground: a low rumble and the house settling far above (seamless loop).
All original (numpy), so no credit is owed.
"""
import os

import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt, sosfiltfilt

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'game', 'assets', 'audio', 'nichols')
SR = 44100
RNG = np.random.default_rng(22)


def bp(x, lo, hi, order=2):
    return sosfiltfilt(butter(order, [lo, hi], 'bandpass', fs=SR, output='sos'), x)


def lp(x, f, order=2):
    return sosfiltfilt(butter(order, f, 'lowpass', fs=SR, output='sos'), x)


def hp(x, f, order=2):
    return sosfiltfilt(butter(order, f, 'highpass', fs=SR, output='sos'), x)


def t_(sec):
    return np.arange(int(sec * SR)) / SR


def write(name, x, peak=.89, loop=False):
    if loop:
        # Crossfade the tail into the head so the loop has no seam.
        n = int(.25 * SR)
        fade = np.linspace(0, 1, n)
        x = x.copy()
        x[:n] = x[:n] * fade + x[-n:] * (1 - fade)
        x = x[:-n]
    x = x / (np.max(np.abs(x)) or 1) * peak
    if not loop:
        f = int(.004 * SR)
        x[:f] *= np.linspace(0, 1, f)
        x[-f * 5:] *= np.linspace(1, 0, f * 5)
    with sf.SoundFile(os.path.join(OUT, name + '.ogg'), 'w', SR, 1, format='OGG', subtype='VORBIS') as out:
        # Written in blocks: libsndfile's Vorbis encoder crashed on one 16 s buffer written whole (0.23 tin_wind).
        x = x.astype('float32')
        for i in range(0, x.size, 8192):
            out.write(x[i:i + 8192])
    print('wrote', name, round(len(x) / SR, 2), 's')


def damped(f, decay, t, phase=0.0):
    return np.sin(2 * np.pi * f * t + phase) * np.exp(-t / decay)


def switch_click():
    t = t_(.3)
    x = np.zeros_like(t)
    for delay, gain in ((0.0, 1.0), (.017, .45)):
        tt = np.clip(t - delay, 0, None)
        on = (t >= delay).astype(float)
        burst = hp(RNG.normal(0, 1, len(t)), 1500) * np.exp(-tt / .0025) * on
        ring = (damped(3150, .012, tt) * .6 + damped(5600, .007, tt) * .35 + damped(2240, .02, tt) * .3) * on
        x += gain * (burst * .8 + ring)
    knock = damped(170, .03, t) * .5 + damped(410, .015, t) * .3
    x += knock
    write('switch_click', x)


def bulb_hum():
    t = t_(3.25)
    x = np.zeros_like(t)
    for k, a in enumerate((1.0, .55, .32, .22, .12, .08, .05)):
        f = 120 * (k + 1)
        x += a * np.sin(2 * np.pi * f * t + RNG.uniform(0, 6.28))
    x *= 1 + .05 * np.sin(2 * np.pi * .31 * t)
    hiss = bp(RNG.normal(0, 1, len(t)), 600, 3200) * .025
    whine = np.sin(2 * np.pi * 9400 * t) * .006
    write('bulb_hum', x * .5 + hiss + whine, peak=.6, loop=True)


def arc_buzz():
    t = t_(1.4)
    buzz = np.sign(np.sin(2 * np.pi * 120 * t)) * .5 + np.sin(2 * np.pi * 240 * t) * .3
    gate = np.zeros_like(t)
    k = 0
    while k < len(t):
        on = int(RNG.uniform(.02, .12) * SR)
        off = int(RNG.uniform(.01, .2) * SR)
        gate[k:k + on] = RNG.uniform(.4, 1.0)
        k += on + off
    gate = lp(gate, 60)
    crackle = np.zeros_like(t)
    for _ in range(90):
        i = RNG.integers(0, len(t) - 400)
        crackle[i:i + 300] += hp(RNG.normal(0, 1, 300), 2000) * np.exp(-np.arange(300) / 40) * RNG.uniform(.3, 1)
    x = lp(buzz, 3000) * gate + crackle * (gate > .2) * .7
    write('arc_buzz', x)


def flies():
    t = t_(8.25)
    x = np.zeros_like(t)
    for i in range(3):
        f0 = RNG.uniform(180, 235)
        vib = np.cumsum(f0 + 9 * lp(RNG.normal(0, 1, len(t)), 6) * 6 + 5 * np.sin(2 * np.pi * RNG.uniform(5, 9) * t)) / SR
        wave = sum(np.sin(2 * np.pi * h * vib) / h ** 1.1 for h in range(1, 12))
        # Each fly comes close and drifts away, sometimes lands (silence).
        env = lp(RNG.uniform(0, 1, len(t)) ** 3, .6)
        env = np.clip((env - env.min()) / (np.ptp(env) + 1e-9) * 1.4 - .2, 0, 1)
        x += wave * env
    x = bp(x, 150, 5000)
    write('flies', x, peak=.7, loop=True)


def drip():
    t = t_(1.2)
    f = 700 + 1400 * (1 - np.exp(-t / .012))
    drop = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / .045)
    tick = hp(RNG.normal(0, 1, len(t)), 3000) * np.exp(-t / .002) * .5
    dry = drop + tick
    # A stone cellar: short, dark reverb.
    ir_t = t_(.9)
    ir = RNG.normal(0, 1, len(ir_t)) * np.exp(-ir_t / .18)
    ir = lp(ir, 3500)
    wet = np.convolve(dry, ir)[:len(t)] * .05
    write('drip', dry * .8 + wet)


def cellar_tone():
    t = t_(10.25)
    brown = np.cumsum(RNG.normal(0, 1, len(t)))
    brown = hp(brown, 20)
    rumble = lp(brown, 110, 4)
    rumble /= np.max(np.abs(rumble))
    drone = np.sin(2 * np.pi * 55 * t) * .06 * (1 + .3 * np.sin(2 * np.pi * .07 * t))
    air = bp(RNG.normal(0, 1, len(t)), 200, 900) * .03
    # The house settling, far above: two soft creaks.
    creaks = np.zeros_like(t)
    for start in (2.8, 7.1):
        i = int(start * SR)
        n = int(.7 * SR)
        tt = np.arange(n) / SR
        fc = 180 + 60 * np.sin(2 * np.pi * 1.3 * tt)
        c = np.sin(2 * np.pi * np.cumsum(fc) / SR) * (np.sin(np.pi * tt / .7) ** 2) * (1 + .5 * np.sign(np.sin(2 * np.pi * 23 * tt)))
        creaks[i:i + n] += lp(c, 900) * .08
    write('cellar_tone', rumble * .7 + drone + air + creaks, peak=.5, loop=True)


def fridge_hum():
    t = t_(6.25)
    motor = sum(a * np.sin(2 * np.pi * f * t + RNG.uniform(0, 6.28)) for f, a in ((60, .5), (120, 1.0), (180, .35), (240, .25), (360, .12)))
    motor *= 1 + .06 * np.sin(2 * np.pi * .9 * t)
    rattle_gate = (np.sin(2 * np.pi * .37 * t) > .82).astype(float)
    rattle = np.sign(np.sin(2 * np.pi * 120 * t)) * lp(rattle_gate, 8) * .25
    hiss = bp(RNG.normal(0, 1, len(t)), 300, 1500) * .03
    write('fridge_hum', lp(motor, 1200) * .6 + lp(rattle, 2500) + hiss, peak=.6, loop=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    switch_click()
    bulb_hum()
    arc_buzz()
    flies()
    drip()
    cellar_tone()
    fridge_hum()


if __name__ == '__main__':
    main()
