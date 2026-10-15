#!/usr/bin/env bash
# Entry point of the build container (Dockerfile CMD): configures, builds and packages
# ui-flow for one or more targets. The source tree is bind-mounted at /src.
# Do not run this on the host - use ./run.sh.
set -euo pipefail

SRC_DIR=${SRC_DIR:-/src}
BUILD_ROOT=${UIFLOW_BUILD_ROOT:-$SRC_DIR/build}
ALL_TARGETS=(linux-x64 linux-arm64 windows-x64 windows-arm64)
CONFIG=Release
CLEAN=0
PACKAGE=1
TARGETS=()

usage() {
    cat <<EOF
Usage: build.sh [--release | --debug] [--target <t>]... [--clean] [--no-package]
  --target   linux-x64 | linux-arm64 | windows-x64 | windows-arm64 | all (default: all;
             repeat it or give a comma-separated list)
  --release  optimised build (default)
  --debug    unoptimised build with debug info (Windows: console subsystem)
  --clean    delete the build directories before configuring
  --no-package  build and deploy into dist/ but do not create the .zip / .tar.gz
Output: dist/ui-flow-<version>-<target>[-debug].zip (Windows) / .tar.gz (Linux); the
unpacked folder stays next to the build trees (\$UIFLOW_BUILD_ROOT/dist, see run.sh).
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --release) CONFIG=Release ;;
        --debug) CONFIG=Debug ;;
        --target|-t)
            IFS=',' read -r -a list <<< "${2:?"--target needs a value"}"
            TARGETS+=("${list[@]}")
            shift ;;
        --clean) CLEAN=1 ;;
        --no-package) PACKAGE=0 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "build.sh: unknown option '$1'" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if [[ ${#TARGETS[@]} -eq 0 || " ${TARGETS[*]} " == *" all "* ]]; then
    TARGETS=("${ALL_TARGETS[@]}")
fi
for t in "${TARGETS[@]}"; do
    if [[ " ${ALL_TARGETS[*]} " != *" $t "* ]]; then
        echo "build.sh: unknown target '$t' (${ALL_TARGETS[*]})" >&2
        exit 2
    fi
done

SUFFIX=""
[[ $CONFIG == Debug ]] && SUFFIX="-debug"

echo "==> $CONFIG build of: ${TARGETS[*]}"
echo "    toolchain: ${UIFLOW_TOOLCHAIN_VERSION:-unknown}"

for target in "${TARGETS[@]}"; do
    echo
    echo "==> [$target] configure"
    BUILD_DIR="$BUILD_ROOT/$target-${CONFIG,,}"
    [[ $CLEAN -eq 1 ]] && rm -rf "$BUILD_DIR"
    cmake -S "$SRC_DIR" -B "$BUILD_DIR" -G Ninja \
        -DCMAKE_BUILD_TYPE="$CONFIG" \
        -DCMAKE_TOOLCHAIN_FILE="$SRC_DIR/cmake/toolchains/$target.cmake" \
        > "$BUILD_DIR.configure.log" 2>&1 \
        || { cat "$BUILD_DIR.configure.log"; exit 1; }

    echo "==> [$target] build"
    cmake --build "$BUILD_DIR"

    VERSION=$(cat "$BUILD_DIR/version.txt")
    NAME="ui-flow-$VERSION-$target$SUFFIX"
    # Deployed folder next to the build tree (hundreds of files written in a burst stay
    # off the bind mount); only the archive is copied to dist/ in the source tree.
    STAGE_ROOT="$BUILD_ROOT/dist"
    DIST_DIR="$STAGE_ROOT/$NAME"
    echo "==> [$target] deploy -> $DIST_DIR/"
    rm -rf "$DIST_DIR"
    cmake --install "$BUILD_DIR" --prefix "$DIST_DIR" > /dev/null
    python3 "$SRC_DIR/scripts/deploy.py" --target "$target" --dist "$DIST_DIR" --qml "$SRC_DIR/src/app/qml"
    bash "$SRC_DIR/scripts/licenses.sh" "$DIST_DIR"

    if [[ $PACKAGE -eq 1 ]]; then
        mkdir -p "$SRC_DIR/dist"
        if [[ $target == windows-* ]]; then
            ARCHIVE="$NAME.zip"
            rm -f "$STAGE_ROOT/$ARCHIVE"
            (cd "$STAGE_ROOT" && zip -qr9 "$ARCHIVE" "$NAME")
        else
            ARCHIVE="$NAME.tar.gz"
            tar -czf "$STAGE_ROOT/$ARCHIVE" -C "$STAGE_ROOT" "$NAME"
        fi
        cp "$STAGE_ROOT/$ARCHIVE" "$SRC_DIR/dist/$ARCHIVE"
        echo "==> [$target] dist/$ARCHIVE ($(du -h --apparent-size "$SRC_DIR/dist/$ARCHIVE" | cut -f1))"
    fi
done

echo
echo "==> Done."
