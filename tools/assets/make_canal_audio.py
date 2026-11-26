"""Surface footsteps derived from the project's Kenney CC0 samples."""
from pathlib import Path
import numpy as np
import soundfile as sf
from scipy.signal import resample_poly, butter, sosfilt
ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / '.local/downloads/kenney/impact/Audio'
OUT = ROOT / 'game/assets/audio/footsteps'
RATE = 44100
def read(name):
    data, rate = sf.read(SRC / name)
    if data.ndim > 1:
        data = data.mean(axis=1)
    if rate != RATE:
        from math import gcd
        g = gcd(rate, RATE)
        data = resample_poly(data, RATE//g, rate//g)
    return data
for i in range(5):
    thud = read(f'footstep_concrete_{i:03}.ogg')
    ring = read(f'impactMetal_light_{i:03}.ogg')
    length = int(RATE*.46)
    metal = np.zeros(length)
    metal[:min(length,len(thud))] += thud[:length]*.63
    count = min(length,len(ring))
    metal[:count] += ring[:count]*np.exp(-np.arange(count)/RATE*6)*.40
    metal = sosfilt(butter(2, [65,6500], btype='bandpass',fs=RATE,output='sos'),metal)
    metal *= .72/max(np.max(np.abs(metal)),.001)
    sf.write(OUT/f'footstep_metal_{i:03}.ogg',metal,RATE,format='OGG',subtype='VORBIS')
    dirt = read(f'footstep_grass_{i:03}.ogg')
    dirt = sosfilt(butter(2,2700,fs=RATE,output='sos'),dirt)
    dirt *= .65/max(np.max(np.abs(dirt)),.001)
    sf.write(OUT/f'footstep_dirt_{i:03}.ogg',dirt,RATE,format='OGG',subtype='VORBIS')
print('Created five metal and five dirt footstep variants from CC0 sources.')
