#!/usr/bin/env bash
# Builds PathOfBuilding.app for macOS (Apple Silicon).
#
# Usage:
#   ./build-macos-app.sh [--no-build] [/path/to/PathOfBuilding-SimpleGraphic]
#
#   --no-build   Skip the cmake build step; use whatever is already in runtime/
#
# If the SimpleGraphic repo path is not given, the script looks for it as a sibling
# of this repo (i.e. ../PathOfBuilding-SimpleGraphic).

set -euo pipefail

POB_DIR="$(cd "$(dirname "$0")" && pwd)"
SG_REPO=""
DO_BUILD=1

for arg in "$@"; do
    case "$arg" in
        --no-build) DO_BUILD=0 ;;
        --*)        echo "Unknown option: $arg" >&2; exit 1 ;;
        *)          SG_REPO="$arg" ;;
    esac
done

if [[ -z "$SG_REPO" ]]; then
    candidate="$(dirname "${POB_DIR}")/PathOfBuilding-SimpleGraphic"
    if [[ -d "$candidate" ]]; then
        SG_REPO="$candidate"
    else
        echo "ERROR: Cannot find PathOfBuilding-SimpleGraphic repo." >&2
        echo "Pass its path as an argument or place it alongside this repo." >&2
        exit 1
    fi
fi

APP_BUNDLE="${POB_DIR}/PathOfBuilding.app"
MACOS_DIR="${APP_BUNDLE}/Contents/MacOS"

# ── Build ──────────────────────────────────────────────────────────────────────
if [[ $DO_BUILD -eq 1 ]]; then
    echo "==> Building SimpleGraphic..."
    cmake -B "${SG_REPO}/build" -S "${SG_REPO}" -DCMAKE_OSX_ARCHITECTURES=arm64
    cmake --build "${SG_REPO}/build" --parallel
    cmake --install "${SG_REPO}/build" --prefix "${POB_DIR}/runtime"
fi

# ── Assemble bundle ────────────────────────────────────────────────────────────
echo "==> Assembling ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"

# Metadata
cp "${SG_REPO}/macos/Info.plist" "${APP_BUNDLE}/Contents/"

# Launcher executable + dylibs
install -m 755 "${POB_DIR}/runtime/PathOfBuilding" "${MACOS_DIR}/"
cp "${POB_DIR}/runtime/"*.dylib "${MACOS_DIR}/"

# Font data (SG_BASE_PATH will be set to MACOS_DIR by the launcher)
mkdir -p "${MACOS_DIR}/SimpleGraphic"
cp -r "${POB_DIR}/runtime/SimpleGraphic/Fonts" "${MACOS_DIR}/SimpleGraphic/"

# Lua stdlib (launcher sets LUA_PATH to <pobRoot>/runtime/lua/)
mkdir -p "${MACOS_DIR}/runtime/lua"
cp -r "${POB_DIR}/runtime/lua/." "${MACOS_DIR}/runtime/lua/"

# PoB Lua sources (launcher defaults to <dir>/src/Launch.lua when invoked with no args)
cp -r "${POB_DIR}/src" "${MACOS_DIR}/src"

# ── Code sign ──────────────────────────────────────────────────────────────────
echo "==> Code signing (ad-hoc)..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "==> Done: ${APP_BUNDLE}"
