#!/usr/bin/env bash
# Runs inside the build container (./run.sh --test):
#   1. unit tests of the core library (native build)
#   2. GUI smoke test: the deployed linux-x64 build is started under Xvfb on the demo
#      app in each view and screenshots are written to build/smoke/*.png
set -euo pipefail
SRC_DIR=${SRC_DIR:-/src}
BUILD_ROOT=${UIFLOW_BUILD_ROOT:-$SRC_DIR/build}
cd "$SRC_DIR"
mkdir -p build/smoke

echo "==> Unit tests"
cmake -S . -B "$BUILD_ROOT/tests" -G Ninja -DUIFLOW_BUILD_APP=OFF -DUIFLOW_BUILD_TESTS=ON > build/tests.configure.log
cmake --build "$BUILD_ROOT/tests"
ctest --test-dir "$BUILD_ROOT/tests" --output-on-failure

echo "==> GUI smoke test"
bash scripts/build.sh --target linux-x64 --no-package > build/smoke-build.log 2>&1 || { cat build/smoke-build.log; exit 1; }
VERSION=$(cat "$BUILD_ROOT/linux-x64-release/version.txt")
APP="$BUILD_ROOT/dist/ui-flow-$VERSION-linux-x64/ui-flow"
python3 scripts/make-demo.py build/smoke/demo.json > /dev/null

shot() {  # shot <name> <args...>
    local name=$1; shift
    rm -f "build/smoke/$name.png"
    xvfb-run -a -s "-screen 0 1600x1000x24" "$APP" --size 1440x900 --screenshot "build/smoke/$name.png" "$@" \
        > "build/smoke/$name.log" 2>&1 || true
    if [[ -s "build/smoke/$name.png" ]]; then
        echo "    ok   $name.png"
    else
        echo "    FAIL $name (see build/smoke/$name.log)"; cat "build/smoke/$name.log"; return 1
    fi
    if grep -E "qrc:|\.qml:[0-9]+" "build/smoke/$name.log" >/dev/null; then
        echo "    QML warnings:"; grep -E "qrc:|\.qml:[0-9]+" "build/smoke/$name.log" | sed 's/^/      /'
    fi
}
export QT_QPA_PLATFORM=xcb
shot welcome
shot canvas build/smoke/demo.json
shot canvas-selected build/smoke/demo.json --select screen-2
shot link-selected build/smoke/demo.json --select link-5
shot editor build/smoke/demo.json --edit screen-1
shot player build/smoke/demo.json --play

# Interaction scenarios: xdotool drives the app, which takes its screenshot after 6 s.
# Coordinates are window pixels for a 1440x900 window and the demo layout.
ui() {  # ui <name> "<xdotool steps>" [app args...]   (opens a fresh copy of the demo)
    local name=$1 steps=$2; shift 2
    rm -f "build/smoke/$name.png"
    cp build/smoke/demo.json "build/smoke/$name.json"
    xvfb-run -a -s "-screen 0 1600x1000x24" bash -c '
        "$0" "build/smoke/$1.json" --size 1440x900 --screenshot "build/smoke/$1.png" --screenshot-delay 6000 "${@:3}" \
            > "build/smoke/$1.log" 2>&1 &
        sleep 2.5
        W=$(xdotool search --sync --name "ui-flow" | head -1)
        xdotool windowfocus --sync "$W" 2>/dev/null || true
        m() { xdotool mousemove --window "$W" "$1" "$2"; }
        eval "$2"
        wait' "$APP" "$name" "$steps" "$@" || true
    if [[ -s "build/smoke/$name.png" ]]; then echo "    ok   $name.png"; else echo "    FAIL $name"; cat "build/smoke/$name.log"; return 1; fi
    if grep -E "qrc:|\.qml:[0-9]+" "build/smoke/$name.log" >/dev/null; then
        grep -E "qrc:|\.qml:[0-9]+" "build/smoke/$name.log" | sed 's/^/      /'
    fi
}
# Editor on "Profile": its image spans about x 537..879, y 104..843; below y 300 it is empty.
DRAW='m 581 454; xdotool mousedown 1; for i in 1 2 3 4 5 6; do m $((581 + i * 36)) $((454 + i * 15)); sleep 0.05; done'
ui editor-drawing "$DRAW; sleep 5; xdotool mouseup 1" --edit screen-4
ui editor-drawn "$DRAW; xdotool mouseup 1; sleep 0.3; m 1000 300" --edit screen-4
ui editor-deleted "$DRAW; xdotool mouseup 1; sleep 0.3; xdotool key Delete" --edit screen-4
ui editor-esc "$DRAW; xdotool mouseup 1; sleep 0.3; m 1300 128; xdotool click 1; sleep 0.2; xdotool type Ok; xdotool key Escape" \
    --edit screen-4
# Canvas: select "Reset password" (leftmost screen) and delete it: the panel must update.
ui canvas-deleted "m 368 520; xdotool click 1; sleep 0.3; xdotool key Delete"

echo "==> File format: files against docs/ui-flow.schema.json"
python3 - examples/demo.json build/smoke/editor-drawn.json build/smoke/editor-esc.json build/smoke/canvas-deleted.json <<'PY'
import json, sys
import jsonschema
schema = json.load(open("docs/ui-flow.schema.json"))
jsonschema.Draft202012Validator.check_schema(schema)
for path in sys.argv[1:]:
    doc = json.load(open(path))
    jsonschema.Draft202012Validator(schema).validate(doc)
    print(f"    ok   {path}  ({len(doc['screens'])} screens, {sum(len(s['hotspots']) for s in doc['screens'])} hotspots, {len(doc['links'])} links)")
PY
echo "==> Done"
