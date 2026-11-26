"""Audit/fix standalone 3D texture imports; preserve every source image and UID."""
import argparse
import collections
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FOLDERS = ("outdoor", "models", "materials", "characters", "hamsters", "surfaces", "horror_textures", "siege")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    changes = []
    modes = collections.Counter()
    for folder in FOLDERS:
        for path in sorted((ROOT / "game/assets" / folder).rglob("*.import")):
            original = path.read_text(encoding="utf-8")
            if 'importer="texture"' not in original:
                continue
            mode = re.search(r"^compress/mode=(\d+)$", original, re.M)
            modes[mode[1] if mode else "missing"] += 1
            edited = original
            for key, value in (("compress/mode", "2"), ("mipmaps/generate", "true"),
                               ("detect_3d/compress_to", "0")):
                edited = re.sub(rf"^{re.escape(key)}=.*$", f"{key}={value}", edited, flags=re.M)
            if edited != original:
                changes.append(str(path.relative_to(ROOT)).replace("\\", "/"))
                if args.apply:
                    path.write_text(edited, encoding="utf-8", newline="\n")
    report = {"applied": args.apply, "previous_compression_modes": dict(modes),
              "changed_imports": len(changes), "paths": changes,
              "source_images_modified": False, "resolution_reduced": False}
    output = ROOT / "docs/mobile-performance/texture-imports.json"
    if args.apply and output.exists():
        previous = json.loads(output.read_text(encoding="utf-8"))
        if previous.get("applied"):
            report["paths"] = sorted(set(previous.get("paths", [])) | set(changes))
            report["changed_imports"] = len(report["paths"])
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps({k:v for k,v in report.items() if k != "paths"}))

if __name__ == "__main__":
    main()
