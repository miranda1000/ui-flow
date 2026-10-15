# syntax=docker/dockerfile:1
#
# Build environment for ui-flow (Qt 6 / QML): one image, five targets, all built on an
# x86_64 Linux host.
#
#   target          compiler                              Qt (official binaries, aqtinstall)
#   linux-x64       gcc 13                                linux_gcc_64
#   linux-arm64     gcc-aarch64-linux-gnu 13 (multiarch)  linux_gcc_arm64
#   windows-x64     clang-cl + lld-link (MSVC ABI)        win64_msvc2022_64
#   windows-arm64   clang-cl + lld-link (MSVC ABI)        win64_msvc2022_arm64_cross_compiled
#   web             emscripten (emsdk)                    wasm_singlethread (static website)
#
#   MSVC CRT + Windows SDK : downloaded with xwin for x86_64 and aarch64
#                            (building this image means accepting Microsoft's license terms)
#   Qt host tools          : moc, rcc, qmlcachegen, qmlimportscanner ... from linux_gcc_64
#   others                 : nlohmann/json, stb, Inter font
#
# The source tree is NOT copied into the image. run.sh bind-mounts it at /src and the
# container runs /src/scripts/build.sh.

FROM ubuntu:24.04

ARG LLVM_VERSION=20
ARG QT_VERSION=6.10.3
ARG AQT_VERSION=3.3.0
ARG XWIN_VERSION=0.10.0
ARG JSON_TAG=v3.12.0
ARG STB_COMMIT=2c980bb59875b0d32144a71867fbdebb2f77cd20
ARG INTER_VERSION=4.1

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Europe/Madrid

# --- Multiarch: amd64 from the main archive, arm64 from ubuntu-ports ---
RUN sed -i '/^Types:/a Architectures: amd64' /etc/apt/sources.list.d/ubuntu.sources \
    && printf '%s\n' \
        'Types: deb' \
        'URIs: http://ports.ubuntu.com/ubuntu-ports/' \
        'Suites: noble noble-updates noble-security' \
        'Components: main universe' \
        'Architectures: arm64' \
        'Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg' \
        > /etc/apt/sources.list.d/ports-arm64.sources \
    && dpkg --add-architecture arm64

# --- Compilers and tools ---
#   python3-pil, fonts-dejavu-core   scripts/make-demo.py
#   xvfb, xauth, mesa, xcb libs      GUI smoke test of the linux-x64 build (--test)
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl xz-utils unzip zip file git \
        python3 python3-venv python3-pil fonts-dejavu-core \
        cmake ninja-build pkg-config patchelf \
        build-essential g++-aarch64-linux-gnu \
        clang-${LLVM_VERSION} lld-${LLVM_VERSION} llvm-${LLVM_VERSION} \
        xvfb xauth libgl1-mesa-dri \
        libxcb-cursor0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-randr0 \
        libxcb-render-util0 libxcb-shape0 libxcb-xinerama0 libxcb-xkb1 libxkbcommon-x11-0 \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/lib/llvm-${LLVM_VERSION}/bin/clang /usr/local/bin/clang-cl

ENV PATH=/usr/lib/llvm-${LLVM_VERSION}/bin:${PATH}

