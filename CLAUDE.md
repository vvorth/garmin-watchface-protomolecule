# CLAUDE.md

Guidance for Claude Code working in this repository.

## What is here

One Connect IQ watch face — **Dashboard**, a dense information face for the
fenix 8 Solar (47 mm and 51 mm). The project is the repository root: its
`manifest.xml`, `monkey.jungle`, `source/` and `resources/` sit at the top
level. (It used to live in a `dashboard/` subdirectory beside an older
"Protomolecule" face; both have been flattened away — ignore any lingering
`dashboard/` path or "root project" mention and fix it if you see one.)

`docs/brief.md` is the original request the face was built from, with the
reference image beside it. Read it before changing the layout — each row exists
for a stated reason.

## Keep docs in step with the code

Prose in this repo is treated as part of the deliverable, not an afterthought.
When a change makes any of the following stale, update it **in the same commit**:

- `docs/internals.md` — architecture, lifecycle, module map, recipes
- `README.md` — the row table, the settings list, the file tree
- `BUILDING.md` — build/verify steps and the troubleshooting table
- this file — anything under "Working on the face" and "Monkey C notes"
- the mirror rule below: `tools/preview.py` tracks every `draw*` change

If you notice existing docs already drifted from the code, say so and fix them
even if it is outside the immediate task.

## Ground truth about the build

**The face cannot be compiled in a sandboxed Claude Code session.** The
`monkeyc` compiler ships only inside Garmin's SDK, which is not on any package
registry and lives behind a licence click-through on `developer.garmin.com` — a
host the session egress policy blocks (CONNECT returns 403). Do not try to route
around it; say so and hand the user the build command instead.

**The face compiles and runs in the simulator** (fenix8solar47mm, SDK 9.2.x) as
of its first build. Layout changes are then checked with the preview renderer
below; treat a claim that a *specific later change* "works" on device as
unverified until the user has re-run it.

Building, when an SDK is available:

```sh
./build.sh                     # → bin/dashboard-fenix8solar47mm.prg
./build.sh fenix8solar51mm     # the other device from manifest.xml
```

`build.sh` locates the SDK (`PATH`, `$CIQ_SDK`, or the SDK Manager's default
directory), generates the signing key on first run, and calls `monkeyc`.
`README.md` has the SDK install steps and the raw command.

## Working on the face

**`docs/internals.md` is the full architecture walkthrough** — entry point,
framework lifecycle, module map, the settings/data-refresh model, and change
recipes. Read it before a non-trivial change; keep it current when the structure
shifts.

- **Layout lives in `source/Theme.mc`** (module `Layout`) as fractions — of
  screen height for anything vertical, of screen width for anything horizontal.
  Nothing is hard coded to 260×260, and **no `draw*` method should contain a
  bare fraction**; add a constant to `Layout` instead. Screen-centred elements
  (clock, date, weather icon, alarm, notification badge) need no X constant.
- **`tools/preview.py` renders a PNG** so layout changes can be checked without
  the simulator:
  ```sh
  python3 tools/preview.py preview.png                 # fenix8solar47mm
  python3 tools/preview.py --device fenix8solar51mm out.png
  python3 tools/preview.py --all                       # one PNG per device
  python3 tools/preview.py --sleep out.png             # burn-in variant
  ```
  It is a mock, not an emulator — fixed sample data, DejaVu standing in for the
  Garmin system fonts (but the real Chivo for the clock). It **parses
  `source/Theme.mc` at run time**, so the colour palette and every `Layout`
  constant are picked up for free. What is still mirrored by hand is the *shape*
  of the drawing — the icon vertex maths in `Icons.mc`, the bar/arc geometry in
  `Graph.mc` / `Arcs.mc`, and the order of operations in each `draw*` method:
  **when you change how something is drawn, change the matching method in
  `preview.py`.** Moving or resizing something via a `Layout` constant needs no
  preview change at all. For transflective devices it snaps every pixel to the
  64-colour MIP palette, so dithering shows up in the preview.
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
- **Respect the refresh tiers in `Data.mc`.** `Data.beginFrame()` takes one
  `DeviceSettings` per frame and `Data.stats()` caches `SystemStats` on the slow
  tier — never call either system API again from a `draw*` method. Anything that
  walks a `SensorHistory` iterator, hits Weather, or changes slower than a
  minute goes behind `fresh(mFooAt)` with the `SLOW_TTL`; only cheap values the
  user wants live on a wrist raise (steps, DND, alarm, notification count) are
  read per frame.
- **Property values are cached.** Any code path that writes a property must call
  `Data.invalidateProperties()` or the change will not take effect. Note
  `onSettingsChanged` fires only for Garmin Connect pushes, not on-watch edits.
- **Colours come from the MIP 64-colour palette** — each channel one of `0x00`,
  `0x55`, `0xAA`, `0xFF`. Anything else is dithered by the firmware and looks
  grainy on the watch. One deliberate exception: `Theme.NOTIFICATION_ON`
  (`0xFF8000`), a user-chosen orange — leave it unless asked.
- **Weather conditions are matched on raw integers** in `Icons.forCondition`,
  with the `Weather.CONDITION_*` name in a comment on each. That is deliberate:
  there are ~50 of them and a device SDK missing one would break the build.

## Monkey C notes

Object-oriented, garbage collected, duck-typed with optional static types
(`as Number`), compiled to bytecode for a small VM. Things that catch people
out:

- `onUpdate` runs **once a minute in low power mode and once a SECOND in high
  power mode** (a wrist raise, ~10 s). The face redraws completely every time
  and keeps no frame state. Never try to save power by returning early without
  drawing — Garmin's guidance is that nothing of the previous frame is
  guaranteed, and it blanks the screen on some devices. Save it in `Data.mc`
  instead, which caches per tier; see `docs/internals.md` §10.
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
