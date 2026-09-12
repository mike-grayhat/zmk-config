# CLAUDE.md

Context for Claude Code working in this repo. Read before touching the keymap.

## Goal

Migrate off a personal fork of `manna-harbour/miryoku_zmk` to a plain,
self-owned ZMK config for a Corne-style split. Keep the Miryoku *layer scheme*
(it works and is in muscle memory); drop the Miryoku *machinery*.

- Fork being replaced: `https://github.com/mike-grayhat/miryoku_zmk` (`master`)
- Diff against upstream:
  `https://github.com/manna-harbour/miryoku_zmk/compare/master...mike-grayhat:miryoku_zmk:master`

Why:

- `miryoku_zmk` last commit June 2025; `manna-harbour/miryoku` June 2024. Pinned
  to an older ZMK than current `main`.
- Every customisation means patching Miryoku's preprocessor headers rather than
  editing a keymap.
- Miryoku's hold-taps cannot express per-hand positional rules without patching
  `miryoku/miryoku_behaviors.dtsi`.
- A Miryoku-generated keymap is not ZMK Studio compatible (it supplies its own
  matrix transform).

## Hardware and build target

- Board: `nice_nano_v2`, both halves
- Shields: `corne_left nice_view_adapter nice_view`,
  `corne_right nice_view_adapter nice_view`
- 42-key Corne: 6 columns per half, 3 rows plus 3 thumbs. The fork edits
  `miryoku/mapping/42/corne.h`, so the outer columns are physically present.
- Keymap processing runs on the central (left) half. Keymap-only changes need
  only the left half reflashed; reflash both when ZMK version, `.conf`, or
  shields change.

**Confirm before scaffolding:** the fork's only build workflow is named
`chocofi-qwerty-cyrillic.yml` but builds Corne shields against the 42-key
mapping, and nothing in the diff is Cyrillic-related. Ask which physical board
is actually in use and whether Cyrillic support is still wanted before writing
`build.yaml`.

## Target architecture

1. Plain `zmk-config` repo layout: `config/`, `build.yaml`, `config/west.yml`.
2. Use the in-tree Corne shield. It already includes
   `layouts/foostan/corne/5column.dtsi` and `6column.dtsi` and selects the
   6-column layout as `zmk,physical-layout`, which covers the outer columns the
   fork hand-patched and satisfies ZMK Studio's physical-layout requirement.
3. Author with [`zmk-helpers`](https://github.com/urob/zmk-helpers) (v2, the
   renamed `zmk-nodefree-config`), installed as a module via `config/west.yml`
   with `urob` as a remote. Use its key-position label header for the board
   rather than raw key indices; check the current path in the repo, it moved
   between v1 and v2.
4. Pin ZMK and every module to explicit revisions in the manifest.

## Keymap content to carry over

From `miryoku/custom_config.h`:

- `MIRYOKU_ALPHAS_QWERTY` — base is QWERTY
- `MIRYOKU_TAP_QWERTY`
- `MIRYOKU_EXTRA_COLEMAKDH` — Colemak-DH lives on the Extra base layer
- Not enabled: `NAV_INVERTEDT`, `CLIPBOARD_WIN`, `LAYERS_FLIP`,
  `MAPPING_EXTENDED_THUMBS`

Layer set: Base, Extra, Tap, Nav, Mouse, Media, Num, Sym, Fun, Button.

Local deviations from stock Miryoku, all intentional unless flagged:

- **Outer columns** (`mapping/42/corne.h`): left `ESC` / `TAB` / `CAPS`, right
  `[` / `'` / `]`, hardcoded across all layers. Note the file also defines
  `XXX_LEFT` and `CAPS_42` macros that are never used — dead code, don't port.
- **Base right pinky home** is `LGUI/SEMI`, changed from stock `SQT`.
- **Tap layer thumbs**: `LCTRL LALT LSHFT | RET ESC →Base`. The outer right
  thumb is `&u_to_U_BASE`, the only exit from Tap.
- **Base-layer switching**: top row of Nav/Mouse/Media is
  `BOOT, →Tap, →Extra, →Base, --` (left hand); top row of Num/Sym/Fun is
  `--, →Base, →Extra, →Tap, BOOT` (right hand). All `to` behaviors are wrapped
  in Miryoku's double-tap guard (a tap-dance of `&none` then `&to`), so they
  need **two taps**. Decide explicitly whether to keep that guard.
- **Sym layer**: right pinky column gets `[` and `'`; bottom row right gets
  `: ' "`, which replaced `&u_to_U_SYM` and `&u_to_U_MOUSE`.
