"""0.60: splits the ElevenLabs takes saved in work/Voices into the game's voice clips.

  python -I tools/install_voices.py            # split, then copy into game/assets/audio/voices
  python -I tools/install_voices.py --verify   # also transcribe every clip and compare it with its text

Which take is what comes from the voice in its file name (ElevenLabs_<time>_<Voice> - <desc>_...mp3) and, for a voice
used twice, the order the takes were made:
  Eric/Sarah/Matilda/Bill/Roger/Chris/Liam/George: that voice's dialogue lines (dialogue.json "voice")
  Will:  1st Aljay's dialogue lines, 2nd Aljay's call-outs (every take)
  Adam:  1st Alex's call-outs (first takes), 2nd Alex's dialogue lines
  Harry: Louie's call-outs (first takes); Brian: Anthony's; Callum: Clyde's
Dialogue clips go to voices/dialogue/<key>.ogg; call-outs to voices/<survivor>/<line>_<take>.ogg, and that
survivor's old Windows-voice placeholders (.wav) are deleted (voices.gd falls back to take 1 when a take is missing).
"""
import glob, os, re, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TAKES = os.path.join(ROOT, 'work', 'Voices')
SPLIT = os.path.join(ROOT, 'work', 'v60', 'voices', 'split')
VOICES = os.path.join(ROOT, 'game', 'assets', 'audio', 'voices')
PLAN = {
    'Will': ['voice=Will', 'callouts:Aljay'],
    'Adam': ['callouts1:Alex', 'voice=Adam'],
    'Harry': ['callouts1:Louie'],
    'Brian': ['callouts1:Anthony'],
    'Callum': ['callouts1:Clyde'],
}


def main():
    done = {}
    seen = set()
    for path in sorted(glob.glob(os.path.join(TAKES, 'ElevenLabs_*.mp3'))):
        m = re.match(r'ElevenLabs_(\S+?T\d\d_\d\d_\d\d)_([A-Za-z]+)', os.path.basename(path))
        voice = m.group(2)
        if (m.group(1), voice) in seen:
            print('same take saved twice, skipped:', os.path.basename(path))
            continue
        seen.add((m.group(1), voice))
        n = done.get(voice, 0)
        done[voice] = n + 1
        jobs = PLAN.get(voice, ['voice=' + voice])
        if n >= len(jobs):
            print('extra take, skipped:', os.path.basename(path))
            continue
        job = jobs[n]
        if job.startswith('voice='):
            arg, out, dest = job, os.path.join(SPLIT, job[6:].lower()), os.path.join(VOICES, 'dialogue')
        else:
            survivor = job.split(':', 1)[1]
            arg = 'voice=' + job
            out = os.path.join(SPLIT, 'callouts-' + survivor.lower())
            dest = os.path.join(VOICES, survivor.lower())
        print('==', os.path.basename(path)[:60], '->', job, flush=True)
        shutil.rmtree(out, ignore_errors=True)
        subprocess.run([sys.executable, '-I', os.path.join(ROOT, 'tools', 'split_voice_takes.py'), path, out, arg], check=True)
        os.makedirs(dest, exist_ok=True)
        if not job.startswith('voice='):
            for old in glob.glob(os.path.join(dest, '*.wav')) + glob.glob(os.path.join(dest, '*.wav.import')):
                os.remove(old)
        for clip in glob.glob(os.path.join(out, '*.ogg')):
            shutil.copy2(clip, os.path.join(dest, os.path.basename(clip)))
        if '--verify' in sys.argv and job.startswith('voice='):
            subprocess.run([sys.executable, '-I', os.path.join(ROOT, 'tools', 'verify_voice_split.py'), out])
    print('takes used:', done)


if __name__ == '__main__':
    main()
