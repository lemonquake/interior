"""0.43: where a frame's script time goes. Wraps every game script's _process / _physics_process with a timer that
adds into InteriorProf (scripts/prof.gd), runs nothing itself, and puts the scripts back byte for byte.

    python -I tools/prof_frame.py apply      # originals kept in work/v43/prof_backup/
    ... run a perf test with `-- --prof` (InteriorProf prints INTERIOR_PROF lines every 2 s) ...
    python -I tools/prof_frame.py revert

Never export while applied.
"""
import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = os.path.join(ROOT, "game")
BACKUP = os.path.join(ROOT, "work", "v43", "prof_backup")
CALLBACKS = ("_process", "_physics_process")


def scripts():
    for folder in ("scripts", os.path.join("scripts", "coop")):
        d = os.path.join(GAME, folder)
        for name in sorted(os.listdir(d)):
            if name.endswith(".gd") and name != "prof.gd":
                yield os.path.join(folder, name)


def apply():
    if os.path.exists(BACKUP):
        raise SystemExit("already applied (revert first)")
    os.makedirs(BACKUP)
    count = 0
    for rel in scripts():
        path = os.path.join(GAME, rel)
        text = open(path, encoding="utf-8", newline="").read()
        changed = text
        for cb in CALLBACKS:
            m = re.search(r"^func %s\((\w+)(: float)?\) -> void:" % cb, changed, re.M)
            if not m:
                continue
            arg = m.group(1)
            inner = "_prof_%s%s" % (re.sub(r"\W", "_", os.path.basename(rel)[:-3]), cb)
            changed = changed[:m.start()] + "func %s(%s: float) -> void:" % (inner, arg) + changed[m.end():]
            tag = rel.replace("\\", "/").replace("scripts/", "") + cb.replace("_process", "").replace("_physics", ":phys")
            changed += ("\n\nfunc %s(prof_delta: float) -> void:\n\tvar prof_t := Time.get_ticks_usec()\n"
                        "\t%s(prof_delta)\n\tInteriorProf.add(\"%s\", Time.get_ticks_usec() - prof_t)\n") % (cb, inner, tag)
            count += 1
        if changed != text:
            dest = os.path.join(BACKUP, rel)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            shutil.copyfile(path, dest)
            open(path, "w", encoding="utf-8", newline="").write(changed)
    print("wrapped", count, "callbacks")


def revert():
    if not os.path.exists(BACKUP):
        raise SystemExit("nothing to revert")
    for base, _dirs, files in os.walk(BACKUP):
        for name in files:
            src = os.path.join(base, name)
            rel = os.path.relpath(src, BACKUP)
            shutil.copyfile(src, os.path.join(GAME, rel))
    shutil.rmtree(BACKUP)
    print("reverted")


if __name__ == "__main__":
    {"apply": apply, "revert": revert}[sys.argv[1]]()
