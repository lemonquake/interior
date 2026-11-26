"""Publishes Sleep: the launcher's signed game updates, the launcher itself, the Android APK and the website.

    python -I tools/release/publish.py keygen                  # once: the signing key (kept outside the repository)
    python -I tools/release/build_launcher.py                  # the Windows launcher -> builds/release/launcher
    python -I tools/export_windows.py                          # the game -> builds/windows (Interior.exe + Interior.pck)
    python -I tools/release/publish.py stage --notes tools/release/notes/0.62.0.md
    python -I tools/release/publish.py upload                  # new chunks + the staged release (players see nothing yet)
    python -I tools/release/publish.py activate                # every launcher offers the update from now on
    python -I tools/release/publish.py apk                     # builds/android/Interior.apk to /downloads
    python -I tools/release/publish.py site                    # website/ to the site root
    python -I tools/release/publish.py launchers | status

How updates work (the same scheme as the Aetherion launcher it came from): every file of the Windows build is cut into
content-defined chunks (chunker.py), stored once by SHA-256, raw-deflated, under /updates/chunks/<2 hex>/<sha256>. The
release is /updates/windows/release.json: {"manifest": base64 of the manifest JSON, "sig": base64 RSA PKCS#1 v1.5
SHA-256 signature of those bytes}. The launcher pins the public key (tools/release/update-public-key.json, built into it)
and checks every chunk's hash and every file's hash, so an update only downloads the chunks that changed and nothing
unsigned is ever installed. The private key is outside the repository (KEY below): losing it means shipping a new
launcher.

Hosting: server/deploy (Caddy serves /srv/sleep on the VPS; the relay and the lobby run beside it).
"""
import argparse
import base64
import datetime
import hashlib
import io
import json
import os
import subprocess
import sys
import tarfile
import time
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import chunker  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "builds" / "windows"
REL = ROOT / "builds" / "release"
STORE = REL / "store"
LAUNCHERS = REL / "launcher"
KEY = Path(os.environ.get("SLEEP_SIGNING_KEY", Path.home() / ".sleep-private" / "update-signing-key.pem"))
PUBLIC = Path(__file__).resolve().parent / "update-public-key.json"
SSH_KEY = Path.home() / ".ssh" / "bh_ovh_testers"
HOST = os.environ.get("SLEEP_VPS", "ubuntu@15.235.246.87")
REMOTE = "/srv/sleep"
SITE_URL = "https://sleep.15-235-246-87.sslip.io"
SITE = ROOT / "website"
APK = ROOT / "builds" / "android" / "Interior.apk"
LAUNCH = "Interior.exe"
LAUNCHER = "SleepLauncher.exe"
# What the launcher installs from builds/windows: the game and its licence/credit files. Not the tools that live there.
GAME_SUFFIXES = (".exe", ".pck", ".dll", ".md", ".txt")
SKIP = {"Interior.exe.truncated"}


def project_version() -> str:
    for line in (ROOT / "game" / "project.godot").read_text(encoding="utf-8").splitlines():
        if line.startswith("config/version="):
            return line.split("=", 1)[1].strip().strip('"')
    raise SystemExit("no config/version in project.godot")


