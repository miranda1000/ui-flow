#!/usr/bin/env bash
# Regenerates the images of README.md. Runs inside the build container: ./run.sh --banners
#
#   1. builds the linux-x64 app into $UIFLOW_BUILD_ROOT/readme-banners (apart from the
#      regular build trees), unless --app <ui-flow binary> is given
#   2. writes the example app (example-app.py: "Kettle", a made-up coffee ordering app)
#      and takes screenshots of ui-flow on it under Xvfb at 2x; xdotool drives the mouse
#      and keyboard for the live states (drawing a hotspot, dragging a link, playing)
#   3. renders the banners from those screenshots (render.py)
#
# Output: scripts/readme-banners/screenshots/ (inputs of render.py: the raw captures, the
# example app's screens, its Markdown export) and docs/banners/*.png (shown by README.md).
#   --app <path>     use this ui-flow binary instead of building one
#   --render-only    skip 1 and 2: re-render the banners from screenshots/
set -euo pipefail

SRC_DIR=${SRC_DIR:-/src}
BUILD_ROOT=${UIFLOW_BUILD_ROOT:-$SRC_DIR/build}
HERE=$SRC_DIR/scripts/readme-banners
OWN_ROOT=$BUILD_ROOT/readme-banners
WORK=$OWN_ROOT/work
SHOTS=$WORK/screenshots
APP=""
RENDER_ONLY=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app) APP=$(realpath "${2:?"--app needs a path"}"); shift ;;
        --render-only) RENDER_ONLY=1 ;;
        -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "make-banners.sh: unknown option '$1'" >&2; exit 2 ;;
    esac
    shift
done

