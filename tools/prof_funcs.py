"""0.65: inclusive time and calls per function, for chosen scripts. Every top-level `func` in the given files (not
static, not an RPC, not a coroutine, not a setter/getter) is renamed `_pfn_<name>` and a same-signature wrapper times
the call into InteriorProf (scripts/prof.gd). Nested calls count in both (inclusive); call counts show the hot small
ones. `-- --prof` prints the top lines every 240 frames.

    python -I tools/prof_funcs.py apply scripts/coop/mission.gd scripts/coop/bots.gd ...
    ... run a perf test with `-- --prof` ...
    python -I tools/prof_funcs.py revert

Never export while applied. Originals are kept in work/v65/prof_funcs_backup/.
"""
import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = os.path.join(ROOT, "game")
BACKUP = os.path.join(ROOT, "work", "v65", "prof_funcs_backup")
SKIP = {"_init", "_ready", "_enter_tree", "_exit_tree", "_notification", "_to_string", "_get", "_set",
        "_get_property_list", "_validate_property"}
FUNC = re.compile(r"^func (\w+)\((.*)\)(\s*->\s*([\w\[\]\.]+))?\s*:(.*)$")


def split_args(text):
    parts, depth, cur, quote = [], 0, "", None
    for ch in text:
        if quote:
            cur += ch
            if ch == quote:
                quote = None
            continue
        if ch in "\"'":
            quote = ch
        elif ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "," and depth == 0:
            parts.append(cur)
            cur = ""
            continue
        cur += ch
    if cur.strip():
        parts.append(cur)
    return [re.split(r"[:=]", p.strip(), 1)[0].strip() for p in parts]


def wrap(text, tag):
    lines = text.split("\n")
    out = []
    extra = []
    i = 0
    count = 0
    while i < len(lines):
        line = lines[i]
        m = FUNC.match(line)
        prev = out[-1].strip() if out else ""
        if not m or m.group(1) in SKIP or prev.startswith("@rpc") or prev.startswith("@warning") and False:
            out.append(line)
            i += 1
            continue
        name, args, _ret, ret, rest = m.group(1), m.group(2), m.group(3), m.group(4), m.group(5)
        # The body: following lines that are indented, blank or comments, up to the next top-level statement.
        j = i + 1
        while j < len(lines) and (lines[j].startswith("\t") or lines[j].strip() == "" or lines[j].startswith("#")):
            j += 1
        body = lines[i + 1:j]
        one_liner = rest.strip() != ""
        coroutine = any(re.search(r"\bawait\b", b) for b in body) or "await" in rest
        if coroutine or "..." in args:
            out.extend(lines[i:j])
            i = j
            continue
        inner = "_pfn_" + name
        out.append("func %s(%s)%s:%s" % (inner, args, _ret or "", rest))
        out.extend(body)
        names = ", ".join(split_args(args))
        sig = "func %s(%s)%s:" % (name, args, _ret or "")
        w = [sig, "\tvar _pft := Time.get_ticks_usec()"]
        if ret and ret != "void":
            w += ["\tvar _pfr = %s(%s)" % (inner, names),
                  "\tInteriorProf.add(\"%s:%s\", Time.get_ticks_usec() - _pft)" % (tag, name),
                  "\treturn _pfr"]
        elif ret == "void":
            w += ["\t%s(%s)" % (inner, names),
                  "\tInteriorProf.add(\"%s:%s\", Time.get_ticks_usec() - _pft)" % (tag, name)]
        else:
            # Untyped return: keep whatever it returns (null for none).
            w += ["\tvar _pfr = %s(%s)" % (inner, names),
                  "\tInteriorProf.add(\"%s:%s\", Time.get_ticks_usec() - _pft)" % (tag, name),
                  "\treturn _pfr"]
        extra.append("\n".join(w))
        count += 1
        i = j
    return "\n".join(out).rstrip("\n") + "\n\n" + "\n\n".join(extra) + "\n", count


def apply(files):
    os.makedirs(BACKUP, exist_ok=True)
    total = 0
    for rel in files:
        path = os.path.join(GAME, rel)
        dest = os.path.join(BACKUP, rel)
        if os.path.exists(dest):
            print("already wrapped:", rel)
            continue
        raw = open(path, encoding="utf-8", newline="").read()
        crlf = "\r\n" in raw
        text = raw.replace("\r\n", "\n")
        tag = os.path.basename(rel)[:-3]
        changed, n = wrap(text, tag)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copyfile(path, dest)
        open(path, "w", encoding="utf-8", newline="").write(changed.replace("\n", "\r\n") if crlf else changed)
        print(rel, n)
        total += n
    print("wrapped", total, "functions")


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
    if sys.argv[1] == "apply":
        apply(sys.argv[2:])
    else:
        revert()
