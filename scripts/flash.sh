#!/usr/bin/env bash
# Copy a firmware image onto a nice!nano in bootloader mode.
#
#   1. double-tap reset on the half (or hit the `boot` key on Nav/Mouse/Media/Num/Fun)
#   2. ./scripts/flash.sh left
#
# Keymap-only changes need the LEFT half only — it is the central half and does
# all keymap processing. Reflash both when the ZMK revision, corne.conf, or the
# shield list changes.
set -euo pipefail

HALF="${1:-}"
if [[ "$HALF" != "left" && "$HALF" != "right" ]]; then
    echo "usage: $0 left|right [path-to.uf2]" >&2
    exit 2
fi

FORCE=""
ARGS=()
for a in "${@:2}"; do
    if [[ "$a" == "--force" ]]; then FORCE=1; else ARGS+=("$a"); fi
done
IMG="${ARGS[0]:-firmware/corne_${HALF} nice_view_adapter nice_view-nice_nano_v2-zmk.uf2}"
VOL="${NICENANO_VOL:-/Volumes/NICENANO}"

[[ -f "$IMG" ]] || { echo "No such image: $IMG" >&2; exit 1; }
if [[ ! -d "$VOL" ]]; then
    echo "No bootloader volume at $VOL." >&2
    echo "Double-tap reset on the $HALF half, then re-run." >&2
    exit 1
fi

# Refuse an image the bootloader cannot take (wrong UF2 family / start address).
family=$(xxd -p -s 28 -l 4 "$IMG" | sed 's/\(..\)\(..\)\(..\)\(..\)/\4\3\2\1/')
if [[ "$family" != "ada52840" ]]; then
    echo "Refusing: $IMG has UF2 family 0x$(printf '%s' "$family" | tr 'a-f' 'A-F'), expected 0xADA52840." >&2
    echo "A CURRENT.UF2 readback is not flashable — use a build artifact." >&2
    exit 1
fi

# Make sure the half that is actually connected is the half we were asked to
# flash. The bootloader volume looks identical on both, so check the image that
# is currently on it. Pass --force to skip (e.g. a half that was fully erased).
if [[ -z "$FORCE" && -f "$VOL/CURRENT.UF2" ]]; then
    ON_BOARD=$(python3 scripts/identify-half.py "$VOL/CURRENT.UF2" 2>/dev/null | tail -1 || true)
    if [[ -n "$ON_BOARD" && "$ON_BOARD" != "$HALF" ]]; then
        echo "Refusing: you asked to flash '$HALF', but the connected half is '$ON_BOARD'." >&2
        echo "Swap halves, or re-run with --force if you really mean it." >&2
        exit 1
    fi
    echo "Connected half verified: $ON_BOARD"
fi

echo "Flashing $HALF  <-  $IMG"

# -X: skip extended attributes. The board reboots and unmounts the moment it has
# the image, so cp often fails writing xattrs to a device that is already gone.
# That failure means the flash worked, so don't trust cp's exit code — confirm
# by watching for the volume to disappear.
cp -X "$IMG" "$VOL/" 2>/dev/null || true
sync 2>/dev/null || true

for _ in 1 2 3 4 5 6 7 8 9 10; do
    [[ -d "$VOL" ]] || break
    sleep 1
done

if [[ -d "$VOL" ]]; then
    echo "Volume is still mounted after 10s — the image may not have been accepted." >&2
    echo "Check the board, then retry." >&2
    exit 1
fi

echo "Done. $HALF half took the image and rebooted."
echo "('Disk Not Ejected Properly' from macOS is expected, not an error.)"
