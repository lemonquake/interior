"""0.60: cuts one ElevenLabs take (one voice reading several lines, one paragraph each) into one file per line.

  python -I tools/split_voice_takes.py <take.mp3> <out_dir> <name1> <name2> ...   # names in reading order
  python -I tools/split_voice_takes.py <take.mp3> --show N                         # the N-1 longest pauses

The cut points are the N-1 longest pauses in the take (paragraph breaks are longer than the pauses inside a line).
Each piece is trimmed to 60 ms before/after its speech, faded 15 ms at both ends and written as OGG Vorbis (Godot
streams it; smaller than MP3 at the same quality).
"""
import os, sys
import numpy as np
import soundfile as sf

FRAME = .01


def load(path):
    data, rate = sf.read(path, always_2d=True)
    return data.mean(axis=1), rate


def energy(mono, rate):
    w = int(rate * FRAME)
    n = len(mono) // w
    return np.sqrt((mono[:n * w].reshape(n, w) ** 2).mean(axis=1))


def pauses(e, floor):
    quiet = e < floor
    runs, start = [], None
    for i, q in enumerate(quiet):
        if q and start is None:
            start = i
        elif not q and start is not None:
            runs.append((start, i))
            start = None
    return runs


def cut_points(mono, rate, count, weights=None):
    """The count-1 pauses to cut at. With `weights` (each line's spoken length, e.g. its letters), a dynamic
    programme picks the pauses that are long AND leave each piece about as long as its text says: pauses inside
    a line ("Diyos ko... you're real") can be as long as the breaks between lines."""
    e = energy(mono, rate)
    floor = max(e.max() * .02, 1e-4)
    runs = [r for r in pauses(e, floor) if r[0] > 0 and r[1] < len(e) and r[1] - r[0] >= 12]
    if len(runs) < count - 1:
        raise SystemExit('only %d pauses found for %d lines' % (len(runs), count))
    if not weights:
        return sorted(sorted(runs, key=lambda r: r[1] - r[0], reverse=True)[:count - 1]), e, floor
    total = float(sum(weights))
    target = np.cumsum(weights)[:-1] / total  # where each break should fall, as a share of the take
    speech = float(len(e))
    mids = [((a + b) / 2) / speech for a, b in runs]
    lens = [(b - a) * FRAME for a, b in runs]
    best_pause = max(lens)
    INF = 1e18
    k, m = count - 1, len(runs)
    cost = np.full((k + 1, m + 1), INF)
    back = np.zeros((k + 1, m + 1), dtype=int)
    cost[0, 0] = 0
    # cost[j][i]: j breaks placed, the last one at run i-1.
    for j in range(1, k + 1):
        for i in range(j, m + 1):
            here = (abs(mids[i - 1] - target[j - 1]) * 6.0) ** 2 - lens[i - 1] / best_pause
            prev = cost[j - 1, :i]
            p = int(np.argmin(prev))
            if prev[p] < INF:
                cost[j, i] = prev[p] + here
                back[j, i] = p
    i = int(np.argmin(cost[k]))
    chosen = []
    for j in range(k, 0, -1):
        chosen.append(runs[i - 1])
        i = back[j, i]
    return sorted(chosen), e, floor


def _words(text):
    import re
    return re.findall(r"[a-z0-9']+", re.sub(r'\[[^\]]*\]', ' ', text.lower()).replace('-', ' '))


def asr_bounds(path, lines, e, floor):
    """Frame indices where each line starts, from word timestamps (faster-whisper, local): each line's first words
    are found in order in the recognised words; the cut goes in the quiet just before them."""
    from difflib import SequenceMatcher
    from faster_whisper import WhisperModel
    model = WhisperModel('small.en', device='cpu', compute_type='int8')
    import librosa
    mono, rate = load(path)
    audio = librosa.resample(mono.astype(np.float32), orig_sr=rate, target_sr=16000)
    segments, _ = model.transcribe(audio, word_timestamps=True, beam_size=5, vad_filter=False)
    heard = []
    for seg in segments:
        for w in seg.words:
            for t in _words(w.word):
                heard.append((t, w.start, w.end))
    tokens = [h[0] for h in heard]
    expected, owner = [], []
    for i, ln in enumerate(lines):
        for t in _words(ln['tts']):
            expected.append(t)
            owner.append(i)
    # Map every expected word to a heard word (difflib alignment), then each line starts at its first mapped word.
    sm = SequenceMatcher(None, expected, tokens, autojunk=False)
    first, last = {}, {}   # per line: (time, word index in line) of its first and last matched words
    first_word = {}
    for idx, i in enumerate(owner):
        first_word.setdefault(i, idx)
    for a, b, size in sm.get_matching_blocks():
        for k in range(size):
            i = owner[a + k]
            if i not in first: first[i] = (heard[b + k][1], a + k - first_word[i])
            last[i] = heard[b + k][2]
    # Short lines the recogniser missed ("Clear."): the line sits in the gap between its neighbours; give it the
    # longest pause in the first part of that gap as its start, and the gap's end as its own end.
    total = len(e) * FRAME
    for i in range(len(lines)):
        if i in first:
            continue
        lo_t = last.get(i - 1, 0.0) if i > 0 else 0.0
        nxt = next((j for j in range(i + 1, len(lines)) if j in first), None)
        hi_t = first[nxt][0] if nxt is not None else total
        lo, hi = int(lo_t / FRAME), max(int(hi_t / FRAME), int(lo_t / FRAME) + 2)
        runs = [r for r in pauses(e[lo:hi], floor) if r[1] - r[0] >= 8]
        start = lo_t + .05
        if runs:
            a, b = max(runs, key=lambda r: r[1] - r[0])
            start = (lo + b) * FRAME
        print('note: line %d (%s) not recognised; placed at %.2f s' % (i, lines[i]['key'], start))
        first[i] = (start, 0)
        last[i] = hi_t - .05
        if i > 0 and (i - 1) in last and last[i - 1] > start:
            last[i - 1] = start - .02
    bounds = [0]
    for i in range(1, len(lines)):
        if i not in first or (i - 1) not in last:
            raise SystemExit('line %d (%s) not heard' % (i, lines[i]['key']))
        lo = int(last[i - 1] / FRAME)
        if first[i][1] == 0:
            hi = int(first[i][0] / FRAME)
        else:
            # Its opening words were not recognised: they are in the gap, so cut right after the previous line.
            print('note: line %d recognised from its word %d' % (i, first[i][1]))
            hi = min(lo + 25, int(first[i][0] / FRAME))
        lo, hi = max(lo, bounds[-1] + 1), max(hi, bounds[-1] + 2)
        if hi <= lo:
            bounds.append(hi)
            continue
        # The quietest stretch between the two (whisper's word edges are approximate).
        window = np.convolve(e[lo:hi], np.ones(5) / 5, mode='same')
        bounds.append(lo + int(np.argmin(window)))
    bounds.append(len(e))
    return bounds


