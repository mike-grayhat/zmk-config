#!/usr/bin/env python3
"""Inject the parsed keymap into the interactive viewer.

Reads the YAML that `keymap-drawer parse` produces and rewrites the
<script id="keymap-data"> block in keymap-drawer/viewer.html, so the viewer
never drifts from config/corne.keymap.

    keymap -c keymap_drawer.config.yaml parse -z config/corne.keymap \
        > keymap-drawer/corne.yaml
    python3 scripts/build_viewer.py
"""
import json
import pathlib
import re
import sys

try:
    import yaml
except ImportError:
    sys.exit("needs pyyaml:  uv run --with pyyaml python3 scripts/build_viewer.py")

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "keymap-drawer" / "corne.yaml"
DST = ROOT / "keymap-drawer" / "viewer.html"


def normalise(key):
    if isinstance(key, dict):
        out = {}
        for src, dest in (("t", "t"), ("h", "h"), ("s", "s"), ("type", "type")):
            if key.get(src) is not None:
                out[dest] = str(key[src])
        return out
    return {"t": "" if key is None else str(key)}


def main():
    data = yaml.safe_load(SRC.read_text())
    layers = {name: [normalise(k) for k in keys] for name, keys in data["layers"].items()}

    bad = {n: len(v) for n, v in layers.items() if len(v) != 42}
    if bad:
        sys.exit(f"expected 42 keys per layer, got {bad}")

    payload = json.dumps(layers, ensure_ascii=False, separators=(",", ":"))
    html = DST.read_text()
    new, n = re.subn(
        r'(<script id="keymap-data" type="application/json">)(.*?)(</script>)',
        lambda m: m.group(1) + "\n" + payload + "\n" + m.group(3),
        html,
        count=1,
        flags=re.S,
    )
    if n != 1:
        sys.exit("could not find the keymap-data script block in viewer.html")
    DST.write_text(new)
    print(f"viewer.html updated: {len(layers)} layers, 42 keys each")


if __name__ == "__main__":
    main()
