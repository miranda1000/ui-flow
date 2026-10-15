# ui-flow

A small, local, Figma-like tool for mapping how the screens of an app connect. Drop in
screenshots, mark what can be clicked, draw arrows between screens, then press **Play** and
click through the app as a user would.

* **One file per app.** An app is a single, pretty-printed `.json` file with the images
  embedded (base64). It is plain text: diff it, commit it, read it.
* **Native and offline.** C++17 + Qt 6 / QML. No account, no server.
* **Linux and Windows, x64 and arm64**, all cross-compiled from one Docker image.

## The flow

1. **Create an app**: *New app*, give it a name and choose where the `.json` goes.
2. **Add screens**: drag and drop images onto the canvas (or *Add images...*, or paste a
   screenshot with `Ctrl+V`). Each image becomes a screen; the first one is the start screen.
3. **Mark what can be clicked**: double-click a screen to open the editor and drag
   rectangles (*hotspots*) over the buttons, links, fields... Name them.
4. **Link hotspots**: back on the canvas, drag a hotspot (or the small circle on its right
   edge) and drop it on the screen it leads to. A blue arrow appears. In the editor, clicking
   that circle lets you pick the target screen from a list instead.
5. **Describe other transitions**: drag the round purple handle on the right edge of a screen
   onto another screen and type what happens, e.g. *user types command help*. A purple arrow
   with that text appears.
6. **Play**: `F5` (or the *Play* button) opens the player at the start screen. Click the
   hotspots; described transitions are listed on the right (keys `1`-`9`). The path you took
   is shown, `Backspace` goes back, `R` restarts. Clicking where nothing happens briefly
   highlights the clickable areas.

The **Screens** panel lists every screen and how it is reached from the start screen, and
a *Flow check* warns about screens that cannot be reached and hotspots that lead nowhere.
*Export flow as Markdown* writes the same information as a document (see below).

Changes are saved automatically about a second after you stop editing (*Autosave* in the
app menu). Undo/redo cover every change.

### Controls

| Where | Input | Action |
|---|---|---|
| Canvas | drag a screen (title or image) | move it |
| | double-click a screen | edit its hotspots |
| | drag a hotspot, or its circle, onto a screen | link: clicking it opens that screen |
| | drag the purple handle onto a screen | described transition |
| | click / double-click an arrow | select / edit its text |
| | wheel, pinch, `+` / `-` | zoom (turn off *Scroll wheel zooms* in the app menu to make the wheel pan; `Ctrl`+wheel always zooms) |
| | `Shift`+wheel, space+drag, middle or right drag | pan |
| | `Shift+1`, `Shift+0` | zoom to fit, 100% |
| | `Del`, `Enter`, `Ctrl+D`, arrows | delete, edit, duplicate, nudge the selection |
| Editor | drag on the image | draw a hotspot |
| | drag inside / on the handles | move / resize |
| | click the circle right of a hotspot | choose the screen it opens |
| | arrows (`Shift`: 10 px), `Del`, `Esc` | nudge, delete, back to the flow (also from a text field) |
| | drop an image | replace the screen's image (hotspots keep their place) |
| Player | click, `1`-`9` | follow a hotspot / a described transition |
| | `Backspace`, `R`, `H`, `Esc` | back, restart, show hotspots, stop |
| Anywhere | `Ctrl+N` `Ctrl+O` `Ctrl+S` `Ctrl+Z` `Ctrl+Shift+Z` `F5` `Shift+F5` `F1` | new, open, save, undo, redo, play, play from selection, shortcuts |

Command line: `ui-flow [app.json] [--play] [--edit <screen-id>] [--select <id>]
[--size WxH] [--screenshot out.png]`.

## File format

An app is one pretty-printed JSON file: `screens` (with their `hotspots` in image pixels),
`links` (a hotspot or a whole screen → another screen, with an optional `message`) and
`images` (the original files in base64, written last). The full specification is in
[docs/file-format.md](docs/file-format.md), with a JSON Schema in
[docs/ui-flow.schema.json](docs/ui-flow.schema.json) (`./run.sh --test` validates the demo
and files saved by the app against it).

```json
{
  "format": "ui-flow", "version": 1, "name": "Demo app", "startScreen": "screen-1",
  "screens": [ { "id": "screen-1", "name": "Login", "image": "img-1", "x": 0, "y": 0, "scale": 0.4265,
                 "hotspots": [ { "id": "hotspot-1", "name": "Sign in", "x": 60, "y": 860, "w": 660, "h": 110 } ] } ],
  "links":   [ { "id": "link-1", "from": "screen-1", "hotspot": "hotspot-1", "to": "screen-2", "message": "" },
               { "id": "link-5", "from": "screen-2", "to": "screen-5", "message": "user types command help" } ],
  "images":  [ { "id": "img-1", "file": "login.png", "mime": "image/png", "width": 780, "height": 1688, "data": "iVBORw0KGgo..." } ]
}
```

