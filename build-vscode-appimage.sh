#!/bin/bash
# ========================================================
# Improved Script for building VS Code AppImage
# Author: Copilot (predlog popravkov)
# ========================================================

set -euo pipefail

VERBOSE=false
INSIDER=false
REMOVE=false

while [ $# -gt 0 ]; do
    case "$1" in
        --verbose) VERBOSE=true ;;
        --insider) INSIDER=true ;;
            --remove) REMOVE=true ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
    shift
done

echo "========================================"
echo " Script: VS Code AppImage Builder (improved)"
echo "========================================"

if [ "$REMOVE" = true ]; then
    echo "Removing installed AppImage and desktop entry..."
    APP="vscode"
    CHANNEL="stable"
    if [ "$INSIDER" = true ]; then
        APP="vscode-insiders"
        CHANNEL="insider"
    fi
    ARCH="x86_64"
    IMAGE_OUT="$PWD/${APP}-${ARCH}-${CHANNEL}.AppImage"
    INSTALL_DIR="$HOME/.local/share/applications"
    ICON_INSTALL_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
    INSTALLED_DESKTOP="$INSTALL_DIR/${APP}.desktop"
    ICON_PATH="$ICON_INSTALL_DIR/${APP}.png"
    rm -f "$IMAGE_OUT" "$INSTALLED_DESKTOP" "$ICON_PATH"
    echo "Removed: $IMAGE_OUT"
    echo "Removed: $INSTALLED_DESKTOP"
    echo "Removed: $ICON_PATH"
    exit 0
fi

APP="vscode"
ROOT="$(pwd)"
CHANNEL="stable"
ARCH="x86_64"
BINARY_NAME="code"
DESKTOP_NAME="Visual Studio Code"
STARTUP_WMCLASS="Code"

if [ "$INSIDER" = true ]; then
    CHANNEL="insider"
    APP="vscode-insiders"
    BINARY_NAME="code-insiders"
    DESKTOP_NAME="Visual Studio Code - Insiders"
    STARTUP_WMCLASS="Code - Insiders"
fi

TARBALL_URL="https://update.code.visualstudio.com/latest/linux-x64/${CHANNEL}"
TARBALL="$ROOT/${APP}-linux-x64.tar.gz"
WORKDIR="$ROOT/vscode_build"
APPDIR="$ROOT/${APP}.AppDir"
IMAGE_OUT="$ROOT/${APP}-${ARCH}-${CHANNEL}.AppImage"
APPIMAGETOOL="$ROOT/appimagetool"

# helpers
log() { echo "ℹ️  $*"; }
err() { echo "❌ $*" >&2; }
dbg() { if [ "${VERBOSE:-false}" = true ]; then echo "DEBUG: $*"; fi }

# prepare
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# appimagetool
if command -v appimagetool &>/dev/null; then
    APPIMAGETOOL="appimagetool"
    log "Using system appimagetool"
else
    if [ ! -x "$APPIMAGETOOL" ]; then
        log "Downloading local copy of appimagetool..."
        if $VERBOSE; then
            wget -O "$APPIMAGETOOL" "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-$(uname -m).AppImage"
        else
            wget -q -O "$APPIMAGETOOL" "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-$(uname -m).AppImage"
        fi
        chmod a+x "$APPIMAGETOOL"
    else
        log "Using existing local copy of appimagetool"
    fi
fi

# download tarball
if [ ! -f "$TARBALL" ]; then
    log "Downloading VS Code tarball from: $TARBALL_URL"
    if $VERBOSE; then
        wget -O "$TARBALL" "$TARBALL_URL"
    else
        wget -q -O "$TARBALL" "$TARBALL_URL"
    fi
    if [ ! -s "$TARBALL" ]; then
        err "Failed to download or empty tarball: $TARBALL"
        exit 1
    fi
else
    log "Tarball already exists: $TARBALL"
fi

# extract tarball and reliably detect created directory
log "Extracting tarball..."
# record directories before
before=$(mktemp)
# redirect output of ls into the file, keep a safe fallback
ls -1d */ 2>/dev/null > "$before" || true
if $VERBOSE; then
    tar -xzf "$TARBALL"
else
    tar -xzf "$TARBALL" >/dev/null 2>&1
fi
# find newly created dir
after=$(mktemp)
# redirect output of ls into the file, keep a safe fallback
ls -1d */ 2>/dev/null > "$after" || true
EX_DIR=""
while read -r d; do
    grep -Fxq "$d" "$before" || EX_DIR="$d"
done < "$after"

if [ -z "$EX_DIR" ]; then
    # fallback: try common name
    if [ -d "VSCode-linux-x64" ]; then
        EX_DIR="VSCode-linux-x64/"
    else
        err "Could not detect extracted directory."
        ls -la
        exit 1
    fi
fi
dbg "EX_DIR detected: '$EX_DIR'"

# normalize name without trailing slash
EX_DIR="${EX_DIR%/}"

# If extracted dir is not named VSCode-linux-x64, rename for consistency
if [ "$EX_DIR" != "VSCode-linux-x64" ]; then
    mv "$EX_DIR" "VSCode-linux-x64"
    EX_DIR="VSCode-linux-x64"
fi

# prepare AppDir
log "Preparing AppDir: $APPDIR"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/opt/VSCode"

