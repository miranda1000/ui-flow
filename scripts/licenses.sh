#!/usr/bin/env bash
# licenses.sh <dist dir> - puts the third-party notices next to a deployed build.
set -euo pipefail
DIST=$1
DEPS=${UIFLOW_DEPS_DIR:-/opt/deps}
mkdir -p "$DIST/licenses"
cp "$DEPS/json/LICENSE.MIT" "$DIST/licenses/nlohmann-json-MIT.txt"
cp "$DEPS/stb/LICENSE" "$DIST/licenses/stb.txt"
cp "$DEPS/inter/LICENSE.txt" "$DIST/licenses/Inter-OFL.txt"
cat > "$DIST/licenses/THIRD-PARTY-NOTICES.txt" <<'TXT'
ui-flow uses the following third-party software:

Qt 6 (https://www.qt.io) - GNU Lesser General Public License v3 (LGPL-3.0).
  The Qt libraries are shipped as unmodified shared libraries next to the program
  (Qt6*.dll / lib/libQt6*.so) and can be replaced with other compatible builds.
  License text: https://www.gnu.org/licenses/lgpl-3.0.txt
  Source code:  https://download.qt.io/archive/qt/

nlohmann/json (https://github.com/nlohmann/json) - MIT, see nlohmann-json-MIT.txt
stb_image (https://github.com/nothings/stb) - MIT / public domain, see stb.txt
Inter typeface (https://rsms.me/inter) - SIL Open Font License 1.1, see Inter-OFL.txt
TXT
if [[ $(basename "$DIST") == *windows* ]]; then
    for f in "$DIST/licenses"/*.txt; do sed -i 's/\r\?$/\r/' "$f"; done
fi
