#!/usr/bin/env bash
# Wraps the jpackage app image into an AppImage.  Usage: build-appimage.sh <x64|arm64> <out.AppImage>
set -euo pipefail
ARCH="$1"; OUT="$2"
cd "$(dirname "$0")/.."
APP=desktopApp/build/compose/binaries/main/app/PicoChat
[ -d "$APP" ] || { echo "run :desktopApp:createDistributable first"; exit 1; }
rm -rf AppDir && mkdir -p AppDir/usr
cp -r "$APP"/* AppDir/usr/
cp desktopApp/icons/icon.png AppDir/picochat.png
cp desktopApp/icons/picochat.desktop AppDir/picochat.desktop
sed -i 's/^Exec=.*/Exec=PicoChat/' AppDir/picochat.desktop
printf '#!/bin/sh\nHERE="$(dirname "$(readlink -f "$0")")"\nexec "$HERE/usr/bin/PicoChat" "$@"\n' > AppDir/AppRun
chmod +x AppDir/AppRun
TOOL=appimagetool-$([ "$ARCH" = arm64 ] && echo aarch64 || echo x86_64).AppImage
curl -fsSL -o "$TOOL" "https://github.com/AppImage/appimagetool/releases/download/continuous/$TOOL"
chmod +x "$TOOL"
ARCH=$([ "$ARCH" = arm64 ] && echo aarch64 || echo x86_64) ./"$TOOL" --appimage-extract-and-run AppDir "$OUT"
