"""Seamless cloud noise for the 0.8 night sky (game/assets/fields/sky/cloud_noise.png).

    python tools/assets/make_cloud_noise.py

Spectrally shaped noise (1/f^beta), so it tiles by construction. R: big billowy shapes, G: fine
detail for eroded edges, B: mid-size noise used to warp the other two. Each channel is equalised
to a flat histogram, so the sky shader's threshold maps straight onto the cloud cover.
"""
import os
import numpy as np
from PIL import Image

N = 1024
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'game', 'assets', 'fields', 'sky', 'cloud_noise.png')

def channel(seed, beta, low_cut, high_cut):
    rng = np.random.default_rng(seed)
    f = np.fft.fftfreq(N)[:, None] ** 2 + np.fft.fftfreq(N)[None, :] ** 2
    f = np.sqrt(f) * N
    amp = np.where(f > 0, 1.0 / np.maximum(f, 1e-6) ** (beta / 2.0), 0.0)
    amp *= 1.0 - np.exp(-(f / low_cut) ** 2)
    amp *= np.exp(-(f / high_cut) ** 2)
    field = np.real(np.fft.ifft2(np.fft.fft2(rng.standard_normal((N, N))) * amp))
    # Billows: fold the field a little so cloud tops read rounded rather than plasma-like.
    field = field / field.std()
    field = field - 0.25 * np.abs(field)
    ranks = field.ravel().argsort().argsort().reshape(N, N)
    return (ranks / (N * N - 1) * 255.0).astype(np.uint8)

if __name__ == '__main__':
    rgb = np.dstack([channel(3, 3.4, 1.5, 120.0), channel(7, 2.4, 10.0, 380.0), channel(11, 3.0, 3.0, 60.0)])
    Image.fromarray(rgb, 'RGB').save(OUT, optimize=True)
    print(OUT, os.path.getsize(OUT) // 1024, 'KB')
