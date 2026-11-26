"""0.36: cuts the player's breathing out of two CC0 recordings (game/licenses/BREATHING_SOUNDS.md).

  python -I tools/breath_sounds.py <folder with the two downloaded previews>

Needs numpy, scipy and soundfile. Reads
  554907_9250976-hq.ogg   Nox_Sound, "Male_Breath_Fast_Loop_Stereo.wav"   https://freesound.org/s/554907/
  474647_1750817-hq.ogg   fadyhaddad, "Male Heavy Breathing.wav"          https://freesound.org/s/474647/
and writes, as mono 44.1 kHz 16-bit WAV in game/assets/audio/sfx/:
  breath_pant.wav          the fast loop, whole, its ends eased so it repeats without a tick
  breath_heavy_<n>.wav     one slow breath each (in, then out), the room's hush between them left out
scripts/body.gd plays them. Both are levelled here, each file by one gain, so the breaths keep the loudness
they had against one another.
"""
import os, sys
import numpy as np
import soundfile as sf
from scipy.signal import resample_poly, butter, sosfiltfilt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'game', 'assets', 'audio', 'sfx')
RATE = 44100


def read(path):
    audio, rate = sf.read(path, dtype='float32', always_2d=True)
    audio = audio.mean(axis=1)
    if rate != RATE:
        from math import gcd
        g = gcd(RATE, rate)
        audio = resample_poly(audio, RATE // g, rate // g).astype(np.float32)
    # Rumble under a breath is only handling noise.
    return sosfiltfilt(butter(2, 70.0, 'highpass', fs=RATE, output='sos'), audio).astype(np.float32)


def ease(audio, seconds_in, seconds_out):
    audio = audio.copy()
    a, b = int(RATE * seconds_in), int(RATE * seconds_out)
    audio[:a] *= np.sin(np.linspace(0, np.pi / 2, a)) ** 2
    audio[-b:] *= np.cos(np.linspace(0, np.pi / 2, b)) ** 2
    return audio


def write(name, audio):
    path = os.path.join(OUT, name)
    sf.write(path, np.clip(audio, -1.0, 1.0), RATE, subtype='PCM_16')
    print('%-22s %5.2f s  peak %.2f' % (name, len(audio) / RATE, float(np.abs(audio).max())))


def breaths(audio):
    """[start, end] in samples of each stretch of breath: louder than the room, gaps under .45 s joined."""
    hop = int(RATE * .02)
    env = np.array([np.sqrt((audio[i:i + hop] ** 2).mean()) for i in range(0, len(audio) - hop, hop)])
    floor = np.percentile(env, 10)
    loud = env > max(floor * 6.0, env.max() * .035)
    spans, start = [], None
    for i, on in enumerate(loud):
        if on and start is None:
            start = i
        elif not on and start is not None:
            spans.append([start, i])
            start = None
    if start is not None:
        spans.append([start, len(loud)])
    joined = []
    for span in spans:
        if joined and (span[0] - joined[-1][1]) * .02 < .45:
            joined[-1][1] = span[1]
        else:
            joined.append(span)
    return [[max(0, s * hop - int(RATE * .06)), min(len(audio), e * hop + int(RATE * .14))] for s, e in joined
            if (e - s) * .02 > .5]


def voiced(audio):
    """How far the strongest tone between 80 and 500 Hz stands above that band's middle (air alone: under 30)."""
    size, best = 4096, 0.0
    for i in range(0, len(audio) - size, size // 2):
        window = audio[i:i + size] * np.hanning(size)
        if np.sqrt((window * window).mean()) < .01:
            continue
        power = np.abs(np.fft.rfft(window)) ** 2
        freq = np.fft.rfftfreq(size, 1.0 / RATE)
        band = power[(freq > 80) & (freq < 500)]
        best = max(best, float(band.max() / (np.median(band) + 1e-12)))
    return best


def main():
    source = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    pant = read(os.path.join(source, '554907_9250976-hq.ogg'))
    pant *= .5 / np.abs(pant).max()
    write('breath_pant.wav', ease(pant, .004, .004))
    heavy = read(os.path.join(source, '474647_1750817-hq.ogg'))
    heavy *= .62 / np.abs(heavy).max()
    count = 0
    for start, end in breaths(heavy):
        piece = heavy[start:end]
        # A breath far quieter than the rest would be lost under the night.
        if np.abs(piece).max() < .2:
            continue
        # One of them has a note of voice in it (a grunt): only air is wanted.
        if voiced(piece) > 60.0:
            continue
        count += 1
        write('breath_heavy_%d.wav' % count, ease(piece, .03, .09))
    print('heavy breaths:', count)


if __name__ == '__main__':
    main()
