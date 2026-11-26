"""0.40: makes the squad's voice lines (game/assets/audio/voices/<survivor>/<line>_<n>.mp3 or .wav) from
game/assets/audio/voices/lines.json.

  python -I tools/squad_voices.py                     # ElevenLabs when ELEVENLABS_API_KEY is set, else Windows voices
  python -I tools/squad_voices.py --engine sapi       # the offline placeholder voices only
  python -I tools/squad_voices.py --engine elevenlabs --force

ElevenLabs: each survivor gets the first voice in its "elevenlabs" list that the account has (premade voices by
name), model eleven_multilingual_v2, MP3 44.1 kHz. A line already made by ElevenLabs is kept unless --force; the
placeholder .wav of a line is deleted once its .mp3 exists (scripts/coop/voices.gd prefers .mp3 anyway).
Run `python -I tools/export_windows.py` afterwards: it imports the new files and rebuilds the EXE.
"""
import argparse, json, os, subprocess, sys, tempfile, time, urllib.error, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VOICES = os.path.join(ROOT, 'game', 'assets', 'audio', 'voices')
API = 'https://api.elevenlabs.io/v1'
MODEL = 'eleven_multilingual_v2'


def manifest():
    with open(os.path.join(VOICES, 'lines.json'), encoding='utf-8') as f:
        return json.load(f)


def eleven(path, key, method='GET', body=None):
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(API + path, data=data, method=method,
                                     headers={'xi-api-key': key, 'Content-Type': 'application/json', 'User-Agent': 'squad-voices'})
    with urllib.request.urlopen(request, timeout=90) as response:
        return response.read()


def make_elevenlabs(spec, force):
    key = os.environ.get('ELEVENLABS_API_KEY', '').strip()
    if not key:
        raise SystemExit('ELEVENLABS_API_KEY is not set')
    voices = json.loads(eleven('/voices', key))['voices']
    by_name = {}
    for v in voices:
        by_name.setdefault(v['name'].split(' ')[0].lower(), v['voice_id'])
    used = set()
    made = 0
    for survivor, info in spec['survivors'].items():
        voice = next((by_name[n.lower()] for n in info['elevenlabs'] if n.lower() in by_name and by_name[n.lower()] not in used), None)
        if voice is None:
            voice = next((v['voice_id'] for v in voices if v['voice_id'] not in used), voices[0]['voice_id'])
        used.add(voice)
        folder = os.path.join(VOICES, survivor.lower())
        os.makedirs(folder, exist_ok=True)
        print(survivor, '->', voice, flush=True)
        for line, takes in spec['lines'].items():
            for n, text in enumerate(takes, 1):
                out = os.path.join(folder, '%s_%d.mp3' % (line, n))
                if os.path.exists(out) and not force:
                    continue
                body = {'text': text, 'model_id': MODEL,
                        'voice_settings': {'stability': .32, 'similarity_boost': .8, 'style': .55, 'use_speaker_boost': True}}
                for attempt in range(4):
                    try:
                        audio = eleven('/text-to-speech/%s?output_format=mp3_44100_128' % voice, key, 'POST', body)
                        break
                    except urllib.error.HTTPError as e:
                        if e.code == 429 and attempt < 3:
                            time.sleep(3 + attempt * 4)
                            continue
                        raise SystemExit('ElevenLabs refused %s/%s: %s %s' % (survivor, line, e.code, e.read()[:300]))
                with open(out, 'wb') as f:
                    f.write(audio)
                placeholder = out[:-4] + '.wav'
                for stale in (placeholder, placeholder + '.import'):
                    if os.path.exists(stale):
                        os.remove(stale)
                made += 1
    print('ElevenLabs lines made:', made)


SAPI = r'''
param($Out, $Text, $Pitch, $Rate)
Add-Type -AssemblyName System.Speech
$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
$s.SelectVoice('Microsoft David Desktop')
$s.Rate = [int]$Rate
$fmt = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(22050, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
$s.SetOutputToWaveFile($Out, $fmt)
$s.Speak($Text)
$s.Dispose()
'''


def shape(path, pitch):
    """Pitch it (resampled: a little faster when higher), trim the silence, level it, give it a little grit."""
    import numpy as np, soundfile as sf
    from scipy.signal import resample
    audio, rate = sf.read(path)
    factor = 1.0 + float(pitch.strip('%')) / 100.0
    audio = resample(audio, max(1, int(len(audio) / factor)))
    loud = np.where(np.abs(audio) > .02)[0]
    if loud.size:
        audio = audio[max(0, loud[0] - int(rate * .02)):loud[-1] + int(rate * .08)]
    audio = np.tanh(audio / max(np.abs(audio).max(), 1e-6) * 1.6) * .82
    sf.write(path, audio.astype('float32'), rate, subtype='PCM_16')


def make_sapi(spec):
    script = os.path.join(tempfile.gettempdir(), 'squad_sapi.ps1')
    with open(script, 'w', encoding='utf-8') as f:
        f.write(SAPI)
    made = 0
    for survivor, info in spec['survivors'].items():
        folder = os.path.join(VOICES, survivor.lower())
        os.makedirs(folder, exist_ok=True)
        for line, takes in spec['lines'].items():
            for n, text in enumerate(takes, 1):
                base = os.path.join(folder, '%s_%d' % (line, n))
                if os.path.exists(base + '.mp3'):
                    continue
                subprocess.run(['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script, base + '.wav', text,
                                info['sapi_pitch'], str(info['sapi_rate'])], check=True, capture_output=True)
                if os.path.getsize(base + '.wav') < 1000:
                    raise SystemExit('Windows speech made nothing for ' + base)
                shape(base + '.wav', info['sapi_pitch'])
                made += 1
    print('placeholder lines made:', made)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--engine', choices=['auto', 'elevenlabs', 'sapi'], default='auto')
    parser.add_argument('--force', action='store_true')
    args = parser.parse_args()
    spec = manifest()
    engine = args.engine
    if engine == 'auto':
        engine = 'elevenlabs' if os.environ.get('ELEVENLABS_API_KEY') else 'sapi'
    if engine == 'elevenlabs':
        make_elevenlabs(spec, args.force)
    else:
        make_sapi(spec)


if __name__ == '__main__':
    main()
