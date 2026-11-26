"""Builds the Windows installer from the current main build:

  python -I tools/build_installer.py

Packs builds/windows/Interior.exe and its licence/readme files into builds/installer/Sleep-<version>-Setup.exe
with Inno Setup 6 (tools/installer/Sleep.iss). The version is the Windows export preset's product version.
Run tools/export_windows.py first; this script does not export.
"""
import hashlib, os, re, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, 'builds', 'windows')
OUTPUT = os.path.join(ROOT, 'builds', 'installer')
SCRIPT = os.path.join(ROOT, 'tools', 'installer', 'Sleep.iss')
PRESETS = os.path.join(ROOT, 'game', 'export_presets.cfg')
ISCC_PLACES = [
    os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Programs', 'Inno Setup 6', 'ISCC.exe'),
    r'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
    r'C:\Program Files\Inno Setup 6\ISCC.exe',
]


def version():
    text = open(PRESETS, encoding='utf-8').read()
    windows = text.split('[preset.0.options]', 1)[1].split('[preset.1]', 1)[0]
    found = re.search(r'application/product_version="([^"]+)"', windows)
    if not found:
        raise SystemExit('no product_version in the Windows export preset')
    return found.group(1)


def main():
    iscc = next((p for p in ISCC_PLACES if os.path.exists(p)), None)
    if iscc is None:
        raise SystemExit('Inno Setup 6 is not installed (winget install JRSoftware.InnoSetup)')
    exe = os.path.join(SOURCE, 'Interior.exe')
    if not os.path.exists(exe):
        raise SystemExit('no %s; run tools/export_windows.py first' % exe)
    os.makedirs(OUTPUT, exist_ok=True)
    v = version()
    print('== installer for Sleep %s (%.0f MB game)' % (v, os.path.getsize(exe) / 1e6), flush=True)
    started = time.time()
    done = subprocess.run([iscc, '/Qp', '/DAppVersion=' + v, '/DSourceDir=' + SOURCE, '/DOutputDir=' + OUTPUT, SCRIPT])
    if done.returncode != 0:
        raise SystemExit('ISCC failed (exit %d)' % done.returncode)
    setup = os.path.join(OUTPUT, 'Sleep-%s-Setup.exe' % v)
    digest = hashlib.sha256()
    with open(setup, 'rb') as f:
        for block in iter(lambda: f.read(1 << 24), b''):
            digest.update(block)
    print('   %.0f s' % (time.time() - started))
    print('   %s  %.0f MB' % (setup, os.path.getsize(setup) / 1e6))
    print('   SHA-256 %s' % digest.hexdigest())


if __name__ == '__main__':
    main()
