#!/bin/bash
# Assemble dist/Ordo.app from the release build.
# Usage: bundle.sh [scratch-path]   (default .build/main)
set -euo pipefail
cd "$(dirname "$0")/.."

SCRATCH="${1:-.build/main}"
BIN="$SCRATCH/release/OrdoApp"
APP="dist/Ordo.app"

[ -f "$BIN" ] || { echo "error: $BIN not found — run 'make release' first" >&2; exit 1; }

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/OrdoApp"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>              <string>Ordo</string>
	<key>CFBundleDisplayName</key>       <string>Ordo</string>
	<key>CFBundleIdentifier</key>        <string>com.ordo.Ordo</string>
	<key>CFBundleExecutable</key>        <string>OrdoApp</string>
	<key>CFBundlePackageType</key>       <string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.0.0</string>
	<key>CFBundleVersion</key>           <string>1</string>
	<key>LSMinimumSystemVersion</key>    <string>14.0</string>
	<key>LSUIElement</key>               <true/>
	<key>NSPrincipalClass</key>          <string>NSApplication</string>
	<key>NSHumanReadableCopyright</key>  <string>© 2026</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --sign - "$APP"
echo "assembled $APP"
