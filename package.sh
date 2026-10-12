#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
bash "$ROOT/build.sh"
mkdir -p "$ROOT/dist"
STAGE="$(mktemp -d "${TMPDIR:-/tmp/}backcraft-package.XXXXXX")"
MOUNT="$STAGE/mounted"
MOUNTED=false
cleanup() {
  if $MOUNTED; then
    hdiutil detach "$MOUNT" || return 1
  fi
  rm -rf "$STAGE"
}
trap cleanup EXIT
mkdir -p "$STAGE/content/.background" "$MOUNT"
xcrun swift "$ROOT/MakeInstallerArt.swift" "$STAGE/content/.background/Installer.png"
ditto "$ROOT/BackCraft.app" "$STAGE/content/BackCraft.app"
ln -s /Applications "$STAGE/content/Applications"
cp "$ROOT/INSTALAR.txt" "$STAGE/content/.background/INSTALAR.txt"
cp "$ROOT/INSTALAR.txt" "$ROOT/dist/INSTALAR.txt"
cp "$ROOT/BackCraft.app/Contents/Resources/BackCraft.icns" "$STAGE/content/.VolumeIcon.icns"
DMG="$ROOT/dist/BackCraft-1.0.0-arm64.dmg"
hdiutil create -volname "Instalar BackCraft" -srcfolder "$STAGE/content" -format UDRW "$STAGE/editable.dmg"
hdiutil attach -readwrite -noverify -noautoopen -mountpoint "$MOUNT" "$STAGE/editable.dmg"
MOUNTED=true
xcrun SetFile -a C "$MOUNT"
osascript "$ROOT/ConfigureInstaller.applescript" "$MOUNT"
# Finder persists icon locations, the background alias and window bounds in .DS_Store.
for attempt in {1..15}; do
  test -s "$MOUNT/.DS_Store" && break
  sleep 1
done
test -s "$MOUNT/.DS_Store"
sync
hdiutil detach "$MOUNT"
MOUNTED=false
hdiutil convert "$STAGE/editable.dmg" -format UDZO -o "$STAGE/final.dmg"
hdiutil verify "$STAGE/final.dmg"
mv "$STAGE/final.dmg" "$DMG"
hdiutil verify "$DMG"
shasum -a 256 "$DMG"
