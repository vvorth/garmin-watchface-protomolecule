# Building the Dashboard watch face

How to turn this source into a `.prg` you can side-load onto a fenix, and how to
verify it first in the simulator.

`README.md` has the same information woven into the project overview; this file
is the short, standalone checklist.

> **Why there is no CI artifact to just download:** the `monkeyc` compiler ships
> only inside Garmin's Connect IQ SDK, which sits behind a licence click-through
> on `developer.garmin.com`. It cannot be fetched from a sandbox or a stock CI
> runner, so the build has to happen on a machine where you have installed the
> SDK yourself. Once that is done it is a one-liner.

---

## Prerequisites (one time)

You need the Connect IQ SDK **and** the per-device files for every device you
build. The compiler alone is not enough — `monkeyc -d fenix8solar47mm` reads
`~/.Garmin/ConnectIQ/Devices/fenix8solar47mm/`, which is a separate download.

**Easiest — the Monkey C extension for VS Code (publisher: Garmin):**

1. Install the extension.
2. Command Palette (`Ctrl/Cmd+Shift+P`) → **Connect IQ: Install the Connect IQ SDK**.
3. Command Palette → **Connect IQ: Download Devices** → tick **fenix 8 Solar 47mm**
   (and any other device from `manifest.xml` you want: `fenix8solar51mm`,
   `fenix843mm`, `fenix847mm`).

**By hand:** download the SDK Manager from
<https://developer.garmin.com/connect-iq/sdk/>, use it to install an SDK and the
devices, and add the SDK's `bin/` to your `PATH`.

Java 17+ must be on `PATH` (`monkeyc` is a Java program).

---

## A. Build and verify in the simulator (VS Code)

Do this first — it is the real check that the code compiles and runs.

> ⚠️ **Open the `dashboard/` folder as its own VS Code window**
> (`File → Open Folder…` → `…/garmin-watchface-protomolecule/dashboard`).
>
> If you open the **repository root** instead, the Monkey C extension builds the
> root **Protomolecule** project (output `garminwatchfaceprotomolecule.prg`, a
> long list of `Invalid device id` warnings, and `Undefined symbol ':SettingsTitle'`
> / `':SourceHeartRate'` errors from `dashboard/source/settings/` — because the
> Protomolecule build is compiling this project's code against Protomolecule's
> string resources). That is the wrong project. Close it and open `dashboard/`.

1. Command Palette → **Monkey C: Build Current Project**. Choose `fenix8solar47mm`.
   On the first run it offers to generate a developer key — accept.
2. If the build fails, the **Problems** panel shows the exact file and line.
3. When it builds clean: Command Palette → **Monkey C: Run App in Simulator**
   (or `F5`). The face should match `docs/preview.png`.

Things to check in the simulator:

- The weather row shows `--` until you feed it data:
  **File → Simulate Data → Weather**.
- **File → Simulate Data → Sensor History** populates the graph and Body Battery.
- Hold the menu button (or **Menu** in the sim) on the face → the on-watch
  settings menu (Graph / Graph range) should open.
- Battery days, notification badge, alarms, DND, steps all come from
  **Settings → System** and **Simulate Data** in the simulator menus.
- **Simulate → Time** near a sunrise/sunset to see the daylight arc move.

---

## B. Build a side-loadable `.prg`

Once A builds clean:

```sh
cd dashboard
export CIQ_SDK="$(ls -d ~/.Garmin/ConnectIQ/Sdks/*/ | sort -V | tail -1)"   # newest SDK
./build.sh                       # → bin/dashboard-fenix8solar47mm.prg
./build.sh fenix847mm            # a different device from manifest.xml
./build.sh fenix8solar47mm -d    # debug build (needed to attach the simulator)
```

`build.sh` locates the SDK (via `PATH`, `$CIQ_SDK`, or the SDK Manager's default
directory), generates `developer_key.der` on the first run, and calls `monkeyc`.
The raw command it runs is just:

```sh
monkeyc -o bin/dashboard-fenix8solar47mm.prg \
        -f monkey.jungle \
        -y developer_key.der \
        -d fenix8solar47mm \
        -r -w
```

From VS Code you can skip the script entirely: **Monkey C: Export Project**
produces the `.prg`.

### The developer key

Every `.prg` is signed with a 4096-bit RSA key. `build.sh` creates
`developer_key.der` the first time it runs; it is gitignored.

- Any key works for side-loading.
- The Connect IQ **store** ties a published app to the key that signed it, so if
  you ever intend to publish: **back this file up** and never commit it.

---

## C. Put it on the watch

1. Connect the fenix over USB and mount it as a drive.
2. Copy `bin/dashboard-fenix8solar47mm.prg` into `GARMIN/APPS/` on the watch.
3. Eject the drive and reboot the watch.
4. On the watch: **Watch Face → Connect IQ → Dashboard**.

To change the graph settings later: from the watch face, hold **Menu** →
face settings; or edit them in Garmin Connect → the watch face → Settings.

---

## Preview without any of this

`tools/preview.py` renders a PNG mock of the face (fixed sample data, DejaVu
standing in for the Garmin fonts, but real per-device resolution and the MIP
64-colour palette). Good for iterating on layout; not a substitute for the
simulator.

```sh
pip install Pillow                        # + a TrueType font, e.g. apt-get install fonts-dejavu-core
python3 tools/preview.py preview.png                      # fenix8solar47mm
python3 tools/preview.py --device fenix847mm out.png
python3 tools/preview.py --all                            # one PNG per device
python3 tools/preview.py --sleep out.png                  # burn-in variant
```

---

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Build output is `garminwatchfaceprotomolecule.prg`, ~100 `Invalid device id` warnings, `Undefined symbol ':SettingsTitle'` / `':SourceHeartRate'` errors | You built the **root Protomolecule** project, not this one. Open the `dashboard/` folder on its own (see section A), or run `./build.sh` from inside `dashboard/`. |
| `could not find the Connect IQ SDK` from `build.sh` | `export CIQ_SDK=…` pointing at the SDK root (the dir containing `bin/monkeyc`), or add `bin/` to `PATH`. |
| `Cannot find device 'fenix8solar47mm'` | Device files not installed — **Connect IQ: Download Devices** in VS Code, or the SDK Manager. |
| Build fails with `monkeyc` errors | The `dashboard/` source has never been through a compiler; first-build errors are expected. The Problems panel / stderr names the file and line. |
| Face loads but weather/graph are blank | Expected until the watch has synced weather and has sensor history. Not a bug — each missing input drops its element. |
| Simulator shows nothing on the graph | **File → Simulate Data → Sensor History** (and pick the matching source in the face's settings). |