# copy contents (preserve executables)
if $VERBOSE; then
    cp -a "VSCode-linux-x64/." "$APPDIR/opt/VSCode/"
else
    cp -a "VSCode-linux-x64/." "$APPDIR/opt/VSCode/" >/dev/null 2>&1
fi

# .desktop inside AppDir
DESKTOP_OUT="$APPDIR/${APP}.desktop"
if [ -d "VSCode-linux-x64/usr/share/applications" ]; then
    DESKTOP_SRC=$(ls "VSCode-linux-x64/usr/share/applications"/*.desktop 2>/dev/null | head -n1 || true)
fi
if [ -n "${DESKTOP_SRC:-}" ] && [ -f "$DESKTOP_SRC" ]; then
    cp "$DESKTOP_SRC" "$DESKTOP_OUT"
else
    log "Creating minimal desktop file inside AppDir."
    cat > "$DESKTOP_OUT" <<EOF
[Desktop Entry]
Name=${DESKTOP_NAME}
Comment=Code Editing.
Exec=opt/VSCode/${BINARY_NAME} %F
Icon=${APP}
Type=Application
Terminal=false
Categories=Development;IDE;
StartupWMClass=${STARTUP_WMCLASS}
EOF
fi

# icon
ICON_SRC=""
if [ -f "VSCode-linux-x64/resources/app/resources/linux/code.png" ]; then
    ICON_SRC="VSCode-linux-x64/resources/app/resources/linux/code.png"
elif [ -f "VSCode-linux-x64/resources/app/resources/linux/code.svg" ]; then
    ICON_SRC="VSCode-linux-x64/resources/app/resources/linux/code.svg"
fi
if [ -n "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$APPDIR/${APP}.png"
else
    log "Icon not found in extracted content; continuing without icon"
fi

# AppRun: create as literal (no expansion) then substitute binary name
cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
# Prefer bundled libs
export LD_LIBRARY_PATH="$HERE/opt/VSCode:${LD_LIBRARY_PATH:-}"
# Help locate system data
export XDG_DATA_DIRS="$HERE/usr/share:${XDG_DATA_DIRS:-/usr/share}"
exec "$HERE/opt/VSCode/REPLACE_BINARY" "$@"
EOF
chmod +x "$APPDIR/AppRun"
# replace placeholder with actual binary name
sed -i "s/REPLACE_BINARY/${BINARY_NAME}/g" "$APPDIR/AppRun"

# Build AppImage
log "Building AppImage..."
cd "$ROOT"
[ -f "$IMAGE_OUT" ] && rm -f "$IMAGE_OUT"

if $VERBOSE; then
    ARCH=$ARCH "$APPIMAGETOOL" -n --verbose "$APPDIR" "$IMAGE_OUT"
    rc=$?
else
    ARCH=$ARCH "$APPIMAGETOOL" -n "$APPDIR" "$IMAGE_OUT" >/dev/null 2>&1
    rc=$?
fi

if [ "$rc" -ne 0 ]; then
    err "appimagetool failed (exit ${rc}). Re-run with --verbose to see details."
    exit 1
else
    if [ ! -f "$IMAGE_OUT" ]; then
        err "AppImage was not created. Re-run with --verbose to see appimagetool output."
        exit 1
    fi
    log "AppImage created: $IMAGE_OUT"
fi

# install desktop entry for current user pointing to AppImage
INSTALL_DIR="$HOME/.local/share/applications"
ICON_INSTALL_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
mkdir -p "$INSTALL_DIR" "$ICON_INSTALL_DIR"
INSTALLED_DESKTOP="$INSTALL_DIR/${APP}.desktop"

REAL_IMAGE_OUT="$(realpath "$IMAGE_OUT")"

ICON_PATH=""
if [ -f "$ROOT/${APP}.png" ]; then
    cp -f "$ROOT/${APP}.png" "$ICON_INSTALL_DIR/${APP}.png"
    ICON_PATH="$ICON_INSTALL_DIR/${APP}.png"
elif [ -f "$APPDIR/${APP}.png" ]; then
    cp -f "$APPDIR/${APP}.png" "$ICON_INSTALL_DIR/${APP}.png"
    ICON_PATH="$ICON_INSTALL_DIR/${APP}.png"
fi

if [ -n "$ICON_PATH" ]; then
    cat > "$INSTALLED_DESKTOP" <<EOF
[Desktop Entry]
Name=${DESKTOP_NAME}
Comment=Code Editing.
Exec=${REAL_IMAGE_OUT} %F
Icon=${ICON_PATH}
Type=Application
Terminal=false
Categories=Development;IDE;
StartupWMClass=${STARTUP_WMCLASS}
EOF
else
    cat > "$INSTALLED_DESKTOP" <<EOF
[Desktop Entry]
Name=${DESKTOP_NAME}
Comment=Code Editing.
Exec=${REAL_IMAGE_OUT} %F
Type=Application
Terminal=false
Categories=Development;IDE;
StartupWMClass=${STARTUP_WMCLASS}
EOF
fi
chmod 644 "$INSTALLED_DESKTOP" || true
log "Installed desktop entry: $INSTALLED_DESKTOP"

# cleanup
log "Cleaning temporary files..."
rm -rf "$WORKDIR" "$APPDIR" "$TARBALL"

log "Done. AppImage: $IMAGE_OUT"
