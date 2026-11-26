"""0.60: checks split voice lines: transcribes each <key>.ogg (faster-whisper, local) and compares it with the
manifest text. Prints a similarity per line; under 0.6 means the piece holds the wrong words.

  python -I tools/verify_voice_split.py <dir> [<dir> ...]
"""
import json, os, re, sys
from difflib import SequenceMatcher

import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, 'game', 'assets', 'audio', 'voices', 'dialogue.json')


def words(text):
    return re.findall(r"[a-z0-9']+", re.sub(r'\[[^\]]*\]', ' ', text.lower()).replace('-', ' '))


def main():
    import librosa
    from faster_whisper import WhisperModel
    texts = {ln['key']: ln['tts'] for ln in json.load(open(MANIFEST, encoding='utf-8'))['lines']}
    texts.update(json.load(open(MANIFEST, encoding='utf-8')).get('callout_keys', {}))
    model = WhisperModel('small.en', device='cpu', compute_type='int8')
    bad = 0
    for folder in sys.argv[1:]:
        for name in sorted(os.listdir(folder)):
            if not name.endswith('.ogg'):
                continue
            key = name[:-4]
            data, rate = sf.read(os.path.join(folder, name), always_2d=True)
            audio = librosa.resample(data.mean(axis=1).astype(np.float32), orig_sr=rate, target_sr=16000)
            heard = ' '.join(s.text for s in model.transcribe(audio, beam_size=5)[0])
            want = texts.get(key, '')
            score = SequenceMatcher(None, words(want), words(heard)).ratio()
            bad += score < .6
            print('%.2f %s %s | %s' % (score, '!!' if score < .6 else '  ', key, heard.strip()[:90]))
    print('bad', bad)


if __name__ == '__main__':
    main()
