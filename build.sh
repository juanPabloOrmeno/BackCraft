#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/BackCraft.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mkdir -p "$ROOT/Assets"
xcrun swift "$ROOT/MakeIcon.swift" "$ROOT/Assets"
iconutil -c icns "$ROOT/Assets/BackCraft.iconset" -o "$APP/Contents/Resources/BackCraft.icns"
xcrun swiftc -swift-version 5 -target arm64-apple-macos14.0 -O -parse-as-library \
  "$ROOT/Models.swift" "$ROOT/Desktop.swift" "$ROOT/MenuBarController.swift" "$ROOT/WebExplorer.swift" "$ROOT/App.swift" "$ROOT/Tests.swift" \
  -o "$APP/Contents/MacOS/BackCraft" \
  -framework SwiftUI -framework AppKit -framework AVKit -framework AVFoundation -framework ImageIO -framework WebKit
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
"$APP/Contents/MacOS/BackCraft" --self-test
