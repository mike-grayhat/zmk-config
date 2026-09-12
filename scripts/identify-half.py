#!/usr/bin/env python3
"""Say whether a nice!nano UF2 image is the central (left) or peripheral (right) half.

The bootloader reports identical INFO_UF2.TXT on both halves, so the only
reliable discriminator is what is actually flashed: the central half carries
split-central symbols the peripheral never links in.

    python3 scripts/identify-half.py /Volumes/NICENANO/CURRENT.UF2
"""
import re
import struct
import sys

# Only these two are genuinely central-only. The zmk_peripheral_*_changed
# event NAMES are linked into both halves, so they do not discriminate —
# verified against the known-good left and right builds in firmware/previous/.
CENTRAL_MARKERS = [
    b"peripheral_addresses",   # settings key the central uses to store bonds
    b"ble_central",            # central-role BLE connection code
]


def flatten(path):
    data = open(path, "rb").read()
    mem = {}
    for i in range(len(data) // 512):
        blk = data[i * 512:(i + 1) * 512]
        magic, _, _, addr, payload, _, _, _ = struct.unpack("<8I", blk[:32])
        if magic == 0x0A324655:
            mem[addr] = blk[32:32 + payload]
    if not mem:
        sys.exit(f"{path}: not a UF2 file")
    lo, hi = min(mem), max(mem) + 256
    buf = bytearray(b"\xff" * (hi - lo))
    for addr, chunk in mem.items():
        buf[addr - lo:addr - lo + len(chunk)] = chunk
    return lo, bytes(buf)


def main():
    if len(sys.argv) != 2:
        sys.exit(f"usage: {sys.argv[0]} <image.uf2>")
    path = sys.argv[1]
    lo, img = flatten(path)

    hits = [m.decode() for m in CENTRAL_MARKERS if m in img]
    half = "left" if hits else "right"

    used = img.rstrip(b"\xff")
    layers = sorted(set(re.findall(rb"\b(?:Base|Extra|Tap|Button|Nav|Mouse|Media|Num|Sym|Fun)\b", img)))

    print(f"half:      {half} ({'central' if hits else 'peripheral'})")
    print(f"start:     0x{lo:06X}")
    print(f"code:      ~{len(used) / 1024:.0f} KiB")
    if hits:
        print(f"evidence:  {', '.join(hits)}")
    else:
        print("evidence:  no split-central symbols present")
    if layers:
        print(f"layers:    {' '.join(s.decode() for s in layers)}")
    print(half)  # last line: machine-readable


if __name__ == "__main__":
    main()
