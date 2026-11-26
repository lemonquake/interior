"""0.35: takes game/assets/ui/menu_still.jpg, the picture under the menu on the loading screen.

  python -I tools/menu_still.py

Starts the game from the project, waits for the home menu, takes the title and the buttons off and saves what is
left (the live street with the menu's shade and blood over it). scripts/loading_screen.gd shows it from the first
frame, so the menu is there about a second after the game starts and the real street fades in behind the same
picture. tools/export_windows.py runs this before every export: take it again whenever the menu's street, its
lighting or the menu's overlays change. A game window is on screen for about fifteen seconds.
"""
import os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.path.join(ROOT, '.local', 'tools', 'Godot_v4.7.2-stable_win64_console.exe')
GAME = os.path.join(ROOT, 'game')
OUT = os.path.join(GAME, 'assets', 'ui', 'menu_still.jpg')


def main():
    target = OUT.replace(os.sep, '/')
    try:
        done = subprocess.run([GODOT, '--path', GAME, '--', '--capture-menu-still=' + target, '--render-size=1920x1080'],
                              capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=150)
    except subprocess.TimeoutExpired:
        subprocess.run(['taskkill', '/F', '/IM', os.path.basename(GODOT)], capture_output=True)
        raise SystemExit('The game did not reach its menu in 150 s.')
    found = re.search(r'INTERIOR_MENU_STILL (.*)', done.stdout + done.stderr)
    if not found or not os.path.exists(OUT):
        sys.stderr.write((done.stdout + done.stderr)[-3000:])
        raise SystemExit('The menu still was not taken; see the output above.')
    print('menu still:', found.group(1).strip(), '%.0f KB' % (os.path.getsize(OUT) / 1e3))


if __name__ == '__main__':
    main()
