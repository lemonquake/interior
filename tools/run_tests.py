"""Runs the headless test scripts three at a time and prints one line each.

  python -I tools/run_tests.py                 # every tests/*_integration.gd
  python -I tools/run_tests.py gun zombies     # only those whose name contains one of the words
"""
import concurrent.futures, glob, json, os, re, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.path.join(ROOT, '.local', 'tools', 'Godot_v4.7.2-stable_win64_console.exe')
GAME = os.path.join(ROOT, 'game')
LOGS = os.path.join(ROOT, 'work', 'v30', 'tests')
MOBILE = {'touch_integration', 'mobile_budget_integration'}


def run(name):
    args = [GODOT, '--headless', '--fixed-fps', '60', '--path', GAME, '--script', 'res://tests/%s.gd' % name]
    if name in MOBILE:
        args += ['--', '--mobile-test']
    started = time.time()
    try:
        done = subprocess.run(args, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=420)
        text = done.stdout + done.stderr
    except subprocess.TimeoutExpired as late:
        text = (late.stdout or '') + '\nTIMEOUT'
        if isinstance(text, bytes):
            text = text.decode('utf-8', 'replace')
    open(os.path.join(LOGS, name + '.log'), 'w', encoding='utf-8').write(text)
    verdict, detail = 'NO REPORT', ''
    for line in text.splitlines():
        found = re.match(r'INTERIOR_\w+ (\{.*\})\s*$', line)
        if found:
            try:
                report = json.loads(found.group(1))
            except ValueError:
                continue
            if 'passed' in report:
                verdict = 'pass' if report['passed'] else 'FAIL'
                detail = '%s checks, failures: %s' % (report.get('checks', '?'), report.get('failures', []))
    if 'TIMEOUT' in text[-20:]:
        verdict = 'TIMEOUT'
    errors = len(re.findall(r'SCRIPT ERROR', text))
    return name, verdict, detail, errors, time.time() - started


def main():
    os.makedirs(LOGS, exist_ok=True)
    names = sorted(os.path.basename(p)[:-3] for p in glob.glob(os.path.join(GAME, 'tests', '*_integration.gd')))
    words = sys.argv[1:]
    if words:
        names = [n for n in names if any(w in n for w in words)]
    with concurrent.futures.ThreadPoolExecutor(3) as pool:
        for name, verdict, detail, errors, took in pool.map(run, names):
            print('%-8s %-34s %4.0f s  script errors %d  %s' % (verdict, name, took, errors, detail[:300]), flush=True)


if __name__ == '__main__':
    main()
