"""Builds builds/windows/Interior.exe + Interior.pck the way 0.30 needs it:

  python -I tools/export_windows.py

1. imports the project, 2. re-bakes the merged district meshes and the boot manifest (tools/boot_manifest.py;
an exported game cannot tell a stale bake from a fresh one), 3. takes the picture under the menu on the loading
screen again (tools/menu_still.py, 0.35; a game window is on screen for a few seconds), 4. closes a running
Interior.exe (AGENTS.md: the main build is always replaced), 5. exports the Windows release, 6. prints the EXE's
own start-up report, 7. packs Sleep-<version>-windows.zip (the folder to share).

0.43: the game data is a separate Interior.pck next to a small Interior.exe (as Aetherion ships), not packed inside a
1.2 GB EXE, and the export bakes the shaders into it (export preset `shader_baker/enabled`): a PC that has never run
the game no longer compiles every shader on its first start. The shader baker needs a rendering device, so the
export runs with a (briefly visible) window, not --headless.
"""
import os, re, subprocess, sys, time, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.path.join(ROOT, '.local', 'tools', 'Godot_v4.7.2-stable_win64_console.exe')
GAME = os.path.join(ROOT, 'game')
EXE = os.path.join(ROOT, 'builds', 'windows', 'Interior.exe')
PCK = os.path.join(ROOT, 'builds', 'windows', 'Interior.pck')
PRESETS = os.path.join(GAME, 'export_presets.cfg')


def step(label, args, **more):
    print('==', label, flush=True)
    started = time.time()
    done = subprocess.run(args, capture_output=True, text=True, encoding='utf-8', errors='replace', **more)
    print('   %.0f s, exit %d' % (time.time() - started, done.returncode), flush=True)
    return done


def main():
    step('import', [GODOT, '--headless', '--path', GAME, '--editor', '--import', '--quit'])
    done = step('bake meshes and boot manifest', [sys.executable, '-I', os.path.join(ROOT, 'tools', 'boot_manifest.py')])
    print('\n'.join(l for l in done.stdout.splitlines() if not l[:1].isspace() or 'boot:' in l))
    if done.returncode != 0:
        sys.stderr.write(done.stderr[-3000:])
        raise SystemExit('bake failed')
    done = step('menu still', [sys.executable, '-I', os.path.join(ROOT, 'tools', 'menu_still.py')])
    print('  ', done.stdout.strip())
    if done.returncode != 0:
        sys.stderr.write(done.stderr[-3000:])
        raise SystemExit('menu still failed')
    step('import the still', [GODOT, '--headless', '--path', GAME, '--editor', '--import', '--quit'])
    subprocess.run(['taskkill', '/F', '/IM', 'Interior.exe'], capture_output=True)
    time.sleep(1.0)
    for old in (EXE, PCK):
        if os.path.exists(old):
            os.remove(old)
    headless = ['--headless'] if '--headless' in sys.argv else []
    done = step('export', [GODOT] + headless + ['--path', GAME, '--export-release', 'Windows Desktop', EXE])
    log = done.stdout + done.stderr
    open(os.path.join(ROOT, 'builds', 'export_windows.log'), 'w', encoding='utf-8').write(log)
    if done.returncode != 0 or not os.path.exists(EXE) or not os.path.exists(PCK):
        sys.stderr.write(log[-3000:])
        raise SystemExit('export failed')
    for line in log.splitlines():
        if 'shader' in line.lower() and ('bak' in line.lower() or 'error' in line.lower()):
            print('  ', line.strip()[:200])
    print('   %s  %.0f MB,  %s  %.0f MB' % (EXE, os.path.getsize(EXE) / 1e6, PCK, os.path.getsize(PCK) / 1e6))
    done = step('EXE start-up report', [EXE, '--', '--load-report', '--load-quit'], timeout=180,
                env=dict(os.environ, INTERIOR_MUTE='1'))
    for line in (done.stdout + done.stderr).splitlines():
        if 'INTERIOR_LOAD' in line and ('boot:' in line or 'menu frame 0' in line) or 'ERROR' in line or 'SCRIPT' in line:
            print('  ', line.strip())
    pack()


def pack():
    """The folder to share, in one file: Interior.exe and Interior.pck must travel together."""
    version = re.search(r'application/product_version="([^"]+)"', open(PRESETS, encoding='utf-8').read()).group(1)
    folder = os.path.dirname(EXE)
    out = os.path.join(folder, 'Sleep-%s-windows.zip' % version)
    for name in os.listdir(folder):
        if name.startswith('Sleep-') and name.endswith('-windows.zip'):
            os.remove(os.path.join(folder, name))
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_STORED, allowZip64=True) as z:
        for name in sorted(os.listdir(folder)):
            path = os.path.join(folder, name)
            if os.path.isfile(path) and not name.endswith('.zip'):
                z.write(path, 'Sleep/' + name)
    print('== zip  %s  %.0f MB' % (out, os.path.getsize(out) / 1e6))


if __name__ == '__main__':
    main()