- **Mouse layer**: right pinky column gets `[` and `'`; bottom row right gets
  `" ' ^ &`, which replaced wheel left/down/up. **Flag this** — losing three
  scroll directions looks accidental rather than deliberate.

From `config/corne.conf`, carry forward:

```
CONFIG_ZMK_SLEEP=y
CONFIG_ZMK_IDLE_SLEEP_TIMEOUT=2000000   # ~33 min
CONFIG_ZMK_BLE_EXPERIMENTAL_FEATURES=y
CONFIG_BT_CTLR_TX_PWR_PLUS_8=y
```

## Hold-tap tuning (the main reason for the migration)

Current Miryoku behavior, both `u_mt` and `u_lt`:

```
flavor = "tap-preferred";
tapping-term-ms = <200>;
```

No `quick-tap-ms`, no `require-prior-idle-ms`, no positional hold-taps. The
complaint is **tap latency on the home row**, not spurious modifiers.

Target: urob-style home row mods, one behavior per hand.

```devicetree
hml: home_row_mod_left {
    compatible = "zmk,behavior-hold-tap";
    #binding-cells = <2>;
    flavor = "balanced";
    tapping-term-ms = <280>;
    quick-tap-ms = <175>;
    require-prior-idle-ms = <150>;
    hold-trigger-key-positions = <...right hand + thumbs...>;
    hold-trigger-on-release;
    bindings = <&kp>, <&kp>;
};
```

`hmr` is the mirror image. Fill the position lists from the zmk-helpers label
header, not by hand.

Two things to get right, because most guides get them wrong:

- The misfire protection comes from the **large tapping term plus positional
  hold-taps**, not from `require-prior-idle-ms`. Per urob, with both of those in
  place the idle timeout only reduces typing delay. A snippet without
  `hold-trigger-key-positions` and `hold-trigger-on-release` is not "timeless
  HRMs".
- `require-prior-idle-ms` rule of thumb is 10500 divided by relaxed WPM. 150 is
  a starting point, tune it.

## Layout diagrams

Use [keymap-drawer](https://github.com/caksoylar/keymap-drawer), wired into CI so
the README diagram regenerates on push.

zmk-helpers breaks keymap-drawer parsing by default. Since keymap-drawer 0.18.0
there is explicit support: if zmk-helpers is installed as a Zephyr module, add
to `keymap_drawer.config.yaml` at the repo root:

```yaml
parse_config:
  zmk_additional_includes: ["zmk-helpers/include"]
```

If instead zmk-helpers is copied into `config/zmk-helpers`, no config is needed;
the headers are found automatically.

## ZMK Studio (optional, not yet decided)

If enabled, it needs all of: `CONFIG_ZMK_STUDIO=y`, the `studio-rpc-usb-uart`
snippet in `build.yaml`, a `&studio_unlock` binding in the keymap, and a
physical layout (the in-tree Corne shield provides one). Add
`status = "reserved"` empty layers if spare layers should be addable later.

Two caveats to state plainly if it comes up:

- Once Studio manages the keymap, later changes to the `.keymap` file **will not
  apply** until "Restore Stock Settings" is run from the Studio client. The repo
  stops being the live truth the moment Studio saves.
- Studio cannot configure hold-tap properties at all, so the tuning above stays
  a rebuild regardless.

## Already ruled out — do not re-propose

- **Keymap Editor (nickcoutsos)** — edits bindings arrays in the keymap file;
  macro-generated layers give it nothing to edit. Mutually exclusive with
  zmk-helpers.
- **Pulling Miryoku in as a west module** — it isn't published as one. Its own
  instructions are to fork the repo or clone it and point `ZMK_CONFIG` at
  `config/`.
- **Pre-emptively flashing `settings_reset`** — unnecessary for a keymap change,
  and on a split it clears BLE pairing on both halves and requires the full
  re-pair procedure. Only if pairing actually breaks.
- **QMK / Vial** — wireless nice!nano, staying on ZMK.
- **Changing the alpha layout** (Gallium, Graphite, Canary, Sturdy) — considered
  and deferred. Colemak-DH stays available on the Extra layer.

## Verification

1. Build locally with west before pushing; don't rely on Actions round-trips.
2. Run keymap-drawer against the old fork and the new config and compare the
   SVGs layer by layer. That is the acceptance test for "same layout, new
   plumbing".
3. Flash the left half only for keymap changes.

## Working agreements

- Verify ZMK specifics against `zmk.dev` docs, not Reddit threads or third-party
  blog posts. Where they conflict, the docs win.
- Don't reintroduce preprocessor indirection to save typing. The point of the
  migration is that the keymap file says what the keyboard does.
- Ask before restructuring anything not listed above.