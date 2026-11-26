"""0.30: writes game/assets/boot_manifest.json for the boot scene (game/scripts/boot.gd).

  python -I tools/boot_manifest.py            # both passes
  python -I tools/boot_manifest.py --stages   # only re-measure the loading bar's shares

Pass 0 bakes the merged district meshes (assets/built/world_meshes.res). Pass 1 starts the game without the boot scene (tests/load_profile.gd) with Godot's --verbose and records every
file the world builders load after main.tscn itself: those are what the boot scene reads on background threads
while the loading screen is up. Pass 2 starts the game through the boot scene with `-- --load-report --load-quit`
and records how far through the build each step was, so the loading bar moves at an even pace.
Run it again whenever a builder starts loading new models or textures, or a new start-up step is added.
"""
import json, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.path.join(ROOT, '.local', 'tools', 'Godot_v4.7.2-stable_win64_console.exe')
GAME = os.path.join(ROOT, 'game')
OUT = os.path.join(GAME, 'assets', 'boot_manifest.json')
# Loaded the first time they are used in play (a zombie, a weapon from the debug menu): read up front as well,
# so the first shot or the first spawn never stops the game to read a file.
EXTRA_DIRS = ['assets/built', 'assets/zombies', 'assets/characters', 'assets/audio/sfx', 'assets/audio/zombies', 'assets/models/story']
EXTRA_TYPES = ('.glb', '.ogg', '.wav', '.png', '.jpg', '.tres', '.res')


def run(args):
    done = subprocess.run([GODOT] + args, capture_output=True, text=True, encoding='utf-8', errors='replace')
    return done.stdout + done.stderr


LEAF_TYPES = ('.jpg', '.jpeg', '.png', '.webp', '.svg', '.exr', '.hdr', '.ogg', '.wav', '.mp3', '.glb', '.gltf',
              '.res', '.tres', '.gdshader', '.ttf', '.otf')


def scripted(path):
    """A resource file that pulls a script in must wait for the scene (see boot.gd)."""
    full = os.path.join(GAME, path[len('res://'):])
    # The baked district meshes are one compressed file of plain meshes (random bytes can spell ".gd").
    if '/assets/built/' in path or not path.endswith(('.tres', '.res')) or not os.path.exists(full):
        return False
    data = open(full, 'rb').read()
    return b'.gd"' in data or b'.gd\x00' in data or b'.tscn' in data or b'type="Script"' in data


def resources():
    text = run(['--verbose', '--path', GAME, '--script', 'res://tests/load_profile.gd', '--', '--load-report'])
    seen, out = set(), []
    for line in text.splitlines():
        found = re.match(r'Loading resource: (res://\S+)', line)
        if not found:
            continue
        path = found.group(1)
        if path.startswith('res://.godot/') or path in seen or not path.lower().endswith(LEAF_TYPES) or scripted(path):
            continue
        seen.add(path)
        out.append(path)
    for folder in EXTRA_DIRS:
        base = os.path.join(GAME, folder)
        for here, _dirs, files in os.walk(base):
            for name in sorted(files):
                if name.lower().endswith(EXTRA_TYPES):
                    path = 'res://' + os.path.relpath(os.path.join(here, name), GAME).replace(os.sep, '/')
                    if path not in seen and not scripted(path):
                        seen.add(path)
                        out.append(path)
    return out


def bake():
    """Writes game/assets/built/world_meshes.res (game/scripts/build_cache.gd): the districts' merged meshes."""
    text = run(['--path', GAME, '--', '--bake-world-meshes', '--load-quit'])
    found = re.search(r'INTERIOR_BUILD_CACHE (.*)', text)
    if not found:
        sys.stderr.write(text[-3000:])
        raise SystemExit('The mesh bake did not finish; see the output above.')
    print('world meshes:', found.group(1).strip())


def stages():
    text = run(['--path', GAME, '--', '--load-report', '--load-quit'])
    marks = []
    for line in text.splitlines():
        found = re.match(r'INTERIOR_LOAD\s+(\d+) ms\s+\+\s*\d+\s+(.*)$', line.strip())
        if found:
            marks.append((found.group(2).strip(), int(found.group(1))))
    labels = [m[0] for m in marks]
    if 'boot: instantiated' not in labels or 'boot: done' not in labels:
        sys.stderr.write(text[-3000:])
        raise SystemExit('The boot scene did not finish; see the output above.')
    start = dict(marks)['boot: instantiated']
    end = [t for l, t in marks if l == 'boot: done'][0]
    shares = {}
    for label, at in marks:
        if at < start or at > end or label in shares:
            continue
        shares[label] = round((at - start) / max(1, end - start), 4)
    return shares, marks


def main():
    manifest = {}
    if os.path.exists(OUT):
        manifest = json.load(open(OUT, encoding='utf-8'))
    if '--stages' not in sys.argv:
        bake()
        manifest['resources'] = resources()
        manifest.setdefault('stages', {})
        json.dump(manifest, open(OUT, 'w', encoding='utf-8', newline='\n'), indent=1)
        print('resources:', len(manifest['resources']))
    shares, marks = stages()
    manifest['stages'] = shares
    json.dump(manifest, open(OUT, 'w', encoding='utf-8', newline='\n'), indent=1)
    print('stages:', len(shares))
    previous = 0
    for label, at in marks:
        print('%6d  +%5d  %s' % (at, at - previous, label))
        previous = at


if __name__ == '__main__':
    main()
