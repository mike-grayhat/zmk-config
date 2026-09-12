#!/usr/bin/env bash
# Pull whatever is on a nice!nano right now, before overwriting it.
#
#   1. connect one half by USB
#   2. double-tap its reset button (or hit the `boot` key on Nav/Mouse/Media/Num/Fun)
#   3. ./scripts/backup-firmware.sh
#
# Which half it is gets worked out from the flashed image — the bootloader
# reports identical INFO_UF2.TXT on both. Pass left|right to override.
#
# NOTE: CURRENT.UF2 is a bootloader READBACK, not a restore image. It starts at
# 0x1000 (inside the SoftDevice) with family 0x239A00B3, and the bootloader will
# not accept it back. It is a record, not a rollback. Your actual rollback
# images are the build artifacts in firmware/previous/.
set -euo pipefail

cd "$(dirname "$0")/.."

VOL="${NICENANO_VOL:-/Volumes/NICENANO}"
if [[ ! -d "$VOL" ]]; then
    echo "No bootloader volume at $VOL." >&2
    echo "Connect a half by USB and double-tap its reset button, then re-run." >&2
    exit 1
fi
[[ -f "$VOL/CURRENT.UF2" ]] || { echo "$VOL has no CURRENT.UF2 — not a nice!nano bootloader?" >&2; exit 1; }

HALF="${1:-}"
if [[ -z "$HALF" ]]; then
    HALF=$(python3 scripts/identify-half.py "$VOL/CURRENT.UF2" | tail -1)
    echo "Detected half: $HALF"
elif [[ "$HALF" != "left" && "$HALF" != "right" ]]; then
    echo "usage: $0 [left|right]" >&2
    exit 2
fi

DEST="firmware/bootloader-readback/$(date +%F)-${HALF}"
if [[ -d "$DEST" ]]; then
    echo "Refusing: $DEST already exists. Move or delete it first." >&2
    exit 1
fi
mkdir -p "$DEST"

cp "$VOL/CURRENT.UF2"  "$DEST/CURRENT.UF2"
cp "$VOL/INFO_UF2.TXT" "$DEST/INFO_UF2.TXT"

{
    echo "Bootloader readback taken $(date '+%Y-%m-%d %H:%M %Z') from $VOL."
    echo
    python3 scripts/identify-half.py "$DEST/CURRENT.UF2" | sed '$d'
    echo
    echo "NOT FLASHABLE. Starts at 0x1000 with UF2 family 0x239A00B3; the"
    echo "bootloader will not accept it back. Record only — to roll back, use a"
    echo "build artifact from firmware/previous/."
} > "$DEST/README.txt"

echo "Saved $HALF readback to $DEST"
sed -n '2,3p' "$DEST/INFO_UF2.TXT"
