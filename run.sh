#!/usr/bin/env bash
# Build ui-flow for Linux and Windows (x64 + arm64) and the web inside Docker (host
# helper; not the container entrypoint).
#
#   ./run.sh                      Release build of all five targets -> dist/
#   ./run.sh -t windows-x64       only some targets (linux-x64, linux-arm64,
#                                 windows-x64, windows-arm64, web; repeat or comma-separate)
#   ./run.sh --debug              Debug build
#   ./run.sh --build              (re)build the Docker image first, then build
#   ./run.sh --test               unit, GUI and interaction tests (screenshots in build/smoke/)
#   ./run.sh --demo               write examples/demo.json (a sample app)
#   ./run.sh --banners [--render-only]  regenerate the README screenshots and banners
#                                 (scripts/readme-banners/; --render-only: banners only)
#   ./run.sh --shell              open a shell in the build container instead
#   other options go to scripts/build.sh (--help there)
#
# Works from Linux, WSL and Git Bash (Docker Desktop or a native Docker engine).
set -euo pipefail

IMAGE_NAME=${UIFLOW_IMAGE:-ui-flow-build}
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

REBUILD_IMAGE=0
OPEN_SHELL=0
RUN_TESTS=0
MAKE_DEMO=0
MAKE_BANNERS=0
BUILD_ARGS=()

usage() {
    sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    echo
    echo "Build options (scripts/build.sh):"
    sed -n '/^Usage:/,/^EOF/p' "$SCRIPT_DIR/scripts/build.sh" | sed '1d;$d'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --build) REBUILD_IMAGE=1 ;;
        --shell) OPEN_SHELL=1 ;;
        --test) RUN_TESTS=1 ;;
        --demo) MAKE_DEMO=1 ;;
        --banners) MAKE_BANNERS=1 ;;
        -h|--help) usage; exit 0 ;;
        *) BUILD_ARGS+=("$1") ;;
    esac
    shift
done

HOST_DIR=$SCRIPT_DIR
DOCKER=docker
DOCKER_USER=()
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        # Git Bash rewrites /src-style arguments into Windows paths; turn that off and
        # hand Docker a native Windows path for the bind mount instead.
        export MSYS_NO_PATHCONV=1
        HOST_DIR=$(cd "$SCRIPT_DIR" && pwd -W)
        ;;
    Linux)
        # Keep build outputs owned by the calling user on native Linux / WSL.
        DOCKER_USER=(--user "$(id -u):$(id -g)")
        ;;
esac

# WSL without Docker Desktop's WSL integration: drive the Windows Docker CLI instead.
if ! { command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; } \
        && grep -qi microsoft /proc/version 2>/dev/null; then
    for candidate in "$(command -v docker.exe 2>/dev/null)" \
                     "/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe"; do
        if [[ -n $candidate && -x $candidate ]] && "$candidate" info >/dev/null 2>&1; then
            DOCKER=$candidate
            HOST_DIR=$(wslpath -w "$SCRIPT_DIR")
            DOCKER_USER=()
            break
        fi
    done
fi

if ! "$DOCKER" info >/dev/null 2>&1; then
    echo "run.sh: cannot reach a Docker daemon. Start Docker Desktop (or the docker service);" >&2
    echo "        from WSL, enable Docker Desktop > Settings > Resources > WSL integration." >&2
    exit 1
fi

if [[ $REBUILD_IMAGE -eq 1 ]] || ! "$DOCKER" image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    echo "==> Building Docker image '$IMAGE_NAME' (first time: ~15 min, ~10 GB)"
    echo "    Note: the image downloads the MSVC CRT and Windows SDK with xwin, which means"
    echo "    accepting Microsoft's license terms for them (https://go.microsoft.com/fwlink/?LinkId=2086102)."
    "$DOCKER" build -t "$IMAGE_NAME" -f "$HOST_DIR/Dockerfile" "$HOST_DIR"
fi

TTY_ARGS=()
if [[ -t 0 && -t 1 ]]; then
    TTY_ARGS=(-it)
fi

# Build trees live in a Docker volume, not in the bind-mounted source tree: much faster
# than a network share, and ninja does not work reliably on SMB/CIFS mounts.
BUILD_VOLUME=${UIFLOW_BUILD_VOLUME:-ui-flow-build-trees}
if [[ ${#DOCKER_USER[@]} -gt 0 ]]; then
    "$DOCKER" run --rm -v "$BUILD_VOLUME:/build" "$IMAGE_NAME" chown "$(id -u):$(id -g)" /build
fi

RUN_ARGS=(--rm "${TTY_ARGS[@]}" "${DOCKER_USER[@]}" -e HOME=/tmp -e UIFLOW_BUILD_ROOT=/build
          -v "$HOST_DIR:/src" -v "$BUILD_VOLUME:/build" -w /src "$IMAGE_NAME")

if [[ $OPEN_SHELL -eq 1 ]]; then
    exec "$DOCKER" run "${RUN_ARGS[@]}" bash
fi
if [[ $RUN_TESTS -eq 1 ]]; then
    exec "$DOCKER" run "${RUN_ARGS[@]}" bash /src/scripts/test.sh
fi
if [[ $MAKE_DEMO -eq 1 ]]; then
    exec "$DOCKER" run "${RUN_ARGS[@]}" python3 /src/scripts/make-demo.py /src/examples/demo.json
fi
if [[ $MAKE_BANNERS -eq 1 ]]; then
    exec "$DOCKER" run "${RUN_ARGS[@]}" bash /src/scripts/readme-banners/make-banners.sh "${BUILD_ARGS[@]}"
fi

exec "$DOCKER" run "${RUN_ARGS[@]}" bash /src/scripts/build.sh "${BUILD_ARGS[@]}"
