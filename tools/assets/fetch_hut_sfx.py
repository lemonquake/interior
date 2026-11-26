"""Download and cut the sounds for the 0.10 hut sequence (Wikimedia Commons), and synthesise the small ones.

    python tools/assets/fetch_hut_sfx.py

- siren_wail.ogg: a civil-defence siren (waver), public domain, cut to a seamless loop. Played by
  game/scripts/story.gd from several far points around the town and the fields.
- drawer_open.ogg: a wooden drawer sliding open (Gravity Sound, CC BY 4.0).
- lock_turn.ogg, key_pickup.ogg, gun_pickup.ogg, ammo_pickup.ogg: synthesised here (clicks and clinks).
0.11, the usable Glock (game/scripts/gun.gd):
- gun_shot.ogg: one 9 mm shot (Commons "9 mm gunshot", CC BY-SA 4.0), high-passed and trimmed.
- gun_rack.ogg: a slide racked (Commons "Gun Cocking Slow", CC BY-SA 4.0).
- gun_tail.ogg: the shot's far echo rolling back off the trees and houses (synthesised from gun_shot.ogg).
- gun_dry.ogg, gun_mag_out.ogg, gun_mag_in.ogg, gun_ricochet.ogg and the bullet impacts (hit_wood, hit_stone,
  hit_metal, hit_dirt, hit_glass, hit_water): synthesised here. (Commons has no free magazine recordings.)
Credits: game/licenses/NIGHT_SOUNDS.md (0.10 and 0.11 rows).
"""
import os, re, sys, time, urllib.parse
import numpy as np
import soundfile as sf
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fetch_fields import DL, ROOT, commons, get

OUT = os.path.join(ROOT, 'game', 'assets', 'audio', 'sfx')
RATE = 44100
# out name -> (file title, start s, length s)
CUTS = {
    'siren_wail': ('Civil-defense-siren-waver.ogg', 8.0, 48.0),
    'drawer_open': ('Open drawer (Gravity Sound).wav', 0.0, 2.0),
    'gun_shot': ('9 mm gunshot-mike-koenig-123.wav', 0.0, 1.0),
    'gun_rack': ('Gun Cocking Slow-Mike Koenig-1019236976.wav', 0.0, 0.78),
}