# --- Libraries the prebuilt Linux Qt links against, for amd64 and arm64 (headers for
#     find_package(Qt6 ...), shared objects so the linker can resolve Qt's own deps).
#     arm64 glib: runtime only - its -dev package drags in an arm64 python. ---
RUN set -eux; \
    pkgs="libgl-dev libegl-dev libopengl-dev libglx-dev libxkbcommon-dev libxkbcommon-x11-dev \
          libfontconfig-dev libfreetype-dev libx11-dev libx11-xcb-dev libxcb1-dev \
          libxcb-cursor-dev libxcb-icccm4-dev libxcb-image0-dev libxcb-keysyms1-dev \
          libxcb-randr0-dev libxcb-render-util0-dev libxcb-shape0-dev libxcb-shm0-dev \
          libxcb-sync-dev libxcb-xfixes0-dev libxcb-xinerama0-dev libxcb-xkb-dev \
          libwayland-dev libdbus-1-dev"; \
    arm="libglib2.0-0t64:arm64"; for p in $pkgs; do arm="$arm $p:arm64"; done; \
    apt-get update; \
    apt-get install -y --no-install-recommends $pkgs libglib2.0-dev $arm; \
    rm -rf /var/lib/apt/lists/*

# --- MSVC CRT + Windows SDK (headers and import libraries), x64 and arm64 ---
RUN curl -fsSL "https://github.com/Jake-Shadle/xwin/releases/download/${XWIN_VERSION}/xwin-${XWIN_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
        | tar -xz -C /tmp \
    && /tmp/xwin-${XWIN_VERSION}-x86_64-unknown-linux-musl/xwin \
        --accept-license --arch x86_64,aarch64 --cache-dir /tmp/xwin-cache \
        splat --output /opt/xwin \
    && rm -rf /tmp/xwin-cache /tmp/xwin-${XWIN_VERSION}-x86_64-unknown-linux-musl

# --- Qt: Linux host tools + the four target builds ---
# aqtinstall 3.3.0 extracts the arm64 cross-compiled Qt and then fails patching a
# qmake.bat it does not ship; that step is irrelevant for CMake builds, so accept the
# failure as long as the CMake package is there.
RUN python3 -m venv /tmp/aqt \
    && /tmp/aqt/bin/pip install --no-cache-dir "aqtinstall==${AQT_VERSION}" \
    && cd /tmp \
    && /tmp/aqt/bin/aqt install-qt linux       desktop ${QT_VERSION} linux_gcc_64    -O /opt/qt \
    && /tmp/aqt/bin/aqt install-qt linux_arm64 desktop ${QT_VERSION} linux_gcc_arm64 -O /opt/qt \
    && /tmp/aqt/bin/aqt install-qt windows     desktop ${QT_VERSION} win64_msvc2022_64 -O /opt/qt \
    && { /tmp/aqt/bin/aqt install-qt windows   desktop ${QT_VERSION} win64_msvc2022_arm64_cross_compiled -O /opt/qt \
         || test -f /opt/qt/${QT_VERSION}/msvc2022_arm64/lib/cmake/Qt6/Qt6Config.cmake; } \
    && rm -rf /tmp/aqt /tmp/aqtinstall.log \
    && ls /opt/qt/${QT_VERSION}

# --- Third-party sources and the UI font ---
RUN set -eux; \
    mkdir -p /opt/deps; cd /opt/deps; \
    git clone -q --depth 1 -b "${JSON_TAG}" https://github.com/nlohmann/json.git json; \
    git init -q stb; cd stb; \
    git fetch -q --depth 1 https://github.com/nothings/stb.git "${STB_COMMIT}"; \
    git checkout -q FETCH_HEAD; cd ..; \
    rm -rf */.git; \
    curl -fsSL -o /tmp/inter.zip "https://github.com/rsms/inter/releases/download/v${INTER_VERSION}/Inter-${INTER_VERSION}.zip"; \
    mkdir -p inter; \
    unzip -q -j /tmp/inter.zip extras/ttf/Inter-Regular.ttf extras/ttf/Inter-Medium.ttf \
        extras/ttf/Inter-SemiBold.ttf LICENSE.txt -d inter; \
    rm /tmp/inter.zip

# --- rsvg-convert: renders the Windows .ico from icons/app.svg (scripts/svg-to-ico.py);
#     xdotool, python3-jsonschema: interaction tests and file format checks (scripts/test.sh) ---
RUN apt-get update && apt-get install -y --no-install-recommends librsvg2-bin xdotool python3-jsonschema \
    && rm -rf /var/lib/apt/lists/*

# --- WebAssembly (target "web"): Emscripten at the exact version Qt's wasm build was made
#     with (Qt checks it: QT_EMCC_RECOMMENDED_VERSION), and Qt for WebAssembly (static,
#     single-threaded: no COOP/COEP headers needed on the web server). ---
ARG EMSDK_VERSION=4.0.7
RUN git clone -q https://github.com/emscripten-core/emsdk.git /opt/emsdk \
    && cd /opt/emsdk \
    && ./emsdk install ${EMSDK_VERSION} \
    && ./emsdk activate ${EMSDK_VERSION} \
    && rm -rf /opt/emsdk/.git /opt/emsdk/zips /opt/emsdk/downloads
RUN python3 -m venv /tmp/aqt \
    && /tmp/aqt/bin/pip install --no-cache-dir "aqtinstall==${AQT_VERSION}" \
    && cd /tmp \
    && /tmp/aqt/bin/aqt install-qt all_os wasm ${QT_VERSION} wasm_singlethread -O /opt/qt \
    && rm -rf /tmp/aqt /tmp/aqtinstall.log \
    && test -f /opt/qt/${QT_VERSION}/wasm_singlethread/lib/cmake/Qt6/qt.toolchain.cmake

ENV LANG=C.UTF-8 \
    XWIN_DIR=/opt/xwin \
    UIFLOW_DEPS_DIR=/opt/deps \
    QT_HOST_PATH=/opt/qt/${QT_VERSION}/gcc_64 \
    QT_LINUX_X64_PATH=/opt/qt/${QT_VERSION}/gcc_64 \
    QT_LINUX_ARM64_PATH=/opt/qt/${QT_VERSION}/gcc_arm64 \
    QT_WIN_X64_PATH=/opt/qt/${QT_VERSION}/msvc2022_64 \
    QT_WIN_ARM64_PATH=/opt/qt/${QT_VERSION}/msvc2022_arm64 \
    QT_WASM_PATH=/opt/qt/${QT_VERSION}/wasm_singlethread \
    EMSDK=/opt/emsdk \
    UIFLOW_TOOLCHAIN_VERSION="gcc-13 llvm-${LLVM_VERSION} qt-${QT_VERSION} xwin-${XWIN_VERSION} emsdk-${EMSDK_VERSION} json-${JSON_TAG}"

WORKDIR /src
CMD ["bash", "/src/scripts/build.sh"]