def ssh(cmd: str, stdin=None, check=True):
    args = ["ssh", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", "-i", str(SSH_KEY), HOST, cmd]
    r = subprocess.run(args, input=stdin, capture_output=True, check=False)
    if check and r.returncode != 0:
        raise SystemExit("ssh failed (%d): %s\n%s" % (r.returncode, cmd, (r.stderr or b"").decode(errors="replace")))
    return r


# ------------------------------------------------------------------ keys

def load_private():
    from cryptography.hazmat.primitives import serialization
    if not KEY.exists():
        raise SystemExit("signing key missing: %s (run keygen once)" % KEY)
    return serialization.load_pem_private_key(KEY.read_bytes(), password=None)


def sign(data: bytes) -> str:
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.asymmetric import padding
    return base64.b64encode(load_private().sign(data, padding.PKCS1v15(), hashes.SHA256())).decode()


def cmd_keygen(_a) -> None:
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import rsa
    if KEY.exists():
        print("signing key already exists at %s; not replacing it" % KEY)
    else:
        KEY.parent.mkdir(parents=True, exist_ok=True)
        k = rsa.generate_private_key(public_exponent=65537, key_size=3072)
        KEY.write_bytes(k.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                        serialization.NoEncryption()))
        print("new signing key at %s: back it up; the launcher trusts only this key" % KEY)
    pub = load_private().public_key()
    n = pub.public_numbers()
    der = pub.public_bytes(serialization.Encoding.DER, serialization.PublicFormat.PKCS1)
    out = {"_doc": "Public half of the Sleep update signing key (tools/release/publish.py). Built into the launcher.",
           "modulus": base64.b64encode(n.n.to_bytes((n.n.bit_length() + 7) // 8, "big")).decode(),
           "exponent": base64.b64encode(n.e.to_bytes(3, "big")).decode(),
           "pkcs1_der": base64.b64encode(der).decode(),
           "sha256": hashlib.sha256(der).hexdigest()}
    PUBLIC.write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("public key written to %s (%s)" % (PUBLIC, out["sha256"][:16]))


# ------------------------------------------------------------------ staging

def game_files():
    out = []
    for p in sorted(BUILD.iterdir()):
        if p.is_file() and p.suffix.lower() in GAME_SUFFIXES and p.name not in SKIP:
            out.append((p.name, p))
    if not (BUILD / LAUNCH).exists():
        raise SystemExit("missing %s: export the game first (python -I tools/export_windows.py)" % (BUILD / LAUNCH))
    return out


def chunk_cached(path: Path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(16 * 1024 * 1024), b""):
            h.update(block)
    digest = h.hexdigest()
    cache_f = STORE / "chunk_cache.json"
    cache = json.loads(cache_f.read_text(encoding="utf-8")) if cache_f.exists() else {}
    key = "%s:%d:%d:%d" % (digest, path.stat().st_size, chunker.CUT_BITS, chunker.MIN_SIZE)
    if key in cache:
        return [tuple(c) for c in cache[key]], digest
    chunks, d2 = chunker.chunk_file(str(path))
    assert d2 == digest
    cache[key] = chunks
    STORE.mkdir(parents=True, exist_ok=True)
    cache_f.write_text(json.dumps(cache), encoding="utf-8")
    return chunks, digest


def store_chunk(path: Path, off: int, size: int, digest: str) -> int:
    dest = STORE / "chunks" / digest[:2] / digest
    if dest.exists():
        return dest.stat().st_size
    with open(path, "rb") as f:
        f.seek(off)
        data = f.read(size)
    assert hashlib.sha256(data).hexdigest() == digest
    c = zlib.compressobj(6, zlib.DEFLATED, -15)
    z = c.compress(data) + c.flush()
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(".tmp")
    tmp.write_bytes(z)
    os.replace(tmp, dest)
    return len(z)


def launcher_info():
    f = LAUNCHERS / LAUNCHER
    meta = LAUNCHERS / (LAUNCHER + ".json")
    if not f.exists() or not meta.exists():
        print("  (no launcher build yet: %s)" % f)
        return None
    m = json.loads(meta.read_text(encoding="utf-8"))
    return {"version": m["version"], "url": "../../downloads/" + LAUNCHER, "size": f.stat().st_size,
            "sha256": hashlib.sha256(f.read_bytes()).hexdigest()}


def cmd_stage(a) -> None:
    version = a.version or project_version()
    notes = []
    if a.notes:
        notes = [l.strip().lstrip("-*").strip() for l in Path(a.notes).read_text(encoding="utf-8").splitlines()
                 if l.strip() and not l.startswith("#")]
    now = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    print("[stage] windows %s" % version)
    files = []
    total = stored = 0
    for rel, path in game_files():
        chunks, digest = chunk_cached(path)
        entry = {"path": rel, "size": path.stat().st_size, "sha256": digest, "chunks": []}
        for off, size, h in chunks:
            z = store_chunk(path, off, size, h)
            entry["chunks"].append([h, size, z])
            stored += z
        total += entry["size"]
        files.append(entry)
        print("  %-40s %12d bytes, %5d chunks" % (rel[:40], entry["size"], len(chunks)))
    man = {"format": 1, "game": "Sleep", "author": "Aljay Leodones", "studio": "AzAz Games",
           "platform": "windows", "version": version, "net_version": "sleep-" + version, "published": now,
           "launch": LAUNCH, "notes": notes, "chunks": "../chunks/",
           "size": total, "download_size": stored, "files": files}
    li = launcher_info()
    if li:
        man["launcher"] = li
    data = json.dumps(man, separators=(",", ":"), sort_keys=True).encode("utf-8")
    rel_doc = {"manifest": base64.b64encode(data).decode(), "sig": sign(data)}
    d = STORE / "staged" / "windows"
    d.mkdir(parents=True, exist_ok=True)
    (d / "release.json").write_text(json.dumps(rel_doc), encoding="utf-8", newline="\n")
    (d / "manifest.json").write_bytes(data)  # readable copy for people and tests; not published
    print("  -> %d files, %.2f GB, %.2f GB compressed" % (len(files), total / 1e9, stored / 1e9))


# ------------------------------------------------------------------ upload / activate

def staged_manifest():
    f = STORE / "staged" / "windows" / "manifest.json"
    if not f.exists():
        raise SystemExit("nothing staged")
    return json.loads(f.read_text(encoding="utf-8"))


def tar_stream(entries):
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w", format=tarfile.GNU_FORMAT) as t:
        for arc, path in entries:
            ti = t.gettarinfo(str(path), arcname=arc)
            ti.uid = ti.gid = 0
            ti.uname = ti.gname = ""
            ti.mode = 0o644
            with open(path, "rb") as f:
                t.addfile(ti, f)
    return buf.getvalue()


def cmd_upload(_a) -> None:
    m = staged_manifest()
    have = set(ssh("mkdir -p %s/updates/chunks && cd %s/updates/chunks && find . -type f -printf '%%P\\n'" % (REMOTE, REMOTE))
               .stdout.decode().split())
    need = {}
    for f in m["files"]:
        for h, _size, _z in f.get("chunks", []):
            key = "%s/%s" % (h[:2], h)
            if key not in have:
                need[key] = STORE / "chunks" / h[:2] / h
    print("[upload] %d chunks already on the server, %d to send (%.2f GB)" % (
        len(have), len(need), sum(p.stat().st_size for p in need.values()) / 1e9))
    batch, size = [], 0
    keys = sorted(need)
    for i, k in enumerate(keys):
        batch.append(("chunks/" + k, need[k]))
        size += need[k].stat().st_size
        if size > 48 * 1024 * 1024 or i == len(keys) - 1:
            # Into a temporary folder first, so a half-sent chunk is never served. A dropped connection is retried.
            body = tar_stream(batch)
            for attempt in range(6):
                r = ssh("cd %s/updates && rm -rf .incoming && mkdir -p .incoming && tar -x -C .incoming && cd .incoming/chunks && "
                        "find . -type f -printf '%%P\\n' | while read f; do mkdir -p ../../chunks/$(dirname $f); mv -f $f ../../chunks/$f; done"
                        % REMOTE, stdin=body, check=False)
                if r.returncode == 0:
                    break
                print("  batch failed (%s), retrying" % (r.stderr or b"").decode(errors="replace").strip()[-120:], flush=True)
                time.sleep(5 * (attempt + 1))
            else:
                raise SystemExit("upload kept failing; run upload again later (it resumes)")
            print("  sent %d/%d" % (i + 1, len(keys)), flush=True)
            batch, size = [], 0
    staged = [("next/windows/release.json", STORE / "staged" / "windows" / "release.json")]
    if (LAUNCHERS / LAUNCHER).exists():
        staged += [("next/downloads/" + LAUNCHER, LAUNCHERS / LAUNCHER),
                   ("next/downloads/%s.json" % LAUNCHER, LAUNCHERS / (LAUNCHER + ".json"))]
    ssh("rm -rf %s/updates/next && mkdir -p %s/updates && tar -x -C %s/updates" % (REMOTE, REMOTE, REMOTE),
        stdin=tar_stream(staged))
    # Check the server's store is complete for this release before anyone is offered it.
    hashes = "\n".join(sorted({c[0] for f in m["files"] for c in f["chunks"]})) + "\n"
    missing = ssh("cd %s/updates/chunks && while read h; do [ -f ${h:0:2}/$h ] || echo $h; done" % REMOTE,
                  stdin=hashes.encode(), check=False).stdout.decode().split()
    if missing:
        raise SystemExit("[upload] %d chunks missing on the server: %s…" % (len(missing), missing[0]))
    print("[upload] staged %s; players still get the current release until activate" % m["version"])


def downloads_index() -> bytes:
    """downloads/index.json for the website: what can be downloaded right now."""
    out = {"launcher": None, "android": None, "game": None}
    r = ssh("cat %s/downloads/%s.json 2>/dev/null; echo; echo ---; cat %s/downloads/Interior.apk.json 2>/dev/null; echo; echo ---; "
            "cat %s/updates/windows/release.json 2>/dev/null" % (REMOTE, LAUNCHER, REMOTE, REMOTE), check=False).stdout.decode()
    parts = [p.strip() for p in r.split("---")]
    try:
        out["launcher"] = dict(json.loads(parts[0]), file="downloads/" + LAUNCHER)
    except (ValueError, IndexError):
        pass
    try:
        out["android"] = dict(json.loads(parts[1]), file="downloads/Interior.apk")
    except (ValueError, IndexError):
        pass
    try:
        man = json.loads(base64.b64decode(json.loads(parts[2])["manifest"]))
        out["game"] = {"version": man["version"], "published": man["published"], "size": man["size"], "notes": man["notes"]}
    except (ValueError, IndexError, KeyError):
        pass
    return (json.dumps(out, indent=1) + "\n").encode()


def write_index() -> None:
    ssh("cat > %s/downloads/index.json.tmp && mv -f %s/downloads/index.json.tmp %s/downloads/index.json" % (REMOTE, REMOTE, REMOTE),
        stdin=downloads_index())


def cmd_activate(_a) -> None:
    m = staged_manifest()
    v = m["version"]
    ssh("set -e; cd {r}/updates; test -f next/windows/release.json; mkdir -p windows history {r}/downloads; "
        "cp next/windows/release.json history/windows-{v}.json; "
        "if [ -d next/downloads ]; then cp -f next/downloads/* {r}/downloads/; fi; "
        "mv -f next/windows/release.json windows/release.json; rm -rf next".format(r=REMOTE, v=v))
    write_index()
    print("[activate] Sleep %s is live: every launcher offers it now (%s/updates/windows/release.json)" % (v, SITE_URL))


def cmd_launchers(_a) -> None:
    """Publish only the launcher download (and its metadata) without a new game release."""
    if not (LAUNCHERS / LAUNCHER).exists():
        raise SystemExit("build it first: python -I tools/release/build_launcher.py")
    entries = [("downloads/" + LAUNCHER, LAUNCHERS / LAUNCHER), ("downloads/%s.json" % LAUNCHER, LAUNCHERS / (LAUNCHER + ".json"))]
    ssh("mkdir -p {r}/downloads.new {r}/downloads && tar -x -C {r}/downloads.new && cp -f {r}/downloads.new/downloads/* {r}/downloads/ "
        "&& rm -rf {r}/downloads.new".format(r=REMOTE), stdin=tar_stream(entries))
    write_index()
    print("[launchers] published %s" % ", ".join(e[0] for e in entries))


def cmd_apk(_a) -> None:
    if not APK.exists():
        raise SystemExit("no %s" % APK)
    h = hashlib.sha256()
    with open(APK, "rb") as f:
        for block in iter(lambda: f.read(16 * 1024 * 1024), b""):
            h.update(block)
    digest = h.hexdigest()
    dest = "%s/downloads/Interior.apk" % REMOTE
    remote = ssh("sha256sum %s 2>/dev/null || true" % dest).stdout.decode().split()
    if remote and remote[0] == digest:
        print("[apk] already on the server")
    else:
        print("[apk] sending %.0f MB" % (APK.stat().st_size / 1e6))
        with open(APK, "rb") as f:
            r = subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", "-i", str(SSH_KEY), HOST,
                                "mkdir -p %s/downloads && cat > %s.part && echo '%s  %s.part' | sha256sum -c --quiet && mv -f %s.part %s"
                                % (REMOTE, dest, digest, dest, dest, dest)], stdin=f, capture_output=True)
        if r.returncode != 0:
            raise SystemExit("upload failed: %s" % r.stderr.decode(errors="replace"))
    info = {"platform": "android", "name": "Sleep for Android", "version": project_version(),
            "requires": "Android 7.0 or newer", "size": APK.stat().st_size, "sha256": digest}
    ssh("cat > %s.json" % dest, stdin=(json.dumps(info, indent=1) + "\n").encode())
    write_index()
    print("[apk] published: %s/downloads/Interior.apk" % SITE_URL)


