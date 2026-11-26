"""0.66: the squad game's mission checks, every one, two at a time (each on its own co-op port), with a summary.

    python -I tools/run_mission_suite.py                  # all of them
    python -I tools/run_mission_suite.py escape jumps     # only those whose name contains one of the words

Logs to work/v67/suite/<name>.log (SLEEP_SUITE_LOGS); SLEEP_SUITE_GAME runs another copy of game/ (0.67: a frozen
snapshot, so scripts can be edited while the suite runs); a test passes when Godot exits 0 and no script error was printed.
"""
import concurrent.futures, os, re, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.path.join(ROOT, '.local', 'tools', 'Godot_v4.7.2-stable_win64_console.exe')
GAME = os.environ.get('SLEEP_SUITE_GAME') or os.path.join(ROOT, 'game')
LOGS = os.environ.get('SLEEP_SUITE_LOGS') or os.path.join(ROOT, 'work', 'v68', 'suite')

# [name, script, user args, rendered?, timeout s]
SUITE = [
    ['dodong_escort', 'dodong_escort_walk', [], False, 900],
    ['dodong_escort_fight', 'dodong_escort_walk', ['--fight'], False, 900],
    ['road_seal', 'road_seal_check', [], False, 600],
    ['coop_integration', 'coop_integration', [], False, 1200],
    ['coop_jumps_each', 'coop_jumps', ['--each'], False, 2700],
    ['coop_jumps_outer', 'coop_jumps', ['--each=outerstreet,outerbus,outerplaza,outerterrace,outerstation,outerplatform,outertunnel,outerriver,outermart,outerbridge'], False, 1500],
    ['coop_jumps_go', 'coop_jumps', ['--go'], False, 1500],
    ['coop_jumps_hospital', 'coop_jumps', ['--each=hospital,hosplobby,hospstairs,hosp2f,berido,kitchen,records,hosp3f,labdoor,lab,lucky,hosproof'], False, 1800],
    ['hospital', 'hospital_check', [], False, 1500],
    ['coop_chapters', 'coop_chapters', [], False, 1200],
    ['coop_store_survival', 'coop_store_survival', [], False, 900],
    ['coop_siege_end', 'coop_siege_end', [], False, 900],
    ['coop_office_entry', 'coop_office_entry', [], False, 900],
    ['coop_backstreets', 'coop_backstreets_integration', [], False, 900],
    ['coop_school', 'coop_school', [], False, 1500],
    ['coop_escape', 'coop_escape', [], False, 1500],
    ['coop_heavyarm', 'coop_heavyarm', [], False, 1200],
    ['coop_kits_modes', 'coop_kits_modes', [], False, 900],
    ['coop_squad', 'coop_squad_integration', [], False, 900],
    ['outer_walk', 'outer_street_walk', [], False, 1800],
    ['outer_walk_mart', 'outer_street_walk', ['--from=mart'], False, 1800],
    ['phone_coop', 'phone_coop', ['--mobile-test'], True, 900, ['--rendering-method', 'gl_compatibility']],
    ['debug_menu', 'debug_menu_integration', [], False, 900],
    ['seals', 'seals_integration', [], False, 900],
    ['pause_options', 'coop_pause_options', [], False, 600],
    ['siege', 'siege_integration', [], False, 900],
]


def run(item, port):
    name, script, extra, rendered, timeout = item[:5]
    engine = item[5] if len(item) > 5 else []
    args = [GODOT] + ([] if rendered else ['--headless']) + ['--fixed-fps', '60', '--path', GAME] + engine + ['--script', 'res://tests/%s.gd' % script]
    if extra: args += ['--'] + extra
    env = dict(os.environ, SLEEP_COOP_PORT=str(port))
    t = time.time()
    try:
        out = subprocess.run(args, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=timeout, env=env)
        text, code = out.stdout + out.stderr, out.returncode
    except subprocess.TimeoutExpired as e:
        text, code = ((e.stdout or b'').decode('utf-8', 'replace') if isinstance(e.stdout, bytes) else (e.stdout or '')) + '\nTIMEOUT', -9
    with open(os.path.join(LOGS, name + '.log'), 'w', encoding='utf-8') as f:
        f.write(text)
    errors = [l for l in text.splitlines() if 'SCRIPT ERROR' in l or 'Parse Error' in l]
    fails = [l.strip() for l in text.splitlines() if re.search(r'\bFAIL\b|CHECK .* false$|TIMEOUT', l)]
    ok = code == 0 and not errors and not any('TIMEOUT' in l for l in fails)
    return name, ok, code, time.time() - t, errors[:3], fails[:8]


def main():
    os.makedirs(LOGS, exist_ok=True)
    words = sys.argv[1:]
    items = [s for s in SUITE if not words or any(w in s[0] for w in words)]
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(run, it, 25160 + i) for i, it in enumerate(items)]
        for fu in concurrent.futures.as_completed(futures):
            name, ok, code, secs, errors, fails = fu.result()
            results.append((name, ok))
            print('%-22s %s  (exit %s, %.0f s)' % (name, 'ok  ' if ok else 'FAIL', code, secs), flush=True)
            for l in errors + fails: print('    ' + l[:220], flush=True)
    bad = [n for n, ok in results if not ok]
    print('SUITE %d/%d ok%s' % (len(results) - len(bad), len(results), (' — failed: ' + ', '.join(bad)) if bad else ''))


if __name__ == '__main__':
    main()
