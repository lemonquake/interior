"""Download and cut the distant dog barks for 0.8 (Wikimedia Commons, CC BY-SA).

    python tools/assets/fetch_dogs.py

Each phrase is trimmed, made mono, band-limited (a far dog loses its lows and its bite) and normalised into
game/assets/audio/night/dog_*.ogg. Played by game/scripts/night_audio.gd far away from the player.
Credits: game/licenses/NIGHT_SOUNDS.md (0.8 rows).
"""
import os, re, sys, time, urllib.parse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fetch_fields import AUDIO_OUT, DL, commons, get

# out name -> (file title, start s, length s)
DOGS = {
    'dog_bark_a': ('Barking dog in Rome.ogg', 1.6, 5.2),
    'dog_bark_b': ('Barking dog in Rome.ogg', 10.2, 7.4),
    'dog_bark_c': ('Barking of a dog 2.ogg', 0.0, 4.0),
    'dog_bark_d': ('Rottweiler Barking.oga', 0.4, 5.4),
    'dog_bark_e': ('Rottweiler Barking.oga', 26.0, 7.0),
    'dog_pack': ('Seis perros ladrando.wav', 46.5, 8.0),
}

def cut(src, dst, start, length):
    import numpy as np, soundfile as sf
    from scipy.signal import butter, sosfiltfilt, resample_poly
    data, rate = sf.read(src, always_2d=True)
    mono = data.mean(axis=1)[int(start * rate):int((start + length) * rate)]
    if rate != 44100:
        from math import gcd
        g = gcd(int(rate), 44100)
        mono = resample_poly(mono, 44100 // g, int(rate) // g)
        rate = 44100
    mono = sosfiltfilt(butter(3, [220, 3200], 'bandpass', fs=rate, output='sos'), mono)
    mono = mono / (np.max(np.abs(mono)) or 1.0) * 0.89
    fade = int(rate * 0.08)
    mono[:fade] *= np.linspace(0, 1, fade)
    mono[-fade:] *= np.linspace(1, 0, fade)
    with sf.SoundFile(dst, 'w', rate, 1, format='OGG', subtype='VORBIS') as out:
        block = mono.astype('float32')
        for i in range(0, len(block), 2048):
            out.write(block[i:i + 2048])

def main():
    titles = sorted({spec[0] for spec in DOGS.values()})
    res = commons({'action': 'query', 'titles': '|'.join('File:' + t for t in titles), 'prop': 'imageinfo',
                   'iiprop': 'url|extmetadata', 'iiextmetadatafilter': 'LicenseShortName|Artist'})
    pages = {p['title']: p for p in res['query']['pages'].values()}
    for out, (title, start, length) in DOGS.items():
        ii = pages['File:' + title]['imageinfo'][0]
        src = get(ii['url'], os.path.join(DL, 'commons', re.sub(r'[^\w.\-]+', '_', title)))
        cut(src, os.path.join(AUDIO_OUT, out + '.ogg'), start, length)
        meta = ii.get('extmetadata', {})
        print(out, '|', title, '|', re.sub('<[^>]+>', '', meta.get('Artist', {}).get('value', '')).strip(), '|',
              meta.get('LicenseShortName', {}).get('value'), '|', 'https://commons.wikimedia.org/wiki/File:' + urllib.parse.quote(title.replace(' ', '_')))
        time.sleep(1)

if __name__ == '__main__':
    sys.exit(main())
