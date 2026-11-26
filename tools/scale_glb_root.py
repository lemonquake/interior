"""Scale a GLB through one of its nodes (its scale and translation), without touching the meshes or animations.

    python -I tools/scale_glb_root.py <file.glb> <node name> <factor>

0.31: glock17.glb was 173 mm from tang to muzzle; a Glock 17 is 204 mm, and the hands (real hand models at a
man's size) made that plain. `Glock17 1.179` puts it right.
"""
import json
import struct
import sys


def main():
    path, name, factor = sys.argv[1], sys.argv[2], float(sys.argv[3])
    data = open(path, "rb").read()
    magic, version, _length = struct.unpack_from("<4sII", data, 0)
    assert magic == b"glTF" and version == 2
    json_len, json_type = struct.unpack_from("<I4s", data, 12)
    assert json_type == b"JSON"
    doc = json.loads(data[20:20 + json_len])
    rest = data[20 + json_len:]
    node = next(n for n in doc["nodes"] if n.get("name") == name)
    assert "matrix" not in node
    node["scale"] = [v * factor for v in node.get("scale", [1.0, 1.0, 1.0])]
    node["translation"] = [v * factor for v in node.get("translation", [0.0, 0.0, 0.0])]
    text = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    text += b" " * (-len(text) % 4)
    out = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(text) + len(rest)) + struct.pack("<I4s", len(text), b"JSON") + text + rest
    open(path, "wb").write(out)
    print(name, "scale", node["scale"], "translation", node["translation"])


if __name__ == "__main__":
    main()