def _resample(mono, rate):
    if rate == RATE:
        return mono
    from math import gcd
    from scipy.signal import resample_poly
    g = gcd(int(rate), RATE)
    return resample_poly(mono, RATE // g, int(rate) // g)

def write(name, mono, peak=0.89):
    mono = mono / (np.max(np.abs(mono)) or 1.0) * peak
    with sf.SoundFile(os.path.join(OUT, name + '.ogg'), 'w', RATE, 1, format='OGG', subtype='VORBIS') as out:
        block = mono.astype('float32')
        for i in range(0, len(block), 2048):
            out.write(block[i:i + 2048])

def cut(src, name, start, length):
    data, rate = sf.read(src, always_2d=True)
    mono = _resample(data.mean(axis=1)[int(start * rate):int((start + length) * rate)], rate)
    if name == 'siren_wail':
        # Seamless loop: cross-fade the last 2 s into the first 2 s.
        x = int(RATE * 2.0)
        head, body = mono[:x], mono[x:]
        ramp = np.linspace(0, 1, x)
        body[-x:] = body[-x:] * (1 - ramp) + head * ramp
        mono = body
    elif name == 'gun_shot':
        from scipy.signal import butter, sosfiltfilt
        mono = sosfiltfilt(butter(2, 70, 'highpass', fs=RATE, output='sos'), mono)
        loud = np.nonzero(np.abs(mono) > np.max(np.abs(mono)) * 0.05)[0]
        mono = mono[max(0, loud[0] - 40):]
        n = mono.size
        mono *= np.exp(-np.arange(n) / RATE / 0.45)
        fade = int(RATE * 0.05)
        mono[-fade:] *= np.linspace(1, 0, fade)
    else:
        fade = int(RATE * 0.03)
        mono[-fade:] *= np.linspace(1, 0, fade)
        # Trim the silent tail.
        loud = np.nonzero(np.abs(mono) > np.max(np.abs(mono)) * 0.01)[0]
        if loud.size:
            mono = mono[max(0, loud[0] - 200):loud[-1] + 4000]
    write(name, mono)

def _click(t0, length, freq, decay, rng, noise=0.6):
    n = int(RATE * length)
    t = np.arange(n) / RATE
    tone = np.sin(2 * np.pi * freq * t) * 0.5 + np.sin(2 * np.pi * freq * 2.71 * t) * 0.3
    env = np.exp(-t / decay)
    return int(RATE * t0), (tone * (1 - noise) + rng.normal(0, 1, n) * noise) * env

def synth(name, parts, total):
    out = np.zeros(int(RATE * total))
    for start, wave in parts:
        out[start:start + wave.size] += wave[:max(0, out.size - start)]
    write(name, out, 0.8)

def main():
    os.makedirs(OUT, exist_ok=True)
    titles = sorted({spec[0] for spec in CUTS.values()})
    res = commons({'action': 'query', 'titles': '|'.join('File:' + t for t in titles), 'prop': 'imageinfo',
                   'iiprop': 'url|extmetadata', 'iiextmetadatafilter': 'LicenseShortName|Artist'})
    pages = {p['title']: p for p in res['query']['pages'].values()}
    for name, (title, start, length) in CUTS.items():
        ii = pages['File:' + title]['imageinfo'][0]
        src = get(ii['url'], os.path.join(DL, 'commons', re.sub(r'[^\w.\-]+', '_', title)))
        cut(src, name, start, length)
        meta = ii.get('extmetadata', {})
        print(name, '|', title, '|', re.sub('<[^>]+>', '', meta.get('Artist', {}).get('value', '')).strip(), '|',
              meta.get('LicenseShortName', {}).get('value'), '|', 'https://commons.wikimedia.org/wiki/File:' + urllib.parse.quote(title.replace(' ', '_')))
        time.sleep(1)
    rng = np.random.default_rng(1010)
    # A key going into a lock, two pin clicks, then the bolt turning over.
    synth('lock_turn', [_click(0.0, .05, 3400, .006, rng, .8), _click(.09, .04, 4100, .005, rng, .8),
                        _click(.16, .04, 3900, .005, rng, .8), _click(.42, .12, 1400, .02, rng, .55),
                        _click(.47, .08, 900, .03, rng, .4)], .8)
    # Small brass key lifted off wood: a soft knock and a little ring.
    synth('key_pickup', [_click(0.0, .06, 700, .012, rng, .7), _click(.03, .5, 5200, .09, rng, .05),
                         _click(.05, .5, 6900, .07, rng, .05)], .7)
    # A pistol lifted: polymer knock, a metallic slide tick.
    synth('gun_pickup', [_click(0.0, .1, 260, .03, rng, .5), _click(.12, .08, 2300, .012, rng, .6),
                         _click(.19, .1, 1800, .02, rng, .5)], .5)
    # A box of rounds: a cardboard thump and brass rattling.
    parts = [_click(0.0, .12, 180, .04, rng, .6)]
    for k in range(9):
        parts.append(_click(.05 + k * .035 + rng.uniform(0, .02), .12, rng.uniform(3800, 6200), .025, rng, .2))
    synth('ammo_pickup', parts, .7)
    gun_sounds()

def _noise_burst(length, decay, rng, lp=None, hp=None):
    from scipy.signal import butter, sosfilt
    n = int(RATE * length)
    x = rng.normal(0, 1, n) * np.exp(-np.arange(n) / RATE / decay)
    if lp:
        x = sosfilt(butter(2, lp, 'lowpass', fs=RATE, output='sos'), x)
    if hp:
        x = sosfilt(butter(2, hp, 'highpass', fs=RATE, output='sos'), x)
    return x

def gun_sounds():
    """0.11: the far echo tail, the dry click, magazine out/in, a ricochet and the bullet impacts."""
    from scipy.signal import butter, sosfilt
    rng = np.random.default_rng(1111)
    shot, _ = sf.read(os.path.join(OUT, 'gun_shot.ogg'))
    # Far echo: the shot, dark and smeared, coming back two or three times off the tree lines and houses.
    tail = np.zeros(int(RATE * 3.2))
    dark = sosfilt(butter(2, 900, 'lowpass', fs=RATE, output='sos'), shot)
    for delay, gain in ((.32, .55), (.71, .38), (1.18, .25), (1.7, .14)):
        smear = np.convolve(dark, np.exp(-np.arange(int(RATE * .05)) / RATE / .015))[:dark.size]
        a = int(RATE * delay)
        tail[a:a + smear.size] += smear[:max(0, tail.size - a)] * gain
    tail += _noise_burst(3.2, .9, rng, lp=500) * .02
    write('gun_tail', tail, .6)
    # Dry fire: the striker falling on nothing, a light polymer click.
    synth('gun_dry', [_click(0.0, .03, 2600, .004, rng, .7), _click(.012, .05, 1200, .008, rng, .5)], .2)
    # Magazine release and drop out of the grip; a fresh one pushed home and seated.
    synth('gun_mag_out', [_click(0.0, .04, 3000, .005, rng, .7), _click(.03, .12, 700, .03, rng, .6),
                          _click(.08, .18, 420, .05, rng, .7)], .4)
    synth('gun_mag_in', [_click(0.0, .1, 520, .03, rng, .7), _click(.11, .05, 2600, .006, rng, .8),
                         _click(.125, .06, 1500, .01, rng, .6)], .35)
    # Ricochet: a whine falling in pitch.
    n = int(RATE * .55)
    t = np.arange(n) / RATE
    f = 3200 * np.exp(-t * 2.2) + 600
    whine = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t / .22) * np.minimum(1, t / .01)
    write('gun_ricochet', whine + _noise_burst(.55, .02, rng, hp=2000)[:n] * .3, .6)
    # Impacts, by surface.
    write('hit_wood', _noise_burst(.25, .03, rng, lp=2200) + _click(0, .25, 380, .04, rng, .3)[1] * .6, .8)
    write('hit_stone', _noise_burst(.4, .025, rng, hp=900) + _noise_burst(.4, .12, rng, lp=3000) * .25, .8)
    write('hit_metal', _noise_burst(.5, .01, rng, hp=1500) * .5 + _click(0, .5, 2100, .12, rng, .05)[1], .8)
    write('hit_dirt', _noise_burst(.3, .05, rng, lp=900), .7)
    glass = _noise_burst(.6, .015, rng, hp=3000) * .6
    for k in range(6):
        a = int(RATE * rng.uniform(.01, .2))
        c = _click(0, .3, rng.uniform(4000, 8000), .03, rng, .1)[1] * .4
        glass[a:a + c.size] += c[:max(0, glass.size - a)]
    write('hit_glass', glass, .7)
    splash = _noise_burst(.7, .12, rng, lp=2500, hp=200)
    splash[:int(RATE * .02)] *= np.linspace(0, 1, int(RATE * .02))
    write('hit_water', splash, .7)

if __name__ == '__main__':
    sys.exit(main())
