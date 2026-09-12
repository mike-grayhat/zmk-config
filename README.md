# chocofi-zmk

ZMK config for a 42-key Corne-compatible split (Chocofi), nice!nano v2 +
nice!view on both halves.

Miryoku's layer scheme, hand-written as a plain ZMK config. Replaces a personal
fork of [`manna-harbour/miryoku_zmk`](https://github.com/manna-harbour/miryoku_zmk),
which pinned an old ZMK and required patching preprocessor headers for every
customisation.

![keymap](keymap-drawer/corne.svg)

## Layout

| # | Layer  | Reached by |
|---|--------|------------|
| 0 | Base   | QWERTY, home row mods |
| 1 | Extra  | Colemak-DH, same thumbs and mods |
| 2 | Tap    | no hold-taps at all; exit via the outer right thumb |
| 3 | Button | hold bottom-row pinky (Z / `/`) |
| 4 | Nav    | hold left thumb SPACE |
| 5 | Mouse  | hold left thumb TAB |
| 6 | Media  | hold left thumb ESC |
| 7 | Num    | hold right thumb BSPC |
| 8 | Sym    | hold right thumb RET |
| 9 | Fun    | hold right thumb DEL |

Layer order is Miryoku's own — Button sits at 3, between Tap and Nav.

Base-layer switching (the `Base` / `Extra` / `Tap` keys on the top row of
Nav/Mouse/Media and Num/Sym/Fun) keeps Miryoku's **double-tap guard**: each is a
tap-dance whose first binding is `&none`, so switching takes two taps and a
stray press does nothing. These are marked `2×` in the diagram.

## Home row mods

The reason for the migration. Miryoku used one hold-tap for everything:

```devicetree
flavor = "tap-preferred";
tapping-term-ms = <200>;
```

No `quick-tap-ms`, no `require-prior-idle-ms`, no positional rules — which made
home-row taps feel laggy. Replaced with urob-style per-hand behaviors:

```devicetree
ZMK_HOLD_TAP(hml,
    flavor = "balanced";
    tapping-term-ms = <280>;
    quick-tap-ms = <175>;
    require-prior-idle-ms = <150>;
    hold-trigger-key-positions = <KEYS_R THUMBS>;
    hold-trigger-on-release;
    bindings = <&kp>, <&kp>;
)
```

`hmr` is the mirror image. The misfire protection comes from the long tapping
term **plus** `hold-trigger-key-positions` / `hold-trigger-on-release` — not
from `require-prior-idle-ms`, which only cuts typing delay. Rule of thumb for
tuning it: `10500 / relaxed WPM`. 150 is a starting point.

Thumb and pinky layer-taps deliberately have **no** positional restriction:
every one of those layers puts something under the same hand that holds it.

## Repo layout

```
build.yaml                    board + shield matrix for CI
keymap_drawer.config.yaml     diagram config (legends, layout)
config/west.yml               ZMK + zmk-helpers, both pinned to a commit
config/corne.conf             sleep, BLE, pointing
config/corne.keymap           the keymap
keymap-drawer/corne.svg       generated diagram, committed by CI
keymap-drawer/viewer.html     interactive viewer, data injected by CI
scripts/build_viewer.py       injects corne.yaml into viewer.html
scripts/backup-firmware.sh    pulls CURRENT.UF2 off a half before flashing
scripts/flash.sh              copies an image onto a half in bootloader mode
firmware/                     build output and readbacks — local only, gitignored
_obsolete/                    old clones + the replaced fork, staged for deletion
```

`config/corne.keymap` uses [zmk-helpers](https://github.com/urob/zmk-helpers)
for its key-position labels and behavior macros, but every layer is written out
as a plain `bindings = < ... >` array — no generated layers.

## Building

CI builds on every push (`.github/workflows/build.yml`) and regenerates the
diagram when the keymap changes (`.github/workflows/draw.yml`).

Locally, via the ZMK build container:

```sh
docker run --rm -it -v "$PWD":/ws -w /ws zmkfirmware/zmk-build-arm:stable bash
west init -l config && west update && west zephyr-export
west build -s zmk/app -b nice_nano_v2 -- \
  -DSHIELD="corne_left nice_view_adapter nice_view" -DZMK_CONFIG=/ws/config
```

Regenerate the diagram and viewer locally (needs `zmk-helpers/` at the repo
root, which `west update` puts there, and keymap-drawer >= 0.18):

```sh
keymap -c keymap_drawer.config.yaml parse -z config/corne.keymap > keymap-drawer/corne.yaml
keymap -c keymap_drawer.config.yaml draw keymap-drawer/corne.yaml > keymap-drawer/corne.svg
python3 scripts/build_viewer.py
```

## Interactive viewer

`keymap-drawer/viewer.html` is a standalone page for browsing the layers: pick
a layer from the rail, and hover any home row mod to see exactly which key
positions can complete its hold — that highlight *is* the behavior's
`hold-trigger-key-positions` list, rendered on the board. Open the file
directly, or view the published copy:

<https://claude.ai/code/artifact/c61a4bee-6a84-4a05-83dc-ad72a08f32b6>

It reads its data from `keymap-drawer/corne.yaml`, so it cannot drift from the
keymap; CI re-injects it whenever the keymap changes.

## Flashing

Keymap processing runs on the central (left) half, so **keymap-only changes
need only the left half reflashed**. Reflash both halves when the ZMK revision,
`corne.conf`, or the shield list changes.

Put a half into bootloader mode by **double-tapping its reset button**, or by
hitting the `boot` key — it sits on the top row of Nav, Mouse, Media, Num and
Fun. It mounts as `/Volumes/NICENANO`.

```sh
# optionally record what is on the board first (see the caveat below)
./scripts/backup-firmware.sh

# flash
./scripts/flash.sh left          # defaults to firmware/corne_left ...uf2
./scripts/flash.sh right

```

Or by hand, which is all the scripts do:

```sh
# back up
cp /Volumes/NICENANO/CURRENT.UF2 firmware/bootloader-readback/$(date +%F)-left-CURRENT.UF2

# flash
cp "firmware/corne_left nice_view_adapter nice_view-nice_nano_v2-zmk.uf2" /Volumes/NICENANO/
```

The board reboots and unmounts itself; macOS reporting *"Disk Not Ejected
Properly"* is expected, not an error.

### `CURRENT.UF2` is not a backup

The `CURRENT.UF2` that appears on `/Volumes/NICENANO` looks like a firmware
dump, and it is — but it is **not restorable**. Checking its header:

| | start address | UF2 family |
|---|---|---|
| `CURRENT.UF2` readback | `0x001000` | `0x239A00B3` |
| a real ZMK build | `0x026000` | `0xADA52840` |

It starts at `0x1000`, inside the SoftDevice region, and carries a family ID the
bootloader will not accept back. Copy it off as a record if you like — that is
what `backup-firmware.sh` does — but your actual rollback path is a build
artifact. `scripts/flash.sh` refuses any image with the wrong family ID so this
cannot be gotten wrong by accident.

### Going back

There is no firmware committed to this repo, deliberately. Rolling back means
rebuilding, which is why ZMK and zmk-helpers are pinned by commit in
`config/west.yml` — **any commit of this repo rebuilds its own exact firmware.**
Check out the commit you want and run the build above, or download the
`firmware` artifact that CI attaches to that commit's run.

To go all the way back to the Miryoku fork, it is still at
`mike-grayhat/miryoku_zmk`, and its `chocofi-qwerty-cyrillic.yml` workflow
builds on demand.

Do not flash `settings_reset` as a precaution — on a split it clears BLE pairing
on both halves and forces the full re-pair procedure. Only if pairing actually
breaks.

## Differences from the old fork

The keymap is position-for-position identical to the fork on all 10 layers
except eight keys, all on Mouse and Sym.

The fork made the same edit to both layers: it put `[` and `'` on the right
pinky column at positions 10 and 22. But those two keys already exist on the
**outer** column immediately to their right (positions 11 and 23), so the edit
bought nothing and silently overwrote whatever was there.

**Mouse layer**

| Position | Fork | Now | Why |
|---|---|---|---|
| 10 — right pinky, top | `[` | `undo` | duplicate of the outer column; the edit dropped undo |
| 19–22 — right home row | `&kp KP_N4/N2/N8` + `'` | `&mmv MOVE_*` | numpad scancodes are OS-level MouseKeys, off by default on macOS; `'` had replaced mouse-right |
| 34 — right bottom, pinky | `&none` | `&msc SCRL_RIGHT` | was a dead key |

**Sym layer**

| Position | Fork | Now | Why |
|---|---|---|---|
| 10 — right pinky, top | `[` | `&bootloader` | duplicate of the outer column; the edit dropped the bootloader key |
| 22 — right pinky, home | `'` | `&kp LGUI` | duplicate of the outer column; the edit dropped the GUI mod |

`[` and `'` are still on Sym and Mouse — on the outer column, where they always
were. Nothing was lost by restoring these.

Note the three "lost" scroll keys on the Mouse layer were already `&none` in
Miryoku itself (`U_WH_*` are all defined as `U_NU`) — they never worked, so
nothing was lost when the fork put `" ' ^ &` there.

Also dropped: the workflow named `chocofi-qwerty-cyrillic.yml` (nothing in it
was Cyrillic-related), and the unused `XXX_LEFT` / `CAPS_42` macros in
`mapping/42/corne.h`.