# The project may sit on a network share that mixes up files created within milliseconds
# of each other: everything is generated in the build volume, then copied over one file at
# a time and read back.
publish() {  # publish <dest dir> <files...>
    local dest=$1 f; shift
    mkdir -p "$dest"
    for f in "$@"; do
        cp "$f" "$dest/"
        sleep 0.2
    done
    for f in "$@"; do
        cmp -s "$f" "$dest/$(basename "$f")" || { echo "make-banners.sh: $dest/$(basename "$f") reads back wrong" >&2; exit 1; }
    done
    if [[ -n $(stat -c %i "$dest"/* | sort | uniq -d) ]]; then
        echo "make-banners.sh: files in $dest share an inode number (network share?), check them" >&2
        exit 1
    fi
}

if [[ $RENDER_ONLY -eq 0 ]]; then
    mkdir -p "$OWN_ROOT"
    if [[ -z $APP ]]; then
        # CMake cannot reuse a build tree configured from another source tree (a worktree).
        CACHE=$OWN_ROOT/linux-x64-release/CMakeCache.txt
        if [[ -f $CACHE ]] && ! grep -qx "CMAKE_HOME_DIRECTORY:INTERNAL=$SRC_DIR" "$CACHE"; then
            rm -rf -- "${OWN_ROOT:?}/linux-x64-release"
        fi
        echo "==> Building linux-x64 (log: $OWN_ROOT/build.log)"
        UIFLOW_BUILD_ROOT=$OWN_ROOT bash "$SRC_DIR/scripts/build.sh" --target linux-x64 --no-package \
            > "$OWN_ROOT/build.log" 2>&1 || { tail -40 "$OWN_ROOT/build.log"; exit 1; }
        APP=$OWN_ROOT/dist/ui-flow-$(cat "$OWN_ROOT/linux-x64-release/version.txt")-linux-x64/ui-flow
    fi

    echo "==> Example app"
    rm -rf -- "${WORK:?}"
    mkdir -p "$SHOTS"
    python3 "$HERE/example-app.py" "$WORK/example.json" "$SHOTS/example-app" > /dev/null
    # Close-ups: Menu + Caffè latte without the link that the "link" shot draws, and the
    # first two screens for the "drop in your screenshots" shot.
    python3 "$HERE/example-app.py" --subset "$WORK/example.json" "$WORK/pair.json" screen-2,screen-3 link-2
    python3 "$HERE/example-app.py" --subset "$WORK/example.json" "$WORK/start.json" screen-1,screen-2
    g++ -std=c++17 -O1 -I"$SRC_DIR/src" -I"$UIFLOW_DEPS_DIR/json/include" -I"$UIFLOW_DEPS_DIR/stb" \
        "$SRC_DIR"/src/core/*.cpp "$HERE/export-md.cpp" -o "$WORK/export-md"
    "$WORK/export-md" "$WORK/example.json" > "$SHOTS/example.md"
    python3 - "$WORK/example.json" "$SHOTS/example-excerpt.json" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
screen = dict(doc["screens"][0], hotspots=doc["screens"][0]["hotspots"][:1])
image = dict(doc["images"][0], data=doc["images"][0]["data"][:24] + "...")
excerpt = {k: doc[k] for k in ("format", "version", "name", "startScreen")}
excerpt.update(screens=[screen], links=doc["links"][:1] + [l for l in doc["links"] if "hotspot" not in l][:1],
               images=[image])
json.dump(excerpt, open(sys.argv[2], "w"), indent=2, ensure_ascii=False)
PY

    echo "==> Screenshots (2x)"
    export QT_QPA_PLATFORM=xcb QT_SCALE_FACTOR=2
    XVFB_ARGS="-screen 0 3000x2000x24"
    check() {
        if [[ -s "$SHOTS/$1.png" ]]; then
            echo "    ok   $1.png"
            rm -f "$SHOTS/$1.log"
        else
            echo "    FAIL $1"; cat "$SHOTS/$1.log"; exit 1
        fi
    }
    shot() {  # shot <name> <app args...>
        local name=$1; shift
        xvfb-run -a -s "$XVFB_ARGS" "$APP" --size 1440x900 --screenshot "$SHOTS/$name.png" "$@" \
            > "$SHOTS/$name.log" 2>&1 || true
        check "$name"
    }
    # drive <name> <screenshot delay ms> "<xdotool steps>" <app args...>
    # Steps use window coordinates of the 1440x900 window in logical pixels: m x y moves
    # the mouse, glide x0 y0 x1 y1 moves it in small steps (for drags).
    drive() {
        local name=$1 delay=$2 steps=$3; shift 3
        xvfb-run -a -s "$XVFB_ARGS" bash -c '
            "$0" --size 1440x900 --screenshot "$1" --screenshot-delay "$2" "${@:4}" > "${1%.png}.log" 2>&1 &
            sleep 2.5
            W=$(xdotool search --sync --name "ui-flow" | head -1)
            xdotool windowfocus --sync "$W" 2>/dev/null || true
            m() { xdotool mousemove --window "$W" $(( $1 * 2 )) $(( $2 * 2 )); }
            glide() { for i in $(seq 1 16); do m $(( $1 + ($3 - $1) * i / 16 )) $(( $2 + ($4 - $2) * i / 16 )); sleep 0.03; done; }
            eval "$3"
            wait' "$APP" "$SHOTS/$name.png" "$delay" "$steps" "$@" || true
        check "$name"
    }
    ex=$WORK/example.json
    shot canvas "$ex"
    shot start "$WORK/start.json"
    # Editor on "Menu": the image spans x 536..879, y 103..846 (0.439 px per image px).
    # Draw a hotspot over the "Cappuccino" card and hold the mouse button.
    drive editor-drawing 6000 "m 712 361; xdotool mousedown 1; glide 712 361 859 550; sleep 5; xdotool mouseup 1" \
        --edit screen-2 "$ex"
    # Click the circle right of the "Caffè latte" hotspot: the list of screens it can open.
    drive editor-picker 4500 "m 715 456; xdotool click 1" --edit screen-2 "$ex"
    # Canvas at 87% on Menu + Caffè latte: drag the "Caffè latte" hotspot onto the screen.
    drive canvas-linking 6000 "m 399 471; xdotool mousedown 1; glide 399 471 951 486; sleep 5; xdotool mouseup 1" \
        "$WORK/pair.json"
    # Same view: drag Menu's purple handle (right edge, middle) onto Caffè latte and type
    # what happens; once with the dialog open, once after Enter.
    TRANSITION="m 590 486; sleep 0.4; m 609 486; sleep 0.3; xdotool mousedown 1; glide 609 486 951 486; sleep 0.3
                xdotool mouseup 1; sleep 0.8; xdotool type --delay 40 'user scans a QR code'"
    drive transition-dialog 6500 "$TRANSITION" "$WORK/pair.json"
    drive transition-new 7000 "$TRANSITION; sleep 0.3; xdotool key Return; sleep 0.3; m 1130 870" "$WORK/pair.json"
    # Player: the screen spans x 397..763, y 75..868 (0.94 px per point of the mock app).
    # Get started, Caffè latte, Add to order, Place order.
    drive player 6400 "for xy in '580 759' '496 453' '580 812' '580 812'; do m \$xy; xdotool click 1; sleep 0.9; done" \
        --play "$ex"
    drive shortcuts 4500 "m 1150 880; xdotool click 1; sleep 0.3; xdotool key F1" "$ex"
    drive app-menu 4500 "m 30 24; xdotool click 1" "$ex"
fi

echo "==> Banners"
INPUTS=$SHOTS
[[ $RENDER_ONLY -eq 1 ]] && INPUTS=$HERE/screenshots
mkdir -p "$WORK/banners"
python3 "$HERE/render.py" "$INPUTS" "$WORK/banners" --icons "$SRC_DIR/src/app/icons"

echo "==> Copying to the source tree"
if [[ $RENDER_ONLY -eq 0 ]]; then
    publish "$HERE/screenshots" "$SHOTS"/*.png "$SHOTS/example.md" "$SHOTS/example-excerpt.json"
    publish "$HERE/screenshots/example-app" "$SHOTS"/example-app/*.png
fi
publish "$SRC_DIR/docs/banners" "$WORK"/banners/*.png
echo "==> Done: docs/banners/ ($(ls "$WORK"/banners | wc -l) images)"