def main():
    path = sys.argv[1]
    mono, rate = load(path)
    if sys.argv[2] == '--show':
        n = int(sys.argv[3])
        cuts, e, floor = cut_points(mono, rate, n)
        runs = sorted(pauses(e, floor), key=lambda r: r[1] - r[0], reverse=True)
        for a, b in runs[:n + 3]:
            print('%.2f s  pause %.2f s %s' % (a * FRAME, (b - a) * FRAME, '<- cut' if (a, b) in cuts else ''))
        return
    out, names = sys.argv[2], sys.argv[3:]
    weights = None
    if len(names) == 1 and names[0].startswith('voice='):
        # Names and weights from the dialogue manifest: every line of that voice, in manifest order.
        import json, re
        voice = names[0][6:]
        manifest = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'game', 'assets', 'audio', 'voices', 'dialogue.json')
        data = json.load(open(manifest, encoding='utf-8'))
        if voice.startswith('callouts1:'):
            # Only each call-out's first take (named <line>_1).
            spec = json.load(open(manifest.replace('dialogue.json', 'lines.json'), encoding='utf-8'))
            lines = [{'key': '%s_1' % k, 'tts': data['callouts'][takes[0]]} for k, takes in spec['lines'].items()]
        elif voice.startswith('callouts:'):
            # A survivor's squad call-outs (lines.json order), named <line>_<take>.
            spec = json.load(open(manifest.replace('dialogue.json', 'lines.json'), encoding='utf-8'))
            lines = [{'key': '%s_%d' % (k, n), 'tts': data['callouts'][t]} for k, takes in spec['lines'].items()
                     for n, t in enumerate(takes, 1)]
        else:
            lines = [ln for ln in data['lines'] if ln['voice'] == voice]
        names = [ln['key'] for ln in lines]
        weights = [len(re.sub(r'\[[^\]]*\]', '', ln['tts']).strip()) + 8 for ln in lines]
    e = energy(mono, rate)
    floor = max(e.max() * .02, 1e-4)
    if weights and '--silence' not in sys.argv:
        bounds = asr_bounds(path, lines, e, floor)
    else:
        cuts, e, floor = cut_points(mono, rate, len(names), weights)
        bounds = [0] + [(a + b) // 2 for a, b in cuts] + [len(e)]
    os.makedirs(out, exist_ok=True)
    pad, fade = int(.06 / FRAME), int(rate * .015)
    for name, lo, hi in zip(names, bounds, bounds[1:]):
        loud = np.nonzero(e[lo:hi] >= floor)[0]
        a = max(lo, lo + int(loud[0]) - pad) if len(loud) else lo
        b = min(hi, lo + int(loud[-1]) + pad) if len(loud) else hi
        piece = mono[int(a * FRAME * rate):int(b * FRAME * rate)].copy()
        ramp = np.linspace(0, 1, fade)
        piece[:fade] *= ramp
        piece[-fade:] *= ramp[::-1]
        # In blocks: libsndfile's Vorbis encoder overflows the stack on one long write.
        with sf.SoundFile(os.path.join(out, name + '.ogg'), 'w', rate, 1, format='OGG', subtype='VORBIS') as f:
            for k in range(0, len(piece), 4096):
                f.write(piece[k:k + 4096].astype(np.float32))
        print('%s %.2f s' % (name, len(piece) / rate))


if __name__ == '__main__':
    main()
