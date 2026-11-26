"""0.60: gathers every spoken line of the game from the scripts into game/assets/audio/voices/dialogue.json.

  python -I tools/dialogue_lines.py            # rewrite the manifest (keeps 'tts' directions already written)
  python -I tools/dialogue_lines.py --count    # characters per speaker (ElevenLabs credits)

Each line: {"key", "speaker", "text"} where key = sha1("<speaker>\\n<text>")[:12] (scripts/voice_lines.gd computes the
same), plus "tts" (what ElevenLabs is given: the text with audio tags and punctuation for delivery) and "voice".
"{P}"/"{Q}" lines and "%s" lines are said by a squad survivor: they get one entry per survivor.
The files are game/assets/audio/voices/dialogue/<key>.mp3.
"""
import hashlib, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = os.path.join(ROOT, 'game')
OUT = os.path.join(GAME, 'assets', 'audio', 'voices', 'dialogue.json')
SQUAD = ['Alex', 'Aljay', 'Louie', 'Anthony', 'Clyde']
## Who reads each speaker (ElevenLabs voice names on the owner's account). No accents, no accent directions: the
## owner forbids any added flavour in the voices. (Lemon Voice, the owner's clone, needs a paid plan: Will and George.)
VOICES = {'Aljay': 'Will', '': 'George', 'Room 501': 'George', 'Alex': 'Adam', 'Louie': 'Harry',
          'Anthony': 'Brian', 'Clyde': 'Callum', 'Jonna': 'Sarah', "Ma'am Teves": 'Matilda', 'Rommel': 'Bill',
          'Dodong Sikma': 'Roger', 'Hooded man': 'Eric', 'Paolo': 'Liam', 'You': 'Chris'}


def read(rel):
    with open(os.path.join(GAME, rel), encoding='utf-8') as f:
        return f.read()


def gd_strings(block):
    return [s.replace('\\n', '\n').replace('\\"', '"').replace('’', "'")
            for s in re.findall(r'"((?:[^"\\]|\\.)*)"', block)]


def const_block(src, name):
    m = re.search(r'const ' + name + r' := \[(.*?)\n\]', src, re.S)
    if not m:
        m = re.search(r'const ' + name + r' := \[(.*?)\]\n', src, re.S)
    return m.group(1)


def key(speaker, text):
    return hashlib.sha1((speaker + '\n' + text).encode('utf-8')).hexdigest()[:12]


def clean(text):
    return re.sub(r'^\(whispering\)\s*', '', text)


def gather():
    lines = []

    def add(speaker, text, source):
        text = text.strip()
        if not text:
            return
        speakers = SQUAD if speaker in ('{P}', '{Q}', '%s') else [speaker]
        for sp in speakers:
            lines.append({'speaker': sp, 'text': text, 'source': source})

    for rel, names in [('scripts/coop/mission.gd', ['TALK', 'GUARD_TALK']), ('scripts/coop/escape.gd', ['TALK', 'AFTER']),
                       ('scripts/coop/heavyarm.gd', ['TALK'])]:
        src = read(rel)
        for name in names:
            for row in re.findall(r'\[("(?:[^"\\]|\\.)*"),\s*("(?:[^"\\]|\\.)*")', const_block(src, name)):
                sp, text = gd_strings(row[0] + row[1])
                add(sp, text, rel + ':' + name)
    # say("Speaker\nText") calls in co-op.
    for rel in ['scripts/coop/mission.gd', 'scripts/coop/escape.gd', 'scripts/coop/heavyarm.gd']:
        for raw in re.findall(r'say\(("(?:[^"\\]|\\.)*")', read(rel)):
            s = gd_strings(raw)[0]
            # No speaker line: a narration caption ('' = the narrator).
            sp, text = s.split('\n', 1) if '\n' in s else ('', s)
            add(sp, text, rel + ':say')
    # The ternary caption when the run is lost.
    add('', "Dodong didn't make it home.", 'scripts/coop/mission.gd:say')
    add('', 'The whole team is down.', 'scripts/coop/mission.gd:say')
    # Single player: the hooded man, and the player's own remarks ("You").
    story = read('scripts/story.gd')
    for s in gd_strings(const_block(story, 'CALL_LINES')):
        add('Hooded man', s, 'scripts/story.gd')
    add('Hooded man', gd_strings(re.search(r'const RUN_LINE := (".*?")', story).group(1))[0], 'scripts/story.gd')
    for rel, pattern in [('scripts/canal_warren.gd', r'const LINES := \[(.*?)\]'),
                         ('scripts/neighborhood_encounters.gd', r'const LINES := \[(.*?)\]'),
                         ('scripts/nichols_basement.gd', r'const SIGHT_LINES := \[(.*?)\]'),
                         ('scripts/nichols_basement.gd', r'const LOCK_LINES := \[(.*?)\]'),
                         ('scripts/nichols_property.gd', r'const ENTRY_LINE := (".*?")')]:
        for s in gd_strings(re.search(pattern, read(rel), re.S).group(1)):
            add('You', s, rel)
    for rel in ['scripts/interior.gd', 'scripts/canal_warren.gd', 'scripts/nichols_locked.gd']:
        for raw in re.findall(r'ui\.say\("You", \[("(?:[^"\\]|\\.)*")\]', read(rel)):
            add('You', gd_strings(raw)[0], rel)
    # Lock remarks set elsewhere (nichols_locked lines come from the properties that place them).
    for raw in re.findall(r'\.lines = \[(.*?)\]', read('scripts/nichols_property.gd'), re.S):
        for s in gd_strings(raw):
            add('You', s, 'scripts/nichols_property.gd:lines')
    seen, out = set(), []
    for ln in lines:
        k = key(ln['speaker'], clean(ln['text']))
        if k in seen:
            continue
        seen.add(k)
        ln['key'] = k
        ln['whisper'] = ln['text'].startswith('(whispering)')
        ln['text'] = clean(ln['text'])
        out.append(ln)
    return out


def main():
    old = {}
    if os.path.exists(OUT):
        with open(OUT, encoding='utf-8') as f:
            for ln in json.load(f)['lines']:
                old[ln['key']] = ln
    lines = gather()
    for ln in lines:
        prev = old.get(ln['key'], {})
        ln['tts'] = prev.get('tts', ln['text'])
        ln['voice'] = VOICES.get(ln['speaker'], 'George')
    if '--count' in sys.argv:
        by = {}
        for ln in lines:
            by.setdefault(ln['speaker'], [0, 0])
            by[ln['speaker']][0] += 1
            by[ln['speaker']][1] += len(ln['tts'])
        for sp, (n, c) in sorted(by.items(), key=lambda x: -x[1][1]):
            print('%-14s %3d lines %5d chars' % (sp, n, c))
        print('total', sum(c for n, c in by.values()))
        return
    out = {'about': __doc__.strip().splitlines()[0], 'lines': lines}
    if os.path.exists(OUT):
        with open(OUT, encoding='utf-8') as f:
            kept = json.load(f).get('callouts')
        if kept:
            out['callouts'] = kept  # the squad call-out directions (tools/dialogue_directions.py)
    with open(OUT, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    print(len(lines), 'lines ->', OUT)


if __name__ == '__main__':
    main()