def cmd_site(_a) -> None:
    """Replace the website (website/ -> /srv/sleep/site) in one rename, so nobody gets half a site."""
    if not (SITE / "index.html").exists():
        raise SystemExit("no %s" % (SITE / "index.html"))
    entries = [(p.relative_to(SITE).as_posix(), p) for p in sorted(SITE.rglob("*")) if p.is_file()]
    ssh("rm -rf {r}/site.new && mkdir -p {r}/site.new && tar -x -C {r}/site.new && find {r}/site.new -type d -exec chmod 755 {{}} + && "
        "rm -rf {r}/site.old && (mv {r}/site {r}/site.old || true) && mv {r}/site.new {r}/site && rm -rf {r}/site.old".format(r=REMOTE),
        stdin=tar_stream(entries))
    print("[site] %d files published to %s/" % (len(entries), SITE_URL))


def cmd_status(_a) -> None:
    r = ssh("systemctl is-active sleep-relay mosquitto caddy | paste -sd' '; curl -s 127.0.0.1:8480/rooms; echo; "
            "du -sh {r}/updates/chunks {r}/downloads 2>/dev/null; ls {r}/updates/history 2>/dev/null".format(r=REMOTE), check=False)
    sys.stdout.write(r.stdout.decode(errors="replace") + r.stderr.decode(errors="replace"))


def main() -> None:
    sys.stdout.reconfigure(errors="replace")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("keygen")
    s = sub.add_parser("stage")
    s.add_argument("--version")
    s.add_argument("--notes")
    for name in ("upload", "activate", "launchers", "apk", "site", "status"):
        sub.add_parser(name)
    a = ap.parse_args()
    {"keygen": cmd_keygen, "stage": cmd_stage, "upload": cmd_upload, "activate": cmd_activate, "launchers": cmd_launchers,
     "apk": cmd_apk, "site": cmd_site, "status": cmd_status}[a.cmd](a)


if __name__ == "__main__":
    main()