`examples/demo.json` is a small sample app (`./run.sh --demo` regenerates it).

### Markdown export

*Export flow as Markdown* writes, for every screen, how to reach it from the start screen
(`Login → Click "Sign in" → Home → user types command help → Help`), its interactions and
where it is reached from, followed by warnings (unreachable screens, hotspots without links).

## Building

Everything builds inside Docker, like `../pico`. The source tree is bind-mounted, not copied.

```sh
./run.sh                    # all four targets, Release -> dist/
./run.sh -t windows-x64     # only some: linux-x64, linux-arm64, windows-x64, windows-arm64
./run.sh --debug            # Debug build (Windows: console subsystem, DWARF debug info)
./run.sh --test             # unit tests, GUI + interaction tests (screenshots in build/smoke/),
                            # file format check against docs/ui-flow.schema.json
./run.sh --build            # rebuild the Docker image first
./run.sh --shell            # shell in the build container
```

The first run builds the image (~15 minutes, about 10 GB): it downloads the MSVC CRT and
Windows SDK with [xwin](https://github.com/Jake-Shadle/xwin), which means accepting
Microsoft's license terms for them.

Output, per target: `dist/ui-flow-<version>-<target>.zip` (Windows) or `.tar.gz` (Linux).

Build trees and the unpacked builds are kept in the Docker volume `ui-flow-build-trees`
(mounted at `/build`; `./run.sh --shell` to look around, `docker volume rm ui-flow-build-trees`
to start over), not in the project folder. That keeps incremental builds fast when the
project sits on a network share, where ninja is also unreliable.

| Target | Compiler | Qt (official binaries via aqtinstall) |
|---|---|---|
| `linux-x64` | gcc 13 | `linux_gcc_64` |
| `linux-arm64` | `aarch64-linux-gnu-g++` 13 + multiarch arm64 libraries | `linux_gcc_arm64` |
| `windows-x64` | clang-cl + lld-link (MSVC ABI), xwin CRT/SDK | `win64_msvc2022_64` |
| `windows-arm64` | clang-cl + lld-link (MSVC ABI), xwin CRT/SDK | `win64_msvc2022_arm64_cross_compiled` |

`scripts/deploy.py` is a Linux-hosted stand-in for windeployqt/linuxdeployqt: it copies the
Qt libraries, plugins and QML modules the program needs next to it and writes `qt.conf`.

### Running the builds

* **Windows** (10 1809+ or 11, x64 or ARM64): unzip, run `ui-flow.exe`. Needs the
  [Microsoft Visual C++ Redistributable 2015-2022](https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist)
  for the same architecture (most PCs have it already).
* **Linux** (x64 or arm64, glibc 2.34+: Ubuntu 22.04, Debian 12, Fedora 35, RHEL 9 or newer):
  extract and run `./ui-flow`. Works on X11 and Wayland. Needs the usual desktop libraries
  (OpenGL/EGL, fontconfig, xkbcommon; on X11 also `libxcb-cursor0`), which desktop
  distributions install by default.

### Building without Docker

With Qt 6.8+ installed: `cmake -B build -DCMAKE_PREFIX_PATH=<qt> && cmake --build build`.
nlohmann/json and stb are fetched by CMake; set `UIFLOW_FONT_DIR` to a directory with
`Inter-Regular/Medium/SemiBold.ttf` to bundle the Inter font (otherwise the system font is used).

## Layout

```
src/core/      document model, JSON file format, flow analysis, Markdown export, geometry
               (plain C++, no Qt: unit-tested in tests/)
src/app/       Qt side: FlowController (the `Doc` QML singleton, list models, image provider),
               main.cpp, qml/ (views and Figma-style controls), icons/
cmake/         toolchain files per target, glibc compatibility header
scripts/       build.sh (container entry), deploy.py, test.sh, make-demo.py, licenses.sh
docs/          file format specification and JSON Schema
Dockerfile     the build image; run.sh drives it from the host
```

## Third-party

Qt 6 (LGPL-3.0, shipped as unmodified shared libraries), nlohmann/json (MIT),
stb_image (MIT / public domain), Inter (SIL OFL 1.1). Notices are in `licenses/` of
every build.
