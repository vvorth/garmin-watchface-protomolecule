# CLAUDE.md

Guidance for Claude Code working in this repository.

## What is here

Two **independent** Connect IQ watch face projects. They share nothing but the
git history — each has its own `manifest.xml` and `monkey.jungle`, and building
one never touches the other.

| Path | Project |
| --- | --- |
| repository root | **Protomolecule** — the original face, published on the Connect IQ store. Broken "Expanse" bitmap fonts, Orbit / Circles / Sleep layouts, ~100 supported devices. |
| `dashboard/` | **Dashboard** — a dense information face for the fenix 8 Solar 47 mm, added later. Self-contained; start here unless told otherwise. |

`dashboard/docs/brief.md` is the original request the Dashboard face was built
from, with the reference image beside it. Read it before changing that face's
layout — each row exists for a stated reason.

## Ground truth about the build

**Neither project can be compiled in a sandboxed Claude Code session.** The
`monkeyc` compiler ships only inside Garmin's SDK, which is not on any package
registry and lives behind a licence click-through on `developer.garmin.com` — a
host the session egress policy blocks (CONNECT returns 403). Do not try to route
around it; say so and hand the user the build command instead.

**The `dashboard/` source has never been through a compiler.** It was written,
reviewed by reading, and checked visually with the preview renderer below — but
expect first-build errors and treat any claim that it "works" as unverified.

Building, when an SDK is available:

```sh
cd dashboard && ./build.sh                # → bin/dashboard-fenix8solar47mm.prg
cd dashboard && ./build.sh fenix847mm     # another device from manifest.xml
```

`build.sh` locates the SDK (`PATH`, `$CIQ_SDK`, or the SDK Manager's default
directory), generates the signing key on first run, and calls `monkeyc`.
`dashboard/README.md` has the SDK install steps and the raw command.

## Working on dashboard/

- **Layout lives in `source/Theme.mc`** as fractions of screen height, measured
  off the reference image. Nothing is hard coded to 260×260.
- **`tools/preview.py` renders a PNG** so layout changes can be checked without
  the simulator:
  ```sh
  python3 dashboard/tools/preview.py preview.png                 # fenix8solar47mm
  python3 dashboard/tools/preview.py --device fenix8solar51mm out.png
  python3 dashboard/tools/preview.py --all                       # one PNG per device
  python3 dashboard/tools/preview.py --sleep out.png             # burn-in variant
  ```
  It is a mock, not an emulator — fixed sample data, DejaVu standing in for the
  Garmin system fonts (but the real Chivo for the clock). It **parses
  `source/Theme.mc` at run time**, so the colour palette and the `Layout`
  fractions never need copying by hand. What is still mirrored by hand is the
  per-row geometry inside the `draw*` methods (the `0.042`, `0.395`, … literals):
  **when you touch a `draw` method in `DashboardView.mc` / `Arcs.mc` /
  `Graph.mc` / `Icons.mc`, change the matching method in `preview.py`.** For
  transflective devices it snaps every pixel to the 64-colour MIP palette, so
  dithering shows up in the preview.
- **Fonts.** The clock is a Chivo bitmap font in `resources/fonts/`, generated
  by `tools/make_clock_font.py` from `tools/fonts/Chivo[wght].ttf` (SIL OFL) —
  Connect IQ has no runtime rasteriser, so custom faces ship as an AngelCode
  `.fnt` + `_0.png` atlas. Only digits and space are baked in. Everything else
  is a fixed system font (`FONT_XTINY` / `FONT_TINY`), sized per device by the
  firmware. The bitmap font is one fixed pixel size (for 260×260); adding a
  device of another size means a matching `resources-round-<w>x<h>/fonts/`.
- **Icons are drawn from primitives** in `source/Icons.mc` and scale with the
  screen — no icon bitmaps. Watch faces have a small fixed heap; keep it that
  way.
- **Guard every optional API.** Devices differ, sensors are absent, weather may
  not have synced. `source/Data.mc` is the only place that reads watch state and
  every read there is behind a `has` check, a null check, or a `try`. A missing
  sensor must drop its element, never crash the face.
- **Colours come from the MIP 64-colour palette** — each channel one of `0x00`,
  `0x55`, `0xAA`, `0xFF`. Anything else is dithered by the firmware and looks
  grainy on the watch.
- **Weather conditions are matched on raw integers** in `Icons.forCondition`,
  with the `Weather.CONDITION_*` name in a comment on each. That is deliberate:
  there are ~50 of them and a device SDK missing one would break the build.

## Working on the root project

Leave it alone unless asked. It is a live published app: changing its
`manifest.xml`, app id, or layouts affects real users. Note `.gitattributes`
sets `manifest.xml merge=ours`, so merges deliberately keep the local device
list.

## Monkey C notes

Object-oriented, garbage collected, duck-typed with optional static types
(`as Number`), compiled to bytecode for a small VM. Things that catch people
out:

- `onUpdate` runs **once a minute** on a memory-in-pixel screen. The Dashboard
  face redraws completely each time and keeps no frame state; there is no
  partial-update path because nothing ticks per second.
- `X has :y` is the capability check for both modules and instance members, and
  the compiler understands it as an API-level guard.
- Resources compile into the generated `Rez` symbol (`Rez.Strings.AppName`).
  Every `Rez.Strings.*` you reference must exist in `resources/strings/`.
- Module-level `const` wants a compile-time constant. Prefer a function
  returning an array when the entries reference other modules' constants.
- Reference: https://developer.garmin.com/connect-iq/monkey-c/

## Repository access

Pushing from a session may fail with HTTP 403 and *"Claude doesn't have GitHub
access to this repository for your organization"*. That is an authorization
denial, not a transient error — do not retry it in a loop. Report it and point
the user at claude.ai settings → Connectors to reconnect GitHub, or offer the
commit as a `git bundle` so the work survives the container.
